local ui = require("alloui.ui")
local pretty = require("pl.pretty")
local class = require("pl.class")
local tablex = require("pl.tablex")
lovr.audio = require("lovr.audio")

class.AudioPane(ui.Surface)
function AudioPane:_init(menu)
    self.menu = menu
    self:super(ui.Bounds{size=ui.Size(1.6, 0.5, 0.1)}:move(0,1.3,-2.2):rotate(-0.3,1,0,0))
    self:setColor({1,1,1,1})

    self:addSubview(ui.Label{
        bounds= ui.Bounds(-0.68, 0.18, 0,   1.6, 0.08, 0.02),
        text= "Use microphone",
        color={0,0,0,1},
        halign="left"
    })
    self.micList = ui.View(ui.Bounds{})
    self:addSubview(self.micList)

    local devices = lovr.audio and lovr.audio.getDevices() or {}
    local microphones = tablex.filter(devices, function(x) return x.type == "capture" end)
    self:setAvailableMicrophones(microphones)
end

function AudioPane:setAvailableMicrophones(mics)
    for _, v in ipairs(self.micList.subviews) do
        v:removeFromSuperview()
    end
    table.insert(mics, 1, {name= "Off"})
    for i, mic in ipairs(mics) do
        local micButton = ui.Button(ui.Bounds(-0.5 + (i-1) * 0.44, 0, 0,   0.40, 0.2, 0.15))
        micButton.label.lineheight = 0.05
        micButton.label.text = mic.name
        micButton.onActivated = function() self.menu:actuate({"chooseMic", mic.name}) end
        micButton.isDefault = mic.isDefault
        self.micList:addSubview(micButton)
    end
end

function AudioPane:setCurrentMicrophone(mic, working)
    for _, micButton in ipairs(self.micList.subviews) do
        local color = {0.6, 0.6, 0.6, 1.0}
        if micButton.label.text == mic or (mic == "" and micButton.isDefault) then
            if working then
                color = {0.3, 0.7, 0.5, 1.0}
            else
                color = {0.99, 0.0, 0.0, 1.0}
            end
        end
        micButton:setColor(color)
    end
end

return AudioPane