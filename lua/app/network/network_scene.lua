namespace("networkscene", "alloverse")

local json = require "json"
local Entity, componentClasses = unpack(require("app.network.entity"))
local SoundEng = require "app.network.sound_eng"
local GraphicsEng = require "app.network.graphics_eng"
local PoseEng = require "app.network.pose_eng"

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
  pkg, err = package.loadlib(lovr.filesystem.getExecutablePath(), "luaopen_liballonet")

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
  
  self:super()
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
  -- Engines. These do the heavy lifting.
  SoundEng():insert(self)
  GraphicsEng():insert(self)
  PoseEng():insert(self)

  --world = lovr.physics.newWorld()
end

function NetworkScene:onDisconnect()
  print("disconnecting...")
  self.client:disconnect(0)
  self.client = nil
  lovr.scenes.menu():insert()
  print("disconnected.")
  queueDoom(self)
end

function NetworkScene:onDraw()
end

function NetworkScene:onUpdate(dt)
  if self.client ~= nil then
    self.client:poll()
    if self.client == nil then
      return route_terminate
    end
  else
    return route_terminate
  end
end

lovr.scenes.network = NetworkScene

return NetworkScene