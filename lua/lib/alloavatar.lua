local ui = require("alloui.ui")
local class = require("pl.class")
local tablex = require("pl.tablex")
local pretty = require("pl.pretty")
local Store = require("lib.lovr-store")
local vec3 = require("modules.vec3")
local mat4 = require("modules.mat4")

class.AlloAvatar(ui.View)

AlloAvatar.assets = {
}

function AlloAvatar.loadAssets()
    if AlloAvatar.assets.nameTag == nil then
        AlloAvatar.assets.nameTag = ui.Asset.Base64("iVBORw0KGgoAAAANSUhEUgAAAMAAAABACAMAAAB7sojtAAABKVBMVEUAAAA4OFA1Mko3NUo3Nkw3NUw3NUs3NUw2NEw2M0k4MFA4NEw3NU03NUs0NExAMFA2Nkw2NEw3NU02Nks2NEw3NUw3NUxcW22OjZq0s7za2d3m5uj////NzNKop7E3NUw3N0s3NU1paHjy8vTm5uk3NUyCgY83NUvl5ehQTmI3NUxEQlenp7CnprA4NEw1NUtcWm7x8fP+/v41NUpAMECmpbA2Nkw2NUxpZ3nMy9GCgI/a2t42NUtdW243NUo2M0xcWm01Mk2PjZo3NEyzsrw3Nks2NUzY2Nw2NUvMzNG0s7s3M0w3NEo4OEg3NUs3NU04NEw4NkswMFCnp7GnprFDQlc5NEs3NEw3NEs2NUvNzdI3NEza2t04NUpAQEA2NUw3NUw2NE02NExc4EV1AAAAY3RSTlMAIGCQr8/f/4BQIEDfn0AQf+/eX+5vv///////////7nCP/////v+e//++////f47///9gEP+A7/////+g/49Q/2D/r/+vz//O//+QTyDenoBfEP///3C/cJ//vv9gEKCQr89JTxAdAAACbklEQVR4AezZA7YlQQwG4Dx17lybebZt27b3v4uZ6s7pa4yTc963gcJfSaOgmqbmltY2CwWw2lo937zwU3wtFgrjDwShQaFwBEWKxrxqp8/i4bpLSMidPqcAtXiTKF7U2+D2p9KZbI4EyLV3pFOY19kFVXSjq6ejl0Tpy+TX0B+GigL56beTQNkBZDgIFbQJnj4bGkY2Un3/R8dIsPHRahlMoGOY61Z8CJMl/QcdU70k3PQUV3IXFPBy/xwgBbiWO72Q5+f9Jw1mpsoKeZbPfy+pMD1ccoi8TgCjOVJiaBSNzrniJ/AYqTGPtgUOYBGNFOkxs8QRFFZAjhRZ5ggKWtAKkcII4Acf2laJ9EXQHwSANTTWiTRGsOGeoAwpM45GFMCrrYTZNBr9TbCp7QSxmS17AdvgQSNN6uxwEezyU1idPTT24QCNdlLnEI0jsNTVMBviNoQ20mcGjf6vBfyurwWoL+IDde+i7Jjb6C4aJ6TOOD/ITnW/SnigWffL3Bmco61XZw33nwO3oTGd73IXAFwESypPEF7mP+rb9b2L8kc9LGqMYIBPkHGlMAIu4WswbvRFMDOMRuc5FEZwS2rc5f8sFkRwr+33+sU5sAedFxzX4HrUeMV0AXnni2hbUXTJFz+HAg/6rlmfoMiptovuBSixho570d20YxQdz1DmANm62BBelpC9AivJgK28SZ1+lf1nV+iaygiLobdjCV0bUMXDIuZNpTteRKwi95ZJT2Fe/AmqOrdQvNdzqOVd+BJqbD87P42gWJGrD6jvnFNQOX3m+xS3Buv7ErgZSAK+9hyJSYNj+X1SYgITIy53AgCT+DcB0RKo5AAAAABJRU5ErkJggg==")

        local avatarsRoot = "/assets/models/avatars"
        for _, avatarName in ipairs(lovr.filesystem.getDirectoryItems(avatarsRoot)) do
            for _, partName in ipairs({"head", "left-hand", "right-hand", "torso"}) do
                local path = avatarsRoot.."/"..avatarName.."/"..partName..".glb"
                if lovr.filesystem.isFile(path) then 
                    local asset = ui.Asset.LovrFile(avatarsRoot.."/"..avatarName.."/"..partName..".glb", true)
                    local assetName = "avatars/"..avatarName.."/"..partName
                    assert(asset)
                    AlloAvatar.assets[assetName] = asset
                else
                    print(path .. " is not an avatar file")
                end
            end
        end
    end
    return AlloAvatar.assets
end


function AlloAvatar:_init(bounds, displayName, avatarName, net, isCamera)
    self:super(bounds)
    self.displayName = displayName
    self.avatarName = avatarName
    self.net = net
    if not isCamera then
        self.leftHand = self:addSubview(AlloBodyPart(nil, avatarName, "hand/left", "left-hand"))
        self.rightHand = self:addSubview(AlloBodyPart(nil, avatarName, "hand/right", "right-hand"))
        self.torso = self:addSubview(AlloBodyPart(nil, avatarName, "torso", "torso"))
        self.torso.displayName = displayName
        self.watchHud = self.leftHand:addSubview(self:makeWatchHud())
    end
    self.head = self:addSubview(AlloBodyPart(nil, avatarName, "head", "head"))
end

function AlloAvatar:sleep()

end

function AlloAvatar:specification()
    local spec = tablex.union(View.specification(self), {
        visor = {
          display_name = self.displayName,
        },
    })
    if self.useClientAuthoritativePositioning then
        spec.intent = {
          actuate_pose = "root"
        }
    end
    return spec
end

function AlloAvatar:makeWatchHud()
    local hudRoot = ui.View(
        ui.Bounds(-0.09, 0.00, 0.04,   0.00, 0.00, 0.00):rotate(-3.14/2, 0,-1,0)
    )

    local muteButton = hudRoot:addSubview(self:makeMuteButton())
    
    return hudRoot
end

function AlloAvatar:makeMuteButton()
    local muteButton = ui.Button(
        ui.Bounds(0, 0.00, 0.00,   0.03, 0.02, 0.010)
    )
    muteButton.label.fitToWidth = true
    muteButton.onActivated = function()
        local soundEng = self.net.engines.sound
        soundEng:setMuted(not soundEng.isMuted)
    end

    local volumeLabel = ui.Label(
        ui.Bounds(0,0,0,   0.03, 0.005, 0.010)
        :scale(1, 2, 1)
            :rotate(-3.14/2, 1,0,0)
            :move(0, 0.003, 0.01)
            
    )
    muteButton:addSubview(volumeLabel)

    function updateLooks()
        if not self.micStatus or self.micStatus.status == "pending" then
            muteButton:setColor({0.7, 0.7, 0.9, 1.0})
            muteButton.label:setText("Starting mic...")
        elseif self.micStatus.status == "failed" then
            muteButton:setColor({0.9, 0.5, 0.5, 1.0})
            muteButton.label:setText("Mic is broken")
        elseif self.micStatus.name == "Off" or self.isMuted == true then
            muteButton:setColor({0.9, 0.7, 0.7, 1.0})
            muteButton.label:setText("Mic off")
        else
            muteButton:setColor({0.7, 0.9, 0.7, 1.0})
            muteButton.label:setText("Mic on")
        end
    end

    self.unsub1 = Store.singleton():listen("currentMic", function(micStatus)
        self.micStatus = micStatus
        updateLooks()
    end)
    self.unsub2 = Store.singleton():listen("micMuted", function(isMuted)
        self.isMuted = isMuted
        updateLooks()
    end)
    self.unsub3 = Store.singleton():listen("micVolume", function(micVolume)
        if micVolume == nil then micVolume = "--" end
        volumeLabel:setText(micVolume)
    end)

    return muteButton
end

function AlloAvatar:onInteraction(inter, body, sender)
    if body[1] == "add_wrist_widget" then
        local widget_eid = body[2]
        print("Got request to add widget eid", widget_eid)
        self.app.client:getEntity(widget_eid, function(widget)
            self:addWristWidget(widget, inter)
        end)
    else
        View.onInteraction(self, inter, body, sender)
    end
end

-- @param entity Entity to add to the wrist
-- @param inter Interaction to reply to, or nil if none
function AlloAvatar:addWristWidget(widgetEntity, inter)
    local hud = self.watchHud
    local otherWidgets = self.watchHud.entity.children
    -- todo: find the leftmost widget, not the "last" widget (the list isn't sorted)
    local lastWidget = otherWidgets[#otherWidgets]
    local lastPos = mat4.new(lastWidget.components.transform.matrix)
    local newPos = mat4.translate(mat4.new(), lastPos, vec3.new(-0.03, 0, 0))
    newPos._m = nil -- so that it becomes a normal array that can be passed as json
    local changes = {
        relationships= {
            parent= hud.entity.id
        },
        transform= {
            matrix= newPos
        }
    }
    self.app.client:sendInteraction({
        sender_entity_id = self.entity.id,
        receiver_entity_id = "place",
        body = {
            "change_components",
            widgetEntity.id,
            "add_or_change", changes,
            "remove", {}
        }
    }, function(resp, body)
        if body[2] == "ok" then
            print("Added wrist widget", widgetEntity.id, "from", inter.sender_entity_id)
            inter:respond({"add_wrist_widget", "ok"})
        else
            print("FAILED to add wrist widget", widgetEntity.id, "from", inter.sender_entity_id, ":", pretty.write(body))
            inter:respond({"add_wrist_widget", "failed"})
        end
    end)
end

class.AlloBodyPart(ui.View)
function AlloBodyPart:_init(bounds, avatarName, poseName, partName)
    self:super(bounds)
    self.avatarName = avatarName
    self.poseName = poseName
    self.partName = partName
end

function AlloBodyPart:specification()
    local spec = tablex.union(View.specification(self), {
        intent = {
            actuate_pose = self.poseName
        },
        children = {
            {
                geometry = {
                    type = "asset",
                    name = AlloAvatar.assets["avatars/"..self.avatarName.."/"..self.partName]:id()
                },
                transform = {
                    matrix = {lovr.math.mat4(0,0,0, 3.14, 0, 1, 0):unpack(true)},
                },
            },
        },
    })
    
    if self.partName == "torso" then
        table.insert(spec.children, self:nameTagSpec())
    end
    return spec
end

-- todo: make it regular alloui
function AlloBodyPart:nameTagSpec()
    return {
        geometry = {
            type = "inline",
            vertices=   {{-0.1, -0.033, 0.0},  {0.1, -0.033, 0.0},  {-0.1, 0.033, 0.0}, {0.1, 0.033, 0.0}},
            uvs=        {{0.0, 0.0},          {1.0, 0.0},         {0.0, 1.0},        {1.0, 1.0}},
            triangles=  {{0, 1, 3},           {0, 3, 2},          {1, 0, 2},         {1, 2, 3}},
        },
        material = {
            texture = AlloAvatar.assets.nameTag:id(),
            hasTransparency = true
        },
        transform = {
            matrix={
                lovr.math.mat4():rotate(3.14, 0, 1, 0):translate(0, 0.3, 0.062):rotate(-3.14/8, 1, 0, 0):unpack(true)
            }
        },
        children = {
            {
                text = {
                    string = self.displayName,
                    height = 0.66,
                    halign = "center",
                    width = 0.16,
                    fitToWidth = true
                },
                material = {
                    color = {0.21484375,0.20703125,0.30078125,1}
                }
            }
        }
    }
end


return AlloAvatar
