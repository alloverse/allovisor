local Client = require("alloui.client")
local ui = require("alloui.ui")
local pretty = require("pl.pretty")
local tablex = require("pl.tablex")
local class = require("pl.class")
local EmbeddedApp = require("alloapps.embedded_app")
local AudioPane = require("alloapps.menu.audio_pane")

class.Menu(EmbeddedApp)
Menu.assets = {
  forest= Asset.LovrFile("assets/models/decorations/forest/PUSHILIN_forest.glb"),
}
function Menu:_init(port)
  self:super("mainmenu", port)
  self.app.assetManager:add(Menu.assets)
end

function Menu:createUI()
  self.menus = {
    main= require("alloapps.menu.main_menu_pane")(self),
    overlay= require("alloapps.menu.overlay_pane")(self),
  }
  self.app.assetManager:add(getmetatable(self.menus.main).assets)
  self.root = ui.View()
  self.nav = ui.NavStack(ui.Bounds(0, 1.6, -2.5,   1.6, 1.2, 0.1))
  self.root:addSubview(self.nav)
  self.root:addSubview(self:createForest())
  return self.root
end

function Menu:updateMessage(msg)
  self.menus.main.messageLabel:setText(msg)
  self.menus.overlay.messageLabel:setText(msg)
end
function Menu:switchToMenu(name)
  if self.nav:top() and self.nav:bottom().name == name then return end

  self.nav:popAll()
  self.nav:push(self.menus[name])
end

function Menu:onInteraction(interaction, body, receiver, sender)
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

function Menu:createForest()
  local decos = ui.View()
  decos:addSubview(ui.ModelView(ui.Bounds(0,0,0, 1, 1, 1):scale(2):move(  0, 0.55, -10), Menu.assets.forest))
  decos:addSubview(ui.ModelView(ui.Bounds(0,0,0, 1, 1, 1):scale(2):move(  4, 0.55, -8), Menu.assets.forest))
  decos:addSubview(ui.ModelView(ui.Bounds(0,0,0, 1, 1, 1):scale(2):move(  8, 0.55, -4), Menu.assets.forest))
  decos:addSubview(ui.ModelView(ui.Bounds(0,0,0, 1, 1, 1):scale(2):move( 10, 0.55, 0), Menu.assets.forest))
  decos:addSubview(ui.ModelView(ui.Bounds(0,0,0, 1, 1, 1):scale(2):move(  8, 0.55, 4), Menu.assets.forest))
  decos:addSubview(ui.ModelView(ui.Bounds(0,0,0, 1, 1, 1):scale(2):move(  4, 0.55, 8), Menu.assets.forest))
  decos:addSubview(ui.ModelView(ui.Bounds(0,0,0, 1, 1, 1):scale(2):move(  0, 0.55, 10), Menu.assets.forest))
  decos:addSubview(ui.ModelView(ui.Bounds(0,0,0, 1, 1, 1):scale(2):move( -4, 0.55, 8), Menu.assets.forest))
  decos:addSubview(ui.ModelView(ui.Bounds(0,0,0, 1, 1, 1):scale(2):move( -8, 0.55, 4), Menu.assets.forest))
  decos:addSubview(ui.ModelView(ui.Bounds(0,0,0, 1, 1, 1):scale(2):move(-10, 0.55, 0), Menu.assets.forest))
  decos:addSubview(ui.ModelView(ui.Bounds(0,0,0, 1, 1, 1):scale(2):move( -8, 0.55, -4), Menu.assets.forest))
  decos:addSubview(ui.ModelView(ui.Bounds(0,0,0, 1, 1, 1):scale(2):move( -4, 0.55, -8), Menu.assets.forest))
  local floor = decos:addSubview(ui.Surface(ui.Bounds(0,0,0, 24, 24, 0.01):rotate(3.14/2, 1,0,0)))
  floor:setColor({181/255, 218/255, 153/255, 0.5})

  return decos
end

return Menu
