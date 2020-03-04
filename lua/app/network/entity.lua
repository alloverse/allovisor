namespace("networkscene", "alloverse")
local Entity = classNamed("Entity")
function Entity:getParent()
    local relationships = self.components.relationships
    if relationships ~= nil then
        return relationships:getParent()
    end
    return nil
end

-- Implemented as a field override in NetworkScene:onStateChanged
function Entity:getSibling(eid)
  return nil
end

local Component = classNamed("Component")

-- Implemented as a field override in NetworkScene:onStateChanged
function Component:getEntity()
  return nil
end

local TransformComponent = classNamed("TransformComponent", Component)
function TransformComponent:getMatrix()
    local parent = self:getEntity():getParent()
    local myMatrix = lovr.math.mat4(unpack(self.matrix))
    if parent ~= nil then
        return parent.components.transform:getMatrix():mul(myMatrix)
    else
        return myMatrix
    end
end

local RelationshipsComponent = classNamed("RelationshipsComponent", Component)
function RelationshipsComponent:getParent()
    if self.parent == nil or self.parent == "" then
        return nil
    end
    return self.getEntity():getSibling(self.parent)
end

local components = {
    transform = TransformComponent,
    relationships = RelationshipsComponent
}
-- default to plain Component
setmetatable(components, {__index = function () return Component end})

-- multiple return values doesn't work?? :/
return {Entity, components}