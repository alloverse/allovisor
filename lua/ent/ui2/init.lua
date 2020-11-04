-- 2D UI classes
-- Assumes pl, ent and mode are in namespace

-- "PSEUDOEVENTS"- FUNCTIONS CALLED, BUT NOT ROUTED, AS PART OF UI
-- onButton, onChange, onLayout(l)

namespace "standard"

local flat = require "engine.flat"
local ui2 = {}
local vec2 = require "cpml.modules.vec2"

local function fontHeight()
	return flat.font:getHeight()*flat.fontscale
end

-- Return a point anchored to a bound
-- bound: a bound2
-- anchor: combination of (l)eft, (r)ight, (t)op, (b)ottom, x (c)enter, y (m)iddle
-- Currently, repeating letters is ok; they'll be overwritten
function ui2.t (bound) return bound.max.y end
function ui2.b (bound) return bound.min.y end
function ui2.l (bound) return bound.min.x end
function ui2.r (bound) return bound.max.x end
function ui2.tl(bound) return vec2(bound.min.x,bound.max.y) end
function ui2.bl(bound) return bound.min end
function ui2.tr(bound) return bound.max end
function ui2.br(bound) return vec2(bound.max.x,bound.min.y) end
function ui2.anchor(bound, anchor)
	local v = vec2(bound.min)
	for i,ch in ichars(anchor) do
		    if ch == "l" then v.x = bound.min.x
     	elseif ch == "r" then v.x = bound.max.x
     	elseif ch == "c" then v.x = (bound.min.x+bound.max.x)/2
     	elseif ch == "t" then v.y = bound.max.y
     	elseif ch == "b" then v.y = bound.min.y
     	elseif ch == "m" then v.y = (bound.min.y+bound.max.y)/2
     	else error(string.format("Unrecognized character %s in anchor", ch))
     	end
	end
	return v
end
function ui2.anchorBools(anchor)
 	local r, b = false, false
 	for i,ch in ichars(anchor) do
 		    if ch == "l" then r = true
      	elseif ch == "r" then r = false
      	elseif ch == "c" then r = true
      	elseif ch == "t" then b = false
      	elseif ch == "b" then b = true
      	elseif ch == "m" then b = false
      	else error(string.format("Unrecognized character %s in anchor", ch))
      	end
 	end
 	return r,b
end

-- Not an ent-- feeds ents to other ents with set bounds
-- spec:
--     managed: array of ButtonEnts
--     swap: ent that can be safely swapped out when "screen" is done
--     parent: ent that laid out items should have as parent
-- members:
--     managedTo: How many managed items have been inserted?
--     placedTo: How many managed items have been laid out?
ui2.Layout = classNamed("Layout")
function ui2.Layout:_init(spec)
	pull(self, {managedTo = 0, placedTo=0})
	pull(self, spec)
  self.managed = self.managed or {}
end

function ui2.Layout:add(e) -- Call to manage another item
	table.insert(self.managed, e)
end

function ui2.Layout:manage(e) -- For internal use
	if self.pass and e.layoutPass then e:layoutPass(self.pass) end
	if self.parent then e:insert(self.parent) end
end

-- Esoteric -- Call this if for some reason insertion/loading needs to occur before layout
function ui2.Layout:prelayout()
	local mn = #self.managed -- Number of managed items
	for i = (self.managedTo+1),mn do
		self:manage(self.managed[i])
	end
	self.managedTo = mn
end


ui2.PileLayout = classNamed("PileLayout", ui2.Layout)

-- spec:
--     face: "x" or "y" -- default "x"
--     anchor: any combination of "tblr", default "lb"
-- members:
--     cursor: Next place to put a button
--     linemax (optional): greatest width of a button this line
function ui2.PileLayout:_init(spec)
	pull(self, {face="x"})
	self:super(spec)
	self.anchor = "lb" .. (self.anchor or "")
end

local margin = 0.05 -- Margin around text. Tunable 

-- Perform all layout at once. If true, re-lay-out things already laid out
function ui2.PileLayout:layout(relayout)
	-- Constants: Logic
	local moveright, moveup = ui2.anchorBools(self.anchor) -- Which direction are we moving?
	local mn = #self.managed -- Number of managed items
	local startAt = relayout and 1 or (self.placedTo+1) -- From what button do we begin laying out?

	-- Constants: Metrics
	local fh = fontHeight() -- Raw height of font
	local screenmargin = (fh + margin*2)/2 -- Space between edge of screen and buttons. Tunable
	local spacing = margin

	-- Logic constants
	local leftedge = -flat.xspan + screenmargin -- Start lines on left
	local rightedge = -leftedge        -- Wrap around on right
	local bottomedge = -flat.yspan + screenmargin -- Start render on bottom
	local topedge = -bottomedge
	local xface = self.face == "x"
	local axis = vec2(moveright and 1 or -1, moveup and 1 or -1) -- Only thing anchor impacts

	-- State
	local okoverflow = toboolean(self.cursor) -- Overflows should be ignored
	self.cursor = self.cursor or vec2(leftedge, bottomedge) -- Placement cursor (start at bottom left)

	for i = startAt,mn do -- Lay out everything not laid out
		local e = self.managed[i] -- Entity to place
		
		-- Item Metrics
		local buttonsize = e:sizeHint(margin)
		local w, h = buttonsize:unpack()
		local to = self.cursor + buttonsize -- Upper right of button

		-- Wrap
		local didoverflow = okoverflow and (
			(xface and to.x > rightedge) or (not xface and to.y > topedge)
		)
		if didoverflow then
			if xface then
				self.cursor = vec2(leftedge, to.y + spacing)
			else
				self.cursor = vec2(self.cursor.x + self.linemax + spacing, bottomedge)
				self.linemax = 0
			end
			to = self.cursor + buttonsize
		else
			okoverflow = true
		end

		local bound = bound2.at(self.cursor*axis, to*axis) -- Button bounds
		e.bound = bound
		if xface then
			self.cursor = vec2(self.cursor.x + w + spacing, self.cursor.y) -- Move cursor
		else
			self.cursor = vec2(self.cursor.x, self.cursor.y + h + spacing) -- Move cursor
			self.linemax = math.max(self.linemax or 0, buttonsize.x)
		end
		if e.onLayout then e:onLayout() end
		if i > self.managedTo then self:manage(e) end
	end
	self.managedTo = mn
	self.placedTo = mn
end


ui2.AlloCustomLayout = classNamed("AlloCustomLayout", ui2.Layout)

-- spec:
--     face: "x" or "y" -- default "x"
--     anchor: any combination of "tblr", default "lb"
-- members:
--     cursor: Next place to put a button
--     linemax (optional): greatest width of a button this line
function ui2.AlloCustomLayout:_init(spec)
	pull(self, {face="x"})
	self:super(spec)
	self.anchor = "lb" .. (self.anchor or "")
end

local margin = 0.05 -- Margin around text. Tunable 

-- Perform all layout at once. If true, re-lay-out things already laid out
function ui2.AlloCustomLayout:layout(relayout)
	-- Constants: Logic
	local moveright, moveup = ui2.anchorBools(self.anchor) -- Which direction are we moving?
	local mn = #self.managed -- Number of managed items
	local startAt = relayout and 1 or (self.placedTo+1) -- From what button do we begin laying out?

	-- Constants: Metrics
	local fh = fontHeight() -- Raw height of font
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


-- Mouse support
function ui2.routeMouse()
	-- taken care from main.lua instead
end

ui2.SwapEnt = classNamed("SwapEnt", OrderedEnt)

function ui2.SwapEnt:swap(ent)
	local parent = self.parent
	self:die()
	queueBirth(ent, parent)
end


ui2.ScreenEnt = classNamed("ScreenEnt", ui2.SwapEnt)

function ui2.ScreenEnt:onMirror() -- Screen might not draw anything but it needs to set up coords
	uiMode()
end

-- Buttons or layout items
-- spec:
--     swap: set by layout, sometimes unused, swap target if needed
--     bound: draw area
-- members:
--     down: is currently depressed (if a button)
-- must-implement methods:
--     sizeHint(margin) - return recommended size

ui2.UiBaseEnt = classNamed("UiBaseEnt", Ent)

function ui2.UiBaseEnt:layoutPass(pass) pull(self, pass) end

-- Items with text
-- spec:
--     label (required): text label

ui2.UiEnt = classNamed("UiEnt", ui2.UiBaseEnt)

function ui2.UiEnt:sizeHint(margin, overrideText)
	local label = overrideText or self.label
	if not label then error("Button without label") end -- TODO: This may be too restrictive

	local fh = fontHeight() -- Raw height of font
	local h = fh + margin*2 -- Height of a button
	local fw = flat.font:getWidth(label)*flat.fontscale -- Text width
	local w = fw + margin*2 -- Button width
	return vec2(w, h)
end

function ui2.UiEnt:onMirror()
	local center = self.bound:center()
	local size = self.bound:size()

	lovr.graphics.setColor(1,1,1,1)
	lovr.graphics.setFont(flat.font)
  lovr.graphics.print(self.label, center.x, center.y, 0, flat.fontscale)
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









ui2.ButtonEnt = classNamed("ButtonEnt", ui2.UiEnt) -- Expects in spec: bounds=, label=

function ui2.ButtonEnt:onPress(at)
	if self.bound:contains(at) then
		self.down = true
	end
end

function ui2.ButtonEnt:onRelease(at)
	if self.bound:contains(at) then
		self:onButton(at) -- FIXME: Is it weird this is an "on" but it does not route?
	end
	self.down = false
end

function ui2.ButtonEnt:onButton()
end

function ui2.ButtonEnt:onMirror()
	local center = self.bound:center()
	local size = self.bound:size()
	local gray = self.down and 0.5 or 0.8
	lovr.graphics.setColor(gray,gray,gray,0.8)
  lovr.graphics.plane('fill', center.x, center.y, 0, size.x, size.y)
  lovr.graphics.setColor(1,1,1,1)

	ui2.UiEnt.onMirror(self)
end

ui2.ToggleEnt = classNamed("ToggleEnt", ui2.ButtonEnt) -- ButtonEnt but stick down instead of hold

function ui2.ToggleEnt:onPress(at)
	if self.bound:contains(at) then
		self.down = not self.down
	end
end

function ui2.ToggleEnt:onRelease(at)
end

-- Ent which acts as a container for other objects
-- spec:
--     layout: a Layout object (required)
-- members:
--     lastCenter: tracks center over time so if the ent moves the offset is known
--     layoutCenter: tracks center at last sizeHint

ui2.LayoutEnt = classNamed("LayoutEnt", ui2.UiBaseEnt)

function ui2.LayoutEnt:_init(spec)
	pull(self, {lastCenter = vec2.zero})
	self:super(spec)
	self.layout = self.layout or
		ui2.PileLayout{anchor=self.anchor, face=self.face, managed=self.managed, parent=self}
		self.anchor = nil self.face = nil self.managed = nil
end

function ui2.LayoutEnt:sizeHint(margin, overrideText)
	self.layout:layout()
	local bound
	for i,v in ipairs(self.layout.managed) do
		bound = bound and bound:extendBound(v.bound) or v.bound
	end
	if not bound then error(string.format("LayoutEnt (%s) with no members", self)) end
	self.layoutCenter = bound:center()
	return bound:size()
end

function ui2.LayoutEnt:onLayout()
	local center = self.bound:center()
	local offset = center - self.lastCenter - self.layoutCenter
	for i,v in ipairs(self.layout.managed) do
		v.bound = v.bound:offset(offset)
	end
	self.lastCenter = center
end

function ui2.LayoutEnt:onLoad()
	if self.standalone then
		self.layout:layout() -- In case sizeHint wasn't called
	end
end

return ui2