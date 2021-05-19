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
      children = {
        {
          transform = {
            matrix = { -- 180 deg rotation around y to compensate for models not being aligned in alloverse coordinate space
              -0.9999988079071,0,-0.0015925480984151,0,
              0,1,0,0,
              0.0015925480984151,0,-0.9999988079071,0,
              0,0,0,1
            },
          },
          geometry= {
            type= "hardcoded-model",
            name= "avatars/" .. self.avatarName .. "/" .. self.partName
          },
        },
      },
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
  nameTag = Base64Asset("iVBORw0KGgoAAAANSUhEUgAAAMAAAABACAMAAAB7sojtAAABKVBMVEUAAAA4OFA1Mko3NUo3Nkw3NUw3NUs3NUw2NEw2M0k4MFA4NEw3NU03NUs0NExAMFA2Nkw2NEw3NU02Nks2NEw3NUw3NUxcW22OjZq0s7za2d3m5uj////NzNKop7E3NUw3N0s3NU1paHjy8vTm5uk3NUyCgY83NUvl5ehQTmI3NUxEQlenp7CnprA4NEw1NUtcWm7x8fP+/v41NUpAMECmpbA2Nkw2NUxpZ3nMy9GCgI/a2t42NUtdW243NUo2M0xcWm01Mk2PjZo3NEyzsrw3Nks2NUzY2Nw2NUvMzNG0s7s3M0w3NEo4OEg3NUs3NU04NEw4NkswMFCnp7GnprFDQlc5NEs3NEw3NEs2NUvNzdI3NEza2t04NUpAQEA2NUw3NUw2NE02NExc4EV1AAAAY3RSTlMAIGCQr8/f/4BQIEDfn0AQf+/eX+5vv///////////7nCP/////v+e//++////f47///9gEP+A7/////+g/49Q/2D/r/+vz//O//+QTyDenoBfEP///3C/cJ//vv9gEKCQr89JTxAdAAACbklEQVR4AezZA7YlQQwG4Dx17lybebZt27b3v4uZ6s7pa4yTc963gcJfSaOgmqbmltY2CwWw2lo937zwU3wtFgrjDwShQaFwBEWKxrxqp8/i4bpLSMidPqcAtXiTKF7U2+D2p9KZbI4EyLV3pFOY19kFVXSjq6ejl0Tpy+TX0B+GigL56beTQNkBZDgIFbQJnj4bGkY2Un3/R8dIsPHRahlMoGOY61Z8CJMl/QcdU70k3PQUV3IXFPBy/xwgBbiWO72Q5+f9Jw1mpsoKeZbPfy+pMD1ccoi8TgCjOVJiaBSNzrniJ/AYqTGPtgUOYBGNFOkxs8QRFFZAjhRZ5ggKWtAKkcII4Acf2laJ9EXQHwSANTTWiTRGsOGeoAwpM45GFMCrrYTZNBr9TbCp7QSxmS17AdvgQSNN6uxwEezyU1idPTT24QCNdlLnEI0jsNTVMBviNoQ20mcGjf6vBfyurwWoL+IDde+i7Jjb6C4aJ6TOOD/ITnW/SnigWffL3Bmco61XZw33nwO3oTGd73IXAFwESypPEF7mP+rb9b2L8kc9LGqMYIBPkHGlMAIu4WswbvRFMDOMRuc5FEZwS2rc5f8sFkRwr+33+sU5sAedFxzX4HrUeMV0AXnni2hbUXTJFz+HAg/6rlmfoMiptovuBSixho570d20YxQdz1DmANm62BBelpC9AivJgK28SZ1+lf1nV+iaygiLobdjCV0bUMXDIuZNpTteRKwi95ZJT2Fe/AmqOrdQvNdzqOVd+BJqbD87P42gWJGrD6jvnFNQOX3m+xS3Buv7ErgZSAK+9hyJSYNj+X1SYgITIy53AgCT+DcB0RKo5AAAAABJRU5ErkJggg==")
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

  self.app.assetManager:add(AvatarChooser.assets)

  local displayNameFieldLabel = ui.Label{
    bounds= ui.Bounds(0, 0, 0,   1.0, 0.07, 0.001):move(0, 2.34, -0.25),
    color= {0.4,0.4,0.4,1},
    text= "Hello, my name is",
    halign= "left",
  }
  root:addSubview(displayNameFieldLabel)

  self.oldDisplayName = ""
  self.displayNameField = ui.TextField(ui.Bounds(0, 0, 0,   1.0, 0.16, 0.1):move(0, 2.2, -0.2))


  self.displayNameField.onChange = function(field, oldText, newText)
    self.oldDisplayName = newText
    self:actuate({"setDisplayName", newText})
    self.avatarNameTagLabel:setText(newText) -- Sets the name on the Avatar puppet's nametag
    return true
  end

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

  self.rightHand = BodyPart(ui.Bounds( 0.2, 1.30, -0.2,   0.2, 0.2, 0.2), self.avatarName, "right-hand", "hand/right")
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
  self.avatarNameTag.hasTransparency = true
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
