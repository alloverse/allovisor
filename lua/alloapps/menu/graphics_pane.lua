local ui = require("alloui.ui")
local pretty = require("pl.pretty")
local class = require("pl.class")
local tablex = require("pl.tablex")
local Store = require("lib.lovr-store")

class.GraphicsPane(ui.Surface)
function GraphicsPane:_init(menu)
    self.menu = menu
    self:super(ui.Bounds{size=ui.Size(0.6, 0.6, 0.01)})
    self:setColor({1,1,1,1})
    self:setPointable(true)

    local stack = ui.StackView(ui.Bounds{size=ui.Size(0.5, 0.6, 0.01)})
    stack:margin(0.02)
    self:addSubview(stack)

    local menuButtonSize = ui.Bounds{size=ui.Size(0.5, 0.08, 0.05)}

    self.reflectionsButton = ui.Button(menuButtonSize:copy())
    self.reflectionsButton.label.text = "Reflections (Off)"
    stack:addSubview(self.reflectionsButton)
    self.reflectionsButtonSub = nil

    stack:layout()
end

function GraphicsPane:awake()
    Surface.awake(self)
    self.reflectionsButtonSub = Store.singleton():listen("graphics.reflections", function(show)
        self.reflectionsButton.label:setText(show and "Reflections (On)" or "Reflections (Off)")

        self.reflectionsButton.onActivated = function()
          Store.singleton():save("graphics.reflections", not show, true)
        end
    end)
end

function GraphicsPane:sleep()
    if self.reflectionsButtonSub then self.reflectionsButtonSub() end
    Surface.sleep(self)
end

return GraphicsPane
