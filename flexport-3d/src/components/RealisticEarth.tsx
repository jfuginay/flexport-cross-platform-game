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
    
    // Load high-resolution satellite Earth texture
    // Using various high-quality Earth textures
    const earthTextureUrls = [
      // High-res Earth texture from Solar System Scope
      'https://www.solarsystemscope.com/textures/download/8k_earth_daymap.jpg',
      // NASA Blue Marble
      'https://visibleearth.nasa.gov/images/73909/december-blue-marble-next-generation/73909_lrg.jpg',
      // Alternative high-res texture
      'https://raw.githubusercontent.com/CoryG89/MoonDemo/master/img/earthmap4k.jpg',
      // Fallback texture
      'https://raw.githubusercontent.com/mrdoob/three.js/dev/examples/textures/planets/earth_atmos_2048.jpg'
    ];
    
    // Try loading textures in order until one succeeds
    let textureLoaded = false;
    const loadEarthTexture = (index: number) => {
      if (index >= earthTextureUrls.length || textureLoaded) return;
      
      loader.load(
        earthTextureUrls[index],
        (texture) => {
          textureLoaded = true;
          texture.anisotropy = 16;
          // Just set the texture without encoding for compatibility
          setTextures(prev => ({ ...prev, earthMap: texture }));
        },
        undefined,
        () => {
          console.warn(`Failed to load texture from ${earthTextureUrls[index]}, trying next...`);
          loadEarthTexture(index + 1);
        }
      );
    };
    
    loadEarthTexture(0);
    
    // Load high-res bump/normal map for terrain detail
    const bumpMapUrls = [
      // High quality elevation map
      'https://www.solarsystemscope.com/textures/download/8k_earth_normal_map.jpg',
      // Alternative elevation data
      'https://raw.githubusercontent.com/turban/webgl-earth/master/images/elev_bump_8k.jpg',
      // Fallback normal map
      'https://raw.githubusercontent.com/mrdoob/three.js/dev/examples/textures/planets/earth_normal_2048.jpg'
    ];
    
    let bumpLoaded = false;
    const loadBumpMap = (index: number) => {
      if (index >= bumpMapUrls.length || bumpLoaded) return;
      
      loader.load(
        bumpMapUrls[index],
        (texture) => {
          bumpLoaded = true;
          texture.anisotropy = 16;
          setTextures(prev => ({ ...prev, bumpMap: texture }));
        },
        undefined,
        () => {
          console.warn(`Failed to load bump map from ${bumpMapUrls[index]}, trying next...`);
          loadBumpMap(index + 1);
        }
      );
    };
    
    loadBumpMap(0);
    
    // Load specular map for water reflection
    loader.load(
      'https://raw.githubusercontent.com/turban/webgl-earth/master/images/water_8k.png',
      (texture) => {
        setTextures(prev => ({ ...prev, specularMap: texture }));
      },
      undefined,
      () => {
        // Fallback to original specular map
        loader.load(
          'https://raw.githubusercontent.com/mrdoob/three.js/dev/examples/textures/planets/earth_specular_2048.jpg',
          (texture) => {
            setTextures(prev => ({ ...prev, specularMap: texture }));
          }
        );
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
        <meshStandardMaterial
          map={textures.earthMap}
          bumpMap={textures.bumpMap}
          bumpScale={2.5}
          normalMap={textures.bumpMap}
          normalScale={new THREE.Vector2(2, 2)}
          roughnessMap={textures.specularMap}
          metalnessMap={textures.specularMap}
          roughness={0.8}
          metalness={0.1}
          color={textures.earthMap ? 0xffffff : 0x4488ff}
          emissive={new THREE.Color(0x000011)}
          emissiveIntensity={0.05}
        />
      </mesh>

      {/* Clouds layer */}
      <mesh ref={cloudsRef} scale={[1.005, 1.005, 1.005]}>
        <sphereGeometry args={[radius, segments, segments]} />
        <meshPhongMaterial
          map={textures.cloudsMap}
          transparent
          opacity={0.2}
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

      {/* Ocean layer with realistic water */}
      <mesh>
        <sphereGeometry args={[radius * 0.999, segments, segments]} />
        <meshPhysicalMaterial
          color={0x006994}
          roughness={0.0}
          metalness={0.2}
          transparent
          opacity={0.3}
          envMapIntensity={1}
          clearcoat={1}
          clearcoatRoughness={0}
          reflectivity={0.5}
        />
      </mesh>
      
      {/* Mountain ranges and terrain features */}
      {textures.bumpMap && (
        <mesh>
          <sphereGeometry args={[radius * 1.001, segments, segments]} />
          <meshStandardMaterial
            map={textures.earthMap}
            displacementMap={textures.bumpMap}
            displacementScale={0.5}
            transparent
            opacity={0.3}
            depthWrite={false}
            side={THREE.FrontSide}
          />
        </mesh>
      )}

      {/* Children (ports) */}
      {children}
    </group>
  );
};