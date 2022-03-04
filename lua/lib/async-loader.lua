-- Request = {callback: Callback}
local AsyncLoader = {
  requests = {}, -- {path: String -> req: Request}
}

local thread = lovr.thread.newThread("lib/async-loader-thread.lua")
thread:start()

local outChan = lovr.thread.getChannel("AlloLoaderRequests")
local inChan = lovr.thread.getChannel("AlloLoaderResponses")

-- Type = <"model"> (only model loading supported atm)
-- Callback = callback(data: {ErrorString|data}, status: bool) -> Void
-- AsyncLoader:load(type: Type, path: string, callback: Callback) -> Void
function AsyncLoader:load(type, path, callback, extra, extra2)
  local key = type .. "-" .. path
  local req = self.requests[key]
  if req then 
    table.insert(req.callbacks, callback)
    return
  end
  self.requests[key] = {callbacks = {callback}, type = type}
  outChan:push(type)
  outChan:push(path)
  outChan:push(extra)
  outChan:push(extra2)
end

function AsyncLoader:poll()
  local type = inChan:pop()
  local path = inChan:pop()
  if path == nil then return end
  local status = inChan:pop(true)
  local dataOrError = inChan:pop(true)
  local key = type .. "-" .. path
  local req = self.requests[key]
  self.requests[key] = nil
  for i,callback in ipairs(req.callbacks) do
    callback(dataOrError, status)
  end
end

function AsyncLoader:shutdown()
  print("Shutting down loader...")
  outChan:push("quit")
  thread:wait()
end

return AsyncLoader
