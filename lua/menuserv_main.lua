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
  print("yielding to existing menu server at", allosocket)
  return
end

local running = true
while running do
  running = allonet.poll_standalone_server(allosocket)
end
print("menu server shutting down", allonet)

