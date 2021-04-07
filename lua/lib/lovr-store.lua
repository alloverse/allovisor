local json = require("alloui.json")
local util = require("lib.util")
local class = require("pl.class")
string.random = require("alloui.random_string")

class.Store()

function Store.singleton()
    if not Store._instance then
        Store._instance = Store()
    end
    return Store._instance 
end

function Store:_init()
    print("main store init")
    self.id = string.random(16)
    self.outChan = lovr.thread.getChannel("AlloStoreRequests")
    self.chanId = "AlloStoreResponses-"..self.id
    self.pubId =  "AlloStorePublications-"..self.id
    self.inChan = lovr.thread.getChannel(self.chanId)
    self.pubChan = lovr.thread.getChannel(self.pubId)
    print("pushing register on", self.outChan)
    self.outChan:push(json.encode({
        register= {
            requests= self.chanId,
            pubs= self.pubId,
        }
    }))
    self.subs = {}
    print("main store", self.chanId)
    local ok = self.inChan:pop(true)
    assert(ok == "ok")
end

function Store:shutdown()
    self.outChan:push(json.encode({quit=true}))
end

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

function Store:listen(key, callback)
    self.outChan:push(json.encode({
        listen= key,
        from= self.pubId
    }))
    table.insert(self.subs, {
        key= key,
        callback= callback,
    })
    local ok = self.inChan:pop(true)
    assert(ok == true)
end

function Store:poll()
    local subEventS = self.pubChan:poll()
    while subEventS do
        local subEvent = json.decode(subEventS)
        for _, v in ipairs(self.subs) do
            if v.key == subEvent.key then
                v.callback(subEvent.value)
            end
        end
        subEventS = self.pubChan:poll()
    end
end

return Store
