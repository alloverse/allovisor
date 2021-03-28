--- The Allovisor Sound engine
-- @classmod SoundEng

namespace("networkscene", "alloverse")

local pretty = require "pl.pretty"
local util = require "lib.util"

local SoundEng = classNamed("SoundEng", Ent)

function SoundEng.supported()
  return lovr.audio ~= nil and (lovr.headset == nil or (lovr.headset.getName() ~= "Pico"))
end

function SoundEng:_init()
  self.audio = {}
  self.effects = {}
  self.track_id = 0
  self.currentMicName = "invalid---"
  self:super()
end

function SoundEng:useMic(micName)
  if self.currentMicName == micName and self.hasMic then return true end
  self.currentMicName = micName

  if self.hasMic then
    lovr.audio.stop("capture")
    self.hasMic = false
    self.captureStream = nil
    self.captureBuffer = nil
  end
  if micName == "Off" or micName == "Mute" then
    self.hasMic = false
    print("SoundEng: Muted microphone")
    lovr.event.push("micchanged", self.currentMicName, true)
    return true
  end
  
  self.hasMic = self:_selectMic(micName) and (lovr.audio.isRunning("capture") or lovr.audio.start("capture"))
  if self.hasMic then
    self.captureBuffer = lovr.data.newSoundData(960, 1, 48000, "i16")
    self.captureStream = lovr.audio.getCaptureStream()
  end
  lovr.event.push("micchanged", self.currentMicName, self.hasMic)
  return self.hasMic
end

function SoundEng:retryMic()
  self:useMic(self.currentMicName)
end

function SoundEng:_selectMic(micName)

  print("Using microphone", micName)
  lovr.audio.setCaptureFormat("i16", 48000)
  lovr.audio.useDevice("capture", micName)
  return true
end

function SoundEng:onLoad()
  self.client.delegates.onAudio = function(track_id, audio)
    self:onAudio(track_id, audio) 
  end
end

function SoundEng:onAudio(track_id, samples)
  if type(track_id) == "table" then 
    print("Here's broken track ID: ", pretty.write(track_id))
  end
  local audio = self.audio[track_id]
  if audio == nil then
    local soundData = lovr.data.newSoundData(48000*1.0, 1, 48000, "i16", "stream")
    audio = {
      soundData = soundData,
      source = lovr.audio.newSource(soundData),
      position = {0,0,0},
      bitrate = 0.0,
    }
    self.audio[track_id] = audio
  end

  local blobLength = #samples
  local now = lovr.timer.getTime()
  local previousAudioTime = audio.lastReceivedTime
  audio.lastReceivedTime = now
  if previousAudioTime and previousAudioTime > 0 then
    local delta = now - previousAudioTime
    local currentBitRate = blobLength / delta
    audio.bitrate = audio.bitrate * 0.90 + currentBitRate * 0.10
  end
  audio.ping = true

  local blob = lovr.data.newBlob(samples, "audio for track #"..track_id)
  audio.soundData:append(blob)
  if audio.source:isPlaying() == false and audio.source:getDuration() >= 0.2 then
    print("Starting playback audio in track "..track_id)
    audio.source:play()
  end
end

-- set position of audio for each entity that has a track_id assigned
function SoundEng:setAudioPositionForEntitiy(entity)

  local voice = nil
  local media = entity.components.live_media
  local effect = entity.components.sound_effect
  if media then
    local track_id = media.track_id
    voice = self.audio[track_id]  
    if voice == nil then return end 
  elseif effect then
    voice = self.effects[entity.id].source
  end

  local matrix = entity.components.transform:getMatrix()
  local x, y, z, sx, sy, sz, a, ax, ay, az = matrix:unpack()
  voice.position = {x, y, z}
  voice.source:setPose(x, y, z, a, ax, ay, az)
end

function SoundEng:onHeadAdded(head)
  self.head = head
  if self.track_id ~= 0 then return end
  if self.track_allocation_request_id ~= nil then return end

  print("Requesting track for mic")
  self.track_allocation_request_id = self.client:sendInteraction({
    type = "request",
    sender_entity_id = self.parent.head_id,
    receiver_entity_id = "place",
    body = {"allocate_track", "audio", 48000, 1, "opus"}
  }, function (response, body) 
    if body[2] == "ok" then
      self.track_id = body[3]
      print("Our head was allocated track ", self.track_id)
    else
      print("Failed to allocate track:", pretty.write(body))
    end
  end)
end

function SoundEng:onDebugDraw()
  for track_id, audio in pairs(self.audio) do
    local x, y, z = unpack(audio.position)
    lovr.graphics.setShader(self.parent.engines.graphics.plainShader)
    if audio.source:isPlaying() then
      lovr.graphics.setColor(0.0, 1.0, audio.ping and 1.0 or 0.2, 0.5)
    else
      lovr.graphics.setColor(1.0, 0.0, audio.ping and 1.0 or 0.2, 0.5)
    end
    audio.ping = false
    lovr.graphics.sphere(
      x, y, z,
      0.1,
      0, 0, 1, 0 -- rot
    )

    lovr.graphics.setShader()
    lovr.graphics.setColor(0.0, 0.0, 0.0, 1.0)
    local s = string.format("Track #%d\n%.2fkBps\n%.2fs buffered", track_id, audio.bitrate/1024.0, audio.source:getDuration())
    lovr.graphics.print(s, 
      x, y+0.15, z,
      0.07, --  scale
      0, 0, 1, 0,
      0, -- wrap
      "left"
    )
  end
end

function SoundEng:onUpdate(dt)
  if self.client == nil then return end

  while self.captureStream and self.captureStream:getDuration("samples") >= 960 do
    local sd = self.captureStream:read(self.captureBuffer, 960)
    if self.track_id then
      self.client:sendAudio(self.track_id, sd:getBlob():getString())
    end
  end

  for _, entity in pairs(self.client.state.entities) do
    self:setAudioPositionForEntitiy(entity)
  end
  if self.head then
    local matrix = self.head.components.transform:getMatrix()
    local x, y, z, sx, sy, sz, a, ax, ay, az = matrix:unpack()
    lovr.audio.setListenerPose(x, y, z, a, ax, ay, az)
  end
end

function SoundEng:onComponentRemoved(component_key, component)
  if component_key == "live_media" then
    self:onliveMediaRemoved(component)
  elseif component_key == "sound_effect" then
    self:onSoundEffectRemoved(component)
  end
end
function SoundEng:onLiveMediaRemoved(component)
  local audio = self.audio[component.track_id]
  print("Removing incoming audio channel ", component.track_id)

  if audio == nil then return end

  audio.source:stop()
  self.audio[component.track_id] = nil
end
function SoundEng:onLiveMediaRemoved(component)
  local eid = component:getEntity().id
  local voice = self.effects[eid]
  print("Removing sound effect for ", eid)

  if voice == nil then return end

  voice.source:stop()
  self.effects[omponent:getEntity().id] = nil
end

function SoundEng:onDisconnect()
  if self.mic ~= nil then
    self.mic:stopRecording()
  end

  lovr.audio.stop()
end

return SoundEng
