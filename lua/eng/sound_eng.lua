--- The Allovisor Sound engine
-- @classmod SoundEng

namespace("networkscene", "alloverse")

local pretty = require "pl.pretty"
local util = require "lib.util"
local ffi = require("ffi")

local SoundEng = classNamed("SoundEng", Ent)

function SoundEng.supported()
  return lovr.audio ~= nil and (lovr.headset == nil or (lovr.headset.getName() ~= "Pico"))
end

function SoundEng:_init()
  self.audio = {}
  self.effects = {}
  self.track_id = 0
  self.mic = nil
  self.isMuted = false
  self.micVolume = 0
  self:super()
end

function SoundEng:onButtonPressed(hand, button)
  if button == "b" then
    self:setMuted(not self.isMuted)
  end
end

function SoundEng:setMuted(newMuted)
  self.isMuted = newMuted
  if self.isMuted then
    self:_setMeasuredMicVolume(0)
    print("SoundEng: soft-muted microphone")
  else
    print("SoundEng: soft-unmuted microphone")
  end
  Store.singleton():save("micMuted", self.isMuted, false)
end

function SoundEng:useMic(micName)
  if self.mic and self.mic.name == micName then return true end

  if self.mic then
    lovr.audio.stop("capture")
    self.mic = nil
  end
  if micName == "Off" or micName == "Mute" then
    print("SoundEng: Muted microphone")
    Store.singleton():save("currentMic", {name= "Off", status="ok"}, true)
    return true
  end
  
  self.mic = self:_openMic(micName)
  local success = self.mic ~= nil
  Store.singleton():save("currentMic", {name= micName, status= (success and "ok" or "failed")}, true)
  return success
end

function SoundEng:retryMic()
  self:useMic(self._lastAttemptedMic)
end

function SoundEng:_openMic(micName)
  print("Attempting to open microphone", micName)
  self._lastAttemptedMic = micName

  local mic = {
    name= micName,
    captureBuffer = lovr.data.newBlob(960*2, "captureBuffer"),
    captureStream = lovr.data.newSound(0.5*48000, "i16", "mono", 48000, "stream"),
  }

  local chosenDeviceId = nil
  for _, dev in ipairs(lovr.audio.getDevices("capture")) do
    if dev.name == micName then
      chosenDeviceId = dev.id
    end
  end

  local setStatus = lovr.audio.setDevice("capture", chosenDeviceId, mic.captureStream, "shared")
  if not setStatus then
    print("Failed to setDevice, seeing if permissions help", micName)
    lovr.system.requestPermission('audiocapture')
    return nil
  end
  print("Selected mic", micName)

  local startStatus = lovr.audio.start("capture")
  if not startStatus then
    print("Failed to open mic, missing permissions. Requesting permissions.")
    lovr.system.requestPermission('audiocapture')
    return nil
  end

  print("Opened mic", micName)
  return mic
end

function SoundEng:onLoad()
  self.client.delegates.onAudio = function(track_id, audio)
    return self:onAudio(track_id, audio) 
  end

  if not self.parent.isMenu then
    local micSettings = Store.singleton():load("currentMic")
    if micSettings and micSettings.status ~= "pending" then
      -- engine just got instantiated so persisted settings are lying. 
      micSettings.status = "pending"
      Store.singleton():save("currentMic", micSettings, true)
    end
    self.unsub = Store.singleton():listen("currentMic", function(micSettings)
      if micSettings and micSettings.status == "pending" then
        self:useMic(micSettings.name)
      end
    end)

    self.unsub2 = Store.singleton():listen("micGain", function(micGain)
      if micGain then
        self.micGain = micGain
      else
        self.micGain = 1.0
      end
    end)
  end
end

function SoundEng:onDie()
  if self.unsub then self.unsub() end
  if self.unsub2 then self.unsub2() end
end

function SoundEng:onAudio(track_id, samples)
  if type(track_id) == "table" then 
    print("Here's broken track ID: ", pretty.write(track_id))
  end
  local audio = self.audio[track_id]
  if audio == nil then
    local soundData = lovr.data.newSound(48000*1.0, "i16", "mono", 48000, "stream")
    audio = {
      soundData = soundData,
      source = lovr.audio.newSource(soundData),
      position = {0,0,0},
      bitrate = 0.0,
      playbackSpeed = 1.0,
    }
    self.audio[track_id] = audio
  end
  if self.parent.isSpectatorCamera and audio.isVisor then
    audio.source:setEffectEnabled("attenuation", false)
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
  audio.soundData:setFrames(blob)
  if audio.source:isPlaying() == false and audio.source:getDuration() >= 0.2 then
    print("Starting playback audio in track "..track_id)
    audio.source:play()
  end
  return true
end

-- set position of audio for each entity that has a track_id assigned
function SoundEng:setAudioPositionForEntitiy(entity)

  local voice = nil
  local media = entity.components.live_media
  local effect = entity.components.sound_effect
  if media then
    local track_id = media.track_id
    voice = self.audio[track_id]  
  elseif effect then
    voice = self.effects[entity.id]
  end
  if voice == nil or voice.source == nil then return end 

  local matrix = entity.components.transform:getMatrix()
  local x, y, z, sx, sy, sz, a, ax, ay, az = matrix:unpack()
  voice.position = {x, y, z}
  voice.source:setPose(x, y, z, a, ax, ay, az)
  voice.isVisor = entity.components.visor ~= nil
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
    body = {"allocate_track", "audio", "opus", {
      sample_rate= 48000, 
      channel_count= 1,
      channel_layout= "mono",
    }}
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
    local s = string.format("Track #%d\n    %.2fkBps\n    %.2fs buffered\n     speed: %.2fx", track_id, audio.bitrate/1024.0, audio.source:getDuration(), audio.playbackSpeed)
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
  if self.client == nil or not self.parent.active then
    self:_setMeasuredMicVolume(0)
    return
  end

  while self.mic and self.mic.captureStream:getFrameCount() >= 960 do
    local count = self.mic.captureStream:getFrames(self.mic.captureBuffer, 960)
    assert(count == 960)
    if self.track_id and not self.isMuted then
      self:_processAndMeasureMic()
      self.client:sendAudio(self.track_id, self.mic.captureBuffer:getString())
    else
      self.micVolume = 0
    end
  end

  for _, entity in pairs(self.client.state.entities) do
    self:setAudioPositionForEntitiy(entity)
    if entity.components.sound_effect then
      self:updateSoundEffect(self.effects[entity.id], entity.components.sound_effect)
    end
  end
  if self.head then
    local matrix = self.head.components.transform:getMatrix()
    local x, y, z, sx, sy, sz, a, ax, ay, az = matrix:unpack()
    lovr.audio.setPose(x, y, z, a, ax, ay, az)
  end

  --self:updatePlaybackSpeeds(dt)
end


function SoundEng:_processAndMeasureMic()
  local buffer = self.mic.captureBuffer
  local vol = 0
  local samples = ffi.cast("int16_t*", buffer:getPointer())
  for i = 1, 960 do
    samples[i] = samples[i] * self.micGain
    vol = vol + math.abs(samples[i])
  end
  self:_setMeasuredMicVolume(vol / 960)
end

local lastReportedDbAt = 0
local lastReportedDb = 0
function SoundEng:_setMeasuredMicVolume(vol)
  self.micVolume = vol
  self.parent.engines.stats.stats["mic volume"] = dBString
  if lovr.timer.getTime() > lastReportedDbAt + 0.25 or (vol == 0 and lastReportedDb ~= 0) then
    lastReportedDbAt = lovr.timer.getTime()
    lastReportedDb = vol

    local dB = 20 * math.log10(vol/32768)
    local dBString = string.format("%02.2f dB", dB)
    Store.singleton():save("micVolume", dBString, false)
  end
end

function SoundEng:updatePlaybackSpeeds(dt)
  local rate = 0.2
  -- todo: use some sort of stream scoring. if playback stops or we underrun, decrease the score
  -- if playback has been continuous for x seconds, improve the score.
  -- with a good score, aim to keep a smaller buffer so we get good latency.
  -- with a bad score, aim to keep a bigger buffer
  for track_id, audio in pairs(self.audio) do
    local cacheDuration = audio.source:getDuration()
    local playbackSpeed = audio.playbackSpeed

    if cacheDuration < 0.1 then
      if playbackSpeed > 0.8 then
        playbackSpeed = playbackSpeed - rate*dt
      end
    elseif cacheDuration > 0.5 then
      if playbackSpeed < 1.2 then
        playbackSpeed = playbackSpeed + rate*dt
      end
    elseif cacheDuration > 0.1 then
      if math.abs(1.0 - playbackSpeed) < 0.02 then
        playbackSpeed = 1.0
      elseif playbackSpeed < 1.0 then
        playbackSpeed = playbackSpeed + rate*dt
      elseif playbackSpeed > 1.0 then
        playbackSpeed = playbackSpeed - rate*dt
      end
    end
    if audio.playbackSpeed ~= playbackSpeed then
      audio.playbackSpeed = playbackSpeed
      audio.source:setPlaybackRate(audio.playbackSpeed)
    end
  end
end

function SoundEng:onComponentAdded(component_key, component)
  if component_key == "sound_effect" then
    self:onSoundEffectAdded(component)
  elseif component_key == "live_media" then 
    self:onLiveMediaAdded(component)
  end
end

function SoundEng:onComponentChanged(component_key, component)
  if component_key == "sound_effect" then
    self:onSoundEffectChanged(component)
  end
end

function SoundEng:onComponentRemoved(component_key, component)
  if component_key == "live_media" then
    self:onLiveMediaRemoved(component)
  elseif component_key == "sound_effect" then
    self:onSoundEffectRemoved(component)
  end
end

function SoundEng:onLiveMediaAdded(component)
  local trackId = component.track_id
  -- XXX HACK there's a race condition where allocate_track's response is slower than
  -- the state stream returning the component. So, we wait a bit before subscribing
  -- so we can almost REALLY know whether the new track is ours or not.
  -- Of course, this is still a race condition and if interaction response is slower than
  -- 500ms we'll still accidentally subscribe to our own media stream.
  self.parent.app:scheduleAction(0.5, false, function()
    if trackId ~= self.track_id then
      print("SoundEng: subscribing to ", trackId)
      self:sendMediaTrackSubscriptionInteraction(trackId, true)
    else
      print("SoundEng: not subscribing to own audio channel", trackId)
    end
  end)
end

function SoundEng:onLiveMediaRemoved(component)
  local audio = self.audio[component.track_id]
  print("Removing incoming audio channel ", component.track_id)

  if audio == nil then return end

  audio.source:stop()
  self.audio[component.track_id] = nil
end

function SoundEng:onSoundEffectAdded(component)
  local eid = component:getEntity().id
  local voice = {
    assetId = component.asset
  }
  self.effects[eid] = voice

  self.parent.engines.assets:loadSoundEffect(component.asset, function (source)
      voice.source = source
  end)
end

function SoundEng:onSoundEffectChanged(component)
  local eid = component:getEntity().id
  local voice = self.effects[eid]
  if voice and component.asset ~= voice.assetId then
    self:onSoundEffectRemoved(component)
    self:onSoundEffectAdded(component)
  end
end

function SoundEng:onSoundEffectRemoved(component)
  local eid = component:getEntity().id
  local voice = self.effects[eid]
  if component.finish_if_orphaned and voice.source and voice.source:isPlaying() then
    voice.removeWhenStopped = true
  end

  if voice == nil then return end

  if voice.source then
    voice.source:stop()
  end
  self.effects[component:getEntity().id] = nil
end

function SoundEng:updateSoundEffect(voice, comp)
  if voice.source == nil then return end
  local eid = comp:getEntity().id

  local now = self.client:getServerTime()
  local startsAt = comp.starts_at
  local oneLength = comp.length or voice.source:getDuration('seconds')
  local loopCount = comp.loop_count or 0
  local playCount = loopCount + 1
  local endsAt = comp.starts_at + oneLength * playCount

  local shouldBePlaying = now > startsAt and now < endsAt

  if shouldBePlaying then
    local globalPosition = now - startsAt
    local localPosition = math.fmod(globalPosition, oneLength)
    local offset = comp.offset or 0.0
    local localTrimmedPosition = offset + localPosition
    local currentPosition = voice.source:tell()
    if math.abs(currentPosition - localTrimmedPosition) > 0.1 then
      -- try to play sounds from exact start even if we slightly missed the start time.
      if localTrimmedPosition < 0.1 then
        localTrimmedPosition = 0
      end
      voice.source:seek(localTrimmedPosition)
    end
  end

  if shouldBePlaying and not voice.source:isPlaying() then
    local volume = comp.volume or 1.0
    voice.source:setVolume(volume)
    voice.source:setLooping(loopCount > 0)
    voice.source:play()
  elseif not shouldBePlaying and voice.source:isPlaying() then
    voice.source:stop()
    if voice.removeWhenStopped then
      self:onComponentRemoved("sound_effect", comp)
    end
  end
end

function SoundEng:onDisconnect()
  if self.mic ~= nil then
    lovr.audio.stop("capture")
    self.mic = nil
  end
  for eid, voice in pairs(self.effects) do
    voice.source:stop()
  end
  self.effects = {}
end

--- Subscribe or unsubscribe to a media track
function SoundEng:sendMediaTrackSubscriptionInteraction(track_id, subscribe)
    assert(track_id and subscribe)
    self.client:sendInteraction({
        type = "request",
        sender_entity_id = self.parent.head_id,
        receiver_entity_id = "place",
        body = {
            "media_track",
            track_id,
            subscribe and "subscribe" or "unsubscribe",
        }
    }, function (response, body)
        if body[2] == "ok" then
            print("SoundEng: Subscribed to ", track_id)
        else
          print("SoundEng: Failed to subscribe to track", track_id, ":", pretty.write(body))
        end
  end)
end

return SoundEng
