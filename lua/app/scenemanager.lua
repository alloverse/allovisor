namespace("menu", "alloverse")
local SceneClasses = {
    menu = require("app.menu.netmenu_scene"),
    net = require("app.network.network_scene"),
    stats = require("app.debug.stats"),
    controls = require("app.test.controlsOverlay"),
}
local sceneOrder = {"menu", "net", "stats", "controls"}

-- This scene manages the main scenes in the app, to make
-- sure things render in the correct order. 
local SceneManager = classNamed("SceneManager", OrderedEnt)

function SceneManager:_init()
    lovr.scenes = self
    self:super()

    for _, k in ipairs({"menu", "stats", "controls"}) do
        self:create(k)
    end
end

-- Create a scene of the name wanted, and insert it into the ent graph
function SceneManager:create(name, ...)
    print("Spawning ", name, "scene with", ...)
    self[name] = SceneClasses[name](...)
    self:_organize()
    return self[name]
end

function SceneManager:_organize()
    local sceneIds = {}
    for i, k in ipairs(sceneOrder) do
        if self[k] then
            if self[k].parent == nil then self[k]:insert(self) end
            table.insert(sceneIds, self[k].id)
        end
    end
    self.kidOrder = sceneIds
end

function SceneManager:unregister(child)
    OrderedEnt.unregister(self, child)
    for i, k in ipairs(sceneOrder) do
        if self[k] == child then self[k] = nil end
    end
    self:_organize()
end

return SceneManager