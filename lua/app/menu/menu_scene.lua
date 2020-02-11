namespace("menu", "alloverse")

local MenuScene = classNamed("MenuScene", Ent)

local x, y, z = 0, 2.5, -1.5
local MENU_ITEM_HEIGHT = .2
local MENU_ITEM_WIDTH = 1
local MENU_ITEM_VERTICAL_PADDING = .1

local COLOR_WHITE = {1,1,1}
local COLOR_BLACK = {0,0,0}
local COLOR_ALLOVERSE_GRAY = {0.40, 0.45, 0.50}
local COLOR_ALLOVERSE_ORANGE = {0.91, 0.43, 0.29}
local COLOR_ALLOVERSE_ORANGE_DARK = {0.7,0.37,0.47}
local COLOR_ALLOVERSE_BLUE = {0.27,0.55,1}

local HandRay = classNamed("HandRay")
function HandRay:init()
  self.currentMenuItem = nil
  self.from = lovr.math.vec3()
  self.to = lovr.math.vec3()
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
function HandRay:getColor()
  if self.currentMenuItem ~= nil then
    return COLOR_ALLOVERSE_ORANGE
  else
    return COLOR_ALLOVERSE_BLUE
  end
end


local MenuItem = classNamed("MenuItem")
function MenuItem:_init(world, label, index, action)
  self.label = label
  self.index = index
  self.action = action
  self.isHighlighted = false
  local menuItemY = y-((MENU_ITEM_HEIGHT+MENU_ITEM_VERTICAL_PADDING)*index)
  self.collider = world:newBoxCollider(x, menuItemY, z, MENU_ITEM_WIDTH, MENU_ITEM_HEIGHT, 0.1 )
  self.collider:setUserData(self)
end

function MenuScene:onLoad()
  self.world = lovr.physics.newWorld()
  skybox = lovr.graphics.newTexture('assets/cloudy-skybox.jpg')
  self.menuItems = {
    MenuItem(self.world, "Nevyn's place", 1, function() self:openPlace("alloplace://nevyn.places.alloverse.com") end),
    MenuItem(self.world, "Localhost", 2, function() self:openPlace("alloplace://localhostcom") end),
    MenuItem(self.world, "Quit", 3, function() lovr.event.quit(0) end),
  }
  self.menuFont = lovr.graphics.newFont(16)
  self.handRays = {HandRay(), HandRay()}
end


function MenuScene:drawLabel(str, x, y, z)
  lovr.graphics.setShader()
  lovr.graphics.setColor(COLOR_WHITE)
  lovr.graphics.print(str, x, y, z, .1)
end

function MenuScene:drawMenuItem(item)
  local menuItemY = y-((MENU_ITEM_HEIGHT+MENU_ITEM_VERTICAL_PADDING)*item.index)

  if (item.isHighlighted) then
    lovr.graphics.setColor(COLOR_ALLOVERSE_ORANGE_DARK)
  else
    lovr.graphics.setColor(COLOR_ALLOVERSE_ORANGE)
  end
  
  lovr.graphics.plane('fill', x, menuItemY, z, MENU_ITEM_WIDTH, MENU_ITEM_HEIGHT)
  lovr.graphics.setColor(COLOR_BLACK)
  lovr.graphics.plane('fill', x, menuItemY, z-0.05, MENU_ITEM_WIDTH, MENU_ITEM_HEIGHT)
  
  self:drawLabel(item.label, x, menuItemY, z+0.01)
end

function MenuScene:drawMenu()
  lovr.graphics.setColor(COLOR_WHITE)
  lovr.graphics.setFont(menuFont)
  lovr.graphics.plane('fill', x, y-0.6, z-0.1, 1.2, 1)

  for i, item in ipairs(self.menuItems) do
    self:drawMenuItem(item)
  end
end

function MenuScene:onDraw()
  lovr.graphics.setColor(COLOR_WHITE)
  lovr.graphics.skybox(skybox)

  lovr.graphics.setColor(COLOR_ALLOVERSE_GRAY)
  for i, hand in ipairs(lovr.headset.getHands()) do
    local ray = self.handRays[i]
    lovr.graphics.box('fill', ray.from, .03, .04, .06, lovr.headset.getOrientation(hand))

    lovr.graphics.setColor(ray:getColor())
    lovr.graphics.line(ray.from, ray.to)
  end
  
  self:drawMenu()
end



function MenuScene:onUpdate(dt)
  for handIndex, hand in ipairs(lovr.headset.getHands()) do
    local ray = self.handRays[handIndex]

    local handPos = lovr.math.vec3(lovr.headset.getPosition(hand))
    local straightAhead = lovr.math.vec3(0, 0, -1)
    local handRotation = lovr.math.mat4():rotate(lovr.headset.getOrientation(hand))
    local pointedDirection = handRotation:mul(straightAhead)
    local distantPoint = lovr.math.vec3(pointedDirection):mul(10):add(handPos)
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

    if lovr.headset.isDown(hand, "trigger") and ray.currentMenuItem ~= nil then
      lovr.headset.vibrate(hand, 0.7, 0.5)
      ray.currentMenuItem.action()
    end
  end
end

function MenuScene:openPlace(url)
  local displayName = "Mario"
  local scene = lovr.scenes.network(displayName, url)
  scene:insert()
  queueDoom(self)

end

lovr.scenes.menu = MenuScene

return MenuScene