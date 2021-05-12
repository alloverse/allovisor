print("Booting store thread")
lovr = require 'lovr'
lovr.filesystem = require 'lovr.filesystem'
lovr.thread = require 'lovr.thread'
lovr.data = require 'lovr.data'
local util = require("lib.util")
local pretty = require("pl.pretty")
local json = require("alloui.json")

local outChans = {}
local pubChans = {}
local inChan = lovr.thread.getChannel("AlloStoreRequests")
local storage = {}
local defaults = {}
local path = "settings.json"

function saveStorage()
    local diskRep = {}
    for k, v in pairs(storage) do
        if v.persistent then
            diskRep[k] = v.value
        end
    end
    local written = lovr.filesystem.write(path, json.encode(diskRep))
end

function fetchValue(key)
  local found = storage[key]
  local value = nil
  if found then
    value = found.value
  else
    value = defaults[key]
  end
  return value
end

local diskS = lovr.filesystem.read(path, -1) 
diskRep = diskS and json.decode(diskS) or {}
for k, v in pairs(diskRep) do
    storage[k] = {
        value= v,
        persistent= true,
        subs= {}
    }

    print(k, v)
end

local running = true
while running do
    local cmd = json.decode(inChan:pop(true))
    if cmd.register then
        outChans[cmd.register.requests] = lovr.thread.getChannel(cmd.register.requests)
        pubChans[cmd.register.pubs] = lovr.thread.getChannel(cmd.register.pubs)
        outChans[cmd.register.requests]:push("ok", true)
    elseif cmd.quit then
        running = false
    elseif cmd.defaults then
        for k, v in pairs(cmd.defaults) do
            defaults[k] = v
        end
        outChans[cmd.from]:push("ok", true)
    elseif cmd.save then
        if not storage[cmd.save.key] then
            storage[cmd.save.key] = cmd.save
            storage[cmd.save.key].subs = {}
        else
            storage[cmd.save.key].value = cmd.save.value
            storage[cmd.save.key].persistent = cmd.save.persistent
        end
        if cmd.save.persistent then
            saveStorage()
        end
        outChans[cmd.from]:push("ok", true)
        
        for id, chan in pairs(storage[cmd.save.key].subs) do
            chan:push(json.encode({key=cmd.save.key, value=storage[cmd.save.key].value}))
        end
    elseif cmd.request then
        local value = fetchValue(cmd.request)
        if type(value) == "nil" then
            outChans[cmd.from]:push(nil, true)
        else
            outChans[cmd.from]:push(json.encode(value), true)
        end
    elseif cmd.listen then
        if not storage[cmd.listen] then
            storage[cmd.listen] = {subs={}}
        end
        local chan = pubChans[cmd.pubFrom]
        storage[cmd.listen].subs[cmd.subId] = chan
        outChans[cmd.reqFrom]:push("ok", true)
        
        chan:push(json.encode({
            key=cmd.listen, 
            value=fetchValue(cmd.listen)
        }))
    elseif cmd.unlisten then
        storage[cmd.unlisten].subs[cmd.subId] = nil
    end
end
print("Exiting store thread.")
