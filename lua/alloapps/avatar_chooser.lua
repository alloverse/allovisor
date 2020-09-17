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
end

function BodyPart:specification()
  local mySpec = tablex.union(View.specification(self), {
      geometry= {
        type= "hardcoded-model",
        name= "avatars/" .. self.avatarName .. "/" .. self.partName
      }
  })
  return mySpec
end

function BodyPart:setAvatar(avatarName)
  self.avatarName = avatarName
  if self:isAwake() then
    local spec = self:specification()
    self:updateComponents(spec)
  end
end

class.AvatarChooser(EmbeddedApp)
function AvatarChooser:_init()
  self.avatarName = "female"
  self:super("avatarchooser")
end

function AvatarChooser:createUI()
  local root = ui.View(ui.Bounds(0, 0, 0,  0.3, 2, 0.3):rotate(3.14/4, 0,1,0):move(-1.6, 0, -1.4))

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

  self.head = BodyPart(     ui.Bounds( 0.0, 1.80, 0.0,   0.2, 0.2, 0.2), self.avatarName, "head", "head")
  root:addSubview(self.head)

  self.torso = BodyPart(    ui.Bounds( 0.0, 1.45, 0.0,   0.2, 0.2, 0.2), self.avatarName, "torso", "torso")
  root:addSubview(self.torso)

  self.leftHand = BodyPart( ui.Bounds( 0.2, 1.20, 0.1,   0.2, 0.2, 0.2), self.avatarName, "left-hand", "hand/left")
  root:addSubview(self.leftHand)

  self.rightHand = BodyPart(ui.Bounds(-0.2, 1.40, 0.2,   0.2, 0.2, 0.2), self.avatarName, "right-hand", "hand/right")
  root:addSubview(self.rightHand)



  return root
end

function AvatarChooser:onInteraction(interaction, body, receiver, sender)
  if body[1] == "showAvatar" then
    local avatarName = body[2]
    self.avatarName = avatarName
    for _, part in ipairs({self.head, self.torso, self.leftHand, self.rightHand}) do
      part:setAvatar(self.avatarName)
      self.nameLabel:setText("Avatar: "..self.avatarName)
    end
  end
end

return AvatarChooser