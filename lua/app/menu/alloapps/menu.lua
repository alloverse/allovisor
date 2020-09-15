local Client = require("alloui.client")
local ui = require("alloui.ui")
local pretty = require("pl.pretty")

local Menu = {
}

function Menu:new(o)
    o = o or {}
  setmetatable(o, self)
  self.__index = self
  o.client = Client(
    "alloplace://localhost:21338", 
    "menu"
  )
  o.app = ui.App(o.client)
  local chain = o.client.delegates.onComponentAdded
  o.client.delegates.onComponentAdded = function(k, v) 
    o:onComponentAdded(k, v)
    chain(k, v)
  end
  local chain = o.client.delegates.onInteraction
  o.client.delegates.onInteraction = function(inter, body, receiver, sender) 
    o:onInteraction(inter, body, receiver, sender)
    chain(inter, body, receiver, sender)
  end

  o.app.mainView = o:createUI()
  if o.app:connect() == false then
    print("menu alloapp failed to connect to menuserv")
    return nil
  end
  return o
end

function Menu:createUI()
  local plate = ui.Surface(ui.Bounds(0, 1.6, -2,   1.6, 1.2, 0.1))
  plate:setColor({1,1,1,1})
  local quitButton = ui.Button(ui.Bounds(0, -0.4, 0.01,     1.4, 0.2, 0.1))
  quitButton.label = "Quit"
  quitButton.onActivated = function() self:actuate({"quit"}) end
  plate:addSubview(quitButton)

  local connectButton = ui.Button(ui.Bounds(0, 0.4, 0.01,   1.4, 0.2, 0.1))
  connectButton.label = "Connect"
  connectButton.onActivated = function() self:actuate({"connect", "alloplace://nevyn.places.alloverse.com"}) end
  plate:addSubview(connectButton)

  self.debugButton = ui.Button(ui.Bounds(0, 0.1, 0.01,     1.4, 0.2, 0.1))
  self.debugButton.label = "Toggle Debug"
  self.debugButton.onActivated = function() self:actuate({"toggleDebug"}) end
  plate:addSubview(self.debugButton)

  self.messageLabel = ui.Label{
    bounds = ui.Bounds(0, 0.8, 0.01,     1.4, 0.1, 0.1),
    text = "Welcome to Alloverse",
    color = {0,0,0,1}
  }
  plate:addSubview(self.messageLabel)

  return plate
end

function Menu:onComponentAdded(key, comp)
  if key == "visor" then
    self.visor = comp.getEntity()
    self.app.client:sendInteraction({
      receiver_entity_id = self.visor.id,
      type = "oneway",
      body = {
          "menu_says_hello",
      }
    })
  end
end

function Menu:actuate(what)
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
        what
    }
  })
end

function Menu:onInteraction(interaction, body, receiver, sender)
  if body[1] == "updateDebugTitle" then
   self.debugButton:setLabel(body[2] and "Debug (On)" or "Debug (Off)")
  elseif body[1] == "updateMessage" then
    self.messageLabel:setText(body[2])
  end
end

function Menu:update()
  self.app:runOnce(1.0/40.0)
end



return Menu