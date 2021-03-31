--- Handles asset importing via the desktop visor
-- @classmod AssetsEngine

namespace("networkscene", "alloverse")

local AssetsEng = classNamed("AssetsEng", Ent)
local Asset = require('lib.alloui.lua.alloui.asset')
local tablex = require "pl.tablex"

function AssetsEng:_init()
    self:super()
    self.droppedPaths = nil
end

function AssetsEng:onFileDrop(path)
    print(self, "got a file drop:", path)

    local function acceptsFile(entity)
        if entity.components.acceptsfile then
            if entity.components.acceptsfile.extensions then
                local _, _, ext = path:find("([^.]+)$")
                if tablex.find(entity.components.acceptsfile.extensions, ext) == nil then 
                    print("Targeted entity did not accept file type " .. ext)
                    return false;
                end
                return true
            end
            return true
        end
        print("Targeted entity did not accept files")
        return false
    end

    if lovr.scenes.net then
        local entity, ray = self.parent.engines.pose:highlightedEntity()
        if entity and ray and acceptsFile(entity) then

            local asset = Asset.File(path)
            local _, _, filename = string.find(path, "([^/\\]+)$")

            self.parent.engines.graphics.assetManager:add(asset, true)
            -- Send interaction to hilighted entity
            
            self.client:sendInteraction({
                type = "request",
                sender = ray.handEntity,
                receiver_entity_id = entity.id,
                body = {"accept-file", filename or "???", asset:id()}
            })
        else
            print("Did not hit anything that accepts files")
        end
    else
        -- Tool to preview models when not connected to a place.
        -- If multiple files are dropped this method is called for each path
        -- in one frame, so we collect them all here
        self.droppedPaths = self.droppedPaths or {}
        table.insert(self.droppedPaths, path)
    end
end

function AssetsEng:onUpdate(dt)
    if self.droppedPaths and not lovr.scenes.net then
        -- If any files were dropped in 'not connected yet' mode then load them in as test files
        self.parent.engines.graphics.testModels = {}
        for _, path in ipairs(self.droppedPaths) do
            self.parent.engines.graphics:modelFromAsset(Asset.File(path), function (model)
                table.insert(self.parent.engines.graphics.testModels, model)
            end)
        end
        self.droppedPaths = nil
    end
end

return AssetsEng
