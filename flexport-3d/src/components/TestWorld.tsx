// @ts-nocheck
import React, { useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';

export const TestWorld: React.FC = () => {
  const meshRef = useRef<THREE.Mesh>(null);
  
  useFrame((state, delta) => {
    if (meshRef.current) {
      meshRef.current.rotation.x += delta * 0.5;
      meshRef.current.rotation.y += delta * 0.5;
    }
  });
  
  console.log('TestWorld rendering');
  
  return (
    <>
      {/* Ambient light for overall illumination */}
      <ambientLight intensity={0.5} />
      
      {/* Directional light */}
      <directionalLight position={[10, 10, 5]} intensity={1} />
      
      {/* Grid helper */}
      <gridHelper args={[200, 20]} />
      
      {/* Axes helper */}
      <axesHelper args={[100]} />
      
      {/* Simple rotating cube to test rendering */}
      <mesh ref={meshRef} position={[0, 0, 0]}>
        <boxGeometry args={[50, 50, 50]} />
        <meshNormalMaterial />
      </mesh>
      
      {/* Earth sphere */}
      <mesh position={[0, 0, 0]}>
        <sphereGeometry args={[100, 32, 32]} />
        <meshBasicMaterial color={0x4444ff} wireframe />
      </mesh>
      
      {/* Small reference cube */}
      <mesh position={[150, 0, 0]}>
        <boxGeometry args={[20, 20, 20]} />
        <meshStandardMaterial color="red" />
      </mesh>
      
      {/* Text to confirm rendering */}
      <mesh position={[0, 150, 0]}>
        <boxGeometry args={[50, 10, 1]} />
        <meshBasicMaterial color="white" />
      </mesh>
    </>
  );
};