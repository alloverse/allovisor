--- The Allovisor Grapics engine.
-- @classmod GraphicsEngine

namespace("networkscene", "alloverse")

local array2d = require "pl.array2d"
local tablex = require "pl.tablex"
local pretty = require "pl.pretty"
local allomath = require("lib.allomath")
local alloBasicShader = require "shader/alloBasicShader"
local alloPbrShader = require "shader/alloPbrShader"
local loader = require "lib.async-loader"
local util = require("lib.util")
local Asset = require("lib.alloui.lua.alloui.asset")
local Store = require("lib.lovr-store")

local GraphicsEng = classNamed("GraphicsEng", Ent)

local Renderer = require('eng.renderer')

local graphics = lovr.graphics
local vec3 = lovr.math.vec3
local newVec3 = lovr.math.newVec3
local newMat4 = lovr.math.newMat4

--- Initialize the graphics engine.
function GraphicsEng:_init()
    self:super()
    
    -- Paint every entity in a differnet shade? Nice to figure out what be longs what
    self.colorfulDebug = true
    -- Draw model boinding boxes?
    self.drawAABBs = true
    -- Draw spheres at the center of AABB's?
    self.drawAABBCenters = true
    
    -- A list of models loaded from a directory for previewing
    self.testModels = {}
    
    self.defaultAmbientLightColor = {0.4,0.4,0.4,1}
    
    self.renderer = Renderer()
    self.renderObjects = {} -- entity.id: table
    self.aabb_for_model = {}
end

--- Called when the application loads.
-- Loads the default models, shaders, etc. 
function GraphicsEng:onLoad()
    self.hardcoded_models = {
        broken = graphics.newModel('/assets/models/broken.glb'),
        loading = graphics.newModel('/assets/models/loading.glb'),
    }
    
    self.basicShader = alloBasicShader
    self.pbrShader = alloPbrShader
    
    graphics.setBackgroundColor(.05, .05, .05)
    
    local skyboxName = "sunset"
    self.cloudSkybox = graphics.newTexture({
        left =  'assets/textures/skybox/' .. skyboxName .. '/left.png',
        right = 'assets/textures/skybox/' .. skyboxName .. '/right.png',
        top =   'assets/textures/skybox/' .. skyboxName .. '/top.png',
        bottom = 'assets/textures/skybox/' .. skyboxName .. '/bottom.png',
        back = 'assets/textures/skybox/' .. skyboxName .. '/back.png',
        front = 'assets/textures/skybox/' .. skyboxName .. '/front.png'
    }, {
        type = "cube",
        mipmaps = true
    })
    self.renderer.defaultEnvironmentMap = self.cloudSkybox
    self.renderer.ambientLightColor = self.defaultAmbientLightColor
    self.renderer.drawSkybox = true
    -- self.renderer.debug = "distance"
    
    local videoMedia = {}
    self.videoMedia = videoMedia
    self.client.delegates.onVideo = function(track, pixels, width, height)
        local media = videoMedia[track]
        if not media then return end -- noone wants this
        media.texture:replacePixels(pixels)
    end
    
    self.testModels = {}
    local houseAssetNames = lovr.filesystem.getDirectoryItems("assets/models/testing")
    for i, name in ipairs(houseAssetNames) do
        self:loadHardcodedModel('testing/'..name, function(m) 
            table.insert(self.testModels, m)
        end)
    end
end

function GraphicsEng:aabbForModel(model, transform)
    local _, _, _, sx, sy, sz = transform:unpack()
    if model.getAABB then
        local minx, maxx, miny, maxy, minz, maxz = model:getAABB()
        return {
            min = newVec3(minx*sx, miny*sy, minz*sz),
            max = newVec3(maxx*sx, maxy*sy, maxz*sz)
        }
    else
        local aabb = self.aabb_for_model[model]
        if aabb then
            return {
                min = newVec3(aabb.min * vec3(sx, sy, sz)),
                max = newVec3(aabb.max * vec3(sx, sy, sz)),
            }
        else
            print("Missing aabb for ", model)
            assert(aabb, "aabb missing for ")
        end
    end
end

--- Called each frame to draw the world
-- Called by Ent
-- @see Ent
function GraphicsEng:onDraw()
    graphics.clear(false, true, true)
    graphics.setCullingEnabled(true)
    graphics.setColor(1, 1, 1, 1)
    
    local objects = tablex.values(self.renderObjects)

    for i,object in ipairs(objects) do
        -- TODO: when transform has changed for self or any parent
        local transform = object.entity.components.transform:getMatrix()
        object.position = newVec3(transform:mul(vec3()))
    end
    
    --- Add objects that are drag&dropped into the visor
    for i, model in ipairs(self.testModels) do
        table.insert(objects, {
            id = "Test object " .. i,
            AABB = self:aabbForModel(model, lovr.math.mat4()),
            position = newVec3(0,0,0),
            draw = function(object)
                object.lovr.model:draw()
            end
        })
    end

    -- Send objects to renderer
    local headEnt = self.parent:getHead()
    if headEnt then
        local headPosition = headEnt.components.transform:getMatrix():mul(vec3())
        self.renderStats = self.renderer:render(objects, {
            drawAABB = self.drawAABBs,
            cameraPosition = newVec3(headPosition),
            enableReflections = Store.singleton():load("graphics.reflections"),
        })
    end
end

function GraphicsEng:onHeadAdded(headEnt)
    for k,object in pairs(self.renderObjects) do
        if object.entity:getParent().id == self.parent.head_id then
            object.isHead = true
            object.visible = false
        end
    end
end

-- if both model and material is loaded for eid, then apply the material to the model
function GraphicsEng:applyModelMaterial(object)
    if not object or not object.lovr then return end
    local model = object.lovr.model
    local media = object.live_media
    local material = (media and media.material) or object.lovr.material
    if not model or not material or not model.setMaterial then return end
    model:setMaterial(material)
end

--- Load a bundled model by name.
-- Loads a model asynchronously and then calls the supplied callback.
-- @tparam string name The name of the model. String
-- @param callback A funcion that takes one argument: the loaded model. Called when the model is fuly loaded.
-- @tparam string path Optional. The file to load. If not supplied then a path into the "assets/models" folder will be build from `name`
function GraphicsEng:loadHardcodedModel(name, callback, path)
    local model = self.hardcoded_models[name]
    if model then
        callback(model)
        return
    end
    path = path and path or '/assets/models/'..name
    if not path:has_suffix(".glb") and not path:has_suffix(".gltf") then
        path = path .. ".glb"
    end
    callback(self.hardcoded_models.loading)
    loader:load(
        "model",
        path,
        function(modelData, status)
            if modelData == nil or status == false then
                print("Failed to load model", name, ":", model)
                self.hardcoded_models[name] = self.hardcoded_models.broken
            else
                local model = graphics.newModel(modelData)
                self.hardcoded_models[name] = model
            end
            callback(self.hardcoded_models[name])
        end
    )
end

function GraphicsEng:loadEnvironment(component, wasRemoved)
    if wasRemoved then component = nil end
    -- TODO: Merge all active environment components. 
    -- TODO: Build a table with all environments and their bounds and switch env as player moves between them
    if component and component.ambient and component.ambient.light and component.ambient.light.color then
        self.renderer.ambientLightColor = component.ambient.light.color or {0,0,0,1}
    elseif self.defaultAmbientLightColor then
        self.renderer.ambientLightColor = self.defaultAmbientLightColor
    end
    if component and component.skybox then
        self:loadCubemap(component.skybox, function(cubeTexture)
            self.renderer.defaultEnvironmentMap = cubeTexture
        end)
    elseif self.cloudSkybox then 
        self.renderer.defaultEnvironmentMap = self.cloudSkybox
    end
end


function GraphicsEng:onEntityAdded(ent)
    if ent.components.geometry then
        self:buildObject(ent)
    end
end

function GraphicsEng:onEntityRemoved(ent)
    self.renderObjects[ent.id] = nil
end

--- Called when a new component is added
-- @tparam string component_key The component type
-- @tparam component component The new component
function GraphicsEng:onComponentAdded(component_key, component)
    if component_key == "environment" then
        self:loadEnvironment(component)
    end
end

--- Called when a component has changed
-- @tparam string component_key The component type
-- @tparam component component The new component state
-- @tparam component old_component The previous component state
function GraphicsEng:onComponentChanged(component_key, component, old_component)
    local entity = component:getEntity()
    if component_key == "environment" then
        self:loadEnvironment(component)
    elseif self.renderObjects[entity.id] then
       self:buildObject(entity, component_key, old_component, false)
    end
end


--- Called when a component is removed
-- @tparam string component_key The component type
-- @tparam component component The removed component
function GraphicsEng:onComponentRemoved(component_key, component)
    local entity = component:getEntity()
    if component_key == "environment" then
        self:loadEnvironment(component, true)
    elseif self.renderObjects[entity.id] then
        self:buildObject(entity, component_key, nil, true)
    end
end

function GraphicsEng:buildObject(entity, component_key, old_component, removed)
    local entityId = entity.id
    local object = self.renderObjects[entityId]

    if object and not object.lovr then 
        assert(false, "what")
    end

    if not object then
        object = {
            id = entity.id,
            visible = true,
            entity = entity,
            lovr = {}, -- holds on to lovr objects
        }
        self.renderObjects[entityId] = object
    end

    if entity.components.geometry and (not component_key or component_key == "geometry") then
        local component = entity.components.geometry
        if removed then 
            object.lovr.model = nil
            object.AABB = nil
        elseif component.type == "inline" then
            object.lovr.model = self:createMesh(object, component, old_component)
            object.AABB = self:aabbForModel(object.lovr.model, lovr.math.mat4())
        elseif component.name then
            object.lovr.model = self.hardcoded_models.loading
            object.AABB = self:aabbForModel(object.lovr.model, lovr.math.mat4())
            
            self.parent.engines.assets:loadModel(component.name, function(model)
                if not object == self.renderObjects[entityId] then return end
                if model then
                    object.lovr.model = model
                    object.AABB = self:aabbForModel(object.lovr.model, lovr.math.mat4())
                    self:applyModelMaterial(object)
                else
                    object.lovr.model = self.hardcoded_models.broken
                    object.AABB = self:aabbForModel(object.lovr.model, lovr.math.mat4())
                end
            end)
        end
        object.draw = (removed and nil) or draw_object
    end
    
    if entity.components.material and (not component_key or component_key == "material") then
        local component = entity.components.material
        object.hasTransparency = false -- TODO: calculate
        object.hasReflection = true
        object.material = {
            color = component.color,
            metalness = component.metalness or 0,
            roughness = component.roughness or 1,
            uvScale = component.uvScale or {1,1}
        }

        -- todo: reuse or recreate material?
        local material = object.lovr.material or lovr.graphics.newMaterial()
        object.lovr.material = material
        if component.color then 
            local c = component.color
            material:setColor("diffuse", c[1], c[2], c[3], c[4] or 1)
        end

        if component.texture and component.texture:match("asset:") then
            self.parent.engines.assets:loadTexture(component.texture, function (texture)
                if not object == self.renderObjects[entityId] then return end
                if not texture then return end
                object.lovr.material:setTexture(texture)
                self:applyModelMaterial(object)
            end)
        end
    end

    if entity.components.transform and (not component_key or component_key == "transform") then
        local component = entity.components.transform
        object.getMatrix = function ()
            return component:getMatrix()
        end
    end

    if entity.components.live_media and (not component_key or component_key == "live_media") then
        local component = entity.components.live_media
        local media = nil
        if removed then 
            media = self:liveMediaRemoved(component)
        elseif object.live_media then
            media = self:liveMediaChanged(component)
        else 
            media = self:liveMediaAdded(component)
        end
        object.live_media = media
        self:applyModelMaterial(object)
    end

    if entity.components.relationships then
        local parent = entity:getParent()
        if parent and parent.id == self.parent.head_id then
            object.isHead = true
            object.visible = false
        end
    end

    --todo: isHead
end

function draw_object(object, renderObject, context)    
    -- Hide head from view but not from reflections.
    if context.view.nr == 1 and object.isHead then
        return
    end

    local model = object.lovr.model
    local material = object.material
    local transform = object.getMatrix()
    
    -- Is this reeeeally the right place to handle animations at all?
    -- TODO: some hack so this it only run for entities that needs it
    local animationCount = model.animate and model:getAnimationCount()
    if animationCount and animationCount > 0 then
        local name = model:getAnimationName(1)
        for i = 1, animationCount do 
            if model:getAnimationName(i) == "autoplay" then
                name = "autoplay"
            end
        end
        model:animate(name, lovr.timer.getTime())
    end
    
    if material and material.color then
        lovr.graphics.setColor(table.unpack(material.color))
        model:draw(transform)
        lovr.graphics.setColor(1,1,1,1)
    else
        model:draw(transform)
    end
end

--- Creates a mesh for a geometry component
-- @tparam geometry_component geom
-- @tparam geometry_component old_geom
function GraphicsEng:createMesh(object, geom, old_geom)
    local mesh = object.lovr.model
    if mesh and not mesh.setMaterial then return end
    
    if mesh == nil
        or not tablex.deepcompare(geom.triangles, old_geom.triangles)
        or not tablex.deepcompare(geom.vertices, old_geom.vertices)
        or not tablex.deepcompare(geom.uvs, old_geom.uvs)
        or not tablex.deepcompare(geom.normals, old_geom.normals) then
        
        if geom.normals == nil then 
            geom = self:generateGeometryWithNormals(geom)
        end
        
        -- convert the flattened zero-based indices list
        local z_indices = array2d.flatten(geom.triangles)
        -- convert to 1-based
        local indices = tablex.map(function (x) return x + 1 end, z_indices)
        
        -- figure out vertex format
        local vertex_data = {geom.vertices}
        local mesh_format = {{'lovrPosition', 'float', 3}}
        if (geom.uvs) then 
            table.insert(vertex_data, geom.uvs)
            table.insert(mesh_format, {'lovrTexCoord', 'float', 2})
        end
        if (geom.normals) then 
            table.insert(vertex_data, geom.normals)
            table.insert(mesh_format, {'lovrNormal', 'float', 3})
        end
        -- zip together vertex data
        local combined = tablex.zip(unpack(vertex_data))
        
        -- flatten the inner tables
        local vertices = tablex.map(function (x) return array2d.flatten(x) end, combined)
        
        -- Setup the mesh
        mesh = graphics.newMesh(
            mesh_format,
            vertices,
            'triangles', -- DrawMode
            'static', -- MeshUsage. dynamic, static, stream
            false -- do we need to read the data from the mesh later
        )
        
        mesh:setVertices(vertices)
        mesh:setVertexMap(indices)
        
        -- build aabb
        local minx, maxx, miny, maxy, minz, maxz
        for i, pt in ipairs(geom.vertices) do
            local x, y, z = table.unpack(pt)
            if not minx or x < minx then minx = x end
            if not miny or y < miny then miny = y end
            if not minz or z < minz then minz = z end
            
            if not maxx or x > maxx then maxx = x end
            if not maxy or y > maxy then maxy = y end
            if not maxz or z > maxz then maxz = z end
        end
        
        local aabb = {
            min = newVec3(minx, miny, minz),
            max = newVec3(maxx, maxy, maxz)
        }
        self.aabb_for_model[mesh] = aabb
    end
    return mesh
end

--- Calculate vertex normal from three corner vertices
local function get_triangle_normal(vert1, vert2, vert3)   
    return vec3(vert3.x - vert1.x, vert3.z - vert1.z, vert3.y - vert1.y)
    :cross(vec3(vert2.x - vert1.x, vert2.z - vert1.z, vert2.y - vert1.y))
    :normalize()
end

--- Create a new geom from the old one with unique triangle vertices and sharp normals
-- @tparam geometry_component geom
-- @treturn geometry_component new_geom
function GraphicsEng:generateGeometryWithNormals(geom)
    local new_geom = {
        vertices = {}, triangles = {}, normals = {}, 
        uvs = geom.uvs and {} or nil
    }
    for _, tri in ipairs(geom.triangles) do
        local a, b, c = tri[1] + 1, tri[2] + 1, tri[3] + 1 -- vertex indices
        local tri_vertices = {
            vec3(table.unpack(geom.vertices[a])),
            vec3(table.unpack(geom.vertices[b])),
            vec3(table.unpack(geom.vertices[c]))
        }
        local normal = get_triangle_normal(unpack(tri_vertices))
        for _, v in ipairs(tri_vertices) do
            table.insert(new_geom.vertices, {v:unpack()})
            table.insert(new_geom.normals, {normal:unpack()})
        end
        table.insert(new_geom.triangles, {
            #new_geom.vertices - 3, 
            #new_geom.vertices - 2, 
            #new_geom.vertices - 1
        })
        if (geom.uvs) then
            table.insert(new_geom.uvs, geom.uvs[a])
            table.insert(new_geom.uvs, geom.uvs[b])
            table.insert(new_geom.uvs, geom.uvs[c])
        end
    end
    return new_geom
end

function GraphicsEng:modelFromAsset(asset_id, callback)
    return self.parent.engines.assets:loadModel(asset_id, callback)
end

function GraphicsEng:textureFromAsset(asset_id, callback)
    return self.parent.engines.assets:loadTexture(asset_id, callback)
end

function GraphicsEng:liveMediaAdded(component) 
    local eid = component:getEntity().id
    if component.type == "video" then
        local media = self.videoMedia[component.track_id]
        if not media then
            media = {
                texture = lovr.graphics.newTexture(component.metadata.width, component.metadata.height, 1, {mipmaps = false, format = "rgba"}),
                material = lovr.graphics.newMaterial()
            }
            media.texture:setWrap('clamp', 'clamp')
            media.texture:setFilter('nearest', 0)
            media.material:setTexture(media.texture)
            self.videoMedia[component.track_id] = media
            media.eid = eid
        end
        return media
    end
end

function GraphicsEng:liveMediaChanged(component)
    local eid = component:getEntity().id
    if component.type == "video" then
        local media = self.videoMedia[component.track_id]
        if media then
            media.texture = lovr.graphics.newTexture(component.metadata.width, component.metadata.height, 1, {
                mipmaps = false,
                format = "rgba"
            })
            media.material:setTexture(media.texture)
        else
            self:liveMediaAdded(component)
        end
    end
end

function GraphicsEng:liveMediaRemoved(component)
    local eid = component:getEntity().id
    if component.type == "video" then
        local media = self.videoMedia[component.track_id]
        if media then media.material:setTexture() end
        self.videoMedia[component.track_id] = nil
    end
end

function GraphicsEng:loadCubemap(asset_ids, callback)
    local box = asset_ids
    local failed = false
    if box.left and box.right and box.top and box.bottom and box.front and box.back then
        local sides = {}
        local function request(side, asset_id)
            local asset_id = box[side]
            self.parent.engines.assets:loadImage(asset_id, function(image)
                if failed then return end
                if not image then
                    failed = true
                    print("Failed to load " .. side .. " part of a cubemap")
                    pretty.dump(asset_ids)
                end
                sides[side] = image
                if sides.left and sides.right and sides.top and sides.bottom and sides.front and sides.back then
                    callback(graphics.newTexture(sides))
                end
            end, true)
        end
        
        request('left')
        request('right')
        request('bottom')
        request('top')
        request('front')
        request('back')
    else
        print("Incomplete cubemap spec")
        pretty.dump(asset_ids)
    end
end

return GraphicsEng


