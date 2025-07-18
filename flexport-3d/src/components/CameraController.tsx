import React, { useRef, useEffect } from 'react';
import { useThree, useFrame } from '@react-three/fiber';
import { OrbitControls } from '@react-three/drei';
import * as THREE from 'three';
import { useGameStore } from '../store/gameStore';

export const CameraController: React.FC = () => {
  const controlsRef = useRef<any>(null);
  const { camera } = useThree();
  const { selectedShipId, selectedPortId, fleet, ports } = useGameStore();
  
  const targetPosition = useRef(new THREE.Vector3());
  const currentTarget = useRef(new THREE.Vector3());
  const isAnimating = useRef(false);
  
  useEffect(() => {
    let target: THREE.Vector3 | null = null;
    
    if (selectedShipId) {
      const ship = fleet.find(s => s.id === selectedShipId);
      if (ship) {
        target = new THREE.Vector3(ship.position.x, ship.position.y + 20, ship.position.z + 20);
      }
    } else if (selectedPortId) {
      const port = ports.find(p => p.id === selectedPortId);
      if (port) {
        target = new THREE.Vector3(port.position.x, port.position.y + 25, port.position.z + 25);
      }
    }
    
    if (target && controlsRef.current) {
      targetPosition.current.copy(target);
      isAnimating.current = true;
    }
  }, [selectedShipId, selectedPortId, fleet, ports]);
  
  useFrame((state, delta) => {
    if (isAnimating.current && controlsRef.current) {
      // Smooth camera movement
      currentTarget.current.lerp(targetPosition.current, delta * 2);
      controlsRef.current.target.copy(currentTarget.current);
      
      // Update camera position to maintain relative view
      const offset = new THREE.Vector3(0, 30, 30);
      const desiredCameraPos = currentTarget.current.clone().add(offset);
      camera.position.lerp(desiredCameraPos, delta * 2);
      
      // Stop animating when close enough
      if (currentTarget.current.distanceTo(targetPosition.current) < 0.1) {
        isAnimating.current = false;
      }
      
      controlsRef.current.update();
    }
  });
  
  return (
    <OrbitControls 
      ref={controlsRef}
      enablePan={true}
      enableZoom={true}
      enableRotate={true}
      maxPolarAngle={Math.PI / 2.2}
      minPolarAngle={0.2}
      minDistance={15}
      maxDistance={150}
      panSpeed={1.5}
      rotateSpeed={0.8}
      zoomSpeed={1.2}
      enableDamping={true}
      dampingFactor={0.05}
      makeDefault
      
      // Mouse controls
      mouseButtons={{
        LEFT: THREE.MOUSE.ROTATE,
        MIDDLE: THREE.MOUSE.DOLLY,
        RIGHT: THREE.MOUSE.PAN
      }}
      
      // Touch controls
      touches={{
        ONE: THREE.TOUCH.ROTATE,
        TWO: THREE.TOUCH.DOLLY_PAN
      }}
    />
  );
};