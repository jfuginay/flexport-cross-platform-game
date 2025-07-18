import React, { useRef, Suspense } from 'react';
import { useFrame, useLoader } from '@react-three/fiber';
import * as THREE from 'three';

interface SimpleEarthProps {
  radius?: number;
  segments?: number;
  isRotating?: boolean;
  rotationSpeed?: number;
  children?: React.ReactNode;
}

// Create a procedural Earth-like texture
const createEarthTexture = () => {
  const canvas = document.createElement('canvas');
  canvas.width = 1024;
  canvas.height = 512;
  const ctx = canvas.getContext('2d')!;
  
  // Create gradient for ocean
  const oceanGradient = ctx.createLinearGradient(0, 0, 0, canvas.height);
  oceanGradient.addColorStop(0, '#001a33');
  oceanGradient.addColorStop(0.5, '#003366');
  oceanGradient.addColorStop(1, '#001a33');
  ctx.fillStyle = oceanGradient;
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  
  // Draw continents (simplified)
  ctx.fillStyle = '#2d5016'; // Dark green for land
  
  // Africa & Europe
  ctx.beginPath();
  ctx.ellipse(canvas.width * 0.55, canvas.height * 0.5, 80, 120, 0, 0, Math.PI * 2);
  ctx.fill();
  
  // Americas
  ctx.beginPath();
  ctx.ellipse(canvas.width * 0.25, canvas.height * 0.5, 60, 100, -0.2, 0, Math.PI * 2);
  ctx.fill();
  
  // Asia
  ctx.beginPath();
  ctx.ellipse(canvas.width * 0.75, canvas.height * 0.35, 120, 80, 0, 0, Math.PI * 2);
  ctx.fill();
  
  // Australia
  ctx.beginPath();
  ctx.ellipse(canvas.width * 0.8, canvas.height * 0.75, 40, 30, 0, 0, Math.PI * 2);
  ctx.fill();
  
  // Add some texture noise
  const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
  const data = imageData.data;
  for (let i = 0; i < data.length; i += 4) {
    const noise = (Math.random() - 0.5) * 20;
    data[i] += noise;
    data[i + 1] += noise;
    data[i + 2] += noise;
  }
  ctx.putImageData(imageData, 0, 0);
  
  return new THREE.CanvasTexture(canvas);
};

export const SimpleEarth: React.FC<SimpleEarthProps> = ({
  radius = 100,
  segments = 64,
  isRotating = true,
  rotationSpeed = 0.0002,
  children
}) => {
  const groupRef = useRef<THREE.Group>(null);
  const earthTexture = React.useMemo(() => createEarthTexture(), []);

  useFrame(() => {
    if (groupRef.current && isRotating) {
      groupRef.current.rotation.y += rotationSpeed;
    }
  });

  return (
    <group ref={groupRef}>
      {/* Earth with procedural texture */}
      <mesh castShadow receiveShadow>
        <sphereGeometry args={[radius, segments, segments]} />
        <meshPhongMaterial
          map={earthTexture}
          specular={new THREE.Color(0x111111)}
          shininess={5}
        />
      </mesh>

      {/* Simple cloud layer */}
      <mesh scale={[1.01, 1.01, 1.01]}>
        <sphereGeometry args={[radius, segments, segments]} />
        <meshPhongMaterial
          color={0xffffff}
          transparent
          opacity={0.1}
          depthWrite={false}
        />
      </mesh>

      {/* Atmosphere */}
      <mesh scale={[1.02, 1.02, 1.02]}>
        <sphereGeometry args={[radius, segments, segments]} />
        <meshPhongMaterial
          color={0x4488ff}
          transparent
          opacity={0.1}
          side={THREE.BackSide}
          blending={THREE.AdditiveBlending}
          depthWrite={false}
        />
      </mesh>

      {/* Children (ports, etc.) */}
      {children}
    </group>
  );
};