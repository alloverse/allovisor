local tablex = require("pl.tablex")

local nodeToParentIndex = {
    0, -- palm=1
    0, -- wrist=2
    2, -- thumb root=3
    3,
    4,
    5,
    2, -- index root=7
    7,
    8,
    9,
    10,
    2, -- middle root = 12
    12,
    13,
    14,
    15,
    2, -- ring root = 17
    17,
    18,
    19,
    20,
    2, -- pinky root = 22
    22,
    23,
    24,
    25,
}
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
local globalNodes = {}
local localNodes = {}

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
    for i, name in ipairs(nodeNames) do
        table.insert(globalNodes, lovr.math.newMat4())
        table.insert(localNodes, lovr.math.newMat4())
    end
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

    lovr.graphics.setShader()

    if model then
        model:pose()
    end

    lovr.graphics.setColor(0,0,0,1)
    local h = 0.05
    if hand == "hand/left" then
        lovr.graphics.print("Node name", -2.0, -h, -2, h, lovr.math.quat(), 0, "left")
        lovr.graphics.print("local pos", -1.5, -h, -2, h, lovr.math.quat(), 0, "left")
        lovr.graphics.print("local rot", -1.0, -h, -2, h, lovr.math.quat(), 0, "left")
        lovr.graphics.print("parent node", -0.4, -h, -2, h, lovr.math.quat(), 0, "left")
        lovr.graphics.print("global pos", 0.1, -h, -2, h, lovr.math.quat(), 0, "left")
        lovr.graphics.print("global rot", 0.6, -h, -2, h, lovr.math.quat(), 0, "left")
    end

    local worldFromHand = lovr.math.mat4(lovr.headset.getPose(hand))
    local handFromWorld = lovr.math.mat4(worldFromHand):invert()

    for i, joint in ipairs(lovr.headset.getSkeleton(hand) or {}) do
        local gx, gy, gz, ga, gax, gay, gaz = unpack(joint)
        local jointPose = lovr.math.mat4(unpack(joint))
        local nodeName = nodeNames[i]
        local parentIndex = nodeToParentIndex[i]
        local parentNodeName = nodeNames[parentIndex] and nodeNames[parentIndex] or ""

        globalNodes[i]:set(jointPose)
        localNodes[i]:set(jointPose)
        if parentIndex ~= 0 then
            local handFromParent = localNodes[parentIndex]
            local parentFromHand = lovr.math.mat4(handFromParent):invert()
            localNodes[i]:set(globalNodes[parentIndex]):mul(parentFromHand)
        end
        localNodes[i]:mul(handFromWorld)

        local lx, ly, lz, lsx, lsy, lsz, la, lax, lay, laz = localNodes[i]:unpack()

        local status, ox, oy, oz, oa, oax, oay, oaz = pcall(model.getNodePose, model, nodeName, "local")
        if status and hand == "hand/left" then
            model:pose(nodeName, ox, oy, oz, la, lax, lay, laz)
        end

        if hand == "hand/left" then
            lovr.graphics.push()
            lovr.graphics.translate(-1.05, i*h, -2)
            lovr.graphics.rotate(la, lax, lay, laz)
            drawAxes(h*0.9)
            lovr.graphics.pop()

            lovr.graphics.push()
            lovr.graphics.translate(0.55, i*h, -2)
            lovr.graphics.rotate(ga, gax, gay, gaz)
            drawAxes(h*0.9)
            lovr.graphics.pop()

            lovr.graphics.setColor(0,0,i%2,1)
            lovr.graphics.print(nodeName, -2.0, i*h, -2, h, lovr.math.quat(), 0, "left")
            lovr.graphics.print(string.format("(%.2f, %.2f, %.2f)", lx, ly, lz), -1.5, i*h, -2, h, lovr.math.quat(), 0, "left")
            lovr.graphics.print(string.format("%.2frad (%.2f, %.2f, %.2f)", la, lax, lay, laz), -1.0, i*h, -2, h, lovr.math.quat(), 0, "left")
            lovr.graphics.print(parentNodeName, -0.4, i*h, -2, h, lovr.math.quat(), 0, "left")
            local gx, gy, gz, gsx, gsy, gsz, ga, gax, gay, gaz = globalNodes[i]:unpack()
            lovr.graphics.print(string.format("(%.2f, %.2f, %.2f)", gx, gy, gz), 0.1, i*h, -2, h, lovr.math.quat(), 0, "left")
            lovr.graphics.print(string.format("%.2frad (%.2f, %.2f, %.2f)", ga, gax, gay, gaz), 0.6, i*h, -2, h, lovr.math.quat(), 0, "left")
        end
    end



    for i, joint in ipairs(globalNodes) do
        lovr.graphics.push()
        lovr.graphics.transform(joint)
        lovr.graphics.setColor(0,0,0,0.5)
        lovr.graphics.sphere(0, 0, 0, 0.01)
        drawAxes(0.018)
        lovr.graphics.transform(0, 0.03, 0.0, 1, 1, 1, -3.14/2, 1, 0, 0)
        lovr.graphics.setColor(0,0,0,1)
        lovr.graphics.print(nodeNames[i], 0, 0, 0, 0.01)
        lovr.graphics.pop()
    end

    lovr.graphics.push()
    lovr.graphics.transform(worldFromHand)
    lovr.graphics.cube("line", 0,0,0, 0.1)
    drawAxes(0.08)
    
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
  