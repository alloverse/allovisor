namespace("networkscene", "alloverse")

local json = require "json"
local Entity, componentClasses = unpack(require("app.network.entity"))

local SoundEng = classNamed("SoundEng", Ent)
function SoundEng:_init()
  self.audio = {}
  self.track_id = 0
  if #lovr.audio.getMicrophoneNames() > 0 then
    self.mic = lovr.audio.newMicrophone(nil, 960*3, 48000, 16, 1)
  end
  
  self:super()
end

function SoundEng:onLoad()
  self.parent.client:set_audio_callback(function(track, audio) self:onAudio(track, audio) end)
end

function SoundEng:onAudio(track_id, samples)
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
  -- todo: position sources at their entities
end

function SoundEng:onHeadAdded(head)
  if self.track_id ~= 0 then return end
  if self.track_allocation_request_id ~= nil then return end

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
  if self.debug == false then
    return
  end

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

function SoundEng:onDisconnect()
  if self.mic ~= nil then
    self.mic:stopRecording()
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

return SoundEng
