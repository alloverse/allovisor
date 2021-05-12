        uniform vec4 ambience;
  
        in vec3 vNormal;
        in vec3 vFragmentPos;
        in vec3 vCameraPositionWorld;
        in vec3 vTangent;
        in vec3 vViewDir;
        in vec3 vNormalView;
        
        // move mat3's to uniforms
        flat in mat3 vLovrTransform; 
        flat in mat3 vLovrViewTransposed; 
        flat in mat3 vLovrNormalMatrixInversed;
        
        uniform float specularStrength;
        uniform int metallic;
        uniform samplerCube cubemap;
        uniform float reflectionStrength;
        uniform float time;
        
        vec4 color(vec4 graphicsColor, sampler2D image, vec2 uv) {
            vec3 viewDir = normalize(vCameraPositionWorld - vFragmentPos);
            vec3 lighting = ambience.rgb;
            vec4 Nmap = texture(lovrNormalTexture, uv);
            vec3 N = normalize(vNormal);
            if (Nmap != vec4(1) ) {
                N = perturb_normal(N, vCameraPositionWorld - vFragmentPos, uv);
//                N = normalize(vNormal + (Nmap.rgb * 2. - 1.));
            }
            
            //Metallness
            float metalness = texture(lovrMetalnessTexture, lovrTexCoord).b * lovrMetalness;
            float roughness = max(texture(lovrRoughnessTexture, lovrTexCoord).g * lovrRoughness, .05);

            vec3 diffuse = vec3(0.), specular = vec3(0.);
            for(int i_light = 0; i_light < lightCount; i_light++) {
                vec3 lightPos = lightPositions[i_light].xyz;
                vec3 lightColor = lightColors[i_light].rgb;
                // lightColor = vec3(1.);
                
                //diffuse
                vec3 norm = normalize(N);
                vec3 lightDir = normalize(lightPos - vFragmentPos);
                float diff = max(dot(norm, lightDir), 0.);
                diffuse += lightColor * diff * texture(lovrOcclusionTexture, uv).r;
                
                // specular
                vec3 reflectDir = reflect(-lightDir, norm);
                float spec = pow(float(max(dot(viewDir, reflectDir), 0.0)), float(metallic)) * metalness;
                specular += specularStrength * spec * lightColor;
                
            }
            lighting += diffuse + specular;

            //object color
            vec4 baseColor = graphicsColor * texture(lovrDiffuseTexture, uv);
            vec4 emissive = texture(lovrEmissiveTexture, uv) * lovrEmissiveColor;
            
            // cubemap reflection and refractions
            vec4 reflections = vec4(0.);
            vec3 refl = vec3(0.0);
            vec3 refr = vec3(0.0);
            if (reflectionStrength > 0) {
                vec3 n_ws=normalize(N);
                vec3 n_vs=normalize(vNormalView);
                n_vs=normalize(vLovrTransform * (vLovrNormalMatrixInversed * N));
                vec3 i_vs=normalize(vViewDir);
                float ndi=0.04+0.96*(1.0-sqrt(max(0.0,dot(n_vs,i_vs))));
                vec3 ref = reflect(normalize(-viewDir), N).xyz;
                refl=texture(cubemap, ref, -0.5).rgb * ndi * metalness * graphicsColor.rgb;
                vec3 r = refract(-i_vs, n_vs, 0.66);
                refr=texture(cubemap, vLovrViewTransposed * r).rgb * (1. - baseColor.a);
                reflections = vec4(refl + refr, 1.) * reflectionStrength;
            }
            
            //float fresnel = clamp(0., 1., 1 - dot(N, viewDir));
//            return texture(lovrRoughnessTexture, uv).rrra;
//            return texture(lovrMetalnessTexture, uv);
//            return texture(lovrDiffuseTexture, uv);
//            return texture(lovrNormalTexture, uv);
        //    return texture(lovrOcclusionTexture, uv);
//            return texture(lovrEmissiveTexture, uv);
         
                if (lovrViewID == 1) {         
                    // return vec4(vec3(reflectionStrength), 1.0);
                    return vec4(specular, 1.0);
                    // return reflections;
                }
                //     return vec4(N, 1.);
                //else return vec4(N, 1);
            return (baseColor + emissive + reflections) * vec4(lighting, 1.);
        }