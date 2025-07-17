export interface Vector2 {
  x: number;
  y: number;
}

export interface Coordinates {
  latitude: number;
  longitude: number;
}

export type ShipType = 'bulk_carrier' | 'container_ship' | 'tanker' | 'general_cargo' | 'roro' | 'refrigerated' | 'heavy_lift';
export type ShipStatus = 'docked' | 'departing' | 'traveling' | 'arriving' | 'loading' | 'unloading';
export type MarketType = 'goods' | 'capital' | 'assets' | 'labor';
export type CommodityType = 'steel' | 'oil' | 'grain' | 'electronics' | 'textiles' | 'chemicals' | 'machinery' | 'coal';

export interface Ship {
  id: string;
  name: string;
  type: ShipType;
  capacity: number;
  speed: number;
  efficiency: number;
  maintenanceCost: number;
  currentLocation: Coordinates;
  destination?: string;
  status: ShipStatus;
  cargo: Cargo[];
  crew: CrewMember[];
  fuel: number;
  condition: number;
}

export interface CrewMember {
  id: string;
  name: string;
  role: string;
  skill: number;
  morale: number;
  experience: number;
}

export interface Cargo {
  type: CommodityType;
  quantity: number;
  value: number;
  destination: string;
}

export interface Port {
  id: string;
  name: string;
  coordinates: Coordinates;
  country: string;
  size: 'small' | 'medium' | 'large' | 'mega';
  facilities: string[];
  demandData: Record<CommodityType, number>;
  supplyData: Record<CommodityType, number>;
  dockingFees: number;
}

export interface TradeRoute {
  id: string;
  origin: string;
  destination: string;
  ships: string[];
  cargo: CommodityType[];
  frequency: number;
  profitability: number;
  distance: number;
  travelTime: number;
}

export interface Market {
  type: MarketType;
  prices: Record<string, number>;
  trends: Record<string, number>;
  volatility: Record<string, number>;
  volume: Record<string, number>;
}

export interface GameState {
  player: PlayerState;
  world: WorldState;
  markets: Record<MarketType, Market>;
  aiCompetitors: AICompetitor[];
  singularityProgress: SingularityState;
  multiplayer: MultiplayerState;
  gameTime: number;
  turn: number;
}

export interface PlayerState {
  id: string;
  name: string;
  cash: number;
  reputation: number;
  level: number;
  experience: number;
  ships: Ship[];
  ports: Port[];
  tradeRoutes: TradeRoute[];
  research: ResearchState;
  achievements: Achievement[];
}

export interface WorldState {
  ports: Port[];
  tradeRoutes: TradeRoute[];
  economicEvents: EconomicEvent[];
  geopoliticalEvents: GeopoliticalEvent[];
  weatherEvents: WeatherEvent[];
}

export interface AICompetitor {
  id: string;
  name: string;
  personality: string;
  efficiency: number;
  marketShare: number;
  ships: number;
  singularityContribution: number;
  phase: SingularityPhase;
}

export type SingularityPhase = 
  | 'early_automation'
  | 'pattern_mastery'
  | 'predictive_dominance'
  | 'strategic_supremacy'
  | 'market_control'
  | 'recursive_acceleration'
  | 'consciousness_emergence'
  | 'the_singularity';

export interface SingularityState {
  phase: SingularityPhase;
  progress: number;
  aiEfficiencyBonus: number;
  marketManipulation: number;
  playerWarning: string;
  timeRemaining: number;
}

export interface ResearchState {
  navigation: number;
  efficiency: number;
  automation: number;
  intelligence: number;
  ai: number;
  availablePoints: number;
}

export interface Achievement {
  id: string;
  name: string;
  description: string;
  unlocked: boolean;
  progress: number;
  maxProgress: number;
}

export interface EconomicEvent {
  id: string;
  type: string;
  title: string;
  description: string;
  effects: Record<string, number>;
  duration: number;
  severity: number;
}

export interface GeopoliticalEvent {
  id: string;
  type: string;
  title: string;
  description: string;
  affectedRegions: string[];
  tradeImpact: number;
  duration: number;
}

export interface WeatherEvent {
  id: string;
  type: string;
  location: Coordinates;
  radius: number;
  severity: number;
  duration: number;
  effects: string[];
}

export interface GameConfig {
  targetFPS: number;
  maxShips: number;
  startingCash: number;
  difficultyLevel: number;
  mapBounds: {
    minLat: number;
    maxLat: number;
    minLng: number;
    maxLng: number;
  };
}

// Multiplayer Types
export interface MultiplayerPlayer {
  id: string;
  name: string;
  isHost: boolean;
  isReady: boolean;
  color: string;
  connectionStatus: 'connected' | 'disconnected' | 'reconnecting';
  lastHeartbeat: number;
}

export interface GameRoom {
  id: string;
  name: string;
  hostId: string;
  players: MultiplayerPlayer[];
  maxPlayers: number;
  status: 'waiting' | 'starting' | 'in_progress' | 'finished';
  gameMode: 'competitive' | 'cooperative' | 'sandbox';
  settings: GameRoomSettings;
  createdAt: number;
  startedAt?: number;
}

export interface GameRoomSettings {
  maxTurns: number;
  startingCash: number;
  aiDifficulty: number;
  enabledFeatures: string[];
  turnTimeLimit?: number;
  privateRoom: boolean;
  password?: string;
}

export interface MultiplayerState {
  isConnected: boolean;
  connectionStatus: 'disconnected' | 'connecting' | 'connected' | 'error';
  currentRoom?: GameRoom;
  currentPlayer?: MultiplayerPlayer;
  availableRooms: GameRoom[];
  lastError?: string;
  reconnectAttempts: number;
  maxReconnectAttempts: number;
}

// WebSocket Message Types
export type MessageType = 
  | 'player_join'
  | 'player_leave' 
  | 'player_ready'
  | 'room_update'
  | 'game_start'
  | 'game_action'
  | 'game_state_sync'
  | 'heartbeat'
  | 'error'
  | 'room_list'
  | 'create_room'
  | 'join_room'
  | 'leave_room'
  | 'ship_update'
  | 'ship_batch_update'
  | 'ship_full_sync'
  | 'ship_reconciliation';

export interface WebSocketMessage {
  type: MessageType;
  payload: any;
  playerId?: string;
  roomId?: string;
  timestamp: number;
  messageId: string;
}

export interface PlayerJoinMessage {
  type: 'player_join';
  payload: {
    player: MultiplayerPlayer;
    room: GameRoom;
  };
}

export interface PlayerLeaveMessage {
  type: 'player_leave';
  payload: {
    playerId: string;
    room: GameRoom;
  };
}

export interface PlayerReadyMessage {
  type: 'player_ready';
  payload: {
    playerId: string;
    isReady: boolean;
  };
}

export interface RoomUpdateMessage {
  type: 'room_update';
  payload: {
    room: GameRoom;
  };
}

export interface GameStartMessage {
  type: 'game_start';
  payload: {
    gameState: GameState;
    playerAssignments: Record<string, string>;
  };
}

export interface GameActionMessage {
  type: 'game_action';
  payload: {
    action: string;
    data: any;
    playerId: string;
  };
}

export interface GameStateSyncMessage {
  type: 'game_state_sync';
  payload: {
    gameState: Partial<GameState>;
    syncId: string;
  };
}