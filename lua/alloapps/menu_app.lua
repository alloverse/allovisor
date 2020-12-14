local Client = require("alloui.client")
local ui = require("alloui.ui")
local pretty = require("pl.pretty")
local class = require("pl.class")

local MenuView = require("alloapps.menu.view")
local AppChooserView = require("alloapps.app_chooser")
local AvatarChooserView = require("alloapps.avatar_chooser")

class.MenuApp()
function MenuApp:_init(appname, port)
  self.appname = appname
  self.client = Client(
    "alloplace://localhost:"..tostring(port), 
    appname
  )
  self.app = ui.App(self.client)
  local chain = self.client.delegates.onComponentAdded
  self.client.delegates.onComponentAdded = function(k, v) 
    self:onComponentAdded(k, v)
    chain(k, v)
  end
  local chain = self.client.delegates.onInteraction
  self.client.delegates.onInteraction = function(inter, body, receiver, sender) 
    self:onInteraction(inter, body, receiver, sender)
    chain(inter, body, receiver, sender)
  end

  self.app.mainView = self:createUI()
  if self.app:connect() == false then
    assert(false, appname.." alloapp failed to connect to menuserv")
  end
end

function MenuApp:createUI()
  assert(false, "Please implement createUI()")
end

function MenuApp:onComponentAdded(key, comp)
  if key == "visor" then
    self.visor = comp.getEntity()
    self.app.client:sendInteraction({
      receiver_entity_id = self.visor.id,
      type = "oneway",
      body = {
          "menuapp_says_hello",
          self.appname
      }
    })
  end
end

function MenuApp:actuate(what)
  if self.app.client == nil or self.visor == nil or self.app.mainView.entity == nil then
    print("can't actuate")
    return
  end
  self.app.client:sendInteraction({
    sender_entity_id = self.app.mainView.entity.id,
    receiver_entity_id = self.visor.id,
    type = "oneway",
    body = {
        "menu_selection",
        self.appname,
        what
    }
  })
end

function MenuApp:onInteraction(interaction, body, receiver, sender)
end

function MenuApp:update()
  self.app:runOnce(0.0) -- sleep in menuapps_main instead
end

return MenuApp