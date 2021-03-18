--- The Allovisor Assets engine.
-- @classmod AssetsEngine

namespace("networkscene", "alloverse")

local AssetsEng = classNamed("AssetsEng", Ent)
local Asset = require('lib.alloui.lua.alloui.asset')

function AssetsEng:_init()
    self:super()
    self.droppedModel = nil
    self.droppedAsset = nil

    
end

function AssetsEng:onFileDrop(path)
    print("Got a file drop:", path, self.client, self.client.connected)

    if not self.client or not self.client.connected or self.parent.isOverlayScene then
        self.droppedAsset = Asset.File(path, true)
        self.parent.engines.graphics.assetManager:add(self.droppedAsset)
        self.parent.engines.graphics:modelFromAsset(self.droppedAsset, function (model)
            self.droppedModel = model
        end)
    else
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
    end
end

function AssetsEng:onLoad()
    -- setup the asset tracking
    print("GRAPH", self.parent.engines.graphics)
end

function AssetsEng:onDraw()
    -- optionally draw debug info
    if not self.client or not self.client.connected and self.droppedModel then
        self.droppedModel:draw()
    end
end

function AssetsEng:onMirror()
    -- optionally draw debug info
end

function AssetsEng:onUpdate(dt)

end

function AssetsEng:onComponentAdded(compnent_key, component)
    -- scan component for assets
end

function AssetsEng:onComponentChanged(component_key, component, old_component)
    -- scan component for new assets, and old_component for assets no longer in use
end

function AssetsEng:onComponentRemoved(component_key, component)
    -- Scan component for assets and check if they should be unloaded?
end

return AssetsEng
