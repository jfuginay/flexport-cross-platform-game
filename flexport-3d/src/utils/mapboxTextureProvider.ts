import * as THREE from 'three';

interface MapboxConfig {
  accessToken: string;
  style?: string; // 'satellite-v9', 'streets-v11', 'dark-v10', etc.
  resolution?: number; // texture resolution
}

export class MapboxTextureProvider {
  private accessToken: string;
  private style: string;
  private resolution: number;
  private textureLoader: THREE.TextureLoader;
  private canvas: HTMLCanvasElement;
  private ctx: CanvasRenderingContext2D;

  constructor(config: MapboxConfig) {
    this.accessToken = config.accessToken || process.env.REACT_APP_MAPBOX_TOKEN || '';
    this.style = config.style || 'satellite-streets-v12';
    this.resolution = config.resolution || 4096; // High resolution for globe
    this.textureLoader = new THREE.TextureLoader();
    
    // Create canvas for texture assembly
    this.canvas = document.createElement('canvas');
    this.canvas.width = this.resolution;
    this.canvas.height = this.resolution / 2; // Equirectangular projection is 2:1
    this.ctx = this.canvas.getContext('2d')!;
  }

  /**
   * Creates a sphere texture using Mapbox Static Images API
   * We'll fetch multiple tiles and stitch them together for high quality
   */
  async createGlobeTexture(): Promise<THREE.Texture> {
    // For a proper globe texture, we need an equirectangular projection
    // We'll fetch tiles at different lat/lon positions and stitch them
    
    const tileSize = 512;
    const zoom = 2; // Adjust for detail level
    
    // Calculate how many tiles we need
    const tilesX = Math.ceil(this.resolution / tileSize);
    const tilesY = Math.ceil((this.resolution / 2) / tileSize);
    
    // Clear canvas
    this.ctx.fillStyle = '#000';
    this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
    
    // Load tiles in parallel for better performance
    const tilePromises: Promise<void>[] = [];
    
    for (let y = 0; y < tilesY; y++) {
      for (let x = 0; x < tilesX; x++) {
        // Convert tile position to lat/lon
        const lon = (x / tilesX) * 360 - 180;
        const lat = 90 - (y / tilesY) * 180;
        
        tilePromises.push(this.loadTile(x, y, lat, lon, tileSize, zoom));
      }
    }
    
    // Wait for all tiles to load
    await Promise.all(tilePromises);
    
    // Create Three.js texture from canvas
    const texture = new THREE.CanvasTexture(this.canvas);
    texture.needsUpdate = true;
    texture.minFilter = THREE.LinearMipmapLinearFilter;
    texture.magFilter = THREE.LinearFilter;
    texture.anisotropy = 16;
    
    return texture;
  }

  /**
   * Load a single map tile
   */
  private async loadTile(
    tileX: number,
    tileY: number,
    lat: number,
    lon: number,
    tileSize: number,
    zoom: number
  ): Promise<void> {
    // Mapbox Static Images API URL
    const url = `https://api.mapbox.com/styles/v1/mapbox/${this.style}/static/` +
      `${lon},${lat},${zoom}/` +
      `${tileSize}x${tileSize}@2x` +
      `?access_token=${this.accessToken}`;
    
    return new Promise((resolve, reject) => {
      const img = new Image();
      img.crossOrigin = 'anonymous';
      
      img.onload = () => {
        // Draw tile to canvas at correct position
        const x = tileX * tileSize;
        const y = tileY * tileSize;
        this.ctx.drawImage(img, x, y, tileSize, tileSize);
        resolve();
      };
      
      img.onerror = (error) => {
        console.error('Failed to load Mapbox tile:', error);
        resolve(); // Continue even if one tile fails
      };
      
      img.src = url;
    });
  }

  /**
   * Alternative: Create texture using Mapbox GL JS rendered to canvas
   * This provides more control but is more complex
   */
  async createGlobeTextureWithMapboxGL(): Promise<THREE.Texture> {
    // This would involve creating an offscreen Mapbox GL map
    // and rendering it to a canvas, then using that as texture
    // More complex but provides full Mapbox GL features
    
    // For now, we'll use the static API approach above
    return this.createGlobeTexture();
  }

  /**
   * Get a simple static map texture for testing
   */
  async getSimpleTexture(): Promise<THREE.Texture> {
    const url = `https://api.mapbox.com/styles/v1/mapbox/${this.style}/static/` +
      `0,0,1/` +
      `1024x512@2x` +
      `?access_token=${this.accessToken}`;
    
    return new Promise((resolve, reject) => {
      this.textureLoader.load(
        url,
        (texture) => {
          texture.minFilter = THREE.LinearMipmapLinearFilter;
          texture.magFilter = THREE.LinearFilter;
          resolve(texture);
        },
        undefined,
        (error) => {
          console.error('Failed to load Mapbox texture:', error);
          reject(error);
        }
      );
    });
  }
}