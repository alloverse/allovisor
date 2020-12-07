print("Booting async loader")
lovr = require 'lovr'
lovr.filesystem = require 'lovr.filesystem'
lovr.thread = require 'lovr.thread'
lovr.data = require 'lovr.data'

local outChan = lovr.thread.getChannel("AlloLoaderResponses")
local inChan = lovr.thread.getChannel("AlloLoaderRequests")

function load(type, path)
  if type == "model" then
    return pcall(lovr.data.newModelData, path)
  else
    return false, "no such loader"
  end
end

local running = true
while running do
  local type = inChan:pop(true)
  if type == "quit" then
    running = false
  else 
    local path = inChan:pop(true)
    local status, thing = load(type, path)
    outChan:push(path)
    outChan:push(status)
    outChan:push(thing)
  end
end
print("Exiting loader thread.")