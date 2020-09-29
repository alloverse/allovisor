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
	-- Create some buttons that do different things
	local ents = {

    --ui2.UiEnt{label="Movement"},


    ui2.AlloLabelUiEnt{label="MY ALLOLABEL"},

    ui2.AlloButtonEnt{label="W", onButton = function(self)
      print("ALLO W!")
    end},
    ui2.AlloButtonEnt{label="A", onButton = function(self)
      print("ALLO A!")
    end},
    ui2.AlloButtonEnt{label="S", onButton = function(self)
      print("ALLO S!")
    end},
    ui2.AlloButtonEnt{label="D", onButton = function(self)
      print("ALLO D!")
    end},


    ui2.AlloButtonEnt{label="esc", onButton = function(self)
      print("Closing control overlay")
      self.swap:die()
    end},

		-- ui2.ButtonEnt{label="X", onButton = function(self) -- Test die
    --   self.swap:die()
		-- end},
		-- ui2.ButtonEnt{label="one", onButton = function(self)
		-- 		print("ONE!")
		-- end},
		-- ui2.ButtonEnt{label="RESET", onButton = function(self) -- Test swap
		-- 	self.swap:swap( ControlsOverlay() )
		-- end},
		-- ui2.ButtonEnt{label=1, onButton = function(self) -- Give this ui some state
		-- 		self.label = self.label + 1
		-- end},
	}
	-- Dynamically create some buttons that do nothing, just to fill up space and demonstrate line wrapping
	-- for i,v in ipairs{"buttonx", "nonsense", "garb", "garbage", "not", "hing", "nothing", "no", "thing"} do
	-- 	table.insert(ents, ui2.ButtonEnt{label=v})
	-- end
	-- Create a slider and a value watcher for that slider
	-- local slider = ui2.SliderEnt()
	-- table.insert(ents, slider)
	-- table.insert(ents, ui2.SliderWatcherEnt{watch=slider})


  -- print("dpododoaodoa")
  -- local logo = ui.Surface(ui.Bounds(-0.65, 0.8, 0.01, 0.2, 0.2, 0.2))
  -- logo:setTexture("iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAB/UlEQVR4nO2av27CMBCHL0AhQqD+GdshUtVnqNStQxk6dUHqVhbExtTn4MX6Bn2CPsZ1wZEJcRLbd7ZD7ifdwJL4++4sRyQAEolEIpFQBY/V1+s7BwEAVwfE1QHVIikXipMR6NdNRsIJuF5As1i8zUcIAPi3fy/rZ/MaXUS5gDp4gwine+jg1YLQE1EURWdwDxGt4LFEOIFbbAtcXGXW8AYR9OC+8C0ivMC5RJCDN4mggqfaFkHAd18fuN+u2SS4iCiPHS5wdZ7vt+uzCiQibtfrwKsS6s5+zmnAmxlv17uAx5wGVvDlYm4Nr+qxuMfrGfs00ArQx8wVPMQ0sAigBucUQSqAG7wqYTr2e2IkE8Ax7qGmwVtALHAqEc4CUgGvk2AjwktAbGCKSRABlyZASRABIkAEiIAu9fJwN2wBg5+A7+enYQvQpkAEWP0dJgJEgAiIDioCDLWcZk7PAaD96LWA23zUCVy9eIGatEpIWUDTBPzu3s663hSjiJQFmCbABrxVRMoC8klGBn4iQX9jnLIANQHQss+dRaiKDdokAIi63jsRIcCNMhIBDw5fSsgnWXARAIDz431jgVcTTAJE7nhb2ERA4uB6cDam2xbAdKyFiPeJAT3qelOsJcCFgFfTKmLzyffNbyopP3EZStdNKSXAwMD1DBZcIpFIksg/LCx2xNxTGTMAAAAASUVORK5CYII=")
  -- table.insert(ents, logo)


	-- Lay all the buttons out
  local layout = ui2.PileLayout{managed=ents, parent=self, pass={swap=self}}
  
  local alloCustomLayout = ui2.AlloCustomLayout{managed=ents, parent=self, pass={swap=self}}

	layout:layout()
end

function ControlsOverlay:onMirror()
  uiMode()
  
  
end

return ControlsOverlay