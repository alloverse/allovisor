namespace = require "engine.namespace"
namespace "standard"

local stringx = require("pl.stringx")

function load_allonet()
  -- load allonet from dll
  local os = lovr.getOS()    
  local err = nil
  local pkg = nil
  if os == "Windows" then
    -- already loaded into runtime
    -- except on new threads
    if allonet == nil then
      local exepath = lovr.filesystem.getExecutablePath()
      local dllpath = string.gsub(exepath, "%w+.exe", "allonet.dll")
      print("loading liballonet from "..dllpath.."...")
      pkg, err = package.loadlib(dllpath, "luaopen_liballonet")
      if pkg == nil then
        error("Failed to load allonet: "..err)
      end
      allonet = pkg()
    end
  elseif os == "macOS" then
    print("loading liballonet from exe...")
    pkg, err = package.loadlib(lovr.filesystem.getExecutablePath(), "luaopen_liballonet")
    if pkg == nil then
      error("Failed to load allonet: "..err)
    end
    allonet = pkg()
  elseif os == "Android" then
    print("loading liballonet from liblovr.so...")
    pkg, err = package.loadlib("liblovr.so", "luaopen_liballonet")
    if pkg == nil then
      error("Failed to load allonet: "..err)
    end
    allonet = pkg()
  elseif os == "Linux" then
    -- already loaded into runtime
    -- except on new threads
    if allonet == nil then
      local exepath = lovr.filesystem.getExecutablePath()
      local dllpath = string.gsub(exepath, "Alloverse", "deps/allonet/liballonet.so")
      print("loading liballonet from "..dllpath.."...")
      pkg, err = package.loadlib(dllpath, "luaopen_liballonet")
      if pkg == nil then
        error("Failed to load allonet: "..err)
      end
      allonet = pkg()
    end
  else
    error("don't know how to load allonet")
  end
  print("allonet loaded", allonet)
  return allonet
end

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
function optchainf(obj, path, ...)
  local f, self = optchain(obj, path)
  if f then
    f(self, ...)
  end
end

function table:remove_value(value)
  local idx = tablex.find(self, value)
  if idx ~= -1 then
    return table.remove(self, idx)
  end
  return nil
end

return {
  load_allonet = load_allonet
}