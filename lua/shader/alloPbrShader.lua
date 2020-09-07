return lovr.graphics.newShader(
  'standard',
  {
    flags = {
      normalTexture = false,
      indirectLighting = true,
      occlusion = true,
      emissive = true,
      skipTonemap = false
    },
    stereo = (lovr.headset.getName() ~= "Pico") -- turn off stereo on pico: it's not supported
  }
)