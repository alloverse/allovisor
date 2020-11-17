local Client = require("alloui.client")
local ui = require("alloui.ui")
local pretty = require("pl.pretty")
local class = require("pl.class")
local tablex = require("pl.tablex")
local EmbeddedApp = require("alloapps.embedded_app")

class.BodyPart(ui.View)
function BodyPart:_init(bounds, avatarName, partName, poseName)
  self:super(bounds)
  self.avatarName = avatarName
  self.partName = partName
  self.poseName = poseName
  self.followingId = nil
end

function BodyPart:specification()
  local mySpec = tablex.union(View.specification(self), {
      geometry= {
        type= "hardcoded-model",
        name= "avatars/" .. self.avatarName .. "/" .. self.partName
      },
      material= {
        shader_name= "pbr"
      }
  })
  if self.followingId then
    mySpec.intent= {
      actuate_pose= self.poseName,
      from_avatar= self.followingId
    }
  end
  return mySpec
end

function BodyPart:setAvatar(avatarName)
  self.avatarName = avatarName
  if self:isAwake() then
    local spec = self:specification()
    self:updateComponents(spec)
  end
end

function BodyPart:follow(avatar)
  self.followingId = avatar.id
  if self:isAwake() then
    self:updateComponents({self:specification().intent})
  end
end

function BodyPart:updateOther(eid)
  local newSpec = {
    geometry= self:specification().geometry
  }
  if self.app and self.entity then
    self.app.client:sendInteraction({
      sender_entity_id = self.entity.id,
      receiver_entity_id = "place",
      body = {
          "change_components",
          eid,
          "add_or_change", newSpec,
          "remove", {}
      }
    })
  end
end

class.AvatarChooser(EmbeddedApp)
function AvatarChooser:_init(port)
  self.avatarName = "female"
  self:super("avatarchooser", port)
end

function AvatarChooser:createUI()
  self.ui = self:_createUI()
  return ui.View()
end

function AvatarChooser:_createUI()
  local root = ui.View(ui.Bounds(0, 0, -1,  0.3, 2, 0.3):rotate(3.14/4, 0,1,0):move(-0.70, 0, -1.3))

  local controls = ui.Surface(ui.Bounds(0, 0, 0,   1.3, 0.2, 0.02):rotate(-3.14/4, 1, 0, 0):move(0, 1.1, 0))
  root:addSubview(controls)

  self.nameLabel = ui.Label{
    bounds= ui.Bounds(0, 0, 0,   0.5, 0.08, 0.02),
    text= "Avatar: " .. self.avatarName
  }
  self.nameLabel.color = {0,0,0,1}
  controls:addSubview(self.nameLabel)

  self.prevButton = ui.Button(ui.Bounds(-0.55, 0.0, 0.01,     0.15, 0.15, 0.05))
  self.prevButton.label.text = "<"
  self.prevButton.onActivated = function() self:actuate({"changeAvatar", -1}) end
  controls:addSubview(self.prevButton)
  self.nextButton = ui.Button(ui.Bounds( 0.55, 0.0, 0.01,     0.15, 0.15, 0.05))
  self.nextButton.label.text = ">"
  self.nextButton.onActivated = function() self:actuate({"changeAvatar", 1}) end
  controls:addSubview(self.nextButton)

  local puppet = ui.View(ui.Bounds():rotate(3.1416, 0,1,0))
  root:addSubview(puppet)

  self.head = BodyPart(     ui.Bounds( 0.0, 1.80, 0.0,   0.2, 0.2, 0.2), self.avatarName, "head", "head")
  puppet:addSubview(self.head)

  self.torso = BodyPart(    ui.Bounds( 0.0, 1.35, 0.0,   0.2, 0.2, 0.2), self.avatarName, "torso", "torso")
  puppet:addSubview(self.torso)

  self.leftHand = BodyPart( ui.Bounds(-0.2, 1.20, 0.2,   0.2, 0.2, 0.2), self.avatarName, "left-hand", "hand/left")
  puppet:addSubview(self.leftHand)

  self.rightHand = BodyPart(ui.Bounds( 0.2, 1.40, -0.2,   0.2, 0.2, 0.2), self.avatarName, "right-hand", "hand/right")
  puppet:addSubview(self.rightHand)

  self.parts = {self.head, self.torso, self.leftHand, self.rightHand}

  self.poseEnts = {
    head = {},
    torso = {},
    ["hand/left"] = {},
    ["hand/right"] = {},
  }

  return root
end

function AvatarChooser:setVisible(visible)
  if visible and #self.app.mainView.subviews == 0 then
    self.app.mainView:addSubview(self.ui)
  elseif not visible and #self.app.mainView.subviews == 1 then
    self.ui:removeFromSuperview()
  end
end

function AvatarChooser:onComponentAdded(key, comp)
  EmbeddedApp.onComponentAdded(self, key, comp)
  if self.visor ~= self.actuatingFor then
    self.actuatingFor = self.visor
    for _, part in ipairs(self.parts) do
      part:follow(self.actuatingFor)
    end
  end
  if key == "intent" then
    local entity = comp.getEntity()

    table.insert(self.poseEnts[comp.actuate_pose], entity.id)
  end
end

function AvatarChooser:onComponentRemoved(key, comp)
  if key == "intent" then
    local entity = comp.getEntity()
    local idx = tablex.find(self.poseEnts[comp.actuate_pose], entity.id)
    if idx ~= -1 then
      table.remove(self.poseEnts[comp.actuate_pose], idx)
    end
  end
end
function AvatarChooser:onInteraction(interaction, body, receiver, sender)
  if body[1] == "showAvatar" then
    local avatarName = body[2]
    self.avatarName = avatarName
    self.nameLabel:setText("Avatar: "..self.avatarName)
    for _, part in ipairs(self.parts) do
      part:setAvatar(self.avatarName)
      
      for _, other in ipairs(self.poseEnts[part.poseName]) do
        part:updateOther(other)
      end
    end
  elseif body[1] == "setVisible" then
    self:setVisible(body[2])
  end
end

return AvatarChooser