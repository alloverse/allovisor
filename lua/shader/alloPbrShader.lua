local alloPbrShader = lovr.graphics.newShader(
  'standard',
  {
    flags = {
      normalMap = true,
      normalTexture = false,
      indirectLighting = true,
      occlusion = true,
      emissive = true,
      skipTonemap = false
    },
    stereo = (lovr.headset.getName() ~= "Pico") -- turn off stereo on pico: it's not supported
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

alloPbrShader:send('ambience', { 0.2, 0.2, 0.2, 1.0 })    -- color & alpha of ambient light
alloPbrShader:send('liteColor', {1.0, 1.0, 1.0, 1.0})     -- color & alpha of diffuse light
alloPbrShader:send('lightPos', {2.0, 5.0, 0.0})           -- position of diffuse light source
alloPbrShader:send('specularStrength', 0.5)
alloPbrShader:send('metallic', 32.0)
alloPbrShader:send('viewPos', {0.0, 0.0, 0.0})

alloPbrShader:send('lovrLightDirection', { -1, -1, -1 })
alloPbrShader:send('lovrLightColor', { 1.0, 1.0, 1.0, 1.0 })
alloPbrShader:send('lovrExposure', 2)
alloPbrShader:send('lovrEnvironmentMap', environmentMap)

return alloPbrShader