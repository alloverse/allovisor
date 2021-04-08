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
local Stats = require("scenes.stats")
local Asset = require("lib.alloui.lua.alloui.asset")

local engines = {
  SoundEng = require "eng.sound_eng",
  GraphicsEng = require "eng.graphics_eng",
  PoseEng = require "eng.pose_eng",
  PhysicsEng = require "eng.physics_eng",
  TextEng = require "eng.text_eng",
  AssetsEng = require "eng.assets_eng",
}

local assets = {
  nameTag = Asset.Base64("iVBORw0KGgoAAAANSUhEUgAAAMAAAABACAMAAAB7sojtAAABKVBMVEUAAAA4OFA1Mko3NUo3Nkw3NUw3NUs3NUw2NEw2M0k4MFA4NEw3NU03NUs0NExAMFA2Nkw2NEw3NU02Nks2NEw3NUw3NUxcW22OjZq0s7za2d3m5uj////NzNKop7E3NUw3N0s3NU1paHjy8vTm5uk3NUyCgY83NUvl5ehQTmI3NUxEQlenp7CnprA4NEw1NUtcWm7x8fP+/v41NUpAMECmpbA2Nkw2NUxpZ3nMy9GCgI/a2t42NUtdW243NUo2M0xcWm01Mk2PjZo3NEyzsrw3Nks2NUzY2Nw2NUvMzNG0s7s3M0w3NEo4OEg3NUs3NU04NEw4NkswMFCnp7GnprFDQlc5NEs3NEw3NEs2NUvNzdI3NEza2t04NUpAQEA2NUw3NUw2NE02NExc4EV1AAAAY3RSTlMAIGCQr8/f/4BQIEDfn0AQf+/eX+5vv///////////7nCP/////v+e//++////f47///9gEP+A7/////+g/49Q/2D/r/+vz//O//+QTyDenoBfEP///3C/cJ//vv9gEKCQr89JTxAdAAACbklEQVR4AezZA7YlQQwG4Dx17lybebZt27b3v4uZ6s7pa4yTc963gcJfSaOgmqbmltY2CwWw2lo937zwU3wtFgrjDwShQaFwBEWKxrxqp8/i4bpLSMidPqcAtXiTKF7U2+D2p9KZbI4EyLV3pFOY19kFVXSjq6ejl0Tpy+TX0B+GigL56beTQNkBZDgIFbQJnj4bGkY2Un3/R8dIsPHRahlMoGOY61Z8CJMl/QcdU70k3PQUV3IXFPBy/xwgBbiWO72Q5+f9Jw1mpsoKeZbPfy+pMD1ccoi8TgCjOVJiaBSNzrniJ/AYqTGPtgUOYBGNFOkxs8QRFFZAjhRZ5ggKWtAKkcII4Acf2laJ9EXQHwSANTTWiTRGsOGeoAwpM45GFMCrrYTZNBr9TbCp7QSxmS17AdvgQSNN6uxwEezyU1idPTT24QCNdlLnEI0jsNTVMBviNoQ20mcGjf6vBfyurwWoL+IDde+i7Jjb6C4aJ6TOOD/ITnW/SnigWffL3Bmco61XZw33nwO3oTGd73IXAFwESypPEF7mP+rb9b2L8kc9LGqMYIBPkHGlMAIu4WswbvRFMDOMRuc5FEZwS2rc5f8sFkRwr+33+sU5sAedFxzX4HrUeMV0AXnni2hbUXTJFz+HAg/6rlmfoMiptovuBSixho570d20YxQdz1DmANm62BBelpC9AivJgK28SZ1+lf1nV+iaygiLobdjCV0bUMXDIuZNpTteRKwi95ZJT2Fe/AmqOrdQvNdzqOVd+BJqbD87P42gWJGrD6jvnFNQOX3m+xS3Buv7ErgZSAK+9hyJSYNj+X1SYgITIy53AgCT+DcB0RKo5AAAAABJRU5ErkJggg=="),
}

require "lib.allostring"
local util = require "lib.util"

local NetworkScene = classNamed("NetworkScene", OrderedEnt)
function NetworkScene:_init(displayName, url, avatarName, isSpectatorCamera)
  print("Starting network scene as", displayName, isSpectatorCamera and "(cam)" or "(user)", "connecting to", url, "on a", (lovr.headset and lovr.headset.getName() or "desktop"))
  
  local avatarsRoot = "/assets/models/avatars"
  for _, avatarName in ipairs(lovr.filesystem.getDirectoryItems(avatarsRoot)) do
    for _, partName in ipairs({"head", "left-hand", "right-hand", "torso"}) do
      local path = avatarsRoot.."/"..avatarName.."/"..partName..".glb"
      if lovr.filesystem.isFile(path) then 
        assets["avatars/"..avatarName.."/"..partName] = Asset.LovrFile(avatarsRoot.."/"..avatarName.."/"..partName..".glb", true)
      else
        print(path .. " is not an avatar file")
      end
    end
  end
  
  self.displayName = displayName
  self.isSpectatorCamera = isSpectatorCamera
  local avatar = self:avatarSpec(avatarName)

  -- turn this off to fall back to make server decide where visors can move
  self.useClientAuthoritativePositioning = true
  if self.useClientAuthoritativePositioning then
    avatar.intent = {
      actuate_pose = "root"
    }
  end

  -- base transform for all other engines
  self.cameraTransform = lovr.math.newMat4()
  self.inverseCameraTransform = lovr.math.newMat4()

  self.viewPoseStack = {}

  local threadedClient = allonet.create(true)
  self.url = url
  self.client = Client(url, displayName, threadedClient)
  
  self.active = true
  self.isOverlayScene = false
  self.head_id = ""
  self.drawTime = 0.0
  self.standardDt = 1.0/40.0
  self.client.delegates.onEntityAdded = function(e) self:route("onEntityAdded", e) end
  self.client.delegates.onEntityRemoved = function(e) self:route("onEntityRemoved", e) end
  self.client.delegates.onComponentAdded = function(k, v) self:route("onComponentAdded", k, v) end
  self.client.delegates.onComponentChanged = function(k, v, old) self:route("onComponentChanged", k, v, old) end
  self.client.delegates.onComponentRemoved = function(k, v) self:route("onComponentRemoved", k, v) end
  self.client.delegates.onInteraction = function(inter, body, receiver, sender) self:route("onInteraction", inter, body, receiver, sender) end
  self.client.delegates.onDisconnected =  function(code, message) self:route("onDisconnect", code, message) end

  self.assetManager = Asset.Manager(self.client.client)
  self.assetManager:add(assets, true)
  if self.client:connect(avatar) == false then
    self:onDisconnect(1003, "Failed to connect")
  end
  self:super()
end

function NetworkScene:avatarSpec(avatarName)
  if self.isSpectatorCamera then
    return self:cameraSpec()
  end

  local avatar = {
    visor = {
      display_name = self.displayName,
    },
    children = {
      {
        geometry = {
          type = "asset",
          name = assets["avatars/"..avatarName.."/left-hand"]:id()
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
          type = "asset",
          name = assets["avatars/"..avatarName.."/right-hand"]:id()
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
          type = "asset",
          name = assets["avatars/"..avatarName.."/head"]:id()
        },
        material= {
          shader_name= "pbr"
        },
        intent = {
          actuate_pose = "head"
        }
      },
      {
        geometry = {
          type = "asset",
          name = assets["avatars/"..avatarName.."/torso"]:id()
        },
        material= {
          shader_name= "pbr"
        },
        intent = {
          actuate_pose = "torso"
        },
        children = {
          {
            geometry = {
              type = "inline",
              vertices=   {{-0.1, -0.033, 0.0},  {0.1, -0.033, 0.0},  {-0.1, 0.033, 0.0}, {0.1, 0.033, 0.0}},
              uvs=        {{0.0, 0.0},          {1.0, 0.0},         {0.0, 1.0},        {1.0, 1.0}},
              triangles=  {{0, 1, 3},           {0, 3, 2},          {1, 0, 2},         {1, 2, 3}},
            },
            material = {
              texture = assets.nameTag:id(),
              hasTransparency = true
            },
            transform = {
              matrix={
                lovr.math.mat4():rotate(3.14, 0, 1, 0):translate(0, 0.3, 0.05):rotate(-3.14/8, 1, 0, 0):unpack(true)
              }
            },
            children = {
              {
                text = {
                  string = self.displayName,
                  height = 0.66,
                  wrap = 0,
                  halign = "center",
                  fitToWidth = 0.16
                },
                material = {
                  color = {0.21484375,0.20703125,0.30078125,1}
                }
              }
            }
          }
        }
      }
    }
  }
  if lovr.headset == nil or lovr.headset.getDriver() == "desktop" then
    table.remove(avatar.children, 2) -- remove right hand as it can't be simulated
  end

  return avatar
end

function NetworkScene:cameraSpec()
  local avatarName = "animal"
  return {
    visor = {
      display_name = self.displayName,
    },
    children = {
      {
        intent = {
          actuate_pose = "hand/left"
        }
      },
      {
        geometry = {
          type = "asset",
          name = assets["avatars/"..avatarName.."/head"]:id()
        },
        material= {
          shader_name= "pbr"
        },
        intent = {
          actuate_pose = "head"
        }
      },
    }
  }
  
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
    }
    if engines.SoundEng.supported() then
      self.engines.sound = engines.SoundEng()
    end
    
    for _, ename in ipairs({"graphics", "text", "pose", "physics", "sound", "assets"}) do
      local engine = self.engines[ename]
      if engine then
        engine.client = self.client
        engine:insert(self)
      end
    end
  end

  if self.isSpectatorCamera and self.parent.hideOverlay then
    self.parent:hideOverlay()
  end

  self.unsub = Store.singleton():listen("debug", function(debug)
    self.debug = debug
  end)
end

function NetworkScene:onDie()
  if self.unsub then self.unsub() end
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
    self:lookForHead()

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
    self.viewPoseStack = {
      lovr.math.mat4(lovr.graphics.getViewPose(1)),
      lovr.math.mat4(lovr.graphics.getViewPose(2)),
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

function NetworkScene:onDebugDraw()
  lovr.graphics.setShader()
  lovr.graphics.setColor(1,1,1,1)
  for eid, entity in pairs(self.client.state.entities) do
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
        0.01, --  scale
        0, 0, 1, 0,
        0, -- wrap
        "left"
      )
    end
  end
end

function NetworkScene:after_onDraw()
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

function NetworkScene:onUpdate(dt)
  local atStartOfPoll = lovr.timer.getTime()
  if self.client then
    self.client:poll(self.standardDt)
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

function NetworkScene:onButtonPressed(device, button)
  if self.isMenu then return end -- can't toggle menu from menu

  if button == "menu" then
    lovr.scenes:setMenuVisible(not self.isOverlayScene)
  end
end

return NetworkScene
