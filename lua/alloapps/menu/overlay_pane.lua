local ui = require("alloui.ui")
local pretty = require("pl.pretty")
local class = require("pl.class")
local OptionsPane = require("alloapps.menu.options_pane")

class.OverlayPane(ui.Surface)
OverlayPane.assets = {
  logo= Asset.LovrFile("assets/alloverse-logo.png"),
}
function OverlayPane:_init(menu)
    self.name = "overlay"
    self:super(ui.Bounds{size=ui.Size(0.6, 0.6, 0.001)})
    self:setColor({1,1,1,1})

    self.optionsPane = OptionsPane(menu)

    local vstack = ui.StackView(ui.Bounds{size=ui.Size(0.5, 0.6, 0.001)})
    vstack:margin(0.02)
    self:addSubview(vstack)

    local menuButtonSize = ui.Bounds{size=ui.Size(0.5, 0.08, 0.05)}


    local optionsButton = ui.Button(menuButtonSize:copy())
    optionsButton.color = {0.6, 0.6, 0.3, 1.0}
    optionsButton.label.text = "Options..."
    optionsButton.onActivated = function() 
      self.nav:push(self.optionsPane)
    end
    vstack:addSubview(optionsButton)
    
  
    local disconnectButton = ui.Button(menuButtonSize:copy())
    disconnectButton.label.text = "Disconnect"
    disconnectButton.onActivated = function() menu:actuate({"disconnect"}) end
    vstack:addSubview(disconnectButton)


    if lovr.headsetName ~= "Oculus Quest" then
      local quitButton = ui.Button(menuButtonSize:copy())
      quitButton.label.text = "Quit!"
      quitButton.onActivated = function() menu:actuate({"quit"}) end
      vstack:addSubview(quitButton)
    end

    local dismissButton = ui.Button(menuButtonSize:copy())
    dismissButton.color = {0.6, 0.6, 0.3, 1.0}
    dismissButton.label.text = "Dismiss"
    dismissButton.onActivated = function() menu:actuate({"dismiss"}) end
    vstack:addSubview(dismissButton)

    
  
    local titleHStack = ui.StackView(ui.Bounds{size=ui.Size(0.5, 0.035, 0.001)}:move(-0.25, 0.33, 0), "h")
    
    self:addSubview(titleHStack)
  
    self.messageLabel = ui.Label{
      bounds = ui.Bounds{size=ui.Size(0,0,0)},
      text = "Not connected",
      color = {0,0,0,1},
      halign = "left"
    }
    titleHStack:addSubview(self.messageLabel)
  
    self.logo = ui.Surface(ui.Bounds{size=ui.Size(0.035, 0.035, 0.001)})
    self.logo:setTexture(OverlayPane.assets.logo)
    titleHStack:addSubview(self.logo)

    titleHStack:layout()


    vstack:layout()
end

return OverlayPane
