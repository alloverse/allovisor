local Client = require("alloui.client")
local ui = require("alloui.ui")
local pretty = require("pl.pretty")
local tablex = require("pl.tablex")
local class = require("pl.class")
local EmbeddedApp = require("alloapps.embedded_app")

class.Menu(EmbeddedApp)
function Menu:_init()
  self:super("mainmenu")
end

function Menu:createUI()
  self.menus = {
    main= require("alloapps.menu.main_menu_pane")(self),
    overlay= require("alloapps.menu.overlay_pane")(self)
  }
  return ui.View()
end

function Menu:updateDebugTitle(newState)
  self.menus.main.debugButton.label:setText(newState and "Debug (On)" or "Debug (Off)")
end
function Menu:updateMessage(msg)
  self.menus.main.messageLabel:setText(msg)
  self.menus.overlay.messageLabel:setText(msg)
end
function Menu:switchToMenu(name)
  if self.currentMenuName == name then return end

  print("Switching to menu", name)
  if self.currentMenu then
    self.currentMenu:removeFromSuperview()
  end
  
  self.currentMenu = self.menus[name]
  self.currentMenuName = name
  self.app.mainView:addSubview(self.currentMenu)
end

function Menu:onInteraction(interaction, body, receiver, sender)
  local body = tablex.deepcopy(body)
  local command = table.remove(body, 1)
  if command == "updateMenu" then
    local verb = table.remove(body, 1)
    self[verb](self, unpack(body))
  end
end

return Menu