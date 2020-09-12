namespace("networkscene", "alloverse")

local json = require "json"
local array2d = require "pl.array2d"
local tablex = require "pl.tablex"
local pretty = require "pl.pretty"
local alloBasicShader = require "shader/alloBasicShader"
local alloPbrShader = require "shader/alloPbrShader"

local GraphicsEng = classNamed("GraphicsEng", Ent)
function GraphicsEng:_init()
  self:super()
end

function GraphicsEng:onLoad()
  self.hardcoded_models = {
    head = lovr.graphics.newModel('assets/models/head/female.glb'),
    lefthand = lovr.graphics.newModel('assets/models/left-hand/left-hand.glb'),
    righthand = lovr.graphics.newModel('assets/models/right-hand/right-hand.glb'),
    forest = lovr.graphics.newModel('/assets/models/decorations/forest/PUSHILIN_forest.gltf')
  }

  self.models_for_eids = {}
  
  self.basicShader = alloBasicShader
  self.pbrShader = alloPbrShader

  lovr.graphics.setBackgroundColor(.05, .05, .05)
  self.cloudSkybox = lovr.graphics.newTexture("assets/cloudy-sunset.png")

  local greenTex = lovr.graphics.newTexture("assets/textures/green.png", {})
  self.greenMat = lovr.graphics.newMaterial(greenTex, 1, 1, 1, 1)
end

function GraphicsEng:onDraw() 
  lovr.graphics.setShader()

  lovr.graphics.skybox(self.cloudSkybox)

  lovr.graphics.setShader(self.basicShader)

  lovr.graphics.setBackgroundColor(.3, .3, .40)
  lovr.graphics.setColor(1,1,1)
  
  lovr.graphics.setCullingEnabled(true)

  
  -- Draws plane & decorates it with trees
  self:drawDecorations()

  for eid, entity in pairs(self.client.state.entities) do
    local trans = entity.components.transform
    local mat = trans:getMatrix()
    local geom = entity.components.geometry
    local text = entity.components.text
    local parent = entity.components.relationships and entity.components.relationships.parent or nil
    local pose = entity.components.intent and entity.components.intent.actuate_pose or nil
    local model = self.models_for_eids[eid]

    lovr.graphics.push()
    lovr.graphics.transform(mat)
    if trans ~= nil and geom ~= nil and model ~= nil then
      -- don't draw our own head, as it obscures the camera
      if parent ~= self.client.avatar_id or pose ~= "head" then
        -- special case avatars to get PBR shading and face them towards negative Z
        if pose ~= nil then 
          lovr.graphics.rotate(3.14, 0, 1, 0)
          -- todo: set shader based on 'material' component instead of hard-coding for avatar
          lovr.graphics.setShader(self.pbrShader)
        else
          lovr.graphics.setShader(self.basicShader)
        end
        model:draw()
      end
    end
    lovr.graphics.pop()
  end

  for _, ray in ipairs(self.parent.engines.pose.handRays) do
    lovr.graphics.setColor(ray:getColor())
    lovr.graphics.line(ray.from, ray.to)
  end

  lovr.graphics.setColor({1,1,1})
end

function GraphicsEng:onUpdate(dt)
  if lovr.headset then 
    hx, hy, hz = lovr.headset.getPosition()
    self.basicShader:send('viewPos', { hx, hy, hz } )
    self.pbrShader:send('viewPos', { hx, hy, hz } )
  end
end

function GraphicsEng:loadComponentModel(component, old_component)
  local eid = component.getEntity().id

  if component.type == "hardcoded-model" then
    self.models_for_eids[eid] = self.hardcoded_models[component.name]
  elseif component.type == "inline" then 
    self.models_for_eids[eid] = self:createMesh(component, old_component)
  end

end

function GraphicsEng:onComponentAdded(component_key, component)
  if component_key ~= "geometry" then
    return
  end

  self:loadComponentModel(component, nil)
end

function GraphicsEng:onComponentChanged(component_key, component, old_component)
  if component_key ~= "geometry" then
    return
  end

  self:loadComponentModel(component, old_component)
end

function GraphicsEng:onComponentRemoved(component_key, component)
  if component_key ~= "geometry" then
    return
  end
  component.model = nil
end

function GraphicsEng:createMesh(geom, old_geom)
  local eid = geom.getEntity().id
  local mesh = self.models_for_eids[eid]
  if old_geom then
    --print("createMesh", tablex.deepcompare(geom.triangles, old_geom.triangles), tablex.deepcompare(geom.vertices, old_geom.vertices), tablex.deepcompare(geom.uvs, old_geom.uvs))
  end

  if mesh == nil or not tablex.deepcompare(geom.triangles, old_geom.triangles) or not tablex.deepcompare(geom.vertices, old_geom.vertices) or not tablex.deepcompare(geom.uvs, old_geom.uvs) then
    print("Creating new mesh from inline model data")
    -- convert the flattened zero-based indices list
    local z_indices = array2d.flatten(geom.triangles)
    -- convert to 1-based 
    local indices = tablex.map(function (x) return x + 1 end, z_indices)
    -- zip together verts, normals, and uv
    local combined = tablex.zip(
      geom.vertices, 
      -- geom.normals, 
      geom.uvs
    )
    -- flatten the inner tables
    local vertices = tablex.map(function (x) return array2d.flatten(x) end, combined)

    -- Setup the mesh
    mesh = lovr.graphics.newMesh({
      { 'lovrPosition', 'float', 3 },
      -- { 'lovrNormal', 'float', 3 },
      { 'lovrTexCoord', 'float', 2 }
    },
    vertices,
    'triangles', -- DrawMode
    'static', -- MeshUsage. dynamic, static, stream
    false -- do we need to read the data from the mesh later
    )

    mesh:setVertices(vertices)
    mesh:setVertexMap(indices)
  end

  if old_geom == nil or old_geom.texture ~= geom.texture then
    -- decode texture data and setup material
    local data = base64decode(geom.texture)
    local blob = lovr.data.newBlob(data, "texture")
    local texture = lovr.graphics.newTexture(blob)
    local material = lovr.graphics.newMaterial(texture)
    mesh:setMaterial(material)
  end

  return mesh
end

-- decoding
function base64decode(data)
  local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/' -- You will need this for encoding/decoding
  data = string.gsub(data, '[^'..b..'=]', '')
  return (data:gsub('.', function(x)
      if (x == '=') then return '' end
      local r,f='',(b:find(x)-1)
      for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
      return r;
  end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
      if (#x ~= 8) then return '' end
      local c=0
      for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
          return string.char(c)
  end))
end

function GraphicsEng:drawDecorations()
  -- "Floorplate"
  lovr.graphics.circle( 
    self.greenMat,
    0, 0, 0, -- x y z
    12,  -- radius
    -3.14/2, -- angle around axis of rotation
    1, 0, 0 -- rotation axis (x, y, z)
  )
  
  local forestModel = self.hardcoded_models.forest
  
  forestModel:draw(0, .5, -10, 2, 0, 0, 1, 0, 1)
  forestModel:draw(4, .5, -8, 2, 5, 0, 1, 0, 1)
  forestModel:draw(8, .5, -4, 2, 0, 0, 1, 0, 1)
  forestModel:draw(10, .5, 0, 2, 1, 0, 1, 0, 1)

  forestModel:draw(8, .5, 4, 2, 0, 0, 1, 0, 1)
  forestModel:draw(4, .5, 8, 2, 2, 0, 1, 0, 1)
  forestModel:draw(0, .5, 10, 2, 0, 0, 1, 0, 1)
  forestModel:draw(-4, .5, 8, 2, 3, 0, 1, 0, 1)

  forestModel:draw(-8, .5, 4, 2, 1, 0, 1, 0, 1)
  forestModel:draw(-10, .5, 0, 2,  3, 0, 1, 0, 1)
  forestModel:draw(-8, .5, -4, 2,  4, 0, 1, 0, 1)
  forestModel:draw(-4, .5, -8, 2,   0, 0, 1, 0, 1)

end

return GraphicsEng