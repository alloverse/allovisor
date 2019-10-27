namespace("networkscene", "alloverse")

local json = require "json"
local allonet = require "liballonet"

local NetworkScene = classNamed("NetworkScene", Ent)

local client = nil

function NetworkScene:_init(displayName, url)
  client = allonet.connect(
    url,
    json.encode({display_name = displayName}),
    json.encode({a = "b"}))
end

function NetworkScene:onLoad()
  --world = lovr.physics.newWorld()
  
end

function NetworkScene:onDraw()

  -- iterera igenom client.get_state().entities
  -- rita ut varje entity som en kub

  for _, entity in ipairs(client:get_state().entities) do

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
  client:poll()
end

return NetworkScene