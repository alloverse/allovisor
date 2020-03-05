namespace("networkscene", "alloverse")

local json = require "json"
local Entity, componentClasses = unpack(require("app.network.entity"))
local array2d = require "pl.array2d"
local tablex = require "pl.tablex"
local pretty = require "pl.pretty"

local GraphicsEng = classNamed("GraphicsEng", Ent)
function GraphicsEng:_init()
  self:super()
end

function GraphicsEng:onLoad()
  self.models = {
	head = lovr.graphics.newModel('assets/models/mask/mask.glb'),
	lefthand = lovr.graphics.newModel('assets/models/left-hand/left-hand.glb'),
	righthand = lovr.graphics.newModel('assets/models/right-hand/right-hand.glb')
  }

  self.shader = lovr.graphics.newShader('standard', {
    flags = {
      normalTexture = false,
      indirectLighting = true,
      occlusion = true,
      emissive = true,
      skipTonemap = false
    }
  })

  self.factorySkybox = lovr.graphics.newTexture({
    left = 'assets/env/nx.png',
    right = 'assets/env/px.png',
    top = 'assets/env/py.png',
    bottom = 'assets/env/ny.png',
    back = 'assets/env/pz.png',
    front = 'assets/env/nz.png'
  }, { linear = true })
  self.cloudSkybox = lovr.graphics.newTexture("assets/cloudy-sunset.png")

  local logoTex = lovr.graphics.newTexture("assets/alloverse-logo.png", {})
  self.logoMat = lovr.graphics.newMaterial(logoTex, 1, 1, 1, 1)

  self.environmentMap = lovr.graphics.newTexture(256, 256, { type = 'cube' })
  for mipmap = 1, self.environmentMap:getMipmapCount() do
    for face, dir in ipairs({ 'px', 'nx', 'py', 'ny', 'pz', 'nz' }) do
      local filename = ('assets/env/m%d_%s.png'):format(mipmap - 1, dir)
      local image = lovr.data.newTextureData(filename, false)
      self.environmentMap:replacePixels(image, 0, 0, face, mipmap)
    end
  end


  self.shader:send('lovrLightDirection', { -1, -1, -1 })
  self.shader:send('lovrLightColor', { .9, .9, .8, 1.0 })
  self.shader:send('lovrExposure', 2)
  --self.shader:send('lovrSphericalHarmonics', require('assets/env/sphericalHarmonics'))
  self.shader:send('lovrEnvironmentMap', self.environmentMap)
end

function GraphicsEng:onDraw()  
  lovr.graphics.setShader()
  lovr.graphics.setColor(1,1,1)
  lovr.graphics.skybox(self.cloudSkybox)
  
  lovr.graphics.setBackgroundColor(.3, .3, .40)
  lovr.graphics.setCullingEnabled(true)
  lovr.graphics.setBlendMode()
  lovr.graphics.setColor({1,1,1})
  lovr.graphics.setShader(self.shader)

  -- Dummy floor until we have something proper
  lovr.graphics.plane( 
    self.logoMat,
    0, 0, 0, -- x y z
    6, 6,  -- w h
    -3.141593/2, 1, 0, 0,  -- rotation
    0, 0, 1, 1 -- u v tw th
  )

  for eid, entity in pairs(self.parent.state.entities) do
    local trans = entity.components.transform
    local geom = entity.components.geometry

    if trans ~= nil and geom ~= nil then
      local mat = trans:getMatrix()
      if geom.type == "hardcoded-model" then

        if geom.name == "lefthand" then
          local handPos = trans:getMatrix():mul(lovr.math.vec3())

          local distantPoint = trans:getMatrix():mul(lovr.math.vec3(0,0,-10))

          lovr.graphics.setColor({0.8,0.55,1})
          lovr.graphics.line(handPos, distantPoint)
          lovr.graphics.setColor({1,1,1})
        end
        
      end
      -- XXX: the bleep bloop seems to get a wonky mat
      geom.model:draw(mat)
    end
  end
end

function GraphicsEng:onUpdate(dt)

end

function GraphicsEng:onComponentAdded(component_key, component)
  if component_key ~= "geometry" then
    return
  end

  local entity = component:getEntity()

  if component.type == "hardcoded-model" then
    entity.components.geometry.model = self.models[component.name]
  elseif component.type == "inline" then 
    entity.components.geometry.model = createMesh(component)
  end

end

-- function GraphicsEng:onComponentRemoved(component_key, component)

-- end

function createMesh(geom)
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
  local mesh = lovr.graphics.newMesh({
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

  -- decode texture data and setup material
  local data = base64decode(geom.texture)
  local blob = lovr.data.newBlob(data, "texture")
  local texture = lovr.graphics.newTexture(blob)
  local material = lovr.graphics.newMaterial(texture)
  mesh:setMaterial(material)

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

return GraphicsEng