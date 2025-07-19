import React, { useState } from 'react';
import { Canvas } from '@react-three/fiber';
import { PerspectiveCamera } from '@react-three/drei';
import * as THREE from 'three';

// 2D Map Components
import { MapSwitcher } from './MapSwitcher';

// 3D Components
import { Ship } from './Ship';
import { SphericalCameraController } from './SphericalCameraController';
import { DayNightCycle } from './DayNightCycle';
import { Weather, WeatherState } from './Weather';
import { RealisticEarth } from './RealisticEarth';
import { EarthPorts } from './EarthPorts';

// Store
import { useGameStore } from '../store/gameStore';

export type ViewType = '2d-maps' | '3d-earth';

interface UnifiedMapViewProps {
  className?: string;
}

export const UnifiedMapView: React.FC<UnifiedMapViewProps> = ({ className }) => {
  const [viewType, setViewType] = useState<ViewType>('3d-earth');
  
  const { fleet, selectedShipId, selectShip } = useGameStore();
  
  // 3D settings
  const [isEarthRotating] = useState(true);
  const [weatherState] = useState<WeatherState>(WeatherState.CLEAR);
  const [timeOfDay] = useState(12);


  return (
    <div style={{ width: '100%', height: '100%', position: 'relative' }} className={className}>
      {/* View Type Selector */}
      <div style={{
        position: 'absolute',
        top: '20px',
        left: '20px',
        zIndex: 1000,
        display: 'flex',
        gap: '10px'
      }}>
        <button
          onClick={() => setViewType('2d-maps')}
          style={{
            padding: '10px 20px',
            background: viewType === '2d-maps' ? '#3b82f6' : 'rgba(20, 20, 30, 0.9)',
            color: '#ffffff',
            border: '1px solid rgba(255, 255, 255, 0.2)',
            borderRadius: '8px',
            cursor: 'pointer',
            fontSize: '14px',
            fontWeight: '500',
            backdropFilter: 'blur(10px)',
            transition: 'all 0.2s'
          }}
        >
          🗺️ 2D Maps
        </button>
        
        <button
          onClick={() => setViewType('3d-earth')}
          style={{
            padding: '10px 20px',
            background: viewType === '3d-earth' ? '#3b82f6' : 'rgba(20, 20, 30, 0.9)',
            color: '#ffffff',
            border: '1px solid rgba(255, 255, 255, 0.2)',
            borderRadius: '8px',
            cursor: 'pointer',
            fontSize: '14px',
            fontWeight: '500',
            backdropFilter: 'blur(10px)',
            transition: 'all 0.2s'
          }}
        >
          🌍 3D Earth
        </button>
      </div>


      {/* Render based on view type */}
      {viewType === '2d-maps' ? (
        <MapSwitcher className={className} />
      ) : (
        <Canvas 
          shadows 
          gl={{ 
            antialias: true, 
            alpha: false,
            toneMapping: THREE.ACESFilmicToneMapping,
            toneMappingExposure: 1.0
          }}
          style={{ width: '100%', height: '100%' }}
        >
          <PerspectiveCamera 
            makeDefault 
            position={[400, 300, 400]} 
            fov={45}
            near={1}
            far={10000}
          />
          <SphericalCameraController />
          
          <ambientLight intensity={0.8} />
          <directionalLight
            position={[100, 100, 50]}
            intensity={1.5}
            castShadow
            shadow-mapSize={[2048, 2048]}
            color={0xffffff}
          />
          
          <DayNightCycle timeOfDay={timeOfDay} />
          <Weather weatherState={weatherState} />
          
          {/* Realistic Earth - the best looking option with continents and water */}
          <RealisticEarth radius={100} segments={128} isRotating={isEarthRotating}>
            <EarthPorts />
          </RealisticEarth>
          
          {/* Ships */}
          {fleet.map(ship => (
            <Ship
              key={ship.id}
              ship={ship}
              onClick={(ship) => selectShip(ship.id)}
              isSelected={selectedShipId === ship.id}
            />
          ))}
          
          {/* Grid helper */}
          <gridHelper args={[400, 40]} position={[0, -150, 0]} />
        </Canvas>
      )}
    </div>
  );
};