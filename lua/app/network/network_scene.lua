namespace("networkscene", "alloverse")

local json = require "json"
local tablex = require "pl.tablex"
local pretty = require "pl.pretty"
local Client = require "alloui.client"

local engines = {
  SoundEng = require "eng.sound_eng",
  GraphicsEng = require "eng.graphics_eng",
  PoseEng = require "eng.pose_eng",
  PhysicsEng = require "eng.physics_eng"
}
local OverlayMenuScene = require "app.menu.overlay_menu_scene"
require "lib.random_string"
local util = require "util"
--allonet = util.load_allonet()


-- The responsibilies of NetworkScene are:
-- * Manage the network connection in self.client
-- * Transform incoming messages and states into a format that the engines can work with nicely
-- * Instantiate engines
--
-- Engines should, in turn, manage roughly one component type.
local NetworkScene = classNamed("NetworkScene", Ent)
function NetworkScene:_init(displayName, url)
  local avatar = {
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
        collider = {
          type = "box",
          width = 0.1,
          height = 0.1,
          depth = 0.1
        },
        intent = {
          actuate_pose = "head"
        }
      }
    }
  }
  if lovr.headset.getDriver() == "desktop" then
    table.remove(avatar.children, 2) -- remove right hand as it can't be simulated
  end
  self.client = Client(url, displayName)
  
  self.head_id = ""
  self.client.delegates = {
    onStateChanged = function() self:route("onStateChanged") end,
    onEntityAdded = function(e) self:route("onEntityAdded", e) end,
    onEntityRemoved = function(e) self:route("onEntityRemoved", e) end,
    onComponentAdded = function(k, v) self:route("onComponentAdded", k, v) end,
    onComponentChanged = function(k, v) self:route("onComponentChanged", k, v) end,
    onComponentRemoved = function(k, v) self:route("onComponentRemoved", k, v) end,
    onInteraction = function(inter, body, receiver, sender) self:route("onInteraction", inter, body, receiver, sender) end,
    onDisconnected =  function(code, message) self:route("onDisconnect", code, message) end
  } 
  if self.client:connect(avatar) == false then
    self:onDisconnect(1003, "Failed to connect")
  end

  self:super()
end

function NetworkScene:onLoad()
  if self.client ~= nil then
    -- Engines. These do the heavy lifting.
    self.engines = {
      graphics = engines.GraphicsEng(),
      sound = engines.SoundEng(),
      pose = engines.PoseEng(),
      physics = engines.PhysicsEng()
    }
    for _, engine in pairs(self.engines) do
      engine.client = self.client
      engine:insert(self)
    end
  end
end

function NetworkScene:onStateChanged()
  -- compatibility with older code
  self.state = self.client.state
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

function NetworkScene:onInteraction(interaction)
  if interaction.type == "response" and interaction.body[1] == "announce" then
    local avatar_id = interaction.body[2]
    local place_name = interaction.body[3]
    print("Welcome to", place_name, ". You are", avatar_id)
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

function NetworkScene:onDisconnect(code, message)
  print("disconnecting...")
  self.client.client:disconnect(0)
  self.client = nil
  if self.engines then
    for _, engine in pairs(self.engines) do
      engine.client = nil
    end
  end
  local menu = lovr.scenes.menu():insert()
  menu:setMessage(message)
  print("disconnected.")
  queueDoom(self)
end

function NetworkScene:onDraw()
  -- Move camera to root entity of avatar. Lovr's standard projection
  -- matrix will then move it to the head (while allonet's pose application
  -- will also move the head entity to the same location).
  -- If this ends up not working, we could also set the projection matrix
  -- to use the avatar's head entity as the base for the camera.
  -- Do this before any sub-engines start trying to draw anything.
  local avatar = self:getAvatar()
  if avatar then
    lovr.graphics.transform(avatar.components.transform:getMatrix():invert())
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
end

function NetworkScene:onUpdate(dt)
  if self.client ~= nil then
    self.client.client:poll()
    if self.client == nil then
      return route_terminate
    end
  else
    return route_terminate
  end

  self.client.client:simulate(dt)


  if lovr.headset.wasPressed("hand/right", "b") then
    OverlayMenuScene(self):insert(self)
  end
end

lovr.scenes.network = NetworkScene

return NetworkScene