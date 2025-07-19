// @ts-nocheck
import React, { useRef, useEffect } from 'react';
import { useThree, useFrame } from '@react-three/fiber';
import { OrbitControls } from '@react-three/drei';
import * as THREE from 'three';

interface MapCameraProps {
  enableMapControls?: boolean;
}

export const MapCamera: React.FC<MapCameraProps> = ({ enableMapControls = false }) => {
  const { camera, gl } = useThree();
  const controlsRef = useRef<any>(null);
  
  useEffect(() => {
    // Set initial camera position for globe view
    camera.position.set(0, 150, 300);
    camera.lookAt(0, 0, 0);
  }, [camera]);

  // Add keyboard controls for map-like navigation
  useEffect(() => {
    if (!enableMapControls) return;

    const handleKeyDown = (e: KeyboardEvent) => {
      const moveSpeed = 10;
      const rotateSpeed = 0.05;

      switch(e.key) {
        case 'w':
        case 'ArrowUp':
          camera.position.z -= moveSpeed;
          break;
        case 's':
        case 'ArrowDown':
          camera.position.z += moveSpeed;
          break;
        case 'a':
        case 'ArrowLeft':
          camera.position.x -= moveSpeed;
          break;
        case 'd':
        case 'ArrowRight':
          camera.position.x += moveSpeed;
          break;
        case 'q':
          camera.position.y += moveSpeed;
          break;
        case 'e':
          camera.position.y -= moveSpeed;
          break;
      }
      
      camera.lookAt(0, 0, 0);
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [camera, enableMapControls]);

  return (
    <OrbitControls
      ref={controlsRef}
      enablePan={true}
      enableZoom={true}
      enableRotate={true}
      minDistance={150}
      maxDistance={800}
      maxPolarAngle={Math.PI * 0.85}
      minPolarAngle={Math.PI * 0.15}
      rotateSpeed={0.8}
      panSpeed={1}
      zoomSpeed={1.2}
      // Enable damping for smooth movement
      enableDamping={true}
      dampingFactor={0.05}
    />
  );
};