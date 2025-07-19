import { io, Socket } from 'socket.io-client';

export interface Player {
  id: string;
  name: string;
  isAI: boolean;
  avatar: string;
  rating: number;
  status: 'ready' | 'waiting';
  stats: {
    gamesPlayed: number;
    winRate: number;
    avgProfit: number;
  };
}

export interface GameSettings {
  startingCapital: number;
  gameDuration: string;
  mapSize: string;
  difficulty: string;
  maxPlayers: number;
}

export interface Room {
  code: string;
  players: Player[];
  host: string;
  settings: GameSettings;
  state: 'waiting' | 'starting' | 'playing';
}

export interface ChatMessage {
  id: number;
  playerId: string;
  playerName: string;
  message: string;
  timestamp: Date;
}

class MultiplayerService {
  private socket: Socket | null = null;
  private serverUrl: string;
  private currentRoom: Room | null = null;
  private eventHandlers: Map<string, Function[]> = new Map();

  constructor() {
    // Use local server in development, production server in production
    if (process.env.NODE_ENV === 'production') {
      // Use the custom server URL if provided
      const customUrl = process.env.REACT_APP_MULTIPLAYER_SERVER_URL;
      if (customUrl) {
        this.serverUrl = customUrl;
      } else {
        // Use secure domain with SSL
        this.serverUrl = 'https://flexportglobal.engindearing.soy';
      }
    } else {
      this.serverUrl = 'http://localhost:3001';
    }
  }

  connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      if (this.socket?.connected) {
        resolve();
        return;
      }

      // Check if multiplayer is disabled (HTTPS without SSL)
      if (!this.serverUrl) {
        reject(new Error('Multiplayer is disabled on HTTPS. Please access the game via HTTP or configure SSL.'));
        return;
      }

      this.socket = io(this.serverUrl, {
        transports: ['websocket', 'polling'],
      });

      this.socket.on('connect', () => {
        console.log('Connected to multiplayer server');
        resolve();
      });

      this.socket.on('connect_error', (error) => {
        console.error('Connection error:', error);
        reject(error);
      });

      // Set up event listeners
      this.setupEventListeners();
    });
  }

  private setupEventListeners() {
    if (!this.socket) return;

    // Room events
    this.socket.on('room-created', (data) => {
      this.currentRoom = data.room;
      this.emit('room-created', data);
    });

    this.socket.on('player-joined', (data) => {
      this.currentRoom = data.room;
      this.emit('player-joined', data);
    });

    this.socket.on('player-left', (data) => {
      this.currentRoom = data.room;
      this.emit('player-left', data);
    });

    this.socket.on('player-status-updated', (data) => {
      this.currentRoom = data.room;
      this.emit('player-status-updated', data);
    });

    this.socket.on('ai-player-added', (data) => {
      this.currentRoom = data.room;
      this.emit('ai-player-added', data);
    });

    this.socket.on('ai-player-removed', (data) => {
      this.currentRoom = data.room;
      this.emit('ai-player-removed', data);
    });

    this.socket.on('room-filled-with-ai', (data) => {
      this.currentRoom = data.room;
      this.emit('room-filled-with-ai', data);
    });

    this.socket.on('settings-updated', (data) => {
      if (this.currentRoom) {
        this.currentRoom.settings = data.settings;
      }
      this.emit('settings-updated', data);
    });

    this.socket.on('chat-message', (data) => {
      this.emit('chat-message', data);
    });

    this.socket.on('game-starting', (data) => {
      this.emit('game-starting', data);
    });

    this.socket.on('game-started', (data) => {
      this.emit('game-started', data);
    });

    this.socket.on('error', (data) => {
      this.emit('error', data);
    });
  }

  // Event handling
  on(event: string, handler: Function) {
    if (!this.eventHandlers.has(event)) {
      this.eventHandlers.set(event, []);
    }
    this.eventHandlers.get(event)!.push(handler);
  }

  off(event: string, handler: Function) {
    const handlers = this.eventHandlers.get(event);
    if (handlers) {
      const index = handlers.indexOf(handler);
      if (index > -1) {
        handlers.splice(index, 1);
      }
    }
  }

  private emit(event: string, data: any) {
    const handlers = this.eventHandlers.get(event);
    if (handlers) {
      handlers.forEach(handler => handler(data));
    }
  }

  // Room actions
  async createRoom(playerData: Omit<Player, 'id' | 'isAI' | 'status'>): Promise<void> {
    if (!this.socket) throw new Error('Not connected to server');
    this.socket.emit('create-room', playerData);
  }

  async joinRoom(roomCode: string, playerData: Omit<Player, 'id' | 'isAI' | 'status'>): Promise<void> {
    if (!this.socket) throw new Error('Not connected to server');
    this.socket.emit('join-room', { roomCode, playerData });
  }

  updateStatus(status: 'ready' | 'waiting') {
    if (!this.socket) throw new Error('Not connected to server');
    this.socket.emit('update-status', status);
  }

  addAIPlayer() {
    if (!this.socket) throw new Error('Not connected to server');
    this.socket.emit('add-ai-player');
  }

  removeAIPlayer(aiId: string) {
    if (!this.socket) throw new Error('Not connected to server');
    this.socket.emit('remove-ai-player', aiId);
  }

  fillWithAI() {
    if (!this.socket) throw new Error('Not connected to server');
    this.socket.emit('fill-with-ai');
  }

  updateSettings(settings: Partial<GameSettings>) {
    if (!this.socket) throw new Error('Not connected to server');
    this.socket.emit('update-settings', settings);
  }

  sendChatMessage(message: string) {
    if (!this.socket) throw new Error('Not connected to server');
    this.socket.emit('chat-message', message);
  }

  startGame() {
    if (!this.socket) throw new Error('Not connected to server');
    this.socket.emit('start-game');
  }

  disconnect() {
    if (this.socket) {
      this.socket.disconnect();
      this.socket = null;
      this.currentRoom = null;
    }
  }

  getCurrentRoom(): Room | null {
    return this.currentRoom;
  }

  isConnected(): boolean {
    return this.socket?.connected || false;
  }

  isHost(): boolean {
    return this.currentRoom?.host === this.socket?.id;
  }
}

export const multiplayerService = new MultiplayerService();