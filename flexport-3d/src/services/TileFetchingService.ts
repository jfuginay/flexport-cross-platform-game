interface TileCoordinate {
  x: number;
  y: number;
  z: number; // zoom level
}

interface TileCache {
  [key: string]: HTMLImageElement | Promise<HTMLImageElement>;
}

export class TileFetchingService {
  private mapTilerKey: string;
  private mapboxToken: string;
  private tileCache: TileCache = {};
  private dbName = 'FlexPortTileCache';
  private db?: IDBDatabase;
  
  constructor() {
    this.mapTilerKey = process.env.REACT_APP_MAPTILER_KEY || '';
    this.mapboxToken = process.env.REACT_APP_MAPBOX_TOKEN || '';
    this.initIndexedDB();
  }
  
  private async initIndexedDB() {
    const request = indexedDB.open(this.dbName, 1);
    
    request.onupgradeneeded = (event) => {
      const db = (event.target as IDBOpenDBRequest).result;
      if (!db.objectStoreNames.contains('tiles')) {
        db.createObjectStore('tiles', { keyPath: 'id' });
      }
    };
    
    request.onsuccess = (event) => {
      this.db = (event.target as IDBOpenDBRequest).result;
    };
  }
  
  // Convert lat/lng to tile coordinates
  private latLngToTile(lat: number, lng: number, zoom: number): TileCoordinate {
    const x = Math.floor((lng + 180) / 360 * Math.pow(2, zoom));
    const y = Math.floor((1 - Math.log(Math.tan(lat * Math.PI / 180) + 1 / Math.cos(lat * Math.PI / 180)) / Math.PI) / 2 * Math.pow(2, zoom));
    return { x, y, z: zoom };
  }
  
  // Get bounds of a tile in lat/lng
  private tileToBounds(x: number, y: number, z: number) {
    const n = Math.pow(2, z);
    const lng1 = x / n * 360 - 180;
    const lat1 = Math.atan(Math.sinh(Math.PI * (1 - 2 * y / n))) * 180 / Math.PI;
    const lng2 = (x + 1) / n * 360 - 180;
    const lat2 = Math.atan(Math.sinh(Math.PI * (1 - 2 * (y + 1) / n))) * 180 / Math.PI;
    return { lat1, lng1, lat2, lng2 };
  }
  
  // Fetch tile from MapTiler
  async fetchMapTilerTile(x: number, y: number, z: number, style: string = 'satellite-v2'): Promise<HTMLImageElement> {
    const cacheKey = `maptiler-${style}-${z}-${x}-${y}`;
    
    if (this.tileCache[cacheKey]) {
      return this.tileCache[cacheKey] as HTMLImageElement;
    }
    
    // Use OpenStreetMap tiles as a fallback/test (no API key required)
    // const url = `https://tile.openstreetmap.org/${z}/${x}/${y}.png`;
    
    // Use MapTiler with API key
    const url = this.mapTilerKey 
      ? `https://api.maptiler.com/tiles/${style}/${z}/${x}/${y}.png?key=${this.mapTilerKey}`
      : `https://tile.openstreetmap.org/${z}/${x}/${y}.png`; // Fallback to OSM
    
    const promise = this.loadImage(url, cacheKey);
    this.tileCache[cacheKey] = promise;
    
    return promise;
  }
  
  // Fetch tile from Mapbox
  async fetchMapboxTile(x: number, y: number, z: number, style: string = 'satellite-v9'): Promise<HTMLImageElement> {
    const cacheKey = `mapbox-${style}-${z}-${x}-${y}`;
    
    if (this.tileCache[cacheKey]) {
      return this.tileCache[cacheKey] as HTMLImageElement;
    }
    
    const url = `https://api.mapbox.com/v4/mapbox.${style}/${z}/${x}/${y}@2x.jpg?access_token=${this.mapboxToken}`;
    
    const promise = this.loadImage(url, cacheKey);
    this.tileCache[cacheKey] = promise;
    
    return promise;
  }
  
  // Load image with caching
  private async loadImage(url: string, cacheKey: string): Promise<HTMLImageElement> {
    // Try IndexedDB first
    if (this.db) {
      try {
        const transaction = this.db.transaction(['tiles'], 'readonly');
        const store = transaction.objectStore('tiles');
        const request = store.get(cacheKey);
        
        const cachedData = await new Promise<any>((resolve) => {
          request.onsuccess = () => resolve(request.result);
        });
        
        if (cachedData) {
          const img = new Image();
          img.src = cachedData.dataUrl;
          return new Promise((resolve) => {
            img.onload = () => resolve(img);
          });
        }
      } catch (error) {
        console.warn('IndexedDB read error:', error);
      }
    }
    
    // Fetch from network
    return new Promise((resolve, reject) => {
      const img = new Image();
      img.crossOrigin = 'anonymous';
      // Add attributes to help with loading
      img.decoding = 'async';
      img.loading = 'eager';
      
      img.onload = async () => {
        // Cache to IndexedDB
        if (this.db) {
          try {
            const canvas = document.createElement('canvas');
            canvas.width = img.width;
            canvas.height = img.height;
            const ctx = canvas.getContext('2d')!;
            ctx.drawImage(img, 0, 0);
            
            const dataUrl = canvas.toDataURL('image/jpeg', 0.9);
            
            const transaction = this.db.transaction(['tiles'], 'readwrite');
            const store = transaction.objectStore('tiles');
            store.put({ id: cacheKey, dataUrl, timestamp: Date.now() });
          } catch (error) {
            console.warn('IndexedDB write error:', error);
          }
        }
        
        resolve(img);
      };
      
      img.onerror = (e) => {
        console.error(`Failed to load tile from URL: ${url}`, e);
        reject(new Error(`Failed to load tile: ${url}`));
      };
      img.src = url;
      console.log(`Attempting to load tile from: ${url}`);
    });
  }
  
  // Get tiles needed for viewport
  getTilesForViewport(
    centerLat: number,
    centerLng: number,
    zoom: number,
    viewportWidth: number,
    viewportHeight: number
  ): TileCoordinate[] {
    const centerTile = this.latLngToTile(centerLat, centerLng, zoom);
    const tiles: TileCoordinate[] = [];
    
    // Calculate how many tiles we need in each direction
    const tilesX = Math.ceil(viewportWidth / 512) + 2;
    const tilesY = Math.ceil(viewportHeight / 512) + 2;
    
    for (let dx = -Math.floor(tilesX / 2); dx <= Math.floor(tilesX / 2); dx++) {
      for (let dy = -Math.floor(tilesY / 2); dy <= Math.floor(tilesY / 2); dy++) {
        tiles.push({
          x: centerTile.x + dx,
          y: centerTile.y + dy,
          z: zoom
        });
      }
    }
    
    return tiles;
  }
  
  // Clear old cache entries
  async clearOldCache(maxAge: number = 7 * 24 * 60 * 60 * 1000) {
    if (!this.db) return;
    
    const transaction = this.db.transaction(['tiles'], 'readwrite');
    const store = transaction.objectStore('tiles');
    const request = store.openCursor();
    
    request.onsuccess = (event) => {
      const cursor = (event.target as IDBRequest).result;
      if (cursor) {
        if (Date.now() - cursor.value.timestamp > maxAge) {
          cursor.delete();
        }
        cursor.continue();
      }
    };
  }
}