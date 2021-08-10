local ui = require("alloui.ui")
local pretty = require("pl.pretty")
local class = require("pl.class")
local tablex = require("pl.tablex")
local Store = require("lib.lovr-store")

class.GraphicsPane(ui.Surface)
function GraphicsPane:_init(menu)
    self.menu = menu
    self:super(ui.Bounds{size=ui.Size(1.6, 1.2, 0.1)})
    self:setColor({1,1,1,1})

    self.reflectionsButton = ui.Button(ui.Bounds(0, 0.4, 0.01,   1.4, 0.2, 0.15))
    self.reflectionsButton.label.text = "Reflections (Off)"
    self:addSubview(self.reflectionsButton)
    self.reflectionsButtonSub = nil
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
