import { create } from 'zustand';
import * as THREE from 'three';
import { GameState, Ship, Port, Contract, Container, ShipType, ShipStatus, ContractStatus, CargoType, GameMode, AICompetitor, GameResult } from '../types/game.types';
import { generateEnhancedContracts, generateDynamicContract } from '../utils/contractGenerator';
import { getPortPosition, realPortLocations, calculateDistance, interpolateRoute } from '../utils/geoUtils';
import { isShipOverWater, getWaterRouteBetweenPorts, getNearestWaterPoint } from '../utils/routeValidation';
import { generatePortsFromWorldData } from '../utils/worldPortsConverter';

interface GameStore extends GameState {
  // Selection state
  selectedShipId: string | null;
  selectedPortId: string | null;
  
  // Actions
  startGame: (mode: GameMode) => void;
  startMultiplayerGame: (settings: any) => void;
  pauseGame: () => void;
  resumeGame: () => void;
  setGameSpeed: (speed: number) => void;
  endGame: (result: GameResult) => void;
  
  // Selection actions
  selectShip: (shipId: string | null) => void;
  selectPort: (portId: string | null) => void;
  
  // Money actions
  spendMoney: (amount: number) => boolean;
  addMoney: (amount: number) => void;
  
  // Fleet actions
  purchaseShip: (type: ShipType, name: string) => void;
  addFreeShip: (type: ShipType, name: string) => void;
  moveShip: (shipId: string, destination: Port) => void;
  sendShipToPort: (shipId: string, portId: string) => void;
  repairShip: (shipId: string) => void;
  upgradeShip: (shipId: string) => void;
  sellShip: (shipId: string) => void;
  
  // Contract actions
  acceptContract: (contractId: string) => void;
  completeContract: (contractId: string) => void;
  assignShipToContract: (shipId: string, contractId: string) => void;
  assignContractToShip: (contractId: string, shipId: string) => void;
  
  // Cargo actions
  loadCargo: (shipId: string, contractId: string) => void;
  unloadCargo: (shipId: string) => void;
  
  // AI actions
  incrementAI: (amount: number) => void;
  triggerSingularity: () => void;
  updateAICompetitors: (deltaTime: number) => void;
  calculateEfficiency: (isPlayer: boolean, competitorId?: string) => number;
  
  // Game loop
  updateGame: (deltaTime: number) => void;
  generateNewContract: () => void;
}

const INITIAL_STATE: GameState = {
  money: 50000000, // $50M starting capital
  reputation: 50,
  companyName: 'FlexPort Global',
  isPaused: false,
  gameSpeed: 1,
  currentDate: new Date(2024, 0, 1),
  fleet: [],
  ports: [],
  contracts: [],
  aiDevelopmentLevel: 0,
  isSingularityActive: false,
  aiCompetitors: [],
  playerEfficiency: 25, // Start at 25% efficiency, similar to AI
  gameMode: undefined,
  gameStartTime: undefined,
  gameDuration: undefined,
  gameResult: undefined,
};

export const useGameStore = create<GameStore>((set, get) => ({
  ...INITIAL_STATE,
  selectedShipId: null,
  selectedPortId: null,
  
  selectShip: (shipId) => set({ selectedShipId: shipId, selectedPortId: null }),
  selectPort: (portId) => set({ selectedPortId: portId, selectedShipId: null }),
  
  startGame: (mode: GameMode) => {
    const gameConfig = getGameModeConfig(mode);
    
    set({ 
      ...INITIAL_STATE,
      gameMode: mode,
      gameStartTime: Date.now(),
      gameDuration: gameConfig.duration,
      money: gameConfig.startingMoney,
      gameSpeed: gameConfig.initialSpeed,
    });
    
    // Generate initial world
    const ports = generateInitialPorts();
    const contracts = generateEnhancedContracts(ports, gameConfig.initialContracts);
    
    // Create AI competitors
    const aiCompetitors = generateAICompetitors(gameConfig.aiCount);
    
    // Create an initial ship for the player
    const homePort = ports[0]; // LA port
    const playerShip: Ship = {
      id: 'player-ship-1',
      name: 'SS FlexPort One',
      type: ShipType.CONTAINER,
      position: { ...homePort.position },
      destination: null,
      cargo: [],
      capacity: getShipCapacity(ShipType.CONTAINER),
      speed: getShipSpeed(ShipType.CONTAINER),
      fuel: 100,
      condition: 100,
      health: 100,
      value: getShipValue(ShipType.CONTAINER),
      status: ShipStatus.IDLE,
      currentPortId: homePort.id,
      ownerId: 'player',
    };
    
    // Create initial AI ships
    const aiShips = aiCompetitors.map((ai, index) => {
      const aiPort = ports[index + 1] || ports[0];
      return {
        id: `ai-ship-${ai.id}`,
        name: `${ai.name} Vessel`,
        type: ShipType.CONTAINER,
        position: { ...aiPort.position },
        destination: null,
        cargo: [],
        capacity: getShipCapacity(ShipType.CONTAINER),
        speed: getShipSpeed(ShipType.CONTAINER),
        fuel: 100,
        condition: 100,
        health: 100,
        value: getShipValue(ShipType.CONTAINER),
        status: ShipStatus.IDLE,
        currentPortId: aiPort.id,
        ownerId: ai.id,
      } as Ship;
    });
    
    set({ 
      ports, 
      contracts, 
      fleet: [playerShip, ...aiShips],
      aiCompetitors 
    });
  },
  
  startMultiplayerGame: (settings) => {
    console.log('Starting multiplayer game with settings:', settings);
    
    // Convert multiplayer settings to game config
    const gameDurationMinutes = parseInt(settings.gameDuration) || 30;
    const startingMoney = settings.startingCapital || 50000000;
    const aiCount = settings.maxPlayers ? settings.maxPlayers - 1 : 7; // AI fills remaining slots
    
    // Don't reset ports/fleet/contracts yet - we'll set them below
    const { ports: _, fleet: __, contracts: ___, ...resetState } = INITIAL_STATE;
    
    set({ 
      ...resetState,
      gameMode: GameMode.CAMPAIGN, // Use campaign mode for multiplayer
      gameStartTime: Date.now(),
      gameDuration: gameDurationMinutes * 60 * 1000,
      money: startingMoney,
      gameSpeed: 1,
    });
    
    // Generate initial world
    const ports = generateInitialPorts();
    console.log('Generated ports:', ports.length);
    const contracts = generateEnhancedContracts(ports, 20); // More contracts for multiplayer
    
    // Create AI competitors based on difficulty
    const aiCompetitors = generateAICompetitors(aiCount);
    
    // Create an initial ship for the player
    const homePort = ports[0]; // LA port
    const playerShip: Ship = {
      id: 'player-ship-1',
      name: 'SS FlexPort One',
      type: ShipType.CONTAINER,
      position: { ...homePort.position },
      destination: null,
      cargo: [],
      capacity: getShipCapacity(ShipType.CONTAINER),
      speed: getShipSpeed(ShipType.CONTAINER),
      fuel: 100,
      condition: 100,
      health: 100,
      value: getShipValue(ShipType.CONTAINER),
      status: ShipStatus.IDLE,
      currentPortId: homePort.id,
      ownerId: 'player',
    };
    
    // Create initial AI ships
    const aiShips = aiCompetitors.map((ai, index) => {
      const aiPort = ports[index + 1] || ports[0];
      return {
        id: `ai-ship-${ai.id}`,
        name: `${ai.name} Vessel`,
        type: ShipType.CONTAINER,
        position: { ...aiPort.position },
        destination: null,
        cargo: [],
        capacity: getShipCapacity(ShipType.CONTAINER),
        speed: getShipSpeed(ShipType.CONTAINER),
        fuel: 100,
        condition: 100,
        health: 100,
        value: getShipValue(ShipType.CONTAINER),
        status: ShipStatus.IDLE,
        currentPortId: aiPort.id,
        ownerId: ai.id,
      } as Ship;
    });
    
    set({ 
      ports, 
      contracts, 
      fleet: [playerShip, ...aiShips],
      aiCompetitors,
      currentDate: new Date(),
    });
    
    console.log('Multiplayer game initialized:', {
      ports: ports.length,
      contracts: contracts.length,
      fleet: [playerShip, ...aiShips].length,
      aiCompetitors: aiCompetitors.length
    });
  },
  
  pauseGame: () => set({ isPaused: true }),
  resumeGame: () => set({ isPaused: false }),
  setGameSpeed: (speed) => set({ gameSpeed: speed }),
  
  spendMoney: (amount) => {
    const state = get();
    if (state.money >= amount) {
      set({ money: state.money - amount });
      return true;
    }
    return false;
  },
  
  addMoney: (amount) => {
    const state = get();
    set({ money: state.money + amount });
  },
  
  purchaseShip: (type, name) => {
    const cost = getShipCost(type);
    console.log('Attempting to purchase ship:', { type, name, cost });
    
    if (get().spendMoney(cost)) {
      const ports = get().ports;
      console.log('Available ports:', ports.length);
      
      if (!ports || ports.length === 0) {
        console.error('No ports available to spawn ship');
        // Refund the money
        get().addMoney(cost);
        return;
      }
      
      const homePort = ports.find(p => p.isPlayerOwned) || ports[0];
      if (!homePort) {
        console.error('No valid home port found');
        // Refund the money
        get().addMoney(cost);
        return;
      }
      
      // Ship spawns at port position (port positions are already elevated)
      const spawnPosition = { ...homePort.position };
      
      const newShip: Ship = {
        id: `ship-${Date.now()}`,
        name,
        type,
        position: spawnPosition,
        destination: null,
        cargo: [],
        capacity: getShipCapacity(type),
        speed: getShipSpeed(type),
        fuel: 100,
        condition: 100,
        health: 100,
        value: getShipValue(type),
        status: ShipStatus.IDLE,
        currentPortId: homePort.id,
      };
      
      console.log(`New ship "${name}" spawned at port "${homePort.name}"`, {
        portPosition: homePort.position,
        shipPosition: spawnPosition
      });
      
      set(state => ({ fleet: [...state.fleet, newShip] }));
    }
  },
  
  addFreeShip: (type, name) => {
    const ports = get().ports;
    if (!ports || ports.length === 0) {
      console.error('No ports available to spawn free ship');
      return;
    }
    
    const homePort = ports.find(p => p.isPlayerOwned) || ports[0];
    if (!homePort) {
      console.error('No valid home port found for free ship');
      return;
    }
    
    const spawnPosition = { ...homePort.position };
    
    const newShip: Ship = {
      id: `ship-${Date.now()}`,
      name,
      type,
      position: spawnPosition,
      destination: null,
      cargo: [],
      capacity: getShipCapacity(type),
      speed: getShipSpeed(type),
      fuel: 100,
      condition: 100,
      health: 100,
      value: getShipValue(type),
      status: ShipStatus.IDLE,
      currentPortId: homePort.id,
    };
    
    console.log(`Free ship "${name}" added at port "${homePort.name}"`);
    set(state => ({ fleet: [...state.fleet, newShip] }));
  },
  
  moveShip: (shipId, destination) => {
    const state = get();
    const ship = state.fleet.find(s => s.id === shipId);
    
    console.log(`moveShip called:`, {
      shipId,
      shipFound: !!ship,
      shipStatus: ship?.status,
      shipName: ship?.name,
      destinationName: destination?.name
    });
    
    if (ship) {
      // Calculate water route for ships (not planes)
      if (ship.type !== ShipType.CARGO_PLANE) {
        const startPos = new THREE.Vector3(ship.position.x, ship.position.y, ship.position.z);
        const endPos = new THREE.Vector3(destination.position.x, destination.position.y, destination.position.z);
        const waypoints = getWaterRouteBetweenPorts(startPos, endPos, 100);
        
        console.log(`Setting ship ${ship.name} to SAILING with ${waypoints.length} waypoints`);
        
        set(state => ({
          fleet: state.fleet.map(s =>
            s.id === shipId
              ? { ...s, destination, status: ShipStatus.SAILING, routeProgress: 0, waypoints } as any
              : s
          ),
        }));
      } else {
        // Planes can fly direct routes
        console.log(`Setting plane ${ship.name} to SAILING (direct route)`);
        
        set(state => ({
          fleet: state.fleet.map(s =>
            s.id === shipId
              ? { ...s, destination, status: ShipStatus.SAILING, routeProgress: 0 } as any
              : s
          ),
        }));
      }
    }
  },
  
  acceptContract: (contractId) => {
    set(state => ({
      contracts: state.contracts.map(contract =>
        contract.id === contractId
          ? { ...contract, status: ContractStatus.ACTIVE }
          : contract
      ),
    }));
  },
  
  assignShipToContract: (shipId, contractId) => {
    const state = get();
    const ship = state.fleet.find(s => s.id === shipId);
    const contract = state.contracts.find(c => c.id === contractId);
    
    console.log(`assignShipToContract called:`, { 
      shipId, 
      contractId, 
      shipFound: !!ship, 
      contractFound: !!contract,
      contractStatus: contract?.status,
      shipStatus: ship?.status
    });
    
    if (ship && contract && contract.status === ContractStatus.ACTIVE) {
      // Store contract assignment on the ship
      set(state => ({
        fleet: state.fleet.map(s =>
          s.id === shipId
            ? { ...s, assignedContract: contractId, contractStage: 'pickup' }
            : s
        ),
      }));
      
      // Move ship to origin port to load cargo
      console.log(`Moving ship ${ship.name} to origin port ${contract.origin.name}`);
      get().moveShip(shipId, contract.origin);
      
      // Show notification
      console.log(`🚢 ${ship.name} assigned to contract: ${contract.origin.name} → ${contract.destination.name}`);
    }
  },
  
  sendShipToPort: (shipId, portId) => {
    const state = get();
    const port = state.ports.find(p => p.id === portId);
    if (port) {
      get().moveShip(shipId, port);
    }
  },
  
  repairShip: (shipId) => {
    const repairCost = 1000;
    if (get().spendMoney(repairCost)) {
      set(state => ({
        fleet: state.fleet.map(ship =>
          ship.id === shipId
            ? { ...ship, health: 100, status: ShipStatus.MAINTENANCE }
            : ship
        ),
      }));
      
      // After repair time, set back to idle
      setTimeout(() => {
        set(state => ({
          fleet: state.fleet.map(ship =>
            ship.id === shipId && ship.status === ShipStatus.MAINTENANCE
              ? { ...ship, status: ShipStatus.IDLE }
              : ship
          ),
        }));
      }, 5000);
    }
  },
  
  upgradeShip: (shipId) => {
    const state = get();
    const ship = state.fleet.find(s => s.id === shipId);
    if (ship) {
      const upgradeCost = ship.value * 0.5;
      if (get().spendMoney(upgradeCost)) {
        set(state => ({
          fleet: state.fleet.map(s =>
            s.id === shipId
              ? { 
                  ...s, 
                  capacity: Math.floor(s.capacity * 1.2),
                  speed: s.speed * 1.1,
                  value: s.value * 1.3
                }
              : s
          ),
        }));
      }
    }
  },
  
  sellShip: (shipId) => {
    const state = get();
    const ship = state.fleet.find(s => s.id === shipId);
    if (ship) {
      const sellPrice = ship.value * 0.7;
      get().addMoney(sellPrice);
      set(state => ({
        fleet: state.fleet.filter(s => s.id !== shipId),
      }));
    }
  },
  
  assignContractToShip: (contractId, shipId) => {
    get().assignShipToContract(shipId, contractId);
  },
  
  loadCargo: (shipId, contractId) => {
    const state = get();
    const ship = state.fleet.find(s => s.id === shipId);
    const contract = state.contracts.find(c => c.id === contractId);
    
    if (ship && contract && ship.cargo.length === 0) {
      // Create cargo containers for the contract
      const containers: Container[] = [];
      const containerCount = Math.ceil(contract.quantity / 10); // 10 units per container
      
      for (let i = 0; i < containerCount; i++) {
        containers.push({
          id: `cargo-${contractId}-${i}`,
          type: contract.cargo,
          weight: 10,
          value: contract.value / containerCount,
          origin: contract.origin,
          destination: contract.destination,
        });
      }
      
      set(state => ({
        fleet: state.fleet.map(s =>
          s.id === shipId
            ? { ...s, cargo: containers, status: ShipStatus.LOADING }
            : s
        ),
      }));
      
      // After loading, move to destination
      setTimeout(() => {
        get().moveShip(shipId, contract.destination);
      }, 2000); // 2 second loading time
    }
  },
  
  unloadCargo: (shipId) => {
    const state = get();
    const ship = state.fleet.find(s => s.id === shipId);
    
    if (ship && ship.cargo.length > 0) {
      // Check if we're at the correct destination
      const firstCargo = ship.cargo[0];
      if (firstCargo && ship.position.x === firstCargo.destination.position.x &&
          ship.position.z === firstCargo.destination.position.z) {
        
        // Find the associated contract
        const contract = state.contracts.find(c => 
          c.origin.id === firstCargo.origin.id && 
          c.destination.id === firstCargo.destination.id &&
          c.status === ContractStatus.ACTIVE
        );
        
        if (contract) {
          // Complete the contract
          get().completeContract(contract.id);
        }
        
        // Clear cargo
        set(state => ({
          fleet: state.fleet.map(s =>
            s.id === shipId
              ? { ...s, cargo: [], status: ShipStatus.IDLE, assignedContract: undefined }
              : s
          ),
        }));
      }
    }
  },
  
  completeContract: (contractId) => {
    const contract = get().contracts.find(c => c.id === contractId);
    if (contract) {
      get().addMoney(contract.value);
      set(state => ({
        contracts: state.contracts.map(c =>
          c.id === contractId
            ? { ...c, status: ContractStatus.COMPLETED }
            : c
        ),
        reputation: Math.min(100, state.reputation + 5),
      }));
    }
  },
  
  incrementAI: (amount) => {
    set(state => ({
      aiDevelopmentLevel: Math.min(100, state.aiDevelopmentLevel + amount),
    }));
  },
  
  triggerSingularity: () => {
    const state = get();
    const result: GameResult = {
      winner: 'singularity',
      reason: 'AI efficiency exceeded human capabilities',
      finalScore: {
        player: state.playerEfficiency,
        ai: Math.max(...state.aiCompetitors.map(ai => ai.efficiency)),
      },
      duration: Date.now() - (state.gameStartTime || 0),
    };
    set({ isSingularityActive: true, gameResult: result });
  },
  
  endGame: (result: GameResult) => {
    set({ gameResult: result, isPaused: true });
  },
  
  calculateEfficiency: (isPlayer: boolean, competitorId?: string) => {
    const state = get();
    
    if (isPlayer) {
      const playerShips = state.fleet.filter(s => s.ownerId === 'player');
      const activeContracts = state.contracts.filter(c => 
        c.status === ContractStatus.ACTIVE && 
        playerShips.some(s => s.assignedContract === c.id)
      ).length;
      const completedContracts = state.contracts.filter(c => 
        c.status === ContractStatus.COMPLETED
      ).length;
      const totalCapacity = playerShips.reduce((sum, ship) => sum + ship.capacity, 0);
      const usedCapacity = playerShips.reduce((sum, ship) => sum + ship.cargo.length * 10, 0);
      
      const utilizationRate = totalCapacity > 0 ? (usedCapacity / totalCapacity) * 100 : 0;
      const completionRate = completedContracts * 10;
      const fleetSize = playerShips.length * 5;
      
      return Math.min(100, (utilizationRate + completionRate + fleetSize) / 3);
    } else if (competitorId) {
      // AI efficiency calculation
      const ai = state.aiCompetitors.find(a => a.id === competitorId);
      if (!ai) return 0;
      
      return ai.efficiency;
    }
    
    return 0;
  },
  
  updateAICompetitors: (deltaTime: number) => {
    const state = get();
    if (state.isPaused || state.isSingularityActive) return;
    
    const updatedCompetitors = state.aiCompetitors.map(ai => {
      // AI makes decisions
      const aiShips = state.fleet.filter(s => s.ownerId === ai.id);
      
      // Purchase new ships if profitable
      if (ai.money > getShipCost(ShipType.CONTAINER) * 2 && aiShips.length < 10) {
        if (Math.random() < 0.01 * deltaTime) { // 1% chance per second
          const cost = getShipCost(ShipType.CONTAINER);
          const newShip: Ship = {
            id: `ai-ship-${ai.id}-${Date.now()}`,
            name: `${ai.name} Vessel ${aiShips.length + 1}`,
            type: ShipType.CONTAINER,
            position: { ...state.ports[0].position },
            destination: null,
            cargo: [],
            capacity: getShipCapacity(ShipType.CONTAINER),
            speed: getShipSpeed(ShipType.CONTAINER),
            fuel: 100,
            condition: 100,
            health: 100,
            value: getShipValue(ShipType.CONTAINER),
            status: ShipStatus.IDLE,
            currentPortId: state.ports[0].id,
            ownerId: ai.id,
          };
          
          set(state => ({ 
            fleet: [...state.fleet, newShip]
          }));
          
          return {
            ...ai,
            money: ai.money - cost,
            shipsOwned: ai.shipsOwned + 1,
          };
        }
      }
      
      // Assign idle ships to contracts (limit to prevent performance issues)
      const idleShips = aiShips.filter(s => s.status === ShipStatus.IDLE && !s.assignedContract);
      const availableContracts = state.contracts.filter(c => c.status === ContractStatus.AVAILABLE);
      const activeAIContracts = state.contracts.filter(c => 
        c.status === ContractStatus.ACTIVE && 
        aiShips.some(s => s.assignedContract === c.id)
      ).length;
      
      // Limit to 3 active contracts per AI to prevent overload
      if (idleShips.length > 0 && availableContracts.length > 0 && activeAIContracts < 3) {
        const ship = idleShips[0];
        const contract = availableContracts.sort((a, b) => b.value - a.value)[0]; // Pick highest value
        
        // Assign contract with a small delay to prevent simultaneous assignments
        if (Math.random() < 0.1) { // 10% chance per update to assign
          get().assignShipToContract(ship.id, contract.id);
          get().acceptContract(contract.id);
        }
      }
      
      // Update AI efficiency based on performance
      const baseEfficiency = ai.efficiency;
      // Much slower growth: 0.001 per second base, up to 0.002 with full AI development
      const efficiencyGrowth = deltaTime * 0.001 * (1 + state.aiDevelopmentLevel / 100);
      const newEfficiency = Math.min(100, baseEfficiency + efficiencyGrowth);
      
      // AI earns passive income
      const passiveIncome = ai.shipsOwned * 1000 * deltaTime;
      
      return {
        ...ai,
        efficiency: newEfficiency,
        money: ai.money + passiveIncome,
        totalRevenue: ai.totalRevenue + passiveIncome,
      };
    });
    
    set({ aiCompetitors: updatedCompetitors });
  },
  
  generateNewContract: () => {
    const state = get();
    const newContract = generateDynamicContract(state.ports, state.reputation);
    if (newContract) {
      set(state => ({ contracts: [...state.contracts, newContract] }));
    }
  },
  
  updateGame: (deltaTime) => {
    const state = get();
    if (state.isPaused || state.isSingularityActive) return;
    
    // Check game duration for timed modes
    if (state.gameMode && state.gameDuration && state.gameStartTime) {
      const elapsed = (Date.now() - state.gameStartTime) / 1000; // in seconds
      if (elapsed >= state.gameDuration) {
        // Time's up - determine winner
        const playerEfficiency = get().calculateEfficiency(true);
        const maxAIEfficiency = Math.max(...state.aiCompetitors.map(ai => ai.efficiency));
        
        const result: GameResult = {
          winner: playerEfficiency > maxAIEfficiency ? 'player' : 'ai',
          reason: 'Time limit reached',
          finalScore: {
            player: playerEfficiency,
            ai: maxAIEfficiency,
          },
          duration: elapsed,
        };
        
        get().endGame(result);
        return;
      }
    }
    
    // Update AI competitors
    get().updateAICompetitors(deltaTime);
    
    // Batch all state updates together to avoid multiple re-renders
    const updates: Partial<GameState> = {};
    
    // Update game time
    const newDate = new Date(state.currentDate.getTime() + deltaTime * state.gameSpeed * 1000);
    updates.currentDate = newDate;
    
    // Update player efficiency
    updates.playerEfficiency = get().calculateEfficiency(true);
    
    // Update AI development - much slower progression
    // 0.0033 per second = 0.2% per minute = 1% per 5 minutes
    const aiIncrement = deltaTime * 0.0033;
    const newAILevel = Math.min(100, state.aiDevelopmentLevel + aiIncrement);
    updates.aiDevelopmentLevel = newAILevel;
    
    // Check for singularity based on AI efficiency vs player
    const maxAIEfficiency = Math.max(...state.aiCompetitors.map(ai => ai.efficiency));
    // Singularity only when AI is significantly ahead (50% more efficient) or AI development is complete
    if ((newAILevel >= 100 || maxAIEfficiency > state.playerEfficiency + 50) && !state.isSingularityActive) {
      get().triggerSingularity();
      return;
    }
    
    // Generate new contracts periodically (every ~30 seconds game time)
    let newContracts = state.contracts;
    if (Math.random() < deltaTime / 30) {
      const newContract = generateDynamicContract(state.ports, state.reputation);
      if (newContract) {
        newContracts = [...state.contracts, newContract];
        updates.contracts = newContracts;
      }
    }
    
    // Update ships
    const updatedFleet = state.fleet.map(ship => {
      if (ship.status === ShipStatus.SAILING && ship.destination) {
        const earthRadius = 100;
        const currentPos = new THREE.Vector3(ship.position.x, ship.position.y, ship.position.z);
        
        // Handle waypoint navigation for ships
        const waypoints = (ship as any).waypoints;
        const currentWaypointIndex = (ship as any).currentWaypointIndex || 0;
        
        let targetPos: THREE.Vector3;
        let isLastWaypoint = false;
        
        if (waypoints && waypoints.length > 0 && currentWaypointIndex < waypoints.length) {
          // Navigate to current waypoint
          const waypoint = waypoints[currentWaypointIndex];
          if (waypoint instanceof THREE.Vector3) {
            targetPos = waypoint;
          } else {
            targetPos = new THREE.Vector3(waypoint.x, waypoint.y, waypoint.z);
          }
          isLastWaypoint = currentWaypointIndex === waypoints.length - 1;
        } else {
          // Direct navigation (for planes or when no waypoints)
          targetPos = new THREE.Vector3(
            ship.destination.position.x,
            ship.destination.position.y,
            ship.destination.position.z
          );
          isLastWaypoint = true;
        }
        
        // Calculate distance to target
        const distance = calculateDistance(currentPos, targetPos, earthRadius);
        const moveDistance = ship.speed * deltaTime * state.gameSpeed;
        
        if (distance < 2) {
          // Reached waypoint or destination
          if (!isLastWaypoint && waypoints) {
            // Move to next waypoint
            return {
              ...ship,
              currentWaypointIndex: currentWaypointIndex + 1,
            } as any;
          } else {
            // Arrived at final destination
            const assignedContract = (ship as any).assignedContract;
            const contract = state.contracts.find(c => c.id === assignedContract);
            
            // Determine next status based on cargo and contract
            let nextStatus = ShipStatus.IDLE;
            if (contract && ship.cargo.length === 0 && 
                ship.destination.id === contract.origin.id) {
              // At origin port, need to load cargo
              nextStatus = ShipStatus.LOADING;
              // Handle loading in a separate update cycle
              if (!ship.loadingStartTime) {
                return {
                  ...ship,
                  position: { ...ship.destination.position },
                  status: nextStatus,
                  destination: null,
                  waypoints: undefined,
                  currentWaypointIndex: 0,
                  loadingStartTime: Date.now(),
                } as any;
              } else if (Date.now() - ship.loadingStartTime > 100) {
                // Loading complete, load cargo
                const cargo: Container = {
                  id: `cargo-${Date.now()}`,
                  type: contract.cargo,
                  weight: contract.quantity * 1000, // Convert tons to kg
                  value: contract.value,
                  origin: contract.origin,
                  destination: contract.destination,
                };
                return {
                  ...ship,
                  position: { ...ship.destination.position },
                  status: ShipStatus.IDLE,
                  cargo: [cargo],
                  destination: null,
                  waypoints: undefined,
                  currentWaypointIndex: 0,
                  loadingStartTime: undefined,
                } as any;
              }
            } else if (ship.cargo.length > 0) {
              // Has cargo, need to unload
              nextStatus = ShipStatus.UNLOADING;
              // Handle unloading in a separate update cycle
              if (!ship.unloadingStartTime) {
                return {
                  ...ship,
                  position: { ...ship.destination.position },
                  status: nextStatus,
                  destination: null,
                  waypoints: undefined,
                  currentWaypointIndex: 0,
                  unloadingStartTime: Date.now(),
                } as any;
              } else if (Date.now() - ship.unloadingStartTime > 2000) {
                // Unloading complete
                const cargoValue = ship.cargo.reduce((sum, item) => sum + item.value, 0);
                updates.money = (updates.money || state.money) + cargoValue;
                return {
                  ...ship,
                  position: { ...ship.destination.position },
                  status: ShipStatus.IDLE,
                  cargo: [],
                  destination: null,
                  waypoints: undefined,
                  currentWaypointIndex: 0,
                  unloadingStartTime: undefined,
                } as any;
              }
            }
            
            return {
              ...ship,
              position: { ...ship.destination.position },
              status: nextStatus,
              destination: null,
              waypoints: undefined,
              currentWaypointIndex: 0,
            } as any;
          }
        } else {
          // Move towards target
          const moveRatio = Math.min(moveDistance / distance, 1);
          const newPosition = interpolateRoute(currentPos, targetPos, moveRatio);
          
          // Ensure ship stays at proper altitude above Earth surface
          const shipAltitude = ship.type === ShipType.CARGO_PLANE ? 15 : 2;
          const normalizedPos = newPosition.clone().normalize();
          const finalPosition = normalizedPos.multiplyScalar(earthRadius + shipAltitude);
          
          // For ships (not planes), ensure they stay over water
          if (ship.type !== ShipType.CARGO_PLANE) {
            if (!isShipOverWater(finalPosition, earthRadius)) {
              // Find nearest water point
              const waterPos = getNearestWaterPoint(finalPosition, earthRadius);
              const waterNorm = waterPos.clone().normalize();
              finalPosition.copy(waterNorm.multiplyScalar(earthRadius + shipAltitude));
            }
          }
          
          // Calculate ship rotation to face movement direction
          const direction = targetPos.clone().sub(currentPos).normalize();
          const shipRotation = Math.atan2(direction.x, direction.z);
          
          return {
            ...ship,
            position: {
              x: finalPosition.x,
              y: finalPosition.y,
              z: finalPosition.z,
            },
            rotation: shipRotation,
          } as any;
        }
      }
      return ship;
    });
    
    // Apply fleet updates to the batch
    updates.fleet = updatedFleet;
    
    // Apply all updates in a single state change to avoid multiple re-renders
    set(updates);
  },
}));

// Helper functions
function generateInitialPorts(): Port[] {
  const ports = generatePortsFromWorldData();
  console.log('generateInitialPorts returning:', ports.length, 'ports');
  return ports;
}

function generateInitialContracts(ports: Port[]): Contract[] {
  const contracts: Contract[] = [];
  const cargoTypes = Object.values(CargoType);
  
  for (let i = 0; i < 5; i++) {
    const origin = ports[Math.floor(Math.random() * ports.length)];
    let destination = ports[Math.floor(Math.random() * ports.length)];
    while (destination.id === origin.id) {
      destination = ports[Math.floor(Math.random() * ports.length)];
    }
    
    const quantity = Math.floor(Math.random() * 100) + 50;
    const value = Math.floor(Math.random() * 500000) + 100000;
    contracts.push({
      id: `contract-${i}`,
      client: `Client ${i + 1}`,
      origin,
      destination,
      cargo: cargoTypes[Math.floor(Math.random() * cargoTypes.length)],
      quantity,
      value,
      payment: value,
      deadline: new Date(Date.now() + Math.random() * 30 * 24 * 60 * 60 * 1000), // 0-30 days
      status: ContractStatus.AVAILABLE,
      requiredCapacity: quantity,
    });
  }
  
  return contracts;
}

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

function getShipValue(type: ShipType): number {
  return getShipCost(type);
}

function getGameModeConfig(mode: GameMode) {
  switch (mode) {
    case GameMode.QUICK:
      return {
        duration: 300, // 5 minutes
        startingMoney: 100000000, // $100M
        initialContracts: 25,
        aiCount: 3,
        initialSpeed: 5,
      };
    case GameMode.CAMPAIGN:
      return {
        duration: 1800, // 30 minutes
        startingMoney: 50000000, // $50M
        initialContracts: 15,
        aiCount: 5,
        initialSpeed: 1,
      };
    case GameMode.INFINITE:
      return {
        duration: undefined,
        startingMoney: 30000000, // $30M
        initialContracts: 10,
        aiCount: 8,
        initialSpeed: 1,
      };
  }
}

function generateAICompetitors(count: number): AICompetitor[] {
  const aiNames = [
    'Maersk AI', 'COSCO Digital', 'MSC Quantum', 'Evergreen Logic',
    'Hapag-Lloyd Neural', 'ONE Algorithm', 'Yang Ming Cyber', 'CMA CGM Matrix',
    'ZIM Compute', 'HMM Digital', 'PIL Network', 'OOCL Systems'
  ];
  
  const colors = [
    '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', 
    '#DDA0DD', '#98D8C8', '#F7DC6F', '#85C1E2',
    '#F8B195', '#C06C84', '#6C5CE7', '#A29BFE'
  ];
  
  return Array.from({ length: count }, (_, i) => ({
    id: `ai-${i + 1}`,
    name: aiNames[i % aiNames.length],
    money: 50000000 + Math.random() * 50000000, // $50M-$100M
    efficiency: 15 + Math.random() * 10, // 15-25% starting efficiency - much lower
    shipsOwned: 1,
    contractsCompleted: 0,
    totalRevenue: 0,
    color: colors[i % colors.length],
  }));
}