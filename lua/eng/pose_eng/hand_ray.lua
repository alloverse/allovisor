namespace("pose_eng", "alloverse")

local HandRay = classNamed("HandRay")
function HandRay:_init()
  self.isPointing = true
  self.highlightedEntity = nil
  self.selectedEntity = nil
  self.heldEntity = nil
  self.heldPoint = lovr.math.newVec3()
  self.from = lovr.math.newVec3()
  self.to = lovr.math.newVec3()
  self.hand = nil -- hand entity
  self.grabber_from_entity_transform = lovr.math.newMat4()
  self.rayLength = 1

  local cursorTexture = lovr.graphics.newTexture("assets/textures/cursor-default.png", {})
  self.cursorMaterial = lovr.graphics.newMaterial(cursorTexture)

  local resizeCursorTexture = lovr.graphics.newTexture("assets/textures/cursor-resize.png", {})
  self.resizeCursorMaterial = lovr.graphics.newMaterial(resizeCursorTexture)

end
function HandRay:highlightEntity(entity)
  if self.highlightedEntity ~= nil then
    --self.highlightedEntity.isHighlighted = false
  end
  self.highlightedEntity = entity
  if self.highlightedEntity ~= nil then
    --self.highlightedEntity.isHighlighted = true
  end
end
function HandRay:selectEntity(entity)
  if self.selectedEntity ~= nil then
    --self.selectedEntity.isSelected = false
  end
  self.selectedEntity = entity
  if self.selectedEntity ~= nil then
    --self.selectedEntity.isSelected = true
  end
end
function HandRay:getColor()
  if self.highlightedEntity ~= nil then
    return {0.91, 0.43, 0.29}
  else
    return {0.27,0.55,1}
  end
end

function HandRay:draw()
  if self.highlightedEntity then
    -- user is pointing at an interactive entity, draw highlight ray & cursor
    self:drawCursor()
    self:drawCone({1,1,0,1.0})
  else
    -- user is not pointing at anything, draw the default ray
    self:drawCone({0,1,1,1.0})
  end
end

function HandRay:drawCone(color)
  local coneCenter = self.from + ((self.to - self.from):normalize() * (self.rayLength/2))
  lovr.graphics.push()
  local mat = lovr.math.mat4():lookAt(coneCenter, self.to)
  lovr.graphics.transform(mat)
  
  lovr.graphics.setColor(color)
  lovr.graphics.setShader(alloPointerRayShader)

  lovr.graphics.cylinder(0, 0, 0, self.rayLength, 0, 0, 0, 0, 0.005, 0.008)
  lovr.graphics.pop()
end

function HandRay:drawCursor()
  lovr.graphics.setShader(alloBasicShader)
  local _, _, _, _, _, _, a, ax, ay, az = self.highlightedEntity.components.transform:getMatrix():unpack()

  lovr.graphics.push()
  lovr.graphics.translate(self.to)
  lovr.graphics.rotate(a, ax, ay, az)

  local cursor = self.highlightedEntity.components.cursor

  if cursor ~= nil then
    
    if cursor.name == "brushCursor" then
      local brushSize = self.highlightedEntity.components.cursor.size and self.highlightedEntity.components.cursor.size or 3
      lovr.graphics.circle("line", 0, 0, 0, brushSize/100)
    end

    if cursor.name == "resizeCursor" then
      lovr.graphics.plane(self.resizeCursorMaterial, 0, 0, 0.01, 0.2, 0.2, 0, 0, 0, 0, 0, 0)
    end

  else
    -- Display a default cursor
    lovr.graphics.plane(self.cursorMaterial, 0, 0, 0.01, 0.2, 0.2, 0, 0, 0, 0, 0, 0)
    --lovr.graphics.circle("line", 0, 0, 0, .03)
  end


  -- lovr.graphics.setColor(1.0, 1.0, 1.0, 1)
  -- lovr.graphics.circle("line", 0, 0, 0, 0.036)
  -- lovr.graphics.circle("line", 0, 0, 0, 0.039)
  -- lovr.graphics.circle("line", 0, 0, 0, 0.042)
  -- lovr.graphics.circle("line", 0, 0, 0, 0.045)
  -- lovr.graphics.setColor(1.0, 1.0, 1.0, 0.9)
  -- lovr.graphics.circle("line", 0, 0, 0, 0.048)
  -- lovr.graphics.setColor(1.0, 1.0, 1.0, 0.8)
  -- lovr.graphics.circle("line", 0, 0, 0, 0.051)
  -- lovr.graphics.setColor(1.0, 1.0, 1.0, 0.7)
  -- lovr.graphics.circle("line", 0, 0, 0, 0.054)
  -- lovr.graphics.setColor(1.0, 1.0, 1.0, 0.6)
  -- lovr.graphics.circle("line", 0, 0, 0, 0.057)
  -- lovr.graphics.setColor(1.0, 1.0, 1.0, 0.5)
  -- lovr.graphics.circle("line", 0, 0, 0, 0.060)
  -- lovr.graphics.setColor(1.0, 1.0, 1.0, 0.4)
  -- lovr.graphics.circle("line", 0, 0, 0, 0.063)
  -- lovr.graphics.setColor(1.0, 1.0, 1.0, 0.3)
  -- lovr.graphics.circle("line", 0, 0, 0, 0.066)
  -- lovr.graphics.setColor(1.0, 1.0, 1.0, 0.2)
  -- lovr.graphics.circle("line", 0, 0, 0, 0.069)
  -- lovr.graphics.setColor(1.0, 1.0, 1.0, 0.1)
  -- lovr.graphics.circle("line", 0, 0, 0, 0.072)

  lovr.graphics.pop()
end

return HandRay