// @ts-nocheck
import React, { useEffect, useRef, useState } from 'react';
import * as THREE from 'three';
import { useFrame } from '@react-three/fiber';

interface MapboxGlobeTextureProps {
  radius?: number;
  segments?: number;
  isRotating?: boolean;
  rotationSpeed?: number;
  children?: React.ReactNode;
}

export const MapboxGlobeTexture: React.FC<MapboxGlobeTextureProps> = ({
  radius = 100,
  segments = 128,
  isRotating = true,
  rotationSpeed = 0.0002,
  children
}) => {
  const groupRef = useRef<THREE.Group>(null);
  const [earthTexture, setEarthTexture] = useState<THREE.Texture | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  
  useEffect(() => {
    const loadMapboxTexture = async () => {
      const mapboxToken = process.env.REACT_APP_MAPBOX_TOKEN;
      
      if (!mapboxToken) {
        console.error('No Mapbox token found');
        setIsLoading(false);
        return;
      }

      try {
        // Create a canvas to render the equirectangular projection
        const canvas = document.createElement('canvas');
        const width = 4096;
        const height = 2048;
        canvas.width = width;
        canvas.height = height;
        const ctx = canvas.getContext('2d')!;

        // Fill with ocean color first
        ctx.fillStyle = '#1a3a52';
        ctx.fillRect(0, 0, width, height);

        // Load map tiles to create equirectangular projection
        // We'll use static API to get a world map
        const zoom = 2;
        const tileSize = 512;
        
        // Load multiple tiles to cover the world
        const promises: Promise<void>[] = [];
        
        // Simplified approach - load one large world image
        const worldImageUrl = `https://api.mapbox.com/styles/v1/mapbox/satellite-v9/static/0,0,1.5,0/1024x512@2x?access_token=${mapboxToken}`;
        
        const img = new Image();
        img.crossOrigin = 'anonymous';
        
        await new Promise((resolve, reject) => {
          img.onload = () => {
            // Draw the world map multiple times to create seamless texture
            const scale = width / 1024;
            ctx.save();
            ctx.scale(scale, scale);
            
            // Draw main world
            ctx.drawImage(img, 0, 0);
            
            // Draw again shifted for seamless wrap
            ctx.drawImage(img, 1024, 0);
            
            ctx.restore();
            resolve(undefined);
          };
          img.onerror = reject;
          img.src = worldImageUrl;
        });

        // Create texture from canvas
        const texture = new THREE.CanvasTexture(canvas);
        texture.needsUpdate = true;
        texture.minFilter = THREE.LinearMipmapLinearFilter;
        texture.magFilter = THREE.LinearFilter;
        texture.anisotropy = 16;
        
        setEarthTexture(texture);
        setIsLoading(false);
      } catch (error) {
        console.error('Failed to load Mapbox texture:', error);
        
        // Fallback to a simple Earth texture
        const loader = new THREE.TextureLoader();
        loader.load(
          'https://raw.githubusercontent.com/mrdoob/three.js/master/examples/textures/planets/earth_atmos_2048.jpg',
          (texture) => {
            setEarthTexture(texture);
            setIsLoading(false);
          }
        );
      }
    };

    loadMapboxTexture();
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
        {earthTexture ? (
          <meshPhongMaterial
            map={earthTexture}
            bumpScale={0.05}
            specular={new THREE.Color(0x333333)}
            shininess={10}
          />
        ) : (
          <meshPhongMaterial 
            color={isLoading ? 0x1a3a52 : 0x4169e1}
            emissive={0x112244}
            emissiveIntensity={0.1}
          />
        )}
      </mesh>

      {/* Ocean shine effect */}
      <mesh>
        <sphereGeometry args={[radius * 0.998, segments, segments]} />
        <meshPhongMaterial
          color={0x006994}
          emissive={0x000033}
          specular={0x111111}
          shininess={100}
          transparent
          opacity={0.5}
          depthWrite={false}
        />
      </mesh>

      {/* Atmosphere */}
      <mesh scale={[1.02, 1.02, 1.02]}>
        <sphereGeometry args={[radius, segments, segments]} />
        <shaderMaterial
          uniforms={{
            color: { value: new THREE.Color(0x88ccff) },
          }}
          vertexShader={`
            varying vec3 vNormal;
            void main() {
              vNormal = normalize(normalMatrix * normal);
              gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
            }
          `}
          fragmentShader={`
            uniform vec3 color;
            varying vec3 vNormal;
            void main() {
              float intensity = pow(0.7 - dot(vNormal, vec3(0, 0, 1.0)), 2.0);
              gl_FragColor = vec4(color, intensity * 0.5);
            }
          `}
          side={THREE.BackSide}
          blending={THREE.AdditiveBlending}
          transparent
          depthWrite={false}
        />
      </mesh>

      {/* Cloud layer */}
      <mesh scale={[1.01, 1.01, 1.01]} rotation={[0, 0, 0.1]}>
        <sphereGeometry args={[radius, segments, segments]} />
        <meshPhongMaterial
          color={0xffffff}
          transparent
          opacity={0.2}
          depthWrite={false}
        />
      </mesh>

      {/* Children (ports) */}
      {children}
    </group>
  );
};