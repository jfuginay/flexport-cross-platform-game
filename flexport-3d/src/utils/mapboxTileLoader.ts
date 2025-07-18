import * as THREE from 'three';

interface TileInfo {
  x: number;
  y: number;
  z: number;
  url: string;
}

export class MapboxTileLoader {
  private token: string;
  private style: string;
  
  constructor(token: string, style: string = 'satellite-v9') {
    this.token = token;
    this.style = style;
  }

  // Convert lat/lon to tile coordinates
  private latLonToTile(lat: number, lon: number, zoom: number): { x: number; y: number } {
    const n = Math.pow(2, zoom);
    const x = Math.floor((lon + 180) / 360 * n);
    const latRad = lat * Math.PI / 180;
    const y = Math.floor((1 - Math.asinh(Math.tan(latRad)) / Math.PI) / 2 * n);
    return { x, y };
  }

  // Get tile URL
  private getTileUrl(x: number, y: number, z: number): string {
    return `https://api.mapbox.com/v4/mapbox.${this.style}/${z}/${x}/${y}@2x.png?access_token=${this.token}`;
  }

  // Load a single tile
  private async loadTile(tileInfo: TileInfo): Promise<HTMLImageElement> {
    return new Promise((resolve, reject) => {
      const img = new Image();
      img.crossOrigin = 'anonymous';
      img.onload = () => resolve(img);
      img.onerror = () => reject(new Error(`Failed to load tile: ${tileInfo.url}`));
      img.src = tileInfo.url;
    });
  }

  // Create equirectangular texture from tiles
  async createWorldTexture(resolution: number = 4096): Promise<THREE.Texture> {
    const canvas = document.createElement('canvas');
    canvas.width = resolution;
    canvas.height = resolution / 2;
    const ctx = canvas.getContext('2d')!;

    // Fill with ocean color
    ctx.fillStyle = '#071a2e';
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    // Calculate tile coverage for equirectangular projection
    const zoom = 3; // Higher zoom for more detail
    const tileSize = 512;
    
    // Load tiles covering the world
    const tilesX = Math.pow(2, zoom);
    const tilesY = Math.pow(2, zoom - 1);
    
    const tileWidth = canvas.width / tilesX;
    const tileHeight = canvas.height / tilesY;

    // Load all tiles in parallel batches
    const batchSize = 10;
    for (let y = 0; y < tilesY; y++) {
      const tileBatch: Promise<{ x: number; y: number; img: HTMLImageElement } | null>[] = [];
      
      for (let x = 0; x < tilesX; x++) {
        const tileInfo: TileInfo = {
          x,
          y,
          z: zoom,
          url: this.getTileUrl(x, y, zoom)
        };
        
        tileBatch.push(
          this.loadTile(tileInfo)
            .then(img => ({ x, y, img }))
            .catch((error) => {
              console.warn(`Failed to load tile ${x},${y}:`, error);
              return null;
            })
        );
        
        if (tileBatch.length >= batchSize || x === tilesX - 1) {
          const results = await Promise.all(tileBatch);
          
          // Draw successfully loaded tiles
          results.forEach(result => {
            if (result !== null) {
              const destX = result.x * tileWidth;
              const destY = result.y * tileHeight;
              ctx.drawImage(result.img, destX, destY, tileWidth, tileHeight);
            }
          });
          
          tileBatch.length = 0;
        }
      }
    }

    // Apply color correction for better visibility
    const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
    const data = imageData.data;
    
    for (let i = 0; i < data.length; i += 4) {
      // Brighten the image slightly
      data[i] = Math.min(255, data[i] * 1.2);     // R
      data[i + 1] = Math.min(255, data[i + 1] * 1.2); // G
      data[i + 2] = Math.min(255, data[i + 2] * 1.3); // B (boost blue for oceans)
    }
    
    ctx.putImageData(imageData, 0, 0);

    // Create Three.js texture
    const texture = new THREE.CanvasTexture(canvas);
    texture.needsUpdate = true;
    texture.minFilter = THREE.LinearMipmapLinearFilter;
    texture.magFilter = THREE.LinearFilter;
    texture.anisotropy = 16;
    texture.wrapS = THREE.RepeatWrapping;
    texture.wrapT = THREE.ClampToEdgeWrapping;
    
    return texture;
  }

  // Create a static world image texture (simpler approach)
  async createStaticWorldTexture(): Promise<THREE.Texture> {
    const width = 2048;
    const height = 1024;
    
    // Use Mapbox Static API for a world view
    const url = `https://api.mapbox.com/styles/v1/mapbox/${this.style}/static/0,0,1,0/${width}x${height}@2x?access_token=${this.token}`;
    
    return new Promise((resolve, reject) => {
      new THREE.TextureLoader().load(
        url,
        (texture) => {
          texture.minFilter = THREE.LinearMipmapLinearFilter;
          texture.magFilter = THREE.LinearFilter;
          texture.anisotropy = 16;
          resolve(texture);
        },
        undefined,
        reject
      );
    });
  }
}