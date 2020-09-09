namespace("menu", "alloverse")

local NetMenuScene = classNamed("NetMenuScene", Ent)
local settings = require("lib.lovr-settings")


function NetMenuScene:_init()
  settings.load()
  self:super()
end

function NetMenuScene:onLoad()
  local net = lovr.scenes.network("owner", "alloplace://localhost:21338")
  net.debug = false
  net:insert(self)
end


function NetMenuScene:openPlace(url)
  settings.d.last_place = url
  settings.save()

  local displayName = settings.d.username and settings.d.username or "Unnamed"
  local scene = lovr.scenes.network(displayName, url)
  scene.debug = settings.d.debug
  scene:insert()
  self:die()
end

return NetMenuScene