namespace("menu", "alloverse")

local MenuScene = classNamed("MenuScene", Ent)
MenuScene.letters = require('lib.letters.letters')

x, y, z = 0, 2.8, -1.5
MENU_ITEM_HEIGHT = .2
MENU_ITEM_WIDTH = 1
MENU_ITEM_VERTICAL_PADDING = .1

local COLOR_WHITE = {1,1,1}
local COLOR_BLACK = {0,0,0}
local COLOR_ALLOVERSE_GRAY = {0.40, 0.45, 0.50}
local COLOR_ALLOVERSE_ORANGE = {0.91, 0.43, 0.29}
local COLOR_ALLOVERSE_ORANGE_DARK = {0.7,0.37,0.47}
local COLOR_ALLOVERSE_BLUE = {0.27,0.55,1}

local MenuItem = require("app.menu.menu_item")

local HandRay = classNamed("HandRay")
function HandRay:_init()
  self.currentMenuItem = nil
  self.from = lovr.math.newVec3()
  self.to = lovr.math.newVec3()
end
function HandRay:highlightItem(item)
  if self.currentMenuItem ~= nil then
    self.currentMenuItem.isHighlighted = false
  end
  self.currentMenuItem = item
  if self.currentMenuItem ~= nil then
    self.currentMenuItem.isHighlighted = true
  end
end
function HandRay:selectItem(item)
  if self.selectedMenuItem ~= nil then
    self.selectedMenuItem.isSelected = false
  end
  self.selectedMenuItem = item
  if self.selectedMenuItem ~= nil then
    self.selectedMenuItem.isSelected = true
  end
end
function HandRay:getColor()
  if self.currentMenuItem ~= nil then
    return COLOR_ALLOVERSE_ORANGE
  else
    return COLOR_ALLOVERSE_BLUE
  end
end

function MenuScene:_init(items, elements)
  self.world = lovr.physics.newWorld()
  skybox = lovr.graphics.newTexture('assets/cloudy-sunset.png')
  self.menuItems = items
  for i, item in ipairs(items) do
    item:createCollider(self.world, i)
  end
  self.handRays = {HandRay(), HandRay()}

  self.elements = elements

  self.drawBackground = true

  self:super()
end

function MenuScene:onLoad()
  MenuScene.letters.load()
  MenuScene.letters.defaultKeyboard = MenuScene.letters.HoverKeyboard
  self.menuFont = lovr.graphics.newFont(24)
end

function MenuScene:drawLabel(str, x, y, z)
  lovr.graphics.setShader()
  lovr.graphics.setColor(COLOR_WHITE)
  lovr.graphics.print(str, x, y, z, .1)
end

function MenuScene:drawMenuItem(item)
  local menuItemY = y-((MENU_ITEM_HEIGHT+MENU_ITEM_VERTICAL_PADDING)*item.index)

  if item.isHighlighted then
    lovr.graphics.setColor(COLOR_ALLOVERSE_ORANGE_DARK)
  else
    lovr.graphics.setColor(COLOR_ALLOVERSE_ORANGE)
  end

  local myZ = z
  if item.isSelected then
    myZ = z - 0.045
  end
  lovr.graphics.plane('fill', x, menuItemY, myZ, MENU_ITEM_WIDTH, MENU_ITEM_HEIGHT)
  lovr.graphics.setColor(COLOR_BLACK)
  lovr.graphics.plane('fill', x, menuItemY, z-0.05, MENU_ITEM_WIDTH, MENU_ITEM_HEIGHT)
  
  self:drawLabel(item.label, x, menuItemY, z+0.01)
end

function MenuScene:drawMenu()
  lovr.graphics.setColor(COLOR_WHITE)
  self.menuFont:setPixelDensity(32)

  lovr.graphics.setFont(self.menuFont)
  
  local h = (MENU_ITEM_HEIGHT+MENU_ITEM_VERTICAL_PADDING)*#self.menuItems + MENU_ITEM_VERTICAL_PADDING*2
  lovr.graphics.plane('fill', x, y-h/2, z-0.1, 1.2, h)

  for i, item in ipairs(self.menuItems) do
    self:drawMenuItem(item)
  end
end

function MenuScene:setMessage(message)

  self.message = message

end

function MenuScene:drawMessage(message)
  local scale = .1
  local wrap = 1 / scale
  local font = lovr.graphics.getFont()
  local height = font:getHeight()
  local width, lines = font:getWidth(message, wrap)
  
  local OFFSET_X = 0.8
  local OFFSET_Y = -0.15

  lovr.graphics.setColor(COLOR_WHITE)
  lovr.graphics.plane('fill', x+OFFSET_X+(scale*width/2), y+OFFSET_Y-(lines * height * scale/2), z, width * scale, lines * height * scale)
  lovr.graphics.setColor(COLOR_BLACK)
  lovr.graphics.print(message, x+OFFSET_X, y+OFFSET_Y, z + .001, scale, quat(), wrap, "left", "top")
end

local function drawHand(ray, hand)
  if ray.from == nil then return end

  lovr.graphics.box('fill', ray.from, .03, .04, .06, lovr.headset.getOrientation(hand))

  lovr.graphics.setColor(ray:getColor())
  lovr.graphics.line(ray.from, ray.to)
end

function MenuScene:onDraw()
  MenuScene.letters.draw()
  for i, e in ipairs(self.elements) do
    e:draw()
  end

  if self.drawBackground then
    lovr.graphics.setColor(COLOR_WHITE)
    lovr.graphics.skybox(skybox)
  end

  lovr.graphics.setColor(COLOR_ALLOVERSE_GRAY)
  for i, hand in ipairs(lovr.headset.getHands()) do
    local ray = self.handRays[i]
    drawHand(ray, hand)
  end
  
  self:drawMenu()
  
  if self.message then
    self:drawMessage(self.message)
  end 

end



function MenuScene:onUpdate(dt)
  MenuScene.letters.update()
  for i, e in ipairs(self.elements) do
    e:update()
  end

  for handIndex, hand in ipairs(lovr.headset.getHands()) do
    local ray = self.handRays[handIndex]

    local handPos = lovr.math.newVec3(lovr.headset.getPosition(hand))
    -- if position is nan, stop trying to raycast (as raycasting with nan will crash ODE)
    if handPos.x ~= handPos.x then
      return
    end
    local straightAhead = lovr.math.vec3(0, 0, -1)
    local handRotation = lovr.math.mat4():rotate(lovr.headset.getOrientation(hand))
    local pointedDirection = handRotation:mul(straightAhead)
    local distantPoint = lovr.math.newVec3(pointedDirection):mul(10):add(handPos)
    ray.from = handPos
    ray.to = distantPoint

    local newItem = nil
    self.world:raycast(ray.from.x, ray.from.y, ray.from.z, ray.to.x, ray.to.y, ray.to.z, function(shape)
      newItem = shape:getCollider():getUserData()
    end)
    if ray.currentMenuItem ~= newItem then 
      lovr.headset.vibrate(hand, 0.5, 0.05) 
      ray:highlightItem(newItem)
    end

    -- todo: shown "down" state on down, and only trigger on release if still within bounds.
    -- this should also fix "accidentally connect to localhost after disconnect" problem

    if lovr.headset.isDown(hand, "trigger") and ray.currentMenuItem ~= nil and ray.selectedMenuItem == nil then
      ray:selectItem(ray.currentMenuItem)
      lovr.headset.vibrate(hand, 0.7, 0.2, 100)
    end
    if not lovr.headset.isDown(hand, "trigger") and ray.selectedMenuItem ~= nil then
      if ray.currentMenuItem == ray.selectedMenuItem then
        lovr.headset.vibrate(hand, 0.7, 0.2, 100)
        ray.currentMenuItem.action()
      end
      ray:selectItem(nil)
    end
  end
end

return MenuScene