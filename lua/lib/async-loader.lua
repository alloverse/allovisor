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
function AsyncLoader:load(type, path, callback, extra, extra2)
  local cached = self.cache[path]
  if cached then
    callback(cached, true)
    return
  end

  local req = self.requests[path]
  assert(not req, "This is allready loading. Cache earlier: " .. type .. " - " .. path)

  req = {callback= callback, type= type}
  self.requests[path] = req
  outChan:push(type)
  outChan:push(path)
  outChan:push(extra)
  outChan:push(extra2)
end

function AsyncLoader:poll()
  local path = inChan:pop()
  if path == nil then return end
  local status = inChan:pop(true)
  local dataOrError = inChan:pop(true)
  local req = self.requests[path]
  self.requests[path] = nil
  if status == true and req.type ~= "base64png" then
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
