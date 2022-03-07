--- The Allovisor Grapics engine.
-- @classmod GraphicsEngine

namespace("networkscene", "alloverse")

local tablex = require "pl.tablex"
local pretty = require "pl.pretty"
local alloBasicShader = require "shader/alloBasicShader"
local alloPbrShader = require "shader/alloPbrShader"
local Asset = require("lib.alloui.lua.alloui.asset")
local Store = require("lib.lovr-store")

local GraphicsEng = classNamed("GraphicsEng", Ent)

local Renderer = require('eng.renderer')

local graphics = lovr.graphics
local vec3 = lovr.math.vec3
local newVec3 = lovr.math.newVec3

--- Initialize the graphics engine.
function GraphicsEng:_init()
    self:super()
    
    -- Paint every entity in a differnet shade? Nice to figure out what be longs what
    self.colorfulDebug = false
    -- Draw model boinding boxes?
    self.drawAABBs = false
    -- Draw spheres at the center of AABB's?
    self.drawAABBCenters = false
    
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
        object.transform = transform
        object.position = newVec3(transform:mul(vec3()))
    end
    
    --- Add objects that are drag&dropped into the visor
    for i, model in ipairs(self.parent.engines.assets.droppedModels) do
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
        local parent = object.entity:getParent()
        if parent and parent.id == self.parent.head_id then
            object.isHead = true
            object.visible = false
        end
    end
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
    local asset = Asset.File(path)
    self.parent.engines.assets:loadCustomModel(asset, function(modelData, status)
        if model then 
            self.hardcoded_models[name] = model
        else
            print("Failed to load model", name, ":", model)
            self.hardcoded_models[name] = self.hardcoded_models.broken
        end
        callback(self.hardcoded_models[name])
    end)
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
    local entity = component:getEntity()
    if component_key == "environment" then
        self:loadEnvironment(component)
    elseif component_key == "live_media" then
        self:handleVideo(entity, component, nil)
    elseif self.renderObjects[entity.id] then
        self:buildObject(entity, component_key, nil, false)
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
    elseif component_key == "live_media" then 
        self:handleVideo(entity, component, old_component)
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
    elseif component_key == "live_media" then 
        self:handleVideo(entity, nil, component)
    elseif self.renderObjects[entity.id] then
        self:buildObject(entity, component_key, nil, true)
    end
end

function GraphicsEng:handleVideo(entity, component, old_component)
    if (component or old_component).type ~= "video" then return end
    local track_id = (component or old_component).track_id
    local media = self.videoMedia[track_id]
    if not component and old_component and media then -- removed
        print("Removing video track " .. track_id)
        self.videoMedia[track_id] = nil
        for i,eid in pairs(media.consumers) do
            local ent = self.renderObjects[eid]
            if ent and ent.material then 
                ent.material.diffuseTexture = nil
            end
        end
        return
    end
    
    if component and media then -- changed
        print("Changing video track " .. track_id)
        local meta = component.metadata
        if not media.texture or media.texture:getWidth() ~= meta.width or media.texture:getHeight() ~= meta.height then
            media.texture = lovr.graphics.newTexture(component.metadata.width, component.metadata.height, 1, {mipmaps = false, format = "rgba"})
            media.texture:setWrap('clamp', 'clamp')
            media.texture:setFilter('nearest', 0)
        end
        for i,eid in pairs(media.consumers) do
            local ent = self.renderObjects[eid]
            print("assign media material to " .. eid)
            if ent and ent.material then
                ent.material.diffuseTexture = media.texture
            end
        end
    end

    if component and not media then -- added
        print("Adding video track " .. track_id)
        media = {
            owner = entity.id,
            consumers = {}
        }
        local meta = component.metadata
        media.texture = lovr.graphics.newTexture(meta.width, meta.height, 1, {mipmaps = false, format = "rgba"})
        media.texture:setWrap('clamp', 'clamp')
        media.texture:setFilter('nearest', 0)
        self.videoMedia[track_id] = media

        -- note: backcompat
        local object = self.renderObjects[entity.id]
        if object then 
            if not object.material then object.material = {} end
            object.material.diffuseTexture = media.texture
        end
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

    if (not component_key or component_key == "geometry") and entity.components.geometry then
        local component = entity.components.geometry
        if removed then 
            object.lovr.model = nil
            object.AABB = nil
        elseif component.type == "inline" then
            local asset = Asset.Geometry(component)
            object.lovr.model = self.hardcoded_models.loading
            object.AABB = self:aabbForModel(object.lovr.model, entity.components.transform:getMatrix())
            self.parent.engines.assets:loadCustomModel(asset, function (model)
                if not object == self.renderObjects[entityId] then return end
                if not (entity and entity.components and entity.components.transform) then return end
                if model then
                    object.lovr.model = model
                    object.AABB = self:aabbForModel(object.lovr.model, entity.components.transform:getMatrix())
                else
                    object.lovr.model = self.hardcoded_models.broken
                    object.AABB = self:aabbForModel(object.lovr.model, entity.components.transform:getMatrix())
                end
            end)
            
        elseif component.name then
            object.lovr.model = self.hardcoded_models.loading
            object.AABB = self:aabbForModel(object.lovr.model, entity.components.transform:getMatrix())
            self.parent.engines.assets:loadModel(component.name, function(model)
                if not object == self.renderObjects[entityId] then return end
                if not (entity and entity.components and entity.components.transform) then return end
                if model then
                    object.lovr.model = model
                    object.AABB = self:aabbForModel(object.lovr.model, entity.components.transform:getMatrix())
                else
                    object.lovr.model = self.hardcoded_models.broken
                    object.AABB = self:aabbForModel(object.lovr.model, entity.components.transform:getMatrix())
                end
            end)
        end
        object.draw = (removed and nil) or draw_object
    end
    
    if (not component_key or component_key == "material") and entity.components.material then
        local component = entity.components.material
        if not component or removed then
            object.material = nil
        else
            local material_alpha = component.color and type(component.color[4]) == "number" and component.color[4] or 1
            object.hasTransparency = component.hasTransparency or material_alpha < 1
            object.hasReflection = true
            object.material = {
                color = component.color,
                metalness = component.metalness or 0,
                roughness = component.roughness or 1,
                uvScale = component.uvScale or {1,1}
            }

            component.texture = component.asset_texture or component.texture -- back.compat
            if component.texture and component.texture:match("asset:") then
                self.parent.engines.assets:loadTexture(component.texture, function (texture)
                    if not object == self.renderObjects[entityId] then return end
                    object.material.diffuseTexture = texture
                end)
            elseif component.texture and component.texture:match("video:") then
                local track_id = tonumber(component.texture:match("video:(.+)"))
                local media = self.videoMedia[track_id]
                if media then
                    print("found media for material")
                    table.insert(media.consumers, entityId)
                    object.material.diffuseTexture = media.texture
                else
                    print("NEW MEDIA for material")
                    media = {consumers = {entityId}}
                    self.videoMedia[track_id] = media
                end
            end
        end
    end

    -- if (not component_key or component_key == "transform") and entity.components.transform then
    --     -- local component = entity.components.transform
    -- end

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
    local model = object.lovr.model
    local material = object.material
    local transform = object.transform
    
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


