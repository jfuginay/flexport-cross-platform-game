import React, { useRef, useState, useMemo } from 'react';
import { useFrame } from '@react-three/fiber';
import { Text, Box, Cylinder, Sphere } from '@react-three/drei';
import * as THREE from 'three';
import { Port as PortType } from '../types/game.types';
import { Haptics, ImpactStyle } from '@capacitor/haptics';
import { ShipParticles } from './ShipParticles';

interface PortProps {
  port: PortType;
  onClick?: (port: PortType) => void;
  isSelected?: boolean;
}

export const Port: React.FC<PortProps> = ({ port, onClick, isSelected }) => {
  const meshRef = useRef<THREE.Group>(null);
  const hoverGroupRef = useRef<THREE.Group>(null);
  const [hovered, setHovered] = useState(false);
  
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
    // Animate only the hover group, not the entire port
    if (hoverGroupRef.current && hovered) {
      hoverGroupRef.current.position.y = Math.sin(state.clock.elapsedTime * 2) * 0.2;
    }
  });
  
  const handleClick = async () => {
    // Trigger haptic feedback on mobile
    try {
      await Haptics.impact({ style: ImpactStyle.Medium });
    } catch (e) {
      // Haptics not available (web)
    }
    onClick?.(port);
  };
  
  const color = port.isPlayerOwned ? '#00ff00' : '#ff6b6b';
  
  // Enhanced materials
  const concreteMaterial = useMemo(() => (
    <meshStandardMaterial 
      color="#8b7355"
      roughness={0.9}
      metalness={0.1}
    />
  ), []);
  
  const buildingMaterial = useMemo(() => (
    <meshStandardMaterial 
      color={color}
      metalness={0.3}
      roughness={0.6}
    />
  ), [color]);
  
  const metalMaterial = useMemo(() => (
    <meshStandardMaterial 
      color="#ff6b00"
      metalness={0.8}
      roughness={0.3}
    />
  ), []);
  
  return (
    <group
      ref={meshRef}
      position={[port.position.x, port.position.y, port.position.z]}
    >
      {/* Invisible hitbox for reliable raycasting */}
      <mesh
        visible={false}
        onClick={(e) => {
          e.stopPropagation();
          handleClick();
        }}
        onPointerOver={(e) => {
          e.stopPropagation();
          setHovered(true);
          document.body.style.cursor = 'pointer';
        }}
        onPointerOut={(e) => {
          e.stopPropagation();
          setHovered(false);
          document.body.style.cursor = 'auto';
        }}
      >
        <boxGeometry args={[3, 3, 3]} />
        <meshBasicMaterial transparent opacity={0} />
      </mesh>
      {/* Hover group for animation without affecting raycasting */}
      <group ref={hoverGroupRef}>
        {/* Port base - concrete platform */}
        <Box args={[2, 0.3, 2]} position={[0, 0.15, 0]} castShadow receiveShadow>
          {concreteMaterial}
        </Box>
      
      {/* Port building - main warehouse */}
      <Box args={[1, 1, 1]} position={[0, 0.8, 0]} castShadow>
        {buildingMaterial}
      </Box>
      
      {/* Building details - windows */}
      <Box args={[0.9, 0.25, 0.02]} position={[0, 1.1, 0.51]} castShadow>
        <meshPhysicalMaterial color="#333344" metalness={0.9} roughness={0.1} />
      </Box>
      
      {/* Storage tanks */}
      <Cylinder args={[0.25, 0.25, 0.75]} position={[-0.75, 0.4, -0.5]} castShadow>
        <meshStandardMaterial color="#666666" metalness={0.7} roughness={0.3} />
      </Cylinder>
      <Cylinder args={[0.2, 0.2, 0.6]} position={[-0.75, 0.3, -0.1]} castShadow>
        <meshStandardMaterial color="#888888" metalness={0.7} roughness={0.3} />
      </Cylinder>
      
      {/* Crane with enhanced details */}
      <group position={[0.75, 0, 0]}>
        <Cylinder args={[0.05, 0.05, 1.5]} position={[0, 0.75, 0]} castShadow>
          {metalMaterial}
        </Cylinder>
        <Box args={[0.75, 0.05, 0.05]} position={[0.4, 1.5, 0]} castShadow>
          {metalMaterial}
        </Box>
        {/* Crane hook */}
        <Box args={[0.1, 0.15, 0.1]} position={[0.75, 1.35, 0]} castShadow>
          <meshStandardMaterial color="#333333" metalness={0.9} roughness={0.2} />
        </Box>
      </group>
      
      {/* Port lights */}
      <Sphere args={[0.05]} position={[1, 1.5, 0]} castShadow>
        <meshBasicMaterial color="#FFFF00" />
      </Sphere>
      <Sphere args={[0.05]} position={[-1, 1.5, 0]} castShadow>
        <meshBasicMaterial color="#FFFF00" />
      </Sphere>
      
      {/* Industrial smoke stacks with particles */}
      <group position={[-1, 0, 1.5]}>
        <Cylinder args={[0.2, 0.3, 2]} position={[0, 1, 0]} castShadow>
          <meshStandardMaterial color="#444444" metalness={0.6} roughness={0.4} />
        </Cylinder>
        <ShipParticles position={[0, 2, 0]} type="smoke" intensity={0.3} />
      </group>
      
      {/* Port name */}
      <Text
        position={[0, 2, 0]}
        fontSize={0.3}
        color="white"
        anchorX="center"
        anchorY="middle"
      >
        {port.name}
      </Text>
      
      {/* Capacity indicator */}
      <Text
        position={[0, 1.7, 0]}
        fontSize={0.2}
        color="white"
        anchorX="center"
        anchorY="middle"
      >
        {`${port.availableBerths}/${port.berths} berths`}
      </Text>
      </group>
      
      {/* Loading indicator ring - outside hover group for stable raycasting */}
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.05, 0]}>
        <ringGeometry args={[1.5, 1.8, 32]} />
        <meshBasicMaterial 
          color={hovered ? '#00ffff' : '#0088ff'} 
          opacity={0.5} 
          transparent 
        />
      </mesh>
      
      {/* Selection indicator - outside hover group */}
      {isSelected && (
        <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.1, 0]}>
          <ringGeometry args={[2, 2.3, 32]} />
          <meshBasicMaterial color="#FFD700" opacity={0.8} transparent />
        </mesh>
      )}
    </group>
  );
};