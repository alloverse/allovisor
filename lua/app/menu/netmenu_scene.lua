namespace("menu", "alloverse")

local NetMenuScene = classNamed("NetMenuScene", Ent)

function NetMenuScene:_init()


  self:super()
end

function NetMenuScene:onLoad()
  local net = lovr.scenes.network("menu", "alloplace://localhost:21338")
  net.debug = false
  net:insert(self)
end

return NetMenuScene