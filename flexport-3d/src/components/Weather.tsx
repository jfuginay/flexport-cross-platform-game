import React, { useRef, useMemo } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';

export enum WeatherState {
  CLEAR = 'CLEAR',
  CLOUDY = 'CLOUDY',
  RAINY = 'RAINY',
  STORMY = 'STORMY'
}

interface WeatherProps {
  weatherState: WeatherState;
}

export const Weather: React.FC<WeatherProps> = ({ weatherState }) => {
  const rainRef = useRef<THREE.Points>(null);
  
  const rainGeometry = useMemo(() => {
    const geometry = new THREE.BufferGeometry();
    const particleCount = weatherState === WeatherState.STORMY ? 5000 : 2000;
    const positions = new Float32Array(particleCount * 3);
    const velocities = new Float32Array(particleCount);
    
    for (let i = 0; i < particleCount; i++) {
      positions[i * 3] = (Math.random() - 0.5) * 200;
      positions[i * 3 + 1] = Math.random() * 100;
      positions[i * 3 + 2] = (Math.random() - 0.5) * 200;
      velocities[i] = 0.5 + Math.random() * 0.5;
    }
    
    geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    geometry.setAttribute('velocity', new THREE.BufferAttribute(velocities, 1));
    
    return geometry;
  }, [weatherState]);
  
  const rainMaterial = useMemo(() => {
    return new THREE.PointsMaterial({
      color: 0xaaaaaa,
      size: weatherState === WeatherState.STORMY ? 0.3 : 0.2,
      transparent: true,
      opacity: weatherState === WeatherState.STORMY ? 0.8 : 0.6,
      blending: THREE.AdditiveBlending,
    });
  }, [weatherState]);
  
  useFrame((state, delta) => {
    if (!rainRef.current || (weatherState !== WeatherState.RAINY && weatherState !== WeatherState.STORMY)) return;
    
    const positions = rainRef.current.geometry.attributes.position;
    const velocities = rainRef.current.geometry.attributes.velocity;
    
    for (let i = 0; i < positions.count; i++) {
      positions.array[i * 3 + 1] -= velocities.array[i] * delta * 50;
      
      if (positions.array[i * 3 + 1] < -10) {
        positions.array[i * 3 + 1] = 100;
        positions.array[i * 3] = (Math.random() - 0.5) * 200;
        positions.array[i * 3 + 2] = (Math.random() - 0.5) * 200;
      }
    }
    
    positions.needsUpdate = true;
  });
  
  if (weatherState === WeatherState.CLEAR || weatherState === WeatherState.CLOUDY) {
    return null;
  }
  
  return (
    <>
      <points ref={rainRef} geometry={rainGeometry} material={rainMaterial} />
      {weatherState === WeatherState.STORMY && (
        <fog attach="fog" args={['#333333', 10, 150]} />
      )}
    </>
  );
};