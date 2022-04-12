--- The Allovisor Stats.
-- I have no idea what this does. 
-- TODO: Fillme
-- @module Stats

namespace "standard"
local pretty = require "pl.pretty"
local tablex = require "pl.tablex"

local flat = require "engine.flat"

local StatsEng = classNamed("Stats", Ent)

local margin = .05

function StatsEng:_init()
    self:clear()
    self:super()
    
    self.graphSize = {60*5, 100}-- 5 seconds of data (if fps is capped at 60)
    self.graphsImage = lovr.data.newImage(self.graphSize[1], self.graphSize[2], "rgba")
    self.graphsTexture = lovr.graphics.newTexture(self.graphsImage, {
        linear = true, mipmaps = false
    })
    self.graphsTexture:setFilter('nearest', 0)
    self.graphMaterial = lovr.graphics.newMaterial(self.graphsTexture)
    self.graphCursor = 0
    self.graphNames = {}
end

function StatsEng:clear()
    self.stats = {}
    
end

function StatsEng:graph(name, value, max, color)
    color = color or {1, 0, 0, 1}
    self.graphNames[#self.graphNames+1] = {
        name = name, value = value, color = color, max = max
    }
    value = value/max
    local y = math.min(math.max(0, (1-value) * self.graphSize[2]), self.graphSize[2]-1)
    self.graphsImage:setPixel(self.graphCursor, y, unpack(color))
end

function StatsEng:set(key, value)
    self.stats[key] = value
end

function StatsEng:enable(isOn)
    self.on = isOn
end

function StatsEng:statsString()
    local s = ""
    for k, v in pairs(self.stats) do
        s = s .. k .. ":   " .. v .. "\n"
    end

    self:graph("fps", lovr.timer.getFPS(), 60, {1,1,1,0.5})
    self:graph("dt", lovr.timer.getDelta()*1000, 60, {1,0,0,0.5})
    self:graph("dtavg", lovr.timer.getAverageDelta()*1000, 60, {1,0,0,1})
    self:graph("ping", self.parent.client:getLatency()*1000, 60, {0.5,0.5,1,0.7})

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
    
    s = s .. "Graphics Objects: " .. #tablex.keys(self.parent.engines.graphics.renderObjects) .. "\n"
    s = s .. "Cached assets: " .. #tablex.keys(self.parent.engines.assets.cache) .. "\n"

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

function StatsEng:onMirror()
    if self.on then
        uiMode()
        lovr.graphics.setShader(nil)
        lovr.graphics.setColor(1,1,1,1)
        lovr.graphics.setFont(flat.font)
        lovr.graphics.print(
            self:statsString(),
            flat.aspect-margin, 1-margin, 0,  -- x,y,z
            flat.fontscale, --scale
            0,0,1,0,--angle,ax,ay,az
            0, --wrap,
            'right','top'
        )
        self:drawGraph()
    end
end

function StatsEng:drawGraph()
    -- draw the graph
    self.graphsTexture:replacePixels(self.graphsImage)
    local w = self.graphSize[1]/flat.pixwidth*6
    local h = self.graphSize[2]/flat.pixheight*3
    local t = (self.graphCursor+1)/self.graphSize[1]
    lovr.graphics.plane(
        self.graphMaterial, 
        -flat.aspect+w/2+margin,1-h/2-margin,0, --xyz
        w, h,--wh
        0,0,0,0,--anglexyz
        t,0,--uv
        1,1--uvsize
    )
    self.graphCursor = self.graphCursor + 1
    if self.graphCursor > self.graphSize[1]-1 then 
        self.graphCursor = 0
    end
    -- draw graph legend
    for i, s in ipairs(self.graphNames) do
        lovr.graphics.setColor(unpack(s.color))
        lovr.graphics.print(
            s.name .. ":".. string.format("%.1f", s.value),--str,
            -flat.aspect+margin+w+margin,1-margin - 0.04*(i-1),0,--xyz,
            flat.fontscale,--scale
            0,0,0,0,--anglezyz
            0, --wrap
            'left', 'top'
        )
    end
    -- prepare next line
    local c = {1/91, 1/194, 1, 0.5}
    for y = 0,self.graphSize[2]-1 do
        self.graphsImage:setPixel(self.graphCursor, y, unpack(c))
    end
    self.graphNames = {}
end

return StatsEng