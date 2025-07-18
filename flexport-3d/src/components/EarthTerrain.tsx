import React, { useMemo, useRef } from 'react';
import * as THREE from 'three';
import { useFrame } from '@react-three/fiber';

interface EarthTerrainProps {
  radius?: number;
  segments?: number;
  rotationSpeed?: number;
  rotationAngle?: number;
  isRotating?: boolean;
  children?: React.ReactNode;
}

export const EarthTerrain: React.FC<EarthTerrainProps> = ({ 
  radius = 100,
  segments = 128,
  rotationSpeed = 0.0001,
  rotationAngle,
  isRotating = true,
  children
}) => {
  const groupRef = useRef<THREE.Group>(null);
  
  // Rotate Earth based on time
  useFrame((state, delta) => {
    if (groupRef.current) {
      if (rotationAngle !== undefined) {
        // Use explicit rotation angle for synchronized day/night
        groupRef.current.rotation.y = rotationAngle;
      } else if (isRotating) {
        // Use rotation speed
        groupRef.current.rotation.y += rotationSpeed * delta * 1000;
      }
    }
  });
  const { geometry, landTexture, oceanTexture } = useMemo(() => {
    const geom = new THREE.SphereGeometry(radius, segments, segments);
    
    // Create texture for continents
    const landCanvas = document.createElement('canvas');
    landCanvas.width = 2048;
    landCanvas.height = 1024;
    const landCtx = landCanvas.getContext('2d')!;
    
    // Ocean gradient background
    const oceanGradient = landCtx.createLinearGradient(0, 0, 0, landCanvas.height);
    oceanGradient.addColorStop(0, '#0f3057');
    oceanGradient.addColorStop(0.5, '#00587a');
    oceanGradient.addColorStop(1, '#0f3057');
    landCtx.fillStyle = oceanGradient;
    landCtx.fillRect(0, 0, landCanvas.width, landCanvas.height);
    
    // Land base color
    const landGradient = landCtx.createRadialGradient(
      landCanvas.width / 2, landCanvas.height / 2, 0,
      landCanvas.width / 2, landCanvas.height / 2, landCanvas.width / 2
    );
    landGradient.addColorStop(0, '#4a7c59');
    landGradient.addColorStop(1, '#3e5e48');
    
    // North America
    landCtx.fillStyle = '#4a7c59';
    landCtx.beginPath();
    landCtx.moveTo(200, 200);
    landCtx.bezierCurveTo(250, 150, 400, 120, 500, 180);
    landCtx.lineTo(520, 220);
    landCtx.lineTo(480, 280);
    landCtx.lineTo(450, 350);
    landCtx.bezierCurveTo(400, 380, 300, 400, 250, 350);
    landCtx.lineTo(200, 250);
    landCtx.closePath();
    landCtx.fill();
    
    // Add Greenland
    landCtx.beginPath();
    landCtx.ellipse(580, 120, 60, 40, -Math.PI / 6, 0, Math.PI * 2);
    landCtx.fill();
    
    // South America
    landCtx.fillStyle = '#4a7c59';
    landCtx.beginPath();
    landCtx.moveTo(380, 480);
    landCtx.bezierCurveTo(420, 460, 450, 500, 440, 580);
    landCtx.lineTo(420, 700);
    landCtx.bezierCurveTo(400, 780, 380, 800, 350, 780);
    landCtx.lineTo(340, 650);
    landCtx.lineTo(350, 550);
    landCtx.bezierCurveTo(360, 500, 370, 480, 380, 480);
    landCtx.closePath();
    landCtx.fill();
    
    // Europe
    landCtx.fillStyle = '#4a7c59';
    landCtx.beginPath();
    landCtx.moveTo(980, 200);
    landCtx.lineTo(1050, 180);
    landCtx.lineTo(1100, 220);
    landCtx.lineTo(1080, 280);
    landCtx.lineTo(1050, 320);
    landCtx.lineTo(1000, 300);
    landCtx.lineTo(980, 250);
    landCtx.closePath();
    landCtx.fill();
    
    // Africa
    landCtx.fillStyle = '#4a7c59';
    landCtx.beginPath();
    landCtx.moveTo(1020, 380);
    landCtx.bezierCurveTo(1080, 360, 1140, 380, 1150, 420);
    landCtx.lineTo(1140, 500);
    landCtx.lineTo(1100, 620);
    landCtx.bezierCurveTo(1050, 680, 1000, 690, 950, 650);
    landCtx.lineTo(960, 550);
    landCtx.lineTo(980, 450);
    landCtx.bezierCurveTo(990, 400, 1000, 380, 1020, 380);
    landCtx.closePath();
    landCtx.fill();
    
    // Asia
    landCtx.fillStyle = '#4a7c59';
    landCtx.beginPath();
    landCtx.moveTo(1150, 180);
    landCtx.bezierCurveTo(1300, 150, 1500, 160, 1650, 220);
    landCtx.lineTo(1680, 300);
    landCtx.lineTo(1600, 400);
    landCtx.lineTo(1400, 420);
    landCtx.lineTo(1200, 380);
    landCtx.lineTo(1150, 300);
    landCtx.closePath();
    landCtx.fill();
    
    // India
    landCtx.beginPath();
    landCtx.moveTo(1350, 420);
    landCtx.lineTo(1400, 450);
    landCtx.lineTo(1380, 520);
    landCtx.lineTo(1320, 500);
    landCtx.closePath();
    landCtx.fill();
    
    // Australia
    landCtx.fillStyle = '#4a7c59';
    landCtx.beginPath();
    landCtx.ellipse(1550, 700, 100, 60, Math.PI / 8, 0, Math.PI * 2);
    landCtx.fill();
    
    // Add texture details and variations
    landCtx.globalAlpha = 0.3;
    
    // Add forests (darker green)
    for (let i = 0; i < 2000; i++) {
      const x = Math.random() * landCanvas.width;
      const y = Math.random() * landCanvas.height;
      const pixel = landCtx.getImageData(x, y, 1, 1).data;
      
      if (pixel[0] > 50 && pixel[1] > 100) { // Land areas
        landCtx.fillStyle = '#2d5a3d';
        landCtx.beginPath();
        landCtx.arc(x, y, Math.random() * 4 + 1, 0, Math.PI * 2);
        landCtx.fill();
      }
    }
    
    // Add deserts (sandy areas)
    landCtx.globalAlpha = 0.4;
    // Sahara
    landCtx.fillStyle = '#c19a6b';
    landCtx.fillRect(1000, 420, 150, 80);
    // Arabian
    landCtx.fillRect(1200, 380, 100, 60);
    // Australian outback
    landCtx.fillRect(1520, 680, 60, 40);
    
    // Add ice caps
    landCtx.globalAlpha = 0.8;
    landCtx.fillStyle = '#e8f4f8';
    // Arctic
    landCtx.fillRect(0, 0, landCanvas.width, 50);
    // Antarctic
    landCtx.fillRect(0, landCanvas.height - 50, landCanvas.width, 50);
    
    landCtx.globalAlpha = 1.0;
    
    // Add subtle cloud shadows over oceans
    landCtx.globalAlpha = 0.1;
    for (let i = 0; i < 20; i++) {
      const x = Math.random() * landCanvas.width;
      const y = Math.random() * landCanvas.height;
      const radius = Math.random() * 100 + 50;
      
      const gradient = landCtx.createRadialGradient(x, y, 0, x, y, radius);
      gradient.addColorStop(0, 'rgba(255, 255, 255, 0.5)');
      gradient.addColorStop(1, 'rgba(255, 255, 255, 0)');
      
      landCtx.fillStyle = gradient;
      landCtx.fillRect(x - radius, y - radius, radius * 2, radius * 2);
    }
    
    landCtx.globalAlpha = 1.0;
    
    const landTex = new THREE.CanvasTexture(landCanvas);
    landTex.wrapS = THREE.RepeatWrapping;
    landTex.wrapT = THREE.ClampToEdgeWrapping;
    
    // Create ocean normal map for water effect
    const oceanCanvas = document.createElement('canvas');
    oceanCanvas.width = 512;
    oceanCanvas.height = 256;
    const oceanCtx = oceanCanvas.getContext('2d')!;
    
    oceanCtx.fillStyle = '#8080ff';
    oceanCtx.fillRect(0, 0, oceanCanvas.width, oceanCanvas.height);
    
    for (let i = 0; i < 2000; i++) {
      const x = Math.random() * oceanCanvas.width;
      const y = Math.random() * oceanCanvas.height;
      const brightness = 100 + Math.random() * 100;
      oceanCtx.fillStyle = `rgb(${brightness}, ${brightness}, 255)`;
      oceanCtx.beginPath();
      oceanCtx.arc(x, y, Math.random() * 3, 0, Math.PI * 2);
      oceanCtx.fill();
    }
    
    const oceanTex = new THREE.CanvasTexture(oceanCanvas);
    oceanTex.wrapS = oceanTex.wrapT = THREE.RepeatWrapping;
    
    return { 
      geometry: geom, 
      landTexture: landTex,
      oceanTexture: oceanTex
    };
  }, [radius, segments]);

  return (
    <group ref={groupRef}>
      {/* Earth sphere */}
      <mesh 
        geometry={geometry}
        castShadow
        receiveShadow
      >
        <meshStandardMaterial 
          map={landTexture}
          normalMap={oceanTexture}
          normalScale={new THREE.Vector2(0.1, 0.1)}
          roughness={0.8}
          metalness={0.2}
        />
      </mesh>
      
      
      {/* Atmosphere glow */}
      <mesh scale={[1.02, 1.02, 1.02]} renderOrder={-1}>
        <sphereGeometry args={[radius, segments, segments]} />
        <meshBasicMaterial
          color={0x4A90E2}
          transparent
          opacity={0.05}
          side={THREE.BackSide}
          depthWrite={false}
        />
      </mesh>
      
      {/* Children (ports, etc.) will rotate with Earth */}
      {children}
    </group>
  );
};