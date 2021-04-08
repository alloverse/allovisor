local json = require("alloui.json")
local util = require("lib.util")
local class = require("pl.class")
local pretty = require("pl.pretty")
string.random = require("alloui.random_string")

-- The Store lets you store key-value pairs in a thread-safe manner. These key-value
-- pairs may also be saved to disk ("persisted"); this is appropriate for app settings.
class.Store()

-- Always access the Store through its thread-local singleton. This makes sure
-- there is only one Store per thread, which is the maximum needed.
function Store.singleton()
    if not Store._instance then
        Store._instance = Store()
    end
    return Store._instance 
end

function Store:_init()
    self.id = string.random(16)
    self.outChan = lovr.thread.getChannel("AlloStoreRequests")
    self.chanId = "AlloStoreResponses-"..self.id
    self.pubId =  "AlloStorePublications-"..self.id
    self.inChan = lovr.thread.getChannel(self.chanId)
    self.pubChan = lovr.thread.getChannel(self.pubId)
    self.outChan:push(json.encode({
        register= {
            requests= self.chanId,
            pubs= self.pubId,
        }
    }))
    self.subs = {}
    local ok = self.inChan:pop(true)
    assert(ok == "ok")
end

-- Must only be called once. Shuts down the worker thread and disables Store on all threads.
function Store:shutdown()
    self.outChan:push(json.encode({quit=true}))
end

-- Set what the default values should be for the given key-pairs. If no value has been stored previously,
-- these default values will be returned instead.
function Store:registerDefaults(defs)
    self.outChan:push(json.encode({
        defaults= defs,
        from= self.chanId
    }))
    local ok = self.inChan:pop(true)
    assert(ok == "ok")
end

-- Save the value 'value' under 'key'. If 'persistent', also save to disk.
-- Note: value must only contain json-safe data types (table, string, number)
function Store:save(key, value, persistent)
    if persistent == nil then persistent = false end

    self.outChan:push(json.encode({
        save= {
            key= key,
            value= value,
            persistent= persistent,
        },
        from= self.chanId
    }))
    local ok = self.inChan:pop(true)
    assert(ok == "ok")
end

-- Load the value for 'key' in the Store.
-- returns value or nil
function Store:load(key)
    self.outChan:push(json.encode({
        request= key,
        from= self.chanId
    }))
    local value = self.inChan:pop(true)
    if value == nil then return nil end
    return json.decode(value)
end

-- Listen to changes in the value for 'key'. Callback is called with 'value' when it
-- changes, and also once immediately after listening (with nil, if no value is available).
function Store:listen(key, callback)
    local subId = string.random(16)
    self.outChan:push(json.encode({
        listen= key,
        pubFrom= self.pubId,
        reqFrom= self.chanId,
        subId= subId
    }))
    self.subs[subId] =  {
        key= key,
        callback= callback,
    }

    local ok = self.inChan:pop(true)
    assert(ok == "ok")
    return function()
        self.outChan:push(json.encode({
            unlisten= key,
            pubFrom= self.pubId,
            subId = subId,
        }))
        self.subs[subId] = nil
    end
end

-- Poll for changes to values. Call this regularly to make your 'listen' callbacks be called.
function Store:poll()
    local subEventS = self.pubChan:pop()
    while subEventS do
        local subEvent = json.decode(subEventS)
        for id, sub in pairs(self.subs) do
            if sub.key == subEvent.key then
                sub.callback(subEvent.value)
            end
        end
        subEventS = self.pubChan:pop()
    end
end

return Store
