local alloBasicShader = lovr.graphics.newShader(
  [[
    out vec3 FragmentPos;
    out vec3 Normal;

    vec4 position(mat4 projection, mat4 transform, vec4 vertex)
    {
      Normal = lovrNormal * lovrNormalMatrix;
      FragmentPos = vec3(lovrModel * vertex);
      
      return projection * transform * vertex; 
    }
  ]],
  [[
  uniform vec4 ambience;
      
  uniform vec4 liteColor;
  uniform vec3 lightPos;

  in vec3 Normal;
  in vec3 FragmentPos;

  uniform vec3 viewPos;
  uniform float specularStrength;
  uniform int metallic;

  vec4 color(vec4 graphicsColor, sampler2D image, vec2 uv) 
  {
    //diffuse
    vec3 norm = normalize(Normal);
    vec3 lightDir = normalize(lightPos - FragmentPos);
    float diff = max(dot(norm, lightDir), 0.0);
    vec4 diffuse = diff * liteColor;

    //specular
    vec3 viewDir = normalize(viewPos - FragmentPos);
    vec3 reflectDir = reflect(-lightDir, norm);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), metallic);
    vec4 specular = specularStrength * spec * liteColor;
    
    vec4 baseColor = graphicsColor * texture(image, uv);            
    return baseColor * (ambience + diffuse + specular);
  }
  ]],
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

alloBasicShader:send('ambience', { 0.2, 0.2, 0.2, 1.0 })    -- color & alpha of ambient light
alloBasicShader:send('liteColor', {1.0, 1.0, 1.0, 1.0})     -- color & alpha of diffuse light
alloBasicShader:send('lightPos', {2.0, 5.0, 0.0})           -- position of diffuse light source
alloBasicShader:send('specularStrength', 0.5)
alloBasicShader:send('metallic', 32.0)
alloBasicShader:send('viewPos', {0.0, 0.0, 0.0})

alloBasicShader:send('lovrLightDirection', { -1, -1, -1 })
alloBasicShader:send('lovrLightColor', { 1.0, 1.0, 1.0, 1.0 })
alloBasicShader:send('lovrExposure', 2)

return alloBasicShader