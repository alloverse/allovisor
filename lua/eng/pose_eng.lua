namespace("networkscene", "alloverse")

local json = require "json"
local tablex = require "pl.tablex"
local pretty = require "pl.pretty"
local allomath = require "lib.allomath"
local isDesktop = (lovr.getOS() == "Windows" or lovr.getOS() == "macOS" or lovr.getOS() == "Linux")
local keyboard = isDesktop and require "lib.lovr-keyboard" or nil
local mouse = isDesktop and require "lib.lovr-mouse" or nil


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




local PoseEng = classNamed("PoseEng", Ent)
function PoseEng:_init()
  self.yaw = 0.0
  self.handRays = {HandRay(), HandRay()}
  self.isFocused = true
  self.mvp = lovr.math.newMat4()

  self:super()
end

function PoseEng:onLoad()
  
end

function PoseEng:onUpdate(dt)
  if self.client == nil then return end

  self:updateIntent()
  for handIndex, hand in ipairs({"hand/left", "hand/right"}) do
    self:updatePointing(hand, self.handRays[handIndex])
  end
end

function PoseEng:onDraw()
  -- Gotta pick up the MVP at the time of drawing so it matches the transform applied in network scene
  local mvp, _ =  lovr.graphics.getTransforms("mvp")
  self.mvp:set(unpack(mvp))

  if true then
    local p = self:getMouseLocationInWorld()
    lovr.graphics.setColor(1,0,0,0.5)
    lovr.graphics.sphere(p, 0.05)
  end

end

function PoseEng:getAxis(device, axis)
  local x, y = 0, 0
  if lovr.headset then
    x, y = lovr.headset.getAxis(device, axis)
  end
  if keyboard then
    if device == "hand/left" and axis == "thumbstick" then
      if keyboard.isDown("a") then
        x = -1
      elseif keyboard.isDown("d") then
        x = 1
      end
      if keyboard.isDown("w") then
        y = 1
      elseif keyboard.isDown("s") then
        y = -1
      end
    elseif device == "hand/right" and axis == "thumbstick" then
      if keyboard.isDown("q") then
        x = -1
      elseif keyboard.isDown("e") then
        x = 1
      end
    elseif device == "hand/left" and axis == "grip" and x == 0 then
      x = keyboard.isDown("f") and 1.0 or 0.0
    end
  end
  return x, y
end

function PoseEng:isDown(device, button)
  local down = false
  if lovr.headset then
    down = lovr.headset.isDown(device, button)
  end
  return down
end

function PoseEng:wasPressed(device, button)
  local down = false
  if lovr.headset then
    down = lovr.headset.wasPressed(device, button)
  end
  if keyboard then
    if device == "hand/right" and button == "b" then
      down = keyboard.wasPressed("r")
    end
  end
  return down
end

function PoseEng:onFocus(focused)
  self.isFocused = focused
end

function PoseEng:getMouseLocationInWorld()
  local x, y = -1, -1; if mouse then x, y = mouse.getPosition() end
  local head = self.parent:getHead()
  local w, h = lovr.graphics.getWidth(), lovr.graphics.getHeight()
  if self.isFocused == false or x < 0 or y < 0 or x > w or y > h or head == nil then
    return nil
  end

  -- https://antongerdelan.net/opengl/raycasting.html
  -- https://github.com/bjornbytes/lovr/pull/237
  -- Unproject from world space
  local matrix = lovr.math.mat4(self.mvp):invert()
  local ndcX = -1 + x/w * 2 -- Normalized Device Coordinates
  local ndcY = 1 - y/h * 2 -- Note: Mouse coordinates have y+ down but OpenGL NDCs are y+ up
  local near = matrix:mul( lovr.math.vec3(ndcX, ndcY, 0) ) -- Where you clicked, touching the screen
  local far  = matrix:mul( lovr.math.vec3(ndcX, ndcY, 1) ) -- Where you clicked, touching the clip plane
  local ray = (far-near):normalize()

  -- point 3 meters into the world
  return near + ray*3
end

function PoseEng:getPose(device)
  local pose = lovr.math.mat4()
  if lovr.headset then
    pose = lovr.math.mat4(lovr.headset.getPose(device))
  else
    if device == "head" then
      pose:translate(0, 1.7, 0)
    elseif device == "hand/left" then
      pose:translate(-0.15, 1.6, -0.2)
      local hoveredPoint = self:getMouseLocationInWorld()
      if hoveredPoint then
        local ava = self.parent:getAvatar()
        local root = ava.components.transform:getMatrix()
        local lookAt = lovr.math.mat4():lookAt(root*pose*lovr.math.vec3(), hoveredPoint)
        pose:mul(lookAt)
      end
      -- todo: use getMouseLocationInWorld and mat4:lookAt
      -- todo: let this location override headset if not tracking too
    end
  end
  return pose
end


function PoseEng:updateIntent()
  if self.client.avatar_id == "" then return end

  -- root entity movement
  local mx, my = self:getAxis("hand/left", "thumbstick")
  local tx, ty = self:getAxis("hand/right", "thumbstick")

  -- It'd be nice if we could have some ownership model, where grabbing "took ownership" of the
  -- stick so this code wouldn't have to hard-code whether it's allowed to use the sticks or not.
  if self.handRays[1].heldEntity ~= nil then 
    mx = 0; my = 0;
  end
  if self.handRays[2].heldEntity ~= nil then
    tx = 0; ty = 0;
  end

  if math.abs(tx) > 0.5 and not self.didTurn then
    self.yaw = self.yaw + allomath.sign(tx) * math.pi/4
    self.didTurn = true
  end
  if math.abs(tx) < 0.5 and self.didTurn then
    self.didTurn = false
  end
  
  local intent = {
    entity_id = self.client.avatar_id,
    xmovement = mx,
    zmovement = -my,
    yaw = self.yaw,
    pitch = 0.0,
    poses = {}
  }

  -- child entity positioning
  for i, device in ipairs({"hand/left", "hand/right", "head"}) do
    intent.poses[device] = {
      matrix = {self:getPose(device):unpack(true)},
      grab = self:grabForDevice(i, device)
    }
  end
  
  self.client:setIntent(intent)
end

local requiredGripStrength = 0.4
function PoseEng:grabForDevice(handIndex, device)
  if device == "head" then return nil end
  local ray = self.handRays[handIndex]
  if ray.hand == nil then return nil end

  local gripStrength = self:getAxis(device, "grip")

  -- released grip button?
  if ray.heldEntity and gripStrength < requiredGripStrength then
    ray.heldEntity = nil

  -- started holding grip button while something is highlighted?
  elseif ray.heldEntity == nil and gripStrength > requiredGripStrength and ray.highlightedEntity then
    ray.heldEntity = ray.highlightedEntity

    local worldFromHand = ray.hand.components.transform:getMatrix()
    local handFromWorld = worldFromHand:invert()
    local worldFromHeld = ray.heldEntity.components.transform:getMatrix()
    local handFromHeld = handFromWorld * worldFromHeld

    ray.grabber_from_entity_transform:set(handFromHeld)
  end

  if ray.heldEntity == nil then
    return nil
  else
    -- Move things to/away from hand with stick
    local stickX, stickY = self:getAxis(device, "thumbstick")

    if math.abs(stickY) > 0.05 then
      local translation = lovr.math.mat4():translate(0,0,-stickY*0.1)
      local newOffset = translation * ray.grabber_from_entity_transform
      if newOffset:mul(lovr.math.vec3()).z < 0 then
        ray.grabber_from_entity_transform:set(newOffset)
      end
    end

    -- return thing to put in intent
    return {
      entity = ray.heldEntity.id,
      grabber_from_entity_transform = ray.grabber_from_entity_transform
    }
  end
end

function PoseEng:updatePointing(hand_pose, ray)
  -- Find the  hand whose parent is my avatar and whose pose is hand_pose
  -- todo: save this in HandRay
  local hand_id = tablex.find_if(self.client.state.entities, function(entity)
    return entity.components.relationships ~= nil and
           entity.components.relationships.parent == self.client.avatar_id and
           entity.components.intent ~= nil and
           entity.components.intent.actuate_pose == hand_pose
  end)

  if hand_id == nil then return end

  
  local hand = self.client.state.entities[hand_id]
  if hand == nil then return end
  ray.hand = hand

  local previouslyHighlighted = ray.highlightedEntity
  ray:highlightEntity(nil)

  local handPos = hand.components.transform:getMatrix():mul(lovr.math.vec3())
    --if position is nan, stop trying to raycast (as raycasting with nan will crash ODE)
  if handPos.x ~= handPos.x then
    return
  end

  ray.from = lovr.math.newVec3(handPos)
  ray.to = lovr.math.newVec3(hand.components.transform:getMatrix():mul(lovr.math.vec3(0,0,-10)))

  -- Raycast from the hand
  self.parent.engines.physics.world:raycast(handPos.x, handPos.y, handPos.z, ray.to.x, ray.to.y, ray.to.z, function(shape, hx, hy, hz)
    -- assuming first hit is nearest; skip all other hovered entities.
    if ray.highlightedEntity == nil then
      ray:highlightEntity(shape:getCollider():getUserData())
      ray.to = lovr.math.newVec3(hx, hy, hz)
    end
  end)

  if previouslyHighlighted and previouslyHighlighted ~= ray.highlightedEntity then
    self.client:sendInteraction({
      type = "one-way",
      receiver_entity_id = previouslyHighlighted.id,
      body = {"point-exit"}
    })
  end

  if ray.highlightedEntity then
    self.client:sendInteraction({
      type = "one-way",
      receiver_entity_id = ray.highlightedEntity.id,
      body = {"point", {ray.from.x, ray.from.y, ray.from.z}, {ray.to.x, ray.to.y, ray.to.z}}
    })

    if ray.selectedEntity == nil and self:isDown(hand_pose, "trigger") then
      ray:selectEntity(ray.highlightedEntity)
      self.client:sendInteraction({
        type = "request",
        receiver_entity_id = ray.selectedEntity.id,
        body = {"poke", true}
      })
    end
  end

  if ray.selectedEntity and not self:isDown(hand_pose, "trigger") then
    self.client:sendInteraction({
      type = "request",
      receiver_entity_id = ray.selectedEntity.id,
      body = {"poke", false}
    })
    ray:selectEntity(nil)
  end
end

return PoseEng
