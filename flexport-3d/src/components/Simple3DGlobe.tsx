// @ts-nocheck
import React, { Suspense, useRef } from 'react';
import { Canvas, useFrame } from '@react-three/fiber';
import { OrbitControls, Sphere, Stars } from '@react-three/drei';
import * as THREE from 'three';
import { useGameStore } from '../store/gameStore';

interface Simple3DGlobeProps {
  className?: string;
}

// Simple ship component
const SimpleShip = ({ position, color = '#00ff9d' }) => {
  const meshRef = useRef<THREE.Mesh>();
  
  useFrame((state) => {
    if (meshRef.current) {
      meshRef.current.rotation.y += 0.01;
      // Bob up and down
      meshRef.current.position.y = position[1] + Math.sin(state.clock.elapsedTime * 2) * 0.5;
    }
  });

  return (
    <mesh ref={meshRef} position={position}>
      <coneGeometry args={[1, 3, 4]} />
      <meshStandardMaterial color={color} emissive={color} emissiveIntensity={0.5} />
    </mesh>
  );
};

// Earth component
const Earth = () => {
  const earthRef = useRef<THREE.Mesh>();
  
  useFrame(() => {
    if (earthRef.current) {
      earthRef.current.rotation.y += 0.001;
    }
  });

  return (
    <mesh ref={earthRef}>
      <sphereGeometry args={[100, 64, 64]} />
      <meshPhongMaterial 
        color="#2a5a8a"
        emissive="#001a33"
        emissiveIntensity={0.2}
        shininess={10}
      />
    </mesh>
  );
};

export const Simple3DGlobe: React.FC<Simple3DGlobeProps> = ({ className }) => {
  const { fleet } = useGameStore();

  // Calculate position for ships on globe
  const getGlobePosition = (lat: number, lng: number, radius: number = 102) => {
    const phi = (90 - lat) * (Math.PI / 180);
    const theta = (lng + 180) * (Math.PI / 180);
    
    const x = -(radius * Math.sin(phi) * Math.cos(theta));
    const y = radius * Math.cos(phi);
    const z = radius * Math.sin(phi) * Math.sin(theta);
    
    return [x, y, z];
  };

  return (
    <div className={className} style={{ width: '100%', height: '100%', background: '#000814' }}>
      <Canvas camera={{ position: [0, 100, 300], fov: 45 }}>
        <Suspense fallback={null}>
          {/* Lighting */}
          <ambientLight intensity={0.4} />
          <directionalLight 
            position={[100, 100, 50]} 
            intensity={1.2}
            color="#ffffff"
            castShadow
          />
          <pointLight position={[-100, -100, -100]} intensity={0.4} color="#4080ff" />
          
          {/* Stars background */}
          <Stars 
            radius={500} 
            depth={50} 
            count={5000} 
            factor={4} 
            saturation={0} 
            fade 
            speed={1} 
          />
          
          {/* Earth */}
          <Earth />
          
          {/* Grid lines on globe */}
          <mesh>
            <sphereGeometry args={[101, 32, 16]} />
            <meshBasicMaterial 
              color="#00ff9d" 
              wireframe 
              transparent 
              opacity={0.1} 
            />
          </mesh>
          
          {/* Ships */}
          {fleet.map((ship) => {
            const position = getGlobePosition(
              ship.position.lat,
              ship.position.lng
            );
            
            return (
              <SimpleShip
                key={ship.id}
                position={position}
                color={ship.status === 'SAILING' ? '#00ff9d' : '#ffa500'}
              />
            );
          })}
          
          {/* Port markers */}
          {useGameStore.getState().ports.map((port) => {
            const position = getGlobePosition(
              port.position.lat,
              port.position.lng,
              101
            );
            
            return (
              <mesh key={port.id} position={position}>
                <boxGeometry args={[2, 2, 2]} />
                <meshStandardMaterial 
                  color="#ff6b6b" 
                  emissive="#ff6b6b" 
                  emissiveIntensity={0.5} 
                />
              </mesh>
            );
          })}
          
          {/* Camera Controls */}
          <OrbitControls 
            enablePan={false}
            minDistance={150}
            maxDistance={500}
            rotateSpeed={0.5}
            zoomSpeed={0.8}
            autoRotate
            autoRotateSpeed={0.5}
          />
        </Suspense>
      </Canvas>
    </div>
  );
};