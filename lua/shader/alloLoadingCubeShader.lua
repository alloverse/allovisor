

local alloLoadingCubeShader = lovr.graphics.newShader(
  [[
    out float alpha;
    vec4 position(mat4 projection, mat4 transform, vec4 vertex) {
      // The z coordinate of cylinder vertices ranges from -.5 at the top to .5 at the bottom
      // Adding .5 will map it from 0 - 1 which can be used as the alpha channel in fragment shader
      // alpha = 1. - (vertex.z + .5); // OG
      // alpha = vertex.z + .5; // REVERSE OG
      
      return projection * transform * vertex;
    }
    ]], [[
    in float alpha;
    uniform float time;
    vec4 color(vec4 graphicsColor, sampler2D image, vec2 uv) {
      

//      return vec4(
//        1 * sin(time * 3 + uv.x * 20) / 2 + .5, 
//        1 * sin(-time * 5 + uv.x * 5) / 2 + .5, 
//        1 * sin(time * 2 + uv.y * 10) / 2 + .5, 
//        graphicsColor.a * alpha ); // Uses incoming alpha and multiplies it by the outgoing alpha (0-1) to blend them

    return vec4(
      0.047, 
      0.168, 
      0.281, 
      graphicsColor.a * sin(time * 4 + uv.y) / 2 + 1);
    }

  ]],
  {
    stereo = lovr.headset == nil or (lovr.headset.getName() ~= "Pico") -- turn off stereo on pico: it's not supported
  }
)

return alloLoadingCubeShader