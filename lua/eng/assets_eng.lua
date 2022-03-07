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
    self.droppedModels = {}

    self.loaders = {} -- "type-assetid":{callback}
    self.cache = setmetatable({}, {__mode = 'v'})--assetid:lovrTypes
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
-- * "model"
-- * "texture" - Produces an Image
-- * "sound"
-- returns true if asynchronous loading started, or false if 
-- object was already loaded and callback called immediately
-- @tparam bool flipTexture If type is 'texture' this specifies that the Image should be returned flipped
function AssetsEng:loadFromAsset(asset, type, callback, flipTexture)
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
            for _, cb in ipairs(asset._lovrObjectLoadingCallbacks) do
                cb(object)
            end
        end
        asset._lovrObjectLoadingCallbacks = nil
      end,
      blob,
      flipTexture
    )
end

function AssetsEng:onFileDrop(path)
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

            self.assetManager:add(asset, true)
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
        self.droppedModels = {}
        for _, path in ipairs(self.droppedPaths) do
            self:loadModel(Asset.File(path), function (model)
                table.insert(self.droppedModels, model)
            end)
        end
        self.droppedPaths = nil
    end
end

function AssetsEng:loadSoundEffect(asset_id, callback)
    assert(string.match(asset_id, "asset:"), "not an asset id")

    return self:getOrLoadResource("sound", asset_id, callback, function (asset, complete)
        if not asset then return complete(nil) end
        self:loadFromAsset(asset, "sound", function (soundData)
            complete(soundData and lovr.audio.newSource(soundData))
        end)
    end)
end

function AssetsEng:loadImage(asset_id, callback, flipped)
    assert(string.match(asset_id, "asset:"), "not an asset id")

    return self:getOrLoadResource("image", asset_id, callback, function(asset, complete)
        if not asset then return complete(nil) end
        self:loadFromAsset(asset, "image", function (image)
            complete(image)
        end, flipped)
    end)
end

function AssetsEng:loadTexture(asset_id, callback)
    assert(string.match(asset_id, "asset:"), "not an asset id")

    return self:getOrLoadResource("texture", asset_id, callback, function (asset, complete)
        if not asset then return complete(nil) end
        self:loadFromAsset(asset, "texture", function (image)
            complete(image and lovr.graphics.newTexture(image))
        end)
    end)
end

function AssetsEng:loadModel(asset_id, callback)
    assert(string.match(asset_id, "asset:"), "not an asset id")

    return self:getOrLoadResource("model", asset_id, callback, function (asset, complete)
        if not asset then return complete(nil) end
        self:loadFromAsset(asset, "model", function (modelData)
            complete(modelData and lovr.graphics.newModel(modelData))
        end)
    end)
end

function AssetsEng:loadCustomModel(geometry_asset, callback)
    -- Add to manager if needed
    local asset = self.assetManager:get(geometry_asset:id())
    if not asset then 
        asset = geometry_asset
        self.assetManager:add(asset)
    end

    -- load it
    return self:loadModel(asset:id(), callback)
end


function AssetsEng:getOrLoadResource(type, asset_id, callback, map)
    local key = type .. '-' .. asset_id
    -- If there's a cached object for asset_id then return it immediately
    local object = self.cache[key]
    if object then 
        callback(object)
        return object
    end
    
    -- If the asset is already loading then wait for it
    local callbacks = self.loaders[key]
    if callbacks then 
        table.insert(callbacks, callback)
        return nil
    end

    -- Start loading
    self.loaders[key] = {callback}
    -- Load the asset
    self:getAsset(asset_id, function (asset)
        -- map to object
        map(asset, function (object)
            -- store in cache
            self.cache[key] = object
            -- clear the callbacks
            local callbacks = self.loaders[key]
            self.loaders[key] = nil
            -- call the callbaks
            for i,callback in ipairs(callbacks) do
                callback(object)
            end
        end)
    end)
    return nil
end

return AssetsEng
