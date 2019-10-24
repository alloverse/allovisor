namespace("menu", "alloverse")

local Menu = classNamed("Menu", Ent)

x, y, z = 0, 2.5, -1.5
MENU_ITEM_HEIGHT = .2
MENU_ITEM_WIDTH = 1
MENU_ITEM_VERTICAL_PADDING = .1

COLOR_WHITE = {1,1,1}
COLOR_BLACK = {0,0,0}
COLOR_ALLOVERSE_GRAY = {0.40, 0.45, 0.50}
COLOR_ALLOVERSE_ORANGE = {0.91, 0.43, 0.29}
COLOR_ALLOVERSE_ORANGE_DARK = {0.7,0.37,0.47}
COLOR_ALLOVERSE_BLUE = {0.27,0.55,1}

rayColor = COLOR_ALLOVERSE_ORANGE

menuItemArray = {"Menu item 1", "Menu item 2", "Menu item 3"}
colliderArray = {}

collidedMenuItemIndex = nil


local function drawLabel(str, x, y, z)
  lovr.graphics.setShader()
  lovr.graphics.setColor(COLOR_WHITE)
  lovr.graphics.print(str, x, y, z, .1)
end

local function drawMenuItem(label, index)

  local menuItemY = y-((MENU_ITEM_HEIGHT+MENU_ITEM_VERTICAL_PADDING)*index)
  
  --print(collidedMenuItemIndex)

  if (index == collidedMenuItemIndex) then
    lovr.graphics.setColor(COLOR_ALLOVERSE_ORANGE_DARK)
    else
    lovr.graphics.setColor(COLOR_ALLOVERSE_ORANGE)
  end
  
  lovr.graphics.plane('fill', x, menuItemY, z, MENU_ITEM_WIDTH, MENU_ITEM_HEIGHT)
  lovr.graphics.setColor(COLOR_BLACK)
  lovr.graphics.plane('fill', x, menuItemY, z-0.05, MENU_ITEM_WIDTH, MENU_ITEM_HEIGHT)
  
  drawLabel(label, x, menuItemY, z+0.01)

  colliderArray[index] = world:newBoxCollider(x, menuItemY, z, MENU_ITEM_WIDTH, MENU_ITEM_HEIGHT, 0.1 )
  --print(colliderArray[index])
end

local menuFont = lovr.graphics.newFont(16)

local function drawMenu()
  lovr.graphics.setColor(COLOR_WHITE)
  lovr.graphics.setFont(menuFont)
  lovr.graphics.plane('fill', x, y-0.6, z-0.1, 1.2, 1)

  for menuItemCount = 1, table.getn(menuItemArray) do
    drawMenuItem(menuItemArray[menuItemCount], menuItemCount)
  end

end

function Menu:onLoad()
  world = lovr.physics.newWorld()
  --skybox = lovr.graphics.newTexture('assets/tron-skybox.jpg')
  skybox = lovr.graphics.newTexture('assets/cloudy-skybox.jpg')
end

function Menu:onDraw()

  lovr.graphics.setColor(COLOR_WHITE)
  lovr.graphics.skybox(skybox)

  for i, hand in ipairs(lovr.headset.getHands()) do
    local handPos = lovr.math.vec3(lovr.headset.getPosition(hand))

    lovr.graphics.setColor(COLOR_ALLOVERSE_GRAY)
    lovr.graphics.box('fill', handPos, .03, .04, .06, lovr.headset.getOrientation(hand))
    
    lovr.graphics.setColor(COLOR_WHITE)

    local straightAhead = lovr.math.vec3(0, 0, -1)
    local handRotation = lovr.math.mat4():rotate(lovr.headset.getOrientation(hand))
    local pointedDirection = handRotation:mul(straightAhead)
    local distantPoint = lovr.math.vec3(pointedDirection):mul(10):add(handPos)

    rayColor = COLOR_ALLOVERSE_ORANGE


    world:raycast(handPos.x, handPos.y, handPos.z, distantPoint.x, distantPoint.y, distantPoint.z, function(shape)

      for colliderCount = 1, table.getn(colliderArray) do
        if (colliderArray[colliderCount]:getShapes()[1] == shape) then
          --print("Colliding with item " .. colliderCount)
          collidedMenuItemIndex = colliderCount
        end
      end

      rayColor = COLOR_ALLOVERSE_BLUE
    end)



    -- CHECK FOR INPUT
    for name, hand in ipairs(lovr.headset.getHands()) do
      if lovr.headset.isDown(hand, "trigger") then
        print("TRIGGER ON MENU ITEM---")
        print(collidedMenuItemIndex)
        print("-----------------------")

        --controller:vibrate(.004)
        --print(controller:getPosition())
      end
    end





    drawMenu()


    lovr.graphics.setColor(rayColor)
    lovr.graphics.line(handPos, distantPoint)
    collidedMenuItemIndex = nil

  end
end



function Menu:onUpdate(dt)
  
  -- for name, hand in ipairs(lovr.headset.getHands()) do
  --   if lovr.headset.isDown(hand, "trigger") then
  --     print("TRIGGERED")
  --     print(collidedMenuItemIndex)

  --     --controller:vibrate(.004)
  --     --print(controller:getPosition())
  --   end
  -- end
end

return Menu