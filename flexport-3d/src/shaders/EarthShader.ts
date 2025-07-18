import * as THREE from 'three';

export const EarthShaderMaterial = {
  uniforms: {
    dayTexture: { value: null },
    nightTexture: { value: null },
    cloudsTexture: { value: null },
    sunDirection: { value: new THREE.Vector3(1, 0, 0) },
    atmosphereColor: { value: new THREE.Color(0x4444ff) },
    time: { value: 0 }
  },

  vertexShader: `
    varying vec2 vUv;
    varying vec3 vNormal;
    varying vec3 vPosition;
    
    void main() {
      vUv = uv;
      vNormal = normalize(normalMatrix * normal);
      vPosition = (modelViewMatrix * vec4(position, 1.0)).xyz;
      gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
    }
  `,

  fragmentShader: `
    uniform sampler2D dayTexture;
    uniform sampler2D nightTexture;
    uniform sampler2D cloudsTexture;
    uniform vec3 sunDirection;
    uniform vec3 atmosphereColor;
    uniform float time;
    
    varying vec2 vUv;
    varying vec3 vNormal;
    varying vec3 vPosition;
    
    void main() {
      // Calculate sun angle for day/night blend
      float sunAngle = dot(vNormal, normalize(sunDirection));
      float dayAmount = smoothstep(-0.25, 0.25, sunAngle);
      
      // Sample textures
      vec4 dayColor = texture2D(dayTexture, vUv);
      vec4 nightColor = texture2D(nightTexture, vUv);
      vec4 cloudsColor = texture2D(cloudsTexture, vUv);
      
      // Blend day and night
      vec3 color = mix(nightColor.rgb * 0.3, dayColor.rgb, dayAmount);
      
      // Add clouds with animated offset
      vec2 cloudUv = vUv + vec2(time * 0.01, 0.0);
      vec4 clouds = texture2D(cloudsTexture, cloudUv);
      color = mix(color, vec3(1.0), clouds.r * 0.3 * dayAmount);
      
      // Add atmosphere on edges
      float atmosphere = pow(1.0 - abs(dot(normalize(vPosition), vNormal)), 2.0);
      color += atmosphereColor * atmosphere * 0.3;
      
      // Add specular highlight for oceans
      vec3 viewDirection = normalize(-vPosition);
      vec3 reflectedLight = reflect(-sunDirection, vNormal);
      float specular = pow(max(dot(viewDirection, reflectedLight), 0.0), 20.0);
      
      // Approximate ocean mask (blue channel dominant areas)
      float oceanMask = smoothstep(0.5, 0.6, dayColor.b - max(dayColor.r, dayColor.g));
      color += vec3(0.5, 0.7, 1.0) * specular * oceanMask * dayAmount;
      
      // Fallback color if textures aren't loaded
      if (dayColor.a == 0.0) {
        color = vec3(0.2, 0.4, 0.8); // Blue Earth fallback
      }
      
      gl_FragColor = vec4(color, 1.0);
    }
  `
};