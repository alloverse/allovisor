--- The Allovisor Text engine
-- Draws text components
-- @classmod TextEng

namespace("networkscene", "alloverse")

local tablex = require "pl.tablex"
local letters = require("lib.letters.letters")

local TextEng = classNamed("TextEng", Ent)
function TextEng:_init()
  self:super()
end

function TextEng:onLoad()
  self:setActive(true)
  self.font = lovr.graphics.newFont(32)
end

function TextEng:setActive(newActive)
  if newActive then
    local poseEng = self.parent.engines.pose
    local headsetProxy = {}
    local mt = {
      -- inject self when used like `letters.headset.foobar(a, b, c)` (so it becomes basically
      -- `textEng:foobar(a, b, c)`)
      __index = function(t, key)
        if poseEng[key] == nil then return nil end
        return function(...)
          return poseEng[key](poseEng, ...)
        end
      end
    }
    setmetatable(headsetProxy, mt)
    letters.headset = headsetProxy
    letters.load()
  end
end

function TextEng:onUpdate()
  if self.client == nil then return end

  letters.update()
end

--- Draws all text components
function TextEng:onDraw() 
  lovr.graphics.setShader()
  self.font:setPixelDensity(32)
  lovr.graphics.setFont(self.font)
  for eid, entity in pairs(self.client.state.entities) do
    local text = entity.components.text
    if text ~= nil then
      local mat = self.parent.engines.graphics.materials_for_eids[eid]
      if mat then
        lovr.graphics.setColor(mat:getColor())
      else
        lovr.graphics.setColor(1,1,1,1)
      end
      lovr.graphics.push()
      lovr.graphics.transform(entity.components.transform:getMatrix())

      if text.halign == "left" and text.wrap then
        lovr.graphics.translate(-text.wrap/2,0,0)
      elseif text.halign == "right" and text.wrap then
        lovr.graphics.translate(text.wrap/2,0,0)
      end

      -- sets a dynamic text scale that fits within a width, if such parameter has been set
      local dynamicTextScale = 0
      if text.fitToWidth and text.fitToWidth ~= 0 then
        local textLabelWidth = lovr.graphics.getFont():getWidth(text.string)
        dynamicTextScale = (text.fitToWidth/textLabelWidth)

        -- arbitrary failsafe for the name tag heigh (so text doesn't get super tall if the name has a very low #letters
        if dynamicTextScale > 0.04 then
          dynamicTextScale = 0.04
        end
      else 
        dynamicTextScale = text.height and text.height or 1.0
      end

      local wrap = text.wrap and text.wrap / (text.height and text.height or 1) or 0
      lovr.graphics.print(
        text.string,
        0, 0, 0.01,
        dynamicTextScale, --text.height and text.height or 1.0, 
        0, 0, 0, 0,
        wrap,
        text.halign and text.halign or "center",
        text.valign and text.valign or "middle"
      )

      if text.insertionMarker then
        lovr.graphics.setColor(0, 0, 0, math.sin(lovr.timer.getTime()*5)*0.5 + 0.6)
        local actualLabelWidth, lines = lovr.graphics.getFont():getWidth(text.string, wrap)
        actualLabelWidth = actualLabelWidth * dynamicTextScale
        local lastLine = string.match(text.string, "[^%c]*$")
        local lastLineWidth = lovr.graphics.getFont():getWidth(lastLine) * dynamicTextScale
        local height = self.font:getHeight()*dynamicTextScale
        lovr.graphics.line(
          lastLineWidth + 0.01, height/2 - height*(lines-1), 0,
          lastLineWidth + 0.01, height/2 - height*lines, 0
        )
      end

      lovr.graphics.pop()
    end
  end

  lovr.graphics.push()
  lovr.graphics.transform(self.parent.inverseCameraTransform)
  if not lovr.headset then
    lovr.graphics.transform(self.parent.engines.pose:getPose("head"):invert())
  end
  letters.draw()

  lovr.graphics.pop()
end

function TextEng:onDebugDraw()
  letters.debugDraw()
end

function TextEng:onFocusChanged(newEnt, focusType)
  if focusType == "key" then
    self.firstResponder = newEnt
    if lovr.headset then
      letters.displayKeyboard()
    end
  else
    self.firstResponder = nil
    letters.hideKeyboard()
  end
  self.parent.engines.pose:useKeyboardForControllerEmulation(self.firstResponder == nil)
end

function TextEng:onKeyPress(code, scancode, repetition)
  if not self.firstResponder then return end

  if code == "escape" then
    return
  end

  self.client:sendInteraction({
    type = "one-way",
    receiver = self.firstResponder,
    body = {"keydown", code, scancode, repetition}
  })
end
function TextEng:onKeyReleased(code, scancode)
  if not self.firstResponder then return end

  self.client:sendInteraction({
    type = "one-way",
    receiver = self.firstResponder,
    body = {"keyup", code, scancode}
  })
end
function TextEng:onTextInput(text, code)
  if not self.firstResponder then return end

  self.client:sendInteraction({
    type = "one-way",
    receiver = self.firstResponder,
    body = {"textinput", text, code}
  })
end

return TextEng
