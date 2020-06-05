namespace("menu", "alloverse")

local MenuScene = require("app.menu.menu_scene")
local MenuItem = require("app.menu.menu_item")

local MainMenuScene = classNamed("MainMenuScene", MenuScene)
function MainMenuScene:_init()
  local mainMenuItems = {
    MenuItem("Nevyn's place", function() self:openPlace("alloplace://nevyn.places.alloverse.com") end),
    MenuItem("Localhost", function() self:openPlace("alloplace://localhost:21337") end),
    MenuItem("Standalone", function() self:openPlace("alloplace://localhost:21338") end),
    MenuItem("Debug (off)", function() self:toggleDebug() end),
    MenuItem("Quit", function() lovr.event.quit(0) end),
  }
  self.debug = false
  return self:super(mainMenuItems)
end

function MainMenuScene:onLoad()
  --self:openPlace("alloplace://localhost")
  self.models = {
    head = lovr.graphics.newModel('assets/models/mask/mask.glb'),
    lefthand = lovr.graphics.newModel('assets/models/left-hand/left-hand.glb'),
    righthand = lovr.graphics.newModel('assets/models/right-hand/right-hand.glb'),
    torso = lovr.graphics.newModel('assets/models/torso/torso.glb')
  }
end

function MainMenuScene:onDraw()
  MenuScene.onDraw(self)
  lovr.graphics.setColor({1,1,1})
  self.models.head:draw(     -1.5, 1.8, -1.2, 1.0, 3.14, 0, 1, 0, 1)
  self.models.torso:draw(     -1.5, 1.2, -1.2, 1.0, 3.14, 0, 1, 0, 1)
  self.models.lefthand:draw( -1.3, 1.2, -1.2, 1.0, 3.14, -0.5, 1, 0, 1)
  self.models.righthand:draw(-1.8, 0.9, -1.4, 1.0, 3.14, 0.5, 1, 1, 1)

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