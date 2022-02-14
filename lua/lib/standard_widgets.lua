namespace("networkscene", "alloverse")

local ui = require("alloui.ui")
local class = require("pl.class")
local tablex = require("pl.tablex")
local pretty = require("pl.pretty")
local vec3 = require("modules.vec3")
local mat4 = require("modules.mat4")
local Store = require("lib.lovr-store")

class.StandardWidgets(Ent)

function StandardWidgets:addAllWidgetsTo(avatar, netscene)
    self.widgetsToAdd = {self.addMuteWidget, self.addHelpWidget}
    self:_addNextWidget(avatar, netscene)
end

-- race condition setting positions if we add multiple widgets at once. add one at a time.
function StandardWidgets:_addNextWidget(avatar, netscene)
    local constructor = table.remove(self.widgetsToAdd, 1)
    if not constructor then return end
    constructor(self, avatar, netscene, function()
        self:_addNextWidget(avatar, netscene)
    end)
end

function StandardWidgets:_addWidget(avatar, netscene, view, cb)
    netscene.app:addRootView(view, function(view, ent)
        avatar:addWristWidget(ent, function(ok, errorOrMatrix)
            if not ok then 
                print("Failed to add standard widget:", errorOrMatrix)
            else
                view.bounds.pose.transform = mat4.new(errorOrMatrix)
                cb()
            end
        end)
    end)
end

function StandardWidgets:_pullUpDetails(widget, details)
    if details.superview then return end
    details.transform = mat4.scale(mat4.new(), mat4.new(), vec3.new(0,0,0))
    widget:addSubview(details)
    details:doWhenAwake(function()
        details:addPropertyAnimation(ui.PropertyAnimation{
            path= "transform.matrix",
            to= mat4.scale(mat4.new(), details.bounds.pose.transform, vec3.new(0,0,0)),
            from=   mat4.new(details.bounds.pose.transform),
            duration = 0.2,
            easing= "quadOut"
        })
    end)
end

function StandardWidgets:_pullDownDetails(widget, details)
    if not details.superview then return end
    details:addPropertyAnimation(ui.PropertyAnimation{
        path= "transform.matrix",
        from= mat4.scale(mat4.new(), details.bounds.pose.transform, vec3.new(0,0,0)),
        to=   mat4.new(details.bounds.pose.transform),
        duration = 0.2,
        easing= "quadIn"
    })
    details.app:scheduleAction(0.2, false, function() 
        if details.superview then
            details:removeFromSuperview()
        end
    end)
end

function StandardWidgets:addMuteWidget(avatar, netscene, cb)
    local soundEng = netscene.engines.sound
    
    local muteButton = ui.Button(
        ui.Bounds(0, 0.00, 0.00,   0.03, 0.02, 0.010)
    )
    muteButton.label.fitToWidth = true
    muteButton.onActivated = function()
        
        soundEng:setMuted(not soundEng.isMuted)
    end

    local volumeLabel = ui.Label(
        ui.Bounds(0,0,0,   0.03, 0.005, 0.010)
        :scale(1, 2, 1)
            :rotate(-3.14/2, 1,0,0)
            :move(0, 0.003, 0.01)
            
    )
    muteButton:addSubview(volumeLabel)

    function updateLooks()
        if not self.micStatus or self.micStatus.status == "pending" then
            muteButton:setColor({0.7, 0.7, 0.9, 1.0})
            muteButton.label:setText("Starting mic...")
        elseif self.micStatus.status == "failed" then
            muteButton:setColor({0.9, 0.5, 0.5, 1.0})
            muteButton.label:setText("Mic is broken")
        elseif self.micStatus.name == "Off" or soundEng.isMuted == true then
            muteButton:setColor({0.9, 0.7, 0.7, 1.0})
            muteButton.label:setText("Mic off")
        else
            muteButton:setColor({0.7, 0.9, 0.7, 1.0})
            muteButton.label:setText("Mic on")
        end
    end

    self:scheduleCleanup(Store.singleton():listen("currentMic", function(micStatus)
        self.micStatus = micStatus
        updateLooks()
    end))
    self:scheduleCleanup(Store.singleton():listen("micMuted", function(isMuted)
        updateLooks()
    end))
    self:scheduleCleanup(Store.singleton():listen("micVolume", function(micVolume)
        if micVolume == nil then micVolume = "--" end
        volumeLabel:setText(micVolume)
    end))

    self:_addWidget(avatar, netscene, muteButton, cb)
end

function StandardWidgets:addHelpWidget(avatar, netscene, cb)
    local widget = ui.Button(
        ui.Bounds(0, 0.00, 0.00,   0.02, 0.02, 0.010)
    )
    widget.label.text = "Help"
    widget.label.fitToWidth = true
    
    local helpUI = ui.Surface(ui.Bounds(0,0.05,0, 0.1, 0.1, 0.001))
    helpUI:setColor({0,0,0,1})
    local front = helpUI:addSubview(ui.Surface(helpUI.bounds:copy():moveToOrigin():inset(0.005, 0.005, 0):move(0,0,0.001)))
    front:setColor({1,0.9,0.9,1})
    local visible = false

    widget.onActivated = function()
        if not visible then
            visible = true
            self:_pullUpDetails(widget, helpUI)
        else
            visible = false
            self:_pullDownDetails(widget, helpUI)
        end
    end

    self:_addWidget(avatar, netscene, widget, cb)
end



return StandardWidgets
