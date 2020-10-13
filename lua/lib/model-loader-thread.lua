print("Booting model loader")
lovr = require 'lovr'
lovr.filesystem = require 'lovr.filesystem'
lovr.thread = require 'lovr.thread'
lovr.data = require 'lovr.data'

local outChan = lovr.thread.getChannel("AlloLoaderResponses")
local inChan = lovr.thread.getChannel("AlloLoaderRequests")

while true do
  local path = inChan:pop(true)
  local status, model = pcall(lovr.data.newModelData, path)
  outChan:push(path)
  outChan:push(status)
  outChan:push(model)
end