local alloPbrShader = lovr.graphics.newShader(
  'standard',
  {
    flags = {
      normalMap = true,
      indirectLighting = true,
      occlusion = true,
      emissive = true,
      skipTonemap = false,
      animated = true
    },
    stereo = lovr.headset == nil or (lovr.headset.getName() ~= "Pico") -- turn off stereo on pico: it's not supported
  }
)

-- global, not local! leak this so it lives as long as the shader. 
-- otherwise, it's deallocated before shader is used.
environmentMap = lovr.graphics.newTexture({
  left = 'assets/textures/skybox/skybox-left.jpg',
  right = 'assets/textures/skybox/skybox-right.jpg',
  top = 'assets/textures/skybox/skybox-top.jpg',
  bottom = 'assets/textures/skybox/skybox-bottom.jpg',
  back = 'assets/textures/skybox/skybox-back.jpg',
  front = 'assets/textures/skybox/skybox-front.jpg'
})

alloPbrShader:send('lovrLightDirection', { -1, -1, -1 })
alloPbrShader:send('lovrLightColor', { .9, .9, .8, 1.0 })
alloPbrShader:send('lovrExposure', 2)
alloPbrShader:send('lovrEnvironmentMap', environmentMap)

return alloPbrShader
