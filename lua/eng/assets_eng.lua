--- Handles asset importing via the desktop visor
-- @classmod AssetsEngine

namespace("networkscene", "alloverse")

local AssetsEng = classNamed("AssetsEng", Ent)
local Asset = require('lib.alloui.lua.alloui.asset')

function AssetsEng:_init()
    self:super()
    self.droppedPaths = nil
end

function AssetsEng:onFileDrop(path)
    print("Got a file drop:", path)

    if lovr.scenes.net then
        local entity, ray = self.parent.engines.pose:highlightedEntity()
        if entity and ray then
            local asset = Asset.File(path, true)
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
        -- Tool to preview models. 
        -- If multiple files are dropped this method is called for each path
        -- in one frame, so we collect them all here
        self.droppedPaths = self.droppedPaths or {}
        table.insert(self.droppedPaths, path)
    end
end

function AssetsEng:onUpdate(dt)
    if self.droppedPaths then 
        -- If any files were dropped in 'not connected yet' mode then load them in as test files
        self.parent.engines.graphics.testModels = {}
        for _, path in ipairs(self.droppedPaths) do
            self.parent.engines.graphics:modelFromAsset(Asset.File(path, true), function (model)
                table.insert(self.parent.engines.graphics.testModels, model)
            end)
        end
        self.droppedPaths = nil
    end
end

return AssetsEng
