--- Handles asset importing via the desktop visor
-- @classmod AssetsEngine

namespace("networkscene", "alloverse")

local AssetsEng = classNamed("AssetsEng", Ent)
local Asset = require('lib.alloui.lua.alloui.asset')
local tablex = require "pl.tablex"
local loader = require "lib.async-loader"

function AssetsEng:_init()
    self:super()
    self.droppedPaths = nil
end

function AssetsEng:onLoad()
    self.assetManager = self.parent.assetManager
    assert(self.assetManager)
end

-- callback(asset)
-- returns the asset if it was found in cache
function AssetsEng:getAsset(name, callback)
    assert(name, "name must not be nil")
    local cached = nil
    self.assetManager:load(name, function (name, asset)
        if asset == nil then 
            print("Asset " .. name .. " was not found on network")
        end
        cached = asset
        callback(asset)
    end)
    return cached
end


--- Loads asset data asynchronously. 
-- Supported types:
-- * "model-asset"
-- * "texture-asset"
-- * "sound-asset"
-- returns true if asynchronous loading started, or false if 
-- object was already loaded and callback called immediately
function AssetsEng:loadFromAsset(asset, type, callback)
    if asset._lovrObject then 
      callback(asset._lovrObject)
      return
    end
    if asset._lovrObjectLoadingCallbacks then
      table.insert(asset._lovrObjectLoadingCallbacks, callback)
      return
    end
    asset._lovrObjectLoadingCallbacks = {callback}
  
    local blob = lovr.data.newBlob(asset:read(), asset:id())
  
    loader:load(
      type,
      asset:id(),
      function(object, status)
        local model
        if object == nil or status == false then
          print("Failed to load " .. type, asset:id(), object)
        else
          asset._lovrObject = object
        end
        for _, cb in ipairs(asset._lovrObjectLoadingCallbacks) do
          cb(asset._lovrObject)
        end
        asset._lovrObjectLoadingCallbacks = nil
      end,
      blob
    )
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
