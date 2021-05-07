lovr.data = require("lovr.data")

function tablefind(tab,el)
    for index, value in pairs(tab) do
        if value == el then
            return index
        end
    end
    return -1
end

function poparg(needle)
  local argn = #arg
  for j=1, argn do
    if arg[j] == needle then
      for i=j,argn do
        arg[i] = arg[i+1]
      end
      return true
    end
  end
  return false
end

function lovr.conf(t)
  -- Pass --desktop at startup (after asset path) to force desktop/fake driver
  if arg and (poparg("--disablevr") or poparg("--desktop")) then
    t.headset.drivers = {}
    t.modules.headset = false
  else
    local desktopi = tablefind(t.headset.drivers, "desktop")
    table.remove(t.headset.drivers, desktopi)
  end

  t.identity = "alloverse"

  t.window.title = "Alloverse"
  t.window.width = 3008/2
  t.window.height = 1692/2
  t.window.fullscreen = false
  
  t.math.globals = true

  if lovr.getOS() ~= "macOS" then -- osx windows don't have icons
    t.window.icon = lovr.data.newTextureData("assets/alloverse-logo.png", false)    
  end
end
