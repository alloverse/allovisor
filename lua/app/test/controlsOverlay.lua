-- Establish that all the basic features of ui2 work

namespace "standard"

local ui = require("alloui.ui")
local ui2 = require "ent.ui2"

local ControlsOverlay = classNamed("ControlsOverlay", ui2.ScreenEnt)

function ControlsOverlay:onLoad()

  ui2.routeMouse()

  local ents = {

    -- WASD buttons
    ui2.AlloKeyEnt{id="w", label="W", onButton = function()
      self:onKeyPress("w")
    end},
    ui2.AlloKeyEnt{id="a",label="A", onButton = function()
      self:onKeyPress("a")
    end},
    ui2.AlloKeyEnt{id="s",label="S", onButton = function()
      self:onKeyPress("s")
    end},
    ui2.AlloKeyEnt{id="d",label="D", onButton = function()
      self:onKeyPress("d")
    end},
    ui2.AlloLabelUiEnt{id="movelabel", label="Move"},

    
    -- Close button
    ui2.AlloKeyEnt{id="escape", label="esc", onButton = function()
      print("Closing control overlay")
      self:onKeyPress("escape")
    end},
    ui2.AlloLabelUiEnt{id="closelabel", label="Close"},


    -- Grab button
    ui2.AlloKeyEnt{id="f", label="F", onButton = function()
      self:onKeyPress("f")
    end},
    ui2.AlloLabelUiEnt{id="grablabel", label="Grab"},


    -- Mouse
    ui2.AlloDummyMouseEnt{id="dummyMouse"},

    ui2.AlloMouseButtonEnt{id="lmb", label="", onButton = function()
      self:onClickDown()
    end},
    ui2.AlloMouseButtonEnt{id="rmb", label="", onButton = function()
      self:onClickDown()
    end},

    ui2.AlloLabelUiEnt{id="lookLabel", label="Look"},
    ui2.AlloLabelUiEnt{id="interactLabel", label="Interact"},
    ui2.AlloLabelUiEnt{id="pointLabel", label="Point"},

  }

  local alloCustomLayout = ui2.AlloCustomLayout{managed=ents, parent=self, pass={swap=self}}
  alloCustomLayout:layout()
    
end

function ControlsOverlay:onKeyPress(code, scancode)
  --print("ControlsOverlay:onKeyPress", code)
  if code == "escape" then
    self:die()
  end
end

function ControlsOverlay:onMousePress(x, y)
  print("ControlsOverlay:onMousePress", x, y)
end

function ControlsOverlay:onMirror()
  uiMode()
end

return ControlsOverlay