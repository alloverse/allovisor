local stringx = require("pl.stringx")
lovr.system = require("lovr.system")

function isDesktop()
  local os = lovr.system.getOS()
  return os == "macOS" or os == "Windows" or os == "Linux"
end

-- Return thing at path from obj, or nil if any part in path is nil
-- e g optchain(foo, "bar.baz.qyp") returns qyp only if bar is non-nil and bar.baz is non-nil
function optchain(obj, path)
  local prevObj = nil
  local parts = stringx.split(path, ".")
  for _, part in ipairs(parts) do
    if not obj then return nil end
    prevObj = obj
    obj = obj[part]
  end
  return obj, prevObj
end

-- Call function at path with vargs if the whole chain in path is non-nil
function optchainf(obj, path, ...)
  local f = optchain(obj, path)
  if f then
    f(...)
  end
end

-- Call a method at path with self and vargs if the whole chain in path is non-nil
function optchainm(obj, path, ...)
  local f, self = optchain(obj, path)
  if f then
    f(self, ...)
  end
end

function default(thing, fallback)
  return thing and thing or fallback
end

local tabley={}

function tabley:remove_value(value)
  local idx = tablex.find(self, value)
  if idx ~= -1 then
    return table.remove(self, idx)
  end
  return nil
end

function tabley:first(pred)
  for k, v in pairs(self) do
    if pred(k, v) == true then return k, v end
  end
  return nil
end


--- Decodes a base64 string
-- @tparam string data A string of base64 encoded data
-- @treturn string The decoded data
function base64decode(data)
  local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/' -- You will need this for encoding/decoding
  data = string.gsub(data, '[^'..b..'=]', '')
  return (data:gsub('.', function(x)
      if (x == '=') then return '' end
      local r,f='',(b:find(x)-1)
      for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
      return r;
  end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
      if (#x ~= 8) then return '' end
      local c=0
      for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
          return string.char(c)
  end))
end

return {
  isDesktop = isDesktop,
  tabley=tabley,
  base64decode=base64decode
}
