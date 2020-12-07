-- Request = {callback: Callback}
local AsyncLoader = {
  requests = {}, -- {path: String -> req: Request}
  cache = {} -- {path: String -> data: ModelData}
}

local thread = lovr.thread.newThread("lib/async-loader-thread.lua")
thread:start()

local outChan = lovr.thread.getChannel("AlloLoaderRequests")
local inChan = lovr.thread.getChannel("AlloLoaderResponses")

-- Type = <"model"> (only model loading supported atm)
-- Callback = callback(data: {ErrorString|data}, status: bool) -> Void
-- AsyncLoader:load(type: Type, path: string, callback: Callback) -> Void
function AsyncLoader:load(type, path, callback)
  local cached = self.cache[path]
  if cached then
    callback(cached, true)
    return
  end

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
  outChan:push(type)
  outChan:push(path)
end

function AsyncLoader:poll()
  local path = inChan:pop()
  if path == nil then return end
  local status = inChan:pop(true)
  local dataOrError = inChan:pop(true)
  local req = self.requests[path]
  self.requests[path] = nil
  if status == true then
    self.cache[path] = dataOrError
  end
  req.callback(dataOrError, status)
end

function AsyncLoader:shutdown()
  print("Shutting down loader...")
  outChan:push("quit")
  thread:wait()
end

return AsyncLoader
