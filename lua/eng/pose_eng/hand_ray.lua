namespace("pose_eng", "alloverse")

local HandRay = classNamed("HandRay")
function HandRay:_init(device)
  self.isPointing = true
  self.highlightedEntity = nil
  self.selectedEntity = nil
  self.heldEntity = nil
  self.handEntity = nil
  self.heldPoint = lovr.math.newVec3()
  self.from = lovr.math.newVec3()
  self.to = lovr.math.newVec3()
  self.hand = nil -- hand entity
  self.grabber_from_entity_transform = lovr.math.newMat4()
  self.rayLength = 0.8
  self.device = device

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

function HandRay:draw()
  if not self.isPointing then return end
  lovr.graphics.push()
  if self.highlightedEntity then
    
    -- draw the UI scaled down if it's very near the hand, or it'll cover what we're highlighting
    local distance = (self.to - self.from):length()
    local scale = utils.clamp(distance, 0.1, 1)
    lovr.graphics.transform(self.to)
    lovr.graphics.scale(scale, scale, scale)
    lovr.graphics.transform(lovr.math.mat4(self.to):invert())

    -- user is pointing at an interactive entity, draw highlight ray & cursor
    self:drawCursor()
    self:drawCone({1, 1, 1, 0.6})
  else
    -- user is not pointing at anything, draw the default ray
    self:drawCone({1, 1, 1, 0.1})
  end
  lovr.graphics.pop()
end

function HandRay:drawCone(color)
  local coneCenter = self.from + ((self.to - self.from):normalize() * (self.rayLength/2))
  lovr.graphics.push()
  local mat = lovr.math.mat4():target(coneCenter, self.to)
  lovr.graphics.transform(mat)
  
  lovr.graphics.setColor(color)
  lovr.graphics.setShader(alloPointerRayShader)

  lovr.graphics.cylinder(0, 0, 0, self.rayLength, 0, 0, 0, 0, 0.005, 0.005)
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
    --lovr.graphics.plane(self.cursorMaterial, 0, 0, 0.01, 0.2, 0.2, 0, 0, 0, 0, 0, 0)
    
    lovr.graphics.setColor(1, 1, 1, 0.2)
    --lovr.graphics.circle("fill", 0, 0, 0, .02)
    lovr.graphics.sphere(0, 0, 0, .02)
    -- lovr.graphics.setColor(1, 1, 1, 1)
    -- lovr.graphics.circle("line", 0, 0, 0, .02)

  end

  lovr.graphics.pop()
end

return HandRay
