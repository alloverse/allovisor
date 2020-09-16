print("Booting allomenu apps")

lovr = require 'lovr'
lovr.filesystem, lovr.thread = require 'lovr.filesystem', require 'lovr.thread'
local json = require("json")
local util = require "util"
local allonet = util.load_allonet()
local running = true
local chan = lovr.thread.getChannel("appserv")
local apps = {
   require("alloapps.mainmenu")()
}

print("allomenu apps started")
chan:push("booted", 2.0)
while running do
  for _, app in ipairs(apps) do
    app:update()
  end
  local m = chan:pop()
  if m == "exit" then running = false end
end

print("Allomenu apps ending")