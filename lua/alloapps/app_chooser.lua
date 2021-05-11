local Client = require("alloui.client")
class = require('pl.class')
tablex = require('pl.tablex')
pretty = require('pl.pretty')
vec3 = require("modules.vec3")
mat4 = require("modules.mat4")
local ui = require("alloui.ui")

local EmbeddedApp = require("alloapps.embedded_app")

----------------------
-- AppPreview Class --
----------------------

class.AppPreview(ui.View)
function AppPreview:_init(bounds, modelName, appName)
  self:super(bounds)
  self.modelName = modelName
  self.appName = appName
end

function AppPreview:specification()
  local mySpec = tablex.union(View.specification(self), {
      geometry= {
        type= "hardcoded-model",
        name= "app-previews/" .. self.modelName
      },
      material= {
        shader_name= "pbr"
      }
  })

  print("AppPreview:specification() mySpec.geometry.name:", mySpec.geometry.name)

  return mySpec
end

function AppPreview:setModelName(appModel)
  self.modelName = appModel
  if self:isAwake() then
    local spec = self:specification()
    print("onto updateComponents with spec:", spec)
    self:updateComponents(spec)
  end
end


----------------------
-- AppChooser Class --
----------------------

class.AppChooser(EmbeddedApp)
function AppChooser:_init(port)
  self:super("appchooser", port)
end

function AppChooser:createUI()
  self.ui = self:_createUI()
  return ui.View()
end

function AppChooser:_createUI()
  local root = ui.View(ui.Bounds(0, 0, -1.2,  0.3, 2, 0.3):rotate(-3.14/4, 0,1,0):move(0.70, 0, -1.3))

  local controls = ui.Surface(ui.Bounds(0, -0.1, 0,   1.3, 0.4, 0.02):rotate(-3.14/4, 1, 0, 0):move(0, 1.1, 0))
  root:addSubview(controls)

  self.nameLabel = ui.Label{
    bounds= ui.Bounds(0, 0.10, 0,   0.5, 0.08, 0.02),
    text= "Loading..."
  }
  self.nameLabel.color = {0,0,0,1}
  controls:addSubview(self.nameLabel)

  self.prevButton = ui.Button(ui.Bounds(-0.55, 0.1, 0.01,     0.15, 0.15, 0.05))
  self.prevButton.label.text = "<"
  self.prevButton.onActivated = function() self:stepThroughAppList(-1) end
  controls:addSubview(self.prevButton)
  self.nextButton = ui.Button(ui.Bounds( 0.55, 0.1, 0.01,     0.15, 0.15, 0.05))
  self.nextButton.label.text = ">"
  self.nextButton.onActivated = function() self:stepThroughAppList(1) end
  controls:addSubview(self.nextButton)

  self.addButton = ui.Button(ui.Bounds(0, -0.1, 0.01,     1.25, 0.15, 0.05))
  self.addButton.label.text = "Launch"
  self.addButton.onActivated = function() self:launchSelectedApp() end
  controls:addSubview(self.addButton)

  self.appPreview = AppPreview(ui.Bounds( 0.0, 1.80, 0.0,   0.2, 0.2, 0.2), "dummy-model", "dummy name")
  root:addSubview(self.appPreview)
  

  -- -- Creates a single dummy app for testing purposes. Later, this will get the list of all viable apps and fill the appList with all AppPreview objects
  self.appList = {}
  table.insert(self.appList, {name="Drawing board", modelname="drawing-board"})
  table.insert(self.appList, {name="Jukebox", modelname="jukebox"})
  table.insert(self.appList, {name="Clock", modelname="clock"})
  table.insert(self.appList, {name="File Viewer", modelname="fileviewer"})
  table.insert(self.appList, {name="Alloverse House", modelname="house"})
  
  -- puts the first app on display
  self:setActivePreview(1)

  return root
end

function AppChooser:setVisible(visible)
  if visible and #self.app.mainView.subviews == 0 then
    self.app.mainView:addSubview(self.ui)
  elseif not visible and #self.app.mainView.subviews == 1 then
    self.ui:removeFromSuperview()
  end
end


function AppChooser:stepThroughAppList(direction)
  local newI = ((self.appListIndex + direction - 1) % #self.appList) + 1
  self:setActivePreview(newI)
end

function AppChooser:setActivePreview(newI)
  local appToPreview = self.appList[newI]
  
  self.appPreview:setModelName(appToPreview.modelname)
  self.nameLabel:setText(appToPreview.name)
  self.appListIndex = newI
end

function AppChooser:launchSelectedApp()
  local appToPreview = self.appList[self.appListIndex]
  self:actuate({"launchApp", appToPreview.modelname})
end

function AppChooser:onInteraction(interaction, body, receiver, sender)
  if body[1] == "setVisible" then
    self:setVisible(body[2])
  end
end



return AppChooser
