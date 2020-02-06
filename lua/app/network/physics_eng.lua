namespace("networkscene", "alloverse")

local json = require "json"
local tablex = require "pl.tablex"
local Entity, componentClasses = unpack(require("app.network.entity"))
local PhysicsEng = classNamed("PhysicsEng", Ent)

function PhysicsEng:_init()
  self:super()
end

function PhysicsEng:onLoad()
  self.world = lovr.physics.newWorld()
end

function PhysicsEng:onUpdate(dt)
  

end

return PhysicsEng
