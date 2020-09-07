Client = require("alloui.client")
ui = require("alloui.ui")

local Menu = {
  onQuit = function() print("bye") end,
  onConnect = function() end,
  onToggleDebug = function() end,
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
  local plate = ui.Surface(ui.Bounds(0, 1.6, -2,   1.6, 1.2, 0.1))
  plate:setTexture("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAAMSURBVBhXY/j//z8ABf4C/qc1gYQAAAAASUVORK5CYII=")
  local quitButton = ui.Button(ui.Bounds(0, -0.4, 0.01,     1.4, 0.2, 0.1))
  quitButton.label = "Quit"
  quitButton.onActivated = function() self.onQuit() end
  plate:addSubview(quitButton)

  local connectButton = ui.Button(ui.Bounds(0, 0.4, 0.01,   1.4, 0.2, 0.1))
  connectButton.label = "Connect"
  connectButton.onActivated = function() self.onConnect("alloplace://nevyn.places.alloverse.com") end
  plate:addSubview(connectButton)

  local debugButton = ui.Button(ui.Bounds(0, 0.1, 0.01,     1.4, 0.2, 0.1))
  debugButton.label = "Debug (off)"
  debugButton.onActivated = function() self.onToggleDebug() end
  plate:addSubview(debugButton)

  return plate
end

function Menu:update()
  self.app:runOnce()
end



return Menu