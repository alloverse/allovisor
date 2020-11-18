--- The Allovisor menu apps.
-- @classmod NetMenuScene

namespace("menu", "alloverse")
local NetworkScene = require("scenes.network_scene")


--- Connects to the menuserv local server that hosts allo apps presenting menues.
-- This scene doesn't have any UI. It just connects to menuserv,
-- which has its own AlloApps running, providing UI. These in turn
-- perform their actions by sending allo interactions back to this scene.
-- So you could say, this is a "controller" class and the alloapps are
-- plain MVC views.
local NetMenuScene = classNamed("NetMenuScene", Ent)

--- Registers user interactions.
-- Delegates user input to the appropriate menu alloapp through menuserv
local MenuInteractor = classNamed("MenuInteractor", Ent)

--- lovr settings.
local settings = require("lib.lovr-settings")


function NetMenuScene:_init(menuServerPort)
  self.menuServerPort = menuServerPort
  self.sendQueue = {}
  self.apps = {}
  self.visible = true
  settings.load()
  self.settings = settings
  self:setupAvatars()
  if not settings.d.currentMicrophone then
    settings.d.currentMicrophone = lovr.audio and lovr.audio.getMicrophoneNames()[1]
    if not settings.d.currentMicrophone then settings.d.currentMicrophone = "Mute" end
  end
  self:updateDebugTitle()
  self:super()
end

--- Setup.
-- Connects to the menuserlv and starts the interactor
function NetMenuScene:onLoad()
  self.net = NetworkScene("owner", "alloplace://localhost:"..tostring(self.menuServerPort), settings.d.avatarName)
  self.net.debug = settings.d.debug
  self.net.isMenu = true
  self.net:insert(self)
  self:sendToApp("mainmenu", {"updateSubmenu", "audio", "setCurrentMicrophone", settings.d.currentMicrophone, true})

  local interactor = MenuInteractor()
  interactor.netmenu = self
  interactor:insert(self.net)
end

--- NetMenuScene not draw anything.
function NetMenuScene:onDraw()
  if self.visible == false then
    return route_terminate
  end
end

--- Loads the different avatar models.
function NetMenuScene:setupAvatars()
  self.avatarNames = {}
  for _, avatarName in ipairs(lovr.filesystem.getDirectoryItems("assets/models/avatars")) do
    table.insert(self.avatarNames, avatarName)
  end
  local i = tablex.find(self.avatarNames, settings.d.avatarName)
  if settings.d.avatarName == nil or i == -1 then
    settings.d.avatarName = self.avatarNames[1]
    settings.save()
  end
  self:sendToApp("avatarchooser", {"showAvatar", settings.d.avatarName})
end

function NetMenuScene:updateDebugTitle()
  self:sendToApp("mainmenu", {"updateMenu", "updateDebugTitle", settings.d.debug and true or false })
end

function NetMenuScene:setMessage(message)
  if message then
    self:sendToApp("mainmenu", {"updateMenu", "updateMessage", message})
  end
end

function NetMenuScene:sendToApp(appname, body)
  local appEnt = self.apps[appname]
  if appEnt == nil then
    if self.sendQueue[appname] == nil then self.sendQueue[appname] = {} end
    table.insert(self.sendQueue[appname], body)
    return
  end
  self.net.client:sendInteraction({
    type = "one-way",
    receiver_entity_id = appEnt.id,
    body = body
  })
end

function NetMenuScene:switchToMenu(which)
  self:sendToApp("mainmenu", {"updateMenu", "switchToMenu", which})
  -- avatar chooser only available in main menu
  self:sendToApp("avatarchooser", {"setVisible", which == "main"})
  self:sendToApp("appchooser", {"setVisible", which ~= "main"})
end

function MenuInteractor:onInteraction(interaction, body, receiver, sender)
  if body[1] == "menuapp_says_hello" then
    local appname = body[2]
    self.netmenu.apps[appname] = sender
    if self.netmenu.sendQueue[appname] then
      for _, body in ipairs(self.netmenu.sendQueue[appname]) do
        self.netmenu:sendToApp(appname, body)
      end
      self.netmenu.sendQueue[appname] = nil
    end
    self.netmenu:switchToMenu("main")
  end
  if body[1] ~= "menu_selection" then return end
  local appname = body[2]
  local action = body[3]
  local verb = table.remove(action, 1)
  self.netmenu.dynamicActions[verb](self.netmenu, unpack(action), sender)
end

--- Holds interaction rpc methods.
-- Menu apps can call out interaction rpc commands which is routed to onInteraction 
-- to functions in dynamicActions
NetMenuScene.dynamicActions = {}

--- Ask the placeserv to launch an application and connect it to the place on its side.
function NetMenuScene.dynamicActions:launchApp(appName)
  local net = self.parent.net
  if net == nil then return end
  
  net.client:sendInteraction({
    receiver_entity_id = "place",
    body = {
        "launch_app",
        appName
    }
  })
  self.parent:setMenuVisible(false)
end

--- Connect to a place.
function NetMenuScene.dynamicActions:connect(url)
  settings.d.last_place = url
  settings.save()

  local displayName = settings.d.username and settings.d.username or "Unnamed"
  local net = lovr.scenes:showPlace(displayName, url, settings.d.avatarName, settings.d.avatarName)
  net.debug = settings.d.debug
end

--- Quit Alloverse.
function NetMenuScene.dynamicActions:quit(url)
  lovr.event.quit(0)
end

--- Dismiss the menu.
function NetMenuScene.dynamicActions:dismiss()
  self.parent:setMenuVisible(false)
end

--- Disconnect from the current place.
function NetMenuScene.dynamicActions:disconnect()
  self.parent.net:onDisconnect()
end

--- Toggle debug mode.
function NetMenuScene.dynamicActions:toggleDebug(sender)
  settings.d.debug = not settings.d.debug
  settings:save()
  self.net.debug = settings.d.debug
  self:updateDebugTitle()
end

--- Cycle through the list of avatars.
function NetMenuScene.dynamicActions:changeAvatar(direction, sender)
  local i = tablex.find(self.avatarNames, settings.d.avatarName)
  local newI = ((i + direction - 1) % #self.avatarNames) + 1
  settings.d.avatarName = self.avatarNames[newI]
  settings.save()
  self:sendToApp("avatarchooser", {"showAvatar", settings.d.avatarName})
end

--- Pick a new microphone to record from
function NetMenuScene.dynamicActions:chooseMic(newMicName)
  settings.d.currentMicrophone = newMicName
  settings.save()
  local ok = true
  if lovr.scenes.net then
    ok = lovr.scenes.net.engines.sound and lovr.scenes.net.engines.sound:useMic(settings.d.currentMicrophone)
  end

  self:sendToApp("mainmenu", {"updateSubmenu", "audio", "setCurrentMicrophone", settings.d.currentMicrophone, ok})
end

function NetMenuScene:applySettingsToCurrentNet()
  self.dynamicActions.chooseMic(self, settings.d.currentMicrophone)
end

return NetMenuScene
