import React, { useRef, useMemo } from 'react';
import { useFrame, useLoader } from '@react-three/fiber';
import * as THREE from 'three';
import { Water } from 'three-stdlib';
import { extend } from '@react-three/fiber';

extend({ Water });

export const Ocean: React.FC = () => {
  const waterRef = useRef<any>(null);
  
  // Load water normal texture
  const waterNormals = useLoader(
    THREE.TextureLoader,
    'https://raw.githubusercontent.com/mrdoob/three.js/master/examples/textures/waternormals.jpg'
  );
  
  waterNormals.wrapS = waterNormals.wrapT = THREE.RepeatWrapping;
  
  const waterConfig = useMemo(() => ({
    textureWidth: 512,
    textureHeight: 512,
    waterNormals,
    sunDirection: new THREE.Vector3(0.7, 0.7, 0),
    sunColor: 0xffffff,
    waterColor: 0x006994,
    distortionScale: 4,
    fog: false,
    alpha: 0.95,
  }), [waterNormals]);
  
  useFrame((state) => {
    if (waterRef.current) {
      waterRef.current.material.uniforms.time.value = state.clock.elapsedTime * 0.5;
    }
  });
  
  // Custom enhanced water shader
  const enhancedWaterShader = useMemo(() => ({
    uniforms: {
      time: { value: 0 },
      tWaterNormals: { value: waterNormals },
      sunDirection: { value: new THREE.Vector3(0.7, 0.7, 0) },
      sunColor: { value: new THREE.Color(0xffffff) },
      waterColor: { value: new THREE.Color(0x006994) },
      eye: { value: new THREE.Vector3(0, 0, 0) },
      distortionScale: { value: 4 },
      foamColor: { value: new THREE.Color(0xffffff) },
      foamScale: { value: 0.15 },
    },
    vertexShader: `
      uniform float time;
      uniform float distortionScale;
      
      varying vec2 vUv;
      varying vec3 vNormal;
      varying vec3 vWorldPosition;
      varying float vWaveHeight;
      
      vec3 getWaveHeight(vec3 pos) {
        float waveA = sin(pos.x * 0.05 + time * 0.5) * cos(pos.z * 0.05 + time * 0.3);
        float waveB = sin(pos.x * 0.08 - time * 0.4) * cos(pos.z * 0.08 + time * 0.6);
        float waveC = sin(pos.x * 0.12 + time * 0.7) * cos(pos.z * 0.12 - time * 0.5);
        
        float height = waveA * 2.0 + waveB * 1.5 + waveC * 1.0;
        return vec3(0.0, height, 0.0);
      }
      
      void main() {
        vUv = uv;
        vec3 newPosition = position + getWaveHeight(position);
        vWaveHeight = newPosition.y;
        
        vec3 neighborA = position + vec3(1.0, 0.0, 0.0);
        neighborA += getWaveHeight(neighborA);
        
        vec3 neighborB = position + vec3(0.0, 0.0, 1.0);
        neighborB += getWaveHeight(neighborB);
        
        vNormal = normalize(cross(neighborB - newPosition, neighborA - newPosition));
        vWorldPosition = (modelMatrix * vec4(newPosition, 1.0)).xyz;
        
        gl_Position = projectionMatrix * modelViewMatrix * vec4(newPosition, 1.0);
      }
    `,
    fragmentShader: `
      uniform float time;
      uniform sampler2D tWaterNormals;
      uniform vec3 sunDirection;
      uniform vec3 sunColor;
      uniform vec3 waterColor;
      uniform vec3 eye;
      uniform float distortionScale;
      uniform vec3 foamColor;
      uniform float foamScale;
      
      varying vec2 vUv;
      varying vec3 vNormal;
      varying vec3 vWorldPosition;
      varying float vWaveHeight;
      
      vec3 getNoise(vec2 uv) {
        vec2 uv0 = (uv / 103.0) + vec2(time / 17.0, time / 29.0);
        vec2 uv1 = uv / 107.0 - vec2(time / -19.0, time / 31.0);
        vec2 uv2 = uv / vec2(897.0, 983.0) + vec2(time / 101.0, time / 97.0);
        vec2 uv3 = uv / vec2(991.0, 877.0) - vec2(time / 109.0, time / -113.0);
        
        vec4 noise = texture2D(tWaterNormals, uv0) +
                     texture2D(tWaterNormals, uv1) +
                     texture2D(tWaterNormals, uv2) +
                     texture2D(tWaterNormals, uv3);
        
        return noise.xyz / 4.0;
      }
      
      void main() {
        vec3 noise = getNoise(vWorldPosition.xz * 0.01);
        vec3 surfaceNormal = normalize(vNormal + noise * distortionScale * 0.1);
        
        vec3 diffuseLight = vec3(0.0);
        vec3 specularLight = vec3(0.0);
        
        vec3 worldToEye = eye - vWorldPosition;
        vec3 eyeDirection = normalize(worldToEye);
        
        // Sun light
        vec3 sunReflection = normalize(reflect(-sunDirection, surfaceNormal));
        float sunSpecular = pow(max(0.0, dot(eyeDirection, sunReflection)), 256.0);
        
        diffuseLight += max(dot(sunDirection, surfaceNormal), 0.0) * sunColor;
        specularLight += sunSpecular * sunColor;
        
        // Fresnel effect
        float theta = max(dot(eyeDirection, surfaceNormal), 0.0);
        float fresnel = pow(1.0 - theta, 3.0);
        
        // Water color with depth
        vec3 waterDepthColor = mix(waterColor * 1.5, waterColor * 0.5, fresnel);
        
        // Foam
        float foam = 0.0;
        foam += smoothstep(1.5, 2.5, vWaveHeight) * 0.5;
        foam += pow(noise.r * noise.g, 3.0) * foamScale;
        foam = clamp(foam, 0.0, 1.0);
        
        // Caustics
        float caustics = pow(max(0.0, noise.r * noise.g * 2.0 - 0.5), 2.0);
        
        // Final color
        vec3 finalColor = waterDepthColor * diffuseLight * 0.9 + specularLight;
        finalColor += caustics * 0.1;
        finalColor = mix(finalColor, foamColor, foam);
        
        gl_FragColor = vec4(finalColor, 0.92);
      }
    `,
  }), [waterNormals]);
  
  return (
    <mesh 
      ref={waterRef} 
      rotation={[-Math.PI / 2, 0, 0]} 
      position={[0, -0.5, 0]}
      receiveShadow
      renderOrder={-1}
    >
      <planeGeometry args={[300, 300, 128, 128]} />
      <shaderMaterial 
        {...enhancedWaterShader} 
        transparent
        side={THREE.DoubleSide}
        depthWrite={true}
        depthTest={true}
      />
    </mesh>
  );
};