namespace("menu", "alloverse")

local MenuScene = require("app.menu.menu_scene")
local MenuItem = require("app.menu.menu_item")
local settings = require("lib.lovr-settings")
local alloBasicShader = require("shader/alloBasicShader")
local alloPbrShader = require("shader/alloPbrShader")

local MainMenuScene = classNamed("MainMenuScene", MenuScene)
function MainMenuScene:_init()
  settings.load()

  local mainMenuItems = {
    MenuItem("Debug (off)", function() 
      settings.d.debug = not settings.d.debug
      settings.save()
      self:setDebug(settings.d.debug) 
    end),
    MenuItem("Quit", function()
      settings.save()
      lovr.event.quit(0) 
    end),
  }
   
  local elements = {
    MenuScene.letters.TextField:new{
      position = lovr.math.newVec3(-0.7, 1.3, -1.5),
      width = 1.1,
      fontScale = 0.1,
      font = font,
      onReturn = function() settings.save(); self.elements[2]:makeKey(); return false; end,
      onChange = function(s, old, new) settings.d.username = new; return true end,
      placeholder = "Name",
      text = settings.d.username and settings.d.username or ""
    },
    MenuScene.letters.TextField:new{
      position = lovr.math.newVec3(-0.7, 1.15, -1.5),
      width = 1.1,
      fontScale = 0.1,
      font = font,
      onReturn = function() self:connect() return false; end,
      placeholder = "nevyn.places.alloverse.com",
      text = settings.d.last_place and settings.d.last_place:gsub("^alloplace://", "") or ""
    },
    MenuScene.letters.Button:new{
      position = lovr.math.newVec3(0.6, 1.2, -1.5),
      onPressed = function() 
        self:connect()
      end,
      label = "Connect"
    }
  }
  self.debug = false
  return self:super(mainMenuItems, elements)
end

function MainMenuScene:onLoad()
  MenuScene.onLoad(self)
  self.models = {
    head = lovr.graphics.newModel('assets/models/head/female.glb'),
    lefthand = lovr.graphics.newModel('assets/models/left-hand/left-hand.glb'),
    righthand = lovr.graphics.newModel('assets/models/right-hand/right-hand.glb'),
    torso = lovr.graphics.newModel('assets/models/torso/torso.glb'),
    helmet = lovr.graphics.newModel('assets/models/DamagedHelmet.glb')
  }
  self:setDebug(settings.d.debug)
  
  self.pbrShader = alloPbrShader
  self.basicShader = alloBasicShader

end

function MainMenuScene:onUpdate()
  MenuScene.onUpdate(self)

  if lovr.headset then 
    hx, hy, hz = lovr.headset.getPosition()
    self.basicShader:send('viewPos', { hx, hy, hz } )
    self.pbrShader:send('viewPos', { hx, hy, hz } )
  end
end

function MainMenuScene:onDraw()
  lovr.graphics.setShader()
  
  MenuScene.onDraw(self)
  lovr.graphics.setColor({1,1,1})

  lovr.graphics.setShader(self.pbrShader)
  self.models.head:draw(     -1.5, 1.8,  -1.2, 1.0, 0, 0, 1, 0, 1)
  self.models.torso:draw(    -1.5, 1.45, -1.2, 1.0, 0, 0, 1, 0, 1)
  self.models.lefthand:draw( -1.3, 1.4,  -1.0, 1.0, 0, 1, 0, 0, 1)
  self.models.righthand:draw(-1.7, 1.2,  -1.1, 1.0, 3.14/2, 1, 0, 0, 1)

  if self.debug then
    self.models.helmet:draw(1.7, 1.8,  -1.1, 0.5, lovr.timer.getTime()/4, 0, 1, 0, 1)
  end

end

function MainMenuScene:setDebug(whether)
  self.debug = whether
  self.menuItems[1].label = string.format("Debug (%s)", self.debug and "on" or "off")
end

function MainMenuScene:connect()
  local url = self.elements[2].text ~= "" and self.elements[2].text or self.elements[2].placeholder
  url = "alloplace://" .. url
  self:openPlace(url)
end

function MainMenuScene:openPlace(url)
  settings.d.last_place = url
  settings.save()

  local displayName = settings.d.username and settings.d.username or "Unnamed"
  local scene = lovr.scenes.network(displayName, url)
  scene.debug = self.debug
  scene:insert()
  self:die()
end


lovr.scenes.menu = MainMenuScene

return MainMenuScene