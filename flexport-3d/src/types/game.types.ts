export interface Position3D {
  x: number;
  y: number;
  z: number;
}

export interface GameState {
  money: number;
  reputation: number;
  companyName: string;
  isPaused: boolean;
  gameSpeed: number;
  currentDate: Date;
  fleet: Ship[];
  ports: Port[];
  contracts: Contract[];
  aiDevelopmentLevel: number;
  isSingularityActive: boolean;
}

export interface Ship {
  id: string;
  name: string;
  type: ShipType;
  position: Position3D;
  destination: Port | null;
  cargo: Container[];
  capacity: number;
  speed: number;
  fuel: number;
  condition: number;
  health: number;
  value: number;
  status: ShipStatus;
  assignedContract?: string;
  currentPortId?: string;
  ownerId?: string; // Player or AI ID
  totalEarnings?: number;
  totalDistance?: number;
  maintenanceCost?: number;
  currentCapacityUsed?: number;
  destinationPortId?: string;
  contractId?: string;
  loadingStartTime?: number;
  unloadingStartTime?: number;
}

export enum ShipType {
  CONTAINER = 'CONTAINER',
  BULK = 'BULK',
  TANKER = 'TANKER',
  CARGO_PLANE = 'CARGO_PLANE',
}

export enum ShipStatus {
  IDLE = 'IDLE',
  SAILING = 'SAILING',
  LOADING = 'LOADING',
  UNLOADING = 'UNLOADING',
  MAINTENANCE = 'MAINTENANCE',
}

export interface Port {
  id: string;
  name: string;
  position: Position3D;
  country: string;
  capacity: number;
  currentLoad: number;
  isPlayerOwned: boolean;
  berths: number;
  availableBerths: number;
  loadingSpeed: number;
  dockedShips: string[];
  contracts?: Contract[];
}

export interface Container {
  id: string;
  type: CargoType;
  weight: number;
  value: number;
  origin: Port;
  destination: Port;
}

export enum CargoType {
  STANDARD = 'STANDARD',
  REFRIGERATED = 'REFRIGERATED',
  HAZARDOUS = 'HAZARDOUS',
  VALUABLE = 'VALUABLE',
}

export interface Contract {
  id: string;
  client: string;
  origin: Port;
  destination: Port;
  cargo: CargoType;
  quantity: number;
  value: number;
  payment: number;
  deadline: Date;
  status: ContractStatus;
  requiredCapacity: number;
  assignedShipId?: string;
}

export enum ContractStatus {
  AVAILABLE = 'AVAILABLE',
  ACTIVE = 'ACTIVE',
  COMPLETED = 'COMPLETED',
  FAILED = 'FAILED',
}

export interface Disaster {
  id: string;
  type: DisasterType;
  location: Position3D;
  radius: number;
  severity: number;
  duration: number;
}

export enum DisasterType {
  STORM = 'STORM',
  PIRACY = 'PIRACY',
  PORT_STRIKE = 'PORT_STRIKE',
  PANDEMIC = 'PANDEMIC',
}