local json = require("alloui.json")

local settings = {}

settings.path = "settings.json"

function settings.load()
  local diskj = lovr.filesystem.read(settings.path, -1) 
  settings.d = diskj and json.decode(diskj) or {}
end

function settings.save()
  local diskj = json.encode(settings.d)
  local written = lovr.filesystem.write(settings.path, diskj)
end

return settings
