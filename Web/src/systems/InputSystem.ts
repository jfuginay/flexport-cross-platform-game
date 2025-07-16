import * as PIXI from 'pixi.js';
import { GameState, Vector2 } from '@/types';

export class InputSystem {
  private app: PIXI.Application;
  private gameState: GameState;
  private mapSystem: any;
  
  private isDragging = false;
  private lastPointerPosition: Vector2 = { x: 0, y: 0 };
  private dragStartPosition: Vector2 = { x: 0, y: 0 };
  private mapStartPosition: Vector2 = { x: 0, y: 0 };
  
  private pinchDistance = 0;
  private isPinching = false;
  private initialZoom = 1;
  
  private keys: Set<string> = new Set();

  constructor(app: PIXI.Application, gameState: GameState) {
    this.app = app;
    this.gameState = gameState;
    this.setupEventListeners();
  }

  public setMapSystem(mapSystem: any): void {
    this.mapSystem = mapSystem;
  }

  private setupEventListeners(): void {
    // Mouse and touch events
    this.app.stage.eventMode = 'static';
    this.app.stage.hitArea = this.app.screen;
    
    this.app.stage.on('pointerdown', this.onPointerDown.bind(this));
    this.app.stage.on('pointermove', this.onPointerMove.bind(this));
    this.app.stage.on('pointerup', this.onPointerUp.bind(this));
    this.app.stage.on('pointerupoutside', this.onPointerUp.bind(this));
    
    // Wheel events for zooming
    this.app.canvas.addEventListener('wheel', this.onWheel.bind(this), { passive: false });
    
    // Keyboard events
    window.addEventListener('keydown', this.onKeyDown.bind(this));
    window.addEventListener('keyup', this.onKeyUp.bind(this));
    
    // Touch-specific events for pinch zoom
    this.app.canvas.addEventListener('touchstart', this.onTouchStart.bind(this), { passive: false });
    this.app.canvas.addEventListener('touchmove', this.onTouchMove.bind(this), { passive: false });
    this.app.canvas.addEventListener('touchend', this.onTouchEnd.bind(this), { passive: false });
    
    // Prevent context menu on right click
    this.app.canvas.addEventListener('contextmenu', (e) => e.preventDefault());
  }

  private onPointerDown(event: PIXI.FederatedPointerEvent): void {
    if (event.data.pointerType === 'touch' && this.getTouchCount() > 1) {
      return; // Multi-touch handled separately
    }
    
    this.isDragging = true;
    this.lastPointerPosition = { x: event.global.x, y: event.global.y };
    this.dragStartPosition = { x: event.global.x, y: event.global.y };
    
    if (this.mapSystem) {
      this.mapStartPosition = { 
        x: this.mapSystem.mapContainer.x, 
        y: this.mapSystem.mapContainer.y 
      };
    }
    
    this.app.stage.cursor = 'grabbing';
  }

  private onPointerMove(event: PIXI.FederatedPointerEvent): void {
    if (!this.isDragging || this.isPinching) return;
    
    const currentPosition = { x: event.global.x, y: event.global.y };
    const deltaX = currentPosition.x - this.lastPointerPosition.x;
    const deltaY = currentPosition.y - this.lastPointerPosition.y;
    
    if (this.mapSystem && this.mapSystem.mapContainer) {
      this.mapSystem.mapContainer.x += deltaX;
      this.mapSystem.mapContainer.y += deltaY;
    }
    
    this.lastPointerPosition = currentPosition;
  }

  private onPointerUp(event: PIXI.FederatedPointerEvent): void {
    this.isDragging = false;
    this.app.stage.cursor = 'default';
    
    // Check if this was a click (minimal movement)
    const dragDistance = Math.sqrt(
      Math.pow(event.global.x - this.dragStartPosition.x, 2) +
      Math.pow(event.global.y - this.dragStartPosition.y, 2)
    );
    
    if (dragDistance < 5) {
      this.handleClick(event);
    }
  }

  private handleClick(event: PIXI.FederatedPointerEvent): void {
    // Handle map clicks, ship selection, etc.
    const localPosition = { x: event.global.x, y: event.global.y };
    
    // Check for UI element clicks first
    const clickedUI = this.checkUIElementClick(localPosition);
    if (clickedUI) return;
    
    // Handle map click
    this.handleMapClick(localPosition);
  }

  private checkUIElementClick(position: Vector2): boolean {
    // This would be expanded to check various UI panels and buttons
    return false;
  }

  private handleMapClick(position: Vector2): void {
    // Convert screen position to world coordinates
    if (this.mapSystem) {
      const worldPos = this.mapSystem.screenToWorld(position);
      console.log(`Clicked map at: ${worldPos.latitude}, ${worldPos.longitude}`);
      
      // Emit map click event for other systems to handle
      this.app.stage.emit('mapClicked', worldPos);
    }
  }

  private onWheel(event: WheelEvent): void {
    event.preventDefault();
    
    if (!this.mapSystem) return;
    
    const zoomFactor = event.deltaY > 0 ? 0.9 : 1.1;
    const currentZoom = this.mapSystem.viewState.zoom;
    const newZoom = currentZoom * zoomFactor;
    
    const rect = this.app.canvas.getBoundingClientRect();
    const centerPoint = {
      x: event.clientX - rect.left,
      y: event.clientY - rect.top,
    };
    
    this.mapSystem.setZoom(newZoom, centerPoint);
  }

  private onTouchStart(event: TouchEvent): void {
    if (event.touches.length === 2) {
      event.preventDefault();
      this.startPinchZoom(event);
    }
  }

  private onTouchMove(event: TouchEvent): void {
    if (event.touches.length === 2 && this.isPinching) {
      event.preventDefault();
      this.updatePinchZoom(event);
    }
  }

  private onTouchEnd(event: TouchEvent): void {
    if (event.touches.length < 2) {
      this.endPinchZoom();
    }
  }

  private startPinchZoom(event: TouchEvent): void {
    this.isPinching = true;
    this.isDragging = false;
    
    const touch1 = event.touches[0];
    const touch2 = event.touches[1];
    
    this.pinchDistance = Math.sqrt(
      Math.pow(touch2.clientX - touch1.clientX, 2) +
      Math.pow(touch2.clientY - touch1.clientY, 2)
    );
    
    if (this.mapSystem) {
      this.initialZoom = this.mapSystem.viewState.zoom;
    }
  }

  private updatePinchZoom(event: TouchEvent): void {
    const touch1 = event.touches[0];
    const touch2 = event.touches[1];
    
    const currentDistance = Math.sqrt(
      Math.pow(touch2.clientX - touch1.clientX, 2) +
      Math.pow(touch2.clientY - touch1.clientY, 2)
    );
    
    if (this.pinchDistance > 0 && this.mapSystem) {
      const scale = currentDistance / this.pinchDistance;
      const newZoom = this.initialZoom * scale;
      
      // Calculate center point between fingers
      const centerX = (touch1.clientX + touch2.clientX) / 2;
      const centerY = (touch1.clientY + touch2.clientY) / 2;
      
      const rect = this.app.canvas.getBoundingClientRect();
      const centerPoint = {
        x: centerX - rect.left,
        y: centerY - rect.top,
      };
      
      this.mapSystem.setZoom(newZoom, centerPoint);
    }
  }

  private endPinchZoom(): void {
    this.isPinching = false;
    this.pinchDistance = 0;
  }

  private getTouchCount(): number {
    // This would need to be implemented to track active touches
    return 0;
  }

  private onKeyDown(event: KeyboardEvent): void {
    this.keys.add(event.code);
    
    // Handle specific key combinations
    switch (event.code) {
      case 'Space':
        event.preventDefault();
        this.handlePause();
        break;
      case 'KeyM':
        if (event.ctrlKey || event.metaKey) {
          event.preventDefault();
          this.toggleMinimap();
        }
        break;
      case 'Escape':
        this.handleEscape();
        break;
      case 'KeyF':
        this.handleFindPort();
        break;
      case 'KeyH':
        this.showHelp();
        break;
    }
  }

  private onKeyUp(event: KeyboardEvent): void {
    this.keys.delete(event.code);
  }

  private handlePause(): void {
    // Toggle game pause
    this.app.stage.emit('gamePauseToggle');
  }

  private toggleMinimap(): void {
    // Toggle minimap visibility
    this.app.stage.emit('minimapToggle');
  }

  private handleEscape(): void {
    // Close modals, deselect objects, etc.
    this.app.stage.emit('escape');
  }

  private handleFindPort(): void {
    // Open port search dialog
    this.app.stage.emit('showPortSearch');
  }

  private showHelp(): void {
    // Show help/controls overlay
    this.app.stage.emit('showHelp');
  }

  public update(deltaTime: number): void {
    // Handle continuous key presses
    this.handleContinuousInput(deltaTime);
  }

  private handleContinuousInput(deltaTime: number): void {
    if (!this.mapSystem) return;
    
    const panSpeed = 300 * deltaTime; // pixels per second
    let panX = 0;
    let panY = 0;
    
    // WASD or arrow key panning
    if (this.keys.has('KeyW') || this.keys.has('ArrowUp')) {
      panY += panSpeed;
    }
    if (this.keys.has('KeyS') || this.keys.has('ArrowDown')) {
      panY -= panSpeed;
    }
    if (this.keys.has('KeyA') || this.keys.has('ArrowLeft')) {
      panX += panSpeed;
    }
    if (this.keys.has('KeyD') || this.keys.has('ArrowRight')) {
      panX -= panSpeed;
    }
    
    if (panX !== 0 || panY !== 0) {
      this.mapSystem.mapContainer.x += panX;
      this.mapSystem.mapContainer.y += panY;
    }
    
    // Zoom with + and - keys
    if (this.keys.has('Equal') || this.keys.has('NumpadAdd')) {
      const currentZoom = this.mapSystem.viewState.zoom;
      this.mapSystem.setZoom(currentZoom * (1 + deltaTime));
    }
    if (this.keys.has('Minus') || this.keys.has('NumpadSubtract')) {
      const currentZoom = this.mapSystem.viewState.zoom;
      this.mapSystem.setZoom(currentZoom * (1 - deltaTime));
    }
  }

  public isKeyPressed(keyCode: string): boolean {
    return this.keys.has(keyCode);
  }

  public destroy(): void {
    // Remove all event listeners
    this.app.stage.removeAllListeners();
    this.app.canvas.removeEventListener('wheel', this.onWheel.bind(this));
    this.app.canvas.removeEventListener('touchstart', this.onTouchStart.bind(this));
    this.app.canvas.removeEventListener('touchmove', this.onTouchMove.bind(this));
    this.app.canvas.removeEventListener('touchend', this.onTouchEnd.bind(this));
    this.app.canvas.removeEventListener('contextmenu', (e) => e.preventDefault());
    
    window.removeEventListener('keydown', this.onKeyDown.bind(this));
    window.removeEventListener('keyup', this.onKeyUp.bind(this));
  }
}