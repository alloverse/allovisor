namespace("networkscene", "alloverse")

local json = require "json"

local NetworkScene = classNamed("NetworkScene", Ent)

--  If ran from lovr.app/lodr/testapp, liballonet.so is in project root
local success, allonet = pcall(require, "liballonet")
if success == false then
  -- If ran from mac, allonet.a is linked into lovr exe
  local pkg = package.loadlib("lovr", "luaopen_liballonet")
  if pkg == nil then
    -- if ran from android, liblovr.so contains allonet.a
    pkg = package.loadlib("liblovr.so", "luaopen_liballonet")
  end
  if pkg == nil then
    error("Allonet missing from so, lovr and liblovr. Giving up.")
  end
  allonet = pkg()
end


function NetworkScene:_init(displayName, url)
  self.client = allonet.connect(
    url,
    json.encode({display_name = displayName}),
    json.encode({geometry = {
      type = "hardcoded-model"
    }})
  )
  self.yaw = 0.0
  self:super()
end

function NetworkScene:onLoad()
  --world = lovr.physics.newWorld()
  self.skybox = lovr.graphics.newTexture('assets/cloudy-skybox.jpg')  
end


function NetworkScene:onDraw()  
  lovr.graphics.setColor({1,1,1})
  lovr.graphics.skybox(self.skybox)
  -- iterera igenom client.get_state().entities
  -- rita ut varje entity som en kub

  for _, entity in ipairs(self.client:get_state().entities) do

    local trans = entity.components.transform
    local geom = entity.components.geometry

    if trans ~= nil and geom ~= nil then
      if geom.type == "hardcoded-model" then
        lovr.graphics.setColor(0, 0, 0)
        lovr.graphics.cube('fill', trans.position.x, trans.position.y, trans.position.z, 1, 0, 0, 0, 0)
      elseif geom.type == "inline" then
        
      end
    end
  end

end


function NetworkScene:onUpdate(dt)
  local mx, my = lovr.headset.getAxis("hand/left", "thumbstick")
  local tx, ty = lovr.headset.getAxis("hand/right", "thumbstick")
  self.yaw = self.yaw - (tx/30.0)
  local intent = {
    xmovement = mx,
    zmovement = -my,
    yaw = self.yaw,
    pitch = 0.0
  }
  self.client:set_intent(intent)
  self.client:poll()
end

return NetworkScene