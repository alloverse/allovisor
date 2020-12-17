local charset = {}

-- qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM1234567890
for i = 48,  57 do table.insert(charset, string.char(i)) end
for i = 65,  90 do table.insert(charset, string.char(i)) end
for i = 97, 122 do table.insert(charset, string.char(i)) end

string.random = require("alloui.random_string")

function string.has_suffix(s, suffix)
  return s:sub(-string.len(suffix)) == suffix
end


return {
  random = string.random,
  has_suffix = string.has_suffix
}