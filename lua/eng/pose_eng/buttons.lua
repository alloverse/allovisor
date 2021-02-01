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

function PoseEng:updateButtons()
  self.previousButtonStates = self.currentButtonStates
  self.currentButtonStates = {["hand/left"]={}, ["hand/right"]={}}
  for handIndex, hand in ipairs(PoseEng.hands) do
    for _, button in ipairs(PoseEng.buttons) do
      self:updateButton(hand, button)
    end
  end
end

function PoseEng:routeButtonEvents()
  if not self.previousButtonStates then return end
  for handIndex, hand in ipairs(PoseEng.hands) do
    for _, button in ipairs(PoseEng.buttons) do
      if not self.previousButtonStates[hand][button] and self.currentButtonStates[hand][button] then
        self.parent:route("onButtonPressed", hand, button)
      end
      if self.previousButtonStates[hand][button] and not self.currentButtonStates[hand][button] then
        self.parent:route("onButtonReleased", hand, button)
      end
    end
  end
end

function PoseEng:updateButton(device, button)
  local down = false
  if lovr.headset then
    down = down or lovr.headset.isDown(device, button)
  end
  if device == "hand/left" and button == "trigger" then
    down = down or (self.mouseIsDown and self.mouseMode == "interact")
  elseif button == "menu" and self.keyboard then
    down = down or self.keyboard.isDown("r")
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
  return self.currentButtonStates[device][button]
end

function PoseEng:wasPressed(device, button)
  if self.parent.active == false then return false end
  if not self.currentButtonStates then return false end
  local was = self.previousButtonStates and self.previousButtonStates[device][button] or false
  return not was and self:isDown(device, button)
end

function PoseEng:wasReleased(device, button)
  if self.parent.active == false then return false end
  if not self.currentButtonStates then return false end
  local was = self.previousButtonStates and self.previousButtonStates[device][button] or false
  return was and not self:isDown(device, button)
end


function PoseEng:getAxis(device, axis)
  if self.parent.active == false then return 0.0, 0.0 end

  local x, y = 0, 0
  if lovr.headset then
    x, y = lovr.headset.getAxis(device, axis)
  end
  if self.keyboard then
    if device == "hand/left" and axis == "thumbstick" then
      if self.keyboard.isDown("a") then
        x = -1
      elseif self.keyboard.isDown("d") then
        x = 1
      end
      if self.keyboard.isDown("w") then
        y = 1
      elseif self.keyboard.isDown("s") then
        y = -1
      end
    elseif device == "hand/right" and axis == "thumbstick" then
      if self.keyboard.isDown("q") then
        x = -1
      elseif self.keyboard.isDown("e") then
        x = 1
      end
    elseif device == "hand/left" and axis == "grip" and x == 0 then
      -- x = self.keyboard.isDown("f") and 1.0 or 0.0
      x = self.rightMouseIsDown and 1.0 or 0.0
    end
  end
  return x, y
end
