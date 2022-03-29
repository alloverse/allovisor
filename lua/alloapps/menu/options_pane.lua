local ui = require("alloui.ui")
local pretty = require("pl.pretty")
local class = require("pl.class")
local AudioPane = require("alloapps.menu.audio_pane")
local GraphicsPane = require("alloapps.menu.graphics_pane")

class.OptionsPane(ui.Surface)
function OptionsPane:_init(menu)
    self:super(ui.Bounds{size=ui.Size(0.6, 0.6, 0.01)})
    self:setColor({1,1,1,1})
    self:setPointable(true)

    local stack = ui.StackView(ui.Bounds{size=ui.Size(0.5, 0.6, 0.01)})
    stack:margin(0.02)
    self:addSubview(stack)

    local menuButtonSize = ui.Bounds{size=ui.Size(0.5, 0.08, 0.05)}

    self.debugButton = ui.Button(menuButtonSize:copy())
    stack:addSubview(self.debugButton)
    self.debugOverlaySub = nil

    self.audioButton = ui.Button(menuButtonSize:copy())
    self.audioButton.label.text = "Audio settings..."
    self.audioButton.label.fitToWidth=0.45
    self.audioButton.onActivated = function()
        self.nav:push(AudioPane(menu))
    end
    stack:addSubview(self.audioButton)

    self.graphicsButton = ui.Button(menuButtonSize:copy())
    self.graphicsButton.label.text = "Graphics settings..."
    self.graphicsButton.label.fitToWidth=0.45
    self.graphicsButton.onActivated = function()
        self.nav:push(GraphicsPane(menu))
    end
    stack:addSubview(self.graphicsButton)

    stack:layout()
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
end

function OptionsPane:sleep()
    print("Option sleep")
    if self.debugOverlaySub then self.debugOverlaySub() end
    Surface.sleep(self)
end

return OptionsPane
