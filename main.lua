--shader = require 'shader'

x, y, z = 0, 2.5, -1.5
menuItemHeight = .2
menuItemVerticalPadding = .1

COLOR_WHITE = {1,1,1}
COLOR_BLACK = {0,0,0}
COLOR_ALLOVERSE_ORANGE = {0.91,0.43,0.29}
COLOR_ALLOVERSE_BLUE = {0.27,0.55,1}

function lovr.load()
  skybox = lovr.graphics.newTexture('assets/tron-skybox.jpg')
end

local function drawLabel(str, x, y, z)
  lovr.graphics.setShader()
  lovr.graphics.setColor(1, 1, 1)
  lovr.graphics.print(str, x, y, z, .1)
end


local function drawMenuItem(label, index)  
  lovr.graphics.setColor(COLOR_ALLOVERSE_ORANGE)
  lovr.graphics.plane('fill', x, y-((menuItemHeight+menuItemVerticalPadding)*index), z, 1, menuItemHeight)
  lovr.graphics.setColor(0,0,0)
  lovr.graphics.plane('fill', x, y-((menuItemHeight+menuItemVerticalPadding)*index), z-0.05, 1, menuItemHeight)

  
  drawLabel(label, x, y-((menuItemHeight+menuItemVerticalPadding)*index), z)
end


function lovr.draw()

  lovr.graphics.skybox(skybox)


    local hx, hy, hz = lovr.headset.getPosition()
    local angle, hax, hay, haz = lovr.headset.getOrientation()


    for i, controller in ipairs(lovr.headset.getControllers()) do
      
      local cx, cy, cz = controller:getPosition()
      local angle, cax, cay, caz = controller:getOrientation()

      lovr.graphics.cube('fill', cx, cy, cz, .05, angle, cax, cay, caz)

      lovr.graphics.setColor(COLOR_WHITE)
      


      local controllerPosVector = lovr.math.vec3(cx, cy, cz)
      local unitVector = lovr.math.vec3(hax, hay, haz)
      final = controllerPosVector:add(unitVector)
      print(unitVector:unpack())

      fx, fy, fz = final:unpack()

      lovr.graphics.line(cx+0.1, cy, cz, fx, fy, fz )

    end

    
  

  drawMenuItem("JOLLYVERSE", 1)
  drawMenuItem("ALLOSTAR", 2)
  drawMenuItem("PONYWAY", 3)

  lovr.graphics.setColor(COLOR_WHITE)
  lovr.graphics.plane('fill', x, y-0.6, z-0.1, 1.2, 1)

  lovr.graphics.setColor(COLOR_WHITE)


end


function lovr.update(dt)
  
  for i, controller in ipairs(lovr.headset.getControllers()) do
    if controller:isDown("trigger") then
      --controller:vibrate(.004)
      print(controller:getPosition())
    end
  end
end