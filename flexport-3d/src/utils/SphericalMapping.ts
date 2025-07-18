import * as THREE from 'three';

export class SphericalMapping {
  // Convert Mercator tile coordinates to sphere UV
  static tileToSphereUV(tileX: number, tileY: number, zoom: number): { u: number; v: number } {
    const n = Math.pow(2, zoom);
    const lon = (tileX / n) * 360 - 180;
    const lat = Math.atan(Math.sinh(Math.PI * (1 - 2 * tileY / n))) * 180 / Math.PI;
    
    // Convert to UV coordinates (0-1 range)
    const u = (lon + 180) / 360;
    const v = (lat + 90) / 180;
    
    return { u, v };
  }
  
  // Create sphere geometry with custom UV mapping for tiles
  static createTiledSphereGeometry(
    radius: number,
    widthSegments: number,
    heightSegments: number,
    tiles: Array<{ x: number; y: number; z: number }>
  ): THREE.BufferGeometry {
    const geometry = new THREE.BufferGeometry();
    
    const vertices: number[] = [];
    const normals: number[] = [];
    const uvs: number[] = [];
    const indices: number[] = [];
    const tileIndices: number[] = []; // Which tile each vertex belongs to
    
    // Generate vertices
    for (let y = 0; y <= heightSegments; y++) {
      const v = y / heightSegments;
      const theta = v * Math.PI; // 0 to PI (north to south)
      
      for (let x = 0; x <= widthSegments; x++) {
        const u = x / widthSegments;
        const phi = u * Math.PI * 2; // 0 to 2PI (around equator)
        
        // Calculate position on sphere
        const sinTheta = Math.sin(theta);
        const cosTheta = Math.cos(theta);
        const sinPhi = Math.sin(phi);
        const cosPhi = Math.cos(phi);
        
        const px = radius * sinTheta * cosPhi;
        const py = radius * cosTheta;
        const pz = radius * sinTheta * sinPhi;
        
        vertices.push(px, py, pz);
        normals.push(sinTheta * cosPhi, cosTheta, sinTheta * sinPhi);
        uvs.push(u, 1 - v);
        
        // Determine which tile this vertex belongs to
        const lon = (u * 360) - 180;
        const lat = 90 - (v * 180);
        const tileIndex = this.findTileForLatLon(lat, lon, tiles);
        tileIndices.push(tileIndex);
      }
    }
    
    // Generate indices
    for (let y = 0; y < heightSegments; y++) {
      for (let x = 0; x < widthSegments; x++) {
        const a = (widthSegments + 1) * y + x;
        const b = (widthSegments + 1) * (y + 1) + x;
        const c = (widthSegments + 1) * (y + 1) + (x + 1);
        const d = (widthSegments + 1) * y + (x + 1);
        
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
  
  // Find which tile a lat/lon coordinate belongs to
  private static findTileForLatLon(
    lat: number, 
    lon: number, 
    tiles: Array<{ x: number; y: number; z: number }>
  ): number {
    for (let i = 0; i < tiles.length; i++) {
      const tile = tiles[i];
      const bounds = this.tileToBounds(tile.x, tile.y, tile.z);
      
      if (lat >= bounds.lat2 && lat <= bounds.lat1 && 
          lon >= bounds.lng1 && lon <= bounds.lng2) {
        return i;
      }
    }
    return -1; // Not found
  }
  
  // Get bounds of a tile
  private static tileToBounds(x: number, y: number, z: number) {
    const n = Math.pow(2, z);
    const lng1 = x / n * 360 - 180;
    const lat1 = Math.atan(Math.sinh(Math.PI * (1 - 2 * y / n))) * 180 / Math.PI;
    const lng2 = (x + 1) / n * 360 - 180;
    const lat2 = Math.atan(Math.sinh(Math.PI * (1 - 2 * (y + 1) / n))) * 180 / Math.PI;
    return { lat1, lng1, lat2, lng2 };
  }
  
  // Create texture atlas from tiles
  static createTextureAtlas(tiles: HTMLImageElement[], tileSize: number = 512): THREE.Texture {
    const atlasSize = Math.ceil(Math.sqrt(tiles.length)) * tileSize;
    const canvas = document.createElement('canvas');
    canvas.width = atlasSize;
    canvas.height = atlasSize;
    const ctx = canvas.getContext('2d')!;
    
    tiles.forEach((tile, index) => {
      const x = (index % Math.ceil(Math.sqrt(tiles.length))) * tileSize;
      const y = Math.floor(index / Math.ceil(Math.sqrt(tiles.length))) * tileSize;
      ctx.drawImage(tile, x, y, tileSize, tileSize);
    });
    
    const texture = new THREE.CanvasTexture(canvas);
    texture.needsUpdate = true;
    texture.minFilter = THREE.LinearMipmapLinearFilter;
    texture.magFilter = THREE.LinearFilter;
    
    return texture;
  }
  
  // Handle pole distortion with special mapping
  static applyPoleCorrection(geometry: THREE.BufferGeometry, poleThreshold: number = 85) {
    const positions = geometry.getAttribute('position');
    const uvs = geometry.getAttribute('uv');
    
    for (let i = 0; i < positions.count; i++) {
      const y = positions.getY(i);
      const radius = Math.sqrt(
        positions.getX(i) ** 2 + 
        positions.getY(i) ** 2 + 
        positions.getZ(i) ** 2
      );
      
      // Calculate latitude
      const lat = Math.asin(y / radius) * 180 / Math.PI;
      
      // Apply correction near poles
      if (Math.abs(lat) > poleThreshold) {
        const polarFactor = (Math.abs(lat) - poleThreshold) / (90 - poleThreshold);
        // Blend to solid color at poles
        uvs.setX(i, 0.5); // Center of texture
        uvs.setY(i, lat > 0 ? 0 : 1); // Top or bottom
      }
    }
    
    uvs.needsUpdate = true;
  }
}