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
    print("awaiting")
    local cmd = json.decode(inChan:pop(true))
    print(pretty.write(cmd))
    if cmd.register then
        outChans[cmd.register.requests] = lovr.thread.getChannel(cmd.register.requests)
        pubChans[cmd.register.pubs] = lovr.thread.getChannel(cmd.register.pubs)
        outChans[cmd.register.requests]:push("ok", true)
    elseif cmd.quit then
        running = false
    elseif cmd.save then
        if not storage[cmd.save.key] then
            storage[cmd.save.key] = cmd.save
        else
            storage[cmd.save.key].value = cmd.save.value
            storage[cmd.save.key].persistent = cmd.save.persistent
        end
        outChans[cmd.from]:push("ok", true)
        -- todo: send to listeners
    elseif cmd.request then
        local found = storage[cmd.request]
        if not found then
            outChans[cmd.from]:push(nil, true)
        else
            outChans[cmd.from]:push(json.encode(found.value), true)
        end
    elseif cmd.listen then
        if not storage[cmd.listen] then
            storage[cmd.listen] = {}
        end
        if not storage[cmd.listen].subs then
            storage[cmd.listen].subs = {}
        end
        local chan = pubChans[cmd.from]
        local found = false
        for _, v in ipairs(storage[cmd.listen].subs) do
            if v == chan then found = true end
        end
        if not found then
            table.insert(storage[cmd.listen].subs, chan)
        end
        -- todo: send initial value
    end
end
print("Exiting store thread.")
