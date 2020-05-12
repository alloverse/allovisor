lovr = require 'lovr'
lovr.filesystem, lovr.thread = require 'lovr.filesystem', require 'lovr.thread'

local util = require "util"
local allonet = util.load_allonet()
print("starting menu server", allonet)

local success = allonet.start_standalone_server(21338)
if success == false then
  print("failed to start menu server.")
else
  print("menu server shutting down", allonet)
end