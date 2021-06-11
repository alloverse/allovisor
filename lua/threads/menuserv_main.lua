print("Booting menuserv")

lovr = require 'lovr'
lovr.filesystem, lovr.thread = require 'lovr.filesystem', require 'lovr.thread'
local util = require "lib.util"
local allonet = util.load_allonet()

allosocket, port = allonet.start_standalone_server(0x0100007F, 0, "Menu")
assert(allosocket ~= -1)
print("Menuserv started on port", port)

local running = true
local chan = lovr.thread.getChannel("menuserv")
chan:push("booted", true)
chan:push(port, true)
while running do
  local ok = allonet.poll_standalone_server(allosocket)
  assert(ok, "standalone server failed")
  local m = chan:pop()
  if m == "exit" then running = false end
end
print("menu server shutting down", allonet)
allonet.stop_standalone_server()

