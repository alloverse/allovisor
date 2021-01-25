local ui = require("alloui.ui")
local pretty = require("pl.pretty")
local class = require("pl.class")

class.ConnectPane(ui.Surface)
function ConnectPane:_init(menu)
    self:super(ui.Bounds{size=ui.Size(1.6, 1.2, 0.1)})
    self:setColor({1,1,1,1})

    local connectionList = {
        {"Nevyn's place", "alloplace://nevyn.places.alloverse.com"},
        {"R4", "alloplace://r4.nevyn.nu"},
        {"Localhost", "alloplace://localhost"},
    }

    for i, conn in ipairs(connectionList) do  
        local connectButton = ui.Button(ui.Bounds(0, 0.7 - i*0.3, 0.01,   1.4, 0.2, 0.15))
        connectButton.label.text = conn[1]
        connectButton.onActivated = function() menu:actuate({"connect", conn[2]}) end
        self:addSubview(connectButton)
    end
end

return ConnectPane
