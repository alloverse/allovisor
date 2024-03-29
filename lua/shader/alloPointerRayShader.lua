

local alloPointerRayShader = lovr.graphics.newShader(
  [[
    out float alpha;
    vec4 position(mat4 projection, mat4 transform, vec4 vertex) {
      // The z coordinate of cylinder vertices ranges from -.5 at the top to .5 at the bottom
      // Adding .5 will map it from 0 - 1 which can be used as the alpha channel in fragment shader
      // alpha = 1. - (vertex.z + .5); // OG
      alpha = vertex.z + .5; // REVERSE OG
      
      return projection * transform * vertex;
    }
    ]], [[
    in float alpha;
    vec4 color(vec4 graphicsColor, sampler2D image, vec2 uv) {
      //return vec4(1., 1., 1., pow(alpha, 2.));
      //return vec4(1., 1., 1., -pow(alpha, 4.)+alpha );

      //return vec4(graphicsColor.r, graphicsColor.g, graphicsColor.b, -pow(alpha, 4.)+alpha );

      return vec4(graphicsColor.r, graphicsColor.g, graphicsColor.b, graphicsColor.a * alpha ); // Uses incoming alpha and multiplies it by the outgoing alpha (0-1) to blend them
      
    }
  ]],
  {
    stereo = lovr.headset == nil or (lovr.headset.getName() ~= "Pico") -- turn off stereo on pico: it's not supported
  }
)

return alloPointerRayShader
