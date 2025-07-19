// @ts-nocheck
import React, { useMemo } from 'react';
import * as THREE from 'three';
import { SimplexNoise } from 'three/examples/jsm/math/SimplexNoise';

interface TerrainProps {
  position?: [number, number, number];
  size?: [number, number];
  segments?: [number, number];
  height?: number;
}

export const Terrain: React.FC<TerrainProps> = ({ 
  position = [0, 0, 0], 
  size = [50, 50],
  segments = [64, 64],
  height = 5
}) => {
  const geometry = useMemo(() => {
    const geom = new THREE.PlaneGeometry(...size, ...segments);
    const simplex = new SimplexNoise();
    
    const vertices = geom.attributes.position.array;
    for (let i = 0; i < vertices.length; i += 3) {
      const x = vertices[i];
      const y = vertices[i + 1];
      
      // Multi-octave noise for realistic terrain
      let elevation = 0;
      elevation += simplex.noise(x * 0.01, y * 0.01) * height;
      elevation += simplex.noise(x * 0.05, y * 0.05) * height * 0.5;
      elevation += simplex.noise(x * 0.1, y * 0.1) * height * 0.25;
      
      // Create beaches near sea level
      if (elevation < 0.5 && elevation > -0.5) {
        elevation *= 0.3;
      }
      
      vertices[i + 2] = elevation;
    }
    
    geom.computeVertexNormals();
    return geom;
  }, [size, segments, height]);

  // Enhanced terrain texturing
  const { colorMap, normalMap } = useMemo(() => {
    // Color map
    const colorCanvas = document.createElement('canvas');
    colorCanvas.width = 1024;
    colorCanvas.height = 1024;
    const colorCtx = colorCanvas.getContext('2d')!;
    
    // Normal map for surface detail
    const normalCanvas = document.createElement('canvas');
    normalCanvas.width = 512;
    normalCanvas.height = 512;
    const normalCtx = normalCanvas.getContext('2d')!;
    
    // Create more detailed terrain coloring
    for (let y = 0; y < colorCanvas.height; y++) {
      for (let x = 0; x < colorCanvas.width; x++) {
        const height = y / colorCanvas.height;
        const noise = Math.random() * 0.1;
        
        let r, g, b;
        if (height < 0.2) {
          // Mountain peaks - rocky
          r = 101 + noise * 20;
          g = 67 + noise * 20;
          b = 33 + noise * 20;
        } else if (height < 0.5) {
          // Forest
          r = 34 + noise * 30;
          g = 139 + noise * 30;
          b = 34 + noise * 20;
        } else if (height < 0.8) {
          // Grassland
          r = 144 + noise * 40;
          g = 238 + noise * 17;
          b = 144 + noise * 20;
        } else if (height < 0.95) {
          // Beach
          r = 244 + noise * 11;
          g = 228 + noise * 15;
          b = 193 + noise * 20;
        } else {
          // Wet sand
          r = 238 + noise * 17;
          g = 203 + noise * 20;
          b = 173 + noise * 20;
        }
        
        colorCtx.fillStyle = `rgb(${Math.floor(r)}, ${Math.floor(g)}, ${Math.floor(b)})`;
        colorCtx.fillRect(x, y, 1, 1);
      }
    }
    
    // Generate normal map
    normalCtx.fillStyle = '#8080ff';
    normalCtx.fillRect(0, 0, 512, 512);
    
    // Add some detail to normal map
    for (let i = 0; i < 1000; i++) {
      const x = Math.random() * 512;
      const y = Math.random() * 512;
      const size = Math.random() * 5 + 1;
      const brightness = Math.random() * 50 + 205;
      normalCtx.fillStyle = `rgb(${brightness}, ${brightness}, 255)`;
      normalCtx.fillRect(x, y, size, size);
    }
    
    const colorTexture = new THREE.CanvasTexture(colorCanvas);
    colorTexture.wrapS = colorTexture.wrapT = THREE.RepeatWrapping;
    
    const normalTexture = new THREE.CanvasTexture(normalCanvas);
    normalTexture.wrapS = normalTexture.wrapT = THREE.RepeatWrapping;
    
    return { colorMap: colorTexture, normalMap: normalTexture };
  }, []);

  return (
    <group position={position}>
      {/* Main terrain - using primitive to ensure it's static */}
      <mesh rotation={[-Math.PI / 2, 0, 0]} receiveShadow castShadow>
        <primitive object={geometry} attach="geometry" />
        <meshStandardMaterial 
          map={colorMap}
          normalMap={normalMap}
          normalScale={new THREE.Vector2(2, 2)}
          roughness={0.85}
          metalness={0.1}
          envMapIntensity={0.5}
          vertexColors={false}
          displacementScale={0}
        />
      </mesh>
      
      {/* Add some trees for visual interest */}
      {useMemo(() => {
        const trees = [];
        const treeCount = Math.floor(size[0] * size[1] / 100);
        
        // Use the terrain geometry to get proper heights
        const simplex = new SimplexNoise();
        
        for (let i = 0; i < treeCount; i++) {
          const x = (Math.random() - 0.5) * size[0] * 0.8; // Keep trees away from edges
          const z = (Math.random() - 0.5) * size[1] * 0.8;
          const scale = 0.8 + Math.random() * 0.4;
          
          // Calculate terrain height at this position
          let terrainHeight = 0;
          terrainHeight += simplex.noise(x * 0.01, z * 0.01) * height;
          terrainHeight += simplex.noise(x * 0.05, z * 0.05) * height * 0.5;
          terrainHeight += simplex.noise(x * 0.1, z * 0.1) * height * 0.25;
          
          // Only place trees on relatively flat areas (not on steep slopes or beaches)
          if (terrainHeight > 0.5 && terrainHeight < height * 0.8) {
            trees.push(
              <group key={`tree-${i}`} position={[x, terrainHeight + 0.1, z]}>
                {/* Tree trunk */}
                <mesh position={[0, scale * 1.5, 0]} castShadow frustumCulled>
                  <cylinderGeometry args={[scale * 0.2, scale * 0.3, scale * 3]} />
                  <meshStandardMaterial 
                    color="#654321" 
                    roughness={0.9}
                    vertexColors={false}
                    displacementScale={0}
                  />
                </mesh>
                {/* Tree leaves */}
                <mesh position={[0, scale * 3.5, 0]} castShadow frustumCulled>
                  <coneGeometry args={[scale * 1.5, scale * 2.5, 8]} />
                  <meshStandardMaterial 
                    color="#228B22" 
                    roughness={0.8}
                    vertexColors={false}
                    displacementScale={0}
                  />
                </mesh>
              </group>
            );
          }
        }
        
        return trees;
      }, [size, height])}
    </group>
  );
};