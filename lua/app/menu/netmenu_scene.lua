namespace("menu", "alloverse")
local NetworkScene = require("app.network.network_scene")

-- This scene doesn't have any UI. It just connects to menuserv,
-- which has its own AlloApps running, providing UI. These in turn
-- perform their actions by sending allo interactions back to this scene.
-- So you could say, this is a "controller" class and the alloapps are
-- plain MVC views.
local NetMenuScene = classNamed("NetMenuScene", Ent)
local MenuInteractor = classNamed("MenuInteractor", Ent)
local settings = require("lib.lovr-settings")


function NetMenuScene:_init()
  self.sendQueue = {}
  self.apps = {}
  settings.load()
  self:setupAvatars()
  self:updateDebugTitle()
  self:super()
end

function NetMenuScene:onLoad()
  self.net = NetworkScene("owner", "alloplace://localhost:21338", settings.d.avatarName)
  self.net.debug = settings.d.debug
  self.net:insert(self)

  local interactor = MenuInteractor()
  interactor.netmenu = self
  interactor:insert(self.net)
end

function NetMenuScene:connect(url)
  settings.d.last_place = url
  settings.save()

  local displayName = settings.d.username and settings.d.username or "Unnamed"
  local net = lovr.scenes:showPlace(displayName, url, settings.d.avatarName, settings.d.avatarName)
  net.debug = settings.d.debug
end

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

function NetMenuScene:quit(url)
  lovr.event.quit(0)
end

function NetMenuScene:toggleDebug(sender)
  settings.d.debug = not settings.d.debug
  settings:save()
  self.net.debug = settings.d.debug
  self:updateDebugTitle()
end

function NetMenuScene:updateDebugTitle()
  self:sendToApp("mainmenu", {"updateDebugTitle", settings.d.debug})
end

function NetMenuScene:setMessage(message)
  if message then
    self:sendToApp("mainmenu", {"updateMessage", message})
  end
end

function NetMenuScene:changeAvatar(direction, sender)
  local i = tablex.find(self.avatarNames, settings.d.avatarName)
  local newI = ((i + direction - 1) % #self.avatarNames) + 1
  settings.d.avatarName = self.avatarNames[newI]
  settings.save()
  self:sendToApp("avatarchooser", {"showAvatar", settings.d.avatarName})
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
  end
  if body[1] ~= "menu_selection" then return end
  local appname = body[2]
  local action = body[3]
  local verb = table.remove(action, 1)
  self.netmenu[verb](self.netmenu, unpack(action), sender)
end

return NetMenuScene