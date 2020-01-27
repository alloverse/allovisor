namespace("networkscene", "alloverse")

local json = require "json"
local Entity, componentClasses = unpack(require("app.network.entity"))

local SoundEng = classNamed("SoundEng", Ent)
function SoundEng:_init()
  self.audio = {}
  self.mic = lovr.audio.newMicrophone(nil, 960*3, 48000, 16, 1)
  self.mic:startRecording()
  
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

function SoundEng:onDisconnect()
  self.mic:stopRecording()
end

function SoundEng:onUpdate(dt)
  if self.mic:getSampleCount() >= 960 then
    local sd = self.mic:getData(960)
    self.parent.client:send_audio(sd:getBlob():getString());
  end
end

return SoundEng
