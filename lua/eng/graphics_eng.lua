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

--- Initialize the graphics engine.
function GraphicsEng:_init()
  self:super()

  -- Paint every entity in a differnet shade? Nice to figure out what be longs what
  self.colorfulDebug = false
  -- Draw model boinding boxes?
  self.drawAABBs = false
end

--- Called when the application loads.
-- Loads the default models, shaders, etc. 
function GraphicsEng:onLoad()
  self.hardcoded_models = {
    broken = lovr.graphics.newModel('/assets/models/broken.glb'),
    loading = lovr.graphics.newModel('/assets/models/loading.glb'),
  }
  self:loadHardcodedModel('forest', function() end, '/assets/models/decorations/forest/PUSHILIN_forest.gltf')

  self.models_for_eids = {}
  self.materials_for_eids = {}
  self.textures_from_assets = {}
  
  self.basicShader = alloBasicShader
  self.pbrShader = alloPbrShader

  self.assetManager = self.parent.assetManager
  assert(self.assetManager)

  lovr.graphics.setBackgroundColor(.05, .05, .05)
  
  self.cloudSkybox = lovr.graphics.newTexture({
    left = 'assets/textures/skybox/skybox-left.jpg',
    right = 'assets/textures/skybox/skybox-right.jpg',
    top = 'assets/textures/skybox/skybox-top.jpg',
    bottom = 'assets/textures/skybox/skybox-bottom.jpg',
    back = 'assets/textures/skybox/skybox-back.jpg',
    front = 'assets/textures/skybox/skybox-front.jpg'
  })

  local oliveTex = lovr.graphics.newTexture("assets/textures/olive-noise.png", {})
  self.oliveMat = lovr.graphics.newMaterial(oliveTex, 1, 1, 1, 1)

  local menuplateTex = lovr.graphics.newTexture("assets/textures/menuplate.png", {})
  self.menuplateMat = lovr.graphics.newMaterial(menuplateTex, 1, 1, 1, 1)
end


-- callback(asset)
-- returns the asset if it was found in cache
function GraphicsEng:getAsset(name, callback)
  local cached = nil
  self.assetManager:load(name, function (name, asset)
    if asset == nil then 
      print("Asset " .. name .. " was not found on network")
    end
    cached = asset
    callback(asset)
  end)
  return cached
end

--- Called each frame to draw the world
-- Called by Ent
-- @see Ent
function GraphicsEng:onDraw() 
  lovr.graphics.setCullingEnabled(true)
  lovr.graphics.setColor(1,1,1,1)
  
  if not self.parent.isOverlayScene then
    lovr.graphics.setBackgroundColor(.3, .3, .40)
    lovr.graphics.setShader()
    lovr.graphics.skybox(self.cloudSkybox)
    self:drawDecorations()
  else
    self:drawOutlines()
  end

  lovr.graphics.setColor(1, 1, 1, 1)

  -- Collect all the objects to sort and draw
  local objects = {}

  -- enteties
  for _, entity in pairs(self.client.state.entities) do
    local material = entity.components.material
    local hasTransparency = material and material.hasTransparency
    local shader_name = material and material.shader_name or "basic"
    local material_alpha = material and material.color and type(material.color[4]) == "number" and material.color[4] or 1
    table.insert(objects, {
      material = {
        shaderKey = shader_name,
        hasTransparency = hasTransparency or material_alpha < 1,
      },
      getPosition = function(object)
        if not object.position then 
          object.position = entity.components.transform:getMatrix():mul(lovr.math.vec3())
        end
        return object.position
      end,
      draw = function(object)
        -- local entity = object.entity
        lovr.graphics.push()
        lovr.graphics.transform(entity.components.transform:getMatrix())
        self:_drawEntity(entity, true)
        lovr.graphics.pop()
      end
    })
  end

  -- Draw all of them
  self:drawObjects(objects)

  lovr.graphics.setColor({1,1,1})
end

--- Draws objects in the list in a sorted manner
-- Objects not in view might not be drawn.
-- Each object must have the following structure
-- {
--    material = {
--       shaderKey = string unique to each shader
--       hasTransparency = Objects that has transparency in them gets special sorting treatment
--    }
--    getPosition(object) = function that returns the vec3 world position of the object. It is good if you can cache the result
--    draw(object) = function to handle the drawing of the object
--
--    ... = add other fields you may need in the functions above
-- }
-- @tparam list objects A list of tables with the following structure
function GraphicsEng:drawObjects(objects)
  -- TODO: remove objects that are outside the view frustrum
  math.randomseed(0)
  -- sort into bins based on material properties
  local materialBins = {}
  for i, object in ipairs(objects) do
    local shader = object.material.shaderKey
    local hasTransparency = object.material.hasTransparency
    local key = shader .. (hasTransparency and "_transparent" or "_opaque")
    local bin = materialBins[key]
    if not bin then
      bin = {
        hasTransparency = hasTransparency,
        shader = shader,
      }
      materialBins[key] = bin
    end
    table.insert(bin, object)
  end

  -- sort bins so that those that include transparency are last
  local bins = tablex.values(materialBins)
  table.sort(bins, function (a, b)
    local aScore = a.hasTransparency and 10 or 0
    local bScore = b.hasTransparency and 10 or 0
    return aScore < bScore
  end)

  if not (self.parent and self.parent:getHead() and self.parent:getHead().components and self.parent:getHead().components.transform) then 
    return
  end
  local headPosition = self.parent:getHead().components.transform:getMatrix():mul(lovr.math.vec3())

  -- Draw the objects one bin at a time
  for _, bin in ipairs(bins) do
    
    -- Sort objects in bins featuring transparency from furthest to closest
    if bin.hasTransparency then
      table.sort(bin, function(a, b)
        local aScore = a:getPosition():distance(headPosition)
        local bScore = b:getPosition():distance(headPosition)
        return aScore > bScore
      end)

      -- don't write depth info
      lovr.graphics.setDepthTest('lequal', false)
    else 
      lovr.graphics.setDepthTest('lequal', true)
    end

    for _, object in ipairs(bin) do
      object:draw(object)
    end
  end

  lovr.graphics.setDepthTest('lequal', true)
end

--- Draws an entity.
function GraphicsEng:_drawEntity(entity, applyShader)
  local geom = entity.components.geometry
  local parent = optchain(entity, "components.relationships.parent")
  local model = self.models_for_eids[entity.id]
  
  if geom == nil or model == nil then
    return
  end

  -- don't draw our own head, as it obscures the camera. Also don't draw avatar if we're in overlay
  if entity.id == self.parent.head_id or (not self.parent.active and parent == self.parent.avatar_id) then
    return
  end

  -- special case avatars to get PBR shading and face them towards negative Z
  local pose = optchain(entity, "components.intent.actuate_pose")
  if pose ~= nil then 
    lovr.graphics.rotate(3.14, 0, 1, 0)
  end

  if applyShader then
    local mat = self.materials_for_eids[entity.id]
    if mat and mat:getColor() ~= nil then
      lovr.graphics.setColor(mat:getColor())
    else
      lovr.graphics.setColor(1,1,1,1)
    end

    lovr.graphics.setShader(self:shaderForEntity(entity))
  end

  local animationCount = model.animate and model:getAnimationCount()
  if model.animate and animationCount > 0 then
    local name = model:getAnimationName(1)
    for i = 1, animationCount do 
      if model:getAnimationName(i) == "autoplay" then
        name = "autoplay"
      end
    end
    model:animate(name, lovr.timer.getTime())
  end

  if self.colorfulDebug then 
    lovr.graphics.setColor(math.random(), math.random(), math.random(), 1)
  end

  model:draw()

  -- local drawAABBs = true
  if self.drawAABBs and model.getAABB then
    local minx, maxx, miny, maxy, minz, maxz = model:getAABB()
    local x, y, z = (maxx+minx)*0.5, (maxy+miny)*0.5, (maxz+minz)*0.5
    local w, h, d = maxx-minx, maxy-miny, maxz-minz

    lovr.graphics.box("line", x, y, z, w, h, d)
  end

end

--- Draws outlines.
function GraphicsEng:drawOutlines()
  lovr.graphics.setShader(self.basicShader)
  lovr.graphics.setDepthTest('lequal', false)
  lovr.graphics.setColor(0,0,0, 0.5)
  for eid, entity in pairs(self.client.state.entities) do
    lovr.graphics.push()
    lovr.graphics.transform(entity.components.transform:getMatrix())
    lovr.graphics.scale(1.04, 1.04, 1.04)
    self:_drawEntity(entity, false)
    lovr.graphics.pop()
  end
  lovr.graphics.setDepthTest('lequal', true)
end

--- The simulation tick
-- Called by Ent
-- @tparam number dt, seconds since last frame
-- @see Ent
function GraphicsEng:onUpdate(dt)
  if self.client == nil then return end

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
    local cached = self:getAsset(component.name, function (asset)
      local model = self:modelFromAsset(asset, function (model)
        self.models_for_eids[eid] = model
      end)
    end)
    if cached == nil then 
      self.models_for_eids[eid] = self.hardcoded_models["loading"]
    end
  end

  -- after loading, apply material if already loaded
  local mat = self.materials_for_eids[eid]
  local mod = self.models_for_eids[eid]
  if mat ~= nil and mod ~= nil and mod.setMaterial ~= nil then
    self.models_for_eids[eid]:setMaterial(mat)
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
  callback(self.hardcoded_models["loading"])
  loader:load(
    "model",
    path,
    function(modelData, status)
       if modelData == nil or status == false then
         print("Failed to load model", name, ":", model)
         self.hardcoded_models[name] = self.hardcoded_models["broken"]
       else
         local model = lovr.graphics.newModel(modelData)
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
         local tex = lovr.graphics.newTexture(texdata)
         callback(tex)
       end
    end,
    base64
  )
end


function GraphicsEng:modelHasBumpmap(model)
  local has_bumps = false
  for i = 1, model:getMaterialCount() do
    if model:getMaterial(i):getTexture('normal') ~= nil then
      return true
    end
  end
  return false
end

function GraphicsEng:pbrShaderForModel(model)
  if self:modelHasBumpmap(model) then
    return self.pbrShader.withNormals
  else
    return self.pbrShader.withoutNormals
  end
end

function GraphicsEng:shaderForEntity(ent)
  local mat = ent.components.material
  if mat and mat.shader_name == "pbr" then
    local mod = self.models_for_eids[ent.id]
    return self:pbrShaderForModel(mod)
  else
    return self.basicShader
  end
end

--- Loads a material for supplied component.
-- @tparam component component The component to load a material for
-- @tparam component old_component not used
function GraphicsEng:loadComponentMaterial(component, old_component)
  local eid = component.getEntity().id
  local mat = lovr.graphics.newMaterial()
  if component.color ~= nil then
    mat:setColor("diffuse", component.color[1], component.color[2], component.color[3], component.color[4])
  end

  local apply = function()
    self.materials_for_eids[eid] = mat
    -- apply the material to matching mesh, if loaded
    local mesh = self.models_for_eids[eid]
    if mesh and mesh.setMaterial then
      mesh:setMaterial(mat)
    end
  end
  
  local textureName = component.texture or component.asset_texture
  if textureName == nil then
    apply()
  else
    if string.match(textureName, "asset:") then
      self:getAsset(textureName, function(asset)
        local texture = self:textureFromAsset(asset, function (texture)
          mat:setTexture(texture)
          apply()
        end)
      end)
    else
      -- backwards compat.
      print("b64 tex")
      local texture = self:loadTexture(eid, textureName, function(tex)
        mat:setTexture(tex)
        apply()
      end)      
    end
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
    mesh = lovr.graphics.newMesh(
      mesh_format,
      vertices,
      'triangles', -- DrawMode
      'static', -- MeshUsage. dynamic, static, stream
      false -- do we need to read the data from the mesh later
    )

    mesh:setVertices(vertices)
    mesh:setVertexMap(indices)
  end

  if (old_geom == nil or old_geom.texture ~= geom.texture) and geom.texture then
    -- decode texture data and setup material
    self:loadTexture(eid, geom.texture, function(tex)
      local material = lovr.graphics.newMaterial(tex)
      mesh:setMaterial(material)
    end)
  end

  return mesh
end


--- Draws some forest decorantions
function GraphicsEng:drawDecorations()
  local place = self.client.state.entities["place"]
  local deco = optchain(place, "components.decorations.type")

  lovr.graphics.setShader(self.basicShader)
  if deco == "mainmenu" then
    lovr.graphics.circle( 
      self.menuplateMat,
      0, 0, 0, -- x y z
      12,  -- radius
      -3.14/2, -- angle around axis of rotation
      1, 0, 0 -- rotation axis (x, y, z)
    )
  else
    -- "Floorplate"
    lovr.graphics.circle( 
      self.oliveMat,
      0, 0, 0, -- x y z
      32,  -- radius
      -3.14/2, -- angle around axis of rotation
      1, 0, 0 -- rotation axis (x, y, z)
    )
    
    local forestModel = nil -- self.hardcoded_models.forest
    if forestModel then
      forestModel:draw(0,   .5,   -28,  2,  0,  0,  1,  0,  1)
      forestModel:draw(4,   .5,   -24,  2,  2,  0,  1,  0,  1)
      forestModel:draw(8,   .5,   -20,  2,  0,  0,  1,  0,  1)
      forestModel:draw(12,  .5,   -16,  2,  0,  0,  1,  0,  1)
      forestModel:draw(16,  .5,   -12,  2,  5,  0,  1,  0,  1)
      forestModel:draw(20,  .5,   -8,   2,  5,  0,  1,  0,  1)
      forestModel:draw(24,  .5,   -4,   2,  0,  0,  1,  0,  1)
      forestModel:draw(28,  .5,   0,    2,  1,  0,  1,  0,  1)

      forestModel:draw(28,  .5,   0,    2,  3,  0,  1,  0,  1)
      forestModel:draw(24,  .5,   4,    2,  0,  0,  1,  0,  1)
      forestModel:draw(20,  .5,   8,    2,  0,  0,  1,  0,  1)
      forestModel:draw(16,  .5,   12,   2,  0,  0,  1,  0,  1)
      forestModel:draw(12,  .5,   16,   2,  2,  0,  1,  0,  1)
      forestModel:draw(8,   .5,   20,   2,  2,  0,  1,  0,  1)
      forestModel:draw(4,   .5,   24,   2,  0,  0,  1,  0,  1)
      forestModel:draw(0,   .5,   28,   2,  3,  0,  1,  0,  1)

      forestModel:draw(0,   .5,   -28,  2,  0,  0,  1,  0,  1)
      forestModel:draw(-4,   .5,   -24,  2,  2,  0,  1,  0,  1)
      forestModel:draw(-8,   .5,   -20,  2,  0,  0,  1,  0,  1)
      forestModel:draw(-12,  .5,   -16,  2,  0,  0,  1,  0,  1)
      forestModel:draw(-16,  .5,   -12,  2,  5,  0,  1,  0,  1)
      forestModel:draw(-20,  .5,   -8,   2,  5,  0,  1,  0,  1)
      forestModel:draw(-24,  .5,   -4,   2,  0,  0,  1,  0,  1)
      forestModel:draw(-28,  .5,   0,    2,  1,  0,  1,  0,  1)

      forestModel:draw(-28,  .5,   0,    2,  3,  0,  1,  0,  1)
      forestModel:draw(-24,  .5,   4,    2,  0,  0,  1,  0,  1)
      forestModel:draw(-20,  .5,   8,    2,  0,  0,  1,  0,  1)
      forestModel:draw(-16,  .5,   12,   2,  0,  0,  1,  0,  1)
      forestModel:draw(-12,  .5,   16,   2,  2,  0,  1,  0,  1)
      forestModel:draw(-8,   .5,   20,   2,  2,  0,  1,  0,  1)
      forestModel:draw(-4,   .5,   24,   2,  0,  0,  1,  0,  1)
      forestModel:draw(-0,   .5,   28,   2,  3,  0,  1,  0,  1)
    end
  end

end

--- Calculate vertex normal from three corner vertices
local function get_triangle_normal(vert1, vert2, vert3)   
  return vec3.new(vert3.x - vert1.x, vert3.z - vert1.z, vert3.y - vert1.y)
    :cross(vec3.new(vert2.x - vert1.x, vert2.z - vert1.z, vert2.y - vert1.y))
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
      vec3.new(geom.vertices[a]),
      vec3.new(geom.vertices[b]),
      vec3.new(geom.vertices[c])
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



--- Loads asset data asynchronously. 
-- type should be "model-asset" or "texture-asset"
-- returns true if asynchronous loading started, or false if 
-- object was already loaded and callback called immediately
function GraphicsEng:_loadFromAsset(asset, type, callback)
  if asset._lovrObject then 
    callback(asset._lovrObject)
    return
  end
  if asset._lovrObjectLoadingCallbacks then
    table.insert(asset._lovrObjectLoadingCallbacks, callback)
    return
  end
  asset._lovrObjectLoadingCallbacks = {callback}

  local blob = lovr.data.newBlob(asset.data, asset:id())

  loader:load(
    type,
    asset:id(),
    function(object, status)
      local model
      if object == nil or status == false then
        print("Failed to load " .. type, asset:id(), object)
      else
        asset._lovrObject = object
      end
      for _, cb in ipairs(asset._lovrObjectLoadingCallbacks) do
        cb(asset._lovrObject)
      end
      asset._lovrObjectLoadingCallbacks = nil
    end,
    blob
  )
end

function GraphicsEng:modelFromAsset(asset, callback)
  if self:_loadFromAsset(asset, "model-asset", function (modelData)
    callback(lovr.graphics.newModel(modelData))
  end) then
    callback(self.hardcoded_models["loading"])
  end
end

function GraphicsEng:textureFromAsset(asset, callback)
  self:_loadFromAsset(asset, "texture-asset", function (textureData)
    callback(lovr.graphics.newTexture(textureData))
  end)
end

return GraphicsEng


