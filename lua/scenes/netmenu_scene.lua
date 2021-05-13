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
require("lib.util")


function NetMenuScene:_init(menuServerPort)
  self.menuServerPort = menuServerPort
  self.sendQueue = {}
  self.apps = {}
  self.visible = true

  Store.singleton():registerDefaults{
    recentPlaces = {
      {name="Sandbox", url="alloplace://sandbox.places.alloverse.com"},
      {name="Nevyn's place", url="alloplace://nevyn.places.alloverse.com"}
    },
    debug= false,
    showOverlay= true,
    avatarName= "female",
    username= "",
  }

  self:setupAvatars()
  self:updateDisplayName()
  self:super()
end

--- Setup.
-- Connects to the menuserlv and starts the interactor
function NetMenuScene:onLoad()
  self.net = NetworkScene("owner", "alloplace://localhost:"..tostring(self.menuServerPort), Store.singleton():load("avatarName"), false)
  self.net.debug = Store.singleton():load("debug")
  self.net.isMenu = true
  self.net:insert(self)

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
    if string.sub(avatarName, 1, 1) ~= "." then
      table.insert(self.avatarNames, avatarName)
    end
  end
  local chosenAvatarName = Store.singleton():load("avatarName")
  if tablex.find(self.avatarNames, chosenAvatarName) == -1 then
    chosenAvatarName = female
    Store.singleton():save("avatarName", chosenAvatarName, true)
  end
  self:sendToApp("avatarchooser", {"showAvatar", chosenAvatarName})
end

function NetMenuScene:updateDisplayName()
  self:sendToApp("avatarchooser", {"setDisplayName", Store.singleton():load("username")})
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

function NetMenuScene:onHandleUrl(url)
  if string.find(url, "alloplace://") == nil then
      return
  end

  self.dynamicActions.connect(self, url)
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

function NetMenuScene:saveRecentPlace(url, name)
  local entry = {name=name, url=url}
  local recentPlaces = Store.singleton():load("recentPlaces")
  for i, place in ipairs(recentPlaces) do
    if place.url == url then
      if name == nil and place.name ~= nil then
        entry = place
      end
      table.remove(recentPlaces, i)
      break
    end
  end

  table.insert(recentPlaces, 1, entry)

  while #recentPlaces > 4 do 
    table.remove(recentPlaces) 
  end
  
  Store.singleton():save("recentPlaces", recentPlaces, true)
end

--- Connect to a place.
function NetMenuScene.dynamicActions:connect(url)
  self:saveRecentPlace(url, nil)

  local displayName = Store.singleton():load("username")
  local isSpectatorCamera = displayName == "Camera"
  local net = lovr.scenes:showPlace(displayName, url, Store.singleton():load("avatarName"), isSpectatorCamera)
  net.debug = Store.singleton():load("debug")
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


--- Cycle through the list of avatars.
function NetMenuScene.dynamicActions:changeAvatar(direction, sender)
  local i = tablex.find(self.avatarNames, Store.singleton():load("avatarName")) or 1
  local newI = ((i + direction - 1) % #self.avatarNames) + 1
  local newAvatarName = self.avatarNames[newI]
  Store.singleton():save("avatarName", newAvatarName, true)
  self:sendToApp("avatarchooser", {"showAvatar", newAvatarName})
end

function NetMenuScene.dynamicActions:setDisplayName(newName)
  Store.singleton():save("username", newName, true)
end

return NetMenuScene
