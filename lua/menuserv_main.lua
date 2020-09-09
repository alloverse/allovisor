lovr = require 'lovr'
lovr.filesystem, lovr.thread = require 'lovr.filesystem', require 'lovr.thread'

local util = require "util"
local allonet = util.load_allonet()
print("starting menu server", allonet, allonet.standalone_server_count())

if allonet.standalone_server_count() == 0 then
  local allosocket = allonet.start_standalone_server(21338)

  local running = true
  while running do
    print("poll")
    running = allonet.poll_standalone_server(allosocket)
  end
  print("menu server shutting down", allonet)
else
  print("menu server already running")
end