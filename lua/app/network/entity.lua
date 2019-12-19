namespace("networkscene", "alloverse")
local Entity = classNamed("Entity")

local Component = classNamed("Component")

local TransformComponent = classNamed("TransformComponent", Component)

function TransformComponent:getParent()
    if self.parent == nil or self.parent == "" then
        return nil
    end
    return self.getEntity():getSibling(self.parent).components.transform
end

function TransformComponent:getMatrix()
    local parent = self:getParent()
    local myMatrix = lovr.math.mat4(unpack(self.matrix))
    if parent ~= nil then
        return myMatrix:mul(parent:getMatrix())
    else
        return myMatrix
    end
end

local components = {
    transform = TransformComponent
}
-- default to plain Component
setmetatable(components, {__index = function () return Component end})

-- multiple return values doesn't work?? :/
return {Entity, components}