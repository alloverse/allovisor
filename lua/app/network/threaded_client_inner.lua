lovr = require 'lovr'
lovr.filesystem, lovr.thread = require 'lovr.filesystem', require 'lovr.thread'

local util = require "util"
local json = require "json"
local allonet = util.load_allonet()
local client = allonet.create()

local inchannel = lovr.thread.getChannel("ThreadedClient-ToInner") -- todo: one unique per thread plz?
local outchannel = lovr.thread.getChannel("ThreadedClient-ToOuter") -- todo: one unique per thread plz?

local url, identity, avatar = unpack(json.decode(inchannel:pop(true)))
print("Connecting from thread to", url)
local connectionResult = client:connect(url, identity, avatar)
outchannel:push(connectionResult)

if connectionResult == false then
  "Failed to connect, exiting thread"
  return
end

