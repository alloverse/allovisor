namespace("networkscene", "alloverse")

local json = require "json"
local Entity, componentClasses = unpack(require("app.network.entity"))

local SoundEng = classNamed("SoundEng", Ent)
function SoundEng:_init()
  self.audio = {}
  if #lovr.audio.getMicrophoneNames() > 0 then
    self.mic = lovr.audio.newMicrophone(nil, 960*3, 48000, 16, 1)
    self.mic:startRecording()
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

  for _, entity in pairs(self.parent.state.entities) do
    self:setAudioPositionForEntitiy(entity)
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
  local position = matrix:mul(lovr.math.vec3())

  track.source:setPosition(position:unpack())
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
    self.parent.client:send_audio(sd:getBlob():getString());
  end
end

return SoundEng
