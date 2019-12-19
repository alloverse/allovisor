namespace("networkscene", "alloverse")

local json = require "json"
local Entity, componentClasses = unpack(require("app.network.entity"))

local NetworkScene = classNamed("NetworkScene", Ent)

--  If ran from lovr.app/lodr/testapp, liballonet.so is in project root
local success, allonet = pcall(require, "liballonet")
if success == false then
  print("No liballonet, trying in lovr binary as if we're on a Mac...")
  local pkg = package.loadlib("lovr", "luaopen_liballonet")
  if pkg == nil then
    print("No allonet in lovr, trying in liblovr.so as if we're on Android...")
    pkg = package.loadlib("liblovr.so", "luaopen_liballonet")

	if pkg == nil then
	  print("No liblovr.so, trying in allonet.dll as if we're on Windows...")
	  pkg = package.loadlib("allonet.dll", "luaopen_liballonet")
	end
  end
  if pkg == nil then
    error("Allonet missing. Giving up.")
  end
  allonet = pkg()
  print("allonet loaded")
end


function NetworkScene:_init(displayName, url)
  self.client = allonet.connect(
    url,
    json.encode({display_name = displayName}),
    json.encode({
      children = {
        {
          geometry = {
            type = "hardcoded-model",
            name = "lefthand"
          },
          intent = {
            actuate_pose = "hand/left"
          }
        },
        {
          geometry = {
            type = "hardcoded-model",
            name = "righthand"
          },
          intent = {
            actuate_pose = "hand/right"
          }
        },
        {
          geometry = {
            type = "hardcoded-model",
            name = "head"
          },
          intent = {
            actuate_pose = "head"
          }
        }
      }
    })
  )
  self.state = {
    entities = {}
  }
  self.client:set_state_callback(function() self:onStateChanged() end)
  self.client:set_disconnected_callback(function() self:onDisconnect() end)
  self.yaw = 0.0
  
  self:super()
end

function NetworkScene:onStateChanged()
  local state = self.client:get_state()
  -- Make Entities and their Components classes so they get convenience methods from entity.lua
  local getSibling = function(id) return state.entities[id] end

  for eid, entity in pairs(state.entities) do
    setmetatable(entity, Entity)
    entity.getSibling = getSibling
    local getEntity = function() return entity end
    for cname, cval in pairs(entity.components) do
      local klass = componentClasses[cname]
      setmetatable(cval, klass)
      cval.getEntity = getEntity
    end
  end
  self.state = state
end

function NetworkScene:onLoad()
  --world = lovr.physics.newWorld()
  self.models = {
	head = lovr.graphics.newModel('assets/models/mask.glb'),
	lefthand = lovr.graphics.newModel('assets/models/left-hand/LeftHand.gltf', 'assets/models/test-texture.png'),
	righthand = lovr.graphics.newModel('assets/models/right-hand/RightHand.gltf', 'assets/models/test-texture.png')
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

  self.skybox = lovr.graphics.newTexture({
    left = 'assets/env/nx.png',
    right = 'assets/env/px.png',
    top = 'assets/env/py.png',
    bottom = 'assets/env/ny.png',
    back = 'assets/env/pz.png',
    front = 'assets/env/nz.png'
  }, { linear = true })

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

function NetworkScene:onDisconnect()
  print("disconnecting...")
  self.client:disconnect(0)
  scene:insert(lovr.scenes.menu)
  queueDoom(self)
end

function NetworkScene:onDraw()  
  lovr.graphics.skybox(self.skybox)
  
  lovr.graphics.setBackgroundColor(.3, .3, .40)
  lovr.graphics.setCullingEnabled(true)
  lovr.graphics.setBlendMode()
  lovr.graphics.setColor({1,1,1})
  lovr.graphics.setShader(self.shader)

  for eid, entity in pairs(self.state.entities) do
    local trans = entity.components.transform
    local geom = entity.components.geometry

    if trans ~= nil and geom ~= nil then
      local mat = trans:getMatrix()
      if geom.type == "hardcoded-model" then
        if geom.name == "head" then
            mat:scale(0.35, 0.35, 0.35)
        end
        self.models[geom.name]:draw(mat)
      elseif geom.type == "inline" then
          
      end
    end
  end
end

function pose2matrix(x, y, z, angle, ax, ay, az)
  local mat = lovr.math.mat4()
  mat:translate(x, y, z)
  mat:rotate(angle, ax, ay, az)
  return mat
end

function NetworkScene:onUpdate(dt)
  local mx, my = lovr.headset.getAxis("hand/left", "thumbstick")
  local tx, ty = lovr.headset.getAxis("hand/right", "thumbstick")
  self.yaw = self.yaw - (tx/30.0)
  local intent = {
    xmovement = mx,
    zmovement = -my,
    yaw = self.yaw,
    pitch = 0.0,
    poses = {}
  }
  for i, device in ipairs({"head", "hand/left", "hand/right"}) do
    intent.poses[device] = {
      matrix = pose2matrix(lovr.headset.getPose(device))
    }
  end
  
  self.client:set_intent(intent)
  self.client:poll()
end

lovr.scenes.network = NetworkScene

return NetworkScene