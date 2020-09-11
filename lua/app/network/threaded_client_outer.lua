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
  self.state = {entities={}, revision=0}
  self.disconnected_callback = function() end
  self.interaction_callback = function() end
  self.state_callback = function() end
  self.audio_callback = function() end
end

function ThreadedClient:set_disconnected_callback(f)
  self.disconnected_callback = f
end
function ThreadedClient:set_interaction_callback(f)
  self.interaction_callback = f
end
function ThreadedClient:set_state_callback(f)
  self.state_callback = function(newstate)
    self.state = newstate
    f(newstate)
  end
end
function ThreadedClient:set_audio_callback(f)
  self.audio_callback = f
end

function ThreadedClient:connect(url, identity, avatar)
  self.outchannel:push(json.encode({url, identity, avatar}))
  self.thread:start()
  local ret = self.inchannel:pop(true)
  print("Threaded client connection result: ", ret)
  return ret
end

function ThreadedClient:disconnect(reason)
  self:_send("disconnect", {reason})
end

function ThreadedClient:send_interaction(interaction)
  self:_send("send_interaction", {interaction})
end

function ThreadedClient:set_intent(intent)
  self:_send("set_intent", {intent})
end

function ThreadedClient:get_state()
  return self.state
end

function ThreadedClient:send_audio(track_id, pcm)
  self:_send("send_audio", {track_id, pcm})
end

function ThreadedClient:simulate(dt)
  if self.lastSimulate then
    if self.outchannel:hasRead(self.lastSimulate) == false then
      return
    end
  end
  self.lastSimulate = self:_send("simulate", {dt})
end

function ThreadedClient:_send(f, a)
  local cmd = {
    f=f,
    a=a
  }
  local jcmd = json.encode(cmd)
  return self.outchannel:push(jcmd)
end

function ThreadedClient:poll(timeout)
  self:_handleIncoming()
  if self.lastPoll then
    if self.outchannel:hasRead(self.lastPoll) == false then
      return
    end
  end
  self.lastPoll = self:_send("poll", {timeout})
end

function ThreadedClient:_handleIncoming()
  local jcmd = self.inchannel:pop(false)
  while(jcmd) do
    cmd = json.decode(jcmd)
    local name = cmd["f"]
    local args = cmd["a"]
    self[name](unpack(args))
    jcmd = self.inchannel:pop(false)
  end
end

return ThreadedClient