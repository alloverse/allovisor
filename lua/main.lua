local path = lovr.filesystem.getRequirePath()
local cpath = package.cpath
cpath = cpath .. 
	";?.so;?.dll;" ..
  lovr.filesystem.getSource() .. "/../deps/allonet/?.so;" ..
	lovr.filesystem.getSource() .. "/../build/deps/allonet/?.dylib;" ..
	lovr.filesystem.getSource() .. "/../../build/deps/allonet/?.dylib;"
if lovr.filesystem.getExecutablePath() and lovr.system.getOS() == "Windows" then
	cpath = cpath .. lovr.filesystem.getExecutablePath():gsub("lovr.exe", "?.dll")
end
path = path ..
  ";lib/alloui/lua/?.lua" ..
  ";lib/alloui/lib/cpml/?.lua" ..
  ";lib/ent/lua/?.lua" ..
  ";lib/ent/lua/?/init.lua" 
	

lovr.filesystem.setRequirePath(path)
package.cpath = cpath

-- load util and allonet into globals in all namespaces on the main thread
local util = require "lib.util"
allonet = nil
allonet = util.load_allonet()

local dragndrop = require("lib.lovr-dragndrop")
Store = require("lib.lovr-store")

namespace = require "engine.namespace"

local ok, mouse = pcall(require, "lib.lovr-mouse")
if not ok then
  print("No mouse available", mouse)
  mouse = nil
end

-- Load namespace basics
do
	-- This should be only used in helper threads. Make sure this matches thread/helper/boot.lua
	local space = namespace.space("minimal")

	-- PL classes missing? add here:
	for _,v in ipairs{"class", "pretty", "stringx", "tablex"} do
		space[v] = require("pl." .. v)
	end
	space.ugly = require "engine.ugly"

	require "engine.types"
end
do
	local space = namespace.space("standard", "minimal")

	space.cpml = require "cpml"
	for _,v in ipairs{"bound2", "bound3", "vec2", "vec3", "quat", "mat4", "color", "utils"} do
		space[v] = space.cpml[v]
	end
	require "engine.loc"

	require "engine.ent"
	space.ent.singleThread = singleThread
	require "engine.common_ent"
	require "engine.lovr"
  require "engine.mode"
  require "lib.util"
end

namespace.prepare("alloverse", "standard", function(space)
end)

-- Ent driver
-- Route all the Lovr callbacks to the ent subsystem
namespace "standard"
local flat = require "engine.flat"
local loader = require "lib.async-loader"
local json = require "alloui.json"

local loadCo = nil
local urlToHandle = nil
local restoreData = nil
function lovr.load(args)
  print("lovr.load(", pretty.write(args), ")")
  lovr.system.requestPermission('audiocapture')
  if args.restart then
    restoreData = json.decode(args.restart)
    urlToHandle = restoreData.url
  end
  lovr.handlers["handleurl"] = function(url)
    if ent.root then
      print("Opening URL:", url)
      ent.root:route("onHandleUrl", url)
    else
      print("Storing URL to open when UI is available:", url)
      urlToHandle = url
    end
  end
  loadCo = coroutine.create(_asyncLoad)
end
function _asyncLoad()
  function check(threadname)
    local deadline = lovr.timer.getTime() + 5
    local chan = lovr.thread.getChannel(threadname)
    while lovr.timer.getTime() < deadline do
      local m = chan:peek()
      if m == "booted" then
        chan:pop()
        return chan
      end
      coroutine.yield()
    end
    error(threadname.." didn't start in time")
  end
  storeThread = lovr.thread.newThread("lib/lovr-store-thread.lua")
  storeThread:start()
  
	menuServerThread = lovr.thread.newThread("threads/menuserv_main.lua")
  menuServerThread:start()
  menuServerPort = check("menuserv"):pop(true)
  menuAppsThread = lovr.thread.newThread("threads/menuapps_main.lua")
  lovr.thread.getChannel("appserv"):push(menuServerPort)
  lovr.thread.getChannel("appserv"):push(lovr.headset and lovr.headset.getName() or "desktop")
  print("starting appserv...")
  menuAppsThread:start()
  check("appserv")
  return "done"
end
function _asyncLoadResume()
  local costatus, err = coroutine.resume(loadCo)
  if err ~= "done" then
    if costatus == false then
      print("Booting failed with error", err)
      error(err)
    end
    return
  end
  print("Pre-boot completed, launching UI")
  
  -- great, all the threads are started. Let's create some UI.
  -- (We can't do this in the above coroutine because allonet stores
  --  the coroutine you call set_*_callback on :S)
  loadCo = nil
	ent.root = require("scenes.scenemanager")(menuServerPort)
	ent.root:route("onBoot") -- This will only be sent once
  ent.root:insert()
  
  lovr.handlers["keypressed"] = function(code, scancode, repetition)
    ent.root:route("onKeyPress", code, scancode, repetition)
  end
  lovr.handlers["keyreleased"] = function(code, scancode)
    ent.root:route("onKeyReleased", code, scancode)
  end
  lovr.handlers["textinput"] = function(text, code)
    ent.root:route("onTextInput", text, code)
  end
  lovr.handlers["mousemoved"] = function(x, y, dx, dy)
    ent.root:route("onMouseMoved", x, y, dx, dy)
  end
  lovr.handlers["mousepressed"] = function(x, y, button)
    ent.root:route("onMousePressed", x, y, button)
    local inx =     x * flat.width  / flat.pixwidth  - flat.width/2    -- Convert pixel x,y to our coordinate system
		local iny = - ( y * flat.height / flat.pixheight - flat.height/2 ) -- GLFW has flipped y-coord
    ent.root:route("onPress", lovr.math.vec2(inx, iny)) -- ui2 compat
  end
  lovr.handlers["mousereleased"] = function(x, y, button)
    ent.root:route("onMouseReleased", x, y, button)
    local inx =     x * flat.width  / flat.pixwidth  - flat.width/2    -- Convert pixel x,y to our coordinate system
		local iny = - ( y * flat.height / flat.pixheight - flat.height/2 ) -- GLFW has flipped y-coord
    ent.root:route("onRelease", lovr.math.vec2(inx, iny)) -- ui2 compat
  end

  lovr.handlers["filedrop"] = function(path)
    ent.root:route("onFileDrop", path)
  end


  local cursors = {}
  local currentCursorName = "arrow"
  if mouse then
    for _, name in ipairs({"arrow", "hand", "crosshair"}) do
      cursors[name] = mouse.getSystemCursor(name)
    end

    lovr.mouse = {
      position = lovr.math.newVec2(-1, -1),
      buttons = { false, false },
      setRelativeMode = function(enable)
        if mouse then mouse.setRelativeMode(enable) end
      end,
      setCursor = function(newCursorName)
        if mouse and newCursorName ~= currentCursorName then 
          mouse.setCursor(cursors[newCursorName]) 
          currentCursorName = newCursorName
        end
      end,
      setHidden = function(hidden)
        mouse.setHidden(hidden)
      end
    }
  end

  if lovr.audio then
    local capDevs = lovr.audio.getDevices("capture")
    local defaultCandidate = nil
    for k, v in ipairs(capDevs) do 
      v.id = nil 
      if v.default or string.find(v.name, "default") or string.find(v.name, "Default") or defaultCandidate == nil then
        defaultCandidate = v.name
      end
    end
    print("Available microphone/capture audio devices:", pretty.write(capDevs))
    Store.singleton():save("availableCaptureDevices", capDevs)
    if Store.singleton():load("currentMic") == nil and defaultCandidate then
      print("Setting default mic candidate", defaultCandidate)
      Store.singleton():save("currentMic", {name= defaultCandidate, status="pending"}, true)
    end
  end
end

function lovr.onNetConnected(net, url, place_name)
  if place_name == "Menu" then
    if urlToHandle then
      print("Opening stored URL:", urlToHandle)
      ent.root:route("onHandleUrl", urlToHandle)
      urlToHandle = nil
    end
  else
    if restoreData then
      lovr.scenes.net.engines.pose.poseToRestore = restoreData.rootPose
      lovr.scenes.net.engines.pose.yaw = restoreData.yaw
      restoreData = nil
    end
  end
end

function lovr.restart()
  local restoreData = {}
  if lovr.scenes.net then
    restoreData.url = lovr.scenes.net.url
    restoreData.rootPose = {lovr.scenes.net:getAvatar().components.transform:getMatrix():unpack(true)}
    restoreData.yaw = lovr.scenes.net.engines.pose.yaw
  end
  local urlToRestore = lovr.scenes.net and lovr.scenes.net.url
  print("Restarting; disconnecting (restoring to", urlToRestore, ")...")
  optchainm(lovr.scenes, "net.onDisconnect", 1000, "Disconnected from lovr.restart")
  print("Shutting down threads...")
  lovr.thread.getChannel("menuserv"):push("exit")
  lovr.thread.getChannel("appserv"):push("exit")
  menuServerThread:wait()
  menuAppsThread:wait()
  Store.singleton():shutdown()

  loader:shutdown()
  print("Done, restarting.")
  if restoreData.url then
    return json.encode(restoreData)
  else
    return nil
  end
end

function _updateMouse()
  if mouse == nil then return end

  local px, py = lovr.mouse.position:unpack()
  local x, y = mouse.getPosition()
  lovr.mouse.position:set(x, y)
  local oldButtons = tablex.copy(lovr.mouse.buttons)
  lovr.mouse.buttons = {mouse.isDown(1), mouse.isDown(2)}
  
  if px ~= x or py ~= y then
    lovr.event.push('mousemoved', x, y, x - px, y - py, false)
  end
  for i, pb in ipairs(oldButtons) do
    local b = lovr.mouse.buttons[i]
    if b and not pb then
      lovr.event.push("mousepressed", x, y, i)
    elseif not b and pb then
      lovr.event.push("mousereleased", x, y, i)
    end
  end
end

function lovr.update(dt)
  if loadCo then
    _asyncLoadResume()
  end
  Store.singleton():poll()
  if lovr.mouse then
    _updateMouse()
  end
  loader:poll()
  if ent.root then
    ent.root:route("onUpdate", dt)
    entity_cleanup()
  end

  calculateFramerateBasedOnActivity()
end

function lovr.draw(isMirror)
  lovr.graphics.origin()
  drawMode()
  if ent.root then
    ent.root:route("onDraw", isMirror)
  end
end

local skippedFrames = 0
local frameSkip = 0
function lovr.mirror()
  drawMode()
  lovr.graphics.reset()
  lovr.graphics.origin()
  local pixwidth = lovr.graphics.getWidth()   -- Window pixel width and height
  local pixheight = lovr.graphics.getHeight()
  local aspect = pixwidth/pixheight
  local proj = lovr.math.mat4():perspective(0.01, 100, 67*(3.14/180), aspect)
  lovr.graphics.setProjection(1, proj)
  lovr.graphics.setShader(nil)
  lovr.graphics.setColor(1,1,1,1)
  lovr.graphics.clear()
  lovr.draw(true)

  if ent.root then
    ent.root:route("onMirror")
  end
end

local wasActive = false
function calculateFramerateBasedOnActivity()
  local isActive = lovr.isFocused
  if lovr.headset then
    isActive = isActive or lovr.headset.isTracked()
  end
  if wasActive ~= isActive then
    wasActive = isActive
    if util.isDesktop() then
      -- glfwSwapInterval broken
      frameSkip = isActive and 0 or 25
    end
  end
end

lovr.isFocused = true
function lovr.focus(focused)
  lovr.isFocused = focused
  if ent.root then
    ent.root:route("onFocus", focused)
  end
end

local permissionsHaveRetried = false
function lovr.permission(permission, granted)
  print("Permission ", permission, "response", granted)
  if permission == "audiocapture" and granted and lovr.scenes and lovr.scenes.net and not permissionsHaveRetried then
    permissionsHaveRetried = true
    print("Mic permissions have been granted, reopening mic.")
    lovr.scenes.net.engines.sound:retryMic()
  end
end


local lastFrameTime = 0.0
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
      end
      if lovr.handlers[name] then lovr.handlers[name](a, b, c, d) end
    end
    local dt = lovr.timer.step()
    local beforeWork = lovr.timer.getTime()
    if lovr.headset then
      lovr.headset.update(dt)
    end
    if lovr.update then lovr.update(dt) end
    if lovr.graphics then
      lovr.graphics.origin()
      if lovr.draw then
        skippedFrames = skippedFrames + 1
        if skippedFrames > frameSkip then
          skippedFrames = 0
          if lovr.headset and lovr.headset.isTracked() then
            lovr.headset.renderTo(lovr.draw)
          end
          if lovr.graphics.hasWindow() then
            lovr.mirror()
          end
          lovr.graphics.present()
        end
      end
    end

    -- XXX HACK vsync doesn't work on mac, so cap framerate
    local afterWork = lovr.timer.getTime()
    local deltaFramLastFrame = beforeWork-lastFrameTime
    local maxFramerate = 60.0
    local sleepAmount = 1.0/maxFramerate - deltaFramLastFrame
    if lovr.system.getOS() == "macOS" and sleepAmount > 0 then
      lovr.timer.sleep(sleepAmount)
    end
    lastFrameTime = beforeWork

    if lovr.math then
      lovr.math.drain()
    end
  end
end
