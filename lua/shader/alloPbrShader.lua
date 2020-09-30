local alloPbrShader = lovr.graphics.newShader(
  'standard',
  {
    flags = {
      normalMap = true,
      indirectLighting = true,
      occlusion = true,
      emissive = true,
      skipTonemap = false
    },
    stereo = lovr.headset == nil or (lovr.headset.getName() ~= "Pico") -- turn off stereo on pico: it's not supported
  }
)

-- global, not local! leak this so it lives as long as the shader. 
-- otherwise, it's deallocated before shader is used.
environmentMap = lovr.graphics.newTexture(256, 256, 6, { type = 'cube' })

for mipmap = 1, environmentMap:getMipmapCount() do
  for face, dir in ipairs({ 'px', 'nx', 'py', 'ny', 'pz', 'nz' }) do
    local filename = ('assets/env/m%d_%s.png'):format(mipmap - 1, dir)
    local image = lovr.data.newTextureData(filename, false)
    environmentMap:replacePixels(image, 0, 0, face, mipmap)
  end
end

  alloPbrShader:send('lovrLightDirection', { -1, -1, -1 })
  alloPbrShader:send('lovrLightColor', { .9, .9, .8, 1.0 })
  alloPbrShader:send('lovrExposure', 2)
  alloPbrShader:send('lovrEnvironmentMap', environmentMap)

return alloPbrShader