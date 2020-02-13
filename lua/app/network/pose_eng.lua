namespace("networkscene", "alloverse")

local json = require "json"
local tablex = require "pl.tablex"
local Entity, componentClasses = unpack(require("app.network.entity"))

local PoseEng = classNamed("PoseEng", Ent)
function PoseEng:_init()
  self.yaw = 0.0
  
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
  local mx, my = lovr.headset.getAxis("hand/left", "thumbstick")
  local tx, ty = lovr.headset.getAxis("hand/right", "thumbstick")
  self.yaw = self.yaw - (tx/30.0)
  local intent = {
    xmovement = mx,
    zmovement = -my,
    yaw = self.yaw,
    pitch = 0.0,
    poses = {}
  }
  for i, device in ipairs({"head", "hand/left", "hand/right"}) do
    intent.poses[device] = {
      matrix = pose2matrix(lovr.headset.getPose(device))
    }
  end
  
  self.parent.client:set_intent(intent)


  -- Find the left hand whose parent is my avatar and whose pose is left hand
  local lefthand_id = tablex.find_if(self.parent.state.entities, function(entity)
    return entity.components.relationships ~= nil and
           entity.components.relationships.parent == self.parent.avatar_id and
           entity.components.intent ~= nil and
           entity.components.intent.actuate_pose == "hand/left"
  end)
  
  if (lefthand_id ~= nil) then
    local lefthand = self.parent.state.entities[lefthand_id]
    if (lefthand ~= nil) then
      local handPos = lefthand.components.transform:getMatrix():mul(lovr.math.vec3())
      local distantPoint = lefthand.components.transform:getMatrix():mul(lovr.math.vec3(0,0,-10))      

      -- Raycast from the left hand
      self.parent.physics.world:raycast(handPos.x, handPos.y, handPos.z, distantPoint.x, distantPoint.y, distantPoint.z, function(shape)
       
        -- TODO: Set the correct point of intersection (i.e. not just the "distantPoint")
        -- self.parent:sendInteraction({
        --   type = "one-way",
        --   receiver_entity_id = shape:getCollider():getUserData().id,
        --   body = {"point", {handPos.x, handPos.y, handPos.z}, {distantPoint.x, distantPoint.y, distantPoint.z}}
        -- })

        if lovr.headset.wasPressed("hand/left", "trigger") then
          self.parent:sendInteraction({
            type = "request",
            receiver_entity_id = shape:getCollider():getUserData().id,
            body = {"poke", true}
          })
        end

        if lovr.headset.wasReleased("hand/left", "trigger") then
          self.parent:sendInteraction({
            type = "request",
            receiver_entity_id = shape:getCollider():getUserData().id,
            body = {"poke", false}
          })
        end

      end)
    end
  end

end

return PoseEng
