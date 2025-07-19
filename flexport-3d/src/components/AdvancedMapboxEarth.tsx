// @ts-nocheck
import React, { useRef, useEffect, useState, useMemo } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';
import { EarthShaderMaterial } from '../shaders/EarthShader';

interface AdvancedMapboxEarthProps {
  radius?: number;
  segments?: number;
  isRotating?: boolean;
  rotationSpeed?: number;
  mapStyle?: 'satellite' | 'streets' | 'dark' | 'light' | 'hybrid';
  children?: React.ReactNode;
}

export const AdvancedMapboxEarth: React.FC<AdvancedMapboxEarthProps> = ({
  radius = 100,
  segments = 256,
  isRotating = true,
  rotationSpeed = 0.0002,
  mapStyle = 'satellite',
  children
}) => {
  const meshRef = useRef<THREE.Mesh>(null);
  const groupRef = useRef<THREE.Group>(null);
  const materialRef = useRef<THREE.ShaderMaterial>(null);
  const [texturesLoaded, setTexturesLoaded] = useState(false);
  const [showFallback, setShowFallback] = useState(false);
  
  const mapboxToken = process.env.REACT_APP_MAPBOX_TOKEN || '';
  
  // Map style configurations
  const styleConfig = {
    satellite: 'satellite-v9',
    streets: 'streets-v11',
    dark: 'dark-v10',
    light: 'light-v10',
    hybrid: 'satellite-streets-v12'
  };

  // Create shader material
  const shaderMaterial = useMemo(() => {
    return new THREE.ShaderMaterial({
      uniforms: {
        ...EarthShaderMaterial.uniforms,
        dayTexture: { value: null },
        nightTexture: { value: null },
        cloudsTexture: { value: null },
        sunDirection: { value: new THREE.Vector3(1, 0.5, 0.5).normalize() },
        atmosphereColor: { value: new THREE.Color(0x4444ff) },
        time: { value: 0 }
      },
      vertexShader: EarthShaderMaterial.vertexShader,
      fragmentShader: EarthShaderMaterial.fragmentShader,
      side: THREE.FrontSide,
      transparent: false,
      depthWrite: true
    });
  }, []);

  useEffect(() => {
    const loadTextures = async () => {
      const textureLoader = new THREE.TextureLoader();
      
      // Create canvas for stitching tiles
      const canvas = document.createElement('canvas');
      const size = 4096;
      canvas.width = size;
      canvas.height = size / 2;
      const ctx = canvas.getContext('2d')!;
      
      // Function to load Mapbox static image
      const loadMapboxImage = (style: string): Promise<HTMLImageElement> => {
        return new Promise((resolve, reject) => {
          const img = new Image();
          img.crossOrigin = 'anonymous';
          
          // Using Mapbox Static API for a world view
          const url = `https://api.mapbox.com/styles/v1/mapbox/${style}/static/` +
            `0,0,0.5,0/` + // center lon,lat,zoom,bearing
            `${size}x${size / 2}@2x?` + // size@2x for retina
            `access_token=${mapboxToken}&` +
            `attribution=false&logo=false`;
          
          img.onload = () => resolve(img);
          img.onerror = reject;
          img.src = url;
        });
      };

      try {
        // Load day texture (main map style)
        const dayImg = await loadMapboxImage(styleConfig[mapStyle]);
        ctx.drawImage(dayImg, 0, 0, size, size / 2);
        const dayTexture = new THREE.CanvasTexture(canvas);
        dayTexture.needsUpdate = true;
        dayTexture.minFilter = THREE.LinearMipmapLinearFilter;
        dayTexture.magFilter = THREE.LinearFilter;
        
        // Load night texture (dark style for night side)
        const nightCanvas = document.createElement('canvas');
        nightCanvas.width = size;
        nightCanvas.height = size / 2;
        const nightCtx = nightCanvas.getContext('2d')!;
        
        const nightImg = await loadMapboxImage('dark-v10');
        nightCtx.drawImage(nightImg, 0, 0, size, size / 2);
        
        // Add city lights effect
        nightCtx.globalCompositeOperation = 'screen';
        nightCtx.fillStyle = 'rgba(255, 200, 100, 0.1)';
        nightCtx.fillRect(0, 0, size, size / 2);
        
        const nightTexture = new THREE.CanvasTexture(nightCanvas);
        nightTexture.needsUpdate = true;
        
        // Create cloud texture procedurally
        const cloudCanvas = document.createElement('canvas');
        cloudCanvas.width = 2048;
        cloudCanvas.height = 1024;
        const cloudCtx = cloudCanvas.getContext('2d')!;
        
        // Generate cloud pattern
        cloudCtx.fillStyle = 'black';
        cloudCtx.fillRect(0, 0, cloudCanvas.width, cloudCanvas.height);
        
        // Add cloud patterns
        for (let i = 0; i < 200; i++) {
          const x = Math.random() * cloudCanvas.width;
          const y = Math.random() * cloudCanvas.height;
          const radius = Math.random() * 50 + 10;
          
          const gradient = cloudCtx.createRadialGradient(x, y, 0, x, y, radius);
          gradient.addColorStop(0, 'rgba(255, 255, 255, 0.3)');
          gradient.addColorStop(1, 'rgba(255, 255, 255, 0)');
          
          cloudCtx.fillStyle = gradient;
          cloudCtx.fillRect(x - radius, y - radius, radius * 2, radius * 2);
        }
        
        const cloudTexture = new THREE.CanvasTexture(cloudCanvas);
        cloudTexture.wrapS = THREE.RepeatWrapping;
        cloudTexture.wrapT = THREE.RepeatWrapping;
        
        // Update shader uniforms
        if (materialRef.current) {
          materialRef.current.uniforms.dayTexture.value = dayTexture;
          materialRef.current.uniforms.nightTexture.value = nightTexture;
          materialRef.current.uniforms.cloudsTexture.value = cloudTexture;
          materialRef.current.needsUpdate = true;
        }
        
        setTexturesLoaded(true);
      } catch (error) {
        console.error('Failed to load Mapbox textures:', error);
        setShowFallback(true);
        
        // Fallback to basic textures
        const fallbackDayTexture = await new Promise<THREE.Texture>((resolve) => {
          textureLoader.load(
            'https://raw.githubusercontent.com/mrdoob/three.js/master/examples/textures/planets/earth_atmos_2048.jpg',
            resolve
          );
        });
        
        const fallbackNightTexture = await new Promise<THREE.Texture>((resolve) => {
          textureLoader.load(
            'https://raw.githubusercontent.com/mrdoob/three.js/master/examples/textures/planets/earth_lights_2048.jpg',
            resolve
          );
        });
        
        if (materialRef.current) {
          materialRef.current.uniforms.dayTexture.value = fallbackDayTexture;
          materialRef.current.uniforms.nightTexture.value = fallbackNightTexture;
          materialRef.current.uniforms.cloudsTexture.value = null;
          materialRef.current.needsUpdate = true;
        }
        
        setTexturesLoaded(true);
      }
    };

    if (mapboxToken) {
      loadTextures();
    } else {
      console.warn('No Mapbox token provided. Add REACT_APP_MAPBOX_TOKEN to your .env file.');
      setShowFallback(true);
      
      // Load fallback textures immediately
      const loadFallback = async () => {
        const textureLoader = new THREE.TextureLoader();
        
        const dayTexture = await new Promise<THREE.Texture>((resolve) => {
          textureLoader.load(
            'https://raw.githubusercontent.com/mrdoob/three.js/master/examples/textures/planets/earth_atmos_2048.jpg',
            resolve
          );
        });
        
        const nightTexture = await new Promise<THREE.Texture>((resolve) => {
          textureLoader.load(
            'https://raw.githubusercontent.com/mrdoob/three.js/master/examples/textures/planets/earth_lights_2048.jpg',
            resolve
          );
        });
        
        if (materialRef.current) {
          materialRef.current.uniforms.dayTexture.value = dayTexture;
          materialRef.current.uniforms.nightTexture.value = nightTexture;
          materialRef.current.needsUpdate = true;
        }
        
        setTexturesLoaded(true);
      };
      
      loadFallback();
    }
  }, [mapboxToken, mapStyle]);

  useFrame((state, delta) => {
    if (groupRef.current && isRotating) {
      groupRef.current.rotation.y += rotationSpeed;
    }
    
    if (materialRef.current) {
      materialRef.current.uniforms.time.value += delta;
      
      // Update sun direction based on time
      const sunAngle = state.clock.elapsedTime * 0.1;
      materialRef.current.uniforms.sunDirection.value.set(
        Math.cos(sunAngle),
        0.5,
        Math.sin(sunAngle)
      ).normalize();
    }
  });

  return (
    <group visible={texturesLoaded || !mapboxToken}>
      {/* Rotating group that contains Earth and ports */}
      <group ref={groupRef}>
        {/* Main Earth sphere */}
        <mesh ref={meshRef} castShadow receiveShadow>
          <sphereGeometry args={[radius, segments, segments]} />
          <primitive 
            ref={materialRef}
            object={shaderMaterial} 
            attach="material" 
          />
        </mesh>
        
        {/* Children (ports, etc.) - attached to rotating group */}
        {children}
      </group>

      {/* Atmosphere */}
      <mesh scale={[1.02, 1.02, 1.02]}>
        <sphereGeometry args={[radius, segments, segments]} />
        <shaderMaterial
          uniforms={{
            color: { value: new THREE.Color(0x88ccff) },
            intensity: { value: 0.5 }
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
            uniform float intensity;
            varying vec3 vNormal;
            
            void main() {
              float atmosphere = pow(1.0 - dot(vNormal, vec3(0.0, 0.0, 1.0)), 2.0);
              gl_FragColor = vec4(color, atmosphere * intensity);
            }
          `}
          side={THREE.BackSide}
          transparent
          blending={THREE.AdditiveBlending}
          depthWrite={false}
        />
      </mesh>

      {/* Loading state - show loading sphere that covers the main sphere */}
      {!texturesLoaded && (
        <mesh>
          <sphereGeometry args={[radius * 1.001, 64, 64]} />
          <meshPhongMaterial 
            color={0x1e3a8a}
            emissive={0x0a1929}
            emissiveIntensity={0.5}
          />
        </mesh>
      )}
    </group>
  );
};