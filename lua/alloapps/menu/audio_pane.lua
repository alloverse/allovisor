local ui = require("alloui.ui")
local pretty = require("pl.pretty")
local class = require("pl.class")
local tablex = require("pl.tablex")
local Store = require("lib.lovr-store")

class.AudioPane(ui.Surface)
function AudioPane:_init(menu)
    self.menu = menu
    self:super(ui.Bounds{size=ui.Size(1.6, 1.6, 0.1)})
    self:setColor({1,1,1,1})

    self.headerLabel = ui.Label{
        bounds= ui.Bounds(0.15, 0, 0,   1.5, 0.08, 0.02),
        text= "Use microphone:",
        color={0,0,0,1},
        halign="left"
    }
    self.vstack = ui.StackView(ui.Bounds(0,0,0, 1.5, 0, 0.02), "v")
    self:addSubview(self.vstack)
    self.micButtons = {}

    self.gainHeaderLabel = ui.Label{
        bounds= ui.Bounds(0.15, 0, 0,   1.5, 0.08, 0.02),
        text= "Mic gain:",
        color={0,0,0,1},
        halign="left"
    }
    self.gainStack = ui.StackView(ui.Bounds(0.15, 0, 0,   1.5, 0.08, 0.02), "h")
    self.gainLabel = self.gainStack:addSubview(ui.Label{
        bounds= ui.Bounds(0.15, 0, 0,   0.4, 0.06, 0.02),
        text= "1.0",
        color={0,0,0,1},
        halign="left"
    })
    self.gainSlider = self.gainStack:addSubview(ui.Slider(ui.Bounds(0,0,0,  1.0, 0.06, 0.02)))
    self.gainSlider:minValue(0.0)
    self.gainSlider:maxValue(2.0)
    self.gainSlider.track.color = {0.3, 0.7, 0.5, 1.0}
    self.gainSlider.onValueChanged = function(_, val)
        Store.singleton():save("micGain", val, true)
    end
    

    

    self.unsub1 = Store.singleton():listen("availableCaptureDevices", function(microphones)
        self:setAvailableMicrophonesAndLayout(microphones)
    end)
    
    self.unsub2 = Store.singleton():listen("currentMic", function(micSettings)
        if micSettings then
            self:setCurrentMicrophone(micSettings.name, micSettings.status)
        end
    end)

    self.unsub3 = Store.singleton():listen("micGain", function(micGain)
        micGain = micGain or 1.0
        self.gainSlider:currentValue(micGain)
        self.gainLabel:setText(string.format("%.0f%%", micGain*100))
    end)
end

function AudioPane:sleep()
    Surface.sleep(self)
    self.unsub1()
    self.unsub2()
end

function AudioPane:setAvailableMicrophonesAndLayout(mics)

    for _, v in ipairs(self.vstack.subviews) do
        v:removeFromSuperview()
    end
    self.vstack:addSubview(self.headerLabel)

    self.micButtons = {}
    table.insert(mics, 1, {name= "Off"})
    for i, mic in ipairs(mics) do
        local micButton = ui.Button(ui.Bounds(0, self.bounds.size.height/2 - i*0.25 - 0.1, 0,   1.40, 0.2, 0.15))
        micButton.label.lineHeight = mic.default and 0.07 or 0.05
        micButton.label.wrap = true
        micButton.label.text = mic.name
        micButton.onActivated = function()
            Store.singleton():save("currentMic", {name= mic.name, status="pending"}, true)
        end
        micButton.isDefault = mic.default
        self.vstack:addSubview(micButton)
        table.insert(self.micButtons, micButton)
    end

    self:setCurrentMicrophone(nil, nil)

    self.vstack:addSubview(self.gainHeaderLabel)
    self.vstack:addSubview(self.gainStack)
    self.vstack:layout()
    
    self:doWhenAwake(function()
        self.bounds.size.height = self.vstack.bounds.size.height + 0.2
        self:setBounds()
    end)
end

function AudioPane:setCurrentMicrophone(mic, status)
    for _, micButton in ipairs(self.micButtons) do
        local color = {0.6, 0.6, 0.6, 1.0}
        if micButton.label.text == mic or (mic == "" and micButton.isDefault) then
            if status == "ok" then
                color = {0.3, 0.7, 0.5, 1.0}
            elseif status == "pending" then
                color = {0.6, 0.6, 0.3, 1.0}
            else
                color = {0.99, 0.0, 0.0, 1.0}
            end
        end
        micButton:setColor(color)
    end
end

return AudioPane


