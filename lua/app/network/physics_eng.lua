namespace("networkscene", "alloverse")

local json = require "json"
local tablex = require "pl.tablex"
local Entity, componentClasses = unpack(require("app.network.entity"))
local PhysicsEng = classNamed("PhysicsEng", Ent)

function PhysicsEng:_init()
  self:super()

  self.colliders = {} -- [entity_id] = collider
end

function PhysicsEng:onLoad()
  self.world = lovr.physics.newWorld()
end

function PhysicsEng:onUpdate(dt)
  
  for eid, collider in pairs(self.colliders) do
    local entity = collider:getUserData()
    local matrix = entity.components.transform:getMatrix()

    local position = matrix:mul(lovr.math.vec3())
    -- todo: rotation
    collider:setPosition(position:unpack())
  end

end

function PhysicsEng:onDraw()
  if self.parent.debug == false then
    return
  end

  lovr.graphics.setShader()
  for eid, collider in pairs(self.colliders) do
    local entity = collider:getUserData()
    local x, y, z = collider:getPosition()
    local boxShape = collider:getShapes()[1]
    local w, h, d = boxShape:getDimensions()
    -- todo: rotation

    if entity == self.parent.pose.pokedEntity then
      lovr.graphics.setColor(1.0, 0.2, 0.2, 1)
    elseif self.parent.pose.hoveredEntity then
      lovr.graphics.setColor(1.0, 0.5, 1.0, 1)
    else
      lovr.graphics.setColor(0.5, 0.5, 1.0, 1)
    end

    lovr.graphics.box("line",
      x, y, z,
      w, h, d,
      0, 0, 1, 0 -- rot
    )
  end
end

function PhysicsEng:onComponentAdded(component_key, component)
  if component_key ~= "collider" then
    return
  end

  local collider = self.world:newBoxCollider(0, 0, 0, component.width, component.height, component.depth)
  local entity = component:getEntity()

  entity.collider = collider
  collider:setUserData(entity)

  self.colliders[entity.id] = collider
end

function PhysicsEng:onComponentRemoved(component_key, component)

  if component_key ~= "collider" then
    return
  end

  local eid = component.getEntity().id
  local collider = self.colliders[eid]

  self.colliders[eid] = nil
  collider:setUserData(nil)
  collider:destroy()  
end


return PhysicsEng
