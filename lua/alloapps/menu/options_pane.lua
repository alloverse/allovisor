local ui = require("alloui.ui")
local pretty = require("pl.pretty")
local class = require("pl.class")
local AudioPane = require("alloapps.menu.audio_pane")

class.OptionsPane(ui.Surface)
function OptionsPane:_init(menu)
    self:super(ui.Bounds{size=ui.Size(1.6, 1.2, 0.1)})
    self:setColor({1,1,1,1})

    self.debugButton = ui.Button(ui.Bounds(0, 0.4, 0.01,   1.4, 0.2, 0.15))
    self:addSubview(self.debugButton)
    self.debugOverlaySub = nil

    self.toggleControlsButton = ui.Button(ui.Bounds(0, 0.1, 0.01,   1.4, 0.2, 0.15))
    self:addSubview(self.toggleControlsButton)
    self.controlOverlaySub = nil

    self.audioButton = ui.Button(ui.Bounds(0, -0.2, 0.01,     1.4, 0.2, 0.15))
    self.audioButton.label.text = "Audio settings..."
    self.audioButton.onActivated = function() 
        self.nav:push(AudioPane(menu))
    end
    self:addSubview(self.audioButton)
end

function OptionsPane:awake()
    Surface.awake(self)
    print("Option awake")

    self.debugOverlaySub = Store.singleton():listen("debug", function(debug)
        self.debugButton.label:setText(debug and "Debug (On)" or "Debug (Off)")
        self.debugButton.onActivated = function()
            Store.singleton():save("debug", not debug, true)
        end
    end)

    self.controlOverlaySub = Store.singleton():listen("showOverlay", function(show)
        self.toggleControlsButton.label:setText(show and "Overlay (On)" or "Overlay (Off)")

        self.toggleControlsButton.onActivated = function()
          Store.singleton():save("showOverlay", not show, true)
        end
    end)
end

function OptionsPane:sleep()
    print("Option sleep")
    if self.debugOverlaySub then self.debugOverlaySub() end
    if self.controlOverlaySub then self.controlOverlaySub() end
    Surface.sleep(self)
end


return OptionsPane


