import { create } from 'zustand';
import * as THREE from 'three';
import { GameState, Ship, Port, Contract, Container, ShipType, ShipStatus, ContractStatus, CargoType } from '../types/game.types';
import { generateEnhancedContracts, generateDynamicContract } from '../utils/contractGenerator';
import { getPortPosition, realPortLocations, calculateDistance, interpolateRoute } from '../utils/geoUtils';
import { isShipOverWater, getWaterRouteBetweenPorts, getNearestWaterPoint } from '../utils/routeValidation';

interface GameStore extends GameState {
  // Selection state
  selectedShipId: string | null;
  selectedPortId: string | null;
  
  // Actions
  startGame: () => void;
  pauseGame: () => void;
  resumeGame: () => void;
  setGameSpeed: (speed: number) => void;
  
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
};

export const useGameStore = create<GameStore>((set, get) => ({
  ...INITIAL_STATE,
  selectedShipId: null,
  selectedPortId: null,
  
  selectShip: (shipId) => set({ selectedShipId: shipId, selectedPortId: null }),
  selectPort: (portId) => set({ selectedPortId: portId, selectedShipId: null }),
  
  startGame: () => {
    set({ ...INITIAL_STATE });
    // Generate initial world
    const ports = generateInitialPorts();
    const contracts = generateEnhancedContracts(ports, 15);
    
    // Create an initial ship for testing visibility
    const homePort = ports[0]; // LA port
    const testShip: Ship = {
      id: 'initial-ship-1',
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
    };
    
    set({ ports, contracts, fleet: [testShip] });
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
    if (get().spendMoney(cost)) {
      const homePort = get().ports.find(p => p.isPlayerOwned) || get().ports[0];
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
    const homePort = get().ports.find(p => p.isPlayerOwned) || get().ports[0];
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
    
    if (ship) {
      // Calculate water route for ships (not planes)
      if (ship.type !== ShipType.CARGO_PLANE) {
        const startPos = new THREE.Vector3(ship.position.x, ship.position.y, ship.position.z);
        const endPos = new THREE.Vector3(destination.position.x, destination.position.y, destination.position.z);
        const waypoints = getWaterRouteBetweenPorts(startPos, endPos, 100);
        
        set(state => ({
          fleet: state.fleet.map(s =>
            s.id === shipId
              ? { ...s, destination, status: ShipStatus.SAILING, routeProgress: 0, waypoints } as any
              : s
          ),
        }));
      } else {
        // Planes can fly direct routes
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
    
    if (ship && contract && contract.status === ContractStatus.ACTIVE) {
      // Move ship to origin port to load cargo
      get().moveShip(shipId, contract.origin);
      
      // Store contract assignment on the ship (we'll add this field)
      set(state => ({
        fleet: state.fleet.map(s =>
          s.id === shipId
            ? { ...s, assignedContract: contractId }
            : s
        ),
      }));
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
    set({ isSingularityActive: true });
    console.log('🤖 THE SINGULARITY HAS ARRIVED! Humans are now in zoos.');
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
    
    // Batch all state updates together to avoid multiple re-renders
    const updates: Partial<GameState> = {};
    
    // Update game time
    const newDate = new Date(state.currentDate.getTime() + deltaTime * state.gameSpeed * 1000);
    updates.currentDate = newDate;
    
    // Update AI development
    const aiIncrement = deltaTime * 0.01; // Slow progression
    const newAILevel = Math.min(100, state.aiDevelopmentLevel + aiIncrement);
    updates.aiDevelopmentLevel = newAILevel;
    
    // Check for singularity
    if (newAILevel >= 100 && !state.isSingularityActive) {
      updates.isSingularityActive = true;
      console.log('🤖 THE SINGULARITY HAS ARRIVED! Humans are now in zoos.');
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
  const EARTH_RADIUS = 100; // Match the Earth sphere radius
  
  // Use first 10 ports from real locations for more variety
  const selectedPorts = realPortLocations.slice(0, 10);
  
  return selectedPorts.map((portData, index) => {
    const position = getPortPosition(portData.name, EARTH_RADIUS);
    
    return {
      id: `port-${index}`,
      name: portData.name,
      position: { 
        x: position.x, 
        y: position.y, 
        z: position.z 
      },
      country: portData.country,
      capacity: 1000,
      currentLoad: Math.random() * 500,
      isPlayerOwned: index === 0, // Player starts with LA port
      berths: 10,
      availableBerths: Math.floor(Math.random() * 5) + 5,
      loadingSpeed: 50 + Math.floor(Math.random() * 50),
      dockedShips: [],
      contracts: [],
    };
  });
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