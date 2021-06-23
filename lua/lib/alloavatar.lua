local ui = require("alloui.ui")
local class = require("pl.class")
class.AlloAvatar(ui.View)

AlloAvatar.assets = {
}

function AlloAvatar.loadAssets()
    if AlloAvatar.assets.nameTag == nil then
        AlloAvatar.assets.nameTag = Asset.Base64("iVBORw0KGgoAAAANSUhEUgAAAMAAAABACAMAAAB7sojtAAABKVBMVEUAAAA4OFA1Mko3NUo3Nkw3NUw3NUs3NUw2NEw2M0k4MFA4NEw3NU03NUs0NExAMFA2Nkw2NEw3NU02Nks2NEw3NUw3NUxcW22OjZq0s7za2d3m5uj////NzNKop7E3NUw3N0s3NU1paHjy8vTm5uk3NUyCgY83NUvl5ehQTmI3NUxEQlenp7CnprA4NEw1NUtcWm7x8fP+/v41NUpAMECmpbA2Nkw2NUxpZ3nMy9GCgI/a2t42NUtdW243NUo2M0xcWm01Mk2PjZo3NEyzsrw3Nks2NUzY2Nw2NUvMzNG0s7s3M0w3NEo4OEg3NUs3NU04NEw4NkswMFCnp7GnprFDQlc5NEs3NEw3NEs2NUvNzdI3NEza2t04NUpAQEA2NUw3NUw2NE02NExc4EV1AAAAY3RSTlMAIGCQr8/f/4BQIEDfn0AQf+/eX+5vv///////////7nCP/////v+e//++////f47///9gEP+A7/////+g/49Q/2D/r/+vz//O//+QTyDenoBfEP///3C/cJ//vv9gEKCQr89JTxAdAAACbklEQVR4AezZA7YlQQwG4Dx17lybebZt27b3v4uZ6s7pa4yTc963gcJfSaOgmqbmltY2CwWw2lo937zwU3wtFgrjDwShQaFwBEWKxrxqp8/i4bpLSMidPqcAtXiTKF7U2+D2p9KZbI4EyLV3pFOY19kFVXSjq6ejl0Tpy+TX0B+GigL56beTQNkBZDgIFbQJnj4bGkY2Un3/R8dIsPHRahlMoGOY61Z8CJMl/QcdU70k3PQUV3IXFPBy/xwgBbiWO72Q5+f9Jw1mpsoKeZbPfy+pMD1ccoi8TgCjOVJiaBSNzrniJ/AYqTGPtgUOYBGNFOkxs8QRFFZAjhRZ5ggKWtAKkcII4Acf2laJ9EXQHwSANTTWiTRGsOGeoAwpM45GFMCrrYTZNBr9TbCp7QSxmS17AdvgQSNN6uxwEezyU1idPTT24QCNdlLnEI0jsNTVMBviNoQ20mcGjf6vBfyurwWoL+IDde+i7Jjb6C4aJ6TOOD/ITnW/SnigWffL3Bmco61XZw33nwO3oTGd73IXAFwESypPEF7mP+rb9b2L8kc9LGqMYIBPkHGlMAIu4WswbvRFMDOMRuc5FEZwS2rc5f8sFkRwr+33+sU5sAedFxzX4HrUeMV0AXnni2hbUXTJFz+HAg/6rlmfoMiptovuBSixho570d20YxQdz1DmANm62BBelpC9AivJgK28SZ1+lf1nV+iaygiLobdjCV0bUMXDIuZNpTteRKwi95ZJT2Fe/AmqOrdQvNdzqOVd+BJqbD87P42gWJGrD6jvnFNQOX3m+xS3Buv7ErgZSAK+9hyJSYNj+X1SYgITIy53AgCT+DcB0RKo5AAAAABJRU5ErkJggg==")

        local avatarsRoot = "/assets/models/avatars"
        for _, avatarName in ipairs(lovr.filesystem.getDirectoryItems(avatarsRoot)) do
            for _, partName in ipairs({"head", "left-hand", "right-hand", "torso"}) do
                local path = avatarsRoot.."/"..avatarName.."/"..partName..".glb"
                if lovr.filesystem.isFile(path) then 
                    local asset = Asset.LovrFile(avatarsRoot.."/"..avatarName.."/"..partName..".glb", true)
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


function AlloAvatar:_init(bounds)
    self.displayName = ""
    self.avatarName = ""
end


function AlloAvatar:specification()
    local torso = self:bodyPartSpec("torso", "torso")
    table.insert(torso.children, self:nameTagSpec())

    local spec = {
        visor = {
          display_name = self.displayName,
        },
        children = {
            self:bodyPartSpec("hand/left", "left-hand"),
            self:bodyPartSpec("hand/right", "right-hand"),
            self:bodyPartSpec("head", "head"),
            torso
        }
    }

    if lovr.headset == nil or lovr.headset.getDriver() == "desktop" then
        table.remove(spec.children, 2) -- remove right hand as it can't be simulated
    end
    
    return spec
end

function AlloAvatar:bodyPartSpec(poseName, partName)
    return {
        intent = {
            actuate_pose = poseName
        },
        children = {
            {
                geometry = {
                    type = "asset",
                    name = AlloAvatar.assets["avatars/"..self.avatarName.."/"..partName]:id()
                },
                transform = {
                    matrix = {lovr.math.mat4(0,0,0, 3.14, 0, 1, 0):unpack(true)},
                },
            },
        },
    }
end

function AlloAvatar:nameTagSpec()
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