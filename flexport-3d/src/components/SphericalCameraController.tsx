import React, { useRef, useEffect } from 'react';
import { useThree, useFrame } from '@react-three/fiber';
import { OrbitControls } from '@react-three/drei';
import * as THREE from 'three';
import { useGameStore } from '../store/gameStore';

export const SphericalCameraController: React.FC = () => {
  const controlsRef = useRef<any>(null);
  const { camera } = useThree();
  const { selectedShipId, selectedPortId, fleet, ports } = useGameStore();
  
  const targetPosition = useRef(new THREE.Vector3());
  const currentTarget = useRef(new THREE.Vector3());
  const isAnimating = useRef(false);
  const hasInitialTarget = useRef(false);
  
  // Initialize camera position
  useEffect(() => {
    camera.position.set(400, 300, 400);
    camera.lookAt(0, 0, 0);
    console.log('Camera initialized at:', camera.position);
  }, [camera]);
  
  useEffect(() => {
    let target: THREE.Vector3 | null = null;
    
    if (selectedShipId) {
      const ship = fleet.find(s => s.id === selectedShipId);
      if (ship) {
        target = new THREE.Vector3(ship.position.x, ship.position.y, ship.position.z);
      }
    } else if (selectedPortId) {
      const port = ports.find(p => p.id === selectedPortId);
      if (port) {
        target = new THREE.Vector3(port.position.x, port.position.y, port.position.z);
      }
    }
    
    if (target && controlsRef.current) {
      targetPosition.current.copy(target);
      isAnimating.current = true;
      hasInitialTarget.current = true;
    } else if (!hasInitialTarget.current && controlsRef.current) {
      // Reset to default view when nothing is selected
      targetPosition.current.set(0, 0, 0);
      isAnimating.current = true;
    }
  }, [selectedShipId, selectedPortId, fleet, ports]);
  
  useFrame((state, delta) => {
    if (isAnimating.current && controlsRef.current) {
      // Smooth target movement
      currentTarget.current.lerp(targetPosition.current, delta * 3);
      
      // For selected objects, just smoothly focus on them without extreme zoom
      if (selectedShipId || selectedPortId) {
        // Get current camera distance from center
        const currentDistance = camera.position.length();
        
        // Calculate desired camera position
        const targetNormal = currentTarget.current.clone().normalize();
        const desiredDistance = Math.max(currentDistance * 0.8, 180); // Don't get too close
        
        // Position camera looking at the target from a reasonable distance
        const offset = targetNormal.clone().multiplyScalar(desiredDistance);
        const right = new THREE.Vector3().crossVectors(targetNormal, new THREE.Vector3(0, 1, 0)).normalize();
        offset.add(right.multiplyScalar(20)); // Slight side offset
        
        // Smoothly move camera
        camera.position.lerp(offset, delta * 1.5);
      } else {
        // Default view when nothing selected
        const defaultPos = new THREE.Vector3(200, 100, 200);
        camera.position.lerp(defaultPos, delta * 1.5);
      }
      
      // Update controls target
      controlsRef.current.target.copy(currentTarget.current);
      
      // Stop animating when close enough
      if (currentTarget.current.distanceTo(targetPosition.current) < 0.5) {
        isAnimating.current = false;
      }
      
      controlsRef.current.update();
    }
  });
  
  return (
    <OrbitControls 
      ref={controlsRef}
      enablePan={false} // Disable panning for spherical navigation
      enableZoom={true}
      enableRotate={true}
      maxPolarAngle={Math.PI}
      minPolarAngle={0}
      minDistance={150}
      maxDistance={400}
      rotateSpeed={0.6}
      zoomSpeed={1.0}
      enableDamping={true}
      dampingFactor={0.05}
      makeDefault
      target={[0, 0, 0]} // Always orbit around Earth center
      
      // Mouse controls
      mouseButtons={{
        LEFT: THREE.MOUSE.ROTATE,
        MIDDLE: THREE.MOUSE.DOLLY,
        RIGHT: THREE.MOUSE.ROTATE
      }}
      
      // Touch controls
      touches={{
        ONE: THREE.TOUCH.ROTATE,
        TWO: THREE.TOUCH.DOLLY_PAN
      }}
    />
  );
};