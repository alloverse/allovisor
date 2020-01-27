namespace("networkscene", "alloverse")

local json = require "json"
local Entity, componentClasses = unpack(require("app.network.entity"))
local SoundEng = require "app.network.sound_eng"
local GraphicsEng = require "app.network.graphics_eng"

-- load allonet from dll
local os = lovr.getOS()    
local err = nil
local pkg = nil
if os == "Windows" then
  local exepath = lovr.filesystem.getExecutablePath()
  local dllpath = string.gsub(exepath, "%w+.exe", "liballonet.dll")
  print("loading liballonet from "..dllpath.."...")
  pkg, err = package.loadlib(dllpath, "luaopen_liballonet")
elseif os == "macOS" or os == "Android" then
  print("loading liballonet from exe...")
  local manualpath = "/Users/kask/Alloverse/allovisor-lovr/build/Alloverse.app/Contents/MacOS/lovr"
  pkg, err = package.loadlib(manualpath, "luaopen_liballonet")
else
  error("don't know how to load allonet")
end
if pkg == nil then
    error("Failed to load allonet: "..err)
end   
allonet = pkg()
print("allonet loaded")


-- The responsibilies of NetworkScene are:
-- * Manage the network connection in self.client
-- * Transform incoming messages and states into a format that the engines can work with nicely
-- * Instantiate engines
--
-- Engines should, in turn, manage roughly one component type.
local NetworkScene = classNamed("NetworkScene", Ent)
function NetworkScene:_init(displayName, url)
  self.client = allonet.connect(
    url,
    json.encode({display_name = displayName}),
    json.encode({
      children = {
        {
          geometry = {
            type = "hardcoded-model",
            name = "lefthand"
          },
          intent = {
            actuate_pose = "hand/left"
          }
        },
        {
          geometry = {
            type = "hardcoded-model",
            name = "righthand"
          },
          intent = {
            actuate_pose = "hand/right"
          }
        },
        {
          geometry = {
            type = "hardcoded-model",
            name = "head"
          },
          intent = {
            actuate_pose = "head"
          }
        }
      },
      live_media = {
        track_id = 0,
        sample_rate = 48000,
        channel_count = 1,
        format = "opus"
	  }
    })
  )
  self.state = {
    entities = {}
  }
  self.client:set_state_callback(function() self:route("onStateChanged") end)
  self.client:set_disconnected_callback(function() self:route("onDisconnect") end)
  self.yaw = 0.0
  
  self:super()

  -- Engines. These do the heavy lifting.
  SoundEng():insert(self)
  GraphicsEng():insert(self)
end

function NetworkScene:onStateChanged()
  local state = self.client:get_state()
  -- Make Entities and their Components classes so they get convenience methods from entity.lua
  local getSibling = function(id) return state.entities[id] end

  for eid, entity in pairs(state.entities) do
    setmetatable(entity, Entity)
    entity.getSibling = getSibling
    local getEntity = function() return entity end
    for cname, cval in pairs(entity.components) do
      local klass = componentClasses[cname]
      setmetatable(cval, klass)
      cval.getEntity = getEntity
    end
  end
  self.state = state
end

function NetworkScene:onLoad()
  --world = lovr.physics.newWorld()
end

function NetworkScene:onDisconnect()
  print("disconnecting...")
  self.client:disconnect(0)
  scene:insert(lovr.scenes.menu)
  queueDoom(self)
end

function NetworkScene:onDraw()
end

function pose2matrix(x, y, z, angle, ax, ay, az)
  local mat = lovr.math.mat4()
  mat:translate(x, y, z)
  mat:rotate(angle, ax, ay, az)
  return mat
end

function NetworkScene:onUpdate(dt)
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
  
  self.client:set_intent(intent)
  self.client:poll()
end

lovr.scenes.network = NetworkScene

return NetworkScene