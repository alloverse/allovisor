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
  local quitButton = ui.Button(ui.Bounds(0, -0.4, 0.01,     1.4, 0.2, 0.15))
  quitButton.label.text = "Quit"
  quitButton.onActivated = function() self:actuate({"quit"}) end
  plate:addSubview(quitButton)

  local connectButton = ui.Button(ui.Bounds(0, 0.4, 0.01,   1.4, 0.2, 0.15))
  connectButton.label.text = "Connect"
  connectButton.onActivated = function() self:actuate({"connect", "alloplace://nevyn.places.alloverse.com"}) end
  plate:addSubview(connectButton)

  self.debugButton = ui.Button(ui.Bounds(0, 0.1, 0.01,     1.4, 0.2, 0.15))
  self.debugButton.label.text = "Toggle Debug"
  self.debugButton.onActivated = function() self:actuate({"toggleDebug"}) end
  plate:addSubview(self.debugButton)

  self.messageLabel = ui.Label{
    bounds = ui.Bounds(-0.45, 0.8, 0.01,     1.4, 0.1, 0.1),
    text = "Welcome to Alloverse",
    color = {0,0,0,1},
    halign = "left"
  }
  plate:addSubview(self.messageLabel)

  local logo = ui.Surface(ui.Bounds(-0.65, 0.8, 0.01, 0.2, 0.2, 0.2))
  logo:setTexture("iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAB/UlEQVR4nO2av27CMBCHL0AhQqD+GdshUtVnqNStQxk6dUHqVhbExtTn4MX6Bn2CPsZ1wZEJcRLbd7ZD7ifdwJL4++4sRyQAEolEIpFQBY/V1+s7BwEAVwfE1QHVIikXipMR6NdNRsIJuF5As1i8zUcIAPi3fy/rZ/MaXUS5gDp4gwine+jg1YLQE1EURWdwDxGt4LFEOIFbbAtcXGXW8AYR9OC+8C0ivMC5RJCDN4mggqfaFkHAd18fuN+u2SS4iCiPHS5wdZ7vt+uzCiQibtfrwKsS6s5+zmnAmxlv17uAx5wGVvDlYm4Nr+qxuMfrGfs00ArQx8wVPMQ0sAigBucUQSqAG7wqYTr2e2IkE8Ax7qGmwVtALHAqEc4CUgGvk2AjwktAbGCKSRABlyZASRABIkAEiIAu9fJwN2wBg5+A7+enYQvQpkAEWP0dJgJEgAiIDioCDLWcZk7PAaD96LWA23zUCVy9eIGatEpIWUDTBPzu3s663hSjiJQFmCbABrxVRMoC8klGBn4iQX9jnLIANQHQss+dRaiKDdokAIi63jsRIcCNMhIBDw5fSsgnWXARAIDz431jgVcTTAJE7nhb2ERA4uB6cDam2xbAdKyFiPeJAT3qelOsJcCFgFfTKmLzyffNbyopP3EZStdNKSXAwMD1DBZcIpFIksg/LCx2xNxTGTMAAAAASUVORK5CYII=")
  plate:addSubview(logo)
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
   self.debugButton.label:setText(body[2] and "Debug (On)" or "Debug (Off)")
  elseif body[1] == "updateMessage" then
    self.messageLabel:setText(body[2])
  end
end

function Menu:update()
  self.app:runOnce(1.0/40.0)
end



return Menu