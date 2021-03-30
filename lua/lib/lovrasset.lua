local class = require('pl.class')
local Asset = require ('alloui.asset.asset')

--- An Asset that loads from Lovr Filesystem
LovrAsset = class.LovrAsset(Asset)

function LovrAsset:_init(path, load)
    self._path = path
    assert(lovr.filesystem.isFile(path))
    self.data, self._size = lovr.filesystem.read(path)
end
function LovrAsset:path()
    return self._path
end

function LovrAsset:size()
    return self._size
end

-- callback: function(data)
function LovrAsset:read(offset, length)
    return self.data:sub(offset, offset + length)
end


return LovrAsset
