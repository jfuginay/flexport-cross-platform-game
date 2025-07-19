import React, { useMemo, useState } from 'react';
import * as THREE from 'three';
import { SimpleEarth } from './SimpleEarth';
import { AdvancedMapboxEarth } from './AdvancedMapboxEarth';
import { VolumetricClouds } from './VolumetricClouds';
import { EarthPorts } from './EarthPorts';
import { MapCamera } from './MapCamera';
import { Html } from '@react-three/drei';

interface WorldProps {
  isEarthRotating: boolean;
  timeOfDay: number;
}

export const World: React.FC<WorldProps> = ({ isEarthRotating, timeOfDay }) => {
  const [useMapboxEarth, setUseMapboxEarth] = useState(false); // Start with simple Earth
  const [viewMode, setViewMode] = useState<'globe' | 'map'>('globe');
  
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
      {/* Camera with map-like controls */}
      <MapCamera enableMapControls={viewMode === 'map'} />
      
      {/* UI Overlay for controls */}
      <Html fullscreen style={{ pointerEvents: 'none' }}>
        <div style={{ 
          position: 'absolute', 
          top: '20px', 
          right: '20px', 
          display: 'flex',
          flexDirection: 'column',
          gap: '10px',
          pointerEvents: 'auto'
        }}>
          {/* View mode toggle */}
          <div style={{
            background: 'rgba(20, 20, 30, 0.9)',
            border: '1px solid rgba(255, 255, 255, 0.1)',
            borderRadius: '8px',
            padding: '5px',
            display: 'flex',
            gap: '5px'
          }}>
            <button
              onClick={() => setViewMode('globe')}
              style={{
                padding: '8px 16px',
                background: viewMode === 'globe' ? '#3b82f6' : 'transparent',
                color: 'white',
                border: 'none',
                borderRadius: '6px',
                cursor: 'pointer',
                fontSize: '14px',
                fontWeight: '500',
                transition: 'all 0.2s'
              }}
            >
              🌍 Globe
            </button>
            <button
              onClick={() => setViewMode('map')}
              style={{
                padding: '8px 16px',
                background: viewMode === 'map' ? '#3b82f6' : 'transparent',
                color: 'white',
                border: 'none',
                borderRadius: '6px',
                cursor: 'pointer',
                fontSize: '14px',
                fontWeight: '500',
                transition: 'all 0.2s'
              }}
            >
              🗺️ Map
            </button>
          </div>
          
          {/* Earth texture toggle */}
          <button
            onClick={() => setUseMapboxEarth(!useMapboxEarth)}
            style={{
              padding: '10px 20px',
              background: useMapboxEarth ? '#8b5cf6' : '#10b981',
              color: 'white',
              border: 'none',
              borderRadius: '8px',
              cursor: 'pointer',
              fontSize: '14px',
              fontWeight: '500',
              boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
              transition: 'all 0.2s'
            }}
          >
            {useMapboxEarth ? '🌐 Mapbox Earth' : '🌍 Simple Earth'}
          </button>
          
          {/* Controls help */}
          {viewMode === 'map' && (
            <div style={{
              background: 'rgba(20, 20, 30, 0.9)',
              border: '1px solid rgba(255, 255, 255, 0.1)',
              borderRadius: '8px',
              padding: '12px',
              color: '#94a3b8',
              fontSize: '12px',
              lineHeight: '1.5'
            }}>
              <div style={{ color: '#ffffff', fontWeight: '600', marginBottom: '8px' }}>Map Controls:</div>
              <div>🖱️ Click + Drag: Rotate</div>
              <div>🖱️ Right Click + Drag: Pan</div>
              <div>🖱️ Scroll: Zoom</div>
              <div>⌨️ WASD/Arrows: Move</div>
              <div>⌨️ Q/E: Up/Down</div>
            </div>
          )}
        </div>
      </Html>

      {/* Earth with Mapbox or Simple texture */}
      {useMapboxEarth ? (
        <AdvancedMapboxEarth
          radius={100}
          segments={256}
          isRotating={isEarthRotating}
          rotationSpeed={0.0002}
          mapStyle="hybrid"
        >
          <EarthPorts />
        </AdvancedMapboxEarth>
      ) : (
        <SimpleEarth
          radius={100}
          segments={128}
          isRotating={isEarthRotating}
          rotationSpeed={0.0002}
        >
          <EarthPorts />
        </SimpleEarth>
      )}
      
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