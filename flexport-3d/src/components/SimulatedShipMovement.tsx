import { useEffect, useRef } from 'react';
import * as THREE from 'three';
import { useGameStore } from '../store/gameStore';
import { getWaterRouteBetweenPorts } from '../utils/routeValidation';
import { Ship, ShipStatus } from '../types/game.types';

// Realistic ship speeds in knots (nautical miles per hour)
const SHIP_SPEEDS = {
  CONTAINER: 24,  // Modern container ships
  BULK: 15,       // Bulk carriers
  TANKER: 16,     // Oil tankers
  CARGO_PLANE: 500 // Cargo planes (much faster)
};

// Convert knots to units per second for our simulation
const KNOTS_TO_UNITS_PER_SECOND = 0.01; // Adjusted for visual appeal

export const SimulatedShipMovement = () => {
  const animationFrameRef = useRef<number | null>(null);
  const lastUpdateRef = useRef<number>(Date.now());
  
  useEffect(() => {
    const animate = () => {
      const now = Date.now();
      const deltaTime = (now - lastUpdateRef.current) / 1000; // Convert to seconds
      lastUpdateRef.current = now;
      
      const state = useGameStore.getState();
      const { fleet } = state;
      
      // Update each sailing ship
      const updatedFleet = fleet.map(ship => {
        if (ship.status !== 'SAILING' || !ship.destination) {
          return ship;
        }
        
        // Get ship's current position
        const currentPos = new THREE.Vector3(ship.position.x, ship.position.y, ship.position.z);
        
        // Initialize waypoints if not set
        if (!ship.waypoints || ship.waypoints.length === 0) {
          const destPos = new THREE.Vector3(
            ship.destination.position.x,
            ship.destination.position.y,
            ship.destination.position.z
          );
          const waypoints = getWaterRouteBetweenPorts(currentPos, destPos, 100);
          return {
            ...ship,
            waypoints,
            currentWaypointIndex: 0
          };
        }
        
        // Get current target waypoint
        const waypointIndex = ship.currentWaypointIndex ?? 0;
        const targetWaypoint = ship.waypoints[waypointIndex];
        if (!targetWaypoint) {
          // Arrived at destination
          return {
            ...ship,
            status: 'UNLOADING' as ShipStatus,
            position: ship.destination.position,
            waypoints: undefined,
            currentWaypointIndex: 0,
            unloadingStartTime: now
          } as Ship;
        }
        
        // Calculate distance to waypoint
        const distance = currentPos.distanceTo(targetWaypoint);
        
        // Calculate speed based on ship type
        const speedKnots = SHIP_SPEEDS[ship.type];
        const speedUnitsPerSecond = speedKnots * KNOTS_TO_UNITS_PER_SECOND;
        const moveDistance = speedUnitsPerSecond * deltaTime;
        
        if (distance <= moveDistance) {
          // Reached waypoint, move to next
          return {
            ...ship,
            position: {
              x: targetWaypoint.x,
              y: targetWaypoint.y,
              z: targetWaypoint.z
            },
            currentWaypointIndex: waypointIndex + 1
          };
        }
        
        // Move towards waypoint
        const direction = targetWaypoint.clone().sub(currentPos).normalize();
        const movement = direction.multiplyScalar(moveDistance);
        const newPosition = currentPos.add(movement);
        
        // Calculate rotation to face movement direction
        const rotation = Math.atan2(direction.z, -direction.x);
        
        return {
          ...ship,
          position: {
            x: newPosition.x,
            y: newPosition.y,
            z: newPosition.z
          },
          rotation
        };
      });
      
      // Update the store with new fleet positions
      if (updatedFleet.some((ship, i) => 
        ship.position.x !== fleet[i].position.x ||
        ship.position.y !== fleet[i].position.y ||
        ship.position.z !== fleet[i].position.z
      )) {
        useGameStore.setState({ fleet: updatedFleet });
      }
      
      animationFrameRef.current = requestAnimationFrame(animate);
    };
    
    animationFrameRef.current = requestAnimationFrame(animate);
    
    return () => {
      if (animationFrameRef.current !== null) {
        cancelAnimationFrame(animationFrameRef.current);
      }
    };
  }, []);
  
  return null;
};