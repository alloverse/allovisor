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

local running = true
while running do
    local cmd = json.decode(inChan:pop(true))
    if cmd.register then
        outChans[cmd.register.requests] = lovr.thread.getChannel(cmd.register.requests)
        pubChans[cmd.register.pubs] = lovr.thread.getChannel(cmd.register.pubs)
        outChans[cmd.register.requests]:push("ok", true)
    elseif cmd.quit then
        running = false
    elseif cmd.save then
        if not storage[cmd.save.key] then
            storage[cmd.save.key] = cmd.save
            storage[cmd.save.key].subs = {}
        else
            storage[cmd.save.key].value = cmd.save.value
            storage[cmd.save.key].persistent = cmd.save.persistent
        end
        outChans[cmd.from]:push("ok", true)
        for _, chan in ipairs(storage[cmd.save.key].subs) do
            chan:push(json.encode({key=cmd.save.key, value=storage[cmd.save.key].value}))
        end
    elseif cmd.request then
        local found = storage[cmd.request]
        if not found then
            outChans[cmd.from]:push(nil, true)
        else
            outChans[cmd.from]:push(json.encode(found.value), true)
        end
    elseif cmd.listen then
        if not storage[cmd.listen] then
            storage[cmd.listen] = {subs={}}
        end
        local chan = pubChans[cmd.pubFrom]
        local found = false
        for _, v in ipairs(storage[cmd.listen].subs) do
            if v == chan then 
                found = true
                break
            end
        end
        if not found then
            table.insert(storage[cmd.listen].subs, chan)
        end

        outChans[cmd.reqFrom]:push("ok", true)

        
        chan:push(json.encode({key=cmd.listen, value=storage[cmd.listen].value}))
    elseif cmd.unlisten then
        local chan = pubChans[cmd.pubFrom]
        local subIndex = nil
        for i, v in ipairs(storage[cmd.unlisten].subs) do
            if v == chan then 
                subIndex = i
                break
             end
        end
        assert(subIndex)
        table.remove(storage[cmd.unlisten].subs, subIndex)
    end
end
print("Exiting store thread.")
