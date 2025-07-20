// @ts-nocheck
import React, { Suspense, useRef, useEffect, useState } from 'react';
import { Canvas, useFrame, useLoader } from '@react-three/fiber';
import { OrbitControls, Stars } from '@react-three/drei';
import * as THREE from 'three';
import { useGameStore } from '../store/gameStore';
import { GeoJsonGeometry } from 'three-geojson-geometry';

interface Globe3DWithGeoProps {
  className?: string;
}

// Enhanced ship component with trails
const EnhancedShip = ({ position, color = '#00ff9d', destination = null }) => {
  const meshRef = useRef<THREE.Mesh>();
  const lightRef = useRef<THREE.PointLight>();
  const trailRef = useRef<THREE.Line>();
  
  useFrame((state) => {
    if (meshRef.current) {
      meshRef.current.rotation.y += 0.01;
      meshRef.current.position.y = position[1] + Math.sin(state.clock.elapsedTime * 2) * 2;
    }
    if (lightRef.current) {
      lightRef.current.intensity = 2 + Math.sin(state.clock.elapsedTime * 3) * 0.5;
    }
  });

  return (
    <group position={position}>
      <mesh ref={meshRef}>
        <coneGeometry args={[4, 12, 6]} />
        <meshStandardMaterial 
          color={color} 
          emissive={color} 
          emissiveIntensity={1} 
          metalness={0.8}
          roughness={0.2}
        />
      </mesh>
      <pointLight 
        ref={lightRef}
        color={color} 
        intensity={2} 
        distance={50} 
      />
      <mesh>
        <sphereGeometry args={[8, 16, 16]} />
        <meshBasicMaterial 
          color={color} 
          transparent 
          opacity={0.3} 
          side={THREE.BackSide}
        />
      </mesh>
    </group>
  );
};

// Earth component with realistic features
const EarthWithGeo = () => {
  const earthRef = useRef<THREE.Mesh>();
  const cloudsRef = useRef<THREE.Mesh>();
  const [geoData, setGeoData] = useState(null);
  
  // Load Natural Earth data (simplified coastlines)
  useEffect(() => {
    // For now, we'll create a simplified representation
    // In production, you'd load actual GeoJSON from Natural Earth
    const mockGeoData = {
      type: "FeatureCollection",
      features: []
    };
    setGeoData(mockGeoData);
  }, []);
  
  useFrame(() => {
    if (earthRef.current) {
      earthRef.current.rotation.y += 0.0005;
    }
    if (cloudsRef.current) {
      cloudsRef.current.rotation.y += 0.0007;
      cloudsRef.current.rotation.z += 0.0002;
    }
  });

  return (
    <group>
      {/* Ocean sphere */}
      <mesh ref={earthRef}>
        <sphereGeometry args={[100, 128, 128]} />
        <meshPhongMaterial 
          color="#1e3a5f"
          emissive="#000033"
          emissiveIntensity={0.1}
          shininess={10}
          specular="#4488ff"
        />
      </mesh>
      
      {/* Continents layer */}
      <mesh>
        <sphereGeometry args={[100.5, 64, 64]} />
        <meshPhongMaterial 
          color="#2d5a2d"
          emissive="#1a3a1a"
          emissiveIntensity={0.05}
          map={generateContinentTexture()}
          transparent
          opacity={0.9}
        />
      </mesh>
      
      {/* Cloud layer */}
      <mesh ref={cloudsRef}>
        <sphereGeometry args={[102, 64, 64]} />
        <meshPhongMaterial 
          map={generateCloudTexture()}
          transparent
          opacity={0.4}
          depthWrite={false}
        />
      </mesh>
      
      {/* Atmosphere glow */}
      <mesh scale={[1.15, 1.15, 1.15]}>
        <sphereGeometry args={[100, 64, 64]} />
        <shaderMaterial
          uniforms={{
            c: { value: 0.5 },
            p: { value: 4.5 },
            glowColor: { value: new THREE.Color(0x00aaff) },
            viewVector: { value: new THREE.Vector3() }
          }}
          vertexShader={`
            uniform vec3 viewVector;
            varying float intensity;
            void main() {
              vec3 vNormal = normalize(normalMatrix * normal);
              vec3 vNormel = normalize(normalMatrix * viewVector);
              intensity = pow(0.8 - dot(vNormal, vNormel), 2.0);
              gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
            }
          `}
          fragmentShader={`
            uniform vec3 glowColor;
            varying float intensity;
            void main() {
              vec3 glow = glowColor * intensity;
              gl_FragColor = vec4(glow, intensity * 0.5);
            }
          `}
          blending={THREE.AdditiveBlending}
          side={THREE.BackSide}
          transparent
        />
      </mesh>
      
      {/* City lights on night side */}
      <mesh>
        <sphereGeometry args={[100.2, 64, 64]} />
        <meshBasicMaterial 
          map={generateCityLightsTexture()}
          blending={THREE.AdditiveBlending}
          transparent
          opacity={0.5}
        />
      </mesh>
    </group>
  );
};

// Helper functions to generate textures
function generateContinentTexture() {
  const canvas = document.createElement('canvas');
  canvas.width = 1024;
  canvas.height = 512;
  const ctx = canvas.getContext('2d');
  
  // Simple continent shapes
  ctx.fillStyle = '#2d5a2d';
  
  // Africa
  ctx.beginPath();
  ctx.ellipse(512, 300, 80, 120, 0, 0, Math.PI * 2);
  ctx.fill();
  
  // Europe
  ctx.beginPath();
  ctx.ellipse(512, 180, 60, 40, 0, 0, Math.PI * 2);
  ctx.fill();
  
  // Asia
  ctx.beginPath();
  ctx.ellipse(700, 200, 120, 80, 0, 0, Math.PI * 2);
  ctx.fill();
  
  // Americas
  ctx.beginPath();
  ctx.ellipse(250, 256, 60, 150, 0, 0, Math.PI * 2);
  ctx.fill();
  
  // Australia
  ctx.beginPath();
  ctx.ellipse(800, 380, 50, 30, 0, 0, Math.PI * 2);
  ctx.fill();
  
  const texture = new THREE.CanvasTexture(canvas);
  texture.needsUpdate = true;
  return texture;
}

function generateCloudTexture() {
  const canvas = document.createElement('canvas');
  canvas.width = 1024;
  canvas.height = 512;
  const ctx = canvas.getContext('2d');
  
  // Create cloud patterns
  ctx.fillStyle = 'rgba(255, 255, 255, 0.8)';
  
  for (let i = 0; i < 100; i++) {
    const x = Math.random() * canvas.width;
    const y = Math.random() * canvas.height;
    const radius = Math.random() * 30 + 10;
    
    ctx.beginPath();
    ctx.arc(x, y, radius, 0, Math.PI * 2);
    ctx.fill();
  }
  
  const texture = new THREE.CanvasTexture(canvas);
  texture.needsUpdate = true;
  return texture;
}

function generateCityLightsTexture() {
  const canvas = document.createElement('canvas');
  canvas.width = 1024;
  canvas.height = 512;
  const ctx = canvas.getContext('2d');
  
  // City lights concentrated on continents
  const cities = [
    { x: 250, y: 200, size: 5 }, // NYC
    { x: 512, y: 180, size: 4 }, // London
    { x: 700, y: 220, size: 6 }, // Shanghai
    { x: 750, y: 250, size: 5 }, // Tokyo
    { x: 250, y: 350, size: 4 }, // São Paulo
    { x: 550, y: 300, size: 3 }, // Cairo
  ];
  
  cities.forEach(city => {
    const gradient = ctx.createRadialGradient(city.x, city.y, 0, city.x, city.y, city.size * 5);
    gradient.addColorStop(0, 'rgba(255, 200, 100, 1)');
    gradient.addColorStop(0.5, 'rgba(255, 200, 100, 0.5)');
    gradient.addColorStop(1, 'rgba(255, 200, 100, 0)');
    
    ctx.fillStyle = gradient;
    ctx.fillRect(city.x - city.size * 5, city.y - city.size * 5, city.size * 10, city.size * 10);
  });
  
  const texture = new THREE.CanvasTexture(canvas);
  texture.needsUpdate = true;
  return texture;
}

export const Globe3DWithGeo: React.FC<Globe3DWithGeoProps> = ({ className }) => {
  const { fleet, ports } = useGameStore();

  const getGlobePosition = (lat: number, lng: number, radius: number = 102) => {
    const phi = (90 - lat) * (Math.PI / 180);
    const theta = (lng + 180) * (Math.PI / 180);
    
    const x = -(radius * Math.sin(phi) * Math.cos(theta));
    const y = radius * Math.cos(phi);
    const z = radius * Math.sin(phi) * Math.sin(theta);
    
    return [x, y, z];
  };

  return (
    <div className={className} style={{ width: '100%', height: '100%', background: '#000814' }}>
      <Canvas camera={{ position: [0, 150, 400], fov: 45 }}>
        <Suspense fallback={null}>
          {/* Enhanced lighting */}
          <ambientLight intensity={0.4} />
          <directionalLight 
            position={[100, 50, 100]} 
            intensity={1.5}
            color="#fffadd"
            castShadow
            shadow-mapSize={[2048, 2048]}
          />
          <pointLight position={[-100, -50, -100]} intensity={0.3} color="#4080ff" />
          
          {/* Stars with nebula effect */}
          <Stars 
            radius={800} 
            depth={100} 
            count={10000} 
            factor={4} 
            saturation={0.1} 
            fade 
            speed={0.5} 
          />
          
          {/* Earth with geographical features */}
          <EarthWithGeo />
          
          {/* Ships with enhanced visuals */}
          {fleet.map((ship) => {
            const position = getGlobePosition(
              ship.position.lat,
              ship.position.lng
            );
            
            return (
              <EnhancedShip
                key={ship.id}
                position={position}
                color={ship.status === 'SAILING' ? '#00ff9d' : '#ffa500'}
                destination={ship.destination}
              />
            );
          })}
          
          {/* Enhanced port markers */}
          {ports.map((port) => {
            const position = getGlobePosition(
              port.position.lat,
              port.position.lng,
              101
            );
            
            const portSize = Math.sqrt(port.realTrafficTEU / 1000000) || 5;
            
            return (
              <group key={port.id} position={position}>
                <mesh>
                  <cylinderGeometry args={[portSize/2, portSize, 10, 8]} />
                  <meshStandardMaterial 
                    color={port.isPlayerOwned ? "#00ff00" : "#ff0000"} 
                    emissive={port.isPlayerOwned ? "#00ff00" : "#ff0000"} 
                    emissiveIntensity={0.8}
                    metalness={0.8}
                    roughness={0.2}
                  />
                </mesh>
                <pointLight 
                  color={port.isPlayerOwned ? "#00ff00" : "#ff0000"} 
                  intensity={1.5} 
                  distance={30} 
                />
                {/* Port activity indicator */}
                <mesh position={[0, 15, 0]}>
                  <ringGeometry args={[portSize, portSize + 2, 32]} />
                  <meshBasicMaterial 
                    color="#ffffff" 
                    transparent 
                    opacity={0.5}
                    side={THREE.DoubleSide}
                  />
                </mesh>
              </group>
            );
          })}
          
          {/* Shipping lanes visualization */}
          {fleet.filter(ship => ship.destination).map((ship, index) => {
            const start = getGlobePosition(ship.position.lat, ship.position.lng, 101);
            const end = getGlobePosition(
              ship.destination.position.lat, 
              ship.destination.position.lng, 
              101
            );
            
            const curve = new THREE.CatmullRomCurve3([
              new THREE.Vector3(...start),
              new THREE.Vector3(
                (start[0] + end[0]) / 2,
                Math.max(start[1], end[1]) + 20,
                (start[2] + end[2]) / 2
              ),
              new THREE.Vector3(...end)
            ]);
            
            const points = curve.getPoints(50);
            const geometry = new THREE.BufferGeometry().setFromPoints(points);
            
            return (
              <line key={`route-${ship.id}`} geometry={geometry}>
                <lineBasicMaterial 
                  color="#00ff9d" 
                  transparent 
                  opacity={0.3}
                  linewidth={2}
                />
              </line>
            );
          })}
          
          {/* Camera Controls */}
          <OrbitControls 
            enablePan={false}
            minDistance={150}
            maxDistance={600}
            rotateSpeed={0.5}
            zoomSpeed={0.8}
            autoRotate
            autoRotateSpeed={0.2}
          />
        </Suspense>
      </Canvas>
    </div>
  );
};