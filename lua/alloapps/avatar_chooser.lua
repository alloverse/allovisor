local Client = require("alloui.client")
local ui = require("alloui.ui")
local pretty = require("pl.pretty")
local class = require("pl.class")
local tablex = require("pl.tablex")
local math = require("lovr.math")
local EmbeddedApp = require("alloapps.embedded_app")

class.BodyPart(ui.View)
function BodyPart:_init(bounds, avatarName, partName, poseName)
  self:super(bounds)
  self.avatarName = avatarName
  self.partName = partName
  self.poseName = poseName
  self.followingId = nil
  self.modelview = self:addSubview(ui.ModelView())
  self.modelview.bounds:rotate(3.14159, 0, 1, 0)
end

function BodyPart:awake()
  View.awake(self)
  if self.partName == "torso" then
    self:addPropertyAnimation(ui.PropertyAnimation{
      path= "transform.matrix.translation.y",
      from= 1.15,
      to=   1.155,
      duration = 2.2,
      repeats= true,
      autoreverses= true,
      easing= "sineInOut",
    })
  elseif self.partName == "head" then
    self:addPropertyAnimation(ui.PropertyAnimation{
      path= "transform.matrix.translation.y",
      start_at = self.app:serverTime() + 0.4,
      from= 1.64,
      to=   1.645,
      duration = 2.2,
      repeats= true,
      autoreverses= true,
      easing= "sineInOut",
    })
  end
end

function BodyPart:specification()
  local mySpec = View.specification(self)
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

  local avatarsRoot = "/assets/models/avatars"
  self.modelview:setAsset(Asset.LovrFile(avatarsRoot.."/"..self.avatarName.."/"..self.partName..".glb"))
end

function BodyPart:follow(avatar)
  self.followingId = avatar.id
  self:markAsDirty("intent")
end

function BodyPart:updateOther(e)
  local newSpec = {
    geometry= self.modelview:specification().geometry
  }
  if self.app and self.entity then
    local matchingBodyPartIndex = tablex.find_if(e:getChildren(), function(child)
      print(child.id, child.components.geometry and child.components.geometry.type)
      return child.components.geometry and child.components.geometry.type=="asset"
    end)
    if matchingBodyPartIndex then
      print("Avatar chooser modifying user's", self.poseName, "to", self.avatarName)
      self.app.client:sendInteraction({
        sender_entity_id = self.entity.id,
        receiver_entity_id = "place",
        body = {
            "change_components",
            e:getChildren()[matchingBodyPartIndex].id,
            "add_or_change", newSpec,
            "remove", {}
        }
      })
    end
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

  self.app.assetManager:add(AvatarChooser.assets)


  local root = ui.Surface(ui.Bounds{size=ui.Size(0.5, 0.6, 0.001)}:rotate(0.4, 0,1,0):move(-0.55, 1.6, -0.905))
  --root:setColor({0.5, 0.8, 0.9, 0.1})
  root:setColor({0, 0, 0, 0})

  local vstack = ui.StackView(ui.Bounds{size=ui.Size(0.5, 0, 0.001)}, "v")
  vstack:margin(0.02)
  root:addSubview(vstack)
  

  self.puppetContainer = ui.View(ui.Bounds{size=ui.Size(0.5, 0.3, 0.3)})


  self.puppet = ui.View(ui.Bounds{size=ui.Size(0.5, 0.3, 0.5)}:move(0, -1.4, 0):rotate(3.14, 0, 1, 0):scale(0.5))

  self.head = BodyPart(     ui.Bounds( 0.0, 0.60, 0.0,   0.2, 0.2, 0.2), self.avatarName, "head", "head")
  self.puppet:addSubview(self.head)

  self.torso = BodyPart(    ui.Bounds( 0.0, 0.15, 0.0,   0.2, 0.2, 0.2), self.avatarName, "torso", "torso")
  self.puppet:addSubview(self.torso)

  self.leftHand = BodyPart( ui.Bounds(-0.2, 0, 0.2,   0.2, 0.2, 0.2), self.avatarName, "left-hand", "hand/left")
  self.puppet:addSubview(self.leftHand)

  self.rightHand = BodyPart(ui.Bounds( 0.2, 0.1, -0.2,   0.2, 0.2, 0.2), self.avatarName, "right-hand", "hand/right")
  self.puppet:addSubview(self.rightHand)

  self.parts = {self.head, self.torso, self.leftHand, self.rightHand}

  self.poseEnts = {
    head = {},
    torso = {},
    ["hand/left"] = {},
    ["hand/right"] = {},
  }

  -- Creates & attaches the name tag to the puppet's torso
  self.avatarNameTag = ui.Surface(ui.Bounds(0, 0.24, 0.174,   0.2, 0.066, 0):rotate(3.14, 0, 1, 0):rotate(3.14/8, 1, 0, 0))
  self.avatarNameTag.material.texture = AvatarChooser.assets.nameTag

  self.avatarNameTag.hasTransparency = true
  self.avatarNameTagLabel = ui.Label {
    bounds= ui.Bounds(0, 0, 0,   0.16, 0.062, 0.001),
    text= "My Name",
    fitToWidth= true
  }
  self.avatarNameTagLabel.color = {12/255, 43/255, 72/255}  -- TODO: Make this refer to Color.alloDark() constant instead of this magic number

  self.avatarNameTag:addSubview(self.avatarNameTagLabel)
  self.torso:addSubview(self.avatarNameTag)


  self.puppetContainer:addSubview(self.puppet)
  vstack:addSubview(self.puppetContainer) 


  local avatarInputBackground = ui.Surface(ui.Bounds{size=ui.Size(0.4, 0.3, 0.01)})
  local avatarInputStack = ui.StackView(avatarInputBackground.bounds:copy())
  avatarInputStack:margin(0.02)


  local nameInputLabel = ui.Label{
    bounds= ui.Bounds{size=ui.Size(0.4, 0.03, 0.01)},
    color= {12/255, 43/255, 72/255, 1},  -- TODO: Make this refer to Color.alloDark() constant instead of this magic number
    text= "Hello, my name is",
    halign= "left",
  }
  
  self.oldDisplayName = ""
  self.nameInputField = ui.TextField(ui.Bounds{size=ui.Size(0.4, 0.08, 0.02)})

  self.nameInputField.onChange = function(field, oldText, newText)
    self.oldDisplayName = newText
    self:actuate({"setDisplayName", newText})
    self.avatarNameTagLabel:setText(newText) -- Sets the name on the Avatar puppet's nametag
    return true
  end

  self.nameInputField.onReturn = function(field, text)
    self.oldDisplayName = text
    self:actuate({"setDisplayName", text})
    field:defocus()
    self.avatarNameTagLabel:setText(text) -- Sets the name on the Avatar puppet's nametag
    return false
  end

  self.nameInputField.onLostFocus = function()
    self.nameInputField.label:setText(self.oldDisplayName)
  end



  local avatarTypeStack = ui.StackView(ui.Bounds{size=ui.Size(0.4, 0.08, 0.01)}, "h")
  --avatarTypeStack:margin(0.02)
  avatarTypeStack:margin(0)

  self.prevButton = ui.Button(ui.Bounds{size=ui.Size(0.08, 0.08, 0.05)})
  self.prevButton.label.text = "<"
  self.prevButton.onActivated = function() self:actuate({"changeAvatar", -1}) end
  
  self.nameLabel = ui.Label{
    bounds= ui.Bounds{size=ui.Size(0.24, 0.06, 0.01)},
    text= self.avatarName,
    lineHeight=0.04,
    color={12/255, 43/255, 72/255} -- TODO: Make this refer to Color.alloDark() constant instead of this magic number
  }
  
  self.nextButton = ui.Button(ui.Bounds{size=ui.Size(0.08, 0.08, 0.05)})
  self.nextButton.label.text = ">"
  self.nextButton.onActivated = function() self:actuate({"changeAvatar", 1}) end
  
  -- TODO: The avatarTypeStack seems to add things from right-to-left, which seems counterintuitive
  avatarTypeStack:addSubview(self.nextButton)
  avatarTypeStack:addSubview(self.nameLabel)
  avatarTypeStack:addSubview(self.prevButton)

  avatarTypeStack:layout()
  
  
  avatarInputStack:addSubview(avatarTypeStack)
  avatarInputStack:addSubview(nameInputLabel)
  avatarInputStack:addSubview(self.nameInputField)
  
  avatarInputStack:layout()

  avatarInputBackground:addSubview(avatarInputStack)
  vstack:addSubview(avatarInputBackground)


  vstack:layout()

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
  local entity = comp:getEntity()
  if key == "intent" and comp.actuate_pose ~= "root" and entity.components.ui == nil then
    self.poseEnts[comp.actuate_pose][entity.id] = entity
  end
end

function AvatarChooser:onComponentRemoved(key, comp)
  if key == "intent" then
    local entity = comp.getEntity()
    self.poseEnts[comp.actuate_pose][entity.id] = nil
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
  self.nameInputField.label:setText(displayName)
  self.avatarNameTagLabel:setText(displayName)
  end

function AvatarChooser:showAvatar(avatarName)
  self.avatarName = avatarName
  self.nameLabel:setText(self.avatarName)
  for _, part in ipairs(self.parts) do
    part:setAvatar(self.avatarName)
    
    for eid, e in pairs(self.poseEnts[part.poseName]) do
      part:updateOther(e)
    end
  end
end


return AvatarChooser
