import * as THREE from 'three';

export const TiledGlobeShaders = {
  // Vertex shader for tiled globe with multiple texture support
  vertexShader: `
    #define MAX_TILES 16
    
    attribute float tileIndex;
    
    varying vec2 vUv;
    varying vec3 vNormal;
    varying vec3 vPosition;
    varying float vTileIndex;
    varying vec3 vWorldPosition;
    
    void main() {
      vUv = uv;
      vTileIndex = tileIndex;
      vNormal = normalize(normalMatrix * normal);
      
      vec4 mvPosition = modelViewMatrix * vec4(position, 1.0);
      vPosition = mvPosition.xyz;
      vWorldPosition = (modelMatrix * vec4(position, 1.0)).xyz;
      
      gl_Position = projectionMatrix * mvPosition;
    }
  `,
  
  // Fragment shader for blending multiple tile textures
  fragmentShader: `
    #define MAX_TILES 16
    
    uniform sampler2D tileTextures[MAX_TILES];
    uniform vec4 tileBounds[MAX_TILES]; // x: minU, y: minV, z: maxU, w: maxV
    uniform int numTiles;
    uniform float tileOpacity;
    uniform vec3 lightDirection;
    uniform float time;
    
    varying vec2 vUv;
    varying vec3 vNormal;
    varying vec3 vPosition;
    varying float vTileIndex;
    varying vec3 vWorldPosition;
    
    // Bilinear interpolation for smooth tile blending
    vec4 sampleTileTexture(int tileIdx, vec2 uv) {
      if (tileIdx < 0 || tileIdx >= numTiles) return vec4(0.0);
      
      vec4 bounds = tileBounds[tileIdx];
      vec2 tileUv = (uv - bounds.xy) / (bounds.zw - bounds.xy);
      
      // Clamp to avoid edge artifacts
      tileUv = clamp(tileUv, 0.001, 0.999);
      
      // Sample texture based on tile index
      for (int i = 0; i < MAX_TILES; i++) {
        if (i == tileIdx) {
          return texture2D(tileTextures[i], tileUv);
        }
      }
      
      return vec4(0.0);
    }
    
    // Smooth step blending between tiles
    float getBlendWeight(vec2 uv, vec4 bounds) {
      float margin = 0.01; // Blend margin
      
      float leftBlend = smoothstep(bounds.x, bounds.x + margin, uv.x);
      float rightBlend = 1.0 - smoothstep(bounds.z - margin, bounds.z, uv.x);
      float bottomBlend = smoothstep(bounds.y, bounds.y + margin, uv.y);
      float topBlend = 1.0 - smoothstep(bounds.w - margin, bounds.w, uv.y);
      
      return leftBlend * rightBlend * bottomBlend * topBlend;
    }
    
    void main() {
      vec4 finalColor = vec4(0.0);
      float totalWeight = 0.0;
      
      // Find which tiles overlap this UV coordinate
      for (int i = 0; i < MAX_TILES; i++) {
        if (i >= numTiles) break;
        
        vec4 bounds = tileBounds[i];
        if (vUv.x >= bounds.x && vUv.x <= bounds.z && 
            vUv.y >= bounds.y && vUv.y <= bounds.w) {
          
          float weight = getBlendWeight(vUv, bounds);
          vec4 tileColor = sampleTileTexture(i, vUv);
          
          finalColor += tileColor * weight;
          totalWeight += weight;
        }
      }
      
      // Normalize by total weight
      if (totalWeight > 0.0) {
        finalColor /= totalWeight;
      } else {
        // Fallback color for unmapped areas
        finalColor = vec4(0.1, 0.2, 0.4, 1.0); // Ocean blue
      }
      
      // Apply basic lighting
      float NdotL = max(dot(vNormal, normalize(lightDirection)), 0.0);
      float lightIntensity = NdotL * 0.5 + 0.5; // Half-lambert
      
      finalColor.rgb *= lightIntensity;
      
      // Add atmospheric scattering at edges
      vec3 viewDir = normalize(-vPosition);
      float rim = 1.0 - max(dot(viewDir, vNormal), 0.0);
      rim = pow(rim, 2.0);
      
      vec3 atmosphereColor = vec3(0.3, 0.5, 0.9);
      finalColor.rgb = mix(finalColor.rgb, atmosphereColor, rim * 0.3);
      
      gl_FragColor = vec4(finalColor.rgb, tileOpacity);
    }
  `,
  
  // Ocean shader with wave animation
  oceanVertexShader: `
    uniform float time;
    uniform float waveHeight;
    uniform float waveFrequency;
    
    varying vec2 vUv;
    varying vec3 vNormal;
    varying vec3 vPosition;
    varying float vWaveHeight;
    
    void main() {
      vUv = uv;
      
      // Calculate wave displacement
      float wave1 = sin(position.x * waveFrequency + time) * cos(position.z * waveFrequency + time);
      float wave2 = sin(position.x * waveFrequency * 0.7 - time * 1.3) * cos(position.z * waveFrequency * 0.7 - time * 1.3);
      float displacement = (wave1 + wave2 * 0.5) * waveHeight;
      
      // Only apply waves to ocean areas (determined by texture later)
      vec3 displacedPosition = position + normal * displacement;
      vWaveHeight = displacement;
      
      // Calculate displaced normal for proper lighting
      vec3 tangent = normalize(vec3(1.0, 0.0, 0.0));
      vec3 bitangent = normalize(cross(normal, tangent));
      
      float delta = 0.01;
      float dx = sin((position.x + delta) * waveFrequency + time) * waveHeight - displacement;
      float dz = sin((position.z + delta) * waveFrequency + time) * waveHeight - displacement;
      
      vec3 modifiedNormal = normalize(normal - tangent * dx / delta - bitangent * dz / delta);
      vNormal = normalize(normalMatrix * modifiedNormal);
      
      vec4 mvPosition = modelViewMatrix * vec4(displacedPosition, 1.0);
      vPosition = mvPosition.xyz;
      
      gl_Position = projectionMatrix * mvPosition;
    }
  `,
  
  oceanFragmentShader: `
    uniform sampler2D oceanMask;
    uniform sampler2D foamTexture;
    uniform vec3 deepWaterColor;
    uniform vec3 shallowWaterColor;
    uniform vec3 foamColor;
    uniform vec3 lightDirection;
    uniform vec3 viewPosition;
    uniform float time;
    uniform float foamThreshold;
    
    varying vec2 vUv;
    varying vec3 vNormal;
    varying vec3 vPosition;
    varying float vWaveHeight;
    
    void main() {
      // Sample ocean mask to determine if this is water
      float oceanDepth = texture2D(oceanMask, vUv).r;
      
      if (oceanDepth < 0.1) {
        discard; // Not ocean, let land show through
      }
      
      // Interpolate between deep and shallow water colors
      vec3 waterColor = mix(shallowWaterColor, deepWaterColor, oceanDepth);
      
      // Calculate foam
      vec2 foamUv = vUv * 50.0 + vec2(time * 0.01, time * 0.02);
      float foam = texture2D(foamTexture, foamUv).r;
      foam *= smoothstep(foamThreshold, foamThreshold + 0.1, vWaveHeight);
      
      // Mix in foam
      vec3 color = mix(waterColor, foamColor, foam * 0.8);
      
      // Calculate lighting
      vec3 normal = normalize(vNormal);
      vec3 lightDir = normalize(lightDirection);
      vec3 viewDir = normalize(viewPosition - vPosition);
      vec3 halfDir = normalize(lightDir + viewDir);
      
      // Diffuse lighting
      float NdotL = max(dot(normal, lightDir), 0.0);
      
      // Specular lighting (Blinn-Phong)
      float NdotH = max(dot(normal, halfDir), 0.0);
      float specular = pow(NdotH, 128.0);
      
      // Fresnel effect
      float fresnel = pow(1.0 - max(dot(normal, viewDir), 0.0), 2.0);
      
      // Combine lighting
      color *= (NdotL * 0.7 + 0.3); // Ambient + diffuse
      color += vec3(0.8, 0.9, 1.0) * specular * (1.0 - foam); // Specular only on water
      color += vec3(0.1, 0.2, 0.3) * fresnel; // Fresnel reflection
      
      gl_FragColor = vec4(color, 0.95);
    }
  `,
  
  // Atmosphere shader
  atmosphereVertexShader: `
    
    varying vec3 vNormal;
    varying vec3 vPosition;
    
    void main() {
      vNormal = normalize(normalMatrix * normal);
      vec4 mvPosition = modelViewMatrix * vec4(position, 1.0);
      vPosition = mvPosition.xyz;
      gl_Position = projectionMatrix * mvPosition;
    }
  `,
  
  atmosphereFragmentShader: `
    uniform vec3 glowColor;
    uniform float c;
    uniform float p;
    
    varying vec3 vNormal;
    varying vec3 vPosition;
    
    void main() {
      vec3 viewDir = normalize(-vPosition);
      float intensity = pow(c - dot(vNormal, viewDir), p);
      vec3 glow = glowColor * intensity;
      gl_FragColor = vec4(glow, intensity * 0.4);
    }
  `
};

// Shader uniform configurations
export const createTiledGlobeUniforms = (tileTextures: THREE.Texture[], tileBounds: Float32Array) => {
  return {
    tileTextures: { value: tileTextures },
    tileBounds: { value: tileBounds },
    numTiles: { value: tileTextures.length },
    tileOpacity: { value: 1.0 },
    lightDirection: { value: new THREE.Vector3(1, 1, 0.5).normalize() },
    time: { value: 0 }
  };
};

export const createOceanUniforms = (oceanMask: THREE.Texture, foamTexture: THREE.Texture) => {
  return {
    oceanMask: { value: oceanMask },
    foamTexture: { value: foamTexture },
    deepWaterColor: { value: new THREE.Color(0x003366) },
    shallowWaterColor: { value: new THREE.Color(0x006699) },
    foamColor: { value: new THREE.Color(0xffffff) },
    lightDirection: { value: new THREE.Vector3(1, 1, 0.5).normalize() },
    viewPosition: { value: new THREE.Vector3() },
    time: { value: 0 },
    waveHeight: { value: 0.5 },
    waveFrequency: { value: 0.1 },
    foamThreshold: { value: 0.3 }
  };
};

export const createAtmosphereUniforms = () => {
  return {
    glowColor: { value: new THREE.Color(0x4488ff) },
    c: { value: 0.3 },
    p: { value: 4.5 }
  };
};