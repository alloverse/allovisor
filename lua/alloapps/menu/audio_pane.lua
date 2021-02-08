local ui = require("alloui.ui")
local pretty = require("pl.pretty")
local class = require("pl.class")
local tablex = require("pl.tablex")
lovr.audio = require("lovr.audio")

class.AudioPane(ui.Surface)
function AudioPane:_init(menu)
    self:super(ui.Bounds{size=ui.Size(1.6, 1.2, 0.1)})
    self:setColor({1,1,1,1})

    self.headerLabel = self:addSubview(ui.Label{
        bounds= ui.Bounds(0.15, 0, 0,   1.6, 0.08, 0.02),
        text= "Use microphone:",
        color={0,0,0,1},
        halign="left"
    })
    self.micList = ui.View(ui.Bounds{})
    self:addSubview(self.micList)

    local microphones = lovr.audio and lovr.audio.getDevices("capture")
    if microphones == nil or #microphones == 0 then
        microphones = {{
            isDefault = true,
            name = "Default",
            type = "capture"
        }}
    end
    print("Available capture devices: ", pretty.write(microphones))
    self:setAvailableMicrophones(microphones)
end

function AudioPane:setAvailableMicrophones(mics)

    self.bounds.size.height = 0.4 * #mics
    self:setBounds(self.bounds)

    self.headerLabel:setBounds(ui.Bounds(0.15, self.bounds.size.height/2-0.1, 0,   1.6, 0.08, 0.02))

    for _, v in ipairs(self.micList.subviews) do
        v:removeFromSuperview()
    end
    table.insert(mics, 1, {name= "Off"})
    for i, mic in ipairs(mics) do
        local micButton = ui.Button(ui.Bounds(0, self.bounds.size.height/2 - i*0.25 - 0.1, 0,   1.40, 0.2, 0.15))
        micButton.label.lineheight = 0.07
        micButton.label.text = mic.name
        micButton.onActivated = function() self.menu:actuate({"chooseMic", mic.name}) end
        micButton.isDefault = mic.isDefault
        self.micList:addSubview(micButton)
    end
end

function AudioPane:setCurrentMicrophone(mic, status)
    for _, micButton in ipairs(self.micList.subviews) do
        local color = {0.6, 0.6, 0.6, 1.0}
        if micButton.label.text == mic or (mic == "" and micButton.isDefault) then
            if status == "ok" then
                color = {0.3, 0.7, 0.5, 1.0}
            elseif status == "working" then
                color = {0.6, 0.6, 0.3, 1.0}
            else
                color = {0.99, 0.0, 0.0, 1.0}
            end
        end
        micButton:setColor(color)
    end
end

return AudioPane


