-- Establish that all the basic features of ui2 work

namespace "standard"

local ui = require("alloui.ui")
local ui2 = require "ent.ui2"

local ControlsOverlay = classNamed("ControlsOverlay", ui2.ScreenEnt)

function ControlsOverlay:onLoad()

  print("=================")
  print("= In the ControlsOverlay =")
  print("=================")
  
  ui2.routeMouse()

  local ents = {

    -- WASD buttons
    ui2.AlloKeyEnt{label="W", onButton = function()
      self:onKeyPress("w")
    end},
    ui2.AlloKeyEnt{label="A", onButton = function()
      self:onKeyPress("a")
    end},
    ui2.AlloKeyEnt{label="S", onButton = function()
      self:onKeyPress("s")
    end},
    ui2.AlloKeyEnt{label="D", onButton = function()
      self:onKeyPress("d")
    end},
    ui2.AlloLabelUiEnt{label="Move"},

    
    -- Close button
    ui2.AlloKeyEnt{label="esc", onButton = function()
      print("Closing control overlay")
      self:onKeyPress("escape")
    end},
    ui2.AlloLabelUiEnt{label="Close"},


    -- Grab button
    ui2.AlloKeyEnt{label="F", onButton = function()
      self:onKeyPress("f")
    end},
    ui2.AlloLabelUiEnt{label="Grab"},


  }

  -- local logo = ui.Surface(ui.Bounds(-0.65, 0.8, 0.01, 0.2, 0.2, 0.2))
  -- logo:setTexture("iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAB/UlEQVR4nO2av27CMBCHL0AhQqD+GdshUtVnqNStQxk6dUHqVhbExtTn4MX6Bn2CPsZ1wZEJcRLbd7ZD7ifdwJL4++4sRyQAEolEIpFQBY/V1+s7BwEAVwfE1QHVIikXipMR6NdNRsIJuF5As1i8zUcIAPi3fy/rZ/MaXUS5gDp4gwine+jg1YLQE1EURWdwDxGt4LFEOIFbbAtcXGXW8AYR9OC+8C0ivMC5RJCDN4mggqfaFkHAd18fuN+u2SS4iCiPHS5wdZ7vt+uzCiQibtfrwKsS6s5+zmnAmxlv17uAx5wGVvDlYm4Nr+qxuMfrGfs00ArQx8wVPMQ0sAigBucUQSqAG7wqYTr2e2IkE8Ax7qGmwVtALHAqEc4CUgGvk2AjwktAbGCKSRABlyZASRABIkAEiIAu9fJwN2wBg5+A7+enYQvQpkAEWP0dJgJEgAiIDioCDLWcZk7PAaD96LWA23zUCVy9eIGatEpIWUDTBPzu3s663hSjiJQFmCbABrxVRMoC8klGBn4iQX9jnLIANQHQss+dRaiKDdokAIi63jsRIcCNMhIBDw5fSsgnWXARAIDz431jgVcTTAJE7nhb2ERA4uB6cDam2xbAdKyFiPeJAT3qelOsJcCFgFfTKmLzyffNbyopP3EZStdNKSXAwMD1DBZcIpFIksg/LCx2xNxTGTMAAAAASUVORK5CYII=")
  -- table.insert(ents, logo)

  local alloCustomLayout = ui2.AlloCustomLayout{managed=ents, parent=self, pass={swap=self}}
  alloCustomLayout:layout()
    
end

function ControlsOverlay:onKeyPress(code, scancode)
  --print("ControlsOverlay:onKeyPress", code)
  if code == "escape" then
    self:die()
  end
end

function ControlsOverlay:onMirror()
  uiMode()
end

return ControlsOverlay