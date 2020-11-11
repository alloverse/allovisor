--- The Allovisor Stats.
-- I have no idea what this does. 
-- TODO: Fillme
-- @module Stats

namespace "standard"

local flat = require "engine.flat"

local Stats = classNamed("Stats", Ent)

local margin = .05

function Stats:_init()
    self:clear()
    self:super()
    Stats.instance = self
end

function Stats:clear()
    self.stats = {}
end

function Stats:set(key, value)
    self.stats[key] = value
end

function Stats:enable(isOn)
    self.on = isOn
end

function Stats:onMirror()
    if self.on then
        uiMode()
        
        local s = ""
        for k, v in pairs(self.stats) do
            s = s .. k .. "   " .. v .. "\n"
        end

        lovr.graphics.setShader(nil)
        lovr.graphics.setColor(1,1,1,1)
        lovr.graphics.setFont(flat.font)
        lovr.graphics.print(
            s,
            flat.aspect-margin, 1-margin, 0, 
            flat.fontscale, 
            0,0,1,0,0, 
            'right','top'
        )
    end
end

return Stats