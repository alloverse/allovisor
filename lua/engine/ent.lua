--- Run Hello autonomous entity lib, adapted for Lovr
-- Assumes pl "class" in namespace
-- IMPORTS ALL ON REQUIRE
-- @classmod Ent

namespace "standard"
require "engine.types"

-- Entity state

--- State used by ent class.
ent = {
	inputLevel = 1 -- ??
}

--- A special value, return from an event and your children will not be called
route_terminate = {}

--- List of entities marked for removal
local doomed = {}

--- Cleans up doomed entities. **User code should not call this.**
-- Called be the system once at the end of each update. 
function entity_cleanup()
	if tableTrue(doomed) then
		for i,v in ipairs(doomed) do
			if type(v) ~= "function" then
				v:bury()
			else
				v()
			end
		end
		doomed = {}
	end
end

--- Call this with a function and it will be run at the end of the next update, when dead entities are buried.
-- @tparam function f Function to be called at and of next update
function queueDoom(f)
	table.insert(doomed, f)
end

--- Call this with an object and a parent and it will be inserted at the end of the next update, when dead entities are buried.
-- @tparam Ent e Entity to queue
-- @tparam Ent parent The entity to become the parent of e
function queueBirth(e, parent)
	table.insert(doomed, function()
		e:insert(parent)
	end)
end

-- Ents

--- Used as seed for generating entity identifiers
local ent_id_generator = 1

class.Ent()

--- Initialize a new Ent
-- @tparam table spec An entity specification
function Ent:_init(spec)
	pull(self, {id=ent_id_generator,kids={}})
	pull(self, spec)
	ent_id_generator = ent_id_generator + 1
end

--- Call with a function name and an argument and it will be called first on this object, then all its children
-- @tparam string key Function name
-- @param ... arguments to pass to the function
function Ent:route(key, ...)
	local result
	if self[key] then
		result = self[key](self, ...)
	end
	if result ~= route_terminate and self.kids then
		for k,v in pairs(self.kids) do
			v:route(key, ...)
		end
	end
	local postKey = "after_"..key
	if self[postKey] then
		self[postKey](self, ...)
	end
end

--- Insert self as a child to `parent`.
-- An error is thrown if self already has a parent.
-- @tparam Ent parent The entity to attach self to
-- @return self
function Ent:insert(parent)
	if self.parent then error("Reparenting not currently supported") end
	if not parent and self ~= ent.root then -- Default to ent.root
		if ent.strictInsert then error("insert() with no parent") end -- Set this flag for no default
		if not ent.root then error("Tried to insert to the root entity, but there isn't one") end
		parent = ent.root
	end
	self.parent = parent
	if parent then
		parent:register(self)
	end
	-- There's an annoying special case to get onLoad to fire the very first boot.
	-- FIXME: Figure out a better way of detecting roothood?
	if not self.loaded and ((parent and parent.loaded) or self == ent.root) then
		self:route("onLoad")
		self:route("_setLoad")
	end
	return self
end

--- Used to set self.loaded and self.dead properly. **User code should not call these.**
function Ent:_setLoad() self.loaded = true end
--- Used to set self.loaded and self.dead properly. **User code should not call these.**
function Ent:_setDead() self.dead = true end

--- Mark self for removal
-- `self.dead` will be set and then self be deleted at the end of the next frame.
function Ent:die()
	if self.dead then return end -- Don't die twice
	self:route("onDie")
	self:route("_setDead")
	
	table.insert(doomed, self)
end

--- Called when a new child entity is being added to self.
-- User code can overload this, but probably should not call it.
-- @tparam Ent child The child that is being added
function Ent:register(child)
	self.kids[child.id] = child
end

--- Called when a child is being removed
-- User code can overload this, but probably should not call it.
-- @tparam Ent child The child that is being removed
function Ent:unregister(child)
	self.kids[child.id] = nil
end

-- It is the end of the frame. This object was die()d and it's time to delete it. **User code can overload this, but probably should not call it.**
--- Called at the end of the frame if self is marked for removal (through `die()`)
-- @see die()
function Ent:bury()
	if self.parent then
		self.parent:unregister(self)
	end
	self:route("onBury")
end

-- For this class, are routed in the order they are added, but unegistration is inefficent
class.OrderedEnt(Ent)
function OrderedEnt:_init(spec)
	pull(self, {kidOrder={}})
	self:super(spec)
end

function OrderedEnt:register(child)
	table.insert(self.kidOrder, child.id)
	Ent.register(self, child)
end

function OrderedEnt:unregister(child) -- TODO: Remove maybe?
	local kidOrder = {}
	for i,v in ipairs(self.kidOrder) do
		if v ~= child.id then
			table.insert(kidOrder, v)
		end
	end
	self.kidOrder = kidOrder
	Ent.unregister(self, child)
end

function OrderedEnt:route(key, ...) -- TODO: Repetitive with Ent:route()?
	local result
	if self[key] then
		result = self[key](self, ...)
	end
	if result ~= route_terminate then
		for _,id in ipairs(self.kidOrder) do
			local v = self.kids[id]
			if v then v:route(key, ...) end
		end
	end
	local postKey = "after_"..key
	if self[postKey] then
		self[postKey](self, ...)
	end
end

-- This class remembers the inputLevel at the moment it was constructed
class.InputEnt(Ent)
function InputEnt:_init(spec)
	pull(self, {inputLevel = ent.inputLevel})
	self:super(spec)
end
