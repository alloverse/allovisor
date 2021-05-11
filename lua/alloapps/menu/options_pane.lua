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
    self.unsub = Store.singleton():listen("debug", function(debug)
        self.debugButton.label:setText(debug and "Debug (On)" or "Debug (Off)")
        self.debugButton.onActivated = function() 
            Store.singleton():save("debug", not debug, true)
        end
    end)

    local toggleControlsButton = ui.Button(ui.Bounds(0, 0.1, 0.01,   1.4, 0.2, 0.15))
    self:addSubview(toggleControlsButton)
    self.unsub_what = Store.singleton():listen("showControls", function(showControls)
        toggleControlsButton.label:setText(showControls and "Controls (On)" or "Controls (Off)")
        toggleControlsButton.onActivated = function() 
            Store.singleton():save("showControls", not showControls, true)
        end
    end)

    local audioButton = ui.Button(ui.Bounds(0, -0.2, 0.01,     1.4, 0.2, 0.15))
    audioButton.label.text = "Audio settings..."
    audioButton.onActivated = function() 
        self.nav:push(AudioPane(menu))
    end
    self:addSubview(audioButton)

end

function AudioPane:sleep()
    Surface.sleep(self)
    if self.unsub then self.unsub() end
end


return OptionsPane


