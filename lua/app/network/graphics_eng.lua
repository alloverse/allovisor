namespace("networkscene", "alloverse")

local json = require "json"
local Entity, componentClasses = unpack(require("app.network.entity"))
local array2d = require "pl.array2d"
local tablex = require "pl.tablex"

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
  self.cloudSkybox = lovr.graphics.newTexture("assets/cloudy-skybox.jpg")

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
        
        self.models[geom.name]:draw(mat)
      elseif geom.type == "inline" then
        -- Flatten the 2d arrays
        local verts = array2d.flatten(geom.vertices)
        local indices = array2d.flatten(geom.triangles)
        -- map indices to coordinates
        local tris = tablex.map(function (i) return {verts[i + 1], verts[i + 2], verts[i + 3]} end, indices)
        local data = array2d.flatten(tris)
        -- Draw in a nice color
        lovr.graphics.setColor(1, 0, 0)
        lovr.graphics.triangle('fill', unpack(data))
      end
    end
  end
end

function GraphicsEng:onUpdate(dt)

end

return GraphicsEng
