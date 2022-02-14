--- The Allovisor network scene.
-- The responsibilies of NetworkScene are:
--
-- * Manage the network connection in self.client
-- * Transform incoming messages and states into a format that the engines can work with nicely
-- * Instantiate engines
--
-- Engines should, in turn, manage roughly one component type.
-- @classmod NetworkScene

namespace("networkscene", "alloverse")

local tablex = require "pl.tablex"
local pretty = require "pl.pretty"
local Client = require "alloui.client"
local ui = require("alloui.ui")
local Asset = require("lib.alloui.lua.alloui.asset")
local AlloAvatar = require("lib.alloavatar")
local StandardWidgets = require("lib.standard_widgets")

local engines = {
  SoundEng = require "eng.sound_eng",
  GraphicsEng = require "eng.graphics_eng",
  PoseEng = require "eng.pose_eng",
  PhysicsEng = require "eng.physics_eng",
  TextEng = require "eng.text_eng",
  AssetsEng = require "eng.assets_eng",
  StatsEng = require("eng.stats_eng"),
}

require "lib.allostring"
local util = require "lib.util"

local NetworkScene = classNamed("NetworkScene", OrderedEnt)
function NetworkScene:_init(displayName, url, avatarName, isSpectatorCamera)
  print("Starting network scene as", displayName, isSpectatorCamera and "(cam)" or "(user)", "connecting to", url, "on a", (lovr.headset and lovr.headset.getName() or "desktop"))
  

  self.displayName = displayName
  self.isSpectatorCamera = isSpectatorCamera

  local assets = AlloAvatar:loadAssets()
  self.avatarView = AlloAvatar(nil, self.displayName, avatarName, self, isSpectatorCamera)

  -- turn this off to fall back to make server decide where visors can move
  self.useClientAuthoritativePositioning = true
  self.avatarView.useClientAuthoritativePositioning = true

  -- base transform for all other engines
  self.cameraTransform = lovr.math.newMat4()
  self.inverseCameraTransform = lovr.math.newMat4()

  self.viewPoseStack = {}

  local threadedClient = allonet.create(true)
  self.url = url
  self.client = Client(url, displayName, threadedClient)
  self.app = ui.App(self.client)
  self.app.mainView = self.avatarView
  
  self.active = true
  self.isOverlayScene = false
  self.head_id = ""
  self.drawTime = 0.0
  self.standardDt = 1.0/40.0
  self.client.delegates.onEntityAdded = function(e) self:route("onEntityAdded", e) end
  self.client.delegates.onEntityRemoved = function(e) self:route("onEntityRemoved", e) end
  self.client.delegates.onComponentAdded = function(k, v) 
    self.app:onComponentAdded(k, v)
    self:route("onComponentAdded", k, v) 
  end
  self.client.delegates.onComponentChanged = function(k, v, old) self:route("onComponentChanged", k, v, old) end
  self.client.delegates.onComponentRemoved = function(k, v) self:route("onComponentRemoved", k, v) end
  self.client.delegates.onInteraction = function(inter, body, receiver, sender) 
    self.app:onInteraction(inter, body, receiver, sender)
    self:route("onInteraction", inter, body, receiver, sender) 
  end
  self.client.delegates.onDisconnected =  function(code, message)
    self:onDisconnect(code, message)
  end

  self.assetManager = Asset.Manager(self.client.client)
  self.assetManager:add(assets, true)
  local ok, error = pcall(self.app.connect, self.app)
  if not ok  then
    self:onDisconnect(1003, error)
  end
  
  self:super()
end

function NetworkScene:onLoad()
  if self.client ~= nil then
    -- Engines. These do the heavy lifting.
    self.engines = {
      graphics = engines.GraphicsEng(),
      pose = engines.PoseEng(),
      physics = engines.PhysicsEng(),
      text = engines.TextEng(),
      assets = engines.AssetsEng(),
      stats = engines.StatsEng(),
    }
    if engines.SoundEng.supported() then
      self.engines.sound = engines.SoundEng()
    end
    
    for _, ename in ipairs({"graphics", "text", "pose", "physics", "sound", "assets", "stats"}) do
      local engine = self.engines[ename]
      if engine then
        engine.client = self.client
        engine:insert(self)
      end
    end
  end

  self:scheduleCleanup(Store.singleton():listen("debug", function(debug)
    self.debug = debug
  end))
end

function NetworkScene:setActive(newActive)
  self.active = newActive
end

function NetworkScene:onComponentAdded(cname, component)
  if cname == "intent" and component.actuate_pose == "head" then
    self:lookForHead()
  end
end

-- See if we can find our head entity plz
function NetworkScene:lookForHead()
  if self.head_id ~= "" then return end
  if self.avatar_id == "" then return end

  for eid, entity in pairs(self.client.state.entities) do
    if 
      entity.components.intent and entity.components.intent.actuate_pose == "head" and 
      entity.components.relationships and entity.components.relationships.parent == self.avatar_id then
      print("Avatar's head entity:", eid)
      self.head_id = eid
      self:route("onHeadAdded", entity)
    end
  end
end

function NetworkScene:onInteraction(interaction, body, receiver, sender)
  if interaction.type == "response" and body[1] == "announce" then
    local avatar_id = body[2]
    local place_name = body[3]
    print("Welcome to", place_name, ". You are", avatar_id)
    self.avatar_id = avatar_id
    self.place_name = place_name
    self:lookForHead()
    self.standardWidgets = StandardWidgets():insert(self)
    self.standardWidgets:addAllWidgetsTo(self.avatarView, self)

    ent.root:route("onNetConnected", self, self.url, place_name)
    lovr.onNetConnected(self, self.url, place_name)
  end
end   

function NetworkScene:getAvatar()
  if self.avatar_id == "" then	
    return nil
  end
  return self.client.state.entities[self.avatar_id]
end

function NetworkScene:getHead()
  if self.head_id == "" then	
    return nil
  end
  return self.client.state.entities[self.head_id]
end

function NetworkScene:moveToOrigin()
  self.client:sendInteraction({
    type = "request",
    receiver_entity_id = "place",
    body = {"change_components", self.avatar_id, "add_or_change", {
      transform= {
        matrix={lovr.math.mat4():unpack(true)}
      }
    }, "remove", {}}
  })
  self.engines.pose.yaw = 0.0
end

function NetworkScene:onDisconnect(code, message)
  print("Network scene was disconnected from", self.place_name, code, message, ", tearing down...")
  if self.engines then
    for _, engine in pairs(self.engines) do
      engine.client = nil
      if engine.onDisconnect then engine:onDisconnect() end
    end
  end
  local client = self.client
  self.client = nil
  if client then
    -- this will destroy the client instance
    client:disconnect(0)
  end
  local menu = lovr.scenes:transitionToMainMenu()
  menu:setMessage(message and message or "Disconnected.")
  print("Network scene finished disconnecting.")
  self:die()
end

function NetworkScene:onDraw(isMirror)
  if not self.active then
    return route_terminate
  end
  local atStartOfDraw = lovr.timer.getTime()
  lovr.graphics.push()
  drawMode()

  lovr.graphics.setCullingEnabled(true)
  lovr.graphics.setDepthTest('lequal', true)

  -- Move camera to head, as if we're looking out the head's eyes.
  -- Do this before any sub-engines start trying to draw anything.
  local head = self:getHead()
  if not isMirror then
    -- can't figure out how to remove the headset module's transform from avatar root to head,
    -- so just offset from body instead.
    head = self:getAvatar()
  end
  if head then
    self.viewPoseStack = {
      lovr.math.newMat4(lovr.graphics.getViewPose(1)),
      lovr.math.newMat4(lovr.graphics.getViewPose(2)),
    }
    self.inverseCameraTransform:set(head.components.transform:getMatrix())
    self.cameraTransform:set(self.inverseCameraTransform):invert()
    
    -- Lovr puts the headset view pose into the lovr.graphics.viewPose
    -- We want to move the camera and then look around that point with the headset

    -- Some weirdness this relies on atm: 
    -- On desktop the camera is the head position, but the viewPose is identity
    -- On headset the camera is the avatar position, but the viewPose is from floor level

    for i = 1,2 do
      local pose = lovr.math.mat4(lovr.graphics.getViewPose(i))
      local camera = lovr.math.mat4(self.inverseCameraTransform)
      camera:mul(pose)
      lovr.graphics.setViewPose(i, camera, false)
    end
  end

  self.drawTime = lovr.timer.getTime() - atStartOfDraw
end

function NetworkScene:onMirror( )
  if not self.active then
    return route_terminate
  end
end

function NetworkScene:after_onDraw()
  if not self.active then
    return route_terminate
  end
  if self.debug then
    self:route("onDebugDraw")
  end
  if #self.viewPoseStack == 2 then
    lovr.graphics.setViewPose(1, self.viewPoseStack[1])
    lovr.graphics.setViewPose(2, self.viewPoseStack[2])
    self.viewPoseStack = {}
  end
  lovr.graphics.pop()
end

function NetworkScene:onKeyPress(key)
  if not self.active then
    return route_terminate
  end

end

function NetworkScene:onKeyReleased(key)
  if not self.active then
    return route_terminate
  end
end

function NetworkScene:onTextInput(key)
  if not self.active then
    return route_terminate
  end
end
function NetworkScene:onMouseMoved(key)
  if not self.active then
    return route_terminate
  end
end
function NetworkScene:onMousePressed(key)
  if not self.active then
    return route_terminate
  end
end
function NetworkScene:onPress(key)
  if not self.active then
    return route_terminate
  end
end
function NetworkScene:onMouseReleased(key)
  if not self.active then
    return route_terminate
  end
end
function NetworkScene:onFileDrop(key)
  if not self.active then
    return route_terminate
  end
end



function NetworkScene:onUpdate(dt)
  if not self.active then
    return route_terminate
  end
  local atStartOfPoll = lovr.timer.getTime()
  if self.client then
    self.app:runOnce(self.standardDt)
    if self.client == nil then
      return route_terminate
    end
  else
    return route_terminate
  end
  self.pollTime = lovr.timer.getTime() - atStartOfPoll

  local atStartOfSimulate = lovr.timer.getTime()
  self.client:simulate()
  self.simulateTime = lovr.timer.getTime() - atStartOfSimulate

  local stats = self.engines.stats
  if stats then
    stats:enable(self.debug)
    stats:set("Clocks", string.format(
      "Server %.3fs\nClient %.3fs", 
      self.client.client:get_server_time(),
      self.client.client:get_time()
    ))
    stats:set("Network stats", self.client.client:get_stats())
    stats:set("Latency", string.format("%.0fms", self.client.client:get_latency()*1000.0))
    stats:set("C/S clock delta", string.format("%.3fs", self.client.client:get_clock_delta()))
    stats:set("FPS", string.format("%.1fhz", lovr.timer.getFPS()))
    stats:set("Entity count", string.format("%d", self.client.entityCount))
    stats:set("Durations", string.format(
      "Render %.1fms\nNetwork %.1fms\nSimulation %.1fms", 
      self.drawTime*1000.0,
      self.pollTime*1000.0,
      self.simulateTime*1000.0
    ))
  end
end

return NetworkScene
