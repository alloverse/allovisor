local path, cpath = lovr.filesystem.getRequirePath()
cpath = cpath .. 
	";?.so;?.dll;" ..
	lovr.filesystem.getSource() .. "/../build/deps/allonet/?.dylib;" ..
	lovr.filesystem.getSource() .. "/../../build/deps/allonet/?.dylib;"
if lovr.filesystem.getExecutablePath() and lovr.getOS() == "Windows" then
	cpath = cpath .. lovr.filesystem.getExecutablePath():gsub("lovr.exe", "?.dll")
end
path = path ..
	";alloui/lua/?.lua;" ..
	";alloui/lib/cpml/?.lua"

lovr.filesystem.setRequirePath(path, cpath)
package.cpath = cpath

lovr.filesystem.setIdentity("alloverse")

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
  print("lovr.load()")
	menuServerThread = lovr.thread.newThread("menuserv_main.lua")
  menuServerThread:start()
  _checkthread(menuServerThread, "menuserv")
	menuAppsThread = lovr.thread.newThread("menuapps_main.lua")
  menuAppsThread:start()
  _checkthread(menuAppsThread, "appserv")

	ent.root = LoaderEnt({
    "app.menu.netmenu_scene",
--    "app.menu.main_menu_scene",
    "app/debug/fps"
	})

	ent.root:route("onBoot") -- This will only be sent once
	ent.root:insert()
end

function _checkthread(thread, channelName)
  local deadline = lovr.timer.getTime() + 2
  local chan = lovr.thread.getChannel(channelName)
  while lovr.timer.getTime() < deadline do
    local m = chan:pop(0.1)
    if m == "booted" then
      return true
    end
    -- todo: instead, wait for these threads to respond async and then start LoaderEnt
    lovr.event.pump()
    for name, a, b, c, d in lovr.event.poll() do
      if name == "threaderror" then
        lovr.threaderror(a, b)
      end -- arrgh discarding events
    end
  end
  assert(channelName.." didn't start in time")
end

function lovr.restart()
  print("Shutting down threads...")
  lovr.thread.getChannel("menuserv"):push("exit", true)
  lovr.thread.getChannel("appserv"):push("exit", true)
  -- wait() crashes on windows. and anyways if "exit" is pop()d, we know thread is done
  -- menuServerThread:wait()
  -- menuAppsThread:wait()
  print("Done, restarting.")
  return true
end


function lovr.update(dt)
	ent.root:route("onUpdate", dt)
	entity_cleanup()
end

function lovr.draw(isMirror)
  if (lovr.headset == nil or lovr.headset.getDriver() == "desktop" ) and isMirror == false then
    return
  end
	drawMode()
	ent.root:route("onDraw")
end


function lovr.mirror()
  lovr.graphics.reset()
  lovr.graphics.origin()
  local pixwidth = lovr.graphics.getWidth()   -- Window pixel width and height
  local pixheight = lovr.graphics.getHeight()
  local aspect = pixwidth/pixheight
  local proj = lovr.math.mat4():perspective(0.01, 100, 67*(3.14/180), aspect)
  lovr.graphics.setProjection(proj)
	ent.root:route("onMirror")
end

function lovr.focus(focused)
  ent.root:route("onFocus", focused)
end


-- need a custom lovr.run to disable built-in lovr.audio.setPose
function lovr.run()
  lovr.timer.step()
  if lovr.load then lovr.load(arg) end
  return function()
    lovr.event.pump()
    for name, a, b, c, d in lovr.event.poll() do
      if name == 'restart' then
        local cookie = lovr.restart and lovr.restart()
        return 'restart', cookie
      elseif name == 'quit' and (not lovr.quit or not lovr.quit(a)) then
        return a or 0
      elseif name == 'threaderror' and lovr.threaderror then
        print("THREAD ERROR!!!")
        lovr.threaderror(a, b)
      end
      if lovr.handlers[name] then lovr.handlers[name](a, b, c, d) end
    end
    local dt = lovr.timer.step()
    if lovr.headset then
      lovr.headset.update(dt)
    end
    if lovr.audio then
      lovr.audio.update()
      if lovr.headset then
        lovr.audio.setVelocity(lovr.headset.getVelocity())
      end
    end
    if lovr.update then lovr.update(dt) end
    if lovr.graphics then
      lovr.graphics.origin()
      if lovr.draw then
        if lovr.headset then
          lovr.headset.renderTo(lovr.draw)
        end
        if lovr.graphics.hasWindow() then
          lovr.mirror()
        end
      end
      lovr.graphics.present()
    end
    if lovr.math then
      lovr.math.drain()
    end
  end
end