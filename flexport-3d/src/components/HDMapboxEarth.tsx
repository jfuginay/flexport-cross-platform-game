import React, { useRef, useEffect, useState } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';
import { MapboxTileLoader } from '../utils/mapboxTileLoader';

interface HDMapboxEarthProps {
  radius?: number;
  segments?: number;
  isRotating?: boolean;
  rotationSpeed?: number;
  children?: React.ReactNode;
}

export const HDMapboxEarth: React.FC<HDMapboxEarthProps> = ({
  radius = 100,
  segments = 256,
  isRotating = true,
  rotationSpeed = 0.0002,
  children
}) => {
  const groupRef = useRef<THREE.Group>(null);
  const [dayTexture, setDayTexture] = useState<THREE.Texture | null>(null);
  const [nightTexture, setNightTexture] = useState<THREE.Texture | null>(null);
  const [normalMap, setNormalMap] = useState<THREE.Texture | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const loadTextures = async () => {
      const mapboxToken = process.env.REACT_APP_MAPBOX_TOKEN;
      
      if (!mapboxToken) {
        console.error('Mapbox token not found');
        // Load fallback textures
        const loader = new THREE.TextureLoader();
        
        const fallbackDay = await new Promise<THREE.Texture>((resolve) => {
          loader.load(
            'https://raw.githubusercontent.com/mrdoob/three.js/master/examples/textures/planets/earth_atmos_2048.jpg',
            resolve
          );
        });
        
        const fallbackNight = await new Promise<THREE.Texture>((resolve) => {
          loader.load(
            'https://raw.githubusercontent.com/mrdoob/three.js/master/examples/textures/planets/earth_lights_2048.jpg',
            resolve
          );
        });
        
        setDayTexture(fallbackDay);
        setNightTexture(fallbackNight);
        setLoading(false);
        return;
      }

      try {
        // Use simpler approach - load single world image
        const textureLoader = new THREE.TextureLoader();
        
        // Load satellite imagery
        const satelliteUrl = `https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/static/0,0,0.5,0,0/1024x512?access_token=${mapboxToken}`;
        const satelliteTexture = await new Promise<THREE.Texture>((resolve, reject) => {
          textureLoader.load(
            satelliteUrl,
            (texture) => {
              texture.wrapS = THREE.RepeatWrapping;
              texture.wrapT = THREE.ClampToEdgeWrapping;
              resolve(texture);
            },
            undefined,
            reject
          );
        });
        setDayTexture(satelliteTexture);

        // Load dark style for night
        const darkUrl = `https://api.mapbox.com/styles/v1/mapbox/dark-v11/static/0,0,0.5,0,0/1024x512?access_token=${mapboxToken}`;
        const darkTexture = await new Promise<THREE.Texture>((resolve, reject) => {
          textureLoader.load(
            darkUrl,
            (texture) => {
              texture.wrapS = THREE.RepeatWrapping;
              texture.wrapT = THREE.ClampToEdgeWrapping;
              resolve(texture);
            },
            undefined,
            reject
          );
        });
        setNightTexture(darkTexture);

        // Load normal map for terrain
        const loader = new THREE.TextureLoader();
        loader.load(
          'https://raw.githubusercontent.com/mrdoob/three.js/master/examples/textures/planets/earth_normal_2048.jpg',
          (texture) => setNormalMap(texture)
        );

        setLoading(false);
      } catch (error) {
        console.error('Failed to load Mapbox textures:', error);
        setLoading(false);
      }
    };

    loadTextures();
  }, []);

  useFrame((state) => {
    if (groupRef.current && isRotating) {
      groupRef.current.rotation.y += rotationSpeed;
    }
  });

  // Custom shader for day/night cycle
  const earthMaterial = React.useMemo(() => {
    if (!dayTexture) return null;

    return new THREE.ShaderMaterial({
      uniforms: {
        dayTexture: { value: dayTexture },
        nightTexture: { value: nightTexture || dayTexture },
        normalMap: { value: normalMap },
        sunDirection: { value: new THREE.Vector3(1, 0.5, 0.5).normalize() },
        atmosphereColor: { value: new THREE.Color(0x88ccff) }
      },
      vertexShader: `
        varying vec2 vUv;
        varying vec3 vNormal;
        varying vec3 vPosition;
        
        void main() {
          vUv = uv;
          vNormal = normalize(normalMatrix * normal);
          vPosition = (modelViewMatrix * vec4(position, 1.0)).xyz;
          gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
        }
      `,
      fragmentShader: `
        uniform sampler2D dayTexture;
        uniform sampler2D nightTexture;
        uniform sampler2D normalMap;
        uniform vec3 sunDirection;
        uniform vec3 atmosphereColor;
        
        varying vec2 vUv;
        varying vec3 vNormal;
        varying vec3 vPosition;
        
        void main() {
          // Sample textures
          vec4 dayColor = texture2D(dayTexture, vUv);
          vec4 nightColor = texture2D(nightTexture, vUv);
          
          // Calculate sun angle
          float sunAngle = dot(vNormal, sunDirection);
          float dayAmount = smoothstep(-0.2, 0.2, sunAngle);
          
          // Mix day and night
          vec3 color = mix(nightColor.rgb * vec3(1.0, 0.9, 0.7), dayColor.rgb, dayAmount);
          
          // Add atmosphere on edges
          float rim = 1.0 - abs(dot(normalize(-vPosition), vNormal));
          float atmosphere = pow(rim, 2.0);
          color += atmosphereColor * atmosphere * 0.3;
          
          // Add specular for water
          vec3 viewDir = normalize(-vPosition);
          vec3 reflectedLight = reflect(-sunDirection, vNormal);
          float specular = pow(max(dot(viewDir, reflectedLight), 0.0), 20.0);
          
          // Simple water detection (blue areas)
          float waterMask = smoothstep(0.5, 0.6, dayColor.b - max(dayColor.r, dayColor.g));
          color += vec3(0.3, 0.5, 0.8) * specular * waterMask * dayAmount;
          
          gl_FragColor = vec4(color, 1.0);
        }
      `
    });
  }, [dayTexture, nightTexture, normalMap]);

  return (
    <group ref={groupRef}>
      {/* Earth sphere */}
      <mesh castShadow receiveShadow>
        <sphereGeometry args={[radius, segments, segments]} />
        {earthMaterial ? (
          <primitive object={earthMaterial} attach="material" />
        ) : (
          <meshPhongMaterial 
            color={loading ? 0x1a3a52 : 0x4169e1}
            emissive={0x001122}
            emissiveIntensity={0.2}
          />
        )}
      </mesh>

      {/* Atmosphere glow */}
      <mesh scale={[1.015, 1.015, 1.015]}>
        <sphereGeometry args={[radius, segments, segments]} />
        <shaderMaterial
          uniforms={{
            color: { value: new THREE.Color(0x4488ff) },
            viewVector: { value: new THREE.Vector3() }
          }}
          vertexShader={`
            uniform vec3 viewVector;
            varying float intensity;
            void main() {
              vec3 vNormal = normalize(normalMatrix * normal);
              vec3 vNormel = normalize(normalMatrix * viewVector);
              intensity = pow(0.65 - dot(vNormal, vNormel), 2.0);
              gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
            }
          `}
          fragmentShader={`
            uniform vec3 color;
            varying float intensity;
            void main() {
              vec3 glow = color * intensity;
              gl_FragColor = vec4(glow, intensity * 0.5);
            }
          `}
          side={THREE.BackSide}
          blending={THREE.AdditiveBlending}
          transparent
          depthWrite={false}
        />
      </mesh>

      {/* Clouds */}
      <mesh scale={[1.005, 1.005, 1.005]} rotation={[0, 0, 0.05]}>
        <sphereGeometry args={[radius, segments, segments]} />
        <meshPhongMaterial
          color={0xffffff}
          map={null} // Could add cloud texture here
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