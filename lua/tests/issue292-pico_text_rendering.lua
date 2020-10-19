
function lovr.mirror()
    lovr.graphics.reset()
    lovr.graphics.origin()
    local pixwidth = lovr.graphics.getWidth()
    local pixheight = lovr.graphics.getHeight()
    local aspect = pixwidth/pixheight
    local proj = lovr.math.mat4():perspective(0.01, 100, 67*(3.14/180), aspect)
    lovr.graphics.setProjection(1, proj)
    lovr.draw()
end

function lovr.load()
    head = lovr.graphics.newModel("assets/models/avatars/female/head.glb")
end

function lovr.draw()
  lovr.graphics.clear()
  lovr.graphics.setShader()
  head:draw(0, 1.2, -3, .5, lovr.timer.getTime())
  lovr.graphics.cube('line', 0, 1.2, -3, .5, lovr.timer.getTime())
  for i=1, 2 do
    lovr.graphics.print('hello world '..tostring(i), 0, 1.7-i*0.2, -5, 0.15)
  end
end
  