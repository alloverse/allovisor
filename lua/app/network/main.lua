namespace("networkscene", "alloverse")

local json = require "json"

local NetworkScene = classNamed("NetworkScene", Ent)

--  If ran from lovr.app/lodr/testapp, liballonet.so is in project root
local success, allonet = pcall(require, "liballonet")
if success == false then
  print("No liballonet, trying in lovr binary as if we're on a Mac...")
  local pkg = package.loadlib("lovr", "luaopen_liballonet")
  if pkg == nil then
    print("No liballonet, trying in liblovr.so as if we're on Android...")
    -- if ran from android, liblovr.so contains allonet.a
    pkg = package.loadlib("liblovr.so", "luaopen_liballonet")
  end
  if pkg == nil then
    error("Allonet missing from so, lovr and liblovr. Giving up.")
  end
  allonet = pkg()
end


function NetworkScene:_init(displayName, url)
  self.client = allonet.connect(
    url,
    json.encode({display_name = displayName}),
    json.encode({geometry = {
      type = "hardcoded-model"
    }})
  )
  self.yaw = 0.0
  self:super()
end

function NetworkScene:onLoad()
  --world = lovr.physics.newWorld()
  self.skybox = lovr.graphics.newTexture('assets/cloudy-skybox.jpg')  
end


function NetworkScene:onDraw()  
  lovr.graphics.setColor({1,1,1})
  lovr.graphics.skybox(self.skybox)
  -- iterera igenom client.get_state().entities
  -- rita ut varje entity som en kub

  for _, entity in ipairs(self.client:get_state().entities) do

    local trans = entity.components.transform
    local geom = entity.components.geometry

    if trans ~= nil and geom ~= nil then
      if geom.type == "hardcoded-model" then
        lovr.graphics.setColor(0, 0, 0)
        lovr.graphics.cube('fill', 
          trans.position.x, trans.position.y, trans.position.z, 
          1, 
          euler2axisangle(trans.rotation.x, trans.rotation.y, trans.rotation.z)
      )
      elseif geom.type == "inline" then
        
      end
    end
  end

end

-- https://www.euclideanspace.com/maths/geometry/rotations/conversions/eulerToAngle/
function euler2axisangle(pitch, yaw, roll)
	local c1 = math.cos(yaw/2)
	local s1 = math.sin(yaw/2)
	local c2 = math.cos(pitch/2)
	local s2 = math.sin(pitch/2)
	local c3 = math.cos(roll/2)
	local s3 = math.sin(roll/2)
	local c1c2 = c1*c2
	local s1s2 = s1*s2
	w =c1c2*c3 - s1s2*s3
	x =c1c2*s3 + s1s2*c3
	y =s1*c2*c3 + c1*s2*s3
	z =c1*s2*c3 - s1*c2*s3
	local angle = 2 * math.acos(w)
	local norm = x*x+y*y+z*z
  if norm < 0.001 then 
    -- when all euler angles are zero angle =0 so
		-- we can set axis to anything to avoid divide by zero
		x=1
    y=0
    z=0
	else
		norm = math.sqrt(norm)
    x = x / norm;
    y = y / norm;
    z = z / norm;
  end
  return angle, x, y, z
end


function NetworkScene:onUpdate(dt)
  local mx, my = lovr.headset.getAxis("hand/left", "thumbstick")
  local tx, ty = lovr.headset.getAxis("hand/right", "thumbstick")
  self.yaw = self.yaw - (tx/30.0)
  local intent = {
    xmovement = mx,
    zmovement = -my,
    yaw = self.yaw,
    pitch = 0.0
  }
  self.client:set_intent(intent)
  self.client:poll()
end

return NetworkScene