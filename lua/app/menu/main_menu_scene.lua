namespace("menu", "alloverse")

local MenuScene = require("app.menu.menu_scene")
local MenuItem = require("app.menu.menu_item")

local MainMenuScene = classNamed("MainMenuScene", MenuScene)
function MainMenuScene:_init()
  local mainMenuItems = {
    MenuItem("Nevyn's place", function() self:openPlace("alloplace://nevyn.places.alloverse.com") end),
    MenuItem("Localhost", function() self:openPlace("alloplace://localhost") end),
    MenuItem("Debug (off)", function() self:toggleDebug() end),
    MenuItem("Quit", function() lovr.event.quit(0) end),
  }
  self.debug = false
  return self:super(mainMenuItems)
end

function MainMenuScene:onLoad()
  --self:openPlace("alloplace://localhost")
end

function MainMenuScene:toggleDebug()
  self.debug = not self.debug
  self.menuItems[3].label = string.format("Debug (%s)", self.debug and "on" or "off")
end

function MainMenuScene:openPlace(url)
  local displayName = "Mario"
  local scene = lovr.scenes.network(displayName, url)
  scene.debug = self.debug
  scene:insert()
  queueDoom(self)
end


lovr.scenes.menu = MainMenuScene

return MainMenuScene