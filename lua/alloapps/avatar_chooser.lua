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
AvatarChooser.assets = {
  nameTag = Base64Asset("iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsIAAA7CARUoSoAAAAP+SURBVHhe7ZsLjpswEIZDol6k6lF6yp6lB2jVK1Q9x0ptROe3Z/BrbA8EdoHk0zoQM29sx9llh2+/fo6XHgMfq5K4IEIr0zONa/0MVO7jeLnyuc5A1sVB4SSOqhXhg4jpWpILkwc3yk8vgBilCukO0PmA5yVIIVaudSgA7jZAXlUnknQssDwir2nTn6RWrnsoAO42UOMJXkv/yyPymjb95V7atNcAcTuI2GC8X8ehUQAkz+nK6Cj42II85JvXt0YBGuaneozhVMVfhaW4rUXbt0akQWve2/1fbwpUcFmUyZX4XkjGzQ5bdUrzNEvI1phGWf8YzLAmtz5s1bnSo7BDtmACDWbp+Ol2sxVgveR2sIhy8pLUsikwh8gZTvRiSm96dXGxZihuUgCXBl6wucJqW/Ui1ZGI08jTcsyAFb211GaO6cvQ9z+/+ewYfP38hc/6dEfA0ZIHc2Lefg3YOZUCnG/LWyMUABlPq4FfrdE1Zz7thTkx0yL4g3KlVCXjCKUr4ArWlFgN58qf2kBGpGTRoRHACRR51KYBh+Os6xKPkYVNRc52sA1YcEZY2RoQO88D4aM7aXiofnO0QrZj86Zb6WWGSNAaBRdgZJ+xZ0YsKZcKIIuAH8Ua/QQp+Bq0kdAiQS5AXDvPlIYpH9ZeIfdNkSSjQmRTIOBl/TpQa4H03f7Iby9DYZ98K4zU2jenOgKEY2+F+yPziiLtfQCvh0zs0K54TebASaqhp+F7ka+0dApIb8RRt8JZGlV4EaSf1oZDfrFxUOLR4LPAq++d9gFq8tKXJK8JfjxIJ040BhFL8wRJ5VMAF1lUtcidNW8b4dyxT+0WpAmW1MINBZjuMo7BE85U5Za3DXDu2GctmZxYrhZuKMBVvv1FanQKxUdyXRJsE46ppOy1xB2NAFGwqNmxWjN7JcGkWNMbcwkTXr8V5mOVY2+FO9DHeyjAshF0bGjhT9aAZ6Q7BY66FbZiWgTPTHcEnBe/6D1HAdQF3g/85yhAY5I/8RTwPH0BXlthPlY59VaYeK0BfHxOaPJ3C3DqrTDtD15bYT5W8Zuo3kPRdv7e71PbA90C+MSXPjQVaXEF8XyutPdHnoMIbLwIRuNmaP+pHW17sucgyOk7fgr4adRqFhYXKvvLlrMzGh+XN0cHuY1vZRqKJTCSQUzZoztes/d/g4I1KchZYlqNTmDurpNMI6Z3nAIb0Mof17K7XmKdAjvD5YbGo9u/ZJhGYj4FMGQKRc0SeTQ56KH56wOVuJltKCMiLQAECplKeV03XqzeNXJ/bCsyicuJiBVSKiLLPgnAzCmQG8D7pZskDbYUGYSHMuwIbZ6jj5Qscc0sgG4yCVCp8jZwhpo/cwyXy3+J0TAitxbCpAAAAABJRU5ErkJggg==")
}

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

  local displayNameFieldLabel = ui.Label{
    bounds= ui.Bounds(0, 0, 0,   1.0, 0.07, 0.001):move(0, 2.34, -0.25),
    color= {0.4,0.4,0.4,1},
    text= "Hello, my name is",
    halign= "left",
  }
  root:addSubview(displayNameFieldLabel)

  self.oldDisplayName = ""
  self.displayNameField = ui.TextField(ui.Bounds(0, 0, 0,   1.0, 0.16, 0.1):move(0, 2.2, -0.2))
  self.displayNameField.onReturn = function(field, text)
    self.oldDisplayName = text
    self:actuate({"setDisplayName", text})
    field:defocus()

    self.avatarNameTagLabel:setText(text) -- Sets the name on the Avatar puppet's nametag

    return false
  end
  self.displayNameField.onLostFocus = function()
    self.displayNameField.label:setText(self.oldDisplayName)
  end
  root:addSubview(self.displayNameField)

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

  self.avatarNameTag = ui.Surface(ui.Bounds(0, 0, 0,   0.2, 0.066, 0):rotate(3.14, 0, 1, 0):move(0, 0.25, -0.18):rotate(3.14/8, 1, 0, 0))
  self.avatarNameTag.texture = AvatarChooser.assets.nameTag
  self.avatarNameTagLabel = ui.Label {
    bounds= ui.Bounds(0, 0, 0,   0.5, 0.04, 0.001),
    text= "My Name",
    lineheight= 0.04,
    fitToWidth= self.avatarNameTag.bounds.size.width - 0.04 -- 2cm padding on the left & right
  }
  self.avatarNameTagLabel.color = {0.21484375,0.20703125,0.30078125,1}
  self.avatarNameTag:addSubview(self.avatarNameTagLabel)
  self.torso:addSubview(self.avatarNameTag)

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
  if key == "intent" and comp.actuate_pose ~= "root" then
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
  local func = self[body[1]]
  if func then
    table.remove(body, 1)
    func(self, unpack(body))
  end
end

function AvatarChooser:setDisplayName(displayName)
  self.oldDisplayName = displayName
  self.displayNameField.label:setText(displayName)
  self.avatarNameTagLabel:setText(displayName)
  end

function AvatarChooser:showAvatar(avatarName)
  self.avatarName = avatarName
  self.nameLabel:setText("Avatar: "..self.avatarName)
  for _, part in ipairs(self.parts) do
    part:setAvatar(self.avatarName)
    
    for _, other in ipairs(self.poseEnts[part.poseName]) do
      part:updateOther(other)
    end
  end
end


return AvatarChooser
