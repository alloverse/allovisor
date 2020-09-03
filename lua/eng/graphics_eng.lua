namespace("networkscene", "alloverse")

local json = require "json"
local array2d = require "pl.array2d"
local tablex = require "pl.tablex"
local pretty = require "pl.pretty"

local GraphicsEng = classNamed("GraphicsEng", Ent)
function GraphicsEng:_init()
  self:super()
end

function GraphicsEng:onLoad()
  self.hardcoded_models = {
    head = lovr.graphics.newModel('assets/models/head/female.glb'),
    lefthand = lovr.graphics.newModel('assets/models/left-hand/left-hand.glb'),
    righthand = lovr.graphics.newModel('assets/models/right-hand/right-hand.glb'),
    forest = lovr.graphics.newModel('/assets/models/decorations/forest/PUSHILIN_forest.gltf')
  }

  self.models_for_eids = {
  }

  customVertex = [[
    out vec3 FragmentPos;
    out vec3 Normal;

    vec4 position(mat4 projection, mat4 transform, vec4 vertex)
    {
      Normal = lovrNormal * lovrNormalMatrix;
      FragmentPos = vec3(lovrModel * vertex);
      
      return projection * transform * vertex; 
    }
  ]]

  customFragment = [[
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
  ]]
  
  self.shader = lovr.graphics.newShader(
    customVertex, 
    customFragment, 
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

  
  self.shader:send('ambience', { .2, .2, .2, 1 })         -- color & alpha of ambient light
  self.shader:send('liteColor', {1.0, 1.0, 1.0, 1.0})     -- color & alpha of diffuse light
  self.shader:send('lightPos', {2.0, 5.0, 0.0})           -- position of diffuse light source
  self.shader:send('specularStrength', 0.5)
  self.shader:send('metallic', 32.0)
  self.shader:send('viewPos', {0.0, 0.0, 0.0})


  self.factorySkybox = lovr.graphics.newTexture({
    left = 'assets/env/nx.png',
    right = 'assets/env/px.png',
    top = 'assets/env/py.png',
    bottom = 'assets/env/ny.png',
    back = 'assets/env/pz.png',
    front = 'assets/env/nz.png'
  }, { linear = true })


  lovr.graphics.setBackgroundColor(.05, .05, .05)
  self.cloudSkybox = lovr.graphics.newTexture("assets/cloudy-sunset.png")

  local greenTex = lovr.graphics.newTexture("assets/textures/green.png", {})
  self.greenMat = lovr.graphics.newMaterial(greenTex, 1, 1, 1, 1)

  self.environmentMap = lovr.graphics.newTexture(256, 256, { type = 'cube' })
  for mipmap = 1, self.environmentMap:getMipmapCount() do
    for face, dir in ipairs({ 'px', 'nx', 'py', 'ny', 'pz', 'nz' }) do
      local filename = ('assets/env/m%d_%s.png'):format(mipmap - 1, dir)
      local image = lovr.data.newTextureData(filename, false)
      self.environmentMap:replacePixels(image, 0, 0, face, mipmap)
    end
  end

  -- self.shader:send('lovrSphericalHarmonics', require('assets/env/sphericalHarmonics'))
  
    self.shader:send('lovrLightDirection', { -1, -1, -1 })
    self.shader:send('lovrLightColor', { 1.0, 1.0, 1.0, 1.0 })
    self.shader:send('lovrExposure', 2)
    self.shader:send('lovrEnvironmentMap', self.environmentMap)

end

function GraphicsEng:onDraw() 
  lovr.graphics.setShader()

  lovr.graphics.skybox(self.cloudSkybox)

  lovr.graphics.setShader(self.shader)

  lovr.graphics.setBackgroundColor(.3, .3, .40)
  lovr.graphics.setColor(1,1,1)
  
  lovr.graphics.setCullingEnabled(true)
  
  -- Draws plane & decorates it with trees
  self:drawDecorations()

  for eid, entity in pairs(self.client.state.entities) do
    local trans = entity.components.transform
    local geom = entity.components.geometry
    local parent = entity.components.relationships and entity.components.relationships.parent or nil
    local pose = entity.components.intent and entity.components.intent.actuate_pose or nil
    local model = self.models_for_eids[eid]
    if trans ~= nil and geom ~= nil and model ~= nil then
      -- don't draw our own head, as it obscures the camera
      if parent ~= self.client.avatar_id or pose ~= "head" then
        local mat = trans:getMatrix()
        if pose == "head" then mat:rotate(3.14, 0, 1, 0) end -- file is wrong
        model:draw(mat)
      end
    end
  end

  for _, ray in ipairs(self.parent.engines.pose.handRays) do
    lovr.graphics.setColor(ray:getColor())
    lovr.graphics.line(ray.from, ray.to)
  end

  lovr.graphics.setColor({1,1,1})
end

function GraphicsEng:onUpdate(dt)
  if lovr.headset then 
    hx, hy, hz = lovr.headset.getPosition()
    self.shader:send('viewPos', { hx, hy, hz } )
  end
end

function GraphicsEng:loadComponentModel(component, old_component)
  local eid = component.getEntity().id

  if component.type == "hardcoded-model" then
    self.models_for_eids[eid] = self.hardcoded_models[component.name]
  elseif component.type == "inline" then 
    self.models_for_eids[eid] = self:createMesh(component, old_component)
  end

end

function GraphicsEng:onComponentAdded(component_key, component)
  if component_key ~= "geometry" then
    return
  end

  self:loadComponentModel(component, nil)
end

function GraphicsEng:onComponentChanged(component_key, component, old_component)
  if component_key ~= "geometry" then
    return
  end

  self:loadComponentModel(component, old_component)
end

function GraphicsEng:onComponentRemoved(component_key, component)
  if component_key ~= "geometry" then
    return
  end
  component.model = nil
end

function GraphicsEng:createMesh(geom, old_geom)
  local eid = geom.getEntity().id
  local mesh = self.models_for_eids[eid]
  if old_geom then
    --print("createMesh", tablex.deepcompare(geom.triangles, old_geom.triangles), tablex.deepcompare(geom.vertices, old_geom.vertices), tablex.deepcompare(geom.uvs, old_geom.uvs))
  end

  if mesh == nil or not tablex.deepcompare(geom.triangles, old_geom.triangles) or not tablex.deepcompare(geom.vertices, old_geom.vertices) or not tablex.deepcompare(geom.uvs, old_geom.uvs) then
    print("Creating new mesh from inline model data")
    -- convert the flattened zero-based indices list
    local z_indices = array2d.flatten(geom.triangles)
    -- convert to 1-based 
    local indices = tablex.map(function (x) return x + 1 end, z_indices)
    -- zip together verts, normals, and uv
    local combined = tablex.zip(
      geom.vertices, 
      -- geom.normals, 
      geom.uvs
    )
    -- flatten the inner tables
    local vertices = tablex.map(function (x) return array2d.flatten(x) end, combined)

    -- Setup the mesh
    mesh = lovr.graphics.newMesh({
      { 'lovrPosition', 'float', 3 },
      -- { 'lovrNormal', 'float', 3 },
      { 'lovrTexCoord', 'float', 2 }
    },
    vertices,
    'triangles', -- DrawMode
    'static', -- MeshUsage. dynamic, static, stream
    false -- do we need to read the data from the mesh later
    )

    mesh:setVertices(vertices)
    mesh:setVertexMap(indices)
  end

  if old_geom == nil or old_geom.texture ~= geom.texture then
    print("Creating new texture from inline data")
    -- decode texture data and setup material
    local data = base64decode(geom.texture)
    local blob = lovr.data.newBlob(data, "texture")
    local texture = lovr.graphics.newTexture(blob)
    local material = lovr.graphics.newMaterial(texture)
    mesh:setMaterial(material)
  end

  return mesh
end

-- decoding
function base64decode(data)
  local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/' -- You will need this for encoding/decoding
  data = string.gsub(data, '[^'..b..'=]', '')
  return (data:gsub('.', function(x)
      if (x == '=') then return '' end
      local r,f='',(b:find(x)-1)
      for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
      return r;
  end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
      if (#x ~= 8) then return '' end
      local c=0
      for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
          return string.char(c)
  end))
end

function GraphicsEng:drawDecorations()
  -- "Floorplate"
  lovr.graphics.circle( 
    self.greenMat,
    0, 0, 0, -- x y z
    12,  -- radius
    -3.14/2, -- angle around axis of rotation
    1, 0, 0 -- rotation axis (x, y, z)
  )
  
  local forestModel = self.hardcoded_models.forest
  
  forestModel:draw(0, .5, -10, 2, 0, 0, 1, 0, 1)
  forestModel:draw(4, .5, -8, 2, 5, 0, 1, 0, 1)
  forestModel:draw(8, .5, -4, 2, 0, 0, 1, 0, 1)
  forestModel:draw(10, .5, 0, 2, 1, 0, 1, 0, 1)

  forestModel:draw(8, .5, 4, 2, 0, 0, 1, 0, 1)
  forestModel:draw(4, .5, 8, 2, 2, 0, 1, 0, 1)
  forestModel:draw(0, .5, 10, 2, 0, 0, 1, 0, 1)
  forestModel:draw(-4, .5, 8, 2, 3, 0, 1, 0, 1)

  forestModel:draw(-8, .5, 4, 2, 1, 0, 1, 0, 1)
  forestModel:draw(-10, .5, 0, 2,  3, 0, 1, 0, 1)
  forestModel:draw(-8, .5, -4, 2,  4, 0, 1, 0, 1)
  forestModel:draw(-4, .5, -8, 2,   0, 0, 1, 0, 1)

end

return GraphicsEng