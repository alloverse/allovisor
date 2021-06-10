namespace("pose_eng", "alloverse")

local ok, keyboardmod = pcall(require, "lib.lovr-keyboard")
if not ok then
  print("No keyboard available", keyboard)
  keyboardmod = nil
end

function PoseEng:useKeyboardForControllerEmulation(emulateControllers)
  if emulateControllers then
    self.keyboard = keyboardmod
  else
    self.keyboard = nil
  end
end

function PoseEng:isKeyboardButtonPressed(key)
  if self.fakeKeyboardEvents[key] then
    return self.fakeKeyboardEvents[key]
  end
  if self.keyboard then
    return self.keyboard.isDown(key)
  end
  return false
end

function PoseEng:onFakeKeyboardEvent(key, down)
  self.fakeKeyboardEvents[key] = down and down or nil
end


-------------
-- goes through all the buttons on the controllers and stores
-- state for them, so we can diff button states between frames
function PoseEng:updateButtons(dt)
  self.previousButtonStates = self.currentButtonStates
  self.currentButtonStates = {["hand/left"]={}, ["hand/right"]={}}
  for handIndex, hand in ipairs(PoseEng.hands) do
    for _, button in ipairs(PoseEng.buttons) do
      self:updateButton(hand, button)
    end
  end
  self:updateSimulatedSticks(dt)
end

function PoseEng:routeButtonEvents()
  if not self.previousButtonStates then return end
  for handIndex, hand in ipairs(PoseEng.hands) do
    local ray = self.handRays[handIndex]
    for _, button in ipairs(PoseEng.buttons) do
      if not self.previousButtonStates[hand][button] and self.currentButtonStates[hand][button] then
        self:_buttonPressed(ray.handEntity, hand, button)
      end
      if self.previousButtonStates[hand][button] and not self.currentButtonStates[hand][button] then
        self:_buttonReleased(ray.handEntity, hand, button)
      end
    end
  end
end

function PoseEng:routeAxisEvents()
  for handIndex, hand in ipairs(PoseEng.hands) do
    local ray = self.handRays[handIndex]
    for _, axis in ipairs(PoseEng.axis) do
      local capturer = self.capturedControls[hand..axis]
      if capturer then
        self.client:sendInteraction({
          type = "one-way",
          sender = ray.handEntity,
          receiver = capturer,
          body = {"captured_axis", hand, axis, {self:getAxis(hand, axis, true)}}
        })
      end
    end
  end
end

function PoseEng:_buttonPressed(handEntity, hand, button)
  local capturer = self.capturedControls[hand..button]
  if capturer then
    self.client:sendInteraction({
      type = "one-way",
      sender = handEntity,
      receiver = capturer,
      body = {"captured_button_pressed", hand, button}
    })
  else
    self.parent:route("onButtonPressed", hand, button)
  end
end

function PoseEng:_buttonReleased(handEntity, hand, button)
  local capturer = self.capturedControls[hand..button]
  if capturer then
    self.client:sendInteraction({
      type = "one-way",
      sender = handEntity,
      receiver = capturer,
      body = {"captured_button_released", hand, button}
    })
  else
    self.parent:route("onButtonReleased", hand, button)
  end
end

------
-- See PoseEng:updateButtons. This updates the stored state
-- for a single button on a single controller.
--  * If lovr.headset is available, the controller hardware button is checked.
--  * If keyboard is available, also check for a key on the keyboard
--    that maps to this controller key.
function PoseEng:updateButton(device, button)
  local down = false
  if lovr.headset then
    down = down or lovr.headset.isDown(device, button)
  end
  if device == "hand/left" and button == "trigger" then
    down = down or (self.mouseIsDown and self.mouseMode == "interact")
  elseif device == "hand/left" and button == "grip" then
    down = down or self:getAxis(device, button) > 0.5
  elseif button == "menu" and device == "hand/left" and self.keyboard then
    down = down or self:isKeyboardButtonPressed("escape")
  elseif button == "x" and device == "hand/left" and self.keyboard then
    down = down or self:isKeyboardButtonPressed("lshift") or self:isKeyboardButtonPressed("rshift")
  end
  self.currentButtonStates[device][button] = down
end

function PoseEng:isTouched(device, button)
  if self.parent.active == false then return false end
  local down = false
  if lovr.headset then
    down = down or lovr.headset.isTouched(device, button)
  end
  return down
end

function PoseEng:isDown(device, button)
  if self.parent.active == false then return false end
  if not self.currentButtonStates then return false end
  if self.capturedControls[device..button] then return false end
  return self.currentButtonStates[device][button]
end

function PoseEng:wasPressed(device, button)
  if self.parent.active == false then return false end
  if not self.currentButtonStates then return false end
  if self.capturedControls[device..button] then return false end
  local was = self.previousButtonStates and self.previousButtonStates[device][button] or false
  return not was and self:isDown(device, button)
end

function PoseEng:wasReleased(device, button)
  if self.parent.active == false then return false end
  if not self.currentButtonStates then return false end
  if self.capturedControls[device..button] then return false end
  local was = self.previousButtonStates and self.previousButtonStates[device][button] or false
  return was and not self:isDown(device, button)
end

function PoseEng:updateSimulatedSticks(dt)
  if not self.keyboard then return end
  if not self.keyboardLeftStick then self.keyboardLeftStick = lovr.math.newVec2() end

  local stickSpeed = 1.0
  local lerpAmount = 8
  if self.parent.isSpectatorCamera then
    stickSpeed = 0.4
    lerpAmount = 4
  end
  
  local xDest = self:isKeyboardButtonPressed("d") and stickSpeed or (self:isKeyboardButtonPressed("a") and -stickSpeed or 0)
  local yDest = self:isKeyboardButtonPressed("w") and stickSpeed or (self:isKeyboardButtonPressed("s") and -stickSpeed or 0)
  local dest = lovr.math.vec2(xDest, yDest)
  self.keyboardLeftStick:lerp(dest, dt*lerpAmount)
  if math.abs(self.keyboardLeftStick.x) + math.abs(self.keyboardLeftStick.y) < 0.01 then
    self.keyboardLeftStick:set(0,0)
  end
end

-------
-- If a controller is available, use the input from it.
-- If a keyboard is available, also use that input to emulate
-- the left hand's stick.
function PoseEng:getAxis(device, axis, evenIfOverridden)
  if self.parent.active == false then return 0.0, 0.0 end
  if self.capturedControls[device..axis] and not evenIfOverridden then return 0.0, 0.0 end

  local x, y = 0, 0
  if lovr.headset then
    x, y = lovr.headset.getAxis(device, axis)
  end
  if self.keyboard then
    if device == "hand/left" and axis == "thumbstick" then
      if x == 0 and y == 0 then
        x, y = self.keyboardLeftStick:unpack()
      end
    elseif device == "hand/right" and axis == "thumbstick" then
      if self:isKeyboardButtonPressed("q") then
        x = -1
      elseif self:isKeyboardButtonPressed("e") then
        x = 1
      end
    elseif device == "hand/left" and axis == "grip" and x == 0 then
      x = self.rightMouseIsDown and 1.0 or 0.0
    end
  end
  return x, y
end
