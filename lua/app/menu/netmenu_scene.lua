namespace("menu", "alloverse")

local NetMenuScene = classNamed("NetMenuScene", Ent)
local settings = require("lib.lovr-settings")



-- setup search path for writing alloapps.
local path, cpath = lovr.filesystem.getRequirePath()
path2 = path ..
	";alloui/lib/cpml/?.lua"
lovr.filesystem.setRequirePath(path2, cpath)

local Menu = require("app.menu.alloapps.menu")

-- set it back so we don't mess with rest of Visor
lovr.filesystem.setRequirePath(path, cpath)



function NetMenuScene:_init()
  settings.load()

  self.apps = {
    Menu:new{
      onQuit = function()
        settings.save()
        lovr.event.quit(0)
      end,
      onConnect = function(url)
        self:openPlace(url)
      end,
      onToggleDebug = function()
        settings.d.debug = not settings.d.debug
        settings.save()
        -- todo: update label
      end
    }
  }

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


function NetMenuScene:onUpdate()
  for _, app in ipairs(self.apps) do
    app:update()
  end
end

return NetMenuScene