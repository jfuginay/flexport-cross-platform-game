import * as PIXI from 'pixi.js';
import { GameState, GameConfig } from '@/types';
import { EconomicSystem } from '@/systems/EconomicSystem';
import { ShipSystem } from '@/systems/ShipSystem';
import { AISystem } from '@/systems/AISystem';
import { RenderSystem } from '@/systems/RenderSystem';
import { InputSystem } from '@/systems/InputSystem';
import { MapSystem } from '@/systems/MapSystem';
import { UISystem } from '@/systems/UISystem';
import { MultiplayerSystem } from '@/systems/MultiplayerSystem';
import { GameStateStore } from '@/core/GameStateStore';
import { LobbyComponent } from '@/components/LobbyComponent';
import { StateSynchronization } from '@/networking/StateSynchronization';

export class GameEngine {
  private app!: PIXI.Application;
  private gameState!: GameState;
  private systems: Map<string, any> = new Map();
  private lastTime = 0;
  private deltaTime = 0;
  private running = false;
  private config: GameConfig;
  private initializationPromise: Promise<void>;
  private lobbyComponent: LobbyComponent | null = null;
  private isMultiplayerMode = false;
  private stateSynchronization: StateSynchronization | null = null;

  constructor(canvas: HTMLElement, config: GameConfig) {
    this.config = config;
    this.initializationPromise = this.initializeGame(canvas);
  }

  private async initializeGame(canvas: HTMLElement): Promise<void> {
    await this.initializePixiApp(canvas);
    this.initializeGameState();
    this.initializeSystems();
    this.setupEventListeners();
  }

  private async initializePixiApp(canvas: HTMLElement): Promise<void> {
    this.app = new PIXI.Application();
    
    await this.app.init({
      width: window.innerWidth,
      height: window.innerHeight,
      backgroundColor: 0x0f172a,
      antialias: true,
      autoDensity: true,
      resolution: window.devicePixelRatio || 1,
    });

    canvas.appendChild(this.app.canvas);

    PIXI.Assets.addBundle('game-assets', {
      oceanTexture: '/assets/textures/ocean.jpg',
      shipSprite: '/assets/sprites/ship.png',
      portSprite: '/assets/sprites/port.png',
      waveParticle: '/assets/particles/wave.png',
    });

    try {
      await PIXI.Assets.loadBundle('game-assets');
    } catch (error) {
      console.warn('Could not load game assets, using fallback graphics');
    }
  }

  private initializeGameState(): void {
    this.gameState = GameStateStore.getInitialState();
  }

  private initializeSystems(): void {
    this.systems.set('economic', new EconomicSystem(this.gameState));
    this.systems.set('ship', new ShipSystem(this.gameState));
    this.systems.set('ai', new AISystem(this.gameState));
    this.systems.set('map', new MapSystem(this.app, this.gameState));
    this.systems.set('render', new RenderSystem(this.app, this.gameState));
    this.systems.set('input', new InputSystem(this.app, this.gameState));
    this.systems.set('ui', new UISystem(this.gameState));
    
    // Initialize multiplayer system
    const multiplayerSystem = new MultiplayerSystem(this.gameState);
    this.systems.set('multiplayer', multiplayerSystem);
    
    // Create lobby component
    this.lobbyComponent = new LobbyComponent(multiplayerSystem);

    this.systems.forEach((system, name) => {
      if (system.initialize) {
        system.initialize();
      }
    });
    
    // Setup multiplayer event handlers
    this.setupMultiplayerHandlers();
  }

  private setupMultiplayerHandlers(): void {
    const multiplayerSystem = this.systems.get('multiplayer');
    if (!multiplayerSystem) return;

    // Handle game start from multiplayer
    multiplayerSystem.on('game_started', ({ gameState, playerAssignments }: any) => {
      console.log('Multiplayer game started!');
      this.isMultiplayerMode = true;
      
      // Hide lobby and resume game
      if (this.lobbyComponent) {
        this.lobbyComponent.hide();
      }
      
      // Apply multiplayer game state
      Object.assign(this.gameState, gameState);
      
      // Update player assignment
      const playerId = multiplayerSystem.wsManager?.getPlayerId();
      if (playerId && playerAssignments[playerId]) {
        this.gameState.player.id = playerAssignments[playerId];
      }
      
      // Initialize state synchronization for multiplayer
      this.initializeStateSynchronization(multiplayerSystem);
      
      this.resume();
    });

    // Handle multiplayer game actions
    multiplayerSystem.on('game_action_received', ({ action, data, playerId }: any) => {
      this.handleMultiplayerAction(action, data, playerId);
    });

    // Handle connection changes
    multiplayerSystem.on('connection_changed', ({ connected }: any) => {
      if (!connected && this.isMultiplayerMode) {
        console.warn('Lost connection during multiplayer game');
        // Could show reconnection UI here
      }
    });
  }

  private initializeStateSynchronization(multiplayerSystem: any): void {
    if (!multiplayerSystem.wsManager) return;
    
    // Create state synchronization instance
    this.stateSynchronization = new StateSynchronization(multiplayerSystem.wsManager);
    
    // Register local ships
    this.stateSynchronization.registerLocalShips(this.gameState.player.ships);
    
    // Handle ship updates from network
    this.stateSynchronization.onShipUpdate((playerShips) => {
      const renderSystem = this.systems.get('render') as RenderSystem;
      if (renderSystem) {
        renderSystem.updatePlayerShips(playerShips);
      }
    });
    
    // Start synchronization
    this.stateSynchronization.start();
  }

  private handleMultiplayerAction(action: string, data: any, _playerId: string): void {
    // Handle different types of multiplayer actions
    switch (action) {
      case 'ship_move':
        // Ship movement is now handled by StateSynchronization
        break;
      case 'trade_order':
        // Handle trade orders from other players
        break;
      case 'chat_message':
        // Handle chat messages
        break;
      default:
        console.log(`Unhandled multiplayer action: ${action}`, data);
    }
  }

  private setupEventListeners(): void {
    window.addEventListener('resize', this.handleResize.bind(this));
    
    window.addEventListener('beforeunload', () => {
      this.saveGame();
    });

    document.addEventListener('visibilitychange', () => {
      if (document.hidden) {
        this.pause();
      } else {
        this.resume();
      }
    });

    // Keyboard shortcuts
    document.addEventListener('keydown', (event) => {
      // Toggle multiplayer lobby with 'M' key
      if (event.key === 'm' || event.key === 'M') {
        this.toggleMultiplayerLobby();
      }
      
      // Show help with 'H' key  
      if (event.key === 'h' || event.key === 'H') {
        this.showHelp();
      }
    });
  }

  private handleResize(): void {
    const width = window.innerWidth;
    const height = window.innerHeight;
    
    this.app.renderer.resize(width, height);
    
    this.systems.get('render')?.handleResize(width, height);
    this.systems.get('ui')?.handleResize(width, height);
  }

  public start(): void {
    if (this.running) return;
    
    this.running = true;
    this.lastTime = performance.now();
    this.gameLoop();
    
    const loadingElement = document.getElementById('loading');
    if (loadingElement) {
      loadingElement.style.display = 'none';
    }
  }

  public pause(): void {
    this.running = false;
  }

  public resume(): void {
    if (!this.running) {
      this.running = true;
      this.lastTime = performance.now();
      this.gameLoop();
    }
  }

  private gameLoop(): void {
    if (!this.running) return;

    const currentTime = performance.now();
    this.deltaTime = Math.min((currentTime - this.lastTime) / 1000, 1/30); // Cap at 30 FPS minimum
    this.lastTime = currentTime;

    this.update(this.deltaTime);
    this.render();

    requestAnimationFrame(() => this.gameLoop());
  }

  private update(deltaTime: number): void {
    this.gameState.gameTime += deltaTime;

    this.systems.get('economic')?.update(deltaTime);
    this.systems.get('ship')?.update(deltaTime);
    this.systems.get('ai')?.update(deltaTime);
    this.systems.get('map')?.update(deltaTime);
    this.systems.get('input')?.update(deltaTime);
    this.systems.get('ui')?.update(deltaTime);
    this.systems.get('multiplayer')?.update(deltaTime);

    // Update state synchronization if in multiplayer mode
    if (this.isMultiplayerMode && this.stateSynchronization) {
      // Update local ship positions in state sync
      this.stateSynchronization.registerLocalShips(this.gameState.player.ships);
      
      // Notify state sync of any ship updates
      this.gameState.player.ships.forEach(ship => {
        this.stateSynchronization.updateLocalShip(ship);
      });
    }

    GameStateStore.updateState(this.gameState);
  }

  private render(): void {
    this.systems.get('render')?.render();
  }

  public saveGame(): void {
    try {
      const saveData = {
        gameState: this.gameState,
        timestamp: Date.now(),
        version: '1.0.0'
      };
      
      localStorage.setItem('flexport_game_save', JSON.stringify(saveData));
    } catch (error) {
      console.error('Failed to save game:', error);
    }
  }

  public loadGame(): boolean {
    try {
      const saveData = localStorage.getItem('flexport_game_save');
      if (!saveData) return false;
      
      const parsed = JSON.parse(saveData);
      if (parsed.gameState && parsed.version === '1.0.0') {
        this.gameState = parsed.gameState;
        GameStateStore.updateState(this.gameState);
        
        this.systems.forEach(system => {
          if (system.onGameLoaded) {
            system.onGameLoaded(this.gameState);
          }
        });
        
        return true;
      }
    } catch (error) {
      console.error('Failed to load game:', error);
    }
    
    return false;
  }

  public getGameState(): GameState {
    return this.gameState;
  }

  public getApp(): PIXI.Application {
    return this.app;
  }

  public getSystem<T>(name: string): T {
    return this.systems.get(name) as T;
  }

  public waitForInitialization(): Promise<void> {
    return this.initializationPromise;
  }

  public toggleMultiplayerLobby(): void {
    if (!this.lobbyComponent) return;

    if (this.lobbyComponent.isShown()) {
      this.lobbyComponent.hide();
      this.resume();
    } else {
      this.pause();
      
      // Initialize multiplayer system if not connected
      const multiplayerSystem = this.systems.get('multiplayer');
      if (multiplayerSystem && !multiplayerSystem.getMultiplayerState().isConnected) {
        multiplayerSystem.initialize().then((connected: any) => {
          if (connected) {
            this.lobbyComponent!.show();
          } else {
            console.error('Failed to connect to multiplayer server');
            this.resume();
          }
        });
      } else {
        this.lobbyComponent.show();
      }
    }
  }

  public showHelp(): void {
    const helpText = `
      🚢 FlexPort: The Video Game - Controls

      📱 Basic Controls:
      • Drag to pan the map
      • Scroll to zoom in/out
      • Click ports for details
      • Click ships to select them

      ⌨️ Keyboard Shortcuts:
      • M - Toggle Multiplayer Lobby
      • H - Show this help
      • ESC - Close dialogs

      🎮 Multiplayer:
      • Create or join rooms
      • Play with 2-4 players
      • Real-time trading competition

      💡 Tips:
      • Build efficient trade routes
      • Watch market prices
      • Compete against AI systems
      • Survive the AI singularity!
    `;

    alert(helpText);
  }

  public isMultiplayer(): boolean {
    return this.isMultiplayerMode;
  }

  public getMultiplayerSystem(): any {
    return this.systems.get('multiplayer');
  }

  public destroy(): void {
    this.running = false;
    
    // Destroy lobby component
    if (this.lobbyComponent) {
      this.lobbyComponent.destroy();
      this.lobbyComponent = null;
    }
    
    this.systems.forEach(system => {
      if (system.destroy) {
        system.destroy();
      }
    });
    
    this.systems.clear();
    this.app.destroy(true, true);
  }
}