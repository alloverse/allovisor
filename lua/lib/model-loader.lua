-- Request = {callback: Callback}
local ModelLoader = {
  requests = {}, -- {path: String -> req: Request}
}

local thread = lovr.thread.newThread("lib/model-loader-thread.lua")
thread:start()

local outChan = lovr.thread.getChannel("AlloLoaderRequests")
local inChan = lovr.thread.getChannel("AlloLoaderResponses")

-- Callback = callback(modelData: {ErrorString|ModelData}, status: bool) -> Void
-- ModelLoader:load(path: string, callback: Callback) -> Void
function ModelLoader:load(path, callback)
  local req = self.requests[path]
  if req then
    local oldCallback = req.callback
    req.callback = function(modelData, status)
      oldCallback(modelData, status)
      callback(modelData, status)
    end
    return
  end
  req = {callback= callback}
  self.requests[path] = req
  outChan:push(path)
end

function ModelLoader:poll()
  local path = inChan:pop()
  if path == nil then return end
  local status = inChan:pop(true)
  local modelDataOrError = inChan:pop(true)
  local req = self.requests[path]
  self.requests[path] = nil
  req.callback(modelDataOrError, status)
end

return ModelLoader
