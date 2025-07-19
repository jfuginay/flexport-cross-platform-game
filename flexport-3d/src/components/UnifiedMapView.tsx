import React, { useState } from 'react';
import { Canvas } from '@react-three/fiber';
import { PerspectiveCamera } from '@react-three/drei';
import * as THREE from 'three';

// 2D Map Components
import { MapSwitcher } from './MapSwitcher';

// 3D Components
import { World } from './World';
import { Ship } from './Ship';
import { SphericalCameraController } from './SphericalCameraController';
import { DayNightCycle } from './DayNightCycle';
import { Weather, WeatherState } from './Weather';
import { SimpleEarth } from './SimpleEarth';
import { RealisticEarth } from './RealisticEarth';
import { AdvancedMapboxEarth } from './AdvancedMapboxEarth';
import { HDMapboxEarth } from './HDMapboxEarth';
import { BasicMapboxEarth } from './BasicMapboxEarth';
import { MapTilerEarth } from './MapTilerEarth';
import { SimpleMapTilerEarth } from './SimpleMapTilerEarth';
import { AdvancedTiledEarth } from './AdvancedTiledEarth';
import { EarthPorts } from './EarthPorts';

// Store
import { useGameStore } from '../store/gameStore';

export type ViewType = '2d-maps' | '3d-earth' | '3d-custom';

export type Earth3DType = 
  | 'world-component'
  | 'simple-earth'
  | 'realistic-earth'
  | 'advanced-mapbox'
  | 'hd-mapbox'
  | 'basic-mapbox'
  | 'maptiler'
  | 'simple-maptiler'
  | 'advanced-tiled';

interface UnifiedMapViewProps {
  className?: string;
}

const earth3DOptions = [
  { id: 'world-component' as Earth3DType, name: 'World (Default)', description: 'Full world with toggle options' },
  { id: 'simple-earth' as Earth3DType, name: 'Simple Earth', description: 'Procedural canvas texture' },
  { id: 'realistic-earth' as Earth3DType, name: 'Realistic Earth', description: 'High-quality textures' },
  { id: 'advanced-mapbox' as Earth3DType, name: 'Advanced Mapbox', description: 'Dynamic Mapbox tiles' },
  { id: 'hd-mapbox' as Earth3DType, name: 'HD Mapbox', description: 'High-res Mapbox earth' },
  { id: 'basic-mapbox' as Earth3DType, name: 'Basic Mapbox', description: 'Simple Mapbox earth' },
  { id: 'maptiler' as Earth3DType, name: 'MapTiler Earth', description: 'MapTiler satellite' },
  { id: 'simple-maptiler' as Earth3DType, name: 'Simple MapTiler', description: 'Basic MapTiler' },
  { id: 'advanced-tiled' as Earth3DType, name: 'Advanced Tiled', description: 'LOD & ocean shaders' },
];

export const UnifiedMapView: React.FC<UnifiedMapViewProps> = ({ className }) => {
  const [viewType, setViewType] = useState<ViewType>('2d-maps');
  const [earth3DType, setEarth3DType] = useState<Earth3DType>('world-component');
  const [showSelector, setShowSelector] = useState(false);
  
  const { fleet, selectedShipId, selectShip } = useGameStore();
  
  // 3D settings
  const [isEarthRotating] = useState(true);
  const [weatherState] = useState<WeatherState>(WeatherState.CLEAR);
  const [timeOfDay] = useState(12);

  const render3DEarth = () => {
    const earthRadius = 100;
    
    switch (earth3DType) {
      case 'world-component':
        return <World isEarthRotating={isEarthRotating} timeOfDay={timeOfDay} />;
        
      case 'simple-earth':
        return (
          <SimpleEarth radius={earthRadius} segments={128} isRotating={isEarthRotating} rotationSpeed={0.0002}>
            <EarthPorts />
          </SimpleEarth>
        );
        
      case 'realistic-earth':
        return (
          <RealisticEarth radius={earthRadius} segments={128} isRotating={isEarthRotating}>
            <EarthPorts />
          </RealisticEarth>
        );
        
      case 'advanced-mapbox':
        return (
          <AdvancedMapboxEarth radius={earthRadius} segments={256} isRotating={isEarthRotating} rotationSpeed={0.0002}>
            <EarthPorts />
          </AdvancedMapboxEarth>
        );
        
      case 'hd-mapbox':
        return (
          <HDMapboxEarth radius={earthRadius} isRotating={isEarthRotating}>
            <EarthPorts />
          </HDMapboxEarth>
        );
        
      case 'basic-mapbox':
        return (
          <BasicMapboxEarth radius={earthRadius} isRotating={isEarthRotating}>
            <EarthPorts />
          </BasicMapboxEarth>
        );
        
      case 'maptiler':
        return (
          <MapTilerEarth radius={earthRadius} isRotating={isEarthRotating}>
            <EarthPorts />
          </MapTilerEarth>
        );
        
      case 'simple-maptiler':
        return (
          <SimpleMapTilerEarth radius={earthRadius} isRotating={isEarthRotating}>
            <EarthPorts />
          </SimpleMapTilerEarth>
        );
        
      case 'advanced-tiled':
        return (
          <AdvancedTiledEarth radius={earthRadius} isRotating={isEarthRotating}>
            <EarthPorts />
          </AdvancedTiledEarth>
        );
        
      default:
        return <World isEarthRotating={isEarthRotating} timeOfDay={timeOfDay} />;
    }
  };

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

      {/* 3D Earth Type Selector (only show when in 3D mode) */}
      {viewType === '3d-earth' && (
        <>
          <button
            onClick={() => setShowSelector(!showSelector)}
            style={{
              position: 'absolute',
              top: '20px',
              right: '20px',
              zIndex: 1000,
              padding: '10px 20px',
              background: 'rgba(20, 20, 30, 0.9)',
              color: '#ffffff',
              border: '1px solid rgba(255, 255, 255, 0.2)',
              borderRadius: '8px',
              cursor: 'pointer',
              fontSize: '14px',
              fontWeight: '500',
              backdropFilter: 'blur(10px)',
              display: 'flex',
              alignItems: 'center',
              gap: '8px'
            }}
          >
            🌍 {earth3DOptions.find(e => e.id === earth3DType)?.name || 'Select Earth'}
            <span style={{ fontSize: '12px', opacity: 0.7 }}>
              {showSelector ? '▲' : '▼'}
            </span>
          </button>

          {showSelector && (
            <div style={{
              position: 'absolute',
              top: '70px',
              right: '20px',
              zIndex: 1000,
              background: 'rgba(20, 20, 30, 0.95)',
              border: '1px solid rgba(255, 255, 255, 0.2)',
              borderRadius: '12px',
              padding: '20px',
              backdropFilter: 'blur(20px)',
              boxShadow: '0 8px 32px rgba(0,0,0,0.5)',
              maxHeight: '70vh',
              overflowY: 'auto',
              width: '350px'
            }}>
              <h3 style={{ margin: '0 0 20px 0', color: '#ffffff' }}>
                Select 3D Earth Type
              </h3>
              
              {earth3DOptions.map(option => (
                <button
                  key={option.id}
                  onClick={() => {
                    setEarth3DType(option.id);
                    setShowSelector(false);
                  }}
                  style={{
                    width: '100%',
                    padding: '12px 16px',
                    marginBottom: '8px',
                    background: earth3DType === option.id 
                      ? 'rgba(59, 130, 246, 0.2)' 
                      : 'rgba(255, 255, 255, 0.05)',
                    border: earth3DType === option.id
                      ? '1px solid #3b82f6'
                      : '1px solid rgba(255, 255, 255, 0.1)',
                    borderRadius: '8px',
                    color: '#ffffff',
                    cursor: 'pointer',
                    textAlign: 'left',
                    transition: 'all 0.2s',
                    display: 'block'
                  }}
                >
                  <div style={{ fontWeight: '500', marginBottom: '4px' }}>
                    {option.name}
                  </div>
                  <div style={{ fontSize: '12px', color: '#94a3b8' }}>
                    {option.description}
                  </div>
                </button>
              ))}
            </div>
          )}
        </>
      )}

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
          
          {/* Render selected 3D Earth */}
          {render3DEarth()}
          
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