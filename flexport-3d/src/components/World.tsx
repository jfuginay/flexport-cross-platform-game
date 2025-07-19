import React, { useMemo } from 'react';
import * as THREE from 'three';
import { SimpleEarth } from './SimpleEarth';
import { EarthPorts } from './EarthPorts';
import { MapCamera } from './MapCamera';

interface WorldProps {
  isEarthRotating: boolean;
  timeOfDay: number;
}

export const World: React.FC<WorldProps> = ({ isEarthRotating, timeOfDay }) => {
  // Simplified - using only SimpleEarth
  
  // Create stable star positions that don't change every frame
  const starPositions = useMemo(() => {
    const positions = new Float32Array(5000 * 3);
    for (let i = 0; i < 5000 * 3; i += 3) {
      // Create stars in a spherical distribution
      const theta = Math.random() * Math.PI * 2;
      const phi = Math.acos(2 * Math.random() - 1);
      const radius = 400 + Math.random() * 100; // Stars at distance 400-500
      
      positions[i] = radius * Math.sin(phi) * Math.cos(theta);
      positions[i + 1] = radius * Math.sin(phi) * Math.sin(theta);
      positions[i + 2] = radius * Math.cos(phi);
    }
    return positions;
  }, []); // Empty dependency array means this only runs once
  
  return (
    <>
      {/* Camera with standard controls */}
      <MapCamera enableMapControls={false} />

      {/* Simple Earth only */}
      <SimpleEarth
        radius={100}
        segments={128}
        isRotating={isEarthRotating}
        rotationSpeed={0.0002}
      >
        <EarthPorts />
      </SimpleEarth>
      
      {/* Grid helper for reference */}
      <gridHelper args={[400, 40]} position={[0, -150, 0]} />
      
      
      {/* Sky sphere */}
      <mesh renderOrder={-10}>
        <sphereGeometry args={[500, 64, 64]} />
        <meshBasicMaterial 
          color={0x000814} 
          side={THREE.BackSide}
          depthWrite={false}
        />
      </mesh>
      
      {/* Stars - Fixed in space, not moving */}
      <points>
        <bufferGeometry>
          <bufferAttribute
            attach="attributes-position"
            count={5000}
            args={[starPositions, 3]}
          />
        </bufferGeometry>
        <pointsMaterial 
          color={0xffffff} 
          size={1.0} 
          sizeAttenuation={true}
          transparent={true}
          opacity={0.8}
        />
      </points>
      
      {/* Volumetric Clouds - temporarily disabled to see Earth */}
      {/* <VolumetricClouds /> */}
      
      {/* Fog temporarily disabled for better visibility */}
      {/* <fog attach="fog" args={[0x000814, 400, 2000]} /> */}
    </>
  );
};