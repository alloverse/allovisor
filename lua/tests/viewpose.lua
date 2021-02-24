function lovr.draw()
    lovr.graphics.cube('line', 0, 1.7, -3, .3, 0)
    movePose()
    lovr.graphics.cube('line', 0, 1.7, -3, .4, 0)
    movePose()
    lovr.graphics.cube('line', 0, 1.7, -3, .5, 0)
end

function movePose()
    for i = 1,2 do
        local pose = lovr.math.mat4(lovr.graphics.getViewPose(i))
        pose:translate(0.5, 0, 0)
        lovr.graphics.setViewPose(i, pose, false)
    end
end  
