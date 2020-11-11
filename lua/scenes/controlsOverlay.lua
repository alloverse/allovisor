--- A mess of ui2 an alloui stuff for building things.
-- @module ControlsOverlay

namespace "standard"

local ui2 = require "ent.ui2"
ui2.doRouteMouse = false
local flat = require "engine.flat"
local vec2 = require "cpml.modules.vec2"

local ControlsOverlay = classNamed("ControlsOverlay", ui2.ScreenEnt)
local AlloCustomLayout = classNamed("AlloCustomLayout", ui2.Layout)


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
    ui2.AlloKeyEnt{id="r",label="R", onButton = function()
      self:onKeyPress("r")
    end},
    ui2.AlloLabelUiEnt{id="movelabel", label="Move"},
    ui2.AlloLabelUiEnt{id="menulabel", label="Menu"},

    
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

  local alloCustomLayout = AlloCustomLayout{managed=ents, parent=self, pass={swap=self}}
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



-- spec:
--     face: "x" or "y" -- default "x"
--     anchor: any combination of "tblr", default "lb"
-- members:
--     cursor: Next place to put a button
--     linemax (optional): greatest width of a button this line
function AlloCustomLayout:_init(spec)
	pull(self, {face="x"})
	self:super(spec)
	self.anchor = "lb" .. (self.anchor or "")
end

local margin = 0.05 -- Margin around text. Tunable 

-- Perform all layout at once. If true, re-lay-out things already laid out
function AlloCustomLayout:layout(relayout)
	-- Constants: Logic
	local moveright, moveup = ui2.anchorBools(self.anchor) -- Which direction are we moving?
	local mn = #self.managed -- Number of managed items
	local startAt = relayout and 1 or (self.placedTo+1) -- From what button do we begin laying out?

	-- Constants: Metrics
	local fh = ui2.fontHeight() -- Raw height of font
	local screenmargin = (fh + margin*2)/2 -- Space between edge of screen and buttons. Tunable
	local spacing = 0 -- spacing is baked into the button due to drop shadow being part of the asset

	-- Logic constants
	local leftedge = -flat.xspan + screenmargin -- Start lines on left
	local rightedge = -leftedge        -- Wrap around on right
	local bottomedge = -flat.yspan + screenmargin -- Start render on bottom
	local topedge = -bottomedge
	local xface = self.face == "x"
	local axis = vec2(moveright and 1 or -1, moveup and 1 or -1) -- Only thing anchor impacts

    

	for i = startAt,mn do -- Lay out everything not laid out
    local e = self.managed[i] -- Entity to place

    local buttonWidth = 0.2
    local buttonHeight = 0.2
    local labelHeight = 0.1
    local labelSpacing = 0.02 -- vertical spacing between label and button

    local mouseButtonWidth = 0.1
    local mouseButtonHeight = 0.15

    local dummyMouseWidth = 0.2
    local dummyMouseHeight = 0.3

    local dummyMouseRightMargin = 0.3

    local bound

    -- wasd
    if e.id == "w" then
      bound = bound2(vec2(leftedge+spacing+buttonWidth, bottomedge-labelHeight/2+labelHeight+labelSpacing+spacing*2+buttonHeight), vec2(leftedge+spacing+buttonWidth*2, bottomedge-labelHeight/2+labelHeight+labelSpacing+spacing*3+buttonHeight*2))
    elseif e.id == "a" then
      bound = bound2(vec2(leftedge, bottomedge-labelHeight/2+labelHeight+labelSpacing+spacing), vec2(leftedge+buttonWidth, bottomedge-labelHeight/2+spacing+labelHeight+labelSpacing+buttonHeight))
    elseif e.id == "s" then
      bound = bound2(vec2(leftedge+spacing+buttonWidth, bottomedge-labelHeight/2+labelHeight+labelSpacing+spacing), vec2(leftedge+spacing+buttonWidth*2, bottomedge-labelHeight/2+spacing+labelHeight+labelSpacing+buttonHeight))  
    elseif e.id == "d" then
      bound = bound2(vec2(leftedge+spacing*2+buttonWidth*2, bottomedge-labelHeight/2+labelHeight+labelSpacing+spacing), vec2(leftedge+spacing*2+buttonWidth*3, bottomedge-labelHeight/2+spacing+labelHeight+labelSpacing+buttonHeight))
    elseif e.id == "movelabel" then
      bound = bound2(vec2(leftedge+buttonWidth, bottomedge-labelHeight/2), vec2(leftedge+spacing+buttonWidth*2, bottomedge-labelHeight/2+labelHeight))

    -- close
    elseif e.id == "escape" then
      bound = bound2(vec2(leftedge, topedge-buttonHeight), vec2(leftedge+buttonWidth, topedge))
    elseif e.id == "closelabel" then
      bound = bound2(vec2(leftedge, topedge-buttonHeight-labelHeight-labelSpacing-spacing), vec2(leftedge+buttonWidth, topedge-buttonHeight-labelSpacing-spacing))

    -- grab
    elseif e.id == "f" then
      bound = bound2(vec2(.8+leftedge, bottomedge-labelHeight/2+labelHeight+labelSpacing), vec2(.8+leftedge+buttonWidth, bottomedge-labelHeight/2+buttonHeight+labelHeight+labelSpacing))
    elseif e.id == "grablabel" then
      bound = bound2(vec2(.8+leftedge, bottomedge-labelHeight/2), vec2(.8+leftedge+buttonWidth, bottomedge-labelHeight/2+labelHeight))

	-- menu
	elseif e.id == "r" then
		bound = bound2(vec2(1.2+leftedge, bottomedge-labelHeight/2+labelHeight+labelSpacing), vec2(1.2+leftedge+buttonWidth, bottomedge-labelHeight/2+buttonHeight+labelHeight+labelSpacing))
	elseif e.id == "menulabel" then
		bound = bound2(vec2(1.2+leftedge, bottomedge-labelHeight/2), vec2(1.2+leftedge+buttonWidth, bottomedge-labelHeight/2+labelHeight))

    -- mouse
    elseif e.id == "dummyMouse" then
      bound = bound2(vec2(rightedge-dummyMouseRightMargin-dummyMouseWidth, bottomedge-labelHeight/2+labelHeight+labelSpacing), vec2(rightedge-dummyMouseRightMargin, bottomedge-labelHeight/2+labelHeight+labelSpacing+dummyMouseHeight))
    elseif e.id == "lmb" then
      bound = bound2(vec2(rightedge-dummyMouseRightMargin-dummyMouseWidth, bottomedge-labelHeight/2+labelHeight+labelSpacing+dummyMouseHeight-mouseButtonHeight), vec2(rightedge-dummyMouseRightMargin-dummyMouseWidth+mouseButtonWidth, bottomedge-labelHeight/2+labelHeight+labelSpacing+dummyMouseHeight))
    elseif e.id == "rmb" then
      bound = bound2(vec2(rightedge-dummyMouseRightMargin-dummyMouseWidth+mouseButtonWidth, bottomedge-labelHeight/2+labelHeight+labelSpacing+dummyMouseHeight-mouseButtonHeight), vec2(rightedge-dummyMouseRightMargin, bottomedge-labelHeight/2+labelHeight+labelSpacing+dummyMouseHeight))
    elseif e.id == "lookLabel" then
      bound = bound2(vec2(rightedge-0.78, bottomedge-labelHeight/2+labelHeight+labelSpacing+dummyMouseHeight-labelHeight), vec2(rightedge-0.58, bottomedge-labelHeight/2+labelHeight+labelSpacing+dummyMouseHeight))
    elseif e.id == "interactLabel" then
      bound = bound2(vec2(rightedge-0.22, bottomedge-labelHeight/2+labelHeight+labelSpacing+dummyMouseHeight-labelHeight), vec2(rightedge-0.02, bottomedge-labelHeight/2+labelHeight+labelSpacing+dummyMouseHeight))
    elseif e.id == "pointLabel" then
      bound = bound2(vec2(rightedge-dummyMouseRightMargin-dummyMouseWidth, bottomedge-labelHeight/2), vec2(rightedge-dummyMouseRightMargin, bottomedge-labelHeight/2+labelHeight))

    else
      print("UNEXPECTED: Layouting something not strictly defined")
      bound = bound2(vec2(0,0), vec2(0.2,0.2))
    end
    e.bound = bound

    self:manage(e)

  end

  self.managedTo = mn
  self.placedTo = mn
end



-- Draw dummy Mouse
ui2.AlloDummyMouseEnt = classNamed("AlloDummyMouseEnt", ui2.UiBaseEnt)

local dummyMouseTex = lovr.graphics.newTexture("assets/textures/controls-overlay/dummy-mouse.png", {})
local dummyMouseMat = lovr.graphics.newMaterial(dummyMouseTex, 1, 1, 1, 1)


function ui2.AlloDummyMouseEnt:sizeHint(margin, overrideText)
  return vec2(0.2,0.3)
end

function ui2.AlloDummyMouseEnt:onMirror()
  -- ui2.UiBaseEnt.onMirror(self)

	local center = self.bound:center()
  local size = self.bound:size()
	
  -- set dummyMouse texture (technically, material)
  
  lovr.graphics.plane(dummyMouseMat, center.x, center.y, 0, size.x, size.y)
end






ui2.AlloLabelUiEnt = classNamed("AlloLabelUiEnt", ui2.UiBaseEnt)

function ui2.AlloLabelUiEnt:sizeHint(margin, overrideText)
	local label = overrideText or self.label
	if not label then error("Button without label") end -- TODO: This may be too restrictive

	local fh = fontHeight() -- Raw height of font
	local h = fh + margin*2 -- Height of a button
	local fw = flat.font:getWidth(label)*flat.fontscale -- Text width
	local w = fw + margin*2 -- Button width
	return vec2(w, h)
end

function ui2.AlloLabelUiEnt:onMirror()
	local center = self.bound:center()
	local size = self.bound:size()

  lovr.graphics.setColor(0,0,0,0.30)
  lovr.graphics.plane('fill', center.x, center.y, 0, size.x, size.y)
  lovr.graphics.arc('fill', 'pie', center.x+size.x/2, center.y, 0, size.y/2, 0, 0, 1, 0, -math.pi/2, math.pi/2, 32)
  lovr.graphics.arc('fill', 'pie', center.x-size.x/2, center.y, 0, size.y/2, 0, 0, 1, 0, math.pi/2, math.pi*1.5, 32)

  lovr.graphics.setFont(flat.font)
  lovr.graphics.setColor(1,1,1,1)
  lovr.graphics.print(self.label, center.x, center.y, 0, flat.fontscale)
  lovr.graphics.setColor(1,1,1,1)
end



ui2.AlloKeyEnt = classNamed("AlloKeyEnt", ui2.UiBaseEnt) -- Expects in spec: bounds=, label=

local whiteBtnTex = lovr.graphics.newTexture("assets/textures/controls-overlay/key.png", {})
local whiteBtnMat = lovr.graphics.newMaterial(whiteBtnTex, 1, 1, 1, 1)
local whiteBtnDownTex = lovr.graphics.newTexture("assets/textures/controls-overlay/key-down.png")
local whiteBtnDownMat = lovr.graphics.newMaterial(whiteBtnDownTex, 1, 1, 1, 1)

function ui2.AlloKeyEnt:onLoad()
end

function ui2.AlloKeyEnt:sizeHint(margin, overrideText)
  -- hardcodes AlloKeyEnt size instead of dynamically setting it from text height & width
  return vec2(0.2, 0.2)
end

function ui2.AlloKeyEnt:onKeyPress(code)
  if code == string.lower(self.id) then
    self.down = true
  end
end

function ui2.AlloKeyEnt:onKeyReleased(code)
  if code == string.lower(self.id) then
    self.down = false
  end
end

function ui2.AlloKeyEnt:onPress(at)
	if self.bound:contains(at) then
		self.down = true
	end
end

function ui2.AlloKeyEnt:onRelease(at)
	if self.bound:contains(at) then
		self:onButton(at) -- FIXME: Is it weird this is an "on" but it does not route?
	end
	self.down = false
end

function ui2.AlloKeyEnt:onButton()
  print("AlloKeyEnt:onButton()")
end

function ui2.AlloKeyEnt:onMirror()
  ui2.UiEnt.onMirror(self)

	local center = self.bound:center()
  local size = self.bound:size()
	
  -- set button texture (technically, material) based on button being down or not
  lovr.graphics.plane(self.down and whiteBtnDownMat or whiteBtnMat, center.x, center.y, 0, size.x, size.y)

  -- set font color based on button being down or not  
  local buttonLabelColor = self.down and 1.0 or 0.0
  lovr.graphics.setFont(flat.font)
  lovr.graphics.setColor(buttonLabelColor,buttonLabelColor,buttonLabelColor,1)
  lovr.graphics.print(self.label, center.x, center.y, 0, flat.fontscale)
  lovr.graphics.setColor(1,1,1,1)
end



ui2.AlloMouseButtonEnt = classNamed("AlloMouseButtonEnt", ui2.UiBaseEnt) -- Expects in spec: bounds=, label=

local whiteLmbTex = lovr.graphics.newTexture("assets/textures/controls-overlay/lmb.png", {})
local whiteLmbMat = lovr.graphics.newMaterial(whiteLmbTex, 1, 1, 1, 1)
local whiteLmbDownTex = lovr.graphics.newTexture("assets/textures/controls-overlay/lmb-down.png")
local whiteLmbDownMat = lovr.graphics.newMaterial(whiteLmbDownTex, 1, 1, 1, 1)

local whiteRmbTex = lovr.graphics.newTexture("assets/textures/controls-overlay/rmb.png", {})
local whiteRmbMat = lovr.graphics.newMaterial(whiteRmbTex, 1, 1, 1, 1)
local whiteRmbDownTex = lovr.graphics.newTexture("assets/textures/controls-overlay/rmb-down.png")
local whiteRmbDownMat = lovr.graphics.newMaterial(whiteRmbDownTex, 1, 1, 1, 1)

function ui2.AlloMouseButtonEnt:onLoad()
end

function ui2.AlloMouseButtonEnt:sizeHint(margin, overrideText)
  -- hardcodes AlloMouseButtonEnt size instead of dynamically setting it from text height & width
  return vec2(0.1, 0.2)
end

function ui2.AlloMouseButtonEnt:onMousePressed(x, y, button)
  if self.id == "lmb" and button == 1 or self.id == "rmb" and button == 2 then
    self.down = true
  end
end 

function ui2.AlloMouseButtonEnt:onMouseReleased(x, y, button)
  if self.id == "lmb" and button == 1 or self.id == "rmb" and button == 2 then
    self.down = false
  end
end

function ui2.AlloMouseButtonEnt:onMirror()
  ui2.UiEnt.onMirror(self)

	local center = self.bound:center()
  local size = self.bound:size()
	
  -- set button texture (technically, material) based on button being down or not
  lovr.graphics.setColor(1,1,1,1)
  if self.id == "lmb" then
    lovr.graphics.plane(self.down and whiteLmbDownMat or whiteLmbMat, center.x, center.y, 0.1, size.x, size.y)
  elseif self.id == "rmb" then
    lovr.graphics.plane(self.down and whiteRmbDownMat or whiteRmbMat, center.x, center.y, 0.1, size.x, size.y)
  end

end





return ControlsOverlay