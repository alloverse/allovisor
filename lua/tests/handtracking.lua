function lovr.load()
    leftHand = lovr.graphics.newModel("assets/models/avatars/female/left-hand.glb")
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
end

function drawHand(hand)
    lovr.graphics.setShader()
    local x, y, z, a, ax, ay, az = lovr.headset.getPose(hand)
    lovr.graphics.cube("line", x, y, z, 0.1, a, ax, ay, az)
    for i, joint in ipairs(lovr.headset.getSkeleton(hand) or {}) do
        local px, py, pz, pa, pax, pay, paz = unpack(joint)
        lovr.graphics.points(unpack(joint, 1, 3))
        --leftHand:pose(i, px, py, pz, pa, pax, pay, paz)
    end

    if hand == "hand/left" then
        lovr.graphics.setShader(pbr)
        leftHand:draw(x, y, z, 1.0, a, ax, ay, az)
    end
end
function lovr.draw()
    lovr.graphics.cube('line', 0, 1.2, -3, .5, lovr.timer.getTime())

    for _, hand in ipairs({ 'hand/left', 'hand/right' }) do
        drawHand(hand)
    end
end
  