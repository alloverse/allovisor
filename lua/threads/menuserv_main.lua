print("Booting menuserv")

lovr = require 'lovr'
lovr.filesystem, lovr.thread = require 'lovr.filesystem', require 'lovr.thread'
local util = require "lib.util"
local allonet = require("alloui.ffi_allonet_handle")

local server = allonet.alloserv_start_standalone("localhost", 0x0100007F, 0, "Menu")
assert(server)
local allosocket = allonet.allo_socket_for_select(server)
local port = server._port
assert(allosocket ~= -1)

print("Menuserv started on port", port)

local running = true
local chan = lovr.thread.getChannel("menuserv")
chan:push("booted", true)
chan:push(port, true)
while running do
  local ok = allonet.alloserv_poll_standalone(allosocket)
  assert(ok, "standalone server failed")
  local m = chan:pop()
  if m == "exit" then running = false end
end
print("menu server shutting down", allonet)
allonet.alloserv_stop_standalone()

