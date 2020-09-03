namespace("menu", "alloverse")

local MenuScene = require("app.menu.menu_scene")
local MenuItem = require("app.menu.menu_item")
local settings = require("lib.lovr-settings")

local MainMenuScene = classNamed("MainMenuScene", MenuScene)
function MainMenuScene:_init()
  settings.load()

  local mainMenuItems = {
    MenuItem("Debug (off)", function() 
      settings.d.debug = not settings.d.debug
      settings.save()
      self:setDebug(settings.d.debug) 
    end),
    MenuItem("Quit", function()
      settings.save()
      lovr.event.quit(0) 
    end),
  }
   
  local elements = {
    MenuScene.letters.TextField:new{
      position = lovr.math.newVec3(-0.7, 1.3, -1.5),
      width = 1.1,
      fontScale = 0.1,
      font = font,
      onReturn = function() settings.save(); self.elements[2]:makeKey(); return false; end,
      onChange = function(s, old, new) settings.d.username = new; return true end,
      placeholder = "Name",
      text = settings.d.username and settings.d.username or ""
    },
    MenuScene.letters.TextField:new{
      position = lovr.math.newVec3(-0.7, 1.15, -1.5),
      width = 1.1,
      fontScale = 0.1,
      font = font,
      onReturn = function() self:connect() return false; end,
      placeholder = "nevyn.places.alloverse.com",
      text = settings.d.last_place and settings.d.last_place:gsub("^alloplace://", "") or ""
    },
    MenuScene.letters.Button:new{
      position = lovr.math.newVec3(0.6, 1.2, -1.5),
      onPressed = function() 
        self:connect()
      end,
      label = "Connect"
    }
  }
  self.debug = false
  return self:super(mainMenuItems, elements)
end

function MainMenuScene:onLoad()
  MenuScene.onLoad(self)
  self.models = {
    head = lovr.graphics.newModel('assets/models/head/female.glb'),
    lefthand = lovr.graphics.newModel('assets/models/left-hand/left-hand.glb'),
    righthand = lovr.graphics.newModel('assets/models/right-hand/right-hand.glb'),
    torso = lovr.graphics.newModel('assets/models/torso/torso.glb')
  }
  self:setDebug(settings.d.debug)

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
end

function MainMenuScene:onUpdate()
  MenuScene.onUpdate(self)
end

function MainMenuScene:onDraw()
  lovr.graphics.setShader()
  
  MenuScene.onDraw(self)
  lovr.graphics.setColor({1,1,1})

  lovr.graphics.setShader(self.shader)
  self.models.head:draw(     -1.5, 1.8, -1.2, 1.0, 0, 0, 1, 0, 1)
  self.models.torso:draw(     -1.5, 1.2, -1.2, 1.0, 3.14, 0, 1, 0, 1)
  self.models.lefthand:draw( -1.3, 1.2, -1.2, 1.0, 3.14, -0.5, 1, 0, 1)
  self.models.righthand:draw(-1.8, 0.9, -1.4, 1.0, 3.14, 0.5, 1, 1, 1)

end

function MainMenuScene:setDebug(whether)
  self.debug = whether
  self.menuItems[1].label = string.format("Debug (%s)", self.debug and "on" or "off")
end

function MainMenuScene:connect()
  local url = self.elements[2].text ~= "" and self.elements[2].text or self.elements[2].placeholder
  url = "alloplace://" .. url
  self:openPlace(url)
end

function MainMenuScene:openPlace(url)
  settings.d.last_place = url
  settings.save()

  local displayName = settings.d.username and settings.d.username or "Unnamed"
  local scene = lovr.scenes.network(displayName, url)
  scene.debug = self.debug
  scene:insert()
  self:die()
end


lovr.scenes.menu = MainMenuScene

return MainMenuScene