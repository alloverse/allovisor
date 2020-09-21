local allomath = {}

function allomath.sign(number)
    return number > 0 and 1 or (number == 0 and 0 or -1)
end

function allomath.mat4_to_string(m)
  local a = {m:unpack(true)}
  local s = string.format("{ %+2.2f %+2.2f %+2.2f %+2.2f\n", a[1], a[5], a[9],  a[13])
  s  = s .. string.format("  %+2.2f %+2.2f %+2.2f %+2.2f\n", a[2], a[6], a[10], a[14])
  s  = s .. string.format("  %+2.2f %+2.2f %+2.2f %+2.2f\n", a[3], a[7], a[11], a[15])
  s  = s .. string.format("  %+2.2f %+2.2f %+2.2f %+2.2f }", a[4], a[8], a[12], a[16])
  return s
end

return allomath