Client = require("alloui.client")
ui = require("alloui.ui")

local Menu = {
  onQuit = function() print("bye") end
}

function Menu:new(o)
    o = o or {}
  setmetatable(o, self)
  self.__index = self

  o.client = Client(
    "alloplace://localhost:21338", 
    "menu"
  )
  o.app = App(o.client)
  o.app.mainView = o:createUI()
  o.app:connect()
  return o
end

function Menu:createUI()
  local quitButton = ui.Button(ui.Bounds(-0.3, 0.05, 0.01,   0.2, 0.2, 0.1))
  quitButton.onActivated = function() self:onQuit() end
  return quitButton
end

function Menu:update()
  self.app:runOnce()
end



return Menu