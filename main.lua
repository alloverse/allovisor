--shader = require 'shader'

x, y, z = 0, 2.5, -1.5
menuItemHeight = .2
menuItemWidth = 1
menuItemVerticalPadding = .1

COLOR_WHITE = {1,1,1}
COLOR_BLACK = {0,0,0}
COLOR_ALLOVERSE_ORANGE = {0.91,0.43,0.29}
COLOR_ALLOVERSE_BLUE = {0.27,0.55,1}

rayColor = COLOR_ALLOVERSE_ORANGE

menuItemArray = {}


function lovr.conf(t)
  t.headset.drivers = {"desktop"}
end


local function drawLabel(str, x, y, z)
  lovr.graphics.setShader()
  lovr.graphics.setColor(1, 1, 1)
  lovr.graphics.print(str, x, y, z, .1)
end

local function drawMenuItem(label, index)  
  lovr.graphics.setColor(COLOR_ALLOVERSE_ORANGE)
  lovr.graphics.plane('fill', x, y-((menuItemHeight+menuItemVerticalPadding)*index), z, menuItemWidth, menuItemHeight)
  lovr.graphics.setColor(COLOR_BLACK)
  lovr.graphics.plane('fill', x, y-((menuItemHeight+menuItemVerticalPadding)*index), z-0.05, menuItemWidth, menuItemHeight)
  
  drawLabel(label, x, y-((menuItemHeight+menuItemVerticalPadding)*index), z)

  menuItemCollider = world:newBoxCollider(x, y-((menuItemHeight+menuItemVerticalPadding)*index), z, menuItemWidth, menuItemHeight, 0.1 )
end


local function drawMenu()
  lovr.graphics.setColor(COLOR_WHITE)
  lovr.graphics.plane('fill', x, y-0.6, z-0.1, 1.2, 1)

  drawMenuItem("JOLLYVERSE", 1)
  drawMenuItem("ALLOSTAR", 2)
  drawMenuItem("PONYWAY", 3)
end



function lovr.load()
  world = lovr.physics.newWorld()
  skybox = lovr.graphics.newTexture('assets/tron-skybox.jpg')
end

function lovr.draw()

  lovr.graphics.setColor(COLOR_WHITE)
  lovr.graphics.skybox(skybox)

  for i, hand in ipairs(lovr.headset.getHands()) do
    local handPos = lovr.math.vec3(lovr.headset.getPosition(hand))

    lovr.graphics.setColor(COLOR_WHITE)
    lovr.graphics.box('fill', handPos, .03, .04, .06, lovr.headset.getOrientation(hand))

    local straightAhead = lovr.math.vec3(0, 0, -1)
    local handRotation = lovr.math.mat4():rotate(lovr.headset.getOrientation(hand))
    local pointedDirection = handRotation:mul(straightAhead)
    local distantPoint = lovr.math.vec3(pointedDirection):mul(10):add(handPos)


    rayColor = COLOR_ALLOVERSE_ORANGE
    world:raycast(handPos.x, handPos.y, handPos.z, distantPoint.x, distantPoint.y, distantPoint.z, function(shape)
      
      -- Iterate through the list of references to menu items
      -- see if the found shape (shape) exists
      -- if it does, remember the index.

      -- when drawing the menu, check for 
      
      
      print(shape)

      rayColor = COLOR_ALLOVERSE_BLUE
    end)

    drawMenu()

    lovr.graphics.setColor(rayColor)
    lovr.graphics.line(handPos, distantPoint)

  end


end



function lovr.update(dt)
  
  for name, hand in ipairs(lovr.headset.getHands()) do
    if lovr.headset.isDown(hand, "trigger") then

      print("TRIGGERED")

      --controller:vibrate(.004)
      --print(controller:getPosition())
    end
  end
end