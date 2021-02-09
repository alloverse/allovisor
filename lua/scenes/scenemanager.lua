--- The Allovisor Scene manager
-- @classmod SceneManager

namespace("menu", "alloverse")
local SceneClasses = {
    menu = require("scenes.netmenu_scene"),
    net = require("scenes.network_scene"),
    stats = require("scenes.stats"),
    controls = require("scenes.controlsOverlay"),
}
local sceneOrder = {"net", "menu", "stats", "controls"}

-- This scene manages the main scenes in the app, to make
-- sure things render in the correct order. 
local SceneManager = classNamed("SceneManager", OrderedEnt)

function SceneManager:_init(menuServerPort)
    lovr.scenes = self
    self:super()

    self:_makeScene("menu", menuServerPort)
    self:_makeScene("stats")
    self:_makeScene("controls")
end

function SceneManager:showPlace(...)
    if self.net then
        self.net:onDisconnect(0, "Connected elsewhere")
    end
    self.menu.net.isOverlayScene = true
    self:setMenuVisible(false)
    self.menu:switchToMenu("overlay")
    self:_makeScene("net", ...)
    self.menu:applySettingsToCurrentNet()
    return self.net
end

function SceneManager:transitionToMainMenu()
    self.menu.net.isOverlayScene = false
    self.menu:switchToMenu("main")
    self:setMenuVisible(true)
    return self.menu
end

function SceneManager:setMenuVisible(visible)
    print("Setting menu to", visible)
    self.menu.visible = visible

    if self.net then
        self.net:route("setActive", not visible)
    end

    self.menu.net:route("setActive", visible)
    self.menu.net:moveToOrigin()
end

function SceneManager:onNetConnected(url, placeName)
    self.menu:setMessage("Connected to "..placeName)
    self.menu:saveRecentPlace(url, placeName)
end

-- Create a scene of the name wanted, and insert it into the ent graph
function SceneManager:_makeScene(name, ...)
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