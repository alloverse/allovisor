namespace("pose_eng", "alloverse")

local nodeToParentIndex = {
  0, -- palm=1
  0, -- wrist=2
  2, -- thumb root=3
  3,
  4,
  5,
  2, -- index root=7
  7,
  8,
  9,
  10,
  2, -- middle root = 12
  12,
  13,
  14,
  15,
  2, -- ring root = 17
  17,
  18,
  19,
  20,
  2, -- pinky root = 22
  22,
  23,
  24,
  25,
}
local nodeNames = {
  "palm",
  "wrist",
  "thumb_metacarpal",
  "thumb_proximal",
  "thumb_distal",
  "thumb_tip",
  "index_metacarpal",
  "index_proximal",
  "index_intermediate",
  "index_distal",
  "index_tip",
  "middle_metacarpal",
  "middle_proximal",
  "middle_intermediate",
  "middle_distal",
  "middle_tip",
  "ring_metacarpal",
  "ring_proximal",
  "ring_intermediate",
  "ring_distal",
  "ring_tip",
  "little_metacarpal",
  "little_proximal",
  "little_intermediate",
  "little_distal",
  "little_tip",
}

function PoseEng:getSkeleton(device)
  if not lovr.headset then
    return nil
  end
  local globalNodes = lovr.headset.getSkeleton(hand)
  if not globalNodes then
    return nil
  end

  local worldFromHand = lovr.math.mat4(lovr.headset.getPose(hand))
  local handFromWorld = lovr.math.mat4(worldFromHand):invert()

  local localNodes = {}
  for i, joint in ipairs(globalNodes) do
    local gx, gy, gz, ga, gax, gay, gaz = unpack(joint)
    local worldFromJoint = lovr.math.mat4(unpack(joint))
    local handFromJoint = lovr.math.mat4(handFromWorld):mul(worldFromJoint)
    local nodeName = nodeNames[i]
    local parentIndex = nodeToParentIndex[i]
    local parentNodeName = nodeNames[parentIndex] and nodeNames[parentIndex] or ""

    -- first off, figure out local positions and rotations for each joint relative to their parent joints
    if parentIndex ~= 0 then
        local handFromParent = localNodes[parentIndex]
        local parentFromHand = lovr.math.mat4(handFromParent):invert()
        localNodes[i] = lovr.math.mat4(parentFromHand):mul(handFromJoint) -- localNodes[i] thus becomes parentFromJoint
    else
        localNodes[i] = lovr.math.mat4(handFromJoint)
    end
  end

  return localNodes
end

function PoseEng:getSkeletonTable(device)
  local skeleton = self:getSkeleton(device)
  if skeleton then
    return tablex.map(function(m) return {m:unpack()} end, skeleton)
  else
    return nil
  end
end