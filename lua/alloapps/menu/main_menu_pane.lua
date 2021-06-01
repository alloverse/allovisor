local ui = require("alloui.ui")
local pretty = require("pl.pretty")
local class = require("pl.class")
local ConnectPane = require("alloapps.menu.connect_pane")
local OptionsPane = require("alloapps.menu.options_pane")

class.MainMenuPane(ui.Surface)
MainMenuPane.assets = {
  logo= Base64Asset("iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAB/UlEQVR4nO2av27CMBCHL0AhQqD+GdshUtVnqNStQxk6dUHqVhbExtTn4MX6Bn2CPsZ1wZEJcRLbd7ZD7ifdwJL4++4sRyQAEolEIpFQBY/V1+s7BwEAVwfE1QHVIikXipMR6NdNRsIJuF5As1i8zUcIAPi3fy/rZ/MaXUS5gDp4gwine+jg1YLQE1EURWdwDxGt4LFEOIFbbAtcXGXW8AYR9OC+8C0ivMC5RJCDN4mggqfaFkHAd18fuN+u2SS4iCiPHS5wdZ7vt+uzCiQibtfrwKsS6s5+zmnAmxlv17uAx5wGVvDlYm4Nr+qxuMfrGfs00ArQx8wVPMQ0sAigBucUQSqAG7wqYTr2e2IkE8Ax7qGmwVtALHAqEc4CUgGvk2AjwktAbGCKSRABlyZASRABIkAEiIAu9fJwN2wBg5+A7+enYQvQpkAEWP0dJgJEgAiIDioCDLWcZk7PAaD96LWA23zUCVy9eIGatEpIWUDTBPzu3s663hSjiJQFmCbABrxVRMoC8klGBn4iQX9jnLIANQHQss+dRaiKDdokAIi63jsRIcCNMhIBDw5fSsgnWXARAIDz431jgVcTTAJE7nhb2ERA4uB6cDam2xbAdKyFiPeJAT3qelOsJcCFgFfTKmLzyffNbyopP3EZStdNKSXAwMD1DBZcIpFIksg/LCx2xNxTGTMAAAAASUVORK5CYII=")
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
      bounds = ui.Bounds(-0.09, -0.71, 0.01,     1.4, 0.07, 0.1),
      text = "ver. unknown",
      color = {0.5, 0.5, 0.5, 1},
      halign = "left"
    }
    self:addSubview(self.versionLabel)
    self:updateVersionLabel()
  
    local logo = ui.Surface(ui.Bounds(-0.65, 0.8, 0.01, 0.2, 0.2, 0.2))
    logo:setTexture(MainMenuPane.assets.logo)
    logo.hasTransparency = true
    self:addSubview(logo)
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

function MainMenuPane:updateVersionLabel()
  local versionString = string.format("App version: %s\nNetwork version: %s", ffi.string(ffi.C.GetAllovisorVersion()), ffi.string(ffi.C.GetAllonetVersion()))
  self.versionLabel:setText(versionString)
end

return MainMenuPane
