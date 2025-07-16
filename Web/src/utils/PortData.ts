import { Port, CommodityType } from '@/types';

const createPort = (
  id: string,
  name: string,
  country: string,
  latitude: number,
  longitude: number,
  size: 'small' | 'medium' | 'large' | 'mega',
  facilities: string[],
  demandProfile: Partial<Record<CommodityType, number>> = {},
  supplyProfile: Partial<Record<CommodityType, number>> = {}
): Port => {
  const defaultDemand: Record<CommodityType, number> = {
    steel: 0,
    oil: 0,
    grain: 0,
    electronics: 0,
    textiles: 0,
    chemicals: 0,
    machinery: 0,
    coal: 0,
  };

  const defaultSupply: Record<CommodityType, number> = {
    steel: 0,
    oil: 0,
    grain: 0,
    electronics: 0,
    textiles: 0,
    chemicals: 0,
    machinery: 0,
    coal: 0,
  };

  return {
    id,
    name,
    coordinates: { latitude, longitude },
    country,
    size,
    facilities,
    demandData: { ...defaultDemand, ...demandProfile },
    supplyData: { ...defaultSupply, ...supplyProfile },
    dockingFees: size === 'mega' ? 50000 : size === 'large' ? 30000 : size === 'medium' ? 15000 : 5000,
  };
};

const MAJOR_PORTS: Port[] = [
  createPort(
    'shanghai',
    'Port of Shanghai',
    'China',
    31.2304,
    121.4737,
    'mega',
    ['container', 'bulk', 'liquid', 'automotive', 'cruise'],
    { electronics: 0.9, textiles: 0.8, machinery: 0.7 },
    { electronics: 0.9, textiles: 0.8, machinery: 0.6, steel: 0.4 }
  ),

  createPort(
    'singapore',
    'Port of Singapore',
    'Singapore',
    1.2966,
    103.7764,
    'mega',
    ['container', 'bulk', 'liquid', 'offshore'],
    { oil: 0.8, chemicals: 0.7, electronics: 0.6 },
    { oil: 0.9, chemicals: 0.8, machinery: 0.5 }
  ),

  createPort(
    'rotterdam',
    'Port of Rotterdam',
    'Netherlands',
    51.9225,
    4.4792,
    'mega',
    ['container', 'bulk', 'liquid', 'breakbulk'],
    { oil: 0.9, chemicals: 0.8, grain: 0.6 },
    { oil: 0.7, chemicals: 0.9, machinery: 0.6 }
  ),

  createPort(
    'losangeles',
    'Port of Los Angeles',
    'United States',
    33.7361,
    -118.2639,
    'large',
    ['container', 'cruise', 'automotive', 'breakbulk'],
    { electronics: 0.8, textiles: 0.7, oil: 0.6 },
    { grain: 0.7, machinery: 0.8, coal: 0.4 }
  ),

  createPort(
    'hamburg',
    'Port of Hamburg',
    'Germany',
    53.5439,
    9.9808,
    'large',
    ['container', 'bulk', 'automotive', 'cruise'],
    { electronics: 0.7, machinery: 0.8, textiles: 0.6 },
    { machinery: 0.9, steel: 0.7, chemicals: 0.6 }
  ),

  createPort(
    'dubai',
    'Port of Dubai',
    'UAE',
    25.2854,
    55.3433,
    'large',
    ['container', 'cruise', 'offshore'],
    { electronics: 0.6, textiles: 0.7, machinery: 0.5 },
    { oil: 0.8, chemicals: 0.6 }
  ),

  createPort(
    'hongkong',
    'Port of Hong Kong',
    'Hong Kong',
    22.2793,
    114.1628,
    'large',
    ['container', 'cruise'],
    { electronics: 0.8, textiles: 0.7, machinery: 0.6 },
    { electronics: 0.7, textiles: 0.6 }
  ),

  createPort(
    'longbeach',
    'Port of Long Beach',
    'United States',
    33.7701,
    -118.2037,
    'large',
    ['container', 'automotive', 'liquid'],
    { electronics: 0.8, textiles: 0.6, oil: 0.5 },
    { grain: 0.6, machinery: 0.7 }
  ),

  createPort(
    'antwerp',
    'Port of Antwerp',
    'Belgium',
    51.2194,
    4.4025,
    'large',
    ['container', 'bulk', 'liquid', 'breakbulk'],
    { electronics: 0.6, chemicals: 0.7, machinery: 0.6 },
    { chemicals: 0.8, machinery: 0.7, steel: 0.5 }
  ),

  createPort(
    'qingdao',
    'Port of Qingdao',
    'China',
    36.0986,
    120.3719,
    'large',
    ['container', 'bulk', 'liquid'],
    { oil: 0.7, steel: 0.8, machinery: 0.6 },
    { steel: 0.9, machinery: 0.7, textiles: 0.5 }
  ),

  createPort(
    'busan',
    'Port of Busan',
    'South Korea',
    35.1796,
    129.0756,
    'large',
    ['container', 'bulk', 'automotive'],
    { electronics: 0.7, steel: 0.6, machinery: 0.8 },
    { electronics: 0.8, steel: 0.7, machinery: 0.6 }
  ),

  createPort(
    'valencia',
    'Port of Valencia',
    'Spain',
    39.4699,
    -0.3763,
    'medium',
    ['container', 'cruise', 'automotive'],
    { electronics: 0.5, textiles: 0.6, machinery: 0.5 },
    { textiles: 0.7, grain: 0.5 }
  ),

  createPort(
    'tokyo',
    'Port of Tokyo',
    'Japan',
    35.6298,
    139.7798,
    'large',
    ['container', 'cruise', 'automotive'],
    { oil: 0.8, electronics: 0.6, machinery: 0.7 },
    { electronics: 0.9, machinery: 0.8, steel: 0.6 }
  ),

  createPort(
    'savannah',
    'Port of Savannah',
    'United States',
    32.1313,
    -81.1437,
    'medium',
    ['container', 'bulk', 'breakbulk'],
    { electronics: 0.6, textiles: 0.7, machinery: 0.5 },
    { grain: 0.8, textiles: 0.6, coal: 0.5 }
  ),

  createPort(
    'santos',
    'Port of Santos',
    'Brazil',
    -23.9608,
    -46.3331,
    'large',
    ['container', 'bulk', 'liquid'],
    { electronics: 0.5, machinery: 0.6, chemicals: 0.5 },
    { grain: 0.9, steel: 0.6, oil: 0.7 }
  ),
];

export const PortData = {
  getAllPorts: (): Port[] => MAJOR_PORTS,
  
  getPortById: (id: string): Port | undefined => 
    MAJOR_PORTS.find(port => port.id === id),
    
  getPortsByCountry: (country: string): Port[] =>
    MAJOR_PORTS.filter(port => port.country === country),
    
  getPortsBySize: (size: 'small' | 'medium' | 'large' | 'mega'): Port[] =>
    MAJOR_PORTS.filter(port => port.size === size),
    
  getNearbyPorts: (latitude: number, longitude: number, radiusKm: number): Port[] => {
    return MAJOR_PORTS.filter(port => {
      const distance = calculateDistance(
        latitude, longitude,
        port.coordinates.latitude, port.coordinates.longitude
      );
      return distance <= radiusKm;
    });
  },
  
  getRandomPort: (): Port => {
    return MAJOR_PORTS[Math.floor(Math.random() * MAJOR_PORTS.length)];
  },
};

function calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371; // Earth's radius in kilometers
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = 
    Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * 
    Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
}