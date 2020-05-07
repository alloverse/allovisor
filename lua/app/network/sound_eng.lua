namespace("networkscene", "alloverse")

local pretty = require "pl.pretty"
local Entity, componentClasses = unpack(require("app.network.entity"))

local SoundEng = classNamed("SoundEng", Ent)
function SoundEng:_init()
  self.audio = {}
  self.track_id = 0
  self.mic = self:_attemptOpenMicrophone()
  
  self:super()
end

function SoundEng:_attemptOpenMicrophone()
  local sampleFmts = {48000, 44100, 32000, 22050, 16000, 8000}
  local bufferSizes = {960*3, 8192, 16384}
  local drivers = lovr.audio.getMicrophoneNames()
  for _, driver in ipairs(drivers) do
    for _, sampleFmt in ipairs(sampleFmts) do
      for _, bufferSize in ipairs(bufferSizes) do
        local mic = lovr.audio.newMicrophone(driver, bufferSize, sampleFmt, 16, 1)
        if mic ~= nil then
          print("SoundEng: Opened microphone '", driver, "' at ", sampleFmt, "hz and ", bufferSize, "bytes per packet")
          return mic
        end
      end
    end
  end
  print("SoundEng: No compatible microphones found :(")
  return nil
end

function SoundEng:onLoad()
  self.parent.client:set_audio_callback(function(track_id, audio) self:onAudio(track_id, audio) end)
end

function SoundEng:onAudio(track_id, samples)
  if type(track_id) == "table" then 
    print("Here's broken track ID: ", pretty.write(track_id))
  end
  local audio = self.audio[track_id]
  if audio == nil then
    local stream = lovr.data.newAudioStream(1, 48000)
    audio = {
      stream = stream,
      source = lovr.audio.newSource(stream, "stream")
    }
    self.audio[track_id] = audio
  end
  local blob = lovr.data.newBlob(samples, "audio for track #"..track_id)
  audio.stream:append(blob)
  if audio.source:isPlaying() == false and audio.stream:getDuration() >= 0.2 then
    print("Starting playback audio in track "..track_id)
    audio.source:play()
  end
end

function SoundEng:onStateChanged()
  for _, entity in pairs(self.parent.state.entities) do
    self:setAudioPositionForEntitiy(entity)
  end
  if self.head then
    local matrix = self.head.components.transform:getMatrix()
    lovr.audio.setPose(matrix:unpack())
  end
end


-- set position of audio for each entity that has a track_id assigned
function SoundEng:setAudioPositionForEntitiy(entity)
  local media = entity.components.live_media 

  if media == nil then return end

  local track_id = media.track_id
  local track = self.audio[track_id]

  if track == nil then return end 

  local matrix = entity.components.transform:getMatrix()

  track.source:setPose(matrix:unpack())
end

function SoundEng:onHeadAdded(head)
  self.head = head
  if self.track_id ~= 0 then return end
  if self.track_allocation_request_id ~= nil then return end
  if self.mic == nil then return end

  self.track_allocation_request_id = self.parent:sendInteraction({
    type = "request",
    sender_entity_id = self.parent.head_id,
    receiver_entity_id = "place",
    body = {"allocate_track", "audio", 48000, 1, "opus"}
  }, function (interaction) 
    if interaction.body[2] == "ok" then
      self.track_id = interaction.body[3]
      self.mic:startRecording()
    else
      print("Failed to allocate track:", interaction.body[3])
    end
  end)
end

function SoundEng:onDraw()
  if self.parent.debug == false then
    return
  end
  lovr.graphics.setShader()
  lovr.graphics.setColor(1.0, 0.0, 1.0, 0.5)
  for track_id, audio in pairs(self.audio) do
    local x, y, z = audio.source:getPosition()
    lovr.graphics.sphere(
      x, y, z,
      0.1,
      0, 0, 1, 0 -- rot
    )

    local s = string.format("%d", track_id)
    lovr.graphics.print(s, 
      x, y+0.15, z,
      0.01, --  scale
      0, 0, 1, 0,
      0, -- wrap
      "left"
    )
  end
end

function SoundEng:onUpdate(dt)
  if self.mic ~= nil and self.mic:getSampleCount() >= 960 then
    local sd = self.mic:getData(960)
    if self.track_id then
      self.parent.client:send_audio(self.track_id, sd:getBlob():getString())
    end
  end
end

function SoundEng:onComponentRemoved(component_key, component)
  if component_key ~= "live_media" then
    return
  end
  
  local audio = self.audio[component.track_id]
  print("Removing incoming audio channel ", component.track_id)

  if audio == nil then return end

  audio.source:stop()
  self.audio[component.track_id] = nil
end

function SoundEng:onDisconnect()
  if self.mic ~= nil then
    self.mic:stopRecording()
  end

  lovr.audio.stop()
end

return SoundEng
