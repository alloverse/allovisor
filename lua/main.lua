local path, cpath = lovr.filesystem.getRequirePath()
cpath = cpath .. 
	";?.so;?.dll;" ..
	lovr.filesystem.getSource() .. "/../build/deps/allonet/?.dylib;" ..
	lovr.filesystem.getSource() .. "/../../build/deps/allonet/?.dylib;"
if lovr.filesystem.getExecutablePath() then
	cpath = cpath .. lovr.filesystem.getExecutablePath():gsub("lovr.exe", "?.dll")
end

lovr.filesystem.setRequirePath(path, cpath)
package.cpath = cpath

lovr.scenes = {}

namespace = require "engine.namespace"

-- Load namespace basics
do
	local space = namespace.space("standard")

	-- PL classes missing? add here:
	for _,v in ipairs{"class", "pretty", "stringx", "tablex"} do
		space[v] = require("pl." .. v)
	end

	require "engine.types"
	require "engine.ent"
	require "engine.common_ent"
	require "engine.lovr"
	require "engine.mode"

	space.cpml = require "cpml" -- CPML classes missing? Add here:
	for _,v in ipairs{"bound2", "bound3", "vec2", "vec3", "quat", "mat4", "color", "utils"} do
		space[v] = space.cpml[v]
	end
end

namespace.prepare("alloverse", "standard", function(space)
	require("app.menu.menu")
	require("app.network.network")
end)

-- Ent driver
-- Route all the Lovr callbacks to the ent subsystem
namespace "standard"

function lovr.load()
	ent.root = LoaderEnt({
		"app/menu/menu",
		"app/debug/fps"
	})
	ent.root:route("onBoot") -- This will only be sent once
	ent.root:insert()
end

function lovr.update(dt)
	ent.root:route("onUpdate", dt)
	entity_cleanup()
end

function lovr.draw()
	drawMode()
	ent.root:route("onDraw")
end

local mirror = lovr.mirror
function lovr.mirror()
	mirror()
	ent.root:route("onMirror")
end
