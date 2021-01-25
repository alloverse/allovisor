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

local GraphicsEng = classNamed("GraphicsEng", Ent)

--- Initialize the graphics engine.
function GraphicsEng:_init()
  self:super()
end

--- Called when the application loadsio.
-- Loads the default models, shaders, etc. 
function GraphicsEng:onLoad()
  self.hardcoded_models = {
    broken = lovr.graphics.newModel('/assets/models/broken.glb'),
    loading = lovr.graphics.newModel('/assets/models/broken.glb'),
  }
  self:loadHardcodedModel('forest', function() end, '/assets/models/decorations/forest/PUSHILIN_forest.gltf')

  self.models_for_eids = {}
  self.materials_for_eids = {}
  self.shaders_for_eids = {}
  self.textures_from_assets = {}
  self.loading_assets = {}
  
  self.basicShader = alloBasicShader
  self.pbrShader = alloPbrShader

  local allonet = self.parent.client.client
  allonet:set_asset_receive_callback(function (name, data, offset, total_size)
    local asset = self.loading_assets[name]
    if asset == nil then
      print("Not expecting asset", name)
      return
    end
    print("Appending " .. string.len(data) .. " bytes to asset " .. name)
    print("Did offset match? " .. string.len(asset.data) .. " vs " .. offset-1)
    asset.data = asset.data .. data
  end)

  allonet:set_asset_state_callback(function (name, state)
    if state == 0 then
      print("Asset " .. name .. " is complete")
      local asset = self.loading_assets[name]

      if asset == nil then
        print("Not expecting asset", name)
      end

      asset.whenDone(asset.data)

      self.loading_assets[name] = nil
    else
      print("Could not fetch asset " .. name .. " (" .. state ")")
    end
  end)

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

  self.houseAssets = {}
  local houseAssetNames = lovr.filesystem.getDirectoryItems("assets/models/house")
  for i, name in ipairs(houseAssetNames) do
    self:loadHardcodedModel('house/'..name, function(m) 
      self.houseAssets[name] = m 
    end)
  end
end

function GraphicsEng:request_asset(name, whenDone)
  local allonet = self.parent.client.client
  local asset = self.loading_assets[name]

  if asset == nil then
    asset = {
      name = name,
      whenDone = whenDone,
      data = ""
    }
  else
    local next = asset.whenDone
    asset.whenDone = function (data)
      next(data)
      whenDone(data)
    end
  end
  self.loading_assets[name] = asset
  allonet:asset_request(name)
end
--- Called each frame to draw the world
-- Called by Ent
-- @see Ent
function GraphicsEng:onDraw() 
  lovr.graphics.setCullingEnabled(true)
  lovr.graphics.setColor(1,1,1,1)

  local head = self.parent:getHead()
  if head then
    local hm = head.components.transform:getMatrix()
    self.basicShader:send('viewPos', hm * lovr.math.vec3() )
    
    -- todo: use setViewPose instead so light direction is in world coordinates properly
    -- https://app.clubhouse.io/alloverse/story/2031/use-setviewpose-instead-of-transform
    local cameraQuat = lovr.math.quat(self.parent.cameraTransform)
    local lightDirection = lovr.math.vec3(0.7,-0.8,-0.5)
    local compensatedLightDirection = cameraQuat * lightDirection
    self.pbrShader:send('lovrLightDirection', compensatedLightDirection)
  end
  
  if not self.parent.isOverlayScene then
    lovr.graphics.setBackgroundColor(.3, .3, .40)
    lovr.graphics.setShader()
    lovr.graphics.skybox(self.cloudSkybox)
    self:drawDecorations()
  else
    self:drawOutlines()
  end

  lovr.graphics.setColor(1,1,1)

  for eid, entity in pairs(self.client.state.entities) do
    lovr.graphics.push()
    lovr.graphics.transform(entity.components.transform:getMatrix())
    self:_drawEntity(entity, true)
    lovr.graphics.pop()
  end

  lovr.graphics.setColor({1,1,1})
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

    local shader = self.shaders_for_eids[entity.id]
    if shader == nil then shader = self.basicShader end
    lovr.graphics.setShader(shader)
  end

  if model.animate and model:getAnimationCount() > 0 then
    model:animate("autoplay", lovr.timer.getTime())
  end
  model:draw()
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
    self:loadAssetModel(component.name, function(model)
      self.models_for_eids[eid] = model
    end)
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

function GraphicsEng:loadAssetModel(name, callback)
  if self.hardcoded_models[name] ~= nil then 
    callback(self.hardcoded_models[name])
    return
  end

  callback(self.hardcoded_models["loading"])
  self:request_asset(name, function (data)
    if data == nil then 
      print("Asset data is nil; asset " .. name .. " was not found on network")
      callback(self.hardcoded_models["broken"])
    else 
      print("Completed loading asset " .. name)
      local blob = lovr.data.newBlob(data, name)
      local model = lovr.graphics.newModel(blob)
      self.hardcoded_models[name] = model;
      callback(model)
    end
  end)
end

--- Loads a material for supplied component.
-- @tparam component component The component to load a material for
-- @tparam component old_component not used
function GraphicsEng:loadAssetModel(name, callback)
  if self.hardcoded_models[name] ~= nil then 
    callback(self.hardcoded_models[name])
    return
  end

  callback(self.hardcoded_models["loading"])
  self:request_asset(name, function (data)
    if data == nil then 
      print("Asset data is nil; asset " .. name .. " was not found on network")
      callback(self.hardcoded_models["broken"])
    else 
      print("Completed loading asset " .. name)
      local blob = lovr.data.newBlob(data, name)
      local model = lovr.graphics.newModel(blob)
      self.hardcoded_models[name] = model;
      callback(model)
    end
  end)
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
  if component.shader_name == "plain" then
    self.shaders_for_eids[eid] = self.basicShader
  elseif component.shader_name == "pbr" then
    self.shaders_for_eids[eid] = self.pbrShader
  end

  local apply = function()
    self.materials_for_eids[eid] = mat
    -- apply the material to matching mesh, if loaded
    local mesh = self.models_for_eids[eid]
    if mesh and mesh.setMaterial then
      mesh:setMaterial(mat)
    end
  end
  
  if component.texture ~= nil then
    local texture = self:loadTexture(eid, component.texture, function(tex)
      mat:setTexture(tex)
      apply()
    end)
  elseif component.asset_texture ~= nil then
    local name = component.asset_texture
    local tex = self.textures_from_assets[name]
    if tex == nil then
      self:request_asset(name, function (data)
        local blob = lovr.data.newBlob(data, "texture")
        local texture = lovr.graphics.newTexture(blob)
        self.textures_from_assets[name] = texture
        mat:setTexture(texture)
      end)
    else
      mat:setTexture(tex)
    end
    apply()
  else
    apply()
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
    self.shaders_for_eids[eid] = nil
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
    
    local forestModel = self.hardcoded_models.forest
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

  lovr.graphics.setShader(self.pbrShader)
  for name, model in pairs(self.houseAssets) do
    if model.animate and model:getAnimationCount() > 0 then
      model:animate(1, lovr.timer.getTime())
    end
    model:draw()
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

return GraphicsEng
