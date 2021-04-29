
local class = require 'pl.class'

local Shader = class.Shader()

function Shader:_init()
    self.lights = {
        {
            type = 'point', -- point, directional, spot
            position = {0, 0, 0}, -- for point, spot
            direction = {0, 0, -1}, -- for directional, spot
            color = {0.8, 1, 1},
        }
    }
    self.lightsBlock = lovr.graphics.newShaderBlock('uniform', {
        lightCount = 'int',
        lightPositions = { 'vec4', 32 },
        lightColors = { 'vec4', 32 },
    }, { usage = 'stream'})
end

function Shader:get(options)
    options = options or {}
    options.useTransparency = options.useTransparency or true
    options.useTransparency = options.useTransparency or false
    options.useNormalMap = options.useNormalMap or false
    options.useTangentMap = options.useTangentMap or false
    options.useGeneratedNormals = options.useTangentMap or false
    options.useMetalnessMap = options.useMetalnessMap or false
    options.useRoughnessMap = options.useRoughnessMap or false
    options.useSpecularMap = options.useSpecularMap or false
    options.useLights = options.useLights or false
    options.maxLightCount = options.maxLightCount or 128
    options.debugMode = options.debugMode or nil -- transparency, normalmap, metalnessmap, roughnessmap, specularmap, reflections, refractions, lights
end

local function read(file)
    file = "eng/" .. file
    if lovr then 
        return assert(lovr.filesystem.read(file), "could not read file at " .. file)
    else
        return io.open(file):read("*a")
    end
end

function Shader:generate(options)
    options = options or {}
    local debug = options.debugMode
    local returnvalue = 'result'
    if debug == 'normalmap' then 
        returnvalue = 'vec4(N)'
    end

    local vert = ""
    local frag = ""

    if true or options.useLights then 
        frag = frag .. self.lightsBlock:getShaderCode('Lights')
    end

    if true or options.useGeneratedNormals then
        frag = frag .. read("shader/normals.glsl")
    end

    vert = vert .. read("shader/vert.glsl")
    frag = frag .. read("shader/frag.glsl")

    assert(vert and frag, "Coult not load shader")

    local shader = lovr.graphics.newShader(vert, frag, {
        stereo = options.stereo,
        flags = {
            highp = true,
            lights = options.lights,
            debug = options.debug
        }
    })
    shader:sendBlock('Lights', self.lightsBlock)
    return shader
end

return Shader