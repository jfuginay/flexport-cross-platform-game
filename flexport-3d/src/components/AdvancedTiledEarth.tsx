import React, { useRef, useEffect, useState, useMemo } from 'react';
import { useFrame, useThree } from '@react-three/fiber';
import * as THREE from 'three';
import { TiledGlobeGeometry } from './TiledGlobeGeometry';
import { MapProviderService } from '../services/MapProviderService';
import { TiledGlobeShaders, createOceanUniforms, createAtmosphereUniforms } from '../shaders/GlobeShaders';

interface AdvancedTiledEarthProps {
  radius?: number;
  segments?: number;
  isRotating?: boolean;
  rotationSpeed?: number;
  children?: React.ReactNode;
}

export const AdvancedTiledEarth: React.FC<AdvancedTiledEarthProps> = ({
  radius = 100,
  segments = 256,
  isRotating = true,
  rotationSpeed = 0.0002,
  children
}) => {
  const groupRef = useRef<THREE.Group>(null);
  const meshRef = useRef<THREE.Mesh>(null);
  const oceanRef = useRef<THREE.Mesh>(null);
  const { camera } = useThree();
  
  const [tiledGlobe, setTiledGlobe] = useState<TiledGlobeGeometry | null>(null);
  const [mapProvider] = useState(() => new MapProviderService());
  const [currentZoom, setCurrentZoom] = useState(3);
  const [isLoading, setIsLoading] = useState(true);
  
  // Ocean shader material
  const oceanMaterial = useMemo(() => {
    // Create ocean mask texture
    const maskCanvas = document.createElement('canvas');
    maskCanvas.width = 512;
    maskCanvas.height = 256;
    const ctx = maskCanvas.getContext('2d')!;
    
    // Simple ocean mask - would be replaced with real data
    ctx.fillStyle = '#000000';
    ctx.fillRect(0, 0, maskCanvas.width, maskCanvas.height);
    ctx.fillStyle = '#FFFFFF';
    // Draw approximate ocean areas
    ctx.fillRect(0, 0, maskCanvas.width, maskCanvas.height);
    
    const oceanMask = new THREE.CanvasTexture(maskCanvas);
    
    // Create foam texture
    const foamCanvas = document.createElement('canvas');
    foamCanvas.width = 256;
    foamCanvas.height = 256;
    const foamCtx = foamCanvas.getContext('2d')!;
    
    // Generate noise pattern for foam
    for (let x = 0; x < 256; x++) {
      for (let y = 0; y < 256; y++) {
        const noise = Math.random();
        const color = Math.floor(noise * 255);
        foamCtx.fillStyle = `rgb(${color},${color},${color})`;
        foamCtx.fillRect(x, y, 1, 1);
      }
    }
    
    const foamTexture = new THREE.CanvasTexture(foamCanvas);
    foamTexture.wrapS = THREE.RepeatWrapping;
    foamTexture.wrapT = THREE.RepeatWrapping;
    
    const uniforms = createOceanUniforms(oceanMask, foamTexture);
    
    return new THREE.ShaderMaterial({
      uniforms,
      vertexShader: TiledGlobeShaders.oceanVertexShader,
      fragmentShader: TiledGlobeShaders.oceanFragmentShader,
      transparent: true,
      depthWrite: false,
      side: THREE.FrontSide
    });
  }, []);
  
  // Atmosphere material
  const atmosphereMaterial = useMemo(() => {
    return new THREE.ShaderMaterial({
      uniforms: createAtmosphereUniforms(),
      vertexShader: TiledGlobeShaders.atmosphereVertexShader,
      fragmentShader: TiledGlobeShaders.atmosphereFragmentShader,
      side: THREE.BackSide,
      blending: THREE.AdditiveBlending,
      transparent: true,
      depthWrite: false
    });
  }, []);
  
  // Initialize tiled globe
  useEffect(() => {
    const globe = new TiledGlobeGeometry(radius, segments, segments / 2);
    setTiledGlobe(globe);
    
    // Initial tile load
    const loadInitialTiles = async () => {
      setIsLoading(true);
      try {
        await globe.loadTilesForView(0, 0, currentZoom, 1920, 1080);
        
        // Preload adjacent areas
        await mapProvider.preloadTilesForArea(0, 0, currentZoom, 3);
      } catch (error) {
        console.error('Failed to load initial tiles:', error);
      }
      setIsLoading(false);
    };
    
    loadInitialTiles();
    
    return () => {
      globe.dispose();
    };
  }, [radius, segments]);
  
  // Update tiles based on camera distance (LOD)
  useEffect(() => {
    if (!tiledGlobe || !groupRef.current) return;
    
    const updateTiles = async () => {
      if (!groupRef.current || !meshRef.current) return;
      
      const distance = camera.position.distanceTo(groupRef.current.position);
      
      // Calculate appropriate zoom level based on distance
      let newZoom = 3;
      if (distance < 150) newZoom = 6;
      else if (distance < 200) newZoom = 5;
      else if (distance < 300) newZoom = 4;
      
      if (newZoom !== currentZoom) {
        setCurrentZoom(newZoom);
        
        // Get camera view direction
        const viewDir = new THREE.Vector3();
        camera.getWorldDirection(viewDir);
        
        // Calculate lat/lng of view center
        const raycaster = new THREE.Raycaster();
        raycaster.set(camera.position, viewDir);
        
        const intersects = raycaster.intersectObject(meshRef.current);
        if (intersects.length > 0) {
          const point = intersects[0].point;
          const lat = Math.asin(point.y / radius) * 180 / Math.PI;
          const lng = Math.atan2(point.z, point.x) * 180 / Math.PI;
          
          await tiledGlobe.loadTilesForView(lat, lng, newZoom, 1920, 1080);
        }
      }
    };
    
    const interval = setInterval(updateTiles, 1000); // Check every second
    
    return () => clearInterval(interval);
  }, [tiledGlobe, currentZoom, camera, radius]);
  
  // Animation loop
  useFrame((state, delta) => {
    if (groupRef.current && isRotating) {
      groupRef.current.rotation.y += rotationSpeed;
    }
    
    if (tiledGlobe) {
      tiledGlobe.update(delta);
    }
    
    // Update ocean shader time
    if (oceanMaterial.uniforms.time) {
      oceanMaterial.uniforms.time.value = state.clock.elapsedTime;
    }
    
    // Update ocean view position for specular
    if (oceanMaterial.uniforms.viewPosition) {
      oceanMaterial.uniforms.viewPosition.value.copy(camera.position);
    }
  });
  
  // Debug: Log provider statistics
  useEffect(() => {
    const interval = setInterval(() => {
      console.log('Provider Stats:', mapProvider.getProviderStats());
    }, 30000); // Every 30 seconds
    
    return () => clearInterval(interval);
  }, [mapProvider]);
  
  if (!tiledGlobe) return null;
  
  return (
    <group ref={groupRef}>
      {/* Main Earth sphere with tiles */}
      <mesh 
        ref={meshRef}
        geometry={tiledGlobe.getGeometry()}
        material={tiledGlobe.getMaterial()}
        castShadow
        receiveShadow
      />
      
      {/* Ocean layer - temporarily disabled to see land tiles */}
      {/* <mesh ref={oceanRef} scale={[1.002, 1.002, 1.002]}>
        <sphereGeometry args={[radius, segments, segments / 2]} />
        <primitive object={oceanMaterial} />
      </mesh> */}
      
      {/* Atmosphere */}
      <mesh scale={[1.03, 1.03, 1.03]}>
        <sphereGeometry args={[radius, segments / 2, segments / 2]} />
        <primitive object={atmosphereMaterial} />
      </mesh>
      
      {/* Cloud layer */}
      <mesh scale={[1.01, 1.01, 1.01]} rotation={[0, 0, 0.05]}>
        <sphereGeometry args={[radius, segments, segments / 2]} />
        <meshPhongMaterial
          color={0xffffff}
          transparent
          opacity={0.1}
          depthWrite={false}
        />
      </mesh>
      
      {/* Loading indicator */}
      {isLoading && (
        <mesh position={[0, radius + 20, 0]}>
          <boxGeometry args={[10, 2, 10]} />
          <meshBasicMaterial color={0x00ff00} />
        </mesh>
      )}
      
      {/* Provider stats display */}
      <group position={[0, -radius - 20, 0]}>
        <mesh>
          <planeGeometry args={[100, 20]} />
          <meshBasicMaterial color={0x000000} opacity={0.5} transparent />
        </mesh>
      </group>
      
      {/* Children (ports, etc.) */}
      {children}
    </group>
  );
};