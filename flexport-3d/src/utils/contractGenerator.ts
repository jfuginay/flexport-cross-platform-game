import { Contract, Port, CargoType, ContractStatus } from '../types/game.types';

export enum ContractTier {
  STANDARD = 'STANDARD',
  PRIORITY = 'PRIORITY',
  URGENT = 'URGENT',
  EXCLUSIVE = 'EXCLUSIVE',
  GOVERNMENT = 'GOVERNMENT',
}

export enum ContractComplexity {
  SIMPLE = 'SIMPLE',           // Single port to port
  MULTI_STOP = 'MULTI_STOP',   // Multiple deliveries
  ROUND_TRIP = 'ROUND_TRIP',   // Return cargo
  TIME_CRITICAL = 'TIME_CRITICAL',
}

interface ClientProfile {
  name: string;
  industry: string;
  preferredCargo: CargoType[];
  paymentModifier: number;
  reliabilityRequirement: number;
}

const CLIENT_PROFILES: ClientProfile[] = [
  {
    name: 'Global Electronics Corp',
    industry: 'Technology',
    preferredCargo: [CargoType.VALUABLE, CargoType.STANDARD],
    paymentModifier: 1.3,
    reliabilityRequirement: 90,
  },
  {
    name: 'Fresh Foods International',
    industry: 'Food & Beverage',
    preferredCargo: [CargoType.REFRIGERATED],
    paymentModifier: 1.2,
    reliabilityRequirement: 95,
  },
  {
    name: 'PetroGlobal Industries',
    industry: 'Energy',
    preferredCargo: [CargoType.HAZARDOUS],
    paymentModifier: 1.5,
    reliabilityRequirement: 85,
  },
  {
    name: 'Amazon Logistics',
    industry: 'E-commerce',
    preferredCargo: [CargoType.STANDARD],
    paymentModifier: 1.1,
    reliabilityRequirement: 80,
  },
  {
    name: 'MediCare Supplies',
    industry: 'Healthcare',
    preferredCargo: [CargoType.REFRIGERATED, CargoType.VALUABLE],
    paymentModifier: 1.4,
    reliabilityRequirement: 98,
  },
  {
    name: 'AutoParts Global',
    industry: 'Automotive',
    preferredCargo: [CargoType.STANDARD, CargoType.VALUABLE],
    paymentModifier: 1.15,
    reliabilityRequirement: 85,
  },
  {
    name: 'ChemTech Solutions',
    industry: 'Chemicals',
    preferredCargo: [CargoType.HAZARDOUS],
    paymentModifier: 1.6,
    reliabilityRequirement: 90,
  },
  {
    name: 'Luxury Goods Inc',
    industry: 'Retail',
    preferredCargo: [CargoType.VALUABLE],
    paymentModifier: 1.5,
    reliabilityRequirement: 88,
  },
  {
    name: 'Agricultural Exports Co',
    industry: 'Agriculture',
    preferredCargo: [CargoType.STANDARD, CargoType.REFRIGERATED],
    paymentModifier: 1.0,
    reliabilityRequirement: 75,
  },
  {
    name: 'Defense Logistics Agency',
    industry: 'Government',
    preferredCargo: [CargoType.HAZARDOUS, CargoType.VALUABLE],
    paymentModifier: 2.0,
    reliabilityRequirement: 99,
  },
];

const CONTRACT_DESCRIPTIONS = {
  [CargoType.STANDARD]: [
    'Consumer electronics shipment',
    'Textile and clothing goods',
    'Industrial machinery parts',
    'Construction materials',
    'Office supplies bulk order',
  ],
  [CargoType.REFRIGERATED]: [
    'Fresh produce shipment',
    'Pharmaceutical vaccines',
    'Frozen seafood cargo',
    'Dairy products transport',
    'Temperature-sensitive chemicals',
  ],
  [CargoType.HAZARDOUS]: [
    'Industrial chemicals',
    'Fuel and petroleum products',
    'Mining explosives',
    'Radioactive materials',
    'Compressed gas cylinders',
  ],
  [CargoType.VALUABLE]: [
    'Luxury automobiles',
    'Precious metals cargo',
    'High-end electronics',
    'Art and antiques collection',
    'Jewelry shipment',
  ],
};

export function generateEnhancedContracts(ports: Port[], count: number = 10): Contract[] {
  const contracts: Contract[] = [];
  
  for (let i = 0; i < count; i++) {
    const client = CLIENT_PROFILES[Math.floor(Math.random() * CLIENT_PROFILES.length)];
    const cargoType = client.preferredCargo[Math.floor(Math.random() * client.preferredCargo.length)];
    const description = CONTRACT_DESCRIPTIONS[cargoType][Math.floor(Math.random() * CONTRACT_DESCRIPTIONS[cargoType].length)];
    
    const origin = ports[Math.floor(Math.random() * ports.length)];
    let destination = ports[Math.floor(Math.random() * ports.length)];
    while (destination.id === origin.id) {
      destination = ports[Math.floor(Math.random() * ports.length)];
    }
    
    // Calculate distance-based pricing
    const distance = Math.sqrt(
      Math.pow(destination.position.x - origin.position.x, 2) +
      Math.pow(destination.position.z - origin.position.z, 2)
    );
    
    const quantity = Math.floor(Math.random() * 150) + 50;
    const baseValue = quantity * 1000 + distance * 500;
    const tierModifier = 1 + Math.random() * 0.5;
    const urgencyModifier = Math.random() > 0.7 ? 1.5 : 1.0;
    
    const value = Math.floor(baseValue * client.paymentModifier * tierModifier * urgencyModifier);
    
    // Set deadline based on distance and urgency
    const daysToDeadline = urgencyModifier > 1 ? 
      Math.floor(distance / 20) + 2 :
      Math.floor(distance / 10) + 7;
    
    contracts.push({
      id: `contract-enhanced-${Date.now()}-${i}`,
      client: client.name,
      origin,
      destination,
      cargo: cargoType,
      quantity,
      value,
      payment: value,
      deadline: new Date(Date.now() + daysToDeadline * 24 * 60 * 60 * 1000),
      status: ContractStatus.AVAILABLE,
      requiredCapacity: quantity,
      description,
      industry: client.industry,
      reliabilityRequirement: client.reliabilityRequirement,
      tier: urgencyModifier > 1 ? ContractTier.URGENT : ContractTier.STANDARD,
    } as Contract & { description: string; industry: string; reliabilityRequirement: number; tier: ContractTier });
  }
  
  return contracts;
}

export function generateDynamicContract(ports: Port[], playerReputation: number): Contract | null {
  // Generate contracts based on player reputation
  const eligibleClients = CLIENT_PROFILES.filter(
    client => playerReputation >= client.reliabilityRequirement - 10
  );
  
  if (eligibleClients.length === 0) return null;
  
  // Higher reputation unlocks better contracts
  const reputationBonus = playerReputation / 100;
  const contracts = generateEnhancedContracts(ports, 1);
  
  if (contracts.length > 0) {
    contracts[0].value = Math.floor(contracts[0].value * (1 + reputationBonus));
    contracts[0].payment = contracts[0].value;
    return contracts[0];
  }
  
  return null;
}