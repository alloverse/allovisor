namespace("networkscene", "alloverse")

local json = require "json"
local tablex = require "pl.tablex"
local pretty = require "pl.pretty"
local util = require "util"

class.ThreadedClient()

function ThreadedClient:_init()
  self.thread = lovr.thread.newThread("app/network/threaded_client_inner.lua")
  self.outchannel = lovr.thread.getChannel("ThreadedClient-ToInner") -- todo: one unique per thread plz?
  self.inchannel = lovr.thread.getChannel("ThreadedClient-ToOuter") -- todo: one unique per thread plz?
end


function ThreadedClient:set_disconnected_callback(f)
    
end
function ThreadedClient:set_interaction_callback(f)
    
end
function ThreadedClient:set_state_callback(f)
    
end
function ThreadedClient:set_audio_callback(f)
    
end

function ThreadedClient:connect(url, identity, avatar)
  self.outchannel:push(json.encode({url, identity, avatar}))
  self.thread:start()
  local ret = self.inchannel:pop(true)
  print("Threaded client connection result: ", ret)
  return ret
end

function ThreadedClient:poll()
  if self.lastPoll then
    if self.outchannel:hasRead(self.lastPoll) == false then
      print("skipping poll, waiting for previous to finish...")
      return
    end
  end
  self.lastPoll = self.outchannel:push("poll")
  -- todo: pop from inchannel
end


return ThreadedClient