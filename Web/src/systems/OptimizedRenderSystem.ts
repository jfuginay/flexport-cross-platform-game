import * as PIXI from 'pixi.js';
import { GameState, Ship, Port } from '@/types';
import { getPerformanceMonitor, ObjectPool, SpatialIndex } from '@/utils/Performance';

interface RenderableShip extends Ship {
  sprite?: PIXI.Sprite;
  lastUpdateTime?: number;
  isVisible?: boolean;
  lodLevel?: 'high' | 'medium' | 'low';
}

export class OptimizedRenderSystem {
  private app: PIXI.Application;
  private gameState: GameState;
  private performanceMonitor = getPerformanceMonitor();
  
  // Containers
  private mainContainer: PIXI.Container;
  private shipContainer: PIXI.Container;
  private effectsContainer: PIXI.Container;
  private uiContainer: PIXI.Container;
  
  // Object pools
  private spritePool: ObjectPool<PIXI.Sprite>;
  private particlePool: ObjectPool<PIXI.Sprite>;
  private graphicsPool: ObjectPool<PIXI.Graphics>;
  
  // Spatial indexing for culling
  private shipSpatialIndex: SpatialIndex<RenderableShip>;
  private portSpatialIndex: SpatialIndex<Port>;
  
  // Performance optimizations
  private frameSkipCounter = 0;
  private readonly MAX_FRAME_SKIP = 2;
  private visibleShips: Set<string> = new Set();
  private renderBounds: PIXI.Rectangle;
  private cullingEnabled = true;
  private lodEnabled = true;
  private batchingEnabled = true;
  
  // Frame budget management
  private frameBudget = 16.67; // Target 60 FPS
  private frameStartTime = 0;
  private renderPhases = {
    culling: 2, // 2ms budget
    ships: 8, // 8ms budget
    effects: 3, // 3ms budget
    ui: 3 // 3ms budget
  };
  
  // Render optimization flags
  private skipNonEssentialEffects = false;
  private reduceParticleCount = false;
  private useSimplifiedShaders = false;
  private dynamicResolution = 1.0;
  
  // Texture caching
  private textureCache: Map<string, PIXI.Texture> = new Map();
  private atlasTexture: PIXI.BaseTexture | null = null;
  
  // Quality settings cache
  private qualitySettings = this.performanceMonitor.getQualitySettings();
  
  // Ship rendering
  private shipSprites: Map<string, PIXI.Sprite> = new Map();
  private shipBatch: PIXI.ParticleContainer;
  private tradeRouteGraphics: PIXI.Graphics;
  
  // Wake effects with pooling
  private wakeParticles: Map<string, PIXI.Container> = new Map();
  private activeParticles = 0;
  
  constructor(app: PIXI.Application, gameState: GameState) {
    this.app = app;
    this.gameState = gameState;
    this.mainContainer = new PIXI.Container();
    this.shipContainer = new PIXI.Container();
    this.effectsContainer = new PIXI.Container();
    this.uiContainer = new PIXI.Container();
    this.renderBounds = new PIXI.Rectangle(0, 0, app.screen.width, app.screen.height);
    
    // Initialize object pools
    this.spritePool = new ObjectPool(
      () => new PIXI.Sprite(),
      (sprite) => {
        sprite.visible = false;
        sprite.alpha = 1;
        sprite.scale.set(1);
        sprite.rotation = 0;
        sprite.tint = 0xffffff;
      },
      50,
      200
    );
    
    this.particlePool = new ObjectPool(
      () => new PIXI.Sprite(),
      (sprite) => {
        sprite.visible = false;
        sprite.alpha = 1;
        sprite.scale.set(1);
      },
      100,
      500
    );
    
    this.graphicsPool = new ObjectPool(
      () => new PIXI.Graphics(),
      (graphics) => graphics.clear(),
      10,
      50
    );
    
    // Initialize spatial indices
    this.shipSpatialIndex = new SpatialIndex(200);
    this.portSpatialIndex = new SpatialIndex(500);
    
    // Initialize particle container for ships (much faster for many sprites)
    this.shipBatch = new PIXI.ParticleContainer(
      this.qualitySettings.maxVisibleShips,
      {
        scale: true,
        position: true,
        rotation: true,
        tint: true,
        alpha: true
      }
    );
    
    this.tradeRouteGraphics = new PIXI.Graphics();
    
    this.initialize();
  }
  
  private initialize(): void {
    // Setup render hierarchy
    this.mainContainer.sortableChildren = true;
    
    this.tradeRouteGraphics.zIndex = 1;
    this.shipBatch.zIndex = 2;
    this.shipContainer.zIndex = 3;
    this.effectsContainer.zIndex = 4;
    this.uiContainer.zIndex = 5;
    
    this.mainContainer.addChild(this.tradeRouteGraphics);
    this.mainContainer.addChild(this.shipBatch);
    this.mainContainer.addChild(this.shipContainer);
    this.mainContainer.addChild(this.effectsContainer);
    this.mainContainer.addChild(this.uiContainer);
    
    this.app.stage.addChild(this.mainContainer);
    
    // Setup texture atlas for better performance
    this.setupTextureAtlas();
    
    // Listen for quality changes
    this.performanceMonitor.onMetricsUpdate(() => {
      this.qualitySettings = this.performanceMonitor.getQualitySettings();
      this.updateQualitySettings();
    });
    
    // Index all ports
    this.gameState.world.ports.forEach(port => {
      this.portSpatialIndex.add({
        ...port,
        x: port.coordinates.longitude,
        y: port.coordinates.latitude
      });
    });
  }
  
  private setupTextureAtlas(): void {
    // Create fallback textures for missing assets
    this.createFallbackTextures();
  }
  
  private createFallbackTextures(): void {
    // Create ship texture
    const shipGraphics = new PIXI.Graphics();
    shipGraphics.beginPath();
    shipGraphics.moveTo(0, -10);
    shipGraphics.lineTo(-5, 10);
    shipGraphics.lineTo(5, 10);
    shipGraphics.closePath();
    shipGraphics.fill({color: 0x4a90e2});
    const shipTexture = this.app.renderer.generateTexture(shipGraphics);
    this.textureCache.set('ship', shipTexture);
    
    // Create port texture
    const portGraphics = new PIXI.Graphics();
    portGraphics.circle(0, 0, 10);
    portGraphics.fill({color: 0xff6b6b});
    const portTexture = this.app.renderer.generateTexture(portGraphics);
    this.textureCache.set('port', portTexture);
    
    // Create wave texture
    const waveGraphics = new PIXI.Graphics();
    waveGraphics.circle(0, 0, 20);
    waveGraphics.fill({color: 0x7fcdff, alpha: 0.3});
    const waveTexture = this.app.renderer.generateTexture(waveGraphics);
    this.textureCache.set('wave', waveTexture);
    
    // Clean up graphics objects
    shipGraphics.destroy();
    portGraphics.destroy();
    waveGraphics.destroy();
  }
  
  public render(): void {
    this.frameStartTime = performance.now();
    
    // Adaptive quality based on previous frame performance
    this.updateDynamicQuality();
    
    // Frame skipping for low performance
    if (this.performanceMonitor.isLowPerformance() && this.shouldSkipFrame()) {
      this.frameSkipCounter++;
      return;
    }
    
    this.frameSkipCounter = 0;
    
    this.performanceMonitor.measureRender(() => {
      // Phase 1: Culling (2ms budget)
      const cullingStart = performance.now();
      this.updateRenderBounds();
      this.cullInvisibleObjects();
      const cullingTime = performance.now() - cullingStart;
      
      // Phase 2: Ships (8ms budget)
      const shipsStart = performance.now();
      if (cullingTime < this.renderPhases.culling) {
        this.renderShips();
      }
      const shipsTime = performance.now() - shipsStart;
      
      // Phase 3: Trade routes (included in ships budget)
      if (shipsTime < this.renderPhases.ships && !this.skipNonEssentialEffects) {
        this.renderTradeRoutes();
      }
      
      // Phase 4: Effects (3ms budget)
      const effectsStart = performance.now();
      const totalElapsed = effectsStart - this.frameStartTime;
      if (totalElapsed < 13 && !this.skipNonEssentialEffects) { // Leave 3ms for UI
        this.renderEffects();
      }
      
      // Always update metrics
      this.updatePerformanceMetrics();
    });
  }
  
  private shouldSkipFrame(): boolean {
    // More intelligent frame skipping based on render complexity
    const shipCount = this.visibleShips.size;
    const particleCount = this.activeParticles;
    
    if (shipCount > 50 || particleCount > 100) {
      return this.frameSkipCounter < this.MAX_FRAME_SKIP;
    }
    
    return this.frameSkipCounter < 1; // Skip fewer frames for simpler scenes
  }
  
  private updateDynamicQuality(): void {
    const avgFrameTime = this.performanceMonitor.getAverageFrameTime();
    
    if (avgFrameTime > 20) { // Below 50 FPS
      this.skipNonEssentialEffects = true;
      this.reduceParticleCount = true;
      this.dynamicResolution = Math.max(0.5, this.dynamicResolution - 0.1);
    } else if (avgFrameTime > 16.67) { // Below 60 FPS
      this.reduceParticleCount = true;
      this.dynamicResolution = Math.max(0.75, this.dynamicResolution - 0.05);
    } else if (avgFrameTime < 14) { // Above 70 FPS - can increase quality
      this.skipNonEssentialEffects = false;
      this.reduceParticleCount = false;
      this.dynamicResolution = Math.min(1.0, this.dynamicResolution + 0.05);
    }
    
    // Apply dynamic resolution
    if (Math.abs(this.app.renderer.resolution - this.dynamicResolution) > 0.05) {
      this.app.renderer.resolution = this.dynamicResolution;
      this.app.renderer.resize(this.app.screen.width, this.app.screen.height);
    }
  }
  
  private updateRenderBounds(): void {
    // Update visible bounds for culling
    const margin = 100; // Extra margin for smooth scrolling
    this.renderBounds.x = -margin;
    this.renderBounds.y = -margin;
    this.renderBounds.width = this.app.screen.width + margin * 2;
    this.renderBounds.height = this.app.screen.height + margin * 2;
  }
  
  private cullInvisibleObjects(): void {
    if (!this.cullingEnabled) return;
    
    // Clear visible ships set
    this.visibleShips.clear();
    
    // Get camera bounds in world coordinates
    const cameraBounds = this.getCameraBounds();
    
    // Query spatial index for visible ships
    const visibleShipData = this.shipSpatialIndex.getNearby(
      cameraBounds.centerX,
      cameraBounds.centerY,
      cameraBounds.radius
    );
    
    visibleShipData.forEach(ship => {
      this.visibleShips.add(ship.id);
    });
  }
  
  private getCameraBounds(): { centerX: number; centerY: number; radius: number } {
    // Convert screen bounds to world coordinates
    const center = this.screenToWorld({
      x: this.app.screen.width / 2,
      y: this.app.screen.height / 2
    });
    
    const corner = this.screenToWorld({
      x: this.app.screen.width,
      y: this.app.screen.height
    });
    
    const radius = Math.sqrt(
      Math.pow(corner.longitude - center.longitude, 2) +
      Math.pow(corner.latitude - center.latitude, 2)
    );
    
    return {
      centerX: center.longitude,
      centerY: center.latitude,
      radius
    };
  }
  
  private renderShips(): void {
    const ships = this.getAllShips();
    let renderedCount = 0;
    
    ships.forEach(ship => {
      // Skip if culled
      if (this.cullingEnabled && !this.visibleShips.has(ship.id)) {
        this.hideShip(ship.id);
        return;
      }
      
      // Apply max visible ships limit
      if (renderedCount >= this.qualitySettings.maxVisibleShips) {
        this.hideShip(ship.id);
        return;
      }
      
      this.updateShipSprite(ship as RenderableShip);
      renderedCount++;
    });
    
    // Update spatial index
    this.updateSpatialIndex();
    
    // Clean up unused sprites
    this.cleanupUnusedSprites(ships);
  }
  
  private updateShipSprite(ship: RenderableShip): void {
    let sprite = this.shipSprites.get(ship.id);
    
    if (!sprite) {
      sprite = this.createShipSprite(ship);
      this.shipSprites.set(ship.id, sprite);
      
      // Use batch container for better performance
      if (this.batchingEnabled && this.shipBatch.children.length < this.qualitySettings.maxVisibleShips) {
        this.shipBatch.addChild(sprite);
      } else {
        this.shipContainer.addChild(sprite);
      }
    }
    
    // Update position with interpolation
    const screenPos = this.worldToScreen(ship.currentLocation);
    sprite.x = screenPos.x;
    sprite.y = screenPos.y;
    
    // Apply LOD
    if (this.lodEnabled) {
      this.applyLOD(ship, sprite);
    }
    
    // Update rotation if moving
    if (ship.status === 'traveling' && ship.destination) {
      this.updateShipRotation(sprite, ship);
    }
    
    // Update appearance
    this.updateShipAppearance(sprite, ship);
    
    // Update wake effect based on quality
    if (this.qualitySettings.particlesEnabled && ship.status === 'traveling') {
      this.updateWakeEffect(ship);
    }
    
    sprite.visible = true;
  }
  
  private createShipSprite(ship: RenderableShip): PIXI.Sprite {
    const sprite = this.spritePool.get();
    
    // Use cached texture or create fallback
    const texture = this.textureCache.get('ship') || this.createFallbackShipTexture(ship.type);
    sprite.texture = texture;
    sprite.anchor.set(0.5);
    sprite.scale.set(this.getShipScale(ship.type));
    
    // Enable interaction only for high quality
    if (this.qualitySettings.qualityLevel === 'high' || this.qualitySettings.qualityLevel === 'ultra') {
      sprite.eventMode = 'static';
      sprite.cursor = 'pointer';
    }
    
    return sprite;
  }
  
  private createFallbackShipTexture(shipType: string): PIXI.Texture {
    const graphics = this.graphicsPool.get();
    
    // Simple ship shape
    const color = this.getShipColor(shipType);
    graphics.beginFill(color);
    graphics.drawRect(-8, -3, 16, 6);
    graphics.endFill();
    
    const texture = this.app.renderer.generateTexture(graphics);
    this.graphicsPool.release(graphics);
    
    return texture;
  }
  
  private applyLOD(ship: RenderableShip, sprite: PIXI.Sprite): void {
    const distance = this.getDistanceFromCamera(ship);
    
    if (distance < 100) {
      ship.lodLevel = 'high';
      sprite.alpha = 1;
      sprite.visible = true;
    } else if (distance < 500) {
      ship.lodLevel = 'medium';
      sprite.alpha = 0.8;
      sprite.visible = true;
    } else if (distance < this.qualitySettings.renderDistance) {
      ship.lodLevel = 'low';
      sprite.alpha = 0.6;
      sprite.visible = true;
    } else {
      sprite.visible = false;
    }
  }
  
  private getDistanceFromCamera(ship: RenderableShip): number {
    const center = this.getCameraBounds();
    const dx = ship.currentLocation.longitude - center.centerX;
    const dy = ship.currentLocation.latitude - center.centerY;
    return Math.sqrt(dx * dx + dy * dy) * 100; // Scale to screen units
  }
  
  private updateWakeEffect(ship: RenderableShip): void {
    // Respect dynamic quality settings
    const maxParticles = this.reduceParticleCount ? 
      Math.floor(this.qualitySettings.particleCount * 0.3) : 
      this.qualitySettings.particleCount;
      
    if (this.activeParticles >= maxParticles) {
      return; // Particle limit reached
    }
    
    let wakeContainer = this.wakeParticles.get(ship.id);
    if (!wakeContainer) {
      wakeContainer = new PIXI.Container();
      this.wakeParticles.set(ship.id, wakeContainer);
      this.effectsContainer.addChild(wakeContainer);
    }
    
    const sprite = this.shipSprites.get(ship.id);
    if (!sprite || !sprite.visible) return;
    
    // Add particles based on LOD and performance
    let particleChance = ship.lodLevel === 'high' ? 0.3 : 
                        ship.lodLevel === 'medium' ? 0.1 : 0.05;
    
    // Reduce particle spawn rate if performance is low
    if (this.reduceParticleCount) {
      particleChance *= 0.3;
    }
    
    // Frame budget check - only spawn particles if we have time
    const frameElapsed = performance.now() - this.frameStartTime;
    if (frameElapsed > 14) { // Near frame budget
      particleChance = 0;
    }
    
    if (Math.random() < particleChance) {
      this.addWakeParticle(wakeContainer, sprite);
    }
    
    // Update existing particles
    this.updateWakeParticles(wakeContainer);
  }
  
  private addWakeParticle(container: PIXI.Container, shipSprite: PIXI.Sprite): void {
    const particle = this.particlePool.get();
    
    // Use cached wave texture or create simple particle
    const texture = this.textureCache.get('wave') || PIXI.Texture.WHITE;
    particle.texture = texture;
    
    particle.x = shipSprite.x - 15 + (Math.random() - 0.5) * 10;
    particle.y = shipSprite.y + (Math.random() - 0.5) * 10;
    particle.anchor.set(0.5);
    particle.scale.set(0.3 + Math.random() * 0.2);
    particle.alpha = 0.6;
    particle.tint = 0x5dade2;
    
    (particle as any).life = 1.0;
    (particle as any).fadeSpeed = 0.02 + Math.random() * 0.01;
    
    container.addChild(particle);
    this.activeParticles++;
  }
  
  private updateWakeParticles(container: PIXI.Container): void {
    for (let i = container.children.length - 1; i >= 0; i--) {
      const particle = container.children[i] as any;
      
      particle.life -= particle.fadeSpeed;
      particle.alpha = particle.life * 0.6;
      particle.scale.x = particle.scale.y = particle.life * 0.5 + 0.1;
      
      if (particle.life <= 0) {
        container.removeChild(particle);
        this.particlePool.release(particle);
        this.activeParticles--;
      }
    }
  }
  
  private renderTradeRoutes(): void {
    if (this.qualitySettings.qualityLevel === 'low') {
      return; // Skip trade routes on low quality
    }
    
    this.tradeRouteGraphics.clear();
    
    // Only render active trade routes
    const activeRoutes = this.gameState.player.tradeRoutes.filter(route => route.ships.length > 0);
    
    activeRoutes.forEach(route => {
      const originPort = this.getPortById(route.origin);
      const destinationPort = this.getPortById(route.destination);
      
      if (originPort && destinationPort) {
        this.drawOptimizedTradeRoute(originPort, destinationPort);
      }
    });
  }
  
  private drawOptimizedTradeRoute(origin: Port, destination: Port): void {
    const startPos = this.worldToScreen(origin.coordinates);
    const endPos = this.worldToScreen(destination.coordinates);
    
    // Skip if outside viewport
    if (!this.isLineInViewport(startPos, endPos)) {
      return;
    }
    
    const quality = this.qualitySettings.qualityLevel;
    const lineWidth = quality === 'ultra' ? 3 : quality === 'high' ? 2 : 1;
    const alpha = quality === 'low' ? 0.3 : quality === 'medium' ? 0.5 : 0.7;
    
    this.tradeRouteGraphics.setStrokeStyle({width: lineWidth, color: 0x10b981, alpha: alpha});
    this.tradeRouteGraphics.moveTo(startPos.x, startPos.y);
    
    // Use straight lines for low quality
    if (quality === 'low' || quality === 'medium') {
      this.tradeRouteGraphics.lineTo(endPos.x, endPos.y);
    } else {
      // Curved line for high quality
      const midX = (startPos.x + endPos.x) / 2;
      const midY = (startPos.y + endPos.y) / 2 - 30;
      this.tradeRouteGraphics.quadraticCurveTo(midX, midY, endPos.x, endPos.y);
    }
  }
  
  private isLineInViewport(start: {x: number, y: number}, end: {x: number, y: number}): boolean {
    // Simple AABB check
    const minX = Math.min(start.x, end.x);
    const maxX = Math.max(start.x, end.x);
    const minY = Math.min(start.y, end.y);
    const maxY = Math.max(start.y, end.y);
    
    return !(maxX < 0 || minX > this.app.screen.width ||
             maxY < 0 || minY > this.app.screen.height);
  }
  
  private renderEffects(): void {
    // Effects are handled per-ship in updateWakeEffect
    // Additional global effects can be added here
  }
  
  private updatePerformanceMetrics(): void {
    this.performanceMonitor.setSpriteCount(this.shipSprites.size);
    this.performanceMonitor.setParticleCount(this.activeParticles);
    
    // Approximate draw calls
    const drawCalls = 
      1 + // Background
      (this.tradeRouteGraphics.children.length > 0 ? 1 : 0) + // Trade routes
      (this.shipBatch.children.length > 0 ? 1 : 0) + // Ship batch
      Math.ceil(this.shipContainer.children.length / 10) + // Individual ships
      Math.ceil(this.effectsContainer.children.length / 20); // Effects
    
    this.performanceMonitor.setDrawCalls(drawCalls);
  }
  
  private updateQualitySettings(): void {
    // Adjust particle container size
    if (this.shipBatch.maxSize !== this.qualitySettings.maxVisibleShips) {
      // Recreate particle container with new size
      const newBatch = new PIXI.ParticleContainer(
        this.qualitySettings.maxVisibleShips,
        {
          scale: true,
          position: true,
          rotation: true,
          tint: true,
          alpha: true
        }
      );
      
      // Transfer children
      while (this.shipBatch.children.length > 0) {
        const child = this.shipBatch.children[0];
        this.shipBatch.removeChild(child);
        if (newBatch.children.length < this.qualitySettings.maxVisibleShips) {
          newBatch.addChild(child);
        } else {
          this.shipContainer.addChild(child);
        }
      }
      
      this.mainContainer.removeChild(this.shipBatch);
      this.shipBatch.destroy();
      this.shipBatch = newBatch;
      this.mainContainer.addChild(this.shipBatch);
    }
    
    // Update interaction based on quality
    this.shipSprites.forEach(sprite => {
      if (this.qualitySettings.qualityLevel === 'low' || this.qualitySettings.qualityLevel === 'medium') {
        sprite.eventMode = 'none';
      } else {
        sprite.eventMode = 'static';
      }
    });
  }
  
  // Helper methods
  private getAllShips(): Ship[] {
    const ships: Ship[] = [...this.gameState.player.ships];
    
    // AI competitors don't have ship arrays in current implementation
    // Only player ships are tracked as actual Ship objects
    
    return ships;
  }
  
  private hideShip(shipId: string): void {
    const sprite = this.shipSprites.get(shipId);
    if (sprite) {
      sprite.visible = false;
    }
    
    const wakeContainer = this.wakeParticles.get(shipId);
    if (wakeContainer) {
      wakeContainer.visible = false;
    }
  }
  
  private updateSpatialIndex(): void {
    // Clear and rebuild spatial index
    this.shipSpatialIndex.clear();
    
    this.getAllShips().forEach(ship => {
      this.shipSpatialIndex.add({
        ...ship,
        x: ship.currentLocation.longitude,
        y: ship.currentLocation.latitude
      } as RenderableShip);
    });
  }
  
  private cleanupUnusedSprites(activeShips: Ship[]): void {
    const activeShipIds = new Set(activeShips.map(s => s.id));
    
    this.shipSprites.forEach((sprite, shipId) => {
      if (!activeShipIds.has(shipId)) {
        // Remove and pool the sprite
        if (sprite.parent) {
          sprite.parent.removeChild(sprite);
        }
        this.spritePool.release(sprite);
        this.shipSprites.delete(shipId);
        
        // Clean up wake particles
        const wakeContainer = this.wakeParticles.get(shipId);
        if (wakeContainer) {
          // Release all particles
          for (let i = wakeContainer.children.length - 1; i >= 0; i--) {
            const particle = wakeContainer.children[i];
            this.particlePool.release(particle as PIXI.Sprite);
            this.activeParticles--;
          }
          
          this.effectsContainer.removeChild(wakeContainer);
          wakeContainer.destroy();
          this.wakeParticles.delete(shipId);
        }
      }
    });
  }
  
  private worldToScreen(coordinates: { latitude: number; longitude: number }): { x: number; y: number } {
    const mapBounds = {
      minLat: -60,
      maxLat: 80,
      minLng: -180,
      maxLng: 180,
    };
    
    const normalizedX = (coordinates.longitude - mapBounds.minLng) / 
                      (mapBounds.maxLng - mapBounds.minLng);
    const normalizedY = (coordinates.latitude - mapBounds.minLat) / 
                      (mapBounds.maxLat - mapBounds.minLat);
    
    return {
      x: normalizedX * this.app.screen.width,
      y: (1 - normalizedY) * this.app.screen.height,
    };
  }
  
  private screenToWorld(point: { x: number; y: number }): { latitude: number; longitude: number } {
    const mapBounds = {
      minLat: -60,
      maxLat: 80,
      minLng: -180,
      maxLng: 180,
    };
    
    const normalizedX = point.x / this.app.screen.width;
    const normalizedY = 1 - (point.y / this.app.screen.height);
    
    return {
      longitude: normalizedX * (mapBounds.maxLng - mapBounds.minLng) + mapBounds.minLng,
      latitude: normalizedY * (mapBounds.maxLat - mapBounds.minLat) + mapBounds.minLat
    };
  }
  
  private updateShipRotation(sprite: PIXI.Sprite, ship: Ship): void {
    if (!ship.destination || typeof ship.destination !== 'string') return;
    
    const destPort = this.getPortById(ship.destination);
    if (!destPort) return;
    
    const dx = destPort.coordinates.longitude - ship.currentLocation.longitude;
    const dy = destPort.coordinates.latitude - ship.currentLocation.latitude;
    const targetRotation = Math.atan2(dy, dx);
    
    // Smooth rotation
    let angleDiff = targetRotation - sprite.rotation;
    if (angleDiff > Math.PI) angleDiff -= 2 * Math.PI;
    if (angleDiff < -Math.PI) angleDiff += 2 * Math.PI;
    
    sprite.rotation += angleDiff * 0.1;
  }
  
  private updateShipAppearance(sprite: PIXI.Sprite, ship: Ship): void {
    const baseColor = this.getShipColor(ship.type);
    
    switch (ship.status) {
      case 'traveling':
        sprite.alpha = 1.0;
        sprite.tint = baseColor;
        break;
      case 'docked':
        sprite.alpha = 0.8;
        sprite.tint = 0xcccccc;
        break;
      case 'loading':
      case 'unloading':
        sprite.alpha = 0.9;
        sprite.tint = 0xffd700;
        break;
      default:
        sprite.alpha = 1.0;
        sprite.tint = baseColor;
    }
  }
  
  private getShipScale(shipType: string): number {
    const scales = {
      container_ship: 1.2,
      tanker: 1.1,
      bulk_carrier: 1.3,
      heavy_lift: 1.4,
      refrigerated: 1.0,
      roro: 1.1,
      general_cargo: 0.9,
    };
    return scales[shipType as keyof typeof scales] || 1.0;
  }
  
  private getShipColor(shipType: string): number {
    const colors = {
      container_ship: 0x3b82f6,
      tanker: 0xf59e0b,
      bulk_carrier: 0x8b5cf6,
      heavy_lift: 0xef4444,
      refrigerated: 0x06b6d4,
      roro: 0x10b981,
      general_cargo: 0x6b7280,
    };
    return colors[shipType as keyof typeof colors] || 0x6b7280;
  }
  
  private getPortById(portId: string): Port | undefined {
    return this.gameState.world.ports.find(port => port.id === portId);
  }
  
  public handleResize(width: number, height: number): void {
    this.renderBounds.width = width;
    this.renderBounds.height = height;
    
    // Update all ship positions
    this.shipSprites.forEach((sprite, shipId) => {
      const ship = this.getAllShips().find(s => s.id === shipId);
      if (ship) {
        const screenPos = this.worldToScreen(ship.currentLocation);
        sprite.x = screenPos.x;
        sprite.y = screenPos.y;
      }
    });
    
    // Redraw trade routes
    this.renderTradeRoutes();
  }
  
  public destroy(): void {
    // Release all pooled objects
    this.shipSprites.forEach(sprite => {
      this.spritePool.release(sprite);
    });
    this.shipSprites.clear();
    
    this.wakeParticles.forEach(container => {
      for (let i = container.children.length - 1; i >= 0; i--) {
        const particle = container.children[i];
        this.particlePool.release(particle as PIXI.Sprite);
      }
      container.destroy();
    });
    this.wakeParticles.clear();
    
    // Clear spatial indices
    this.shipSpatialIndex.clear();
    this.portSpatialIndex.clear();
    
    // Destroy containers
    this.mainContainer.destroy({ children: true });
    
    // Clear pools
    this.spritePool.clear();
    this.particlePool.clear();
    this.graphicsPool.clear();
    
    // Clear texture cache
    this.textureCache.clear();
  }
}