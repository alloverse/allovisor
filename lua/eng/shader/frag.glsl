
#define PI 3.141592653589
#define PI2 PI / 2.0

in vec3 vNormal;
in vec3 vFragmentPos;
in vec3 vCameraPositionWorld;
in vec3 vTangent;
in vec3 vViewDir;
in vec3 vNormalView;

uniform samplerCube cubemap;
uniform float time;

uniform float alloMetalness;
uniform float alloRoughness;

uniform int alloEnvironmentMapType; // 0: none, 1: cubemap, 2: spherical
uniform sampler2D alloEnvironmentMapSpherical;
uniform samplerCube alloEnvironmentMapCube;

#ifdef FLAG_debug

uniform float draw_albedo;
uniform float draw_metalness;
uniform float draw_roughness;
uniform float draw_diffuseEnv;
uniform float draw_specularEnv;
uniform float draw_diffuseLight;
uniform float draw_specularLight;
uniform float draw_occlusion;
uniform float draw_lights;
uniform float draw_ambient;
uniform float draw_emissive;
uniform float draw_tonemap;
uniform float draw_normalMap;

uniform float only_albedo;
uniform float only_metalness;
uniform float only_roughness;
uniform float only_diffuseEnv;
uniform float only_specularEnv;
uniform float only_diffuseLight;
uniform float only_specularLight;
uniform float only_occlusion;
uniform float only_lights;
uniform float only_ambient;
uniform float only_emissive;
uniform float only_tonemap;
uniform float only_normalMap;

#define debug(expr) expr

#else

#define debug(expr) 

#endif

vec3 environmentMap(vec3 direction);
vec3 environmentMap(vec3 direction, float bias);

vec3 environmentMap(vec3 direction) {
    return environmentMap(direction, 0.);
}

vec3 environmentMap(vec3 direction, float roughness) {
    if (alloEnvironmentMapType == 1) {
        // float mipmapCount = log2(float(textureSize(alloEnvironmentMapCube, 0).x));
        float mipmapCount = floor(log2(float(textureSize(alloEnvironmentMapCube, 0).x))) - 1.;
        float k =  min(sin(PI2*roughness) * 2., 1.);
        return textureLod(alloEnvironmentMapCube, direction, k * mipmapCount).rgb;
    } 
    
    if (alloEnvironmentMapType == 2) {
        float theta = acos(-direction.y / length(direction));
        float phi = atan(direction.x, -direction.z);
        vec2 cubeUv = vec2(.5 + phi / (2. * PI), theta / PI);
        // float mipmapCount = log2(float(textureSize(alloEnvironmentMapSpherical, 0).x));
        float mipmapCount = floor(log2(float(textureSize(alloEnvironmentMapSpherical, 0).x))) - 2.;
        // return textureLod(alloEnvironmentMapSpherical, cubeUv, ).rgb;
        float k =  min(sin(PI2*roughness) * 2., 1.);
        return textureLod(alloEnvironmentMapSpherical, cubeUv, k * mipmapCount).rgb;
    }
    return vec3(0.0);
}

float distributionGGX(float NdotH, float roughness) {
    float a = roughness * roughness;
    float a2 = a * a;
    float denom = NdotH * NdotH * (a2 - 1.0) + 1.0;
    denom = PI * denom * denom;
    return a2 / max(denom, 0.0000001);
}

float geometrySmith(float NdotV, float NdotL, float roughness) {
    float r = roughness + 1.0;
    float k = (r * r) / 8.0;
    float ggx1 = NdotV / (NdotV * (1.0 - k) + k); // Schlick GGX
    float ggx2 = NdotL / (NdotL * (1.0 - k) + k);
    return ggx1 * ggx2;
}

// fresnel: light bouncing at a large (approaching 180) reflect more easily
vec3 fresnelSchlick(float HdotV, vec3 baseReflectivity) {
    // baseRef. 0...1
    // returns baseRef...1
    return baseReflectivity + (1.0 - baseReflectivity) * pow(1.0 - HdotV, 5.0);
}

vec3 fresnelSchlickRoughness(float HdotV, vec3 baseReflectivity, float roughness) {
    // More rough = less fresnel
    return baseReflectivity + (max(vec3(1.0 - roughness), baseReflectivity) - baseReflectivity) * pow(1.0 - HdotV, 5.0);
}

// https://www.unrealengine.com/en-US/blog/physically-based-shading-on-mobile
vec2 prefilteredBRDF(float NoV, float roughness) {
  vec4 c0 = vec4(-1., -.0275, -.572, .022);
  vec4 c1 = vec4(1., .0425, 1.04, -.04);
  vec4 r = roughness * c0 + c1;
  float a004 = min(r.x * r.x, exp2(-9.28 * NoV)) * r.x + r.y;
  return vec2(-1.04, 1.04) * a004 + r.zw;
}

vec3 tonemap_ACES(vec3 x) {
  float a = 2.51;
  float b = 0.03;
  float c = 2.43;
  float d = 0.59;
  float e = 0.14;
  return (x * (a * x + b)) / (x * (c * x + d) + e);
}

// vec3 reflections(vec3 N, vec3 viewDir, float metalness, vec4 graphicsColor, float opacity) {
//     // cubemap reflection and refractions
//     vec3 refl = vec3(0.0);
//     vec3 refr = vec3(0.0);

//     vec3 n_ws=normalize(N);
//     vec3 n_vs=normalize(vNormalView);
//     n_vs=normalize(vLovrTransform * (vLovrNormalMatrixInversed * N));
//     vec3 i_vs=normalize(vViewDir);
//     float ndi=0.04+0.96*(1.0-sqrt(max(0.0,dot(n_vs,i_vs))));
//     vec3 ref = reflect(normalize(-viewDir), N).xyz;
//     // refl=texture(cubemap, ref, -0.5).rgb * ndi * metalness * graphicsColor.rgb;
//     refl=environmentMap(ref, -0.5) * ndi * metalness * graphicsColor.rgb;
//     vec3 r = refract(-i_vs, n_vs, 0.66);
//     refr=texture(cubemap, vLovrViewTransposed * r).rgb * (1. - opacity);
//     return vec3(refl + refr) * reflectionStrength;
// }
vec4 color(vec4 graphicsColor, sampler2D image, vec2 uv) {
    vec3 viewDir = normalize(vCameraPositionWorld - vFragmentPos);
    vec3 V = viewDir;
    vec3 N = normalize(vNormal);
    
    // Apply normalmap without tangent map
    debug(if (draw_normalMap > 0.) {)
        vec4 Nmap = texture(lovrNormalTexture, uv);
        if (Nmap != vec4(1) ) {
            N = perturb_normal(N, vCameraPositionWorld - vFragmentPos, uv);
        }
    debug(})

    // mapped values
    vec3 albedo = texture(lovrDiffuseTexture, lovrTexCoord).rgb * graphicsColor.rgb;
    vec4 emissive = texture(lovrEmissiveTexture, uv) * lovrEmissiveColor;
    float occlusion = texture(lovrOcclusionTexture, lovrTexCoord).r;
    float roughness = texture(lovrRoughnessTexture, lovrTexCoord).g * lovrRoughness * alloRoughness;
    float metalness = texture(lovrMetalnessTexture, lovrTexCoord).b * lovrMetalness * alloMetalness;

    #ifdef FLAG_debug
        float raw_roughness = roughness;
        float raw_metalness = metalness;
        roughness *= draw_roughness;
        metalness *= draw_metalness;
    #endif
    // Reflectance at normal incidence. F0.
    // dia-electric use 0.04 and if it's metal then use the albedo color

    #ifdef FLAG_debug
    vec3 baseColor = vec3(1.);
    if (draw_albedo > 0.) 
        baseColor = albedo;
    vec3 baseReflectivity = mix(vec3(0.04), baseColor, metalness);
    #else 
    vec3 baseReflectivity = mix(vec3(0.04), albedo, metalness);
    #endif

    float NdotV = max(dot(N, V), 0.001);
    vec3 luminence = vec3(0.0); // Lo
    debug(vec3 diffuse = vec3(0.);)
    debug(vec3 specular = vec3(0.);)
    #ifdef FLAG_lights
    debug(if(draw_lights > 0.))
    for(int i_light = 0; i_light < lightCount; i_light++) {
        vec3 lightPos = lightPositions[i_light].xyz;
        vec3 lightColor = lightColors[i_light].rgb;

        vec3 L = normalize(lightPos - vFragmentPos);
        vec3 H = normalize(V + L);
        float distance = length(lightPos - vFragmentPos);
        float attenuation = 1.0 / (distance * distance);
        vec3 radiance = lightColor * attenuation;

        // Cook-Torrence BRDF
        float NdotL = max(dot(N, L), 0.001);
        float HdotV = max(dot(H, V), 0.0);
        float NdotH = max(dot(N, H), 0.0);
        
        float D = distributionGGX(NdotH, roughness); // statistical amount of light rays reflected by micro facets
        float G = geometrySmith(NdotV, NdotL, roughness); // statistical amount of light rays not shadowed by micro facets
        vec3 F = fresnelSchlick(HdotV, baseReflectivity); // fresnel - reflections are more clear at glancing anles - ie edges of a sphere
        
        debug(if (draw_specularLight == 0.) F = vec3(0.);)
        // Diffuse is all light not reflected as specular because the equal amount of enery coming in has to come out somewhere
        // But metallic materials absorb anything not bounced of as specular so subtract that energy
        vec3 diff = (vec3(1.0) - F) * (1.0 - metalness);
        // diff *= occlusion;

        vec3 spec = D * G * F;
        spec /= 4.0 * NdotV * NdotL;

        debug(if (draw_diffuseLight == 0.))
            diff = vec3(1.0);
        debug(if (draw_albedo > 0.) )
            diff *= albedo;
        
        
        #ifdef FLAG_debug
            diff /= PI;
            diff *= radiance;
            spec *= radiance;
            // luminence += (diff / PI + spec) * radiance ; // modified for debugging
            if (draw_specularLight > 0.)
                luminence += spec;
            if (draw_diffuseLight > 0.) 
                luminence += diff;
            
            specular += spec;
            diffuse += diff;
        #else
        // diffuse * albedo because diffuse is the wavelengths (colors) not absorbed while refracting(?)
        // divided by PI ??
        // NdotL ??
        luminence += (diff * albedo / PI + spec) * radiance * NdotL; // original
        #endif
    }
    #endif
    debug(diffuse /= float(lightCount);)
    debug(specular /= float(lightCount);)

    // environment diffuse is the color shining on us and taking up by the material
    vec3 F = fresnelSchlickRoughness(NdotV, baseReflectivity, roughness);
    vec3 kD = (1.0 - F) * (1.0 - metalness);
    vec3 diffuseEnvironmentMap = environmentMap(N, 0.75);
    vec3 environmentDiffuse = diffuseEnvironmentMap * kD;
    debug(if(draw_albedo > 0.) )
        environmentDiffuse *= albedo;


    // environment specular is the color of environment reflecting off the surface of the material and into our eyes
    vec3 R = reflect(-V, N);
    vec2 lookup = prefilteredBRDF(NdotV, roughness); // microfacet statistical amount of light rays hitting us
    vec3 specularEnvironmentMap = environmentMap(R, roughness);
    vec3 environmentSpecular = specularEnvironmentMap * (F * lookup.r + lookup.g);


    // if (lovrViewID == 1)
    // environmentSpecular  /=  4. ;

    debug(environmentDiffuse *= draw_diffuseEnv;)
    debug(environmentSpecular *= draw_specularEnv;)

    vec3 ambient = vec3(0.);
    debug(if (draw_specularEnv > 0.) )
        ambient += environmentSpecular;
    debug(if (draw_diffuseEnv > 0.) )
        ambient += environmentDiffuse;

    #ifdef FLAG_debug
    if (draw_specularEnv == 0. && draw_diffuseEnv == 0.) {
        ambient = vec3(1.0) ;
        if (draw_albedo > 0.) ambient *= albedo;
    }
    #endif
    debug(if (draw_occlusion > 0.) )
        ambient *= occlusion;

    vec3 result = vec3(0.);
    debug(if (draw_ambient > 0.) )
        result += ambient;
    debug(if (draw_emissive > 0.) )
        result += emissive.rgb;
    result += luminence;


    vec3 pre_tonemap = result;
    // HDR tonemapping
    debug(if (draw_tonemap > 0.))
        result.rgb = tonemap_ACES(result.rgb);

    
    // missing: gamma correction; lovr does that for us

#ifdef FLAG_debug
    if (only_albedo > 0.) return vec4(vec3(albedo), 1.0);
    if (only_metalness > 0.) return vec4(vec3(raw_metalness), 1.0);
    if (only_roughness > 0.) return vec4(vec3(raw_roughness), 1.0);
    if (only_diffuseEnv > 0.) return vec4(vec3(environmentDiffuse), 1.0);
    if (only_specularEnv > 0.) return vec4(vec3(environmentSpecular), 1.0);
    if (only_diffuseLight > 0.) return vec4(vec3(diffuse), 1.0);
    if (only_specularLight > 0.) return vec4(vec3(specular), 1.0);
    if (only_occlusion > 0.) return vec4(vec3(occlusion), 1.0);
    if (only_lights > 0.) return vec4(vec3(luminence), 1.0);
    if (only_ambient > 0.) return vec4(vec3(ambient), 1.0);
    if (only_emissive > 0.) return vec4(vec3(emissive), 1.0);
    if (only_normalMap > 0.) return vec4(N, 1.);
    if (only_tonemap > 0.) return vec4(result - pre_tonemap, 1.);
#endif

    return vec4(result, 1.0);

    // //object color
    // vec4 baseColor = graphicsColor * texture(lovrDiffuseTexture, uv);
    // vec4 emissive = texture(lovrEmissiveTexture, uv) * lovrEmissiveColor;
    
    // // cubemap reflection and refractions
    // vec4 reflections = vec4(0.);
    // vec3 refl = vec3(0.0);
    // vec3 refr = vec3(0.0);
    // if (reflectionStrength > 0) {
    //     vec3 n_ws=normalize(N);
    //     vec3 n_vs=normalize(vNormalView);
    //     n_vs=normalize(vLovrTransform * (vLovrNormalMatrixInversed * N));
    //     vec3 i_vs=normalize(vViewDir);
    //     float ndi=0.04+0.96*(1.0-sqrt(max(0.0,dot(n_vs,i_vs))));
    //     vec3 ref = reflect(normalize(-viewDir), N).xyz;
    //     refl=texture(cubemap, ref, -0.5).rgb * ndi * metalness * graphicsColor.rgb;
    //     vec3 r = refract(-i_vs, n_vs, 0.66);
    //     refr=texture(cubemap, vLovrViewTransposed * r).rgb * (1. - baseColor.a);
    //     reflections = vec4(refl + refr, 1.) * reflectionStrength;
    // }
    
    // //float fresnel = clamp(0., 1., 1 - dot(N, viewDir));
    // // return texture(lovrRoughnessTexture, uv).rrra;
    // // return texture(lovrMetalnessTexture, uv);
    // // return texture(lovrDiffuseTexture, uv);
    // // return texture(lovrNormalTexture, uv);
    // // return texture(lovrOcclusionTexture, uv);
    // // return texture(lovrEmissiveTexture, uv);
    
    // if (lovrViewID == 1) {         
    //     // return vec4(vec3(reflectionStrength), 1.0);
    //     return vec4(refl, 1.0);
    //     // return reflections;
    // }
    // //     return vec4(N, 1.);
    // //else return vec4(N, 1);
    // return (baseColor + emissive + reflections) * vec4(lighting, 1.);
}