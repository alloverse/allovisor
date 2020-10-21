local nodeNames = {
    "palm",
    "wrist",
    "thumb_metacarpal",
    "thumb_proximal",
    "thumb_distal",
    "thumb_tip",
    "index_metacarpal",
    "index_proximal",
    "index_intermediate",
    "index_distal",
    "index_tip",
    "middle_metacarpal",
    "middle_proximal",
    "middle_intermediate",
    "middle_distal",
    "middle_tip",
    "ring_metacarpal",
    "ring_proximal",
    "ring_intermediate",
    "ring_distal",
    "ring_tip",
    "little_metacarpal",
    "little_proximal",
    "little_intermediate",
    "little_distal",
    "little_tip",
}

function lovr.load()
    models = {
        ["hand/left"] = lovr.graphics.newModel("assets/models/avatars/female/left-hand.glb"),
    }
    pbr = lovr.graphics.newShader(
        'standard',
        {
            flags = {
                normalMap = true,
                indirectLighting = true,
                occlusion = true,
                emissive = true,
                skipTonemap = false,
                animated = true,
            },
            stereo = lovr.headset == nil or (lovr.headset.getName() ~= "Pico") -- turn off stereo on pico: it's not supported
        }
    )
    pbr:send('lovrLightDirection', { -1, -1, -1 })
    pbr:send('lovrLightColor', { .9, .9, .8, 1.0 })
    pbr:send('lovrExposure', 2)
    lovr.graphics.setBackgroundColor(0.95, 0.98, 0.98)
    lovr.graphics.setColor(0,0,0)
end

function drawAxes(size)
    lovr.graphics.setColor(1,0,0)
    lovr.graphics.line(0,0,0, size,0,0)
    lovr.graphics.setColor(0,1,0)
    lovr.graphics.line(0,0,0, 0,size,0)
    lovr.graphics.setColor(0,0,1)
    lovr.graphics.line(0,0,0, 0,0,size)
end

function drawHand(hand)
    models[hand] = models[hand] or lovr.headset.newModel(hand)
    local model = models[hand]
    lovr.graphics.push()

    lovr.graphics.setShader()

    if model then
        model:pose()
    end
    for i, joint in ipairs(lovr.headset.getSkeleton(hand) or {}) do
        local x, y, z, a, ax, ay, az = unpack(joint)
        local jointPose = lovr.math.mat4(unpack(joint))
        local nodeName = nodeNames[i]
        local status, ox, oy, oz, oa, oax, oay, oaz = pcall(model.getNodePose, model, nodeName, "local")
        if status and hand == "hand/left" then
            lovr.graphics.setColor(0,0.6,0)
            model:pose(nodeName, ox, oy, oz, a, ax, ay, az)
        else
             lovr.graphics.setColor(0.6,0,0)
        end

        lovr.graphics.push()

        lovr.graphics.transform(jointPose)
        lovr.graphics.sphere(0, 0, 0, 0.01)
        drawAxes(0.018)
        
        lovr.graphics.transform(0, 0.03, 0.0, 1, 1, 1, -3.14/2, 1, 0, 0)
        
        
        
        if status then
            lovr.graphics.print(string.format("%.2f %.2f %.2f", ox, oy, oz), 0, 0.008, 0, 0.007, lovr.math.quat(), 0, "left")
        end
        lovr.graphics.print(string.format("%.2f %.2f %.2f %.2f %.2f %.2f %.2f", x, y, z, a, ax, ay, az), 0, 0.004, 0, 0.007, lovr.math.quat(), 0, "left")
        lovr.graphics.print(tostring(i-1), 0, 0.000, 0, 0.007, lovr.math.quat(), 0, "left")
        lovr.graphics.print(nodeNames[i], 0, -0.004, 0, 0.007, lovr.math.quat(), 0, "left")
        
        lovr.graphics.pop()

        if hand == "hand/left" then
            lovr.graphics.setColor(0,0,0)
            local h = 0.05
            lovr.graphics.print(nodeNames[i], 0, i*h, -2, h, lovr.math.quat(), 0, "left")
            lovr.graphics.print(string.format("(%.2f, %.2f, %.2f)", x, y, z), 0.5, i*h, -2, h, lovr.math.quat(), 0, "left")
            lovr.graphics.print(string.format("%.2frad (%.2f, %.2f, %.2f)", a, ax, ay, az), 0.9, i*h, -2, h, lovr.math.quat(), 0, "left")
            if status then
                lovr.graphics.print(string.format("(%.2f, %.2f, %.2f)", ox, oy, oz), 1.5, i*h, -2, h, lovr.math.quat(), 0, "left")
            end
        end
    end

    local pose = lovr.math.mat4(lovr.headset.getPose(hand))
    lovr.graphics.transform(pose)
    lovr.graphics.cube("line", 0,0,0, 0.1)
    drawAxes(0.06)
    
    lovr.graphics.setColor(1, 1, 1)
    if model then
        if hand == "hand/right" then
            lovr.headset.animate(hand, model)
        end
        lovr.graphics.setShader(pbr)
        model:draw()
    end
    lovr.graphics.pop()
    
end
function lovr.draw()
    lovr.graphics.clear()
    lovr.graphics.cube('line', 0, 1.2, -3, .5, lovr.timer.getTime())

    for _, hand in ipairs({ 'hand/left', 'hand/right' }) do
        drawHand(hand)
    end
end
  