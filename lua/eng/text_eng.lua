namespace("networkscene", "alloverse")

local json = require "json"
local tablex = require "pl.tablex"

local TextEng = classNamed("TextEng", Ent)
function TextEng:_init()
  self:super()
end

function TextEng:onLoad()
  self.font = lovr.graphics.newFont(32)
end

function TextEng:onDraw() 
  lovr.graphics.setShader()
  self.font:setPixelDensity(32)
  lovr.graphics.setFont(self.font)
  for eid, entity in pairs(self.client.state.entities) do
    local text = entity.components.text
    if text ~= nil then
      local mat = self.parent.engines.graphics.materials_for_eids[eid]
      if mat then
        lovr.graphics.setColor(mat:getColor())
      else
        lovr.graphics.setColor(1,1,1,1)
      end
      lovr.graphics.push()
      lovr.graphics.transform(entity.components.transform:getMatrix())
      lovr.graphics.print(
        text.string,
        0, 0, 0.01,
        text.height and text.height or 1.0, 
        0, 0, 0, 0,
        text.wrap and text.wrap / (text.height and text.height or 1) or 0,
        text.halign and text.halign or "center"
      )
      lovr.graphics.pop()
    end
  end
end

return TextEng