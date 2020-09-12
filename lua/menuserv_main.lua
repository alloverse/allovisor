lovr = require 'lovr'
lovr.filesystem, lovr.thread = require 'lovr.filesystem', require 'lovr.thread'
local json = require("json")
local util = require "util"
local allonet = util.load_allonet()
local allosocket = allonet.last_allosocket()

if allosocket == -1 then
  print("starting menu server")
  allosocket = allonet.start_standalone_server(21338)
else
  assert(false, "menu serv already exists, which is bad")
  return
end

local running = true
local chan = lovr.thread.getChannel("menuserv")
while running do
  local ok = allonet.poll_standalone_server(allosocket)
  assert(ok, "standalone server failed")
  local m = chan:pop()
  if m == "exit" then running = false end
end
print("menu server shutting down", allonet)

