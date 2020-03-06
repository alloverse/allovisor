namespace("networkscene", "alloverse")

local json = require "json"
local tablex = require "pl.tablex"
local Entity, componentClasses = unpack(require("app.network.entity"))
local keyboard = (lovr.getOS() == "Windows" or lovr.getOS() == "macOS") and require "lib.lovr-keyboard" or nil

local PoseEng = classNamed("PoseEng", Ent)
function PoseEng:_init()
  self.yaw = 0.0
  self.hoveredEntity = nil
  self.pokedEntity = nil

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
  self:updatePointing()
end

function PoseEng:updateIntent()
  -- root entity movement
  local mx, my = lovr.headset.getAxis("hand/left", "thumbstick")
  local tx, ty = lovr.headset.getAxis("hand/right", "thumbstick")
  self.yaw = self.yaw - (-tx/30.0)
  local intent = {
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

function PoseEng:updatePointing()
  -- Find the left hand whose parent is my avatar and whose pose is left hand
  local lefthand_id = tablex.find_if(self.parent.state.entities, function(entity)
    return entity.components.relationships ~= nil and
           entity.components.relationships.parent == self.parent.avatar_id and
           entity.components.intent ~= nil and
           entity.components.intent.actuate_pose == "hand/left"
  end)
  
  if lefthand_id == nil then return end
  
  local lefthand = self.parent.state.entities[lefthand_id]
  if lefthand == nil then return end

  local handPos = lefthand.components.transform:getMatrix():mul(lovr.math.vec3())
  local distantPoint = lefthand.components.transform:getMatrix():mul(lovr.math.vec3(0,0,-10))

  self.hoveredEntity = nil

  -- Raycast from the left hand
  self.parent.physics.world:raycast(handPos.x, handPos.y, handPos.z, distantPoint.x, distantPoint.y, distantPoint.z, function(shape, hx, hy, hz)
    -- assuming first hit is nearest; skip all other hovered entities.
    if self.hoveredEntity == nil then
      self.hoveredEntity = shape:getCollider():getUserData()
    end
  end)

  if self.hoveredEntity then
    -- todo: server needs to be more resilient before we can start spamming these :S
    -- self.parent:sendInteraction({
    --   type = "one-way",
    --   receiver_entity_id = shape:getCollider():getUserData().id,
    --   body = {"point", {handPos.x, handPos.y, handPos.z}, {hx, hy, hz}}
    -- })

    if self.pokedEntity == nil and lovr.headset.isDown("hand/left", "trigger") then
      self.pokedEntity = self.hoveredEntity
      self.parent:sendInteraction({
        type = "request",
        receiver_entity_id = self.pokedEntity.id,
        body = {"poke", true}
      })
    end
  end

  if self.pokedEntity and not lovr.headset.isDown("hand/left", "trigger") then
    self.parent:sendInteraction({
      type = "request",
      receiver_entity_id = self.pokedEntity.id,
      body = {"poke", false}
    })
    self.pokedEntity = nil
  end
end

return PoseEng
