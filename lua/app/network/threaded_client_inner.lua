lovr = require 'lovr'
lovr.filesystem, lovr.thread = require 'lovr.filesystem', require 'lovr.thread'

local util = require "util"
local json = require "json"
local allonet = util.load_allonet()
local client = allonet.create()

local inchannel = lovr.thread.getChannel("ThreadedClient-ToInner") -- todo: one unique per thread plz?
local outchannel = lovr.thread.getChannel("ThreadedClient-ToOuter") -- todo: one unique per thread plz?

client:set_state_callback(function(newstate)
  _send("state_callback", {newstate})
end)

client:set_interaction_callback(function(interaction)
  _send("interaction_callback", {interaction})
end)

client:set_disconnected_callback(function(reason)
  _send("disconnected_callback", {reason})
end)

client:set_audio_callback(function(track_id, audio)
  _send("audio_callback", {track_id, audio})
end)

local url, identity, avatar = unpack(json.decode(inchannel:pop(true)))
print("Connecting from thread to", url)
local connectionResult = client:connect(url, identity, avatar)
outchannel:push(connectionResult)

if connectionResult == false then
  print("Failed to connect, exiting thread")
  return
end

function _send(f, a)
  local cmd = {
    f=f,
    a=a
  }
  local jcmd = json.encode(cmd)
  outchannel:push(jcmd)
end

local running = true
while running do
  local jcmd = inchannel:pop(true)
  local cmd = json.decode(jcmd)
  local name = cmd["f"]
  local args = cmd["a"]
  client[name](client, unpack(args))

  if name == "disconnect" then
    running = false
  end
end

print("Local disconnect, exiting network thread")