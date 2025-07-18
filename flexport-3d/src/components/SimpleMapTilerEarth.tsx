import React, { useRef, useEffect, useState } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';

interface SimpleMapTilerEarthProps {
  radius?: number;
  segments?: number;
  isRotating?: boolean;
  rotationSpeed?: number;
  children?: React.ReactNode;
}

export const SimpleMapTilerEarth: React.FC<SimpleMapTilerEarthProps> = ({
  radius = 100,
  segments = 128,
  isRotating = true,
  rotationSpeed = 0.0002,
  children
}) => {
  const groupRef = useRef<THREE.Group>(null);
  const [texture, setTexture] = useState<THREE.Texture | null>(null);
  
  useEffect(() => {
    const mapTilerKey = 'YbCOFqTnXk0xnOtrQ6vG';
    const textureLoader = new THREE.TextureLoader();
    
    // Load world map from MapTiler
    const worldMapUrl = `https://api.maptiler.com/maps/satellite/static/0,0,0/2048x1024.png?key=${mapTilerKey}`;
    
    textureLoader.load(
      worldMapUrl,
      (loadedTexture) => {
        loadedTexture.wrapS = THREE.RepeatWrapping;
        loadedTexture.wrapT = THREE.ClampToEdgeWrapping;
        loadedTexture.offset.x = 0.5; // Adjust for correct positioning
        loadedTexture.needsUpdate = true;
        setTexture(loadedTexture);
      },
      undefined,
      (error) => {
        console.error('Failed to load MapTiler texture:', error);
        // Fallback texture
        textureLoader.load(
          'https://raw.githubusercontent.com/mrdoob/three.js/dev/examples/textures/planets/earth_atmos_2048.jpg',
          (fallbackTexture) => {
            setTexture(fallbackTexture);
          }
        );
      }
    );
  }, []);
  
  useFrame(() => {
    if (groupRef.current && isRotating) {
      groupRef.current.rotation.y += rotationSpeed;
    }
  });

  return (
    <group ref={groupRef}>
      {/* Earth sphere */}
      <mesh castShadow receiveShadow>
        <sphereGeometry args={[radius, segments, segments]} />
        <meshPhongMaterial
          map={texture}
          color={texture ? 0xffffff : 0x2255aa}
          emissive={0x001122}
          emissiveIntensity={0.1}
          bumpScale={0.05}
          specular={new THREE.Color(0x333333)}
          shininess={15}
        />
      </mesh>

      {/* Ocean layer for water effect */}
      <mesh>
        <sphereGeometry args={[radius * 0.999, segments, segments]} />
        <meshPhongMaterial
          color={0x004080}
          transparent
          opacity={0.5}
          specular={0x4488ff}
          shininess={100}
          depthWrite={false}
        />
      </mesh>

      {/* Atmosphere */}
      <mesh scale={[1.015, 1.015, 1.015]}>
        <sphereGeometry args={[radius, 64, 64]} />
        <meshPhongMaterial
          color={0x4488ff}
          transparent
          opacity={0.1}
          side={THREE.BackSide}
          depthWrite={false}
        />
      </mesh>

      {/* Clouds */}
      <mesh scale={[1.005, 1.005, 1.005]}>
        <sphereGeometry args={[radius, segments, segments]} />
        <meshPhongMaterial
          color={0xffffff}
          transparent
          opacity={0.15}
          depthWrite={false}
        />
      </mesh>

      {/* Children (ports) */}
      {children}
    </group>
  );
};