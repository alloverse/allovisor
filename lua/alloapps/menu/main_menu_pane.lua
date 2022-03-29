local ui = require("alloui.ui")
local pretty = require("pl.pretty")
local class = require("pl.class")
local ConnectPane = require("alloapps.menu.connect_pane")
local OptionsPane = require("alloapps.menu.options_pane")
local mat4 = require("lib.alloui.lib.cpml.modules.mat4")
local vec3 = require("lib.alloui.lib.cpml.modules.vec3")

class.MainMenuPane(ui.Surface)
MainMenuPane.assets = {
  logo= Asset.LovrFile("assets/alloverse-logo.png"),
  arcade= Asset.LovrFile("assets/models/arcade.glb"),
}
function MainMenuPane:_init(menu)
    self.name = "main"
    self:super(ui.Bounds{size=ui.Size(0.6, 0.6, 0.01)})
    self:setColor({1,1,1,1})
    self:setPointable(true)

    local stack = ui.StackView(ui.Bounds{size=ui.Size(0.5, 0.6, 0.01)})
    stack:margin(0.02)
    self:addSubview(stack)

    local menuButtonSize = ui.Bounds{size=ui.Size(0.5, 0.08, 0.05)}
    
    local connectButton = ui.Button(menuButtonSize:copy())
    connectButton.label.text = "Connect..."
    connectButton.onActivated = function() 
      self.nav:push(ConnectPane(menu))
    end
    stack:addSubview(connectButton)
    
    self.optionsPane = OptionsPane(menu)
    local optionsButton = ui.Button(menuButtonSize:copy())
    optionsButton.label.text = "Options..."
    optionsButton.onActivated = function() 
      self.nav:push(self.optionsPane)
    end
    stack:addSubview(optionsButton)

    if lovr.headsetName ~= "Oculus Quest" then
      local gap = ui.View(ui.Bounds{size=ui.Size(0.5, 0.08, 0.05)})
      stack:addSubview(gap)

      local quitButton = ui.Button(menuButtonSize:copy())
      quitButton.label.text = "Quit"
      quitButton.onActivated = function() 
        menu:actuate({"quit"})
      end
      stack:addSubview(quitButton)
    end

    stack:layout()
  
    self.messageLabel = ui.Label{
      bounds = ui.Bounds(0.13, 0.35, 0.01,     0.6, 0.04, 0.01),
      text = "Welcome to Alloverse!",
      color = {0,0,0,1},
      halign = "left"
    }
    self:addSubview(self.messageLabel)
  
    self.logo = ui.Surface(ui.Bounds(-0.25, 0.35, 0.01, 0.08, 0.08, 0.001))
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

    self.versionLabel = ui.Label{
      bounds = ui.Bounds(0, -0.36, 0,     0.6, 0.017, 0.01),
      text = "ver. unknown",
      color = {0.8, 0.8, 0.8, 1},
      halign = "left",
      wrap = true
    }
    self:addSubview(self.versionLabel)
    self:updateVersionLabel()



    local ad = self:addSubview(ui.Surface(ui.Bounds(0, 0, 0,    0.6, 0.6, 0.01):rotate(-0.7, 0,1,0):move(0.65,0,0.2)))
    ad:setColor({0, 0, 0, 0})

    local adStack = ui.StackView(ui.Bounds{size=ui.Size(0.5, 0.6, 0.01)})
    adStack:margin(0.02)
    ad:addSubview(adStack)

    local menuButtonSize = ui.Bounds{size=ui.Size(0.5, 0.08, 0.05)}

    local adLabel = adStack:addSubview(ui.Label{
      bounds = ui.Bounds(0.0, 0.3, 0.01,     0.3, 0.05, 0.1),
      text = "Try our new\nretro arcade!",
      color = {0,0,0,1},
      halign = "center"
    })
    adLabel:doWhenAwake(function()
      adLabel:addPropertyAnimation(ui.PropertyAnimation{
        path= "transform.matrix.translation.z",
        from= 0,
        to=   0.05,
        duration = 1.0,
        repeats= true,
        autoreverses= true,
        easing= "quadInOut",
      })
    end)


    -- In order to scale down the arcade model we need to put it in a container, and then scale said container down.
    local adIconContainer = ui.View(ui.Bounds{size=ui.Size(0.3, 0.3, 0.3)})

    local adIcon = ui.ModelView(ui.Bounds{size=ui.Size(0.3, 0.3, 0.3)}, MainMenuPane.assets.arcade)
    adIcon:doWhenAwake(function()
      adIcon:addPropertyAnimation(ui.PropertyAnimation{
        path= "transform.matrix.rotation.y",
        from= 0,
        to=   6.28,
        duration = 8.0,
        repeats= true,
      })
    end)

    adIconContainer:addSubview(adIcon)
    adIconContainer:setTransform(mat4.scale(mat4.new(), mat4.new(), vec3.new(0.5, 0.5, 0.5)))
    
    adStack:addSubview(adIconContainer)



    local adButtonBackground = ui.Surface(ui.Bounds(0, 0, 0,    0.6, 0.18, 0.01):rotate(-0.7, 0,1,0):move(0.65,0,0.2))
    adButtonBackground:setColor({1, 1, 1, 1})
    adButtonBackground:setPointable(true)

    local adButton = ui.Button(ui.Bounds{size=ui.Size(0.4, 0.08, 0.05)})
    adButton.label.text = "Play~!"
    adButton.onActivated = function() 
      menu:actuate({"connect", "alloplace://arcade.places.alloverse.com"})
    end

    adButtonBackground:addSubview(adButton)
    adStack:addSubview(adButtonBackground)
    

    adStack:layout()
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
