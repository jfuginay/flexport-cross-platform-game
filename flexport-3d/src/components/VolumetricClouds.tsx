import React, { useRef, useMemo } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';

interface CloudProps {
  position: [number, number, number];
  scale?: number;
  opacity?: number;
  speed?: number;
}

const Cloud: React.FC<CloudProps> = ({ position, scale = 1, opacity = 0.8, speed = 0.1 }) => {
  const meshRef = useRef<THREE.Group>(null);
  
  useFrame((state) => {
    if (meshRef.current) {
      meshRef.current.position.x = position[0] + Math.sin(state.clock.elapsedTime * speed) * 2;
      meshRef.current.position.z = position[2] + Math.cos(state.clock.elapsedTime * speed * 0.8) * 1.5;
    }
  });

  const cloudMaterial = useMemo(() => 
    new THREE.MeshPhongMaterial({
      color: 0xffffff,
      transparent: true,
      opacity: opacity,
      flatShading: false,
      side: THREE.DoubleSide,
    }), [opacity]
  );

  return (
    <group ref={meshRef} position={position}>
      {/* Create fluffy cloud using multiple spheres */}
      <mesh position={[0, 0, 0]} material={cloudMaterial} castShadow>
        <sphereGeometry args={[8 * scale, 16, 16]} />
      </mesh>
      <mesh position={[6 * scale, 1, 0]} material={cloudMaterial} castShadow>
        <sphereGeometry args={[6 * scale, 12, 12]} />
      </mesh>
      <mesh position={[-5 * scale, 0, 2]} material={cloudMaterial} castShadow>
        <sphereGeometry args={[7 * scale, 14, 14]} />
      </mesh>
      <mesh position={[3 * scale, -1, -3]} material={cloudMaterial} castShadow>
        <sphereGeometry args={[5 * scale, 10, 10]} />
      </mesh>
      <mesh position={[-3 * scale, 1, 3]} material={cloudMaterial} castShadow>
        <sphereGeometry args={[4 * scale, 8, 8]} />
      </mesh>
      <mesh position={[0, 2, 0]} material={cloudMaterial} castShadow>
        <sphereGeometry args={[5 * scale, 10, 10]} />
      </mesh>
    </group>
  );
};

export const VolumetricClouds: React.FC = () => {
  const cloudsRef = useRef<THREE.Group>(null);
  const shaderRef = useRef<THREE.ShaderMaterial>(null);
  
  // Slowly rotate all clouds and update shader time
  useFrame((state) => {
    if (cloudsRef.current) {
      cloudsRef.current.rotation.y = state.clock.elapsedTime * 0.01;
    }
    if (shaderRef.current) {
      shaderRef.current.uniforms.time.value = state.clock.elapsedTime;
    }
  });

  // Enhanced cloud shader for more realistic appearance
  const cloudShader = useMemo(() => ({
    uniforms: {
      time: { value: 0 },
      cloudColor: { value: new THREE.Color(0xffffff) },
      shadowColor: { value: new THREE.Color(0x8090a0) },
      lightDirection: { value: new THREE.Vector3(0.5, 0.8, 0.3).normalize() },
    },
    vertexShader: `
      varying vec3 vNormal;
      varying vec3 vPosition;
      varying vec2 vUv;
      
      void main() {
        vUv = uv;
        vNormal = normalize(normalMatrix * normal);
        vPosition = (modelViewMatrix * vec4(position, 1.0)).xyz;
        gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
      }
    `,
    fragmentShader: `
      uniform float time;
      uniform vec3 cloudColor;
      uniform vec3 shadowColor;
      uniform vec3 lightDirection;
      
      varying vec3 vNormal;
      varying vec3 vPosition;
      varying vec2 vUv;
      
      float noise(vec3 p) {
        return sin(p.x * 2.0) * sin(p.y * 2.0) * sin(p.z * 2.0);
      }
      
      void main() {
        vec3 normal = normalize(vNormal);
        
        // Calculate lighting
        float light = dot(normal, lightDirection);
        light = clamp(light, 0.0, 1.0);
        
        // Add some noise for cloud texture
        float n = noise(vPosition * 0.05 + time * 0.1);
        light += n * 0.1;
        
        // Mix between light and shadow colors
        vec3 color = mix(shadowColor, cloudColor, light);
        
        // Edge softness
        float edgeFade = 1.0 - pow(abs(dot(normalize(vPosition), normal)), 2.0);
        float opacity = 0.9 * edgeFade;
        
        gl_FragColor = vec4(color, opacity);
      }
    `,
  }), []);

  return (
    <group ref={cloudsRef}>
      {/* Layer 1 - Lower clouds */}
      <Cloud position={[50, 40, -30]} scale={1.5} opacity={0.7} speed={0.05} />
      <Cloud position={[-60, 35, 40]} scale={1.8} opacity={0.6} speed={0.03} />
      <Cloud position={[30, 38, 60]} scale={1.2} opacity={0.8} speed={0.04} />
      <Cloud position={[-40, 42, -50]} scale={1.6} opacity={0.65} speed={0.06} />
      
      {/* Layer 2 - Mid clouds */}
      <Cloud position={[80, 55, 20]} scale={2.0} opacity={0.5} speed={0.02} />
      <Cloud position={[-70, 50, -30]} scale={1.7} opacity={0.55} speed={0.025} />
      <Cloud position={[20, 52, -70]} scale={1.4} opacity={0.6} speed={0.035} />
      
      {/* Layer 3 - High clouds */}
      <Cloud position={[0, 70, 0]} scale={2.5} opacity={0.4} speed={0.01} />
      <Cloud position={[-90, 65, 50]} scale={2.2} opacity={0.35} speed={0.015} />
      <Cloud position={[100, 68, -40]} scale={2.0} opacity={0.45} speed={0.018} />
      
      {/* Animated shader clouds for extra detail - removed due to rendering issues */}
    </group>
  );
};