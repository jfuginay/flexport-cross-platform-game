import { GameState, Ship, ShipType, ShipStatus, Port, TradeRoute, Coordinates, CrewMember, Cargo } from '@/types';
import { PortData } from '@/utils/PortData';
import { ProgressionSystem } from './ProgressionSystem';

export class ShipSystem {
  private gameState: GameState;
  private progressionSystem: ProgressionSystem | null = null;
  private readonly SHIP_SPECS: Record<ShipType, any> = {
    bulk_carrier: {
      capacity: 50000,
      speed: 14,
      efficiency: 0.8,
      baseCost: 25000000,
      maintenanceRate: 0.02,
      fuelConsumption: 120,
      crewSize: 20,
    },
    container_ship: {
      capacity: 18000, // TEU
      speed: 24,
      efficiency: 0.9,
      baseCost: 50000000,
      maintenanceRate: 0.025,
      fuelConsumption: 200,
      crewSize: 25,
    },
    tanker: {
      capacity: 80000,
      speed: 16,
      efficiency: 0.85,
      baseCost: 40000000,
      maintenanceRate: 0.03,
      fuelConsumption: 150,
      crewSize: 22,
    },
    general_cargo: {
      capacity: 15000,
      speed: 18,
      efficiency: 0.75,
      baseCost: 15000000,
      maintenanceRate: 0.015,
      fuelConsumption: 80,
      crewSize: 18,
    },
    roro: {
      capacity: 2500, // Vehicles
      speed: 22,
      efficiency: 0.8,
      baseCost: 35000000,
      maintenanceRate: 0.02,
      fuelConsumption: 110,
      crewSize: 30,
    },
    refrigerated: {
      capacity: 12000,
      speed: 20,
      efficiency: 0.7,
      baseCost: 45000000,
      maintenanceRate: 0.035,
      fuelConsumption: 160,
      crewSize: 24,
    },
    heavy_lift: {
      capacity: 25000,
      speed: 12,
      efficiency: 0.6,
      baseCost: 60000000,
      maintenanceRate: 0.04,
      fuelConsumption: 180,
      crewSize: 35,
    },
  };

  constructor(gameState: GameState) {
    this.gameState = gameState;
  }

  public createShip(type: ShipType, name: string, homePort: string): Ship {
    const specs = this.SHIP_SPECS[type];
    const port = PortData.getPortById(homePort);
    
    if (!port) {
      throw new Error(`Invalid home port: ${homePort}`);
    }

    // Check if player has unlocked this ship type
    if (this.progressionSystem) {
      const unlockRequired = this.getShipUnlockRequirement(type);
      if (unlockRequired && !this.progressionSystem.isFeatureUnlocked(unlockRequired)) {
        throw new Error(`Ship type ${type} is not yet unlocked. Reach the required level to unlock it.`);
      }
    }

    const ship: Ship = {
      id: `ship_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      name,
      type,
      capacity: specs.capacity,
      speed: specs.speed,
      efficiency: specs.efficiency,
      maintenanceCost: specs.baseCost * specs.maintenanceRate / 365, // Daily maintenance
      currentLocation: port.coordinates,
      status: 'docked',
      cargo: [],
      crew: this.generateCrew(specs.crewSize),
      fuel: 1000, // Start with full fuel
      condition: 100, // Perfect condition
    };

    this.gameState.player.ships.push(ship);

    // Grant XP for purchasing ship
    if (this.progressionSystem) {
      const shipTier = this.getShipTier(type);
      this.progressionSystem.grantExperience('purchase_ship', {
        ship_tier: shipTier
      });

      // Check fleet size milestones
      const fleetSize = this.gameState.player.ships.length;
      if (fleetSize % 5 === 0) {
        this.progressionSystem.grantExperience('fleet_size_milestone', {
          fleet_size: fleetSize
        });
      }
    }

    return ship;
  }

  private generateCrew(size: number): CrewMember[] {
    const crew: CrewMember[] = [];
    const roles = ['Captain', 'Engineer', 'Navigator', 'Mechanic', 'Cook', 'Deckhand'];
    
    // Always have a captain
    crew.push({
      id: `crew_${Date.now()}_captain`,
      name: this.generateCrewName(),
      role: 'Captain',
      skill: 0.7 + Math.random() * 0.3,
      morale: 0.6 + Math.random() * 0.4,
      experience: Math.random() * 10,
    });

    // Fill remaining positions
    for (let i = 1; i < size; i++) {
      const role = roles[Math.floor(Math.random() * roles.length)];
      crew.push({
        id: `crew_${Date.now()}_${i}`,
        name: this.generateCrewName(),
        role,
        skill: 0.3 + Math.random() * 0.7,
        morale: 0.4 + Math.random() * 0.6,
        experience: Math.random() * 8,
      });
    }

    return crew;
  }

  private generateCrewName(): string {
    const firstNames = ['James', 'Maria', 'Robert', 'Patricia', 'John', 'Jennifer', 'Michael', 'Linda', 'William', 'Elizabeth'];
    const lastNames = ['Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis', 'Rodriguez', 'Martinez'];
    
    const firstName = firstNames[Math.floor(Math.random() * firstNames.length)];
    const lastName = lastNames[Math.floor(Math.random() * lastNames.length)];
    
    return `${firstName} ${lastName}`;
  }

  public assignShipToRoute(shipId: string, routeId: string): boolean {
    const ship = this.getShipById(shipId);
    const route = this.getRouteById(routeId);
    
    if (!ship || !route) return false;
    
    if (ship.status !== 'docked') return false;
    
    // Check if ship is at the origin port
    const originPort = PortData.getPortById(route.origin);
    if (!originPort || !this.isShipAtPort(ship, originPort)) return false;
    
    // Add ship to route
    if (!route.ships.includes(shipId)) {
      route.ships.push(shipId);
    }
    
    // Start the journey
    this.startJourney(ship, route.destination);
    
    return true;
  }

  private startJourney(ship: Ship, destinationPortId: string): void {
    const destinationPort = PortData.getPortById(destinationPortId);
    if (!destinationPort) return;
    
    ship.destination = destinationPortId;
    ship.status = 'departing';
    
    // Calculate journey time based on distance and ship speed
    const distance = this.calculateDistance(ship.currentLocation, destinationPort.coordinates);
    const journeyTime = (distance / ship.speed) * 24; // Hours
    
    // Schedule status changes
    setTimeout(() => {
      ship.status = 'traveling';
    }, 2000); // 2 seconds departure time
    
    setTimeout(() => {
      ship.status = 'arriving';
      ship.currentLocation = destinationPort.coordinates;
    }, journeyTime * 1000 * 60); // Convert to milliseconds (simplified for demo)
    
    setTimeout(() => {
      ship.status = 'docked';
      ship.destination = undefined;
    }, (journeyTime + 0.5) * 1000 * 60); // Add 30 minutes docking time
  }

  private calculateDistance(from: Coordinates, to: Coordinates): number {
    const R = 6371; // Earth's radius in kilometers
    const dLat = (to.latitude - from.latitude) * Math.PI / 180;
    const dLon = (to.longitude - from.longitude) * Math.PI / 180;
    const a = 
      Math.sin(dLat/2) * Math.sin(dLat/2) +
      Math.cos(from.latitude * Math.PI / 180) * Math.cos(to.latitude * Math.PI / 180) * 
      Math.sin(dLon/2) * Math.sin(dLon/2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    return R * c;
  }

  public loadCargo(shipId: string, cargo: Cargo[]): boolean {
    const ship = this.getShipById(shipId);
    if (!ship || ship.status !== 'docked') return false;
    
    // Calculate current cargo weight/volume
    const currentLoad = ship.cargo.reduce((total, item) => total + item.quantity, 0);
    const newLoad = cargo.reduce((total, item) => total + item.quantity, 0);
    
    if (currentLoad + newLoad > ship.capacity) return false;
    
    ship.cargo.push(...cargo);
    ship.status = 'loading';
    
    // Simulate loading time
    setTimeout(() => {
      ship.status = 'docked';
    }, 5000); // 5 seconds loading time
    
    return true;
  }

  public unloadCargo(shipId: string, cargoTypes?: string[]): Cargo[] {
    const ship = this.getShipById(shipId);
    if (!ship || ship.status !== 'docked') return [];
    
    ship.status = 'unloading';
    
    let unloadedCargo: Cargo[];
    
    if (cargoTypes) {
      // Unload specific cargo types
      unloadedCargo = ship.cargo.filter(cargo => cargoTypes.includes(cargo.type));
      ship.cargo = ship.cargo.filter(cargo => !cargoTypes.includes(cargo.type));
    } else {
      // Unload all cargo
      unloadedCargo = [...ship.cargo];
      ship.cargo = [];
    }
    
    // Simulate unloading time
    setTimeout(() => {
      ship.status = 'docked';
    }, 3000); // 3 seconds unloading time
    
    return unloadedCargo;
  }

  public refuelShip(shipId: string): boolean {
    const ship = this.getShipById(shipId);
    if (!ship || ship.status !== 'docked') return false;
    
    const fuelNeeded = 1000 - ship.fuel;
    const fuelCost = fuelNeeded * 2; // $2 per unit of fuel
    
    if (this.gameState.player.cash < fuelCost) return false;
    
    this.gameState.player.cash -= fuelCost;
    ship.fuel = 1000;
    
    return true;
  }

  public repairShip(shipId: string): boolean {
    const ship = this.getShipById(shipId);
    if (!ship || ship.status !== 'docked') return false;
    
    const repairNeeded = 100 - ship.condition;
    const repairCost = repairNeeded * 1000; // $1000 per condition point
    
    if (this.gameState.player.cash < repairCost) return false;
    
    this.gameState.player.cash -= repairCost;
    ship.condition = 100;
    
    return true;
  }

  public upgradeShip(shipId: string, upgradeType: string): boolean {
    const ship = this.getShipById(shipId);
    if (!ship || ship.status !== 'docked') return false;
    
    const upgradeCosts: Record<string, number> = {
      engine: 500000,
      cargo_hold: 300000,
      navigation: 200000,
      efficiency: 400000,
    };
    
    const cost = upgradeCosts[upgradeType];
    if (!cost || this.gameState.player.cash < cost) return false;
    
    this.gameState.player.cash -= cost;
    
    switch (upgradeType) {
      case 'engine':
        ship.speed *= 1.1;
        break;
      case 'cargo_hold':
        ship.capacity *= 1.15;
        break;
      case 'navigation':
        ship.efficiency *= 1.05;
        break;
      case 'efficiency':
        ship.maintenanceCost *= 0.9;
        break;
    }
    
    // Grant XP for upgrading
    if (this.progressionSystem) {
      this.progressionSystem.grantExperience('upgrade_ship');
    }
    
    return true;
  }

  public createTradeRoute(originPortId: string, destinationPortId: string, cargo: string[]): TradeRoute | null {
    const originPort = PortData.getPortById(originPortId);
    const destinationPort = PortData.getPortById(destinationPortId);
    
    if (!originPort || !destinationPort) return null;
    
    const distance = this.calculateDistance(originPort.coordinates, destinationPort.coordinates);
    const travelTime = distance / 20; // Assume average speed of 20 knots
    
    const route: TradeRoute = {
      id: `route_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      origin: originPortId,
      destination: destinationPortId,
      ships: [],
      cargo: cargo as any[],
      frequency: 1, // Weekly
      profitability: this.calculateRouteProfitability(originPort, destinationPort, cargo),
      distance,
      travelTime,
    };
    
    this.gameState.player.tradeRoutes.push(route);
    this.gameState.world.tradeRoutes.push(route);
    
    // Grant XP for establishing route
    if (this.progressionSystem) {
      this.progressionSystem.grantExperience('establish_route');
    }
    
    return route;
  }

  private calculateRouteProfitability(origin: Port, destination: Port, cargo: string[]): number {
    let totalProfit = 0;
    
    cargo.forEach(cargoType => {
      const supply = origin.supplyData[cargoType as keyof typeof origin.supplyData] || 0;
      const demand = destination.demandData[cargoType as keyof typeof destination.demandData] || 0;
      
      // Simple profit calculation based on supply/demand differential
      const profit = (demand - supply) * 1000;
      totalProfit += Math.max(0, profit);
    });
    
    return totalProfit;
  }

  public update(deltaTime: number): void {
    this.gameState.player.ships.forEach(ship => {
      this.updateShip(ship, deltaTime);
    });
    
    this.updateMaintenanceCosts(deltaTime);
    this.updateCrewMorale(deltaTime);
    this.updateShipConditions(deltaTime);
  }

  private updateShip(ship: Ship, deltaTime: number): void {
    // Update fuel consumption during travel
    if (ship.status === 'traveling') {
      const specs = this.SHIP_SPECS[ship.type];
      const fuelConsumption = specs.fuelConsumption * deltaTime / 3600; // Per hour
      ship.fuel = Math.max(0, ship.fuel - fuelConsumption);
      
      // If out of fuel, ship gets stranded
      if (ship.fuel <= 0) {
        ship.status = 'docked'; // Emergency docking
        ship.condition -= 5; // Damage from emergency situation
      }
    }
    
    // Update ship position during travel
    if (ship.status === 'traveling' && ship.destination) {
      this.updateShipPosition(ship, deltaTime);
    }
  }

  private updateShipPosition(ship: Ship, deltaTime: number): void {
    if (!ship.destination) return;
    
    const destinationPort = PortData.getPortById(ship.destination);
    if (!destinationPort) return;
    
    const target = destinationPort.coordinates;
    const current = ship.currentLocation;
    
    // Calculate movement based on ship speed
    const speedKmPerSec = (ship.speed * 1.852) / 3600; // Convert knots to km/s
    const distance = this.calculateDistance(current, target);
    
    if (distance > speedKmPerSec * deltaTime) {
      // Still traveling
      const ratio = (speedKmPerSec * deltaTime) / distance;
      ship.currentLocation = {
        latitude: current.latitude + (target.latitude - current.latitude) * ratio,
        longitude: current.longitude + (target.longitude - current.longitude) * ratio,
      };
    } else {
      // Arrived at destination
      ship.currentLocation = target;
      ship.status = 'arriving';
      
      // Auto-dock after short delay
      setTimeout(() => {
        ship.status = 'docked';
        ship.destination = undefined;
      }, 2000);
    }
  }

  private updateMaintenanceCosts(deltaTime: number): void {
    const dailyMaintenance = this.gameState.player.ships.reduce(
      (total, ship) => total + ship.maintenanceCost,
      0
    );
    
    const costPerSecond = dailyMaintenance / (24 * 3600);
    this.gameState.player.cash -= costPerSecond * deltaTime;
  }

  private updateCrewMorale(deltaTime: number): void {
    this.gameState.player.ships.forEach(ship => {
      ship.crew.forEach(crewMember => {
        // Morale slowly decreases over time
        crewMember.morale = Math.max(0, crewMember.morale - 0.001 * deltaTime);
        
        // Experience slowly increases
        crewMember.experience += 0.0001 * deltaTime;
        
        // Low morale affects ship efficiency
        const avgMorale = ship.crew.reduce((sum, crew) => sum + crew.morale, 0) / ship.crew.length;
        ship.efficiency = this.SHIP_SPECS[ship.type].efficiency * (0.5 + avgMorale * 0.5);
      });
    });
  }

  private updateShipConditions(deltaTime: number): void {
    this.gameState.player.ships.forEach(ship => {
      // Ships slowly deteriorate over time
      const deteriorationRate = ship.status === 'traveling' ? 0.01 : 0.005;
      ship.condition = Math.max(0, ship.condition - deteriorationRate * deltaTime);
      
      // Poor condition affects efficiency and increases maintenance costs
      if (ship.condition < 80) {
        ship.efficiency *= (ship.condition / 100);
        ship.maintenanceCost *= (100 / ship.condition);
      }
    });
  }

  private getShipById(shipId: string): Ship | undefined {
    return this.gameState.player.ships.find(ship => ship.id === shipId);
  }

  private getRouteById(routeId: string): TradeRoute | undefined {
    return this.gameState.player.tradeRoutes.find(route => route.id === routeId);
  }

  private isShipAtPort(ship: Ship, port: Port): boolean {
    const distance = this.calculateDistance(ship.currentLocation, port.coordinates);
    return distance < 1; // Within 1 km
  }

  public getShipStats(shipId: string): any {
    const ship = this.getShipById(shipId);
    if (!ship) return null;
    
    const avgCrewMorale = ship.crew.reduce((sum, crew) => sum + crew.morale, 0) / ship.crew.length;
    const avgCrewSkill = ship.crew.reduce((sum, crew) => sum + crew.skill, 0) / ship.crew.length;
    const cargoUtilization = ship.cargo.reduce((sum, cargo) => sum + cargo.quantity, 0) / ship.capacity;
    
    return {
      id: ship.id,
      name: ship.name,
      type: ship.type,
      status: ship.status,
      condition: ship.condition,
      fuel: ship.fuel,
      efficiency: ship.efficiency,
      avgCrewMorale,
      avgCrewSkill,
      cargoUtilization,
      maintenanceCost: ship.maintenanceCost,
    };
  }

  public getAllShipsStats(): any[] {
    return this.gameState.player.ships.map(ship => this.getShipStats(ship.id));
  }

  public setProgressionSystem(progressionSystem: ProgressionSystem): void {
    this.progressionSystem = progressionSystem;
  }

  private getShipUnlockRequirement(type: ShipType): string | null {
    const unlockMap: Record<ShipType, string> = {
      bulk_carrier: 'bulk_carrier_ships',
      container_ship: 'container_ships',
      tanker: 'tanker_ships',
      general_cargo: 'general_cargo_ships',
      roro: 'roro_ships',
      refrigerated: 'refrigerated_ships',
      heavy_lift: 'heavy_lift_ships'
    };
    return unlockMap[type] || null;
  }

  private getShipTier(type: ShipType): number {
    const tierMap: Record<ShipType, number> = {
      general_cargo: 1,
      bulk_carrier: 2,
      container_ship: 3,
      tanker: 3,
      roro: 4,
      refrigerated: 4,
      heavy_lift: 5
    };
    return tierMap[type] || 1;
  }
}