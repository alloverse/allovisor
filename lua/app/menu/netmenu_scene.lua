namespace("menu", "alloverse")

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
  settings.load()
  self:updateDebugTitle()
  self:super()
end

function NetMenuScene:onLoad()
  self.net = lovr.scenes.network("owner", "alloplace://localhost:21338")
  self.net.debug = false
  self.net:insert(self)

  local interactor = MenuInteractor()
  interactor.netmenu = self
  interactor:insert(self.net)
end

function NetMenuScene:connect(url)
  settings.d.last_place = url
  settings.save()

  local displayName = settings.d.username and settings.d.username or "Unnamed"
  local net = lovr.scenes.network(displayName, url)
  net.debug = settings.d.debug
  net:insert()
  self:die()
end

function NetMenuScene:quit(url)
  lovr.event.quit(0)
end

function NetMenuScene:toggleDebug(url, sender)
  settings.d.debug = not settings.d.debug
  settings:save()
  self:updateDebugTitle()
end

function NetMenuScene:updateDebugTitle()
  self:sendToApp({"updateDebugTitle", settings.d.debug})
end

function NetMenuScene:setMessage(message)
  self:sendToApp({"updateMessage", message})
end

function NetMenuScene:sendToApp(body)
  if self.appe == nil then
    table.insert(self.sendQueue, body)
    return
  end
  self.net.client:sendInteraction({
    type = "one-way",
    receiver_entity_id = self.appe.id,
    body = body
  })
end



function MenuInteractor:onInteraction(interaction, body, receiver, sender)
  if body[1] == "menu_says_hello" then
    self.netmenu.appe = sender
    for _, body in ipairs(self.netmenu.sendQueue) do
      self.netmenu:sendToApp(body)
    end
  end
  if body[1] ~= "menu_selection" then return end
  local action = body[2]
  local verb = table.remove(action, 1)
  self.netmenu[verb](self.netmenu, unpack(action), sender)
end

lovr.scenes.menu = NetMenuScene

return NetMenuScene