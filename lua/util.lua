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

return {
  load_allonet = load_allonet
}