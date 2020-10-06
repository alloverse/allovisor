
local Client = require("alloui.client")
local ui = require("alloui.ui")
local pretty = require("pl.pretty")
local class = require("pl.class")
local tablex = require("pl.tablex")
local EmbeddedApp = require("alloapps.embedded_app")


class.AppPreview(ui.View)
function AppPreview:_init(bounds, appName)
  self:super(bounds)
  self.appName = appName
end

function AppPreview:specification()
  local mySpec = tablex.union(View.specification(self), {
      geometry= {
        type= "hardcoded-model",
        name= "broken"
      },
      material= {
        shader_name= "pbr"
      }
  })
  return mySpec
end




class.AppChooser(EmbeddedApp)
function AppChooser:_init()
  self.appName = "N/A"
  self.appPreviewListIndex = 1
  self:super("appchooser")
end

function AppChooser:createUI()
  local root = ui.View(ui.Bounds(0, 0, 0,  0.3, 2, 0.3):rotate(-3.14/4, 0,1,0):move(1.6, 0, -1.4))

  local controls = ui.Surface(ui.Bounds(0, 0, 0,   1.3, 0.2, 0.02):rotate(-3.14/4, 1, 0, 0):move(0, 1.1, 0))
  root:addSubview(controls)

  self.nameLabel = ui.Label{
    bounds= ui.Bounds(0, 0, 0,   0.5, 0.08, 0.02),
    text= "App: " .. self.appName
  }
  self.nameLabel.color = {0,0,0,1}
  controls:addSubview(self.nameLabel)

  self.prevButton = ui.Button(ui.Bounds(-0.55, 0.0, 0.01,     0.15, 0.15, 0.05))
  self.prevButton.label.text = "<"
  self.prevButton.onActivated = function() self:stepThroughAppList(-1) end
  controls:addSubview(self.prevButton)
  self.nextButton = ui.Button(ui.Bounds( 0.55, 0.0, 0.01,     0.15, 0.15, 0.05))
  self.nextButton.label.text = ">"
  self.nextButton.onActivated = function() self:stepThroughAppList(1) end
  controls:addSubview(self.nextButton)

  self.addButton = ui.Button(ui.Bounds(0, -0.25, 0.01,     1.1, 0.15, 0.05))
  self.addButton.label.text = "Add"
  self.addButton.onActivated = function() self:addApp() end
  controls:addSubview(self.addButton)


  self.appPreviewShowcase = ui.View(ui.Bounds():rotate(3.1416, 0,1,0))
  root:addSubview(self.appPreviewShowcase)
  
  -- Creates a single dummy app for testing purposes. Later, this will get the list of all viable apps and fill the appPreviewList with all AppPreview objects
  self.appPreviewList = {}
  table.insert(self.appPreviewList, AppPreview(ui.Bounds( 0.0, 1.35, 0.0,   0.2, 0.2, 0.2), "Dummy App 1"))
  table.insert(self.appPreviewList, AppPreview(ui.Bounds( 0.0, 1.35, 0.0,   0.2, 0.2, 0.2), "Dummy App 2"))
  table.insert(self.appPreviewList, AppPreview(ui.Bounds( 0.0, 1.35, 0.0,   0.2, 0.2, 0.2), "Dummy App 3"))

  -- puts the first app in (at index 1) appPreviewList on display
  self:setActivePreview(self.appPreviewListIndex)

  -- Not sure what this does
  self.poseEnts = {
    head = {},
    torso = {},
    ["hand/left"] = {},
    ["hand/right"] = {},
  }

  return root
end

function AppChooser:setActivePreview(index)
  if self.appPreviewList == nil then return end

  local appToPreview = self.appPreviewList[index]
  self.nameLabel:setText(appToPreview.appName)
  self.appPreviewShowcase:addSubview(appToPreview)

  -- update the current list index to be the new one
  self.appPreviewListIndex = index
end

function AppChooser:stepThroughAppList(direction)
  if self.appPreviewList == nil then return end

  local newI = ((self.appPreviewListIndex + direction - 1) % #self.appPreviewList) + 1

  -- print("==============================")
  -- print("Stepping through list of apps:")
  -- print("Direction: ", direction)
  -- print("i:         ", self.appPreviewListIndex)
  -- print("newI:      ", newI)

  self:setActivePreview(newI)
end

function AppChooser:addApp()

  local appToAdd = self.appPreviewList[self.appPreviewListIndex]
  print("Adding " .. appToAdd.appName)

end





-- function AppChooser:onComponentAdded(key, comp)
--   EmbeddedApp.onComponentAdded(self, key, comp)
--   if self.visor ~= self.actuatingFor then
--     self.actuatingFor = self.visor
--     -- for _, part in ipairs(self.appPreviewModels) do
--     --   part:follow(self.actuatingFor)
--     -- end
--   end
--   if key == "intent" then
--     local entity = comp.getEntity()

--     table.insert(self.poseEnts[comp.actuate_pose], entity.id)
--   end
-- end

-- function AppChooser:onComponentRemoved(key, comp)
--   if key == "intent" then
--     local entity = comp.getEntity()
--     local idx = tablex.find(self.poseEnts[comp.actuate_pose], entity.id)
--     if idx ~= -1 then
--       table.remove(self.poseEnts[comp.actuate_pose], idx)
--     end
--   end
-- end

-- function AppChooser:onInteraction(interaction, body, receiver, sender)
--   if body[1] == "showAvatar" then
--     local appName = body[2]
--     self.appName = appName
--     for _, part in ipairs(self.appPreviewModels) do
--       part:setApp(self.appName)
--       self.nameLabel:setText("Avatar: "..self.appName)

--       for _, other in ipairs(self.poseEnts[part.poseName]) do
--         part:updateOther(other)
--       end
--     end
--   end
-- end

return AppChooser