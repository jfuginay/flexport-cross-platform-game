import * as PIXI from 'pixi.js';
import { GameState, Ship, Port } from '@/types';

export class RenderSystem {
  private app: PIXI.Application;
  private gameState: GameState;
  private shipContainer: PIXI.Container = new PIXI.Container();
  private effectsContainer: PIXI.Container = new PIXI.Container();
  private shipSprites: Map<string, PIXI.Sprite> = new Map();
  private tradeRouteGraphics: PIXI.Graphics = new PIXI.Graphics();
  private wakeParticles: Map<string, PIXI.ParticleContainer> = new Map();
  private playerShips: Map<string, Ship[]> = new Map(); // playerId -> ships
  private playerColors: Map<string, number> = new Map(); // playerId -> color

  constructor(app: PIXI.Application, gameState: GameState) {
    this.app = app;
    this.gameState = gameState;
    this.initializeContainers();
  }

  private initializeContainers(): void {
    // Create ship container
    this.shipContainer = new PIXI.Container();
    this.shipContainer.zIndex = 3;
    this.app.stage.addChild(this.shipContainer);

    // Create effects container
    this.effectsContainer = new PIXI.Container();
    this.effectsContainer.zIndex = 4;
    this.app.stage.addChild(this.effectsContainer);

    // Create trade route graphics
    this.tradeRouteGraphics = new PIXI.Graphics();
    this.tradeRouteGraphics.zIndex = 1;
    this.app.stage.addChild(this.tradeRouteGraphics);
  }

  public render(): void {
    this.renderShips();
    this.renderTradeRoutes();
    this.renderEffects();
  }

  public updatePlayerShips(playerShips: Map<string, Ship[]>): void {
    this.playerShips = playerShips;
    this.assignPlayerColors();
  }

  private assignPlayerColors(): void {
    const colors = [0x3b82f6, 0xef4444, 0x10b981, 0xf59e0b, 0x8b5cf6, 0x06b6d4, 0xf97316, 0x84cc16];
    let colorIndex = 0;
    
    this.playerShips.forEach((ships, playerId) => {
      if (!this.playerColors.has(playerId)) {
        this.playerColors.set(playerId, colors[colorIndex % colors.length]);
        colorIndex++;
      }
    });
  }

  private renderShips(): void {
    // Collect all current ship IDs
    const currentShipIds = new Set<string>();
    
    // Render all players' ships
    this.playerShips.forEach((ships, playerId) => {
      ships.forEach(ship => {
        currentShipIds.add(ship.id);
        this.updateShipSprite(ship, playerId);
      });
    });

    // Also render local player ships if not in playerShips
    this.gameState.player.ships.forEach(ship => {
      if (!currentShipIds.has(ship.id)) {
        currentShipIds.add(ship.id);
        this.updateShipSprite(ship, this.gameState.player.id);
      }
    });

    // Remove sprites for ships that no longer exist
    this.shipSprites.forEach((sprite, shipId) => {
      if (!currentShipIds.has(shipId)) {
        this.shipContainer.removeChild(sprite);
        sprite.destroy();
        this.shipSprites.delete(shipId);
        
        // Clean up wake particles
        const wakeContainer = this.wakeParticles.get(shipId);
        if (wakeContainer) {
          this.effectsContainer.removeChild(wakeContainer);
          wakeContainer.destroy({ children: true });
          this.wakeParticles.delete(shipId);
        }
      }
    });
  }

  private updateShipSprite(ship: Ship, playerId?: string): void {
    let shipSprite = this.shipSprites.get(ship.id);

    if (!shipSprite) {
      shipSprite = this.createShipSprite(ship, playerId);
      this.shipSprites.set(ship.id, shipSprite);
      this.shipContainer.addChild(shipSprite);
      this.createWakeEffect(ship);
    }

    // Smooth movement animation
    const screenPos = this.worldToScreen(ship.currentLocation);
    this.animateShipMovement(shipSprite, screenPos, ship);

    // Update ship rotation based on movement direction
    this.updateShipRotation(shipSprite, ship);

    // Update appearance based on status
    this.updateShipAppearance(shipSprite, ship, playerId);
    
    // Update wake effects
    this.updateWakeEffect(ship);
  }

  private animateShipMovement(sprite: PIXI.Sprite, targetPos: {x: number, y: number}, ship: Ship): void {
    const currentX = sprite.x;
    const currentY = sprite.y;
    const speed = this.getShipSpeed(ship);
    
    // Smooth interpolation
    const lerpFactor = Math.min(speed * 0.016, 1); // 60fps target
    sprite.x = currentX + (targetPos.x - currentX) * lerpFactor;
    sprite.y = currentY + (targetPos.y - currentY) * lerpFactor;
    
    // Add subtle bob animation for realism
    const time = Date.now() * 0.001;
    sprite.y += Math.sin(time * 2 + ship.id.charCodeAt(0)) * 0.5;
  }

  private updateShipRotation(sprite: PIXI.Sprite, ship: Ship): void {
    if (ship.destination) {
      const currentPos = ship.currentLocation;
      const destPos = ship.destination;
      
      // Calculate angle to destination  
      const currentCoords = typeof currentPos === 'string' ? 
        this.gameState.world.ports.find(p => p.id === currentPos)?.coordinates : currentPos;
      const destCoords = typeof destPos === 'string' ? 
        this.gameState.world.ports.find(p => p.id === destPos)?.coordinates : destPos;
        
      if (!currentCoords || !destCoords) return;
      
      const dx = destCoords.lng - currentCoords.lng;
      const dy = destCoords.lat - currentCoords.lat;
      const targetRotation = Math.atan2(dy, dx);
      
      // Smooth rotation
      const currentRotation = sprite.rotation;
      let angleDiff = targetRotation - currentRotation;
      
      // Normalize angle difference
      if (angleDiff > Math.PI) angleDiff -= 2 * Math.PI;
      if (angleDiff < -Math.PI) angleDiff += 2 * Math.PI;
      
      sprite.rotation = currentRotation + angleDiff * 0.1;
    }
  }

  private createWakeEffect(ship: Ship): void {
    const wakeContainer = new PIXI.ParticleContainer(100, {
      scale: true,
      position: true,
      rotation: true,
      alpha: true
    });
    
    this.wakeParticles.set(ship.id, wakeContainer);
    this.effectsContainer.addChild(wakeContainer);
  }

  private updateWakeEffect(ship: Ship): void {
    const wakeContainer = this.wakeParticles.get(ship.id);
    if (!wakeContainer) return;

    // Only show wake if ship is moving
    if (ship.status === 'traveling') {
      const shipSprite = this.shipSprites.get(ship.id);
      if (shipSprite) {
        // Add wake particles behind the ship
        this.addWakeParticles(wakeContainer, shipSprite, ship);
      }
    }
    
    // Update existing wake particles
    this.updateWakeParticles(wakeContainer);
  }

  private addWakeParticles(container: PIXI.ParticleContainer, shipSprite: PIXI.Sprite, ship: Ship): void {
    if (Math.random() < 0.3) { // 30% chance per frame
      try {
        const waveTexture = PIXI.Texture.from('/assets/particles/wave.png');
        const particle = new PIXI.Sprite(waveTexture);
        
        // Position behind ship
        const offsetDistance = 20;
        const offsetX = -Math.cos(shipSprite.rotation) * offsetDistance;
        const offsetY = -Math.sin(shipSprite.rotation) * offsetDistance;
        
        particle.x = shipSprite.x + offsetX + (Math.random() - 0.5) * 10;
        particle.y = shipSprite.y + offsetY + (Math.random() - 0.5) * 10;
        particle.anchor.set(0.5);
        particle.scale.set(0.3 + Math.random() * 0.5);
        particle.alpha = 0.6;
        particle.rotation = Math.random() * Math.PI * 2;
        
        // Store particle data for animation
        (particle as any).life = 1.0;
        (particle as any).fadeSpeed = 0.02 + Math.random() * 0.01;
        
        container.addChild(particle);
      } catch (error) {
        // Fallback: create simple wake graphics
        this.createFallbackWakeParticle(container, shipSprite);
      }
    }
  }

  private createFallbackWakeParticle(container: PIXI.ParticleContainer, shipSprite: PIXI.Sprite): void {
    const graphics = new PIXI.Graphics();
    graphics.beginFill(0x5dade2, 0.5);
    graphics.drawCircle(0, 0, 2);
    graphics.endFill();
    
    const texture = this.app.renderer.generateTexture(graphics);
    const particle = new PIXI.Sprite(texture);
    
    particle.x = shipSprite.x - 15 + (Math.random() - 0.5) * 8;
    particle.y = shipSprite.y + (Math.random() - 0.5) * 8;
    particle.anchor.set(0.5);
    particle.alpha = 0.4;
    
    (particle as any).life = 1.0;
    (particle as any).fadeSpeed = 0.03;
    
    container.addChild(particle);
    graphics.destroy();
  }

  private updateWakeParticles(container: PIXI.ParticleContainer): void {
    for (let i = container.children.length - 1; i >= 0; i--) {
      const particle = container.children[i] as any;
      
      particle.life -= particle.fadeSpeed;
      particle.alpha = particle.life * 0.6;
      particle.scale.x = particle.scale.y = particle.life * 0.5 + 0.2;
      
      if (particle.life <= 0) {
        container.removeChild(particle);
        particle.destroy();
      }
    }
  }

  private getShipSpeed(ship: Ship): number {
    switch (ship.status) {
      case 'traveling': return 1.0;
      case 'docked': return 0.0;
      case 'loading': return 0.1;
      case 'unloading': return 0.1;
      default: return 0.5;
    }
  }

  private createShipSprite(ship: Ship, playerId?: string): PIXI.Sprite {
    // Create ship sprite with fallback graphics
    let shipSprite: PIXI.Sprite;

    try {
      const texture = PIXI.Texture.from('shipSprite');
      shipSprite = new PIXI.Sprite(texture);
    } catch {
      // Fallback: create a simple graphic representation
      const graphics = new PIXI.Graphics();
      this.drawShipGraphic(graphics, ship.type);
      const texture = this.app.renderer.generateTexture(graphics);
      shipSprite = new PIXI.Sprite(texture);
      graphics.destroy();
    }

    // Set ship properties
    shipSprite.anchor.set(0.5);
    shipSprite.scale.set(this.getShipScale(ship.type));
    
    // Use player color if available, otherwise default ship color
    const color = playerId ? this.playerColors.get(playerId) : null;
    shipSprite.tint = color || this.getShipColor(ship.type);

    // Add interactivity
    shipSprite.eventMode = 'static';
    shipSprite.cursor = 'pointer';

    shipSprite.on('pointerover', () => {
      shipSprite.scale.set(shipSprite.scale.x * 1.2);
      this.showShipTooltip(ship, playerId);
    });

    shipSprite.on('pointerout', () => {
      shipSprite.scale.set(shipSprite.scale.x / 1.2);
      this.hideShipTooltip();
    });

    shipSprite.on('pointertap', () => {
      this.selectShip(ship);
    });

    // Store ship reference and player ID
    (shipSprite as any).shipData = ship;
    (shipSprite as any).playerId = playerId;

    return shipSprite;
  }

  private drawShipGraphic(graphics: PIXI.Graphics, shipType: string): void {
    graphics.clear();
    
    // Different shapes for different ship types
    switch (shipType) {
      case 'container_ship':
        graphics.beginFill(0x3b82f6);
        graphics.drawRect(-8, -3, 16, 6);
        graphics.beginFill(0x1d4ed8);
        graphics.drawRect(-6, -2, 12, 4);
        break;
      
      case 'tanker':
        graphics.beginFill(0xf59e0b);
        graphics.drawEllipse(0, 0, 10, 4);
        graphics.beginFill(0xd97706);
        graphics.drawEllipse(0, 0, 8, 3);
        break;
      
      case 'bulk_carrier':
        graphics.beginFill(0x8b5cf6);
        graphics.drawRect(-7, -4, 14, 8);
        graphics.beginFill(0x7c3aed);
        graphics.drawRect(-5, -3, 10, 6);
        break;
      
      default:
        graphics.beginFill(0x10b981);
        graphics.drawRect(-6, -2, 12, 4);
        graphics.beginFill(0x059669);
        graphics.drawRect(-4, -1, 8, 2);
    }
    
    graphics.endFill();
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

  private updateShipAppearance(sprite: PIXI.Sprite, ship: Ship, playerId?: string): void {
    // Get base color from player or ship type
    const baseColor = playerId ? 
      (this.playerColors.get(playerId) || this.getShipColor(ship.type)) : 
      this.getShipColor(ship.type);
    
    // Update tint based on status
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

    // Add pulsing effect for active ships
    if (ship.status === 'traveling') {
      const time = Date.now() * 0.001;
      sprite.alpha = 0.8 + Math.sin(time * 2) * 0.2;
    }

    // Add rotation based on movement direction
    if (ship.status === 'traveling' && ship.destination) {
      const destination = this.getPortById(ship.destination);
      if (destination) {
        const angle = Math.atan2(
          destination.coordinates.latitude - ship.currentLocation.latitude,
          destination.coordinates.longitude - ship.currentLocation.longitude
        );
        sprite.rotation = angle + Math.PI / 2; // Adjust for sprite orientation
      }
    }
  }

  private renderTradeRoutes(): void {
    this.tradeRouteGraphics.clear();

    this.gameState.player.tradeRoutes.forEach(route => {
      const originPort = this.getPortById(route.origin);
      const destinationPort = this.getPortById(route.destination);

      if (originPort && destinationPort) {
        this.drawTradeRoute(originPort, destinationPort, route.ships.length > 0);
      }
    });
  }

  private drawTradeRoute(origin: Port, destination: Port, isActive: boolean): void {
    const startPos = this.worldToScreen(origin.coordinates);
    const endPos = this.worldToScreen(destination.coordinates);

    // Route line
    const lineColor = isActive ? 0x10b981 : 0x6b7280;
    const lineAlpha = isActive ? 0.8 : 0.4;
    const lineWidth = isActive ? 3 : 2;

    this.tradeRouteGraphics.lineStyle(lineWidth, lineColor, lineAlpha);
    
    // Draw curved line
    const midX = (startPos.x + endPos.x) / 2;
    const midY = (startPos.y + endPos.y) / 2 - 50; // Curve upward
    
    this.tradeRouteGraphics.moveTo(startPos.x, startPos.y);
    this.tradeRouteGraphics.quadraticCurveTo(midX, midY, endPos.x, endPos.y);

    // Add direction arrow
    if (isActive) {
      this.drawRouteArrow(endPos, startPos, lineColor);
    }
  }

  private drawRouteArrow(endPos: { x: number; y: number }, startPos: { x: number; y: number }, color: number): void {
    const angle = Math.atan2(endPos.y - startPos.y, endPos.x - startPos.x);
    const arrowSize = 8;
    
    this.tradeRouteGraphics.beginFill(color, 0.8);
    this.tradeRouteGraphics.moveTo(endPos.x, endPos.y);
    this.tradeRouteGraphics.lineTo(
      endPos.x - arrowSize * Math.cos(angle - Math.PI / 6),
      endPos.y - arrowSize * Math.sin(angle - Math.PI / 6)
    );
    this.tradeRouteGraphics.lineTo(
      endPos.x - arrowSize * Math.cos(angle + Math.PI / 6),
      endPos.y - arrowSize * Math.sin(angle + Math.PI / 6)
    );
    this.tradeRouteGraphics.endFill();
  }

  private renderEffects(): void {
    // Add particle effects, animations, etc.
    this.renderWakeEffects();
    this.renderPortActivityEffects();
  }

  private renderWakeEffects(): void {
    // Wake effects are handled in updateWakeEffect method
    // which is called from updateShipSprite for each ship
  }


  private renderPortActivityEffects(): void {
    // Add visual effects for busy ports
    this.gameState.world.ports.forEach(port => {
      const activity = this.calculatePortActivity(port);
      if (activity > 0.5) {
        this.createPortActivityEffect(port);
      }
    });
  }

  private calculatePortActivity(port: Port): number {
    // Calculate how busy the port is based on ships and cargo
    const shipsAtPort = this.gameState.player.ships.filter(ship => 
      this.isShipAtPort(ship, port)
    ).length;
    
    return Math.min(1, shipsAtPort / 3); // Normalize to 0-1
  }

  private createPortActivityEffect(port: Port): void {
    const screenPos = this.worldToScreen(port.coordinates);
    
    // Create subtle glow effect
    const glow = new PIXI.Graphics();
    glow.beginFill(0xffd700, 0.1);
    glow.drawCircle(screenPos.x, screenPos.y, 20);
    glow.endFill();
    
    this.effectsContainer.addChild(glow);
    
    // Animate glow
    let scale = 1;
    let growing = true;
    
    const animate = () => {
      if (growing) {
        scale += 0.01;
        if (scale >= 1.2) growing = false;
      } else {
        scale -= 0.01;
        if (scale <= 1) growing = true;
      }
      
      glow.scale.set(scale);
      
      setTimeout(() => {
        if (glow.parent) animate();
      }, 50);
    };
    
    animate();
    
    // Remove after 5 seconds
    setTimeout(() => {
      if (glow.parent) {
        this.effectsContainer.removeChild(glow);
        glow.destroy();
      }
    }, 5000);
  }

  private showShipTooltip(ship: Ship, playerId?: string): void {
    // Create tooltip (would be more sophisticated in real implementation)
    const playerInfo = playerId ? `Player: ${playerId.substring(0, 8)} | ` : '';
    console.log(`${playerInfo}Ship: ${ship.name} | Type: ${ship.type} | Status: ${ship.status}`);
  }

  private hideShipTooltip(): void {
    // Hide tooltip
  }

  private selectShip(ship: Ship): void {
    // Emit ship selection event
    this.app.stage.emit('shipSelected', ship);
    console.log(`Selected ship: ${ship.name}`);
  }

  private worldToScreen(coordinates: { latitude: number; longitude: number }): { x: number; y: number } {
    // This should match the MapSystem's worldToScreen method
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

  private getPortById(portId: string): Port | undefined {
    return this.gameState.world.ports.find(port => port.id === portId);
  }

  private isShipAtPort(ship: Ship, port: Port): boolean {
    const distance = this.calculateDistance(ship.currentLocation, port.coordinates);
    return distance < 1; // Within 1 km
  }

  private calculateDistance(from: { latitude: number; longitude: number }, to: { latitude: number; longitude: number }): number {
    const R = 6371; // Earth's radius in kilometers
    const dLat = (to.latitude - from.latitude) * Math.PI / 180;
    const dLon = (to.longitude - from.longitude) * Math.PI / 180;
    const a = 
      Math.sin(dLat/2) * Math.sin(dLat/2) +
      Math.cos(from.latitude * Math.PI / 180) * Math.cos(to.latitude * Math.PI / 180) * 
      Math.sin(dLon/2) * Math.sin(dLon/2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    return R * c;
  }

  public handleResize(width: number, height: number): void {
    // Update ship positions for new screen size
    this.gameState.player.ships.forEach(ship => {
      const sprite = this.shipSprites.get(ship.id);
      if (sprite) {
        const screenPos = this.worldToScreen(ship.currentLocation);
        sprite.x = screenPos.x;
        sprite.y = screenPos.y;
      }
    });

    // Redraw trade routes
    this.renderTradeRoutes();
  }

  public destroy(): void {
    this.shipSprites.forEach(sprite => {
      sprite.destroy();
    });
    this.shipSprites.clear();
    
    this.shipContainer.destroy({ children: true });
    this.effectsContainer.destroy({ children: true });
    this.tradeRouteGraphics.destroy();
  }
}