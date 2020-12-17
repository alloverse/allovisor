--- The Allovisor Assets engine.
-- @classmod AssetsEngine

namespace("networkscene", "alloverse")

local AssetsEng = classNamed("AssetsEng", Ent)

function AssetsEng:_init()
    self:super()
end

function AssetsEng:onLoad()
    -- setup the asset tracking
end

function AssetsEng:onDraw()
    -- optionally draw debug info
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


