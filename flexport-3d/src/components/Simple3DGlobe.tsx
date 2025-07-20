// @ts-nocheck
import React, { Suspense, useRef } from 'react';
import { Canvas, useFrame } from '@react-three/fiber';
import { OrbitControls, Sphere, Stars } from '@react-three/drei';
import * as THREE from 'three';
import { useGameStore } from '../store/gameStore';

interface Simple3DGlobeProps {
  className?: string;
}

// Simple ship component - MUCH LARGER
const SimpleShip = ({ position, color = '#00ff9d' }) => {
  const meshRef = useRef<THREE.Mesh>();
  const lightRef = useRef<THREE.PointLight>();
  
  useFrame((state) => {
    if (meshRef.current) {
      meshRef.current.rotation.y += 0.01;
      // Bob up and down
      meshRef.current.position.y = position[1] + Math.sin(state.clock.elapsedTime * 2) * 2;
    }
    if (lightRef.current) {
      lightRef.current.intensity = 2 + Math.sin(state.clock.elapsedTime * 3) * 0.5;
    }
  });

  return (
    <group position={position}>
      <mesh ref={meshRef}>
        <coneGeometry args={[4, 12, 6]} />
        <meshStandardMaterial 
          color={color} 
          emissive={color} 
          emissiveIntensity={1} 
          metalness={0.8}
          roughness={0.2}
        />
      </mesh>
      <pointLight 
        ref={lightRef}
        color={color} 
        intensity={2} 
        distance={50} 
      />
      {/* Glow sphere around ship */}
      <mesh>
        <sphereGeometry args={[8, 16, 16]} />
        <meshBasicMaterial 
          color={color} 
          transparent 
          opacity={0.3} 
          side={THREE.BackSide}
        />
      </mesh>
    </group>
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
    <group>
      <mesh ref={earthRef}>
        <sphereGeometry args={[100, 64, 64]} />
        <meshPhongMaterial 
          color="#4a90e2"
          emissive="#003366"
          emissiveIntensity={0.5}
          shininess={30}
        />
      </mesh>
      {/* Add continent outlines */}
      <mesh>
        <sphereGeometry args={[101, 32, 32]} />
        <meshBasicMaterial 
          color="#66ff99" 
          wireframe 
          transparent 
          opacity={0.3} 
        />
      </mesh>
    </group>
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
    <div className={className} style={{ width: '100%', height: '100%', background: '#001133' }}>
      <Canvas camera={{ position: [0, 150, 400], fov: 45 }}>
        <Suspense fallback={null}>
          {/* Much brighter lighting */}
          <ambientLight intensity={0.8} />
          <directionalLight 
            position={[100, 100, 50]} 
            intensity={2}
            color="#ffffff"
            castShadow
          />
          <pointLight position={[-100, -100, -100]} intensity={1} color="#4080ff" />
          <pointLight position={[100, -100, 100]} intensity={1} color="#ff8040" />
          
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
          
          {/* Grid lines on globe - more visible */}
          <mesh>
            <sphereGeometry args={[101, 24, 12]} />
            <meshBasicMaterial 
              color="#00ff9d" 
              wireframe 
              transparent 
              opacity={0.4} 
            />
          </mesh>
          
          {/* Add axes helper to see orientation */}
          <axesHelper args={[150]} />
          
          {/* Add a bright marker at LA port location for reference */}
          <mesh position={getGlobePosition(33.73, -118.26, 105)}>
            <sphereGeometry args={[5, 16, 16]} />
            <meshBasicMaterial color="#ffff00" />
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
          
          {/* Port markers - MUCH LARGER */}
          {useGameStore.getState().ports.map((port) => {
            const position = getGlobePosition(
              port.position.lat,
              port.position.lng,
              102
            );
            
            return (
              <group key={port.id} position={position}>
                <mesh>
                  <boxGeometry args={[6, 12, 6]} />
                  <meshStandardMaterial 
                    color="#ff0000" 
                    emissive="#ff0000" 
                    emissiveIntensity={1}
                    metalness={0.5}
                    roughness={0.3}
                  />
                </mesh>
                <pointLight color="#ff0000" intensity={2} distance={40} />
                {/* Port name label */}
                <sprite scale={[30, 10, 1]} position={[0, 20, 0]}>
                  <spriteMaterial color="#ffffff" />
                </sprite>
              </group>
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