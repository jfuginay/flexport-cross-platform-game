import * as PIXI from 'pixi.js';
import { GameState, Port, Coordinates, Vector2 } from '@/types';

export class MapSystem {
  private app: PIXI.Application;
  private gameState: GameState;
  private mapContainer!: PIXI.Container;
  private oceanContainer!: PIXI.Container;
  private portContainer!: PIXI.Container;
  private routeContainer!: PIXI.Container;
  
  private mapBounds = {
    minLat: -60,
    maxLat: 80,
    minLng: -180,
    maxLng: 180,
  };
  
  private viewState = {
    zoom: 1.0,
    centerX: 0,
    centerY: 0,
    minZoom: 0.5,
    maxZoom: 5.0,
  };
  
  private oceanShader: PIXI.Filter | null = null;
  private animationTime = 0;

  constructor(app: PIXI.Application, gameState: GameState) {
    this.app = app;
    this.gameState = gameState;
    this.createMapLayers();
    this.setupShaders();
  }

  private createMapLayers(): void {
    this.mapContainer = new PIXI.Container();
    this.mapContainer.sortableChildren = true;
    this.app.stage.addChild(this.mapContainer);

    this.oceanContainer = new PIXI.Container();
    this.oceanContainer.zIndex = 0;
    this.mapContainer.addChild(this.oceanContainer);

    this.routeContainer = new PIXI.Container();
    this.routeContainer.zIndex = 1;
    this.mapContainer.addChild(this.routeContainer);

    this.portContainer = new PIXI.Container();
    this.portContainer.zIndex = 2;
    this.mapContainer.addChild(this.portContainer);

    this.createOceanBackground();
    this.createPorts();
  }

  private setupShaders(): void {
    const oceanVertexShader = `
      attribute vec2 aVertexPosition;
      attribute vec2 aTextureCoord;
      
      uniform mat3 projectionMatrix;
      uniform mat3 translationMatrix;
      uniform mat3 uTextureMatrix;
      
      varying vec2 vTextureCoord;
      varying vec2 vWorldPos;
      
      void main(void) {
        gl_Position = vec4((projectionMatrix * translationMatrix * vec3(aVertexPosition, 1.0)).xy, 0.0, 1.0);
        vTextureCoord = (uTextureMatrix * vec3(aTextureCoord, 1.0)).xy;
        vWorldPos = aVertexPosition;
      }
    `;

    const oceanFragmentShader = `
      precision mediump float;
      
      varying vec2 vTextureCoord;
      varying vec2 vWorldPos;
      
      uniform float uTime;
      uniform vec2 uResolution;
      uniform float uZoom;
      
      // Ocean wave functions
      float noise(vec2 p) {
        return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
      }
      
      float fbm(vec2 p) {
        float value = 0.0;
        float amplitude = 0.5;
        for(int i = 0; i < 4; i++) {
          value += amplitude * noise(p);
          p *= 2.0;
          amplitude *= 0.5;
        }
        return value;
      }
      
      void main() {
        vec2 uv = vWorldPos / uResolution;
        
        // Create animated ocean waves
        float wave1 = sin(uv.x * 10.0 + uTime * 2.0) * 0.1;
        float wave2 = sin(uv.y * 8.0 + uTime * 1.5) * 0.08;
        float wave3 = fbm(uv * 5.0 + uTime * 0.5) * 0.05;
        
        float waves = wave1 + wave2 + wave3;
        
        // Ocean color gradients
        vec3 deepOcean = vec3(0.1, 0.2, 0.4);
        vec3 shallowOcean = vec3(0.2, 0.4, 0.6);
        vec3 foam = vec3(0.7, 0.8, 0.9);
        
        // Mix colors based on wave height
        vec3 oceanColor = mix(deepOcean, shallowOcean, waves + 0.5);
        
        // Add foam on wave peaks
        if(waves > 0.08) {
          oceanColor = mix(oceanColor, foam, (waves - 0.08) * 10.0);
        }
        
        // Add depth based on distance from center
        float depth = length(uv - 0.5);
        oceanColor = mix(oceanColor, deepOcean, depth * 0.3);
        
        gl_FragColor = vec4(oceanColor, 1.0);
      }
    `;

    try {
      this.oceanShader = new PIXI.Filter({
        fragmentShader: oceanFragmentShader,
        uniforms: {
          uTime: 0.0,
          uResolution: [this.app.screen.width, this.app.screen.height],
          uZoom: this.viewState.zoom,
        }
      });
    } catch (error) {
      console.warn('Could not create ocean shader, using fallback');
      this.oceanShader = null;
    }
  }

  private createOceanBackground(): void {
    // Create large ocean background with realistic blue color
    const oceanBackground = new PIXI.Graphics();
    
    // Create gradient ocean background
    const gradient = new PIXI.FillGradient(0, 0, this.app.screen.width, this.app.screen.height);
    gradient.addColorStop(0, 0x0f4c75); // Deep ocean blue
    gradient.addColorStop(0.5, 0x3282b8); // Mid ocean blue  
    gradient.addColorStop(1, 0x1a365d); // Darker blue at edges
    
    oceanBackground.beginFill(0x1a365d); // Use solid color instead of gradient
    oceanBackground.drawRect(-1000, -1000, this.app.screen.width + 2000, this.app.screen.height + 2000);
    oceanBackground.endFill();
    
    // Add animated wave patterns
    if (this.oceanShader) {
      try {
        oceanBackground.filters = [this.oceanShader];
      } catch (error) {
        console.warn('Ocean shader failed, using static background');
      }
    }
    
    this.oceanContainer.addChild(oceanBackground);
    
    // Add subtle water texture overlay
    this.addWaterTexture();
  }
  
  private addWaterTexture(): void {
    const waterTexture = new PIXI.Graphics();
    
    // Create subtle wave patterns
    for (let i = 0; i < 50; i++) {
      const x = Math.random() * this.app.screen.width;
      const y = Math.random() * this.app.screen.height;
      const radius = Math.random() * 3 + 1;
      const alpha = Math.random() * 0.1 + 0.05;
      
      waterTexture.beginFill(0x5dade2, alpha);
      waterTexture.drawCircle(x, y, radius);
      waterTexture.endFill();
    }
    
    this.oceanContainer.addChild(waterTexture);
  }

  private createPorts(): void {
    this.gameState.world.ports.forEach(port => {
      this.createPortSprite(port);
    });
  }

  private createPortSprite(port: Port): PIXI.Container {
    const portSprite = new PIXI.Container();
    
    // Port background circle
    const background = new PIXI.Graphics();
    const portColor = this.getPortColor(port.size);
    background.beginFill(portColor, 0.8);
    background.drawCircle(0, 0, this.getPortRadius(port.size));
    background.endFill();
    
    // Port border
    background.lineStyle(2, 0xffffff, 0.9);
    background.drawCircle(0, 0, this.getPortRadius(port.size));
    
    portSprite.addChild(background);
    
    // Port icon/symbol
    const icon = this.createPortIcon(port);
    portSprite.addChild(icon);
    
    // Port label
    const label = this.createPortLabel(port);
    portSprite.addChild(label);
    
    // Position port on map
    const screenPos = this.worldToScreen(port.coordinates);
    portSprite.x = screenPos.x;
    portSprite.y = screenPos.y;
    
    // Interactive features
    portSprite.eventMode = 'static';
    portSprite.cursor = 'pointer';
    
    portSprite.on('pointerover', () => {
      background.tint = 0xffff99;
      portSprite.scale.set(1.2);
    });
    
    portSprite.on('pointerout', () => {
      background.tint = 0xffffff;
      portSprite.scale.set(1.0);
    });
    
    portSprite.on('pointertap', () => {
      this.handlePortClick(port);
    });
    
    // Store port reference
    (portSprite as any).portData = port;
    
    this.portContainer.addChild(portSprite);
    return portSprite;
  }

  private getPortColor(size: string): number {
    switch (size) {
      case 'mega': return 0xff6b6b;
      case 'large': return 0x4ecdc4;
      case 'medium': return 0x45b7d1;
      case 'small': return 0x96ceb4;
      default: return 0x85c1e9;
    }
  }

  private getPortRadius(size: string): number {
    switch (size) {
      case 'mega': return 12;
      case 'large': return 10;
      case 'medium': return 8;
      case 'small': return 6;
      default: return 8;
    }
  }

  private createPortIcon(port: Port): PIXI.Graphics {
    const icon = new PIXI.Graphics();
    icon.lineStyle(1, 0xffffff, 1);
    
    // Simple port icon - crane/dock symbol
    icon.moveTo(-3, -2);
    icon.lineTo(3, -2);
    icon.moveTo(0, -2);
    icon.lineTo(0, 2);
    icon.moveTo(-2, 0);
    icon.lineTo(2, 0);
    
    return icon;
  }

  private createPortLabel(port: Port): PIXI.Text {
    const style = new PIXI.TextStyle({
      fontFamily: 'Arial',
      fontSize: 10,
      fill: 0xffffff,
      stroke: { width: 2, color: '#66d9ef' },
      dropShadow: true,
      // dropShadowDistance: 1, // Deprecated in PIXI v8
      // dropShadowBlur: 2, // Deprecated in PIXI v8
    });
    
    const label = new PIXI.Text(port.name, style);
    label.anchor.set(0.5, -0.5);
    label.y = -this.getPortRadius(port.size) - 5;
    label.alpha = 0.8;
    
    return label;
  }

  private handlePortClick(port: Port): void {
    console.log(`Clicked port: ${port.name}`);
    // Emit event for UI system to handle
    this.app.stage.emit('portSelected', port);
  }

  private worldToScreen(coordinates: Coordinates): Vector2 {
    const normalizedX = (coordinates.longitude - this.mapBounds.minLng) / 
                      (this.mapBounds.maxLng - this.mapBounds.minLng);
    const normalizedY = (coordinates.latitude - this.mapBounds.minLat) / 
                      (this.mapBounds.maxLat - this.mapBounds.minLat);
    
    return {
      x: normalizedX * this.app.screen.width,
      y: (1 - normalizedY) * this.app.screen.height, // Flip Y axis
    };
  }

  private screenToWorld(screenPos: Vector2): Coordinates {
    const normalizedX = screenPos.x / this.app.screen.width;
    const normalizedY = 1 - (screenPos.y / this.app.screen.height); // Flip Y axis
    
    return {
      longitude: this.mapBounds.minLng + normalizedX * (this.mapBounds.maxLng - this.mapBounds.minLng),
      latitude: this.mapBounds.minLat + normalizedY * (this.mapBounds.maxLat - this.mapBounds.minLat),
    };
  }

  public panTo(coordinates: Coordinates, animated = true): void {
    const targetScreen = this.worldToScreen(coordinates);
    const centerX = this.app.screen.width / 2;
    const centerY = this.app.screen.height / 2;
    
    if (animated) {
      // Smooth pan animation
      const startX = this.mapContainer.x;
      const startY = this.mapContainer.y;
      const targetX = centerX - targetScreen.x;
      const targetY = centerY - targetScreen.y;
      
      this.animatePan(startX, startY, targetX, targetY, 1000);
    } else {
      this.mapContainer.x = centerX - targetScreen.x;
      this.mapContainer.y = centerY - targetScreen.y;
    }
  }

  private animatePan(startX: number, startY: number, targetX: number, targetY: number, duration: number): void {
    const startTime = Date.now();
    
    const animate = () => {
      const elapsed = Date.now() - startTime;
      const progress = Math.min(elapsed / duration, 1);
      const eased = this.easeInOutCubic(progress);
      
      this.mapContainer.x = startX + (targetX - startX) * eased;
      this.mapContainer.y = startY + (targetY - startY) * eased;
      
      if (progress < 1) {
        requestAnimationFrame(animate);
      }
    };
    
    animate();
  }

  private easeInOutCubic(t: number): number {
    return t < 0.5 ? 4 * t * t * t : (t - 1) * (2 * t - 2) * (2 * t - 2) + 1;
  }

  public setZoom(zoom: number, center?: Vector2): void {
    const newZoom = Math.max(this.viewState.minZoom, Math.min(zoom, this.viewState.maxZoom));
    const zoomCenter = center || { x: this.app.screen.width / 2, y: this.app.screen.height / 2 };
    
    const oldZoom = this.viewState.zoom;
    const zoomRatio = newZoom / oldZoom;
    
    // Adjust position to zoom around the specified point
    this.mapContainer.x = zoomCenter.x - (zoomCenter.x - this.mapContainer.x) * zoomRatio;
    this.mapContainer.y = zoomCenter.y - (zoomCenter.y - this.mapContainer.y) * zoomRatio;
    
    this.mapContainer.scale.set(newZoom);
    this.viewState.zoom = newZoom;
    
    // Update shader uniforms
    if (this.oceanShader) {
      (this.oceanShader as any).uniforms.uZoom = newZoom;
    }
    
    this.updatePortVisibility();
  }

  private updatePortVisibility(): void {
    this.portContainer.children.forEach(portSprite => {
      const port = (portSprite as any).portData as Port;
      const radius = this.getPortRadius(port.size);
      
      // Hide small ports when zoomed out
      if (this.viewState.zoom < 1.0 && port.size === 'small') {
        portSprite.visible = false;
      } else if (this.viewState.zoom < 0.7 && port.size === 'medium') {
        portSprite.visible = false;
      } else {
        portSprite.visible = true;
      }
      
      // Scale ports based on zoom
      const baseScale = Math.max(0.5, 1 / this.viewState.zoom);
      portSprite.scale.set(baseScale);
    });
  }

  public drawTradeRoute(originPort: Port, destinationPort: Port, active = false): void {
    const route = new PIXI.Graphics();
    
    const startPos = this.worldToScreen(originPort.coordinates);
    const endPos = this.worldToScreen(destinationPort.coordinates);
    
    // Draw route line
    const lineColor = active ? 0x00ff00 : 0x888888;
    const lineAlpha = active ? 0.8 : 0.5;
    
    route.lineStyle(2, lineColor, lineAlpha);
    route.moveTo(startPos.x, startPos.y);
    route.lineTo(endPos.x, endPos.y);
    
    // Add direction arrow
    const angle = Math.atan2(endPos.y - startPos.y, endPos.x - startPos.x);
    const arrowSize = 8;
    const arrowX = endPos.x - Math.cos(angle) * 20;
    const arrowY = endPos.y - Math.sin(angle) * 20;
    
    route.beginFill(lineColor, lineAlpha);
    route.moveTo(arrowX, arrowY);
    route.lineTo(arrowX - arrowSize * Math.cos(angle - Math.PI / 6), arrowY - arrowSize * Math.sin(angle - Math.PI / 6));
    route.lineTo(arrowX - arrowSize * Math.cos(angle + Math.PI / 6), arrowY - arrowSize * Math.sin(angle + Math.PI / 6));
    route.endFill();
    
    this.routeContainer.addChild(route);
  }

  public clearTradeRoutes(): void {
    this.routeContainer.removeChildren();
  }

  public update(deltaTime: number): void {
    this.animationTime += deltaTime;
    
    // Update ocean shader animation
    if (this.oceanShader && this.oceanShader.uniforms) {
      this.oceanShader.uniforms.uTime = this.animationTime;
    }
    
    // Update port animations or effects if needed
    this.updatePortAnimations(deltaTime);
  }

  private updatePortAnimations(deltaTime: number): void {
    // Add subtle breathing animation to ports
    this.portContainer.children.forEach((portSprite, index) => {
      const breatheAmount = Math.sin(this.animationTime * 2 + index * 0.5) * 0.05 + 1;
      portSprite.alpha = 0.8 + breatheAmount * 0.2;
    });
  }

  public handleResize(width: number, height: number): void {
    if (this.oceanShader) {
      this.oceanShader.uniforms.uResolution = [width, height];
    }
    
    // Recreate ocean background with new dimensions
    this.oceanContainer.removeChildren();
    this.createOceanBackground();
    
    // Update port positions
    this.updatePortPositions();
  }

  private updatePortPositions(): void {
    this.portContainer.children.forEach(portSprite => {
      const port = (portSprite as any).portData as Port;
      const screenPos = this.worldToScreen(port.coordinates);
      portSprite.x = screenPos.x;
      portSprite.y = screenPos.y;
    });
  }

  public getVisibleBounds(): { minLat: number; maxLat: number; minLng: number; maxLng: number } {
    const topLeft = this.screenToWorld({ x: 0, y: 0 });
    const bottomRight = this.screenToWorld({ x: this.app.screen.width, y: this.app.screen.height });
    
    return {
      minLat: bottomRight.latitude,
      maxLat: topLeft.latitude,
      minLng: topLeft.longitude,
      maxLng: bottomRight.longitude,
    };
  }

  public destroy(): void {
    this.mapContainer.removeFromParent();
    this.mapContainer.destroy({ children: true });
  }
}