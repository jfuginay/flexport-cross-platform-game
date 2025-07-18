import React, { useRef, useMemo } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';

interface ShipParticlesProps {
  position: [number, number, number];
  type: 'smoke' | 'jet' | 'steam';
  intensity: number;
}

export const ShipParticles: React.FC<ShipParticlesProps> = ({ position, type, intensity }) => {
  const meshRef = useRef<THREE.Group>(null);
  const particleCount = type === 'jet' ? 30 : 20;
  
  // Create simple particle sprites instead of points for better compatibility
  const particles = useMemo(() => {
    const parts = [];
    
    for (let i = 0; i < particleCount; i++) {
      const delay = i * 0.1;
      parts.push({ 
        id: i, 
        delay,
        initialSpeed: {
          x: (Math.random() - 0.5) * (type === 'jet' ? 0.5 : 1),
          y: type === 'jet' ? (Math.random() - 0.5) * 0.3 : Math.random() * 2 + 1,
          z: type === 'jet' ? -Math.random() * 3 - 2 : (Math.random() - 0.5) * 1,
        }
      });
    }
    
    return parts;
  }, [particleCount, type]);
  
  useFrame((state) => {
    if (!meshRef.current) return;
    
    meshRef.current.children.forEach((child, i) => {
      const particle = particles[i];
      const time = state.clock.elapsedTime + particle.delay;
      const lifecycle = (time * intensity) % 1;
      
      // Reset position and move particle
      child.position.x = particle.initialSpeed.x * lifecycle * 2;
      child.position.y = particle.initialSpeed.y * lifecycle * 2;
      child.position.z = particle.initialSpeed.z * lifecycle * 2;
      
      // Fade out
      child.scale.setScalar((1 - lifecycle) * 0.5);
      if (child instanceof THREE.Mesh && child.material instanceof THREE.MeshBasicMaterial) {
        child.material.opacity = (1 - lifecycle) * 0.6;
      }
    });
  });
  
  const particleColor = {
    smoke: '#666666',
    jet: '#CCDDFF',
    steam: '#FFFFFF',
  }[type];
  
  return (
    <group ref={meshRef} position={position}>
      {particles.map((particle) => (
        <mesh key={particle.id}>
          <sphereGeometry args={[0.1, 4, 4]} />
          <meshBasicMaterial 
            color={particleColor} 
            transparent 
            opacity={0.6}
            depthWrite={false}
          />
        </mesh>
      ))}
    </group>
  );
};