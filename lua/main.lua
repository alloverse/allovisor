local path, cpath = lovr.filesystem.getRequirePath()
cpath = cpath .. 
	";?.so;?.dll;" ..
	lovr.filesystem.getSource() .. "/../build/deps/allonet/?.dylib;" ..
	lovr.filesystem.getSource() .. "/../../build/deps/allonet/?.dylib;"
if lovr.filesystem.getExecutablePath() then
	cpath = cpath .. lovr.filesystem.getExecutablePath():gsub("lovr.exe", "?.dll")
end
path = path ..
	";alloui/lua/?.lua"

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
	for _,v in ipairs{"bound2", "bound3", "color", "utils"} do
		space[v] = space.cpml[v]
	end
end

namespace.prepare("alloverse", "standard", function(space)
  require("app.network.network_scene") -- for lovr.scenes.network
end)

-- Ent driver
-- Route all the Lovr callbacks to the ent subsystem
namespace "standard"

function lovr.load()
	local menuServerThread = lovr.thread.newThread("menuserv_main.lua")
	menuServerThread:start()
	ent.root = LoaderEnt({
  "app.menu.main_menu_scene",
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

-- need a custom lovr.run to disable built-in lovr.audio.setPose
function lovr.run()
  lovr.timer.step()
  lovr.load()
  return function()
    lovr.event.pump()
    for name, a, b, c, d in lovr.event.poll() do
      if name == 'quit' and (not lovr.quit or not lovr.quit()) then
        return a or 0
      end
      if lovr.handlers[name] then lovr.handlers[name](a, b, c, d) end
    end
    local dt = lovr.timer.step()
    lovr.headset.update(dt)
    lovr.update(dt)

	if lovr.audio then
	    lovr.audio.setVelocity(lovr.headset.getVelocity())
		lovr.audio.update()
	end

    lovr.graphics.origin()
    lovr.headset.renderTo(lovr.draw)
    if lovr.graphics.hasWindow() then
      lovr.mirror()
    end
    lovr.graphics.present()
		lovr.math.drain()
  end
end