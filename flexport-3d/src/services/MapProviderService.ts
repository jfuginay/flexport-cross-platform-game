import { TileFetchingService } from './TileFetchingService';

export interface MapProvider {
  name: string;
  priority: number;
  zoomRange: { min: number; max: number };
  rateLimit: { requests: number; windowMs: number };
  styles: string[];
}

export interface TileRequest {
  x: number;
  y: number;
  z: number;
  provider?: string;
  style?: string;
}

export class MapProviderService {
  private tileFetchingService: TileFetchingService;
  private providers: Map<string, MapProvider>;
  private requestCounts: Map<string, { count: number; resetTime: number }>;
  private tileQuality: Map<string, number>; // Track quality scores for different areas
  
  constructor() {
    this.tileFetchingService = new TileFetchingService();
    this.providers = new Map();
    this.requestCounts = new Map();
    this.tileQuality = new Map();
    
    this.initializeProviders();
  }
  
  private initializeProviders() {
    // MapTiler configuration
    this.providers.set('maptiler', {
      name: 'MapTiler',
      priority: 1,
      zoomRange: { min: 0, max: 20 },
      rateLimit: { requests: 100000, windowMs: 24 * 60 * 60 * 1000 }, // Daily limit
      styles: ['satellite-v2', 'hybrid', 'streets-v2']
    });
    
    // Mapbox configuration
    this.providers.set('mapbox', {
      name: 'Mapbox',
      priority: 2,
      zoomRange: { min: 0, max: 22 },
      rateLimit: { requests: 50000, windowMs: 30 * 24 * 60 * 60 * 1000 }, // Monthly limit
      styles: ['satellite-v9', 'satellite-streets-v12', 'outdoors-v12']
    });
  }
  
  // Intelligent provider selection based on zoom level and location
  private selectProvider(tile: TileRequest): { provider: string; style: string } {
    const { z } = tile;
    
    // For high zoom levels, prefer Mapbox for better detail
    if (z >= 16) {
      if (this.canMakeRequest('mapbox')) {
        return { provider: 'mapbox', style: 'satellite-v9' };
      }
    }
    
    // For medium zoom levels, use quality scores if available
    const tileKey = `${z}-${tile.x}-${tile.y}`;
    const mapTilerQuality = this.tileQuality.get(`maptiler-${tileKey}`) || 1;
    const mapboxQuality = this.tileQuality.get(`mapbox-${tileKey}`) || 1;
    
    // Select based on quality and availability
    if (mapTilerQuality >= mapboxQuality && this.canMakeRequest('maptiler')) {
      return { provider: 'maptiler', style: 'satellite-v2' };
    } else if (this.canMakeRequest('mapbox')) {
      return { provider: 'mapbox', style: 'satellite-v9' };
    }
    
    // Fallback to any available provider
    return { provider: 'maptiler', style: 'satellite-v2' };
  }
  
  // Check if we can make a request to a provider
  private canMakeRequest(providerName: string): boolean {
    const provider = this.providers.get(providerName);
    if (!provider) return false;
    
    const requestData = this.requestCounts.get(providerName);
    const now = Date.now();
    
    if (!requestData || now > requestData.resetTime) {
      // Reset counter
      this.requestCounts.set(providerName, {
        count: 0,
        resetTime: now + provider.rateLimit.windowMs
      });
      return true;
    }
    
    return requestData.count < provider.rateLimit.requests;
  }
  
  // Track request for rate limiting
  private trackRequest(providerName: string) {
    const requestData = this.requestCounts.get(providerName);
    if (requestData) {
      requestData.count++;
    }
  }
  
  // Fetch tile with intelligent provider selection
  async fetchTile(tile: TileRequest): Promise<HTMLImageElement> {
    const { provider, style } = tile.provider 
      ? { provider: tile.provider, style: tile.style || 'satellite-v2' }
      : this.selectProvider(tile);
    
    this.trackRequest(provider);
    
    try {
      let img: HTMLImageElement;
      
      if (provider === 'maptiler') {
        img = await this.tileFetchingService.fetchMapTilerTile(
          tile.x, 
          tile.y, 
          tile.z, 
          style
        );
      } else {
        img = await this.tileFetchingService.fetchMapboxTile(
          tile.x, 
          tile.y, 
          tile.z, 
          style
        );
      }
      
      // Analyze tile quality (simple heuristic based on image size/content)
      this.analyzeTileQuality(img, provider, tile);
      
      return img;
    } catch (error) {
      console.error(`Failed to fetch tile from ${provider}:`, error);
      
      // Try fallback provider
      const fallbackProvider = provider === 'maptiler' ? 'mapbox' : 'maptiler';
      if (this.canMakeRequest(fallbackProvider)) {
        this.trackRequest(fallbackProvider);
        
        if (fallbackProvider === 'maptiler') {
          return this.tileFetchingService.fetchMapTilerTile(tile.x, tile.y, tile.z);
        } else {
          return this.tileFetchingService.fetchMapboxTile(tile.x, tile.y, tile.z);
        }
      }
      
      throw error;
    }
  }
  
  // Batch fetch tiles with optimized provider distribution
  async fetchTileBatch(tiles: TileRequest[]): Promise<Map<string, HTMLImageElement>> {
    const results = new Map<string, HTMLImageElement>();
    
    // Group tiles by zoom level for better provider selection
    const tilesByZoom = new Map<number, TileRequest[]>();
    tiles.forEach(tile => {
      const zoom = tile.z;
      if (!tilesByZoom.has(zoom)) {
        tilesByZoom.set(zoom, []);
      }
      tilesByZoom.get(zoom)!.push(tile);
    });
    
    // Process each zoom level
    const promises: Promise<void>[] = [];
    
    tilesByZoom.forEach((tilesAtZoom, zoom) => {
      // Distribute tiles between providers based on rate limits
      const mapTilerAvailable = this.getRemainingRequests('maptiler');
      const mapboxAvailable = this.getRemainingRequests('mapbox');
      const total = mapTilerAvailable + mapboxAvailable;
      
      if (total === 0) {
        console.warn('Rate limits reached for all providers');
        return;
      }
      
      const mapTilerRatio = mapTilerAvailable / total;
      const mapTilerCount = Math.floor(tilesAtZoom.length * mapTilerRatio);
      
      // Split tiles between providers
      tilesAtZoom.forEach((tile, index) => {
        const useMapTiler = index < mapTilerCount;
        const provider = useMapTiler ? 'maptiler' : 'mapbox';
        
        const promise = this.fetchTile({ ...tile, provider })
          .then(img => {
            const key = `${tile.z}-${tile.x}-${tile.y}`;
            results.set(key, img);
          })
          .catch(error => {
            console.error(`Failed to fetch tile ${tile.z}-${tile.x}-${tile.y}:`, error);
          });
        
        promises.push(promise);
      });
    });
    
    await Promise.all(promises);
    return results;
  }
  
  // Get remaining requests for a provider
  private getRemainingRequests(providerName: string): number {
    const provider = this.providers.get(providerName);
    if (!provider) return 0;
    
    const requestData = this.requestCounts.get(providerName);
    if (!requestData || Date.now() > requestData.resetTime) {
      return provider.rateLimit.requests;
    }
    
    return Math.max(0, provider.rateLimit.requests - requestData.count);
  }
  
  // Simple quality analysis based on image characteristics
  private analyzeTileQuality(img: HTMLImageElement, provider: string, tile: TileRequest) {
    // Create canvas to analyze image
    const canvas = document.createElement('canvas');
    canvas.width = 32; // Sample size
    canvas.height = 32;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    
    ctx.drawImage(img, 0, 0, 32, 32);
    const imageData = ctx.getImageData(0, 0, 32, 32);
    const data = imageData.data;
    
    // Calculate variance as a simple quality metric
    let sum = 0;
    let sumSq = 0;
    const pixels = data.length / 4;
    
    for (let i = 0; i < data.length; i += 4) {
      const gray = (data[i] + data[i + 1] + data[i + 2]) / 3;
      sum += gray;
      sumSq += gray * gray;
    }
    
    const mean = sum / pixels;
    const variance = (sumSq / pixels) - (mean * mean);
    
    // Higher variance generally means more detail
    const quality = Math.min(1, variance / 1000);
    const tileKey = `${tile.z}-${tile.x}-${tile.y}`;
    this.tileQuality.set(`${provider}-${tileKey}`, quality);
  }
  
  // Get vector tiles for hybrid overlays
  async fetchVectorTile(tile: TileRequest): Promise<any> {
    // This would fetch vector tiles for roads, labels, etc.
    // Implementation depends on the specific vector tile format (MVT, etc.)
    const provider = tile.z >= 14 ? 'mapbox' : 'maptiler';
    const style = provider === 'mapbox' ? 'streets-v12' : 'streets-v2';
    
    // For now, return a placeholder
    return {
      provider,
      style,
      tile,
      features: []
    };
  }
  
  // Preload tiles for smooth navigation
  async preloadTilesForArea(
    centerLat: number,
    centerLng: number,
    zoom: number,
    radius: number = 2
  ) {
    const tiles: TileRequest[] = [];
    const centerTileX = Math.floor((centerLng + 180) / 360 * Math.pow(2, zoom));
    const centerTileY = Math.floor(
      (1 - Math.log(Math.tan(centerLat * Math.PI / 180) + 
      1 / Math.cos(centerLat * Math.PI / 180)) / Math.PI) / 2 * Math.pow(2, zoom)
    );
    
    // Preload surrounding tiles
    for (let dx = -radius; dx <= radius; dx++) {
      for (let dy = -radius; dy <= radius; dy++) {
        tiles.push({
          x: centerTileX + dx,
          y: centerTileY + dy,
          z: zoom
        });
      }
    }
    
    return this.fetchTileBatch(tiles);
  }
  
  // Clear old quality scores
  clearQualityCache() {
    this.tileQuality.clear();
  }
  
  // Get provider statistics
  getProviderStats() {
    const stats: any = {};
    
    this.providers.forEach((provider, name) => {
      const remaining = this.getRemainingRequests(name);
      const requestData = this.requestCounts.get(name);
      
      stats[name] = {
        remaining,
        used: requestData ? requestData.count : 0,
        limit: provider.rateLimit.requests,
        resetTime: requestData ? new Date(requestData.resetTime) : null
      };
    });
    
    return stats;
  }
}