namespace("networkscene", "alloverse")

local json = require "json"
local tablex = require "pl.tablex"
local pretty = require "pl.pretty"
local Client = require "alloui.client"
local Stats = require("scenes.stats")

local engines = {
  SoundEng = require "eng.sound_eng",
  GraphicsEng = require "eng.graphics_eng",
  PoseEng = require "eng.pose_eng",
  PhysicsEng = require "eng.physics_eng",
  TextEng = require "eng.text_eng",
}

require "lib.allostring"
local util = require "util"
allonet = util.load_allonet()


-- The responsibilies of NetworkScene are:
-- * Manage the network connection in self.client
-- * Transform incoming messages and states into a format that the engines can work with nicely
-- * Instantiate engines
--
-- Engines should, in turn, manage roughly one component type.
local NetworkScene = classNamed("NetworkScene", OrderedEnt)
function NetworkScene:_init(displayName, url, avatarName)
  print("Starting network scene as", displayName, "connecting to", url, "on a", (lovr.headset and lovr.headset.getName() or "desktop"))
  local avatar = {
    visor = {
      display_name = displayName,
    },
    children = {
      {
        geometry = {
          type = "hardcoded-model",
          name = "avatars/"..avatarName.."/left-hand"
        },
        intent = {
          actuate_pose = "hand/left"
        },
        material= {
          shader_name= "pbr"
        }
      },
      {
        geometry = {
          type = "hardcoded-model",
          name = "avatars/"..avatarName.."/right-hand"
        },
        intent = {
          actuate_pose = "hand/right"
        },
        material= {
          shader_name= "pbr"
        }
      },
      {
        geometry = {
          type = "hardcoded-model",
          name = "avatars/"..avatarName.."/head"
        },
        material= {
          shader_name= "pbr"
        },
        intent = {
          actuate_pose = "head"
        }
      }
    }
  }
  if lovr.headset == nil or lovr.headset.getDriver() == "desktop" then
    table.remove(avatar.children, 2) -- remove right hand as it can't be simulated
  end
  -- base transform for all other engines
  self.transform = lovr.math.newMat4()

  local threadedClient = allonet.create(true)
  self.client = Client(url, displayName, threadedClient)
  
  self.active = true
  self.isOverlayScene = false
  self.head_id = ""
  self.drawTime = 0.0
  self.client.delegates = {
    onStateChanged = function() self:route("onStateChanged") end,
    onEntityAdded = function(e) self:route("onEntityAdded", e) end,
    onEntityRemoved = function(e) self:route("onEntityRemoved", e) end,
    onComponentAdded = function(k, v) self:route("onComponentAdded", k, v) end,
    onComponentChanged = function(k, v, old) self:route("onComponentChanged", k, v, old) end,
    onComponentRemoved = function(k, v) self:route("onComponentRemoved", k, v) end,
    onInteraction = function(inter, body, receiver, sender) self:route("onInteraction", inter, body, receiver, sender) end,
    onDisconnected =  function(code, message) self:route("onDisconnect", code, message) end,
    onAudio = function(...) end -- set from SoundEng
  } 
  if self.client:connect(avatar) == false then
    self:onDisconnect(1003, "Failed to connect")
  end
  self:onStateChanged()
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
    }
    if engines.SoundEng.supported() then
      self.engines.sound = engines.SoundEng()
    end
    
    for _, ename in ipairs({"graphics", "text", "pose", "physics"}) do
      local engine = self.engines[ename]
      engine.client = self.client
      engine:insert(self)
    end
  end
end

function NetworkScene:onStateChanged()
  -- compatibility with older code
  if self.client then
    self.state = self.client.state
  end
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

  for eid, entity in pairs(self.state.entities) do
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
    optchainf(self, "parent.onNetConnected", place_name)
    self.avatar_id = avatar_id
    self:lookForHead()
  end
end   

function NetworkScene:getAvatar()
  if self.avatar_id == "" then	
    return nil
  end
  return self.state.entities[self.avatar_id]
end

function NetworkScene:getHead()
  if self.head_id == "" then	
    return nil
  end
  return self.state.entities[self.head_id]
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
  self.engines.pose.yaw = 0.00001
end

function NetworkScene:onDisconnect(code, message)
  print("disconnecting...")
  if self.client then
    self.client:disconnect(0)
  end
  self.client = nil
  if self.engines then
    for _, engine in pairs(self.engines) do
      engine.client = nil
    end
  end
  local menu = lovr.scenes:transitionToMainMenu()
  menu:setMessage(message and message or "Disconnected.")
  print("disconnected.")
  self:die()
end

function NetworkScene:onDraw(isMirror)
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
    self.transform:set(head.components.transform:getMatrix():invert())
    lovr.graphics.transform(self.transform)
  end


  if self.debug == false then
    return
  end

  for eid, entity in pairs(self.state.entities) do
    local trans = entity.components.transform

    if trans ~= nil then
      local mat = trans:getMatrix()
      local rowmajor_mat = lovr.math.mat4(mat):transpose()
      local pos = mat:mul(lovr.math.vec3())
      local s = string.format("Entity[%s]", eid)
      local parent = entity:getParent()
      if parent then
        s = string.format("%s\nParent: %s", s, parent.id )
      end
      s = string.format("%s\n %.1f %.1f %.1f %.1f\n%.1f %.1f %.1f %.1f\n%.1f %.1f %.1f %.1f\n%.1f %.1f %.1f %.1f", s, rowmajor_mat:unpack(true))
      lovr.graphics.print(s, 
        pos.x, pos.y, pos.z,
        0.001, --  scale
        0, 0, 1, 0,
        0, -- wrap
        "left"
      )
    end
  end
  self.drawTime = lovr.timer.getTime() - atStartOfDraw
end

function NetworkScene:after_onDraw()
  lovr.graphics.pop()
end

function NetworkScene:onUpdate(dt)
  local atStartOfPoll = lovr.timer.getTime()
  if self.client then
    self.client:poll(1.0/40.0)
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

  local stats = Stats.instance
  if stats and not self.isOverlayScene then
    stats:enable(self.debug)
    stats:set("Server time", string.format("%.3fs", self.client.client:get_server_time()))
    stats:set("Client time", string.format("%.3fs", self.client.client:get_time()))
    stats:set("Latency", string.format("%.0fms", self.client.client:get_latency()*1000.0))
    stats:set("C/S clock delta", string.format("%.3fs", self.client.client:get_clock_delta()))
    stats:set("FPS", string.format("%.1fhz", lovr.timer.getFPS()))
    stats:set("Entity count", string.format("%d", self.client.entityCount))
    stats:set("Render duration", string.format("%.0fms", self.drawTime*1000.0))
    stats:set("Network duration", string.format("%.0fms", self.pollTime*1000.0))
    stats:set("Simulation duration", string.format("%.0fms", self.simulateTime*1000.0))
  end


  if self.engines.pose:wasPressed("hand/right", "b") and (not self.isMenu or self.isOverlayScene) then
    lovr.scenes:toggleMenuVisible()
  end
end

return NetworkScene