namespace("pose_eng", "alloverse")

local tablex = require "pl.tablex"
local pretty = require "pl.pretty"
local allomath = require "lib.allomath"
alloBasicShader = require "shader/alloBasicShader"
alloPointerRayShader = require "shader/alloPointerRayShader"
local HandRay = require "eng.pose_eng.hand_ray"
local letters = require("lib.letters.letters")
local ffi = require("ffi")

--------------------------
-- PoseEng abstracts headset and hand input; and translates them into intents and interactions.
--
-- First, it is a layer on top of lovr.headset, either proxying
-- headset's functionality (when in VR) or emulating it (when
-- in desktop mode). On desktop, it translates keyboard and
-- mouse input into equivalent hand/controller and headset
-- movement and actions. If you ever feel the urge to use the
-- lovr.headset module, please use your network scene's pose engine
-- instead, because lovr.headset is null when in desktop mode.
--
-- Second, it reads all input states and translates it into
-- an Allonet Intent, sending it onto the network each frame.
--
-- It's a really large class so it's split into multiple files:
--  * init.lua contains:
--    * high level callbacks (update, debug draw, etc)
--    * parsing the mouse
--    * interpreting its internal state as poses for various 
--      headset devices (including one made-up pose called "torso"),
--    * Translate state into intent
--    * figure out grabs, points and pokes, and translates them
--      into interactions
--  * hand_ray.lua is a class that handles state for the hand, which helps
--    with pointing, poking, picking and grabbing
--  * buttons.lua keeps track of buttons and sticks on the controllers,
--    sending callbacks when things are pressed, etc
--  * skeleton.lua manages the hand skeleton for hand tracking
--
-- @classmod PoseEng

PoseEng = classNamed("PoseEng", Ent)

PoseEng.hands = {"hand/left", "hand/right"}
PoseEng.buttons = {"trigger", "thumbstick", "touchpad", "grip", "menu", "a", "b", "x", "y", "proximity"}
PoseEng.axis = {"trigger", "thumbstick", "touchpad", "grip"}

local leftHandIndex = 1
local rightHandIndex = 2

function PoseEng:_init()
  self.yaw = 0.0
  self.handRays = {HandRay("hand/left"), HandRay("hand/right")}
  -- don't point with the fake left hand
  if not lovr.headset then self.handRays[leftHandIndex].isPointing = false end
  self.isFocused = true
  self.mvp = lovr.math.newMat4()
  self.oldMousePos = lovr.math.newVec2()
  self.fakeMousePos = lovr.math.newVec2()
  self.fakeKeyboardEvents = {}
  self.capturedControls = {}
  self.mousePitch = 0
  self.lastAxisEvent = 0
  self.focus = {
    entity= nil,
    type= nil
  }
  self:super()
  self:useKeyboardForControllerEmulation(true)
end

--- Returns the primary highlighted entity
-- @treturn Entity nil, or an entity highlighted by either left or right hand, depending on last active controller or user setting, and the hand ray that has the entity
function PoseEng:highlightedEntity()
  if self.handRays[rightHandIndex].highlightedEntity then 
    return self.handRays[rightHandIndex].highlightedEntity, self.handRays[rightHandIndex]
  end

  if self.handRays[leftHandIndex].highlightedEntity then 
    return self.handRays[leftHandIndex].highlightedEntity, self.handRays[leftHandIndex]
  end
  
  return nil, nil
end

function PoseEng:onLoad()
  
end

function PoseEng:onUpdate(dt)
  self:updateButtons(dt)

  if self.parent.active == false then return end
  if self.client == nil then return end
  
  if lovr.mouse then
    self:updateMouse()
  end
  self:updateIntent(dt)
  for handIndex, hand in ipairs(PoseEng.hands) do
    self:updatePointing(hand, self.handRays[handIndex], handIndex)
  end

  self:routeButtonEvents()
  self:routeAxisEvents()
end

function PoseEng:onDraw()
  -- Gotta pick up the MVP at the time of drawing so it matches the transform applied in network scene
  lovr.graphics.getProjection(1, self.mvp)
  local view = lovr.math.mat4()
  lovr.graphics.getViewPose(1, view, true)
  self.mvp:mul(view)
  if self.parent.active and not self.parent.isSpectatorCamera then
    for _, ray in ipairs(self.handRays) do
      ray:draw()
    end
  end

  -- if lovr.mouse and self.mouseInWorld then
  --   lovr.graphics.setColor(1,0,0,0.5)
  --   lovr.graphics.sphere(self.mouseInWorld, 0.05)
  -- end
end

function PoseEng:onFocus(focused)
  self.isFocused = true 
  -- this isn't set to _focused_ because of reasons documented in onFileDrop
end

function PoseEng:isTracked(device)
  if device == "torso" then return false end
  if not lovr.headset then return false end
  return lovr.headset.isTracked(device)
end

function PoseEng:vibrate(...)
  if lovr.headset then
    lovr.headset.vibrate(...)
  end
end

function PoseEng:getPosition(device)
  local x, y, z, sx, sy, sz, a, ax, ay, az = self:getPose(device):unpack()
  return lovr.math.vec3(x, y, z)
end

function PoseEng:getOrientation(device)
  return lovr.math.quat(self:getPose(device))
end

function PoseEng:getPose(device)
  local pose = lovr.math.mat4()
  if lovr.headset and self:isTracked(device) then
    pose = lovr.math.mat4(lovr.headset.getPose(device))
  else
    if device == "head" then
      pose:translate(0, 1.65, 0)
      pose:rotate(self.mousePitch, 1,0,0)
    elseif device == "torso" then
      local head = self:getPose("head")
      pose
        :translate(head:mul(lovr.math.vec3()))
        :translate(0, -0.485, 0.04)
    elseif device == "hand/left" then
      local head = self:getPose("head")
      local invHead = lovr.math.mat4(head):invert()
      local torso = self:getPose("torso")
      pose
        :mul(torso)
        :translate(0,-1.15,0)
        :mul(head)
        :rotate(self.mousePitch, 1,0,0)  
        :mul(invHead)
        :translate(-0.18, 1.50, -0.35)
        :rotate(-3.1416/3, 0,1,0)
        :rotate(-1.3, 0,0,1)
        :translate(0,0,-0.05)
    elseif device == "hand/right" then
      pose:translate( 0.18, 1.45, -0.0)
      local ava = self.parent:getAvatar()
      if lovr.mouse and self.mouseInWorld and ava then
        local worldFromAvatar = ava.components.transform:getMatrix()
        local avatarFromWorld = lovr.math.mat4(worldFromAvatar):invert()
        local worldFromHand = worldFromAvatar:mul(pose)
        local from = worldFromHand:mul(lovr.math.vec3())
        local to = self.mouseInWorld
        worldFromHand:identity():target(from, to):translate(0,0,-0.35)
        local avatarFromHand = avatarFromWorld * worldFromHand
        pose:set(avatarFromHand)
      else
        local torso = self:getPose("torso")
        pose
          :mul(torso)
          :rotate(-3.1416/2, 1,0,0)
          :translate(0,0.04,-1.55)
      end
    end
  end
  return pose
end

function PoseEng:_recalculateMouseInWorld(x, y, w, h)
  -- https://antongerdelan.net/opengl/raycasting.html
  -- https://github.com/bjornbytes/lovr/pull/237
  -- Unproject from world space
  local matrix = lovr.math.mat4(self.mvp):invert()
  local ndcX = -1 + x/w * 2 -- Normalized Device Coordinates
  local ndcY = 1 - y/h * 2 -- Note: Mouse coordinates have y+ down but OpenGL NDCs are y+ up
  local near = matrix:mul( lovr.math.vec3(ndcX, ndcY, 0) ) -- Where you clicked, touching the screen
  local far  = matrix:mul( lovr.math.vec3(ndcX, ndcY, 1) ) -- Where you clicked, touching the clip plane
  local ray = (far-near):normalize()

  -- point 3 meters into the world by default
  local mouseInWorld = near + ray*3

  -- see if we hit something closer than that, and if so move 3d mouse there
  local nearestHit = nil
  local nearestDistance = 10000
  self.parent.engines.physics.world:raycast(near.x, near.y, near.z, mouseInWorld.x, mouseInWorld.y, mouseInWorld.z, function(shape, hx, hy, hz)
    local newHit = shape:getCollider():getUserData()
    local newLocation = lovr.math.vec3(hx, hy, hz)
    local newDistance = (newLocation - near):length()
    if newDistance < nearestDistance then
      nearestHit = newHit
      nearestDistance = newDistance
      mouseInWorld = newLocation
    end
  end)
  
  self.mouseInWorld = lovr.math.newVec3(mouseInWorld)
  self.mouseTouchesEntity = nearestHit ~= nil
end

function PoseEng:updateMouse()
  -- figure out where in the world the mouse is...
  local x, y = lovr.mouse.position:unpack()
  local w, h = lovr.graphics.getWidth(), lovr.graphics.getHeight()
  local isOutOfBounds = x < 0 or y < 0 or x > w or y > h
  if self.isFocused == false or (self.mouseIsDown == false and isOutOfBounds) then
    self.mouseInWorld = nil
    --self.mouseMode = "move"
    self.mouseIsDown = false
    return
  end

  -- if (x ~= self.fakeMousePos.x) and self.fakeMousePos.x ~= 0 then
  --   print("===============================")
  --   print("x                     ", x)
  --   print("self.fakeMousePos.x   ", self.fakeMousePos.x)
  --   print("y                     ", y)
  --   print("self.fakeMousePos.y   ", self.fakeMousePos.y)
  --   print("self.mouseMode        ", self.mouseMode)
  --   print("self.mouseIsDown      ", self.mouseIsDown)
  --   print("RMB is down:          ", lovr.mouse.buttons[2])
  -- end

  if self.mouseMode == "move" and self.mouseIsDown then
    -- make it look like cursor is fixed in place, since lovr-mouse fakes relative movement by hiding cursor
    self:_recalculateMouseInWorld(self.fakeMousePos.x, self.fakeMousePos.y, w, h)
  else
    self:_recalculateMouseInWorld(x, y, w, h)
  end

  -- okay great, we know where the mouse is.
  -- Now figure out what to do with mouse buttons.
  local mouseIsDown = lovr.mouse.buttons[1]
  local rightMouseIsDown = lovr.mouse.buttons[2]

  -- started clicking/dragging; choose mousing mode
  if not self.mouseIsDown and mouseIsDown then
    if self.handRays[rightHandIndex].highlightedEntity or #letters.hands[rightHandIndex].highlightedNodes > 0 then
      self.mouseMode = "interact"
    else
      self.mouseMode = "move"
      self.oldMousePos:set(x, y)
      self.fakeMousePos:set(x, y)
      lovr.mouse.setRelativeMode(true)
    end
  end
  self.mouseIsDown = mouseIsDown
  self.rightMouseIsDown = rightMouseIsDown
  if self.mouseMode == "move" and not mouseIsDown then
    lovr.mouse.setRelativeMode(false)
  end

  if self.mouseIsDown and self.mouseMode == "move" then
    local newMousePos = lovr.math.vec2(x, y)
    local delta = lovr.math.vec2(newMousePos) - self.oldMousePos
    self.yaw = self.yaw + (delta.x/500)
    self.mousePitch = utils.clamp(self.mousePitch - (delta.y/500), -3.14/2, 3.14/2)
    self.oldMousePos:set(newMousePos)
  end
end


function PoseEng:updateIntent(dt)
  if self.client.avatar_id == "" then return end

  -- root entity movement
  local mx, my = self:getAxis("hand/left", "thumbstick")
  if self:isDown("hand/left", "x") then
    mx = mx * 2
    my = my * 2
  end
  local tx, ty = self:getAxis("hand/right", "thumbstick")

  -- XXX<nevyn> It'd be nice if we could have some ownership model, where grabbing "took ownership" of the
  --            stick so this code wouldn't have to hard-code whether it's allowed to use the sticks or not.
  -- Stick up-down is used to move entity, so stop moving user
  if self.handRays[leftHandIndex].heldEntity ~= nil then 
    my = 0;
  end
  if self.handRays[rightHandIndex].heldEntity ~= nil then
    ty = 0;
  end

  -- not allowed to walk around in the overlay menu
  if self.parent.isOverlayScene then
    mx = 0; my = 0; tx = 0; ty = 0
  end

  if math.abs(tx) > 0.5 and not self.didTurn then
    self.yaw = self.yaw + allomath.sign(tx) * math.pi/4
    self.didTurn = true
  end
  if math.abs(tx) < 0.5 and self.didTurn then
    self.didTurn = false
  end


  

  local intent = self.client:createIntent({
    entity_id = self.client.avatar_id,
    wants_stick_movement = false,
    xmovement = mx,
    zmovement = -my,
    yaw = self.yaw,
    pitch = 0.0,
  })

  intent.poses.head.matrix.v = {self:getPose("head"):unpack(true)}
  intent.poses.torso.matrix.v = {self:getPose("torso"):unpack(true)}
  intent.poses.left_hand.matrix.v = {self:getPose("hand/left"):unpack(true)}
  intent.poses.left_hand.grab = self:grabForDevice(1, "hand/left")
  --intent.poses.left_hand.skeleton = self:getSkeletonTable("hand/left")
  intent.poses.right_hand.matrix.v = {self:getPose("hand/right"):unpack(true)}
  intent.poses.right_hand.grab = self:grabForDevice(2, "hand/right")
  --intent.poses.right_hand.skeleton = self:getSkeletonTable("hand/right")

  if self.parent.useClientAuthoritativePositioning then
    local avatar_id = self.parent.avatar_id
    self.client:simulateRootPose(avatar_id, dt, intent)
  end
  
  self.client:setIntent(intent)
end

local requiredGripStrength = 0.4
function PoseEng:grabForDevice(handIndex, device)
  if device == "head" or device == "torso" then return nil end
  local ray = self.handRays[handIndex]
  if ray.hand == nil then return {} end

  local previouslyHeld = ray.heldEntity

  local gripStrength = self:getAxis(device, "grip")

  -- released grip button?
  if ray.heldEntity and gripStrength < requiredGripStrength then
    ray.heldEntity = nil

  -- started holding grip button while something is highlighted?
  elseif ray.heldEntity == nil and gripStrength > requiredGripStrength and ray.highlightedEntity and ray.highlightedEntity.components.grabbable then
    ray.heldEntity = ray.highlightedEntity

    local targetHandTransform = ray.heldEntity.components.grabbable.target_hand_transform
    if targetHandTransform then
      targetHandTransform = lovr.math.mat4(unpack(targetHandTransform))
      ray.grabber_from_entity_transform:set(targetHandTransform)
    else
      local worldFromHand = ray.hand.components.transform:getMatrix()
      local handFromWorld = worldFromHand:invert()
      local worldFromHeld = ray.heldEntity.components.transform:getMatrix()
      local handFromHeld = handFromWorld * worldFromHeld

      ray.grabber_from_entity_transform:set(handFromHeld)
    end
  end

  if previouslyHeld ~= ray.heldEntity then
    if previouslyHeld then
      self:_endGrab(ray.device, ray.handEntity, previouslyHeld)
    end
    if ray.heldEntity then
      self:_startGrab(ray.device, ray.handEntity, ray.heldEntity)
    end
  end


  if ray.heldEntity == nil then
    return {}
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
    local entId = ffi.C.malloc(#ray.heldEntity.id+1)
    ffi.copy(entId, ray.heldEntity.id)
    return {
      entity = entId,
      grabber_from_entity_transform = {
        v = {ray.grabber_from_entity_transform:unpack(true)}
      }
    }
  end
end

function PoseEng:_startGrab(device, hand, held)
  self.client:sendInteraction({
    type = "one-way",
    sender = hand,
    receiver_entity_id = held.id,
    body = {"grabbing", true}
  })

  local grabbable = held.components.grabbable
  if grabbable and grabbable.capture_controls then
    for _, button in ipairs(grabbable.capture_controls) do
      if button ~= "grip" then
        self.capturedControls[device..button] = held
      end
    end
  end
end

function PoseEng:_endGrab(device, hand, previouslyHeld)
  self.client:sendInteraction({
    type = "one-way",
    sender = hand,
    receiver_entity_id = previouslyHeld.id,
    body = {"grabbing", false}
  })
  for devicebutton, holder in pairs(self.capturedControls) do
    if holder == previouslyHeld then
      self.capturedControls[devicebutton] = nil
    end
  end
end


function PoseEng:updatePointing(hand_pose, ray, handIndex)
  -- Find the  hand whose parent is my avatar and whose pose is hand_pose
  -- todo: save this in HandRay
  local hand_id = tablex.find_if(self.client.state.entities, function(entity)
    return entity.components.relationships ~= nil and
           entity.components.relationships.parent == self.client.avatar_id and
           entity.components.intent ~= nil and
           entity.components.intent.actuate_pose == hand_pose
  end)

  if hand_id == nil then return end

  if not ray.isPointing then return end

  
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
  local nearestHit = nil
  local nearestDistance = 10000
  local nearestHitLocation = lovr.math.vec3()
  self.parent.engines.physics.world:raycast(handPos.x, handPos.y, handPos.z, ray.to.x, ray.to.y, ray.to.z, function(shape, hx, hy, hz)
    local newHit = shape:getCollider():getUserData()
    local newLocation = lovr.math.vec3(hx, hy, hz)
    local newDistance = (newLocation - ray.from):length()
    if newDistance < nearestDistance then
      nearestHit = newHit
      nearestDistance = newDistance
      nearestHitLocation = newLocation
    end
  end)
  if ray.highlightedEntity ~= nearestHit then
    ray:highlightEntity(nearestHit)
    ray.to:set(nearestHitLocation)
  end

  if previouslyHighlighted and previouslyHighlighted ~= ray.highlightedEntity then
    self.client:sendInteraction({
      type = "one-way",
      sender = ray.handEntity,
      receiver_entity_id = previouslyHighlighted.id,
      body = {"point-exit"}
    })
  end

  if ray.highlightedEntity then
    local sendAtFullFramerate = self:isDown(hand_pose, "trigger")
    self:sendPointingEvent(ray, sendAtFullFramerate)

    local shouldSendPoke = (ray.selectedEntity == nil and self:isDown(hand_pose, "trigger") and #letters.hands[handIndex].highlightedNodes == 0)
    if shouldSendPoke then
      ray:selectEntity(ray.highlightedEntity)
      self:pokeEntity(ray.selectedEntity, ray.handEntity)
    end
  end

  if ray.selectedEntity and not self:isDown(hand_pose, "trigger") then
    self:endPokeEntity(ray.selectedEntity, ray.handEntity)
    ray:selectEntity(nil)
  end
end

function PoseEng:sendPointingEvent(ray, forceSendNow)
  local lastSentAt = ray.lastSentPointAt or 0
  local now = lovr.timer.getTime()
  local delta = now - lastSentAt
  if forceSendNow or lastSentAt == 0 or delta > 1/10.0 then
    self.client:sendInteraction({
      type = "one-way",
      sender = ray.handEntity,
      receiver_entity_id = ray.highlightedEntity.id,
      body = {"point", {ray.from.x, ray.from.y, ray.from.z}, {ray.to.x, ray.to.y, ray.to.z}}
    })
    ray.lastSentPointAt = now
  end
end

function PoseEng:pokeEntity(ent, hand)
  self.client:sendInteraction({
    type = "request",
    sender = hand,
    receiver = ent,
    body = {"poke", true}
  })

  if self.focus.entityid ~= ent.id then
    self:setFocus(ent)
  end
end

function PoseEng:endPokeEntity(ent, hand)
  self.client:sendInteraction({
    type = "request",
    sender = hand,
    receiver = ent,
    body = {"poke", false}
  })
end

function PoseEng:setFocus(ent)
  if self.focus.entity and ent.id == self.focus.entity.id then return end

  if self.focus.entity then
    self.client:sendInteraction({
      type = "oneway",
      receiver = self.focus.entity,
      body = {"defocus"}
    })
  end

  -- todo: I dunno... I feel like text fields shouldn't be defocused just 'cause we press
  -- a button. let's figure this out through experimentation what feels good...

  local type = "attention"
  local focuscomp = ent.components.focus
  if focuscomp and focuscomp.type then
    type = focuscomp.type
  end

  print("Focusing ("..type..")", ent.id)

  self.client:sendInteraction({
    receiver = ent,
    body = {"focus"}
  }, function(reply, body)
    if body[2] == "ok" then
      self.focus = {
        entity= ent,
        type= type
      }
      self.parent:route("onFocusChanged", ent, type)
    else
      print("Failed to focus", ent.id, ":", pretty.write(body))
    end
  end)
end
function PoseEng:defocus()
  if self.focus.entity == nil then return end
  print("Defocusing from", self.focus.entity.id)
  self.client:sendInteraction({
    type = "oneway",
    receiver = self.focus.entity,
    body = {"defocus"}
  })
  self.focus = {
    entity= nil,
    type= nil
  }
  self.parent:route("onFocusChanged", nil, nil)
end

function PoseEng:onInteraction(interaction, body, receiver, sender)
  if self.focus.entity and body[1] == "defocus" and self.focus.entity.id == sender.id then
    self:defocus()
  elseif body[1] == "changeFocusTo" then
    local entityId = body[2]
    local entity = self.parent.client.state.entities[entityId]
    if entity then
      self:setFocus(entity)
    end
  end
end

function PoseEng:onEntityRemoved(e)
  if self.focus.entity and e.id == self.focus.entity.id then
    self:defocus()
  end
end

function PoseEng:onComponentAdded(cname, component)
  local entity = component:getEntity()
  if cname == "intent" and entity.components.relationships and entity.components.relationships.parent == self.parent.avatar_id then
    if component.actuate_pose == "hand/left" then
      self.handRays[leftHandIndex].handEntity = entity
    elseif component.actuate_pose == "hand/right" then
      self.handRays[rightHandIndex].handEntity = entity
    end
  end
end

function PoseEng:onKeyPress(code, scancode, repetition)
  if code == "escape" then
    self:defocus()
  end
end

function PoseEng:onFileDrop(key)
  -- file drop is likely to happen when app is in background, so let's do a once-over update of hand position
  -- (which is hidden when backgrounded) before AssetsEngine runs into this file drop.
  -- TODO: This doesn't work, because pointing is using the _hand entity's location_ to calculate the
  -- handray, which is likely a frame or two off due to network latency :S So, try this again when
  -- hand has locally interpolated location. (or maybe we just need to trigger a simulate() here?)
  -- In any case, meanwhile I'm going to set isFocused to always be true.
  if not self.isFocused then
    self.isFocused = true
    self:onUpdate(0.01)
    self.isFocused = false
  end
end

require "eng.pose_eng.skeleton"
require "eng.pose_eng.buttons"

return PoseEng
