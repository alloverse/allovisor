namespace("networkscene", "alloverse")

local json = require "json"
local allonet = require "liballonet"

local NetworkScene = classNamed("NetworkScene", Ent)

local client = allonet.connect(
    "alloplace://nevyn.places.alloverse.com",
    json.encode({display_name = "lua-sample"}),
    json.encode({a = "b"})
)

function NetworkScene:onLoad()
  --world = lovr.physics.newWorld()
  
end

function NetworkScene:onDraw()
  -- iterera igenom client.get_state().entities
  -- rita ut varje entity som en kub
end


function NetworkScene:onUpdate(dt)
  client:poll()
end

return NetworkScene