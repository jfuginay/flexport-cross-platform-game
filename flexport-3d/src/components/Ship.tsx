import React, { useRef, useMemo } from 'react';
import { useFrame } from '@react-three/fiber';
import { Text, Box, Sphere, Cone, Cylinder, Line } from '@react-three/drei';
import * as THREE from 'three';
import { Ship as ShipType, ShipType as ShipTypeEnum, ShipStatus } from '../types/game.types';
import { ShipTrail } from './ShipTrail';
import { ShipParticles } from './ShipParticles';

interface ShipProps {
  ship: ShipType;
  onClick?: (ship: ShipType) => void;
  isSelected?: boolean;
}

export const Ship: React.FC<ShipProps> = ({ ship, onClick, isSelected }) => {
  const meshRef = useRef<THREE.Group>(null);
  const shipMeshRef = useRef<THREE.Group>(null);
  
  // Disable frustum culling once when mounted
  React.useEffect(() => {
    if (meshRef.current) {
      meshRef.current.traverse((child) => {
        if ((child as THREE.Mesh).isMesh) {
          (child as THREE.Mesh).frustumCulled = false;
        }
      });
    }
  }, []);
  
  useFrame((state) => {
    if (meshRef.current && shipMeshRef.current) {
      // Calculate ship's position on sphere
      const shipPos = new THREE.Vector3(ship.position.x, ship.position.y, ship.position.z);
      const normalizedPos = shipPos.clone().normalize();
      
      // Orient ship to follow sphere surface
      const up = normalizedPos;
      const shipRotation = (ship as any).rotation || 0;
      
      // Create rotation matrix to align ship with sphere surface
      const rotationMatrix = new THREE.Matrix4();
      const quaternion = new THREE.Quaternion();
      
      // Calculate forward direction
      const forward = new THREE.Vector3(Math.sin(shipRotation), 0, Math.cos(shipRotation));
      
      // Calculate right vector
      const right = new THREE.Vector3().crossVectors(forward, up).normalize();
      
      // Recalculate forward to be perpendicular to up
      forward.crossVectors(up, right).normalize();
      
      // Build rotation matrix
      rotationMatrix.makeBasis(right, up, forward);
      quaternion.setFromRotationMatrix(rotationMatrix);
      
      // Apply rotation
      meshRef.current.quaternion.copy(quaternion);
      
      // Only add subtle bobbing for ships (not planes)
      if (ship.type !== ShipTypeEnum.CARGO_PLANE) {
        // Small bobbing motion on water
        const bobbing = Math.sin(state.clock.elapsedTime * 2 + ship.id.charCodeAt(0)) * 0.2;
        shipMeshRef.current.position.y = bobbing;
        shipMeshRef.current.rotation.z = Math.sin(state.clock.elapsedTime * 1.5) * 0.02;
      }
      
      // Rotate if idle
      if (ship.status === ShipStatus.IDLE) {
        shipMeshRef.current.rotation.y += 0.001;
      }
    }
  });
  
  // Ship colors based on type
  const shipColor = {
    [ShipTypeEnum.CONTAINER]: '#4169E1',
    [ShipTypeEnum.BULK]: '#8B4513',
    [ShipTypeEnum.TANKER]: '#FF6347',
    [ShipTypeEnum.CARGO_PLANE]: '#87CEEB',
  }[ship.type];
  
  // Status indicator color
  const statusColor = {
    [ShipStatus.IDLE]: '#00FF00',
    [ShipStatus.SAILING]: '#0080FF',
    [ShipStatus.LOADING]: '#FFFF00',
    [ShipStatus.UNLOADING]: '#FFA500',
    [ShipStatus.MAINTENANCE]: '#FF0000',
  }[ship.status];
  
  const isPlane = ship.type === ShipTypeEnum.CARGO_PLANE;
  
  // Enhanced metallic materials
  const hullMaterial = useMemo(() => (
    <meshStandardMaterial 
      color={shipColor}
      metalness={0.8}
      roughness={0.2}
      envMapIntensity={1}
    />
  ), [shipColor]);
  
  const bridgeMaterial = useMemo(() => (
    <meshStandardMaterial 
      color="#444444"
      metalness={0.6}
      roughness={0.4}
    />
  ), []);
  
  const glassMaterial = useMemo(() => (
    <meshPhysicalMaterial 
      color="#88CCFF"
      metalness={0.1}
      roughness={0.1}
      transmission={0.8}
      thickness={0.5}
      transparent
    />
  ), []);
  
  return (
    <group
      ref={meshRef}
      position={[ship.position.x, ship.position.y, ship.position.z]}
    >
      {/* Invisible hitbox for reliable raycasting */}
      <mesh
        visible={false}
        onClick={(e) => {
          e.stopPropagation();
          onClick?.(ship);
        }}
        onPointerOver={(e) => {
          e.stopPropagation();
          document.body.style.cursor = 'pointer';
        }}
        onPointerOut={(e) => {
          e.stopPropagation();
          document.body.style.cursor = 'auto';
        }}
      >
        <boxGeometry args={[4, 3, 4]} />
        <meshBasicMaterial transparent opacity={0} />
      </mesh>
      <group ref={shipMeshRef} renderOrder={1}>
      {/* Ship hull/body */}
      {!isPlane ? (
        <group>
          {/* Main hull */}
          <Box args={[2, 0.8, 4]} position={[0, 0, 0]} castShadow receiveShadow>
            {hullMaterial}
          </Box>
          
          {/* Hull details - side panels */}
          <Box args={[2.1, 0.6, 3.8]} position={[0, -0.1, 0]} castShadow>
            <meshStandardMaterial color={shipColor} metalness={0.9} roughness={0.15} />
          </Box>
          
          {/* Bridge */}
          <Box args={[1.5, 0.6, 1]} position={[0, 0.7, -1.5]} castShadow>
            {bridgeMaterial}
          </Box>
          
          {/* Bridge windows */}
          <Box args={[1.4, 0.3, 0.05]} position={[0, 0.8, -1]} castShadow>
            {glassMaterial}
          </Box>
          
          {/* Stack/chimney */}
          <Cone args={[0.2, 0.8, 8]} position={[0, 1.2, -1.5]} castShadow>
            <meshStandardMaterial color="#222222" metalness={0.7} roughness={0.3} />
          </Cone>
          
          {/* Railings */}
          <Box args={[2.2, 0.1, 0.02]} position={[0, 0.5, 2]} castShadow>
            <meshStandardMaterial color="#888888" metalness={0.8} roughness={0.2} />
          </Box>
          <Box args={[2.2, 0.1, 0.02]} position={[0, 0.5, -2]} castShadow>
            <meshStandardMaterial color="#888888" metalness={0.8} roughness={0.2} />
          </Box>
          
          {/* Containers (for container ships) */}
          {ship.type === ShipTypeEnum.CONTAINER && (
            <group position={[0, 0.6, 0.5]}>
              {[...Array(3)].map((_, i) => (
                <Box key={i} args={[0.6, 0.4, 0.8]} position={[i * 0.7 - 0.7, 0, 0]} castShadow>
                  <meshStandardMaterial 
                    color={['#FF0000', '#0000FF', '#00FF00'][i]} 
                    metalness={0.6}
                    roughness={0.4}
                  />
                </Box>
              ))}
            </group>
          )}
        </group>
      ) : (
        /* Cargo plane */
        <group>
          {/* Fuselage */}
          <Box args={[0.8, 0.8, 3]} position={[0, 0, 0]} castShadow>
            <meshStandardMaterial 
              color={shipColor} 
              metalness={0.8}
              roughness={0.2}
            />
          </Box>
          
          {/* Cockpit windows */}
          <Box args={[0.6, 0.4, 0.1]} position={[0, 0.2, 1.4]} castShadow>
            {glassMaterial}
          </Box>
          
          {/* Wings */}
          <Box args={[4, 0.1, 1]} position={[0, 0, 0]} castShadow>
            <meshStandardMaterial 
              color={shipColor} 
              metalness={0.85}
              roughness={0.15}
            />
          </Box>
          
          {/* Engines */}
          <Cylinder args={[0.15, 0.15, 0.5]} position={[1, -0.1, 0.2]} rotation={[0, 0, Math.PI / 2]} castShadow>
            <meshStandardMaterial color="#333333" metalness={0.9} roughness={0.1} />
          </Cylinder>
          <Cylinder args={[0.15, 0.15, 0.5]} position={[-1, -0.1, 0.2]} rotation={[0, 0, Math.PI / 2]} castShadow>
            <meshStandardMaterial color="#333333" metalness={0.9} roughness={0.1} />
          </Cylinder>
          
          {/* Tail */}
          <Box args={[0.1, 1, 0.6]} position={[0, 0.5, -1.5]} castShadow>
            <meshStandardMaterial 
              color={shipColor} 
              metalness={0.8}
              roughness={0.2}
            />
          </Box>
        </group>
      )}
      
      
      {/* Enhanced wake trail using ShipTrail component */}
      {!isPlane && (
        <ShipTrail 
          shipPosition={new THREE.Vector3(ship.position.x, ship.position.y, ship.position.z)}
          isMoving={ship.status === ShipStatus.SAILING}
        />
      )}
      
      {/* Engine particles for ships and planes */}
      {ship.status === ShipStatus.SAILING && (
        <ShipParticles 
          position={isPlane ? [0, -0.3, -1.5] : [0, 1.5, -2]}
          type={isPlane ? 'jet' : 'smoke'}
          intensity={ship.speed}
        />
      )}
      
      {/* Destination line */}
      {ship.destination && (
        <Line
          points={[
            [0, 0, 0],
            [
              ship.destination.position.x - ship.position.x,
              ship.destination.position.y - ship.position.y,
              ship.destination.position.z - ship.position.z,
            ],
          ]}
          color="#00FF00"
          lineWidth={1}
          opacity={0.3}
          transparent
          dashed
        />
      )}
      
      {/* Selection indicator */}
      {isSelected && (
        <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, -0.5, 0]}>
          <ringGeometry args={[2, 2.5, 32]} />
          <meshBasicMaterial color="#FFD700" opacity={0.7} transparent />
        </mesh>
      )}
      </group>
    </group>
  );
};