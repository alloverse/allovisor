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
  if poparg("--desktop") then
    t.headset.drivers = {"desktop"}
  end
end
