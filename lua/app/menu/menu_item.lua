namespace("menu", "alloverse")

local MenuItem = classNamed("MenuItem")
function MenuItem:_init(label, action)
  self.label = label
  self.action = action
  self.isHighlighted = false
  self.isSelected = false
end

function MenuItem:createCollider(world, index)
  self.index = index
  local menuItemY = y-((MENU_ITEM_HEIGHT+MENU_ITEM_VERTICAL_PADDING)*index)
  self.collider = world:newBoxCollider(x, menuItemY, z, MENU_ITEM_WIDTH, MENU_ITEM_HEIGHT, 0.1 )
  self.collider:setUserData(self)
end

return MenuItem