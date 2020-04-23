namespace("networkscene", "alloverse")

local json = require "json"
local tablex = require "pl.tablex"
local pretty = require "pl.pretty"
local allomath = require "lib.allomath"
local Entity, componentClasses = unpack(require("app.network.entity"))
local keyboard = (lovr.getOS() == "Windows" or lovr.getOS() == "macOS") and require "lib.lovr-keyboard" or nil


local HandRay = classNamed("HandRay")
function HandRay:_init()
  self.isPointing = true
  self.highlightedEntity = nil
  self.selectedEntity = nil
  self.from = lovr.math.newVec3()
  self.to = lovr.math.newVec3()
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

  self:super()
end

function PoseEng:onLoad()
  
end

function pose2matrix(x, y, z, angle, ax, ay, az)
  local mat = lovr.math.mat4()
  mat:translate(x, y, z)
  mat:rotate(angle, ax, ay, az)
  return mat
end

function PoseEng:onUpdate(dt)
  self:updateIntent()
  for handIndex, hand in ipairs(lovr.headset.getHands()) do
    self:updatePointing(hand, self.handRays[handIndex])
  end
end

function PoseEng:updateIntent()
  if self.parent.avatar_id == "" then return end

  -- root entity movement
  local mx, my = lovr.headset.getAxis("hand/left", "thumbstick")
  local tx, ty = lovr.headset.getAxis("hand/right", "thumbstick")

  if math.abs(tx) > 0.5 and not self.didTurn then
    self.yaw = self.yaw + allomath.sign(tx) * math.pi/4
    self.didTurn = true
  end
  if math.abs(tx) < 0.5 and self.didTurn then
    self.didTurn = false
  end
  
  local intent = {
    entity_id = self.parent.avatar_id,
    xmovement = mx,
    zmovement = -my,
    yaw = self.yaw,
    pitch = 0.0,
    poses = {}
  }

  if keyboard then
    if keyboard.isDown("j") then
      intent.xmovement = -1
    elseif keyboard.isDown("l") then
      intent.xmovement = 1
    end
    if keyboard.isDown("i") then
      intent.zmovement = -1
    elseif keyboard.isDown("k") then
      intent.zmovement = 1
    end
    if keyboard.wasPressed("u") then
      intent.yaw = self.yaw - 3.141592 / 4 -- 45deg snap turns
    elseif keyboard.wasPressed("o") then
      intent.yaw = self.yaw + 3.141592 / 4 -- 45deg snap turns
    end
    self.yaw = intent.yaw
  end

  -- child entity positioning
  for i, device in ipairs({"head", "hand/left", "hand/right"}) do
    intent.poses[device] = {
      matrix = pose2matrix(lovr.headset.getPose(device))
    }
  end
  
  self.parent.client:set_intent(intent)
end

function PoseEng:updatePointing(hand_pose, ray)
  -- Find the  hand whose parent is my avatar and whose pose is hand_pose
  -- todo: save this in HandRay
  local hand_id = tablex.find_if(self.parent.state.entities, function(entity)
    return entity.components.relationships ~= nil and
           entity.components.relationships.parent == self.parent.avatar_id and
           entity.components.intent ~= nil and
           entity.components.intent.actuate_pose == hand_pose
  end)

  if hand_id == nil then return end

  
  local hand = self.parent.state.entities[hand_id]
  if hand == nil then return end

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
  self.parent.physics.world:raycast(handPos.x, handPos.y, handPos.z, ray.to.x, ray.to.y, ray.to.z, function(shape, hx, hy, hz)
    -- assuming first hit is nearest; skip all other hovered entities.
    if ray.highlightedEntity == nil then
      ray:highlightEntity(shape:getCollider():getUserData())
      ray.to = lovr.math.newVec3(hx, hy, hz)
    end
  end)

  if previouslyHighlighted and previouslyHighlighted ~= ray.highlightedEntity then
    self.parent:sendInteraction({
      type = "one-way",
      receiver_entity_id = previouslyHighlighted.id,
      body = {"point-exit"}
    })
  end

  if ray.highlightedEntity then
    self.parent:sendInteraction({
      type = "one-way",
      receiver_entity_id = ray.highlightedEntity.id,
      body = {"point", {ray.from.x, ray.from.y, ray.from.z}, {ray.to.x, ray.to.y, ray.to.z}}
    })

    if ray.selectedEntity == nil and lovr.headset.isDown(hand_pose, "trigger") then
      ray:selectEntity(ray.highlightedEntity)
      self.parent:sendInteraction({
        type = "request",
        receiver_entity_id = ray.selectedEntity.id,
        body = {"poke", true}
      })
    end
  end

  if ray.selectedEntity and not lovr.headset.isDown(hand_pose, "trigger") then
    self.parent:sendInteraction({
      type = "request",
      receiver_entity_id = ray.selectedEntity.id,
      body = {"poke", false}
    })
    ray:selectEntity(nil)
  end
end

return PoseEng
