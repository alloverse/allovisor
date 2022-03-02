print("Booting async loader")
lovr = require 'lovr'
lovr.filesystem = require 'lovr.filesystem'
lovr.thread = require 'lovr.thread'
lovr.data = require 'lovr.data'

local util = require("lib.util")

local outChan = lovr.thread.getChannel("AlloLoaderResponses")
local inChan = lovr.thread.getChannel("AlloLoaderRequests")

function load(type, path, extra, extra2)
  if type == "model" then
    -- expects a lovr blob in extra
    return pcall(lovr.data.newModelData, extra)
  elseif type == "texture" or type == "image" then
    -- expects a lovr blob in extra
    -- expects a boolean 'flip' in extra2
    return pcall(lovr.data.newImage, extra, not extra2)
  elseif type == "sound" then
    -- expects a lovr blob in extra
    return pcall(lovr.data.newSound, extra)
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
    local extra = inChan:pop(true)
    local extra2 = inChan:pop(true)
    local status, thing = load(type, path, extra, extra2)
    outChan:push(type)
    outChan:push(path)
    outChan:push(status)
    outChan:push(thing)
  end
end
print("Exiting loader thread.")
