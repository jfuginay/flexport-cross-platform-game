// @ts-nocheck
import React, { useRef, useMemo } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';
import { OceanShader } from '../shaders/OceanShader';

interface RealisticOceanProps {
  radius?: number;
  segments?: number;
}

export const RealisticOcean: React.FC<RealisticOceanProps> = ({ 
  radius = 100, 
  segments = 256 
}) => {
  const meshRef = useRef<THREE.Mesh>(null);
  
  // Create ocean material with custom shader
  const oceanMaterial = useMemo(() => {
    const material = new THREE.ShaderMaterial({
      uniforms: {
        ...OceanShader.uniforms,
        time: { value: 0 },
        waveHeight: { value: 0.3 },
        waveFrequency: { value: 0.02 },
        waveSpeed: { value: 0.3 },
      },
      vertexShader: OceanShader.vertexShader,
      fragmentShader: OceanShader.fragmentShader,
      transparent: true,
      side: THREE.DoubleSide,
    });
    
    return material;
  }, []);
  
  // Animate ocean
  useFrame((state) => {
    if (meshRef.current && oceanMaterial) {
      // Update time uniform
      oceanMaterial.uniforms.time.value = state.clock.elapsedTime;
      
      // Adjust wave parameters based on weather
      const targetWaveHeight = 0.3;
      
      // Smooth transition
      oceanMaterial.uniforms.waveHeight.value = THREE.MathUtils.lerp(
        oceanMaterial.uniforms.waveHeight.value,
        targetWaveHeight,
        0.01
      );
      
      // Update sun direction based on time of day
      const timeOfDay = (state.clock.elapsedTime * 0.01) % 1;
      const sunAngle = timeOfDay * Math.PI * 2;
      oceanMaterial.uniforms.sunDirection.value.set(
        Math.cos(sunAngle),
        Math.sin(sunAngle) * 0.5 + 0.5,
        Math.sin(sunAngle)
      );
    }
  });
  
  return (
    <mesh ref={meshRef} material={oceanMaterial}>
      <sphereGeometry args={[radius, segments, segments]} />
    </mesh>
  );
};