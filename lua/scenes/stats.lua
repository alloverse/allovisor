--- The Allovisor Stats.
-- I have no idea what this does. 
-- TODO: Fillme
-- @module Stats

namespace "standard"
local pretty = require "pl.pretty"

local flat = require "engine.flat"

local Stats = classNamed("Stats", Ent)

local margin = .05

function Stats:_init()
    self:clear()
    self:super()
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

function Stats:statsString()
    local s = ""
    for k, v in pairs(self.stats) do
        s = s .. k .. ":   " .. v .. "\n"
    end

    local renderStats = lovr.graphics.getStats()


    for i,v in ipairs({"drawcalls", "renderpasses", "shaderswitches", "buffers", "textures", "buffermemory", "texturememory"}) do
        s = s .. v .. ":   " .. renderStats[v] .. "\n"
    end

    if self.parent and self.parent.assetManager then 
        local stat = self.parent.assetManager:getStats()
        s = s .. "AssetManager: " .. stat["published"] .. ", " .. stat["loading"] .. ", " .. stat["cached"] .. ", " .. stat["disk"] .. "\n"
    end

    self.second = (self.second or 1) + lovr.timer.getDelta()
    if self.second >= 1 then
        self.second = 0
        self.lua_memory = collectgarbage("count")
    end

    s = "Lua KBytes: " .. self.lua_memory .. "\n" .. s            
    if self.parent and self.parent.engines.graphics.renderStats then
        local renderStats = self.parent.engines.graphics.renderStats
        local t = renderStats.cubemapTargets
        for _, name in ipairs(t) do
            s = s .. name .. ","
        end
        s = s .. "\n"
        for k,v in pairs(renderStats) do
            if not (type(v) == "table") then
                s = s .. k .. " = " .. v .. "\n"
            end
        end
    end
    return s
end

function Stats:onMirror()
    if self.on then
        uiMode()
        lovr.graphics.setShader(nil)
        lovr.graphics.setColor(1,1,1,1)
        lovr.graphics.setFont(flat.font)
        lovr.graphics.print(
            self:statsString(),
            flat.aspect-margin, 1-margin, 0, 
            flat.fontscale, 
            0,0,1,0,0, 
            'right','top'
        )
    end
end

function Stats:onDraw2()
    lovr.graphics.setShader(nil)
    lovr.graphics.setColor(1,1,1,1)
    lovr.graphics.setFont(flat.font)
    lovr.graphics.sphere(0,0,-2)
    lovr.graphics.print(
        self:statsString(),
        0,0,0, 
        1, 
        0,0,1,0,0
        -- 'right','top'
    )
end


return Stats