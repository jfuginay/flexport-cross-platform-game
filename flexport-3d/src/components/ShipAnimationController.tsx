import { useEffect, useRef } from 'react';
import { useFrame, useThree } from '@react-three/fiber';
import * as THREE from 'three';
import { useGameStore } from '../store/gameStore';

interface ShipAnimationControllerProps {
  focusShipId?: string | null;
  followShip?: boolean;
}

export const ShipAnimationController: React.FC<ShipAnimationControllerProps> = ({ 
  focusShipId, 
  followShip = false 
}) => {
  const { camera } = useThree();
  const { fleet, selectedShipId } = useGameStore();
  const targetPositionRef = useRef(new THREE.Vector3());
  const currentLookAtRef = useRef(new THREE.Vector3());
  const isTransitioningRef = useRef(false);
  const transitionStartRef = useRef(0);
  const transitionDurationRef = useRef(2000); // 2 seconds
  const initialCameraPositionRef = useRef(new THREE.Vector3());
  const initialLookAtRef = useRef(new THREE.Vector3());

  // Focus on selected ship when it changes or starts a new journey
  useEffect(() => {
    const shipToFocus = focusShipId || selectedShipId;
    if (!shipToFocus) return;

    const ship = fleet.find(s => s.id === shipToFocus);
    if (!ship) return;

    // Only focus if ship is sailing or just started a journey
    if (ship.status === 'SAILING' && ship.destination) {
      // Store initial camera state
      initialCameraPositionRef.current.copy(camera.position);
      
      // Calculate target position for camera (offset from ship)
      const shipPos = new THREE.Vector3(ship.position.x, ship.position.y, ship.position.z);
      const normalizedShipPos = shipPos.clone().normalize();
      
      // Position camera above and behind the ship
      const cameraOffset = normalizedShipPos.clone().multiplyScalar(180); // 180 units from center
      const tangent = new THREE.Vector3().crossVectors(normalizedShipPos, new THREE.Vector3(0, 1, 0)).normalize();
      cameraOffset.add(tangent.multiplyScalar(50)); // Offset to the side
      
      targetPositionRef.current.copy(cameraOffset);
      currentLookAtRef.current.copy(shipPos);
      
      // Start transition
      isTransitioningRef.current = true;
      transitionStartRef.current = Date.now();
      transitionDurationRef.current = 2000; // 2 second transition
    }
  }, [focusShipId, selectedShipId, fleet, camera]);

  useFrame(() => {
    if (!isTransitioningRef.current && !followShip) return;

    const now = Date.now();
    
    // Handle camera transition to ship
    if (isTransitioningRef.current) {
      const elapsed = now - transitionStartRef.current;
      const progress = Math.min(elapsed / transitionDurationRef.current, 1);
      
      // Smooth easing function
      const easeInOutCubic = (t: number) => {
        return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
      };
      
      const easedProgress = easeInOutCubic(progress);
      
      // Interpolate camera position
      camera.position.lerpVectors(
        initialCameraPositionRef.current,
        targetPositionRef.current,
        easedProgress
      );
      
      // Look at the ship
      camera.lookAt(currentLookAtRef.current);
      
      if (progress >= 1) {
        isTransitioningRef.current = false;
      }
    }
    
    // Follow selected ship if enabled
    if (followShip && selectedShipId) {
      const ship = fleet.find(s => s.id === selectedShipId);
      if (ship && ship.status === 'SAILING') {
        const shipPos = new THREE.Vector3(ship.position.x, ship.position.y, ship.position.z);
        const normalizedShipPos = shipPos.clone().normalize();
        
        // Keep camera at fixed distance from ship
        const cameraOffset = normalizedShipPos.clone().multiplyScalar(180);
        const tangent = new THREE.Vector3().crossVectors(normalizedShipPos, new THREE.Vector3(0, 1, 0)).normalize();
        cameraOffset.add(tangent.multiplyScalar(50));
        
        // Smooth camera follow
        camera.position.lerp(cameraOffset, 0.05);
        camera.lookAt(shipPos);
      }
    }
  });

  return null;
};