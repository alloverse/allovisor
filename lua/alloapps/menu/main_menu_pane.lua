local ui = require("alloui.ui")
local pretty = require("pl.pretty")
local class = require("pl.class")
local ConnectPane = require("alloapps.menu.connect_pane")
local OptionsPane = require("alloapps.menu.options_pane")

class.MainMenuPane(ui.Surface)
MainMenuPane.assets = {
  logo= Asset.LovrFile("assets/alloverse-logo.png")
}
function MainMenuPane:_init(menu)
    self.name = "main"
    self:super(ui.Bounds{size=ui.Size(1.6, 1.2, 0.1)})
    self:setColor({1,1,1,1})

    if lovr.headsetName ~= "Oculus Quest" then
      local quitButton = ui.Button(ui.Bounds(0, -0.4, 0.01,     1.4, 0.2, 0.15))
      quitButton.label.text = "Quit"
      quitButton.onActivated = function() 
        menu:actuate({"quit"})
      end
      self:addSubview(quitButton)
    end
    
    local connectButton = ui.Button(ui.Bounds(0, 0.4, 0.01,   1.4, 0.2, 0.15))
    connectButton.label.text = "Connect..."
    connectButton.onActivated = function() 
      self.nav:push(ConnectPane(menu))
    end
    self:addSubview(connectButton)
    
    self.optionsPane = OptionsPane(menu)
    local optionsButton = ui.Button(ui.Bounds(0, 0.1, 0.01,     1.4, 0.2, 0.15))
    optionsButton.label.text = "Options..."
    optionsButton.onActivated = function() 
      self.nav:push(self.optionsPane)
    end
    self:addSubview(optionsButton)
  
    self.messageLabel = ui.Label{
      bounds = ui.Bounds(0.2, 0.8, 0.01,     1.4, 0.1, 0.1),
      text = "Welcome to Alloverse",
      color = {0,0,0,1},
      halign = "left"
    }
    self:addSubview(self.messageLabel)

    self.versionLabel = ui.Label{
      bounds = ui.Bounds(-0.09, -0.80, 0.01,     1.4, 0.05, 0.1),
      text = "ver. unknown",
      color = {0.5, 0.5, 0.5, 1},
      halign = "left"
    }
    self:addSubview(self.versionLabel)
    self:updateVersionLabel()
  
    self.logo = ui.Surface(ui.Bounds(-0.65, 0.8, 0.01, 0.2, 0.2, 0.2))
    self.logo:setTexture(MainMenuPane.assets.logo)
    self.logo.hasTransparency = true
    self:addSubview(self.logo)
    self.logo:doWhenAwake(function()
      self.logo:addPropertyAnimation(ui.PropertyAnimation{
        path= "transform.matrix.rotation.y",
        start_at = self.app:serverTime() + 1.0,
        from= -0.2,
        to=   0.2,
        duration = 2.0,
        repeats= true,
        autoreverses= true,
        easing= "elasticOut",
      })
    end)

    local ad = self:addSubview(ui.Surface(ui.Bounds(0, 0, 0,    1, 0.7, 0.1):rotate(-0.4, 0,1,0):move(1.5,0,0)))
    ad:setColor({1.0, 1.0, 0.9, 1.0})
    local adLabel = ad:addSubview(ui.Label{
      bounds = ui.Bounds(0.0, 0.2, 0.01,     0.3, 0.1, 0.1),
      text = "Try our new\nretro arcade!",
      color = {0,0,0,1},
      halign = "center"
    })
    adLabel:doWhenAwake(function()
      adLabel:addPropertyAnimation(ui.PropertyAnimation{
        path= "transform.matrix.translation.z",
        start_at = self.app:serverTime() + 0.1,
        from= 0,
        to=   0.2,
        duration = 1.0,
        repeats= true,
        autoreverses= true,
        easing= "quadInOut",
      })
    end)
    local adButton = ad:addSubview(ui.Button(ui.Bounds(0, -0.2, 0.01,     0.65, 0.2, 0.15)))
    adButton.label.text = "Play~!"
    adButton.onActivated = function() 
      menu:actuate({"connect", "alloplace://arcade.places.alloverse.com"})
    end
end

local ffi = require("ffi")
ffi.cdef[[
  const char *GetAllonetVersion();
  const char *GetAllonetNumericVersion();
  const char *GetAllonetGitHash();
  int GetAllonetProtocolVersion();
  const char *GetAllovisorVersion();
  const char *GetAllovisorNumericVersion();
  const char *GetAllovisorGitHash();
]]

local AllonetC = ffi.os == 'Windows' and ffi.load('allonet') or ffi.C
local VisorC = ffi.C

function MainMenuPane:updateVersionLabel()
  local versionString = string.format("App version: %s\nNetwork version: %s", ffi.string(VisorC.GetAllovisorVersion()), ffi.string(AllonetC.GetAllonetVersion()))
  versionString = versionString.."\n\nThis software uses libraries from the FFmpeg project under the LGPLv2.1.\nSee https://docs.alloverse.com/licenses for all OSS licenses used."
  self.versionLabel:setText(versionString)
end

return MainMenuPane
