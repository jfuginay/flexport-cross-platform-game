import React, { useRef, useEffect, useState } from 'react';
import { useFrame, useLoader } from '@react-three/fiber';
import * as THREE from 'three';

interface RealisticEarthProps {
  radius?: number;
  segments?: number;
  isRotating?: boolean;
  rotationSpeed?: number;
  children?: React.ReactNode;
}

export const RealisticEarth: React.FC<RealisticEarthProps> = ({
  radius = 100,
  segments = 128,
  isRotating = true,
  rotationSpeed = 0.0002,
  children
}) => {
  const groupRef = useRef<THREE.Group>(null);
  const cloudsRef = useRef<THREE.Mesh>(null);
  
  const [textures, setTextures] = useState<{
    earthMap?: THREE.Texture;
    bumpMap?: THREE.Texture;
    specularMap?: THREE.Texture;
    cloudsMap?: THREE.Texture;
  }>({});

  useEffect(() => {
    const loader = new THREE.TextureLoader();
    
    // Load Earth map
    loader.load(
      'https://raw.githubusercontent.com/mrdoob/three.js/dev/examples/textures/planets/earth_atmos_2048.jpg',
      (texture) => {
        texture.anisotropy = 16;
        setTextures(prev => ({ ...prev, earthMap: texture }));
      }
    );
    
    // Load bump map
    loader.load(
      'https://raw.githubusercontent.com/mrdoob/three.js/dev/examples/textures/planets/earth_normal_2048.jpg',
      (texture) => {
        setTextures(prev => ({ ...prev, bumpMap: texture }));
      }
    );
    
    // Load specular map
    loader.load(
      'https://raw.githubusercontent.com/mrdoob/three.js/dev/examples/textures/planets/earth_specular_2048.jpg',
      (texture) => {
        setTextures(prev => ({ ...prev, specularMap: texture }));
      }
    );
    
    // Load clouds
    loader.load(
      'https://raw.githubusercontent.com/mrdoob/three.js/dev/examples/textures/planets/earth_clouds_1024.png',
      (texture) => {
        setTextures(prev => ({ ...prev, cloudsMap: texture }));
      }
    );
  }, []);

  useFrame((state, delta) => {
    if (groupRef.current && isRotating) {
      groupRef.current.rotation.y += rotationSpeed;
    }
    if (cloudsRef.current) {
      cloudsRef.current.rotation.y += rotationSpeed * 0.5;
    }
  });

  return (
    <group ref={groupRef}>
      {/* Main Earth sphere with continents */}
      <mesh castShadow receiveShadow>
        <sphereGeometry args={[radius, segments, segments]} />
        <meshPhongMaterial
          map={textures.earthMap}
          bumpMap={textures.bumpMap}
          bumpScale={0.5}
          specularMap={textures.specularMap}
          specular={new THREE.Color('grey')}
          shininess={10}
          color={textures.earthMap ? 0xffffff : 0x4488ff}
        />
      </mesh>

      {/* Clouds layer */}
      <mesh ref={cloudsRef} scale={[1.01, 1.01, 1.01]}>
        <sphereGeometry args={[radius, segments, segments]} />
        <meshPhongMaterial
          map={textures.cloudsMap}
          transparent
          opacity={0.3}
          depthWrite={false}
          color={0xffffff}
        />
      </mesh>

      {/* Atmosphere glow */}
      <mesh scale={[1.025, 1.025, 1.025]}>
        <sphereGeometry args={[radius, segments / 2, segments / 2]} />
        <shaderMaterial
          uniforms={{
            c: { value: 0.4 },
            p: { value: 4.5 },
            glowColor: { value: new THREE.Color(0x00aaff) },
            viewVector: { value: new THREE.Vector3() }
          }}
          vertexShader={`
            uniform vec3 viewVector;
            uniform float c;
            uniform float p;
            varying float intensity;
            void main() {
              vec3 vNormal = normalize(normalMatrix * normal);
              vec3 vNormel = normalize(normalMatrix * viewVector);
              intensity = pow(c - dot(vNormal, vNormel), p);
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
          side={THREE.FrontSide}
          blending={THREE.AdditiveBlending}
          transparent
          depthWrite={false}
        />
      </mesh>

      {/* Ocean reflection layer */}
      <mesh>
        <sphereGeometry args={[radius * 0.999, segments, segments]} />
        <meshPhongMaterial
          color={0x000080}
          emissive={0x000020}
          specular={0x4488ff}
          shininess={100}
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