lovr = require 'lovr'
lovr.filesystem, lovr.thread = require 'lovr.filesystem', require 'lovr.thread'

local util = require "util"
local allonet = util.load_allonet()
print("starting menu server", allonet, allonet.standalone_server_count())

if allonet.standalone_server_count() == 0 then
  local success = allonet.start_standalone_server(21338)
  if success == false then
    print("failed to start menu server.")
  else
    print("menu server shutting down", allonet)
  end
else
  print("menu server already running")
end