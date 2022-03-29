local ui = require("alloui.ui")
local pretty = require("pl.pretty")
local class = require("pl.class")

class.ConnectPane(ui.Surface)
function ConnectPane:_init(menu)
    self.menu = menu
    self:super(ui.Bounds{size=ui.Size(0.6, 0.6, 0.01)})
    self:setColor({1,1,1,1})
    self:setPointable(true)

    local vstack = ui.StackView(ui.Bounds{size=ui.Size(0.5, 0.6, 0.01)})
    vstack:margin(0.02)
    self:addSubview(vstack)

    local menuHeaderSize = ui.Bounds{size=ui.Size(0.5, 0.03, 0.01)}
    local menuButtonSize = ui.Bounds{size=ui.Size(0.5, 0.08, 0.05)}

    local connectHeaderLabel = ui.Label{
        bounds= menuHeaderSize:copy(),
        text= "URL to place:",
        color={0,0,0,1},
        halign="left"
    }
    vstack:addSubview(connectHeaderLabel)

    local connectField = ui.TextField{
        bounds= menuButtonSize:copy(),
    }
    connectField.onReturn = function(field, text)
      self:connect(text)
    end
    vstack:addSubview(connectField)

    local connectButton = ui.Button(menuButtonSize:copy())
    connectButton.label.text = "Connect"
    connectButton.onActivated = function()
        self:connect(connectField.label.text)
    end
    vstack:addSubview(connectButton)

    local headerLabel = ui.Label{
      bounds= ui.Bounds{size=ui.Size(0.5, 0.03, 0.01)},
      text= "Recent Places:",
      color={0,0,0,1},
      halign="left"
    }
    vstack:addSubview(headerLabel)

    for i, conn in ipairs(Store.singleton():load("recentPlaces")) do
        local connectToPlaceButton = ui.Button(menuButtonSize:copy())
        connectToPlaceButton.label.text = conn.name or conn.url
        connectToPlaceButton.label.fitToWidth=0.45
        connectToPlaceButton.onActivated = function() self:connect(conn.url) end
        vstack:addSubview(connectToPlaceButton)
    end
    
    vstack:layout()


    self:doWhenAwake(function()
      self.bounds.size.height = vstack.bounds.size.height + 0.1
      self:setBounds()
    end)


end

function ConnectPane:connect(urlOrName)
    local isComplete = string.find(urlOrName, ".", 1, true) ~= nil or urlOrName == "localhost" or urlOrName == "alloplace://localhost"
    if not isComplete then
        urlOrName = urlOrName .. ".places.alloverse.com"
    end
    if string.find(urlOrName, "alloplace://") == nil then
        urlOrName = "alloplace://" .. urlOrName
    end
    self.menu:actuate({"connect", urlOrName})
end

return ConnectPane
