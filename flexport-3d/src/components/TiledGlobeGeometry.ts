import * as THREE from 'three';
import { SphericalMapping } from '../utils/SphericalMapping';
import { TileFetchingService } from '../services/TileFetchingService';

export interface TileInfo {
  x: number;
  y: number;
  z: number;
  texture?: THREE.Texture;
  bounds: { minU: number; minV: number; maxU: number; maxV: number };
}

export class TiledGlobeGeometry {
  private radius: number;
  private widthSegments: number;
  private heightSegments: number;
  private tileService: TileFetchingService;
  private tiles: Map<string, TileInfo> = new Map();
  private geometry: THREE.BufferGeometry;
  private material: THREE.ShaderMaterial;
  private maxTilesPerBatch = 16; // GPU limit for texture arrays (WebGL MAX_TEXTURE_IMAGE_UNITS)
  
  constructor(
    radius: number = 100,
    widthSegments: number = 256,
    heightSegments: number = 128
  ) {
    this.radius = radius;
    this.widthSegments = widthSegments;
    this.heightSegments = heightSegments;
    this.tileService = new TileFetchingService();
    this.geometry = this.createBaseGeometry();
    this.material = this.createMaterial();
  }
  
  private createBaseGeometry(): THREE.BufferGeometry {
    const geometry = new THREE.BufferGeometry();
    
    const vertices: number[] = [];
    const normals: number[] = [];
    const uvs: number[] = [];
    const indices: number[] = [];
    const tileIndices: number[] = [];
    
    // Generate sphere vertices with proper UV mapping
    for (let y = 0; y <= this.heightSegments; y++) {
      const v = y / this.heightSegments;
      const theta = v * Math.PI; // 0 to PI (north to south)
      
      for (let x = 0; x <= this.widthSegments; x++) {
        const u = x / this.widthSegments;
        const phi = u * Math.PI * 2; // 0 to 2PI (around equator)
        
        // Calculate position on sphere
        const sinTheta = Math.sin(theta);
        const cosTheta = Math.cos(theta);
        const sinPhi = Math.sin(phi);
        const cosPhi = Math.cos(phi);
        
        const px = this.radius * sinTheta * cosPhi;
        const py = this.radius * cosTheta;
        const pz = this.radius * sinTheta * sinPhi;
        
        vertices.push(px, py, pz);
        normals.push(sinTheta * cosPhi, cosTheta, sinTheta * sinPhi);
        uvs.push(u, 1 - v);
        tileIndices.push(-1); // Will be updated when tiles are loaded
      }
    }
    
    // Generate indices for triangles
    for (let y = 0; y < this.heightSegments; y++) {
      for (let x = 0; x < this.widthSegments; x++) {
        const a = (this.widthSegments + 1) * y + x;
        const b = (this.widthSegments + 1) * (y + 1) + x;
        const c = (this.widthSegments + 1) * (y + 1) + (x + 1);
        const d = (this.widthSegments + 1) * y + (x + 1);
        
        indices.push(a, b, d);
        indices.push(b, c, d);
      }
    }
    
    geometry.setAttribute('position', new THREE.Float32BufferAttribute(vertices, 3));
    geometry.setAttribute('normal', new THREE.Float32BufferAttribute(normals, 3));
    geometry.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2));
    geometry.setAttribute('tileIndex', new THREE.Float32BufferAttribute(tileIndices, 1));
    geometry.setIndex(indices);
    
    return geometry;
  }
  
  private createMaterial(): THREE.ShaderMaterial {
    // Initialize with empty textures
    const tileTextures: THREE.Texture[] = [];
    const tileBounds = new Float32Array(this.maxTilesPerBatch * 4);
    
    // Create placeholder textures
    for (let i = 0; i < this.maxTilesPerBatch; i++) {
      const canvas = document.createElement('canvas');
      canvas.width = 1;
      canvas.height = 1;
      const ctx = canvas.getContext('2d')!;
      ctx.fillStyle = '#1e3a5f';
      ctx.fillRect(0, 0, 1, 1);
      
      const texture = new THREE.CanvasTexture(canvas);
      tileTextures.push(texture);
    }
    
    const material = new THREE.ShaderMaterial({
      uniforms: {
        tileTextures: { value: tileTextures },
        tileBounds: { value: tileBounds },
        numTiles: { value: 0 },
        tileOpacity: { value: 1.0 },
        lightDirection: { value: new THREE.Vector3(1, 1, 0.5).normalize() },
        time: { value: 0 }
      },
      vertexShader: this.getVertexShader(),
      fragmentShader: this.getFragmentShader(),
      transparent: true,
      side: THREE.FrontSide
    });
    
    return material;
  }
  
  private getVertexShader(): string {
    return `
      attribute float tileIndex;
      
      varying vec2 vUv;
      varying vec3 vNormal;
      varying vec3 vPosition;
      varying float vTileIndex;
      varying vec3 vWorldPosition;
      
      void main() {
        vUv = uv;
        vTileIndex = tileIndex;
        vNormal = normalize(normalMatrix * normal);
        
        vec4 mvPosition = modelViewMatrix * vec4(position, 1.0);
        vPosition = mvPosition.xyz;
        vWorldPosition = (modelMatrix * vec4(position, 1.0)).xyz;
        
        gl_Position = projectionMatrix * mvPosition;
      }
    `;
  }
  
  private getFragmentShader(): string {
    return `
      #define MAX_TILES 16
      
      uniform sampler2D tileTextures[MAX_TILES];
      uniform vec4 tileBounds[MAX_TILES];
      uniform int numTiles;
      uniform float tileOpacity;
      uniform vec3 lightDirection;
      uniform float time;
      
      varying vec2 vUv;
      varying vec3 vNormal;
      varying vec3 vPosition;
      varying float vTileIndex;
      varying vec3 vWorldPosition;
      
      vec4 sampleTileTexture(int tileIdx, vec2 uv) {
        if (tileIdx < 0 || tileIdx >= numTiles) return vec4(0.0);
        
        vec4 bounds = tileBounds[tileIdx];
        vec2 tileUv = (uv - bounds.xy) / (bounds.zw - bounds.xy);
        tileUv = clamp(tileUv, 0.001, 0.999);
        
        // Manual texture array indexing due to WebGL limitations
        ${Array.from({ length: 16 }, (_, i) => `
        if (tileIdx == ${i}) return texture2D(tileTextures[${i}], tileUv);
        `).join('')}
        
        return vec4(0.0);
      }
      
      float getBlendWeight(vec2 uv, vec4 bounds) {
        float margin = 0.005;
        
        float leftBlend = smoothstep(bounds.x, bounds.x + margin, uv.x);
        float rightBlend = 1.0 - smoothstep(bounds.z - margin, bounds.z, uv.x);
        float bottomBlend = smoothstep(bounds.y, bounds.y + margin, uv.y);
        float topBlend = 1.0 - smoothstep(bounds.w - margin, bounds.w, uv.y);
        
        return leftBlend * rightBlend * bottomBlend * topBlend;
      }
      
      void main() {
        vec4 finalColor = vec4(0.0);
        float totalWeight = 0.0;
        
        // Find overlapping tiles
        for (int i = 0; i < MAX_TILES; i++) {
          if (i >= numTiles) break;
          
          vec4 bounds = tileBounds[i];
          if (vUv.x >= bounds.x && vUv.x <= bounds.z && 
              vUv.y >= bounds.y && vUv.y <= bounds.w) {
            
            float weight = getBlendWeight(vUv, bounds);
            vec4 tileColor = sampleTileTexture(i, vUv);
            
            finalColor += tileColor * weight;
            totalWeight += weight;
          }
        }
        
        if (totalWeight > 0.0) {
          finalColor /= totalWeight;
        } else {
          // More visible fallback color to debug tile loading
          finalColor = vec4(1.0, 0.0, 0.0, 1.0); // Red for debugging
        }
        
        // Apply lighting
        float NdotL = max(dot(vNormal, normalize(lightDirection)), 0.0);
        float lightIntensity = NdotL * 0.5 + 0.5;
        finalColor.rgb *= lightIntensity;
        
        // Atmospheric scattering
        vec3 viewDir = normalize(-vPosition);
        float rim = 1.0 - max(dot(viewDir, vNormal), 0.0);
        rim = pow(rim, 2.0);
        
        vec3 atmosphereColor = vec3(0.3, 0.5, 0.9);
        finalColor.rgb = mix(finalColor.rgb, atmosphereColor, rim * 0.2);
        
        gl_FragColor = vec4(finalColor.rgb, tileOpacity);
      }
    `;
  }
  
  async loadTilesForView(
    centerLat: number,
    centerLng: number,
    zoom: number,
    viewportWidth: number,
    viewportHeight: number
  ) {
    const neededTiles = this.tileService.getTilesForViewport(
      centerLat,
      centerLng,
      zoom,
      viewportWidth,
      viewportHeight
    );
    
    console.log(`Loading ${neededTiles.length} tiles at zoom ${zoom} for center (${centerLat}, ${centerLng})`);
    
    const loadPromises = neededTiles.map(async (tile) => {
      const key = `${tile.z}-${tile.x}-${tile.y}`;
      
      if (!this.tiles.has(key)) {
        try {
          const img = await this.tileService.fetchMapTilerTile(tile.x, tile.y, tile.z);
          console.log(`Successfully loaded tile ${key}, image size: ${img.width}x${img.height}`);
          
          const texture = new THREE.Texture(img);
          texture.needsUpdate = true;
          texture.minFilter = THREE.LinearMipmapLinearFilter;
          texture.magFilter = THREE.LinearFilter;
          texture.generateMipmaps = true;
          
          const bounds = this.tileToBounds(tile.x, tile.y, tile.z);
          
          this.tiles.set(key, {
            ...tile,
            texture,
            bounds: {
              minU: (bounds.lng1 + 180) / 360,
              maxU: (bounds.lng2 + 180) / 360,
              minV: 1 - (bounds.lat2 + 90) / 180,  // Fixed: swapped lat1 and lat2
              maxV: 1 - (bounds.lat1 + 90) / 180
            }
          });
        } catch (error) {
          console.error(`Failed to load tile ${key}:`, error);
        }
      }
    });
    
    await Promise.all(loadPromises);
    console.log(`Total tiles loaded: ${this.tiles.size}`);
    this.updateMaterialTextures();
  }
  
  private tileToBounds(x: number, y: number, z: number) {
    const n = Math.pow(2, z);
    const lng1 = x / n * 360 - 180;
    const lat1 = Math.atan(Math.sinh(Math.PI * (1 - 2 * y / n))) * 180 / Math.PI;
    const lng2 = (x + 1) / n * 360 - 180;
    const lat2 = Math.atan(Math.sinh(Math.PI * (1 - 2 * (y + 1) / n))) * 180 / Math.PI;
    return { lat1, lng1, lat2, lng2 };
  }
  
  private updateMaterialTextures() {
    const activeTiles = Array.from(this.tiles.values())
      .filter(tile => tile.texture)
      .slice(0, this.maxTilesPerBatch);
    
    console.log(`Updating material with ${activeTiles.length} active tiles`);
    
    const textures: THREE.Texture[] = [];
    const bounds = new Float32Array(this.maxTilesPerBatch * 4);
    
    activeTiles.forEach((tile, index) => {
      if (tile.texture) {
        textures[index] = tile.texture;
        bounds[index * 4] = tile.bounds.minU;
        bounds[index * 4 + 1] = tile.bounds.minV;
        bounds[index * 4 + 2] = tile.bounds.maxU;
        bounds[index * 4 + 3] = tile.bounds.maxV;
        
        console.log(`Tile ${index}: bounds UV (${tile.bounds.minU.toFixed(3)}, ${tile.bounds.minV.toFixed(3)}) to (${tile.bounds.maxU.toFixed(3)}, ${tile.bounds.maxV.toFixed(3)})`);
      }
    });
    
    // Fill remaining slots with placeholder textures
    for (let i = textures.length; i < this.maxTilesPerBatch; i++) {
      const canvas = document.createElement('canvas');
      canvas.width = 1;
      canvas.height = 1;
      const ctx = canvas.getContext('2d')!;
      ctx.fillStyle = '#1e3a5f';
      ctx.fillRect(0, 0, 1, 1);
      textures[i] = new THREE.CanvasTexture(canvas);
    }
    
    // Update uniforms
    this.material.uniforms.tileTextures.value = textures;
    this.material.uniforms.tileBounds.value = bounds;
    this.material.uniforms.numTiles.value = activeTiles.length;
    this.material.uniforms.tileOpacity.value = 1.0; // Ensure full opacity
    this.material.needsUpdate = true;
    
    console.log('Material uniforms updated:', {
      numTiles: activeTiles.length,
      tileOpacity: this.material.uniforms.tileOpacity.value
    });
  }
  
  update(deltaTime: number) {
    this.material.uniforms.time.value += deltaTime;
  }
  
  getGeometry(): THREE.BufferGeometry {
    return this.geometry;
  }
  
  getMaterial(): THREE.ShaderMaterial {
    return this.material;
  }
  
  dispose() {
    this.geometry.dispose();
    this.material.dispose();
    
    this.tiles.forEach(tile => {
      if (tile.texture) {
        tile.texture.dispose();
      }
    });
    
    this.tiles.clear();
  }
}