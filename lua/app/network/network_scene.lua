namespace("networkscene", "alloverse")

local json = require "json"
local tablex = require "pl.tablex"
local pretty = require "pl.pretty"
local Entity, componentClasses = unpack(require("app.network.entity"))
local SoundEng = require "app.network.sound_eng"
local GraphicsEng = require "app.network.graphics_eng"
local PoseEng = require "app.network.pose_eng"
local PhysicsEng = require "app.network.physics_eng"
local OverlayMenuScene = require "app.menu.overlay_menu_scene"
require "lib.random_string"

-- load allonet from dll
local os = lovr.getOS()    
local err = nil
local pkg = nil
if os == "Windows" then
  local exepath = lovr.filesystem.getExecutablePath()
  local dllpath = string.gsub(exepath, "%w+.exe", "liballonet.dll")
  print("loading liballonet from "..dllpath.."...")
  pkg, err = package.loadlib(dllpath, "luaopen_liballonet")
elseif os == "macOS" then
  print("loading liballonet from exe...")
  pkg, err = package.loadlib(lovr.filesystem.getExecutablePath(), "luaopen_liballonet")
elseif os == "Android" then
  print("loading liballonet from liblovr.so...")
  pkg, err = package.loadlib("liblovr.so", "luaopen_liballonet")
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
  self.avatar_id = ""
  self.outstanding_response_callbacks = {}
  self.client:set_state_callback(function() self:route("onStateChanged") end)
  self.client:set_interaction_callback(function(inter) self:onInteractionInternal(inter) end)
  self.client:set_disconnected_callback(function() self:route("onDisconnect") end)
  
  self:super()
end

function NetworkScene:onStateChanged()
  local newState = self.client:get_state()
  local oldEntities = tablex.copy(self.state.entities)

  -- Compare existing state to the new incoming state, and apply appropriate functions when we're done.
  local newEntities = {}
  local deletedEntities = {}
  local newComponents = {}
  local updatedComponents = {}
  local deletedComponents = {}

  -- While at it, also make Entities and their Components classes so they get convenience methods from entity.lua

  -- Entity:getSibling(eid) to get any entity from an entity.
  local getSibling = function(id) return self.state.entities[id] end

  for eid, newEntity in pairs(newState.entities) do
    local existingEntity = oldEntities[eid]
    local entity = existingEntity
    -- Check for new entity
    if entity == nil then
      entity = newEntity
      setmetatable(entity, Entity)
      entity.getSibling = getSibling
      table.insert(newEntities, entity)
      tablex.insertvalues(newComponents, entity.components)
      self.state.entities[eid] = newEntity
    end
    
    -- Component:getEntity()
    local getEntity = function() return entity end

    -- Check for new or updated components
    for cname, newComponent in pairs(newEntity.components) do
      local oldComponent = existingEntity and existingEntity.components[cname]
      if oldComponent == nil then
        -- it's a new component
        local klass = componentClasses[cname]
        setmetatable(newComponent, klass)
        newComponent.getEntity = getEntity
        newComponent.key = cname
        entity.components[cname] = newComponent
        table.insert(newComponents, newComponent)
      elseif tablex.deepcompare(oldComponent, newComponent, false) == false then
        -- it's a changed component
        table.insert(updatedComponents, oldComponent)
        tablex.update(oldComponent, newComponent)
      end
    end
    -- Check for deleted components
    if existingEntity ~= nil then
      for cname, oldComponent in pairs(existingEntity.components) do
        local newComponent = newEntity.components[cname]
        if newComponent == nil then
          table.insert(deletedComponents, oldComponent)
          entity.components[cname] = nil
        end
      end
    end
  end

  -- check for deleted entities
  for eid, oldEntity in pairs(oldEntities) do
    local newEntity = newState.entities[eid]
    if newEntity == nil then
      table.insert(deletedEntities, oldEntity)
      tablex.insertvalues(deletedComponents, oldEntity.components)
      self.state.entities[eid] = nil
    end
  end

  -- Run callbacks
  --if #newEntities > 0 then print("New entities: ", pretty.write(newEntities)) end
  --if #deletedEntities > 0 then print("Removed entities: ", pretty.write(deletedEntities)) end
  --if #newComponents > 0 then print("New components: ", pretty.write(newComponents)) end
  --if #deletedComponents > 0 then print("Removed components: ", pretty.write(deletedComponents)) end
  tablex.map(function(x) self:route("onEntityAdded", x) end, newEntities)
  tablex.map(function(x) self:route("onEntityRemoved", x) end, deletedEntities)
  tablex.map(function(x) self:route("onComponentAdded", x.key, x) end, newComponents)
  tablex.map(function(x) self:route("onComponentChanged", x.key, x) end, updatedComponents)
  tablex.map(function(x) self:route("onComponentRemoved", x.key, x) end, deletedComponents)
end

function NetworkScene:onInteractionInternal(interaction)
  interaction.body = json.decode(interaction.body)
  self:route("onInteraction", interaction)
end

function NetworkScene:onInteraction(interaction)
  if interaction.type == "response" and interaction.body[1] == "announce" then
    local avatar_id = interaction.body[2]
    local place_name = interaction.body[3]
    print("Welcome to", place_name, ". You are", avatar_id)
    self.avatar_id = avatar_id
  elseif interaction.type == "response" then
    local callback = self.outstanding_response_callbacks[interaction.request_id]
    if callback ~= nil then
      callback(interaction)
      self.outstanding_response_callbacks[interaction.request_id] = nil
    end
  end
end

function NetworkScene:sendInteraction(interaction, callback)
  if interaction.sender_entity_id == nil then
    assert(self.avatar_id ~= nil)
    interaction.sender_entity_id = self.avatar_id
  end
  if interaction.type == "request" then
    interaction.request_id = string.random(16)
    if callback ~= nil then
      self.outstanding_response_callbacks[interaction.request_id] = callback
    end
  else
    interaction.request_id = "" -- todo, fix this in allonet
  end
  interaction.body = json.encode(interaction.body)
  self.client:send_interaction(interaction)
end

function NetworkScene:getAvatar()
  if self.avatar_id == "" then	
	return nil
  end
  return self.state.entities[self.avatar_id]
end

function NetworkScene:onLoad()
  -- Engines. These do the heavy lifting.
  self.sound = SoundEng():insert(self)
  self.graphics = GraphicsEng():insert(self)
  self.pose = PoseEng():insert(self)
  self.physics = PhysicsEng():insert(self)
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

  if lovr.headset.wasPressed("hand/right", "b") then
    OverlayMenuScene(self):insert(self)
  end
end

lovr.scenes.network = NetworkScene

return NetworkScene