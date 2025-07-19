// @ts-nocheck
import React, { useRef, useEffect, useState } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';
import { MapboxTextureProvider } from '../utils/mapboxTextureProvider';

interface MapboxEarthProps {
  radius?: number;
  segments?: number;
  isRotating?: boolean;
  rotationSpeed?: number;
  children?: React.ReactNode;
}

export const MapboxEarth: React.FC<MapboxEarthProps> = ({
  radius = 100,
  segments = 128,
  isRotating = true,
  rotationSpeed = 0.001,
  children
}) => {
  const meshRef = useRef<THREE.Mesh>(null);
  const [texture, setTexture] = useState<THREE.Texture | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Load Mapbox texture
    const loadTexture = async () => {
      try {
        const provider = new MapboxTextureProvider({
          accessToken: process.env.REACT_APP_MAPBOX_TOKEN || '',
          style: 'satellite-streets-v12',
          resolution: 4096
        });

        // Start with simple texture for faster loading
        const simpleTexture = await provider.getSimpleTexture();
        setTexture(simpleTexture);
        setLoading(false);

        // Then load high-quality texture
        const hqTexture = await provider.createGlobeTexture();
        setTexture(hqTexture);
      } catch (error) {
        console.error('Failed to load Mapbox texture:', error);
        setLoading(false);
        
        // Fallback to a basic Earth texture
        const loader = new THREE.TextureLoader();
        loader.load(
          'https://raw.githubusercontent.com/mrdoob/three.js/master/examples/textures/planets/earth_atmos_2048.jpg',
          (fallbackTexture) => {
            setTexture(fallbackTexture);
          }
        );
      }
    };

    loadTexture();
  }, []);

  useFrame((state, delta) => {
    if (meshRef.current && isRotating) {
      meshRef.current.rotation.y += rotationSpeed;
    }
  });

  // Create material with loaded texture
  const material = texture ? (
    <meshPhongMaterial
      map={texture}
      bumpScale={0.05}
      specular={new THREE.Color(0x333333)}
      shininess={5}
    />
  ) : (
    <meshPhongMaterial color={0x2b4c8c} />
  );

  return (
    <group>
      {/* Earth sphere */}
      <mesh ref={meshRef} castShadow receiveShadow>
        <sphereGeometry args={[radius, segments, segments]} />
        {material}
      </mesh>

      {/* Atmosphere glow */}
      <mesh scale={[1.01, 1.01, 1.01]}>
        <sphereGeometry args={[radius, segments, segments]} />
        <meshPhongMaterial
          color={0x4444ff}
          transparent
          opacity={0.1}
          side={THREE.BackSide}
        />
      </mesh>

      {/* Cloud layer */}
      <mesh scale={[1.02, 1.02, 1.02]}>
        <sphereGeometry args={[radius, segments, segments]} />
        <meshPhongMaterial
          color={0xffffff}
          transparent
          opacity={0.2}
          depthWrite={false}
        />
      </mesh>

      {/* Loading indicator */}
      {loading && (
        <mesh>
          <sphereGeometry args={[radius * 0.99, 32, 32]} />
          <meshBasicMaterial color={0x1a1a1a} />
        </mesh>
      )}

      {/* Children (ports, etc.) */}
      {children}
    </group>
  );
};