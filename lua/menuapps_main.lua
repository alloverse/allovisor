lovr = require 'lovr'
lovr.filesystem, lovr.thread = require 'lovr.filesystem', require 'lovr.thread'
local json = require("json")
local util = require "util"
local allonet = util.load_allonet()
local running = true
local apps = {
   require("app.menu.alloapps.menu"):new{}
}

print("Booting allomenu apps")

while running do
  for _, app in ipairs(apps) do
    app:update()
  end
end

print("Allomenu apps ending")