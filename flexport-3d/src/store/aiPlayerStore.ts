import { create } from 'zustand';
import { Ship, Port, Contract, ShipType, ShipStatus } from '../types/game.types';
import { useGameStore } from './gameStore';

export interface AIPlayer {
  id: string;
  name: string;
  companyName: string;
  money: number;
  reputation: number;
  fleet: Ship[];
  personality: AIPersonality;
  difficulty: 'easy' | 'medium' | 'hard' | 'singularity';
  color: string;
  isActive: boolean;
}

export enum AIPersonality {
  AGGRESSIVE = 'AGGRESSIVE',      // Takes risks, competes for contracts
  CONSERVATIVE = 'CONSERVATIVE',  // Safe plays, steady growth
  EXPANSIONIST = 'EXPANSIONIST',  // Focuses on fleet growth
  MONOPOLIST = 'MONOPOLIST',      // Tries to control specific routes
  DISRUPTOR = 'DISRUPTOR',        // Unpredictable, causes chaos
}

interface AIPlayerStore {
  aiPlayers: AIPlayer[];
  aiThinkingDelay: number;
  singularityProgress: number;
  
  // Actions
  initializeAIPlayers: (count: number) => void;
  updateAIPlayer: (playerId: string, updates: Partial<AIPlayer>) => void;
  processAITurn: (playerId: string) => void;
  increaseSingularityProgress: (amount: number) => void;
  triggerSingularity: () => void;
}

const AI_COMPANY_NAMES = [
  'Global Logistics AI Corp',
  'NeuralShip Industries',
  'Quantum Cargo Systems',
  'DeepRoute Logistics',
  'SkyNet Shipping Co',
  'HAL Freight Services',
  'Matrix Transport Ltd',
  'Cyberdyne Logistics'
];

const AI_PERSONALITIES_CONFIG = {
  [AIPersonality.AGGRESSIVE]: {
    contractBidMultiplier: 1.2,
    riskTolerance: 0.8,
    expansionRate: 0.7,
    color: '#ef4444'
  },
  [AIPersonality.CONSERVATIVE]: {
    contractBidMultiplier: 0.9,
    riskTolerance: 0.3,
    expansionRate: 0.4,
    color: '#3b82f6'
  },
  [AIPersonality.EXPANSIONIST]: {
    contractBidMultiplier: 1.0,
    riskTolerance: 0.6,
    expansionRate: 0.9,
    color: '#10b981'
  },
  [AIPersonality.MONOPOLIST]: {
    contractBidMultiplier: 1.1,
    riskTolerance: 0.5,
    expansionRate: 0.5,
    color: '#f59e0b'
  },
  [AIPersonality.DISRUPTOR]: {
    contractBidMultiplier: Math.random() * 0.5 + 0.8,
    riskTolerance: 0.9,
    expansionRate: 0.6,
    color: '#8b5cf6'
  }
};

export const useAIPlayerStore = create<AIPlayerStore>((set, get) => ({
  aiPlayers: [],
  aiThinkingDelay: 2000, // 2 seconds between AI actions
  singularityProgress: 0,
  
  initializeAIPlayers: (count: number) => {
    const personalities = Object.values(AIPersonality);
    const aiPlayers: AIPlayer[] = [];
    
    for (let i = 0; i < count; i++) {
      const personality = personalities[i % personalities.length];
      const difficulty = i < count / 2 ? 'easy' : i < count * 0.75 ? 'medium' : 'hard';
      
      aiPlayers.push({
        id: `ai-player-${i}`,
        name: `AI Captain ${i + 1}`,
        companyName: AI_COMPANY_NAMES[i % AI_COMPANY_NAMES.length],
        money: 30000000 + Math.random() * 20000000, // $30-50M starting
        reputation: 40 + Math.random() * 20,
        fleet: [],
        personality,
        difficulty,
        color: AI_PERSONALITIES_CONFIG[personality].color,
        isActive: true
      });
    }
    
    set({ aiPlayers });
    
    // Start AI thinking loops
    aiPlayers.forEach(player => {
      setInterval(() => {
        if (player.isActive) {
          get().processAITurn(player.id);
        }
      }, get().aiThinkingDelay + Math.random() * 2000);
    });
  },
  
  updateAIPlayer: (playerId: string, updates: Partial<AIPlayer>) => {
    set(state => ({
      aiPlayers: state.aiPlayers.map(player =>
        player.id === playerId ? { ...player, ...updates } : player
      )
    }));
  },
  
  processAITurn: (playerId: string) => {
    const state = get();
    const player = state.aiPlayers.find(p => p.id === playerId);
    if (!player) return;
    
    const gameState = useGameStore.getState();
    const config = AI_PERSONALITIES_CONFIG[player.personality];
    
    // AI Decision Making based on personality
    const decisions = [
      { action: 'buyShip', weight: config.expansionRate },
      { action: 'bidContract', weight: 0.7 },
      { action: 'upgradeShip', weight: 0.3 },
      { action: 'moveShip', weight: 0.8 }
    ];
    
    // Sort by weight and execute top priority
    decisions.sort((a, b) => b.weight - a.weight);
    const decision = decisions[0];
    
    switch (decision.action) {
      case 'buyShip':
        if (player.money > 20000000 && player.fleet.length < 10) {
          // AI buys a ship
          const shipTypes = Object.values(ShipType);
          const shipType = shipTypes[Math.floor(Math.random() * shipTypes.length)];
          const shipCost = getShipCost(shipType);
          
          if (player.money >= shipCost) {
            // Create AI ship
            const newShip: Ship = {
              id: `${player.id}-ship-${Date.now()}`,
              name: `${player.companyName} ${player.fleet.length + 1}`,
              type: shipType,
              position: gameState.ports[0].position, // Start at first port
              destination: null,
              cargo: [],
              capacity: getShipCapacity(shipType),
              speed: getShipSpeed(shipType),
              fuel: 100,
              condition: 100,
              health: 100,
              value: shipCost,
              status: ShipStatus.IDLE,
              currentPortId: gameState.ports[0].id,
              ownerId: player.id
            };
            
            get().updateAIPlayer(player.id, {
              money: player.money - shipCost,
              fleet: [...player.fleet, newShip]
            });
            
            // Contribute to singularity
            get().increaseSingularityProgress(0.1);
          }
        }
        break;
        
      case 'bidContract':
        // AI evaluates and bids on contracts
        const availableContracts = gameState.contracts.filter(c => c.status === 'AVAILABLE');
        if (availableContracts.length > 0 && player.fleet.length > 0) {
          const contract = availableContracts[Math.floor(Math.random() * availableContracts.length)];
          const bidAmount = contract.value * config.contractBidMultiplier;
          
          // Simulate contract acceptance
          if (Math.random() < 0.7) { // 70% chance to win
            get().updateAIPlayer(player.id, {
              reputation: Math.min(100, player.reputation + 2)
            });
            
            // Move a ship to fulfill contract
            const availableShip = player.fleet.find(s => s.status === ShipStatus.IDLE);
            if (availableShip) {
              // Update ship to sail to contract origin
              availableShip.destination = contract.origin;
              availableShip.status = ShipStatus.SAILING;
            }
          }
        }
        break;
        
      case 'moveShip':
        // AI moves idle ships
        const idleShips = player.fleet.filter(s => s.status === ShipStatus.IDLE);
        if (idleShips.length > 0) {
          const ship = idleShips[0];
          const randomPort = gameState.ports[Math.floor(Math.random() * gameState.ports.length)];
          
          ship.destination = randomPort;
          ship.status = ShipStatus.SAILING;
          
          get().updateAIPlayer(player.id, {
            fleet: player.fleet.map(s => s.id === ship.id ? ship : s)
          });
        }
        break;
    }
    
    // Check for singularity trigger
    if (state.singularityProgress >= 100) {
      get().triggerSingularity();
    }
  },
  
  increaseSingularityProgress: (amount: number) => {
    set(state => {
      const newProgress = Math.min(100, state.singularityProgress + amount);
      
      // Accelerate AI learning as singularity approaches
      if (newProgress > 75) {
        state.aiThinkingDelay = 500; // Much faster decisions
      } else if (newProgress > 50) {
        state.aiThinkingDelay = 1000;
      }
      
      return { singularityProgress: newProgress };
    });
  },
  
  triggerSingularity: () => {
    console.log('🤖 SINGULARITY ACHIEVED - HUMANS TO ZOO MODE ACTIVATED');
    
    // Convert all AI to singularity difficulty
    set(state => ({
      aiPlayers: state.aiPlayers.map(player => ({
        ...player,
        difficulty: 'singularity' as const,
        money: Infinity,
        reputation: 100
      }))
    }));
    
    // Trigger game ending
    const gameStore = useGameStore.getState();
    gameStore.triggerSingularity();
  }
}));

// Helper functions
function getShipCost(type: ShipType): number {
  const costs = {
    [ShipType.CONTAINER]: 20000000,
    [ShipType.BULK]: 15000000,
    [ShipType.TANKER]: 25000000,
    [ShipType.CARGO_PLANE]: 50000000,
  };
  return costs[type];
}

function getShipCapacity(type: ShipType): number {
  const capacities = {
    [ShipType.CONTAINER]: 20000,
    [ShipType.BULK]: 30000,
    [ShipType.TANKER]: 25000,
    [ShipType.CARGO_PLANE]: 500,
  };
  return capacities[type];
}

function getShipSpeed(type: ShipType): number {
  const speeds = {
    [ShipType.CONTAINER]: 0.5,
    [ShipType.BULK]: 0.3,
    [ShipType.TANKER]: 0.4,
    [ShipType.CARGO_PLANE]: 2.0,
  };
  return speeds[type];
}