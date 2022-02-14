namespace("networkscene", "alloverse")

local ui = require("alloui.ui")
local class = require("pl.class")
local tablex = require("pl.tablex")
local pretty = require("pl.pretty")
local vec3 = require("modules.vec3")
local mat4 = require("modules.mat4")
local Store = require("lib.lovr-store")

class.StandardWidgets(Ent)

function StandardWidgets:addAllWidgetsTo(avatar, netscene)
    self:addMuteWidget(avatar, netscene)
end

function StandardWidgets:addMuteWidget(avatar, netscene)
    local soundEng = netscene.engines.sound
    
    local muteButton = ui.Button(
        ui.Bounds(0, 0.00, 0.00,   0.03, 0.02, 0.010)
    )
    muteButton.label.fitToWidth = true
    muteButton.onActivated = function()
        
        soundEng:setMuted(not soundEng.isMuted)
    end

    local volumeLabel = ui.Label(
        ui.Bounds(0,0,0,   0.03, 0.005, 0.010)
        :scale(1, 2, 1)
            :rotate(-3.14/2, 1,0,0)
            :move(0, 0.003, 0.01)
            
    )
    muteButton:addSubview(volumeLabel)

    function updateLooks()
        if not self.micStatus or self.micStatus.status == "pending" then
            muteButton:setColor({0.7, 0.7, 0.9, 1.0})
            muteButton.label:setText("Starting mic...")
        elseif self.micStatus.status == "failed" then
            muteButton:setColor({0.9, 0.5, 0.5, 1.0})
            muteButton.label:setText("Mic is broken")
        elseif self.micStatus.name == "Off" or soundEng.isMuted == true then
            muteButton:setColor({0.9, 0.7, 0.7, 1.0})
            muteButton.label:setText("Mic off")
        else
            muteButton:setColor({0.7, 0.9, 0.7, 1.0})
            muteButton.label:setText("Mic on")
        end
    end

    self:scheduleCleanup(Store.singleton():listen("currentMic", function(micStatus)
        self.micStatus = micStatus
        updateLooks()
    end))
    self:scheduleCleanup(Store.singleton():listen("micMuted", function(isMuted)
        updateLooks()
    end))
    self:scheduleCleanup(Store.singleton():listen("micVolume", function(micVolume)
        if micVolume == nil then micVolume = "--" end
        volumeLabel:setText(micVolume)
    end))

    self:_addWidget(avatar, netscene, muteButton)
end

function StandardWidgets:_addWidget(avatar, netscene, view)
    netscene.app:addRootView(view, function(view, ent)
        avatar:addWristWidget(ent, function(ok, err)
            if not ok then 
                print("Failed to add standard widget:", err)
            end
        end)
    end)
end

return StandardWidgets