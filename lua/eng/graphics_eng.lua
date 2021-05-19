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
  self.colorfulDebug = false
  -- Draw model boinding boxes?
  self.drawAABBs = false
  -- Draw spheres at the center of AABB's?
  self.drawAABBCenters = false

  -- A list of models loaded from a directory for previewing
  self.testModels = {}

  self.defaultAmbientLightColor = {0.4,0.4,0.4,1}

  self.renderer = Renderer()
  self.renderObjects = {}
  self.aabb_for_model = {}
end

--- Called when the application loads.
-- Loads the default models, shaders, etc. 
function GraphicsEng:onLoad()
  self.hardcoded_models = {
    broken = graphics.newModel('/assets/models/broken.glb'),
    loading = graphics.newModel('/assets/models/loading.glb'),
  }

  self.models_for_eids = {}
  self.materials_for_eids = {}
  self.textures_from_assets = {}
  
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
        return {
            min = newVec3(aabb.min * vec3(sx, sy, sz)),
            max = newVec3(aabb.max * vec3(sx, sy, sz)),
        }
    end
end

--- Called each frame to draw the world
-- Called by Ent
-- @see Ent
function GraphicsEng:onDraw()
    graphics.clear(false, true, true)
    graphics.setCullingEnabled(true)
    graphics.setColor(1, 1, 1, 1)

    local aabbForModel = self.aabbForModel
    
    -- Collect all the objects to sort and draw
    local objects = self.renderObjects
    
    local count = 0
    -- enteties
    -- TODO: Use a managed list instead based on added/removed componets
    for id, entity in pairs(self.client.state.entities) do
        local model = self.models_for_eids[entity.id]
        if model then
            count = count + 1
            -- Default material property is basically plastic
            local material = entity.components.material or {
                metalness = 0,
                roughness = 1
            }

            -- Transparent obects have opposite draw order than opaque objects
            local material_alpha = material and material.color and type(material.color[4]) == "number" and material.color[4] or 1
            local hasTransparency = material and material.hasTransparency or material_alpha < 1
            local transform = newMat4(entity.components.transform:getMatrix())
            assert(entity.id, "must have an id")
            objects[count] = {
                id = id,
                visible = true,
                AABB = aabbForModel(self, model, transform),
                position = newVec3(transform:mul(vec3())),
                hasTransparency = hasTransparency,
                hasReflection = true,
                material = {
                    metalness = material.metalness or 0,
                    roughness = material.roughness or 1,
                },
                draw = function(object, context)
                    -- TODO: not nice with an inline closure but will be less expensive with a managed object list

                    -- Hide head from view but not from reflections.
                    -- TODO: This is stupid expensive for what it does. Move to somewhere
                    if context.view.nr == 1 then
                        local parent = entity:getParent()
                        if parent and parent.id == self.parent.head_id then
                            return
                        end
                    end
                    graphics.push()
                    graphics.transform(transform)

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
                  
                    model:draw()
                    graphics.pop()
                end
            }
        end
    end

    --- Add objects that are drag&dropped into the visor
    for i, model in ipairs(self.testModels) do
        table.insert(objects, {
            id = "Test object " .. i,
            AABB = aabbForModel(self, model, lovr.math.mat4()),
            position = newVec3(0,0,0),
            draw = function(object)
                object.model:draw()
            end
        })
    end
  
    -- clear eventual old objects
    for j = count, #objects do
        objects[j] = nil
    end
  
    -- Draw all of them (unless things are not initialized properly)
    if self.parent:getHead() then 
        local headPosition = self.parent:getHead().components.transform:getMatrix():mul(vec3())
        self.renderStats = self.renderer:render(objects, {
            drawAABB = self.drawAABBs,
            cameraPosition = newVec3(headPosition)
        })
    end
end

--- Load a model for supplied component.
-- @tparam component component The component to load the model for
-- @tparam component old_component The previous component state, if any
function GraphicsEng:loadComponentModel(component, old_component)
  local eid = component.getEntity().id

  if component.type == "hardcoded-model" then
    self:loadHardcodedModel(component.name, function(model)
      self.models_for_eids[eid] = model
    end)
  elseif component.type == "inline" then 
    self.models_for_eids[eid] = self:createMesh(component, old_component)
  elseif component.type == "asset" then
    local cached = self.parent.engines.assets:getAsset(component.name, function (asset)
      if asset then 
        local model = self:modelFromAsset(asset, function (model)
          self.models_for_eids[eid] = model
        end)
      else
        self.models_for_eids[eid] = self.hardcoded_models.broken
      end
    end)
    if cached == nil then 
      self.models_for_eids[eid] = self.hardcoded_models.loading
    end
  end

  -- after loading, apply material if already loaded
  local mat = self.materials_for_eids[eid]
  local model = self.models_for_eids[eid]
  if mat and model and model.setMaterial then
    model:setMaterial(mat)
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

function GraphicsEng:loadTexture(eid, base64, callback)
  loader:load(
    "base64png",
    "base64png/"..eid,
    function(texdata, status)
       if texdata== nil or status == false then
         print("Failed to load base64 texture", eid, ":", texdata)
       else
         local tex = graphics.newTexture(texdata)
         callback(tex)
       end
    end,
    base64
  )
end

--- Loads a material for supplied component.
-- @tparam component component The component to load a material for
-- @tparam component old_component not used
function GraphicsEng:loadComponentMaterial(component, old_component)
  local eid = component.getEntity().id
  local mat = graphics.newMaterial()
  if component.color ~= nil then
    mat:setColor("diffuse", component.color[1], component.color[2], component.color[3], component.color[4])
  end

  local apply = function(texture)
    mat:setTexture(texture)
    self.materials_for_eids[eid] = mat
    -- apply the material to matching mesh, if loaded
    local model = self.models_for_eids[eid]
    if model and model.setMaterial then
      model:setMaterial(mat)
    end
  end
  
  local textureName = component.texture or component.asset_texture
  if textureName == nil then
    apply()
  else
    if string.match(textureName, "asset:") then
      self.parent.engines.assets:getAsset(textureName, function(asset)
        if asset then 
          self:textureFromAsset(asset, apply)
        else
          print("Texture asset " .. textureName .. " was not found")
        end  
      end)
    else
      -- backwards compat.
      self:loadTexture(eid, textureName, apply)
    end
  end
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

--- Called when a new component is added
-- @tparam string component_key The component type
-- @tparam component component The new component
function GraphicsEng:onComponentAdded(component_key, component)
  if component_key == "geometry" then
    self:loadComponentModel(component, nil)
  elseif component_key == "material" then
    self:loadComponentMaterial(component, nil)
  elseif component_key == "environment" then
    self:loadEnvironment(component)
  end
end

--- Called when a component has changed
-- @tparam string component_key The component type
-- @tparam component component The new component state
-- @tparam component old_component The previous component state
function GraphicsEng:onComponentChanged(component_key, component, old_component)
  if component_key == "geometry" then
    self:loadComponentModel(component, old_component)
  elseif component_key == "material" then
    self:loadComponentMaterial(component, old_component)
  elseif component_key == "environment" then
    self:loadEnvironment(component)
  end
end


--- Called when a new component is removed
-- @tparam string component_key The component type
-- @tparam component component The removed component
function GraphicsEng:onComponentRemoved(component_key, component)
  local eid = component.getEntity().id
  if component_key == "geometry" then
    self.models_for_eids[eid] = nil
  elseif component_key == "material" then
    self.materials_for_eids[eid] = nil
  elseif component_key == "environment" then
    self:loadEnvironment(component, true)
  end
end

--- Creates a mesh for a geometry component
-- @tparam geometry_component geom
-- @tparam geometry_component old_geom
function GraphicsEng:createMesh(geom, old_geom)
    local eid = geom.getEntity().id
    local mesh = self.models_for_eids[eid]
    if old_geom then
        --print("createMesh", tablex.deepcompare(geom.triangles, old_geom.triangles), tablex.deepcompare(geom.vertices, old_geom.vertices), tablex.deepcompare(geom.uvs, old_geom.uvs))
    end

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
        print(aabb.min, aabb.max)
        self.aabb_for_model[mesh] = aabb
    end

    if (old_geom == nil or old_geom.texture ~= geom.texture) and geom.texture then
        -- decode texture data and setup material
        self:loadTexture(eid, geom.texture, function(tex)
        local material = graphics.newMaterial(tex)
        mesh:setMaterial(material)
        end)
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


function GraphicsEng:modelFromAsset(asset, callback)
  if self.parent.engines.assets:loadFromAsset(asset, "model-asset", function (modelData)
    if modelData then 
      callback(graphics.newModel(modelData))
    else
      print("Failed to parse model data for " .. asset:id())
      callback(self.hardcoded_models.broken)
    end
  end) then
    callback(self.hardcoded_models.loading)
  end
end

function GraphicsEng:textureFromAsset(asset, callback)
  self.parent.engines.assets:loadFromAsset(asset, "texture-asset", function (image)
    if image then 
      callback(graphics.newTexture(image))
    else
      print("Failed to load texture data")
    end
  end)
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

function GraphicsEng:loadTextureAsset(asset_id, callback)
  self.parent.engines.assets:loadTexture(asset_id, callback)
end

return GraphicsEng


