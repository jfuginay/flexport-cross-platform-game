import React, { useRef, useEffect, useState } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';

interface MapTilerEarthProps {
  radius?: number;
  segments?: number;
  isRotating?: boolean;
  rotationSpeed?: number;
  children?: React.ReactNode;
}

export const MapTilerEarth: React.FC<MapTilerEarthProps> = ({
  radius = 100,
  segments = 256,
  isRotating = true,
  rotationSpeed = 0.0002,
  children
}) => {
  const groupRef = useRef<THREE.Group>(null);
  const [earthTexture, setEarthTexture] = useState<THREE.Texture | null>(null);
  const [oceanTexture, setOceanTexture] = useState<THREE.Texture | null>(null);
  const [loading, setLoading] = useState(true);
  
  useEffect(() => {
    const loadMapTilerTextures = async () => {
      // MapTiler API key
      const mapTilerKey = process.env.REACT_APP_MAPTILER_KEY || 'YbCOFqTnXk0xnOtrQ6vG';
      
      // Create canvas for the globe texture
      const canvas = document.createElement('canvas');
      const size = 4096;
      canvas.width = size;
      canvas.height = size / 2;
      const ctx = canvas.getContext('2d')!;
      
      // Fill with ocean base color
      ctx.fillStyle = '#1e3a5f';
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      
      try {
        // Load multiple tiles for better coverage
        const zoom = 2;
        const tilePromises = [];
        
        // Load satellite tiles to cover the world
        for (let lon = -180; lon <= 180; lon += 90) {
          for (let lat = -60; lat <= 60; lat += 60) {
            const url = `https://api.maptiler.com/maps/satellite/static/${lon},${lat},${zoom}/512x512@2x.png?key=${mapTilerKey}`;
            tilePromises.push(loadTileToCanvas(url, lon, lat, zoom, ctx, canvas.width, canvas.height));
          }
        }
        
        await Promise.all(tilePromises);
        
        // Load ocean/hybrid overlay for better land/sea definition
        const hybridUrl = `https://api.maptiler.com/maps/hybrid/static/0,0,1/2048x1024@2x.png?key=${mapTilerKey}`;
        const hybridImg = await loadImage(hybridUrl);
        
        // Apply hybrid overlay
        ctx.globalCompositeOperation = 'multiply';
        ctx.drawImage(hybridImg, 0, 0, canvas.width, canvas.height);
        ctx.globalCompositeOperation = 'source-over';
        
        // Create ocean texture
        const oceanCanvas = document.createElement('canvas');
        oceanCanvas.width = size;
        oceanCanvas.height = size / 2;
        const oceanCtx = oceanCanvas.getContext('2d')!;
        oceanCtx.drawImage(hybridImg, 0, 0, oceanCanvas.width, oceanCanvas.height);
        
        // Create textures
        const earthTex = new THREE.CanvasTexture(canvas);
        earthTex.needsUpdate = true;
        earthTex.minFilter = THREE.LinearMipmapLinearFilter;
        earthTex.magFilter = THREE.LinearFilter;
        earthTex.anisotropy = 16;
        
        const oceanTex = new THREE.CanvasTexture(oceanCanvas);
        oceanTex.needsUpdate = true;
        
        setEarthTexture(earthTex);
        setOceanTexture(oceanTex);
      } catch (error) {
        console.error('Failed to load MapTiler textures:', error);
        
        // Fallback to standard Earth texture
        const loader = new THREE.TextureLoader();
        loader.load(
          'https://raw.githubusercontent.com/mrdoob/three.js/dev/examples/textures/planets/earth_atmos_2048.jpg',
          (texture) => {
            setEarthTexture(texture);
          }
        );
      }
      
      setLoading(false);
    };
    
    const loadImage = (url: string): Promise<HTMLImageElement> => {
      return new Promise((resolve, reject) => {
        const img = new Image();
        img.crossOrigin = 'anonymous';
        img.onload = () => resolve(img);
        img.onerror = reject;
        img.src = url;
      });
    };
    
    const loadTileToCanvas = async (
      url: string, 
      lon: number, 
      lat: number, 
      zoom: number,
      ctx: CanvasRenderingContext2D,
      canvasWidth: number,
      canvasHeight: number
    ) => {
      try {
        const img = await loadImage(url);
        
        // Convert lon/lat to canvas coordinates
        const x = ((lon + 180) / 360) * canvasWidth;
        const y = ((90 - lat) / 180) * canvasHeight;
        
        // Draw tile at calculated position
        const tileSize = canvasWidth / 4; // Approximate size for zoom level 2
        ctx.drawImage(img, x - tileSize/2, y - tileSize/2, tileSize, tileSize);
      } catch (error) {
        console.warn(`Failed to load tile at ${lon},${lat}:`, error);
      }
    };
    
    loadMapTilerTextures();
  }, []);
  
  useFrame((state, delta) => {
    if (groupRef.current && isRotating) {
      groupRef.current.rotation.y += rotationSpeed;
    }
  });
  
  // Custom shader for realistic ocean
  const oceanShader = {
    uniforms: {
      time: { value: 0 },
      oceanTexture: { value: oceanTexture },
      baseColor: { value: new THREE.Color(0x006994) },
      foamColor: { value: new THREE.Color(0xffffff) }
    },
    vertexShader: `
      varying vec2 vUv;
      varying vec3 vNormal;
      varying vec3 vPosition;
      uniform float time;
      
      void main() {
        vUv = uv;
        vNormal = normalize(normalMatrix * normal);
        
        // Add subtle wave motion
        vec3 pos = position;
        float wave = sin(position.x * 0.1 + time) * cos(position.z * 0.1 + time) * 0.2;
        pos += normal * wave;
        
        vPosition = (modelViewMatrix * vec4(pos, 1.0)).xyz;
        gl_Position = projectionMatrix * modelViewMatrix * vec4(pos, 1.0);
      }
    `,
    fragmentShader: `
      uniform sampler2D oceanTexture;
      uniform vec3 baseColor;
      uniform vec3 foamColor;
      uniform float time;
      varying vec2 vUv;
      varying vec3 vNormal;
      varying vec3 vPosition;
      
      void main() {
        vec4 oceanData = texture2D(oceanTexture, vUv);
        
        // Base ocean color
        vec3 color = mix(baseColor * 0.8, baseColor * 1.2, oceanData.b);
        
        // Add foam on coasts
        float coastLine = smoothstep(0.4, 0.6, oceanData.r);
        color = mix(color, foamColor, coastLine * 0.3);
        
        // Specular for water
        vec3 viewDir = normalize(-vPosition);
        vec3 lightDir = normalize(vec3(1.0, 1.0, 0.5));
        vec3 reflectDir = reflect(-lightDir, vNormal);
        float spec = pow(max(dot(viewDir, reflectDir), 0.0), 32.0);
        color += vec3(0.3, 0.4, 0.5) * spec;
        
        gl_FragColor = vec4(color, 0.95);
      }
    `
  };
  
  useFrame((state) => {
    if (oceanShader.uniforms.time) {
      oceanShader.uniforms.time.value = state.clock.elapsedTime;
    }
  });

  return (
    <group ref={groupRef}>
      {/* Main Earth sphere */}
      <mesh castShadow receiveShadow>
        <sphereGeometry args={[radius, segments, segments]} />
        {earthTexture ? (
          <meshPhongMaterial
            map={earthTexture}
            bumpScale={0.5}
            specular={new THREE.Color(0x101010)}
            shininess={10}
          />
        ) : (
          <meshPhongMaterial
            color={loading ? 0x1e3a5f : 0x4169e1}
            emissive={0x112244}
            emissiveIntensity={0.1}
          />
        )}
      </mesh>

      {/* Ocean layer with custom shader */}
      {oceanTexture && (
        <mesh>
          <sphereGeometry args={[radius * 1.001, segments, segments]} />
          <shaderMaterial
            uniforms={oceanShader.uniforms}
            vertexShader={oceanShader.vertexShader}
            fragmentShader={oceanShader.fragmentShader}
            transparent
            depthWrite={false}
          />
        </mesh>
      )}

      {/* Atmosphere */}
      <mesh scale={[1.02, 1.02, 1.02]}>
        <sphereGeometry args={[radius, segments / 2, segments / 2]} />
        <shaderMaterial
          uniforms={{
            c: { value: 0.3 },
            p: { value: 4.5 },
            glowColor: { value: new THREE.Color(0x4488ff) }
          }}
          vertexShader={`
            uniform float c;
            uniform float p;
            varying float intensity;
            void main() {
              vec3 vNormal = normalize(normalMatrix * normal);
              vec3 vNormel = normalize(normalMatrix * vec3(0.0, 0.0, 1.0));
              intensity = pow(c - dot(vNormal, vNormel), p);
              gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
            }
          `}
          fragmentShader={`
            uniform vec3 glowColor;
            varying float intensity;
            void main() {
              vec3 glow = glowColor * intensity;
              gl_FragColor = vec4(glow, intensity * 0.4);
            }
          `}
          side={THREE.BackSide}
          blending={THREE.AdditiveBlending}
          transparent
          depthWrite={false}
        />
      </mesh>

      {/* Cloud layer */}
      <mesh scale={[1.005, 1.005, 1.005]} rotation={[0, 0, 0.05]}>
        <sphereGeometry args={[radius, segments, segments]} />
        <meshPhongMaterial
          color={0xffffff}
          transparent
          opacity={0.1}
          depthWrite={false}
        />
      </mesh>

      {/* Children (ports) */}
      {children}
    </group>
  );
};