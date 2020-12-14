local Client = require("alloui.client")
local ui = require("alloui.ui")
local pretty = require("pl.pretty")
local tablex = require("pl.tablex")
local class = require("pl.class")

class.MenuView(ui.View)
function MenuView:_init(port)
  self.name = "mainmenu"

  self.menus = {
    main= require("alloapps.menu.main_menu_pane")(self),
    overlay= require("alloapps.menu.overlay_pane")(self),
    audio= require("alloapps.menu.audio")(self)
  }
  self.root = ui.View()
  self.nav = ui.NavStack(ui.Bounds(0, 1.6, -2.5,   1.6, 1.2, 0.1))
  self.root:addSubview(self.nav)
  self.root:addSubview(self.menus.audio)
end

function MenuView:updateDebugTitle(newState)
  self.menus.main.debugButton.label:setText(newState and "Debug (On)" or "Debug (Off)")
end
function MenuView:updateMessage(msg)
  self.menus.main.messageLabel:setText(msg)
  self.menus.overlay.messageLabel:setText(msg)
end
function MenuView:switchToMenu(name)
  if self.nav:top() and self.nav:bottom().name == name then return end

  print("Switching to menu", name)
  self.nav:popAll()
  self.nav:push(self.menus[name])
end

function MenuView:onInteraction(interaction, body, receiver, sender)
  local body = tablex.deepcopy(body)
  local command = table.remove(body, 1)
  if command == "updateMenu" then
    local verb = table.remove(body, 1)
    self[verb](self, unpack(body))
  elseif command == "updateSubmenu" then
    local menuName = table.remove(body, 1)
    local verb = table.remove(body, 1)
    local menu = self.menus[menuName]
    menu[verb](menu, unpack(body))
  end
end

return MenuView