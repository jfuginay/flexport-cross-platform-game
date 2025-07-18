import * as THREE from 'three';

export const OceanShader = {
  uniforms: {
    time: { value: 0 },
    waterColor: { value: new THREE.Color(0x001e2f) },
    waterHighlight: { value: new THREE.Color(0x4a8db8) },
    waveHeight: { value: 0.5 },
    waveFrequency: { value: 0.1 },
    waveSpeed: { value: 0.5 },
    foamThreshold: { value: 0.7 },
    foamColor: { value: new THREE.Color(0xffffff) },
    sunDirection: { value: new THREE.Vector3(0.7, 0.5, 0.5) },
    envMap: { value: null },
    roughness: { value: 0.0 },
    metalness: { value: 0.5 },
  },

  vertexShader: `
    precision highp float;
    
    uniform float time;
    uniform float waveHeight;
    uniform float waveFrequency;
    uniform float waveSpeed;
    
    varying vec3 vWorldPosition;
    varying vec3 vNormal;
    varying vec2 vUv;
    varying float vWaveHeight;
    
    // Improved noise function for ocean waves
    vec3 mod289(vec3 x) {
      return x - floor(x * (1.0 / 289.0)) * 289.0;
    }
    
    vec4 mod289(vec4 x) {
      return x - floor(x * (1.0 / 289.0)) * 289.0;
    }
    
    vec4 permute(vec4 x) {
      return mod289(((x*34.0)+1.0)*x);
    }
    
    vec4 taylorInvSqrt(vec4 r) {
      return 1.79284291400159 - 0.85373472095314 * r;
    }
    
    float snoise(vec3 v) {
      const vec2 C = vec2(1.0/6.0, 1.0/3.0);
      const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);
      
      vec3 i  = floor(v + dot(v, C.yyy));
      vec3 x0 = v - i + dot(i, C.xxx);
      
      vec3 g = step(x0.yzx, x0.xyz);
      vec3 l = 1.0 - g;
      vec3 i1 = min(g.xyz, l.zxy);
      vec3 i2 = max(g.xyz, l.zxy);
      
      vec3 x1 = x0 - i1 + C.xxx;
      vec3 x2 = x0 - i2 + C.yyy;
      vec3 x3 = x0 - D.yyy;
      
      i = mod289(i);
      vec4 p = permute(permute(permute(
                i.z + vec4(0.0, i1.z, i2.z, 1.0))
              + i.y + vec4(0.0, i1.y, i2.y, 1.0))
              + i.x + vec4(0.0, i1.x, i2.x, 1.0));
              
      float n_ = 0.142857142857;
      vec3 ns = n_ * D.wyz - D.xzx;
      
      vec4 j = p - 49.0 * floor(p * ns.z * ns.z);
      
      vec4 x_ = floor(j * ns.z);
      vec4 y_ = floor(j - 7.0 * x_);
      
      vec4 x = x_ *ns.x + ns.yyyy;
      vec4 y = y_ *ns.x + ns.yyyy;
      vec4 h = 1.0 - abs(x) - abs(y);
      
      vec4 b0 = vec4(x.xy, y.xy);
      vec4 b1 = vec4(x.zw, y.zw);
      
      vec4 s0 = floor(b0)*2.0 + 1.0;
      vec4 s1 = floor(b1)*2.0 + 1.0;
      vec4 sh = -step(h, vec4(0.0));
      
      vec4 a0 = b0.xzyw + s0.xzyw*sh.xxyy;
      vec4 a1 = b1.xzyw + s1.xzyw*sh.zzww;
      
      vec3 p0 = vec3(a0.xy, h.x);
      vec3 p1 = vec3(a0.zw, h.y);
      vec3 p2 = vec3(a1.xy, h.z);
      vec3 p3 = vec3(a1.zw, h.w);
      
      vec4 norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2,p2), dot(p3,p3)));
      p0 *= norm.x;
      p1 *= norm.y;
      p2 *= norm.z;
      p3 *= norm.w;
      
      vec4 m = max(0.6 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
      m = m * m;
      return 42.0 * dot(m*m, vec4(dot(p0,x0), dot(p1,x1), dot(p2,x2), dot(p3,x3)));
    }
    
    // Generate ocean waves
    float generateWaves(vec3 position) {
      float wave = 0.0;
      float frequency = waveFrequency;
      float amplitude = waveHeight;
      float speed = waveSpeed;
      
      // Multiple octaves for realistic waves
      for(int i = 0; i < 4; i++) {
        float noiseVal = snoise(vec3(position.xz * frequency, time * speed));
        wave += noiseVal * amplitude;
        
        frequency *= 2.0;
        amplitude *= 0.5;
        speed *= 1.5;
      }
      
      return wave;
    }
    
    void main() {
      vUv = uv;
      vec3 pos = position;
      
      // Calculate wave displacement
      float wave = generateWaves(position);
      pos.y += wave;
      
      // Calculate normals for lighting
      float delta = 0.1;
      float waveX1 = generateWaves(position + vec3(delta, 0.0, 0.0));
      float waveX2 = generateWaves(position - vec3(delta, 0.0, 0.0));
      float waveZ1 = generateWaves(position + vec3(0.0, 0.0, delta));
      float waveZ2 = generateWaves(position - vec3(0.0, 0.0, delta));
      
      vec3 tangent = normalize(vec3(delta * 2.0, waveX1 - waveX2, 0.0));
      vec3 bitangent = normalize(vec3(0.0, waveZ1 - waveZ2, delta * 2.0));
      vNormal = normalize(cross(tangent, bitangent));
      
      vWaveHeight = wave;
      vWorldPosition = (modelMatrix * vec4(pos, 1.0)).xyz;
      
      gl_Position = projectionMatrix * modelViewMatrix * vec4(pos, 1.0);
    }
  `,

  fragmentShader: `
    precision highp float;
    
    uniform vec3 waterColor;
    uniform vec3 waterHighlight;
    uniform float foamThreshold;
    uniform vec3 foamColor;
    uniform vec3 sunDirection;
    uniform float roughness;
    uniform float metalness;
    uniform float time;
    
    varying vec3 vWorldPosition;
    varying vec3 vNormal;
    varying vec2 vUv;
    varying float vWaveHeight;
    
    // Fresnel effect
    float fresnel(vec3 viewDirection, vec3 normal) {
      return pow(1.0 + dot(viewDirection, normal), 3.0);
    }
    
    void main() {
      vec3 normal = normalize(vNormal);
      vec3 viewDirection = normalize(cameraPosition - vWorldPosition);
      
      // Base water color with depth
      vec3 color = mix(waterColor, waterHighlight, 0.5 + 0.5 * normal.y);
      
      // Foam on wave peaks
      float foam = smoothstep(foamThreshold - 0.1, foamThreshold + 0.1, vWaveHeight);
      color = mix(color, foamColor, foam * 0.8);
      
      // Add smaller foam details
      float smallFoam = smoothstep(0.4, 0.6, sin(vUv.x * 100.0 + time) * sin(vUv.y * 100.0 - time));
      color = mix(color, foamColor, smallFoam * foam * 0.3);
      
      // Lighting
      float NdotL = max(dot(normal, normalize(sunDirection)), 0.0);
      vec3 diffuse = color * NdotL;
      
      // Specular highlights
      vec3 halfVector = normalize(sunDirection + viewDirection);
      float NdotH = max(dot(normal, halfVector), 0.0);
      float specular = pow(NdotH, 128.0) * (1.0 - roughness);
      
      // Fresnel effect for water edges
      float fresnelFactor = fresnel(viewDirection, normal);
      
      // Combine lighting
      vec3 finalColor = diffuse + vec3(specular) * waterHighlight;
      finalColor = mix(finalColor, waterHighlight, fresnelFactor * 0.5);
      
      // Add atmospheric fog
      float fogFactor = 1.0 - exp(-distance(cameraPosition, vWorldPosition) * 0.0005);
      finalColor = mix(finalColor, vec3(0.7, 0.8, 0.9), fogFactor * 0.3);
      
      gl_FragColor = vec4(finalColor, 0.6);
    }
  `
};