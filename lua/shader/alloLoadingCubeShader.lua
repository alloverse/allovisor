

local alloLoadingCubeShader = lovr.graphics.newShader(
  [[
    out float alpha;
    vec4 position(mat4 projection, mat4 transform, vec4 vertex) {      
      return projection * transform * vertex;
    }
  ]], 
  [[
    in float alpha;
    uniform float time;

    vec4 color(vec4 graphicsColor, sampler2D image, vec2 uv) {  
      return vec4 (
        1, 
        1, 
        1, 
        graphicsColor.a * sin(time * 4 + uv.y) / 2 + 0.5
      );
    }
  ]],
  {
    stereo = lovr.headset == nil or (lovr.headset.getName() ~= "Pico") -- turn off stereo on pico: it's not supported
  }
)

return alloLoadingCubeShader