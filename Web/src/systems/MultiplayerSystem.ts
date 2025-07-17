import { WebSocketManager } from '@/networking/WebSocketManager';
import { 
  GameState, 
  MultiplayerState, 
  MultiplayerPlayer, 
  GameRoom, 
  WebSocketMessage,
  GameRoomSettings
} from '@/types';

export class MultiplayerSystem {
  private gameState: GameState;
  private wsManager: WebSocketManager;
  private multiplayerState: MultiplayerState;
  private eventCallbacks: Map<string, Function[]> = new Map();
  private lastSyncTime = 0;
  private syncInterval = 5000; // Sync every 5 seconds
  private actionQueue: any[] = [];
  private isHost = false;

  constructor(gameState: GameState, wsUrl?: string) {
    this.gameState = gameState;
    this.wsManager = new WebSocketManager(wsUrl);
    this.multiplayerState = this.createInitialMultiplayerState();
    this.setupWebSocketHandlers();
    this.setupEventMap();
  }

  private createInitialMultiplayerState(): MultiplayerState {
    return {
      isConnected: false,
      connectionStatus: 'disconnected',
      availableRooms: [],
      reconnectAttempts: 0,
      maxReconnectAttempts: 5
    };
  }

  private setupEventMap(): void {
    const events = ['room_joined', 'room_left', 'player_joined', 'player_left', 'game_started', 'game_ended', 'connection_changed'];
    events.forEach(event => {
      this.eventCallbacks.set(event, []);
    });
  }

  private setupWebSocketHandlers(): void {
    // Connection status
    this.wsManager.onConnectionChange((connected) => {
      this.multiplayerState.isConnected = connected;
      this.multiplayerState.connectionStatus = connected ? 'connected' : 'disconnected';
      this.multiplayerState.reconnectAttempts = connected ? 0 : this.multiplayerState.reconnectAttempts;
      this.emit('connection_changed', { connected });
    });

    // Player join
    this.wsManager.onMessage('player_join', (message) => {
      const { player, room } = message.payload;
      this.handlePlayerJoin(player, room);
    });

    // Player leave
    this.wsManager.onMessage('player_leave', (message) => {
      const { playerId, room } = message.payload;
      this.handlePlayerLeave(playerId, room);
    });

    // Room updates
    this.wsManager.onMessage('room_update', (message) => {
      const { room } = message.payload;
      this.handleRoomUpdate(room);
    });

    // Game start
    this.wsManager.onMessage('game_start', (message) => {
      const { gameState, playerAssignments } = message.payload;
      this.handleGameStart(gameState, playerAssignments);
    });

    // Game actions from other players
    this.wsManager.onMessage('game_action', (message) => {
      const { action, data, playerId } = message.payload;
      this.handleGameAction(action, data, playerId);
    });

    // Game state synchronization
    this.wsManager.onMessage('game_state_sync', (message) => {
      const { gameState, syncId } = message.payload;
      this.handleGameStateSync(gameState, syncId);
    });

    // Room list updates
    this.wsManager.onMessage('room_list', (message) => {
      const { rooms } = message.payload;
      this.multiplayerState.availableRooms = rooms;
    });

    // Error handling
    this.wsManager.onMessage('error', (message) => {
      const { error } = message.payload;
      this.multiplayerState.lastError = error;
      console.error('Multiplayer error:', error);
    });
  }

  public async initialize(): Promise<boolean> {
    try {
      console.log('Initializing multiplayer system...');
      const connected = await this.wsManager.connect();
      
      if (connected) {
        console.log('Multiplayer system initialized successfully');
        await this.refreshRoomList();
        return true;
      } else {
        console.error('Failed to connect to multiplayer server');
        return false;
      }
    } catch (error) {
      console.error('Error initializing multiplayer system:', error);
      this.multiplayerState.lastError = error instanceof Error ? error.message : 'Unknown error';
      return false;
    }
  }

  public async createRoom(roomName: string, settings?: Partial<GameRoomSettings>): Promise<GameRoom | null> {
    try {
      const defaultSettings: GameRoomSettings = {
        maxTurns: 100,
        startingCash: 1000000,
        aiDifficulty: 1,
        enabledFeatures: ['trading', 'shipping', 'markets'],
        privateRoom: false
      };

      const roomSettings = { ...defaultSettings, ...settings };
      const room = await this.wsManager.createRoom(roomName, roomSettings);
      
      this.multiplayerState.currentRoom = room;
      this.isHost = true;
      
      // Create player for this client
      this.multiplayerState.currentPlayer = {
        id: this.wsManager.getPlayerId(),
        name: this.gameState.player.name,
        isHost: true,
        isReady: false,
        color: this.generatePlayerColor(),
        connectionStatus: 'connected',
        lastHeartbeat: Date.now()
      };

      this.emit('room_joined', { room, isHost: true });
      return room;
    } catch (error) {
      // Only log if not a timeout error to reduce console noise
      if (!error.message?.includes('timeout')) {
        console.error('Failed to create room:', error);
      }
      this.multiplayerState.lastError = error instanceof Error ? error.message : 'Failed to create room';
      return null;
    }
  }

  public async joinRoom(roomId: string, password?: string): Promise<GameRoom | null> {
    try {
      const room = await this.wsManager.joinRoom(roomId, password);
      
      this.multiplayerState.currentRoom = room;
      this.isHost = room.hostId === this.wsManager.getPlayerId();
      
      // Create player for this client
      this.multiplayerState.currentPlayer = {
        id: this.wsManager.getPlayerId(),
        name: this.gameState.player.name,
        isHost: this.isHost,
        isReady: false,
        color: this.generatePlayerColor(),
        connectionStatus: 'connected',
        lastHeartbeat: Date.now()
      };

      this.emit('room_joined', { room, isHost: this.isHost });
      return room;
    } catch (error) {
      // Only log if not a timeout error to reduce console noise
      if (!error.message?.includes('timeout')) {
        console.error('Failed to join room:', error);
      }
      this.multiplayerState.lastError = error instanceof Error ? error.message : 'Failed to join room';
      return null;
    }
  }

  public async leaveRoom(): Promise<void> {
    try {
      if (this.multiplayerState.currentRoom) {
        await this.wsManager.leaveRoom();
        const room = this.multiplayerState.currentRoom;
        this.multiplayerState.currentRoom = undefined;
        this.multiplayerState.currentPlayer = undefined;
        this.isHost = false;
        this.emit('room_left', { room });
      }
    } catch (error) {
      console.error('Failed to leave room:', error);
    }
  }

  public async setReady(isReady: boolean): Promise<void> {
    try {
      if (this.multiplayerState.currentPlayer) {
        await this.wsManager.setReady(isReady);
        this.multiplayerState.currentPlayer.isReady = isReady;
      }
    } catch (error) {
      console.error('Failed to set ready status:', error);
    }
  }

  public async refreshRoomList(): Promise<GameRoom[]> {
    try {
      const rooms = await this.wsManager.getRoomList();
      this.multiplayerState.availableRooms = rooms;
      return rooms;
    } catch (error) {
      // Only log if not a timeout error to reduce console noise
      if (!error.message?.includes('timeout')) {
        console.error('Failed to refresh room list:', error);
      }
      return this.multiplayerState.availableRooms;
    }
  }

  public async startGame(): Promise<void> {
    try {
      if (this.multiplayerState.currentRoom && this.isHost) {
        await this.wsManager.sendMessage('start_game', {
          roomId: this.multiplayerState.currentRoom.id
        }, this.multiplayerState.currentRoom.id);
      }
    } catch (error) {
      console.error('Failed to start game:', error);
    }
  }

  public async sendGameAction(action: string, data: any): Promise<void> {
    try {
      if (this.multiplayerState.currentRoom) {
        await this.wsManager.sendMessage('game_action', {
          action,
          data,
          playerId: this.wsManager.getPlayerId()
        }, this.multiplayerState.currentRoom.id);
      }
    } catch (error) {
      console.error('Failed to send game action:', error);
      // Queue action for retry
      this.actionQueue.push({ action, data, timestamp: Date.now() });
    }
  }

  public update(_deltaTime: number): void {
    // Sync game state periodically if we're the host
    if (this.isHost && this.multiplayerState.currentRoom?.status === 'in_progress') {
      const now = Date.now();
      if (now - this.lastSyncTime > this.syncInterval) {
        this.syncGameState();
        this.lastSyncTime = now;
      }
    }

    // Retry queued actions
    if (this.actionQueue.length > 0 && this.wsManager.isConnected()) {
      const actions = [...this.actionQueue];
      this.actionQueue = [];
      
      actions.forEach(({ action, data }) => {
        this.sendGameAction(action, data);
      });
    }

    // Update player heartbeat
    if (this.multiplayerState.currentPlayer) {
      this.multiplayerState.currentPlayer.lastHeartbeat = Date.now();
    }
  }

  private async syncGameState(): Promise<void> {
    if (!this.multiplayerState.currentRoom) return;

    try {
      const syncData = {
        gameTime: this.gameState.gameTime,
        turn: this.gameState.turn,
        markets: this.gameState.markets,
        world: {
          economicEvents: this.gameState.world.economicEvents,
          geopoliticalEvents: this.gameState.world.geopoliticalEvents,
          weatherEvents: this.gameState.world.weatherEvents
        },
        aiCompetitors: this.gameState.aiCompetitors,
        singularityProgress: this.gameState.singularityProgress
      };

      await this.wsManager.sendMessage('game_state_sync', {
        gameState: syncData,
        syncId: Date.now().toString()
      }, this.multiplayerState.currentRoom.id);
    } catch (error) {
      console.error('Failed to sync game state:', error);
    }
  }

  private handlePlayerJoin(player: MultiplayerPlayer, room: GameRoom): void {
    this.multiplayerState.currentRoom = room;
    this.emit('player_joined', { player, room });
  }

  private handlePlayerLeave(playerId: string, room: GameRoom): void {
    this.multiplayerState.currentRoom = room;
    this.emit('player_left', { playerId, room });
  }

  private handleRoomUpdate(room: GameRoom): void {
    this.multiplayerState.currentRoom = room;
    
    // Update our player info from the room
    const ourPlayer = room.players.find(p => p.id === this.wsManager.getPlayerId());
    if (ourPlayer) {
      this.multiplayerState.currentPlayer = ourPlayer;
      this.isHost = ourPlayer.isHost;
    }
  }

  private handleGameStart(gameState: GameState, playerAssignments: Record<string, string>): void {
    // Update local game state with multiplayer game state
    Object.assign(this.gameState, gameState);
    
    // Assign player specific data
    const playerId = this.wsManager.getPlayerId();
    if (playerAssignments[playerId]) {
      this.gameState.player.id = playerAssignments[playerId];
    }

    if (this.multiplayerState.currentRoom) {
      this.multiplayerState.currentRoom.status = 'in_progress';
    }

    this.emit('game_started', { gameState, playerAssignments });
  }

  private handleGameAction(action: string, data: any, playerId: string): void {
    // Don't process our own actions
    if (playerId === this.wsManager.getPlayerId()) return;

    console.log(`Received game action from ${playerId}:`, action, data);
    
    // Apply the action to our local game state
    this.applyGameAction(action, data, playerId);
  }

  private handleGameStateSync(gameState: Partial<GameState>, syncId: string): void {
    // Only non-hosts should apply synced state
    if (this.isHost) return;

    console.log('Applying synced game state:', syncId);
    
    // Merge synced state with local state
    Object.assign(this.gameState, gameState);
  }

  private applyGameAction(action: string, data: any, playerId: string): void {
    // This would contain the logic for applying different types of game actions
    // For now, we'll just emit an event for other systems to handle
    this.emit('game_action_received', { action, data, playerId });
  }

  private generatePlayerColor(): string {
    const colors = [
      '#3b82f6', // Blue
      '#ef4444', // Red  
      '#10b981', // Green
      '#f59e0b', // Yellow
      '#8b5cf6', // Purple
      '#06b6d4', // Cyan
      '#f97316', // Orange
      '#ec4899'  // Pink
    ];
    
    const usedColors = this.multiplayerState.currentRoom?.players.map(p => p.color) || [];
    const availableColors = colors.filter(color => !usedColors.includes(color));
    
    return availableColors.length > 0 ? availableColors[0] : colors[0];
  }

  // Event system
  public on(event: string, callback: Function): () => void {
    if (!this.eventCallbacks.has(event)) {
      this.eventCallbacks.set(event, []);
    }
    
    this.eventCallbacks.get(event)!.push(callback);
    
    // Return unsubscribe function
    return () => {
      const callbacks = this.eventCallbacks.get(event);
      if (callbacks) {
        const index = callbacks.indexOf(callback);
        if (index > -1) {
          callbacks.splice(index, 1);
        }
      }
    };
  }

  private emit(event: string, data: any): void {
    const callbacks = this.eventCallbacks.get(event);
    if (callbacks) {
      callbacks.forEach(callback => {
        try {
          callback(data);
        } catch (error) {
          console.error(`Error in event callback for ${event}:`, error);
        }
      });
    }
  }

  // Getters
  public getMultiplayerState(): MultiplayerState {
    return this.multiplayerState;
  }

  public getCurrentRoom(): GameRoom | undefined {
    return this.multiplayerState.currentRoom;
  }

  public getCurrentPlayer(): MultiplayerPlayer | undefined {
    return this.multiplayerState.currentPlayer;
  }

  public isInRoom(): boolean {
    return !!this.multiplayerState.currentRoom;
  }

  public isGameHost(): boolean {
    return this.isHost;
  }

  public getConnectionStats(): any {
    return this.wsManager.getConnectionStats();
  }

  public destroy(): void {
    this.wsManager.disconnect();
    this.eventCallbacks.clear();
    this.actionQueue = [];
  }
}