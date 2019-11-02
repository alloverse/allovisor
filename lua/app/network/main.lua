namespace("networkscene", "alloverse")

local json = require "json"

local NetworkScene = classNamed("NetworkScene", Ent)

--  If ran from lovr.app/lodr/testapp, liballonet.so is in project root
require("liballonet")
local success, allonet = pcall(require, "liballonet")
if success == false then
  -- If ran from mac, allonet.a is linked into lovr exe
  local pkg = package.loadlib("lovr", "luaopen_liballonet")
  if pkg == nil then
    -- if ran from android, liblovr.so contains allonet.a
    pkg = package.loadlib("liblovr.so", "luaopen_liballonet")
  end
  allonet = pkg()
end


function NetworkScene:_init(displayName, url)
  self.client = allonet.connect(
    url,
    json.encode({display_name = displayName}),
    json.encode({a = "b"})
  )
  self:super()
end

function NetworkScene:onLoad()
  --world = lovr.physics.newWorld()
  self.skybox = lovr.graphics.newTexture('assets/cloudy-skybox.jpg')  
end


function NetworkScene:onDraw()  
  lovr.graphics.skybox(self.skybox)
  -- iterera igenom client.get_state().entities
  -- rita ut varje entity som en kub

  for _, entity in ipairs(self.client:get_state().entities) do

    print("entity.id: " .. entity.id)

    local entityTransform = entity.components.transform

    if (entityTransform ~= nil) then
      print(entityTransform.position.x)
      lovr.graphics.setColor(0, 0, 0)
      lovr.graphics.cube('fill', entityTransform.position.x, entityTransform.position.y, entityTransform.position.z, 1, 0, 0, 0, 0)
    end
  end

end


function NetworkScene:onUpdate(dt)
  self.client:poll()
end

return NetworkScene