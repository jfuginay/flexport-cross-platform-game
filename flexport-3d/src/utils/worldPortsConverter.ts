import worldPortsData from '../data/worldPorts.json';
import majorPortsData from '../data/majorPorts.json';
import { Port } from '../types/game.types';

interface WorldPortData {
  CITY: string;
  STATE: string;
  COUNTRY: string;
  LATITUDE: number;
  LONGITUDE: number;
}

export function generatePortsFromWorldData(): Port[] {
  console.log('generatePortsFromWorldData called');
  const EARTH_RADIUS = 100; // Match the Earth sphere radius
  const ports: Port[] = [];
  
  console.log('worldPortsData:', worldPortsData ? 'loaded' : 'not loaded', 'length:', worldPortsData?.length);
  console.log('majorPortsData:', majorPortsData ? 'loaded' : 'not loaded');
  
  // First, add our curated major ports with accurate traffic data
  const majorPortsMap = new Map<string, any>();
  if (majorPortsData?.features) {
    majorPortsData.features.forEach(feature => {
      const key = `${feature.properties.name}-${feature.properties.country}`;
      majorPortsMap.set(key, feature);
    });
  }
  
  // Process world ports
  const worldPorts = worldPortsData as WorldPortData[];
  
  if (!worldPorts || worldPorts.length === 0) {
    console.error('No world ports data available!');
    return [];
  }
  
  // Create a scoring system to identify likely major ports
  const portScores = worldPorts.map((port, index) => {
    let score = 0;
    
    // Capital cities often have major ports
    const capitalCities = ['Singapore', 'Tokyo', 'London', 'Amsterdam', 'Copenhagen', 'Dubai', 'Hong Kong'];
    if (capitalCities.includes(port.CITY)) score += 50;
    
    // Known major port cities
    const majorCities = ['Shanghai', 'Rotterdam', 'Los Angeles', 'Hamburg', 'Antwerp', 'Busan', 
                        'Valencia', 'Barcelona', 'Yokohama', 'Santos', 'Mumbai', 'Chennai',
                        'Aalborg', 'Aabenraa']; // Include Danish ports
    if (majorCities.some(city => port.CITY.includes(city))) score += 100;
    
    // Coastal countries with high trade volume
    const tradingCountries = ['China', 'United States', 'Singapore', 'Netherlands', 'Germany', 
                             'South Korea', 'Japan', 'United Kingdom', 'Belgium', 'Spain',
                             'Denmark', 'Morocco']; // Include Denmark and Morocco
    if (tradingCountries.includes(port.COUNTRY)) score += 30;
    
    return { port, index, score };
  });
  
  // Sort by score and take top ports
  const sortedPorts = portScores.sort((a, b) => b.score - a.score);
  const selectedPorts = sortedPorts.slice(0, 200); // Take top 200 ports
  
  // Track unique ports to avoid duplicates
  const uniquePorts = new Set<string>();
  
  selectedPorts.forEach(({ port, index, score }) => {
    // Create a unique key for this port
    const portKey = `${port.CITY}-${port.COUNTRY}`;
    
    // Skip if we've already added this port
    if (uniquePorts.has(portKey)) {
      return;
    }
    uniquePorts.add(portKey);
    const lat = port.LATITUDE;
    const lng = port.LONGITUDE;
    
    // Convert lat/lng to 3D coordinates
    const phi = (90 - lat) * (Math.PI / 180);
    const theta = (lng + 180) * (Math.PI / 180);
    
    const x = -(EARTH_RADIUS * Math.sin(phi) * Math.cos(theta));
    const y = EARTH_RADIUS * Math.cos(phi);
    const z = EARTH_RADIUS * Math.sin(phi) * Math.sin(theta);
    
    // Check if this matches a major port
    const majorPortKey = `${port.CITY}-${port.COUNTRY}`;
    const majorPortData = majorPortsMap.get(majorPortKey);
    
    let capacity, berths, loadingSpeed;
    
    if (majorPortData) {
      // Use real data for major ports
      const trafficTEU = majorPortData.properties.container_traffic_2022_teu * 1000;
      capacity = Math.floor(trafficTEU / 10000);
      berths = Math.floor(trafficTEU / 1000000) + 10;
      loadingSpeed = 80 + Math.floor(trafficTEU / 500000);
    } else {
      // Generate realistic data based on score
      const baseFactor = score / 100;
      capacity = Math.floor(500 + baseFactor * 2000 + Math.random() * 1000);
      berths = Math.floor(5 + baseFactor * 10 + Math.random() * 5);
      loadingSpeed = Math.floor(40 + baseFactor * 30 + Math.random() * 20);
    }
    
    ports.push({
      id: `port-${index}-${port.CITY.replace(/\s+/g, '-').toLowerCase()}`,
      name: `Port of ${port.CITY}`,
      position: { x, y, z },
      country: port.COUNTRY,
      capacity: capacity,
      currentLoad: Math.floor(Math.random() * 0.7 * capacity),
      isPlayerOwned: port.CITY === 'Los Angeles' && port.COUNTRY === 'United States',
      berths: berths,
      availableBerths: Math.floor(berths * 0.3) + 1,
      loadingSpeed: loadingSpeed,
      dockedShips: [],
      contracts: []
    });
  });
  
  // Sort by capacity to ensure major ports appear prominently
  ports.sort((a, b) => b.capacity - a.capacity);
  console.log('generatePortsFromWorldData returning:', ports.length, 'ports');
  return ports;
}