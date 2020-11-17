--- The Allovisor physics engine
-- @classmod PhysicsEng

namespace("networkscene", "alloverse")

local tablex = require "pl.tablex"
local pretty = require "pl.pretty"
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

    local x, y, z, sx, sy, sz, a, ax, ay, az = matrix:unpack()
    if x ~= x or a ~= a or ax ~= ax then
      print("HOOPS broken matrix", pretty.write({matrix:unpack(true)}))
    else
      collider:setPose(x, y, z, a, ax, ay, az)
    end
  end

end

function PhysicsEng:onDraw()
  if self.parent.debug == false then
    return
  end

  lovr.graphics.setShader()
  for eid, collider in pairs(self.colliders) do
    local entity = collider:getUserData()
    local x, y, z, a, ax, ay, az = collider:getPose()
    local boxShape = collider:getShapes()[1]
    local w, h, d = boxShape:getDimensions()

    if entity == self.parent.engines.pose.pokedEntity then
      lovr.graphics.setColor(1.0, 0.2, 0.2, 1)
    elseif self.parent.engines.pose.hoveredEntity then
      lovr.graphics.setColor(1.0, 0.5, 1.0, 1)
    else
      lovr.graphics.setColor(0.5, 0.5, 1.0, 1)
    end

    lovr.graphics.box("line",
      x, y, z,
      w, h, d,
      a, ax, ay, az
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

function PhysicsEng:onComponentChanged(component_key, component, old_component)
  if component_key ~= "collider" then
    return
  end

  local eid = component.getEntity().id
  local collider = self.colliders[eid]

  local boxShape = collider:getShapes()[1]
  boxShape:setDimensions(component.width, component.height, component.depth)

end

function PhysicsEng:onDisconnect()
  for eid, collider in pairs(self.colliders) do
    collider:setUserData(nil)
    collider:destroy()  
  end
  self.colliders = {}
end


return PhysicsEng
