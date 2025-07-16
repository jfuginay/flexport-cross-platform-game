import { create } from 'zustand';
import { GameState, PlayerState, WorldState, Market, MarketType, AICompetitor, SingularityState, MultiplayerState } from '@/types';
import { PortData } from '@/utils/PortData';

interface GameStore extends GameState {
  updatePlayer: (updates: Partial<PlayerState>) => void;
  updateMarket: (type: MarketType, updates: Partial<Market>) => void;
  addAICompetitor: (competitor: AICompetitor) => void;
  updateSingularity: (updates: Partial<SingularityState>) => void;
  updateMultiplayer: (updates: Partial<MultiplayerState>) => void;
  reset: () => void;
}

const createInitialMarket = (type: MarketType): Market => ({
  type,
  prices: {},
  trends: {},
  volatility: {},
  volume: {},
});

const getInitialState = (): GameState => ({
  player: {
    id: 'player-1',
    name: 'Captain Logistics',
    cash: 1000000,
    reputation: 50,
    level: 1,
    experience: 0,
    ships: [],
    ports: [],
    tradeRoutes: [],
    research: {
      navigation: 0,
      efficiency: 0,
      automation: 0,
      intelligence: 0,
      ai: 0,
      availablePoints: 0,
    },
    achievements: [],
  },
  world: {
    ports: PortData.getAllPorts(),
    tradeRoutes: [],
    economicEvents: [],
    geopoliticalEvents: [],
    weatherEvents: [],
  },
  markets: {
    goods: createInitialMarket('goods'),
    capital: createInitialMarket('capital'),
    assets: createInitialMarket('assets'),
    labor: createInitialMarket('labor'),
  },
  aiCompetitors: [
    {
      id: 'ai-1',
      name: 'LogiCorp AI',
      personality: 'aggressive',
      efficiency: 0.8,
      marketShare: 0.15,
      ships: 5,
      singularityContribution: 0.1,
      phase: 'early_automation',
    },
    {
      id: 'ai-2',
      name: 'TradeMind Systems',
      personality: 'analytical',
      efficiency: 0.85,
      marketShare: 0.12,
      ships: 4,
      singularityContribution: 0.12,
      phase: 'early_automation',
    },
    {
      id: 'ai-3',
      name: 'FlowOptima',
      personality: 'efficient',
      efficiency: 0.75,
      marketShare: 0.10,
      ships: 3,
      singularityContribution: 0.08,
      phase: 'early_automation',
    },
  ],
  singularityProgress: {
    phase: 'early_automation',
    progress: 0,
    aiEfficiencyBonus: 0,
    marketManipulation: 0,
    playerWarning: 'AI systems are beginning to optimize trade routes automatically.',
    timeRemaining: 72000, // 20 hours in seconds
  },
  multiplayer: {
    isConnected: false,
    connectionStatus: 'disconnected',
    availableRooms: [],
    reconnectAttempts: 0,
    maxReconnectAttempts: 5
  },
  gameTime: 0,
  turn: 1,
});

export const useGameStore = create<GameStore>((set, get) => ({
  ...getInitialState(),

  updatePlayer: (updates) =>
    set((state) => ({
      player: { ...state.player, ...updates },
    })),

  updateMarket: (type, updates) =>
    set((state) => ({
      markets: {
        ...state.markets,
        [type]: { ...state.markets[type], ...updates },
      },
    })),

  addAICompetitor: (competitor) =>
    set((state) => ({
      aiCompetitors: [...state.aiCompetitors, competitor],
    })),

  updateSingularity: (updates) =>
    set((state) => ({
      singularityProgress: { ...state.singularityProgress, ...updates },
    })),

  updateMultiplayer: (updates) =>
    set((state) => ({
      multiplayer: { ...state.multiplayer, ...updates },
    })),

  reset: () => set(getInitialState()),
}));

export const GameStateStore = {
  getInitialState,
  updateState: (newState: GameState) => {
    useGameStore.setState(newState);
  },
};