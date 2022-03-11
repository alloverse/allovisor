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

function TextEng:onDie()
    letters.hideKeyboard()
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
