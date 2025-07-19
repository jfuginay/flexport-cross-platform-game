import React, { useRef, useMemo } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';
import { Points, PointMaterial } from '@react-three/drei';

interface WeatherParticlesProps {
  type: 'rain' | 'snow' | 'fog';
  intensity?: number;
  windSpeed?: number;
  windDirection?: THREE.Vector3;
}

export const WeatherParticles: React.FC<WeatherParticlesProps> = ({ 
  type, 
  intensity = 0.5,
  windSpeed = 0.5,
  windDirection = new THREE.Vector3(1, 0, 0)
}) => {
  const pointsRef = useRef<THREE.Points>(null);
  
  // Create particle positions
  const particles = useMemo(() => {
    const count = type === 'fog' ? 1000 : 2000 * intensity;
    const positions = new Float32Array(count * 3);
    const velocities = new Float32Array(count * 3);
    
    for (let i = 0; i < count; i++) {
      // Spread particles around the globe
      const i3 = i * 3;
      positions[i3] = (Math.random() - 0.5) * 600;
      positions[i3 + 1] = Math.random() * 300 + 100;
      positions[i3 + 2] = (Math.random() - 0.5) * 600;
      
      // Initial velocities
      if (type === 'rain') {
        velocities[i3] = windDirection.x * windSpeed;
        velocities[i3 + 1] = -5 - Math.random() * 3;
        velocities[i3 + 2] = windDirection.z * windSpeed;
      } else if (type === 'snow') {
        velocities[i3] = windDirection.x * windSpeed * 0.3;
        velocities[i3 + 1] = -0.5 - Math.random() * 0.5;
        velocities[i3 + 2] = windDirection.z * windSpeed * 0.3;
      } else { // fog
        velocities[i3] = (Math.random() - 0.5) * 0.1;
        velocities[i3 + 1] = (Math.random() - 0.5) * 0.05;
        velocities[i3 + 2] = (Math.random() - 0.5) * 0.1;
      }
    }
    
    return { positions, velocities, count };
  }, [type, intensity, windSpeed, windDirection]);
  
  // Particle material settings
  const material = useMemo(() => {
    switch (type) {
      case 'rain':
        return {
          color: '#aaccff',
          size: 0.5,
          opacity: 0.4,
          transparent: true,
          blending: THREE.AdditiveBlending
        };
      case 'snow':
        return {
          color: '#ffffff',
          size: 1.5,
          opacity: 0.6,
          transparent: true,
          map: null // Could add snowflake texture
        };
      case 'fog':
        return {
          color: '#cccccc',
          size: 20,
          opacity: 0.05,
          transparent: true,
          blending: THREE.NormalBlending
        };
    }
  }, [type]);
  
  useFrame((state, delta) => {
    if (!pointsRef.current) return;
    
    const positions = pointsRef.current.geometry.attributes.position.array as Float32Array;
    const { velocities, count } = particles;
    
    for (let i = 0; i < count; i++) {
      const i3 = i * 3;
      
      // Update positions based on velocity
      positions[i3] += velocities[i3] * delta * 60;
      positions[i3 + 1] += velocities[i3 + 1] * delta * 60;
      positions[i3 + 2] += velocities[i3 + 2] * delta * 60;
      
      // Wrap particles around when they fall too low or drift too far
      if (type === 'rain' || type === 'snow') {
        if (positions[i3 + 1] < -50) {
          positions[i3 + 1] = 300 + Math.random() * 100;
          positions[i3] = (Math.random() - 0.5) * 600;
          positions[i3 + 2] = (Math.random() - 0.5) * 600;
        }
      } else { // fog
        // Keep fog particles within bounds
        if (Math.abs(positions[i3]) > 300) velocities[i3] *= -1;
        if (Math.abs(positions[i3 + 2]) > 300) velocities[i3 + 2] *= -1;
        if (positions[i3 + 1] < 50 || positions[i3 + 1] > 200) velocities[i3 + 1] *= -1;
      }
      
      // Add some turbulence
      if (type === 'snow') {
        positions[i3] += Math.sin(state.clock.elapsedTime + i) * 0.1;
        positions[i3 + 2] += Math.cos(state.clock.elapsedTime + i) * 0.1;
      }
    }
    
    pointsRef.current.geometry.attributes.position.needsUpdate = true;
    
    // Rotate fog particles slowly
    if (type === 'fog') {
      pointsRef.current.rotation.y += 0.0001;
    }
  });
  
  return (
    <Points ref={pointsRef} positions={particles.positions} stride={3}>
      <PointMaterial
        {...material}
        size={material.size}
        sizeAttenuation={true}
        depthWrite={false}
      />
    </Points>
  );
};