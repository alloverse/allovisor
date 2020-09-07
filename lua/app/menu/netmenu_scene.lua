namespace("menu", "alloverse")

local NetMenuScene = classNamed("NetMenuScene", Ent)

-- setup search path for writing alloapps.
local path, cpath = lovr.filesystem.getRequirePath()
path2 = path ..
	";alloui/lib/cpml/?.lua"
lovr.filesystem.setRequirePath(path2, cpath)

local Menu = require("app.menu.alloapps.menu")

-- set it back so we don't mess with rest of Visor
lovr.filesystem.setRequirePath(path, cpath)

function NetMenuScene:_init()
  
  self.apps = {
    Menu:new{
      onQuit = function()
        print("oh yeah we're quitting")
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

function NetMenuScene:onUpdate()
  for _, app in ipairs(self.apps) do
    app:update()
  end
end

return NetMenuScene