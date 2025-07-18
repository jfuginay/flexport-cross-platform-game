import React, { useRef, useEffect, useState } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';

interface BasicMapboxEarthProps {
  radius?: number;
  segments?: number;
  isRotating?: boolean;
  rotationSpeed?: number;
  children?: React.ReactNode;
}

export const BasicMapboxEarth: React.FC<BasicMapboxEarthProps> = ({
  radius = 100,
  segments = 128,
  isRotating = true,
  rotationSpeed = 0.0002,
  children
}) => {
  const groupRef = useRef<THREE.Group>(null);
  const [texture, setTexture] = useState<THREE.Texture | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const loadTexture = async () => {
      const mapboxToken = process.env.REACT_APP_MAPBOX_TOKEN;
      const textureLoader = new THREE.TextureLoader();

      if (mapboxToken) {
        try {
          // Simple static image request
          const mapUrl = `https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/static/0,0,0/1024x512?access_token=${mapboxToken}`;
          
          const mapTexture = await new Promise<THREE.Texture>((resolve, reject) => {
            textureLoader.load(
              mapUrl,
              (texture) => {
                // Configure texture for sphere mapping
                texture.wrapS = THREE.RepeatWrapping;
                texture.wrapT = THREE.ClampToEdgeWrapping;
                texture.repeat.set(1, 1);
                texture.offset.set(0, 0);
                texture.needsUpdate = true;
                resolve(texture);
              },
              undefined,
              reject
            );
          });

          setTexture(mapTexture);
        } catch (error) {
          console.error('Failed to load Mapbox texture:', error);
        }
      }

      // Always load fallback texture
      textureLoader.load(
        'https://raw.githubusercontent.com/mrdoob/three.js/master/examples/textures/planets/earth_atmos_2048.jpg',
        (fallbackTexture) => {
          if (!texture) {
            setTexture(fallbackTexture);
          }
        }
      );

      setLoading(false);
    };

    loadTexture();
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
        {texture ? (
          <meshPhongMaterial
            map={texture}
            bumpScale={0.05}
            specular={new THREE.Color(0x090909)}
            specularMap={texture}
            shininess={5}
          />
        ) : (
          <meshPhongMaterial
            color={loading ? 0x2244aa : 0x4169e1}
            emissive={0x112244}
            emissiveIntensity={0.1}
          />
        )}
      </mesh>

      {/* Simple atmosphere */}
      <mesh scale={[1.01, 1.01, 1.01]}>
        <sphereGeometry args={[radius, segments, segments]} />
        <meshPhongMaterial
          color={0x88ccff}
          transparent
          opacity={0.1}
          side={THREE.BackSide}
          depthWrite={false}
        />
      </mesh>

      {/* Children (ports) */}
      {children}
    </group>
  );
};