local ui = require("alloui.ui")
local pretty = require("pl.pretty")
local class = require("pl.class")

class.ConnectPane(ui.Surface)
function ConnectPane:_init(menu)
    self.menu = menu
    self:super(ui.Bounds{size=ui.Size(0.6, 0.6, 0.1)})
    self:setColor({1,1,1,1})

    local stack = ui.StackView(ui.Bounds{size=ui.Size(0.5, 0.6, 0.01)})
    stack:margin(0.03)
    self:addSubview(stack)

    local menuHeaderSize = ui.Bounds{size=ui.Size(0.5, 0.04, 0.01)}
    local menuButtonSize = ui.Bounds{size=ui.Size(0.5, 0.08, 0.05)}

    local connectHeaderLabel = ui.Label{
        bounds= menuHeaderSize:copy(),
        text= "URL to place:",
        color={0,0,0,1},
        halign="left"
    }
    stack:addSubview(connectHeaderLabel)

    local connectField = ui.TextField{
        bounds= menuButtonSize:copy(),
    }
    connectField.onReturn = function(field, text)
      self:connect(text)
    end
    stack:addSubview(connectField)

    local connectButton = ui.Button(menuButtonSize:copy())
    connectButton.label.text = "Connect"
    connectButton.onActivated = function()
        self:connect(connectField.label.text)
    end
    stack:addSubview(connectButton)

    local headerLabel = ui.Label{
      bounds= ui.Bounds{size=ui.Size(0.5, 0.04, 0.01)},
      text= "Recent Places:",
      color={0,0,0,1},
      halign="left"
    }
    stack:addSubview(headerLabel)

    for i, conn in ipairs(Store.singleton():load("recentPlaces")) do
        local connectToPlaceButton = ui.Button(menuButtonSize:copy())
        connectToPlaceButton.label.text = conn.name or conn.url
        connectToPlaceButton.onActivated = function() self:connect(conn.url) end
        stack:addSubview(connectToPlaceButton)
    end
    
    stack:layout()



    -- local pen = self.bounds:copy()
    -- pen.size.width = pen.size.width - 0.2
    -- pen.size.height = 0.2
    -- pen:move(0, self.bounds.size.height/2 - 0.1, 0.05)

    -- local fieldHeaderLabel = self:addSubview(ui.Label{
    --     bounds= pen:copy():inset(0, 0.12, 0):move(0, 0, 0),
    --     text= "URL to place:",
    --     color={0,0,0,1},
    --     halign="left"
    -- })

    -- pen:move(0, -pen.size.height, 0)
    -- local placeField = self:addSubview(ui.TextField(
    --     pen:copy():inset(0, 0.04, 0)
    -- ))
    -- placeField.onReturn = function(field, text)
    --     self:connect(text)
    -- end

    -- pen:move(0, -pen.size.height*1.2, 0)
    -- local connectButton = self:addSubview(ui.Button(pen:copy()))
    -- connectButton.label.text = "Connect"
    -- connectButton.onActivated = function()
    --     self:connect(placeField.label.text)
    -- end

    -- pen:move(0 , -pen.size.height - 0.1, 0)
    -- local headerLabel = self:addSubview(ui.Label{
    --     bounds= pen:copy():inset(0, 0.12, 0):move(0, 0, 0),
    --     text= "Recent Places:",
    --     color={0,0,0,1},
    --     halign="left"
    -- })

    -- pen:move(0, -pen.size.height, 0)
    -- for i, conn in ipairs(Store.singleton():load("recentPlaces")) do
    --     local connectButton = self:addSubview(ui.Button(pen:copy()))
    --     connectButton.label.text = conn.name or conn.url
    --     connectButton.onActivated = function() self:connect(conn.url) end
    --     pen:move(0, -pen.size.height*1.2, 0)
    -- end
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
