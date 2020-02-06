namespace("networkscene", "alloverse")

local json = require "json"
local tablex = require "pl.tablex"
local Entity, componentClasses = unpack(require("app.network.entity"))
local PhysicsEng = classNamed("PhysicsEng", Ent)

function PhysicsEng:_init()
  self:super()

  self.colliders = {}
end

function PhysicsEng:onLoad()
  self.world = lovr.physics.newWorld()
end

function PhysicsEng:onUpdate(dt)
  
  for i, collider in ipairs(self.colliders) do
    local entity = collider.entity
    local matrix = entity.components.transform:getMatrix()

    local position = matrix:mul(lovr.math.vec3())

    collider:setPosition(position:unpack())
  end

end

function PhysicsEng:onComponentAdded(component_key, component)
  
  if component_key ~= "collider" then
    return
  end

  local collider = self.world:newBoxCollider(0, 0, 0, component.width, component.height, component.depth)

  local entity = component:getEntity()

  entity.collider = collider
  collider.entity = entity

  table.insert(self.colliders, collider)

end


return PhysicsEng
