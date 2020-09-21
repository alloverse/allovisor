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
  if poparg("--disablevr") then
    t.headset.drivers = {}
    t.modules.headset = false
  else
    local desktopi = tablefind(t.headset.drivers, "desktop")
    table.remove(t.headset.drivers, desktopi)
  end
end
