import React, { useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';

interface DayNightCycleProps {
  timeOfDay: number; // 0-24 hours
}

export const DayNightCycle: React.FC<DayNightCycleProps> = ({ timeOfDay }) => {
  const sunRef = useRef<THREE.DirectionalLight>(null);
  const moonRef = useRef<THREE.PointLight>(null);
  const ambientRef = useRef<THREE.AmbientLight>(null);
  
  useFrame(() => {
    if (!sunRef.current || !moonRef.current || !ambientRef.current) return;
    
    // Calculate sun position
    const sunAngle = (timeOfDay / 24) * Math.PI * 2 - Math.PI / 2;
    const sunHeight = Math.sin(sunAngle) * 50;
    const sunDistance = Math.cos(sunAngle) * 50;
    
    sunRef.current.position.set(sunDistance, Math.max(0, sunHeight), 25);
    
    // Calculate moon position (opposite of sun)
    moonRef.current.position.set(-sunDistance, Math.max(0, -sunHeight), 25);
    
    // Adjust light intensities based on time
    const dayIntensity = Math.max(0, Math.sin(sunAngle));
    const nightIntensity = Math.max(0, -Math.sin(sunAngle));
    
    sunRef.current.intensity = dayIntensity;
    moonRef.current.intensity = nightIntensity * 0.3;
    
    // Adjust ambient light
    ambientRef.current.intensity = 0.3 + dayIntensity * 0.2;
    
    // Adjust colors
    const sunColor = new THREE.Color();
    if (timeOfDay >= 6 && timeOfDay <= 7) {
      // Sunrise
      sunColor.setHSL(30 / 360, 1, 0.5);
    } else if (timeOfDay >= 17 && timeOfDay <= 19) {
      // Sunset
      sunColor.setHSL(15 / 360, 1, 0.5);
    } else if (timeOfDay >= 8 && timeOfDay <= 16) {
      // Day
      sunColor.setHSL(60 / 360, 0.5, 1);
    } else {
      // Night
      sunColor.setHSL(220 / 360, 0.3, 0.7);
    }
    
    sunRef.current.color = sunColor;
    ambientRef.current.color = sunColor;
  });
  
  return (
    <>
      <ambientLight ref={ambientRef} intensity={0.5} />
      <directionalLight
        ref={sunRef}
        castShadow
        shadow-mapSize={[2048, 2048]}
        shadow-camera-far={150}
        shadow-camera-left={-100}
        shadow-camera-right={100}
        shadow-camera-top={100}
        shadow-camera-bottom={-100}
      />
      <pointLight ref={moonRef} color="#8888ff" />
      
      {/* Sun sphere */}
      <mesh position={[50, 30, 25]}>
        <sphereGeometry args={[2, 16, 16]} />
        <meshBasicMaterial color="#ffff00" />
      </mesh>
      
      {/* Moon sphere */}
      <mesh position={[-50, 30, 25]}>
        <sphereGeometry args={[1.5, 16, 16]} />
        <meshBasicMaterial color="#ffffff" />
      </mesh>
    </>
  );
};