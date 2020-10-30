namespace("pose_eng", "alloverse")

function PoseEng:getSkeleton(device)
  if not lovr.headset then
    return nil
  end
  local skeleton = {}
  for i, joint in ipairs(lovr.headset.getSkeleton(hand) or {}) do
    
  end
  return skeleton
end