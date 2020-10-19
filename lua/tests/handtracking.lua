
function lovr.draw()
    lovr.graphics.cube('line', 0, 1.2, -3, .5, lovr.timer.getTime())

    for _, hand in ipairs({ 'left', 'right' }) do
      for _, joint in ipairs(lovr.headset.getSkeleton(hand) or {}) do
        lovr.graphics.points(unpack(joint, 1, 3))
      end
    end
  end
  