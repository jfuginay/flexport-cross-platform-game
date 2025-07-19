// @ts-nocheck
import React, { Suspense, useRef } from 'react';
import { Canvas } from '@react-three/fiber';
import { OrbitControls, PerspectiveCamera, Environment } from '@react-three/drei';
import * as THREE from 'three';
import { World } from './World';
import { Ship } from './Ship';
import { DayNightCycle } from './DayNightCycle';
import { Weather, WeatherState } from './Weather';
import { useGameStore } from '../store/gameStore';

interface Globe3DViewProps {
  className?: string;
}

export const Globe3DView: React.FC<Globe3DViewProps> = ({ className }) => {
  const { fleet, ports } = useGameStore();
  const controlsRef = useRef<any>();

  // Calculate position for ships on globe
  const getGlobePosition = (lat: number, lng: number, radius: number = 100) => {
    const phi = (90 - lat) * (Math.PI / 180);
    const theta = (lng + 180) * (Math.PI / 180);
    
    const x = -(radius * Math.sin(phi) * Math.cos(theta));
    const y = radius * Math.cos(phi);
    const z = radius * Math.sin(phi) * Math.sin(theta);
    
    return new THREE.Vector3(x, y, z);
  };

  return (
    <div className={className} style={{ width: '100%', height: '100%' }}>
      <Canvas shadows camera={{ position: [0, 100, 300], fov: 45 }}>
        <Suspense fallback={null}>
          {/* Lighting */}
          <DayNightCycle />
          <ambientLight intensity={0.3} />
          <directionalLight 
            position={[100, 100, 50]} 
            intensity={1.5}
            castShadow
            shadow-mapSize={[2048, 2048]}
          />
          
          {/* Sky and Environment */}
          <Environment preset="sunset" />
          
          {/* Globe */}
          <World />
          
          {/* Weather Effects */}
          <Weather state={WeatherState.CLEAR} />
          
          {/* Ships */}
          {fleet.map((ship) => {
            const position = getGlobePosition(
              ship.position.lat,
              ship.position.lng,
              101 // Slightly above globe surface
            );
            
            return (
              <Ship
                key={ship.id}
                ship={ship}
                position={position}
              />
            );
          })}
          
          {/* Camera Controls */}
          <OrbitControls 
            ref={controlsRef}
            enablePan={false}
            minDistance={150}
            maxDistance={500}
            rotateSpeed={0.5}
            zoomSpeed={0.5}
          />
          
          <PerspectiveCamera makeDefault position={[0, 100, 300]} />
        </Suspense>
      </Canvas>
    </div>
  );
};