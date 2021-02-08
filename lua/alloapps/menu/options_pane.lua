local ui = require("alloui.ui")
local pretty = require("pl.pretty")
local class = require("pl.class")
local AudioPane = require("alloapps.menu.audio_pane")

class.OptionsPane(ui.Surface)
function OptionsPane:_init(menu)
    self:super(ui.Bounds{size=ui.Size(1.6, 1.2, 0.1)})
    self:setColor({1,1,1,1})

    self.debugButton = ui.Button(ui.Bounds(0, 0.4, 0.01,   1.4, 0.2, 0.15))
    self.debugButton.label.text = "Debug (Off)"
    self.debugButton.onActivated = function() 
        menu:actuate({"toggleDebug"}) 
    end
    self:addSubview(self.debugButton)

    local audioButton = ui.Button(ui.Bounds(0, 0.1, 0.01,     1.4, 0.2, 0.15))
    audioButton.label.text = "Audio settings..."
    audioButton.onActivated = function() 
        self.nav:push(AudioPane(menu))
    end
    self:addSubview(audioButton)

end

return OptionsPane


