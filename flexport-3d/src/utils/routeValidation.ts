import * as THREE from 'three';

// Define land masses (more accurate bounding boxes for continents)
const LAND_REGIONS = [
  // North America (excluding Caribbean)
  { minLat: 25, maxLat: 72, minLng: -170, maxLng: -52 },
  // Central America
  { minLat: 7, maxLat: 25, minLng: -118, maxLng: -77 },
  // South America  
  { minLat: -56, maxLat: 13, minLng: -82, maxLng: -34 },
  // Europe (Western)
  { minLat: 36, maxLat: 71, minLng: -10, maxLng: 25 },
  // Europe (Eastern) & Russia
  { minLat: 35, maxLat: 75, minLng: 25, maxLng: 180 },
  // Africa
  { minLat: -35, maxLat: 37, minLng: -18, maxLng: 52 },
  // Middle East
  { minLat: 12, maxLat: 42, minLng: 26, maxLng: 63 },
  // India
  { minLat: 8, maxLat: 35, minLng: 68, maxLng: 88 },
  // Southeast Asia
  { minLat: -10, maxLat: 25, minLng: 92, maxLng: 125 },
  // China/East Asia
  { minLat: 18, maxLat: 54, minLng: 73, maxLng: 135 },
  // Australia
  { minLat: -44, maxLat: -10, minLng: 112, maxLng: 154 },
  // Greenland
  { minLat: 59, maxLat: 84, minLng: -73, maxLng: -12 },
  // Antarctica (simplified)
  { minLat: -90, maxLat: -60, minLng: -180, maxLng: 180 },
];

// Ocean corridors for shipping
const OCEAN_ROUTES = [
  // Atlantic Ocean
  { name: 'Atlantic', minLat: -60, maxLat: 60, minLng: -80, maxLng: 20 },
  // Pacific Ocean
  { name: 'Pacific', minLat: -60, maxLat: 60, minLng: 120, maxLng: -120 },
  // Indian Ocean
  { name: 'Indian', minLat: -60, maxLat: 30, minLng: 20, maxLng: 120 },
  // Mediterranean Sea
  { name: 'Mediterranean', minLat: 30, maxLat: 45, minLng: -5, maxLng: 35 },
];

export function isPointOnLand(lat: number, lng: number): boolean {
  return LAND_REGIONS.some(region => 
    lat >= region.minLat && lat <= region.maxLat &&
    lng >= region.minLng && lng <= region.maxLng
  );
}

export function isValidShipRoute(startLat: number, startLng: number, endLat: number, endLng: number): boolean {
  // Ships can't cross major land masses
  // This is simplified - in reality we'd use more complex pathfinding
  
  // Check if route crosses continents
  const steps = 20;
  for (let i = 0; i <= steps; i++) {
    const t = i / steps;
    const lat = startLat + (endLat - startLat) * t;
    const lng = startLng + (endLng - startLng) * t;
    
    if (isPointOnLand(lat, lng)) {
      // Check if it's near a canal (Panama, Suez)
      const nearPanama = Math.abs(lat - 9) < 2 && Math.abs(lng - (-80)) < 5;
      const nearSuez = Math.abs(lat - 30) < 2 && Math.abs(lng - 32) < 5;
      
      if (!nearPanama && !nearSuez) {
        return false; // Route crosses land without canal
      }
    }
  }
  
  return true;
}

export function getWaterRouteBetweenPorts(startPos: THREE.Vector3, endPos: THREE.Vector3, earthRadius: number): THREE.Vector3[] {
  const startNorm = startPos.clone().normalize();
  const endNorm = endPos.clone().normalize();
  
  const startLat = Math.asin(startNorm.y) * (180 / Math.PI);
  const startLng = Math.atan2(startNorm.z, -startNorm.x) * (180 / Math.PI);
  const endLat = Math.asin(endNorm.y) * (180 / Math.PI);
  const endLng = Math.atan2(endNorm.z, -endNorm.x) * (180 / Math.PI);
  
  const waypoints: THREE.Vector3[] = [startPos];
  
  // Check if direct route is valid
  if (isValidShipRoute(startLat, startLng, endLat, endLng)) {
    waypoints.push(endPos);
    return waypoints;
  }
  
  // Add strategic waypoints to avoid continents
  // These are common shipping lane waypoints
  const strategicPoints = [
    { name: 'Gibraltar', lat: 36, lng: -5 }, // Mediterranean entrance
    { name: 'Suez', lat: 30, lng: 32 }, // Suez Canal
    { name: 'Panama', lat: 9, lng: -80 }, // Panama Canal
    { name: 'Cape Good Hope', lat: -34, lng: 18 }, // Around Africa
    { name: 'Cape Horn', lat: -56, lng: -68 }, // Around South America
    { name: 'Malacca', lat: 2, lng: 102 }, // Strait of Malacca
  ];
  
  // Simple waypoint selection based on start/end positions
  // This is a simplified version - real pathfinding would be more complex
  for (const point of strategicPoints) {
    const phi = (90 - point.lat) * (Math.PI / 180);
    const theta = (point.lng + 180) * (Math.PI / 180);
    
    const x = -(earthRadius * Math.sin(phi) * Math.cos(theta));
    const y = earthRadius * Math.cos(phi);
    const z = earthRadius * Math.sin(phi) * Math.sin(theta);
    
    const waypointPos = new THREE.Vector3(x, y, z);
    
    // Add waypoint if it helps avoid land
    if (isValidShipRoute(startLat, startLng, point.lat, point.lng) &&
        isValidShipRoute(point.lat, point.lng, endLat, endLng)) {
      waypoints.push(waypointPos);
      break;
    }
  }
  
  waypoints.push(endPos);
  return waypoints;
}

// Calculate if ship is over water based on its position
export function isShipOverWater(position: THREE.Vector3, earthRadius: number): boolean {
  // Convert 3D position back to lat/lng
  const normalized = position.clone().normalize();
  const lat = Math.asin(normalized.y) * (180 / Math.PI);
  const lng = Math.atan2(normalized.z, -normalized.x) * (180 / Math.PI);
  
  return !isPointOnLand(lat, lng);
}

// Get the nearest water point from a given position
export function getNearestWaterPoint(position: THREE.Vector3, earthRadius: number): THREE.Vector3 {
  const normalized = position.clone().normalize();
  const lat = Math.asin(normalized.y) * (180 / Math.PI);
  const lng = Math.atan2(normalized.z, -normalized.x) * (180 / Math.PI);
  
  if (!isPointOnLand(lat, lng)) {
    return position; // Already over water
  }
  
  // Search in expanding circles for nearest water
  const searchRadius = 5; // degrees
  let nearestWater = position;
  let minDistance = Infinity;
  
  for (let dlat = -searchRadius; dlat <= searchRadius; dlat += 0.5) {
    for (let dlng = -searchRadius; dlng <= searchRadius; dlng += 0.5) {
      const testLat = lat + dlat;
      const testLng = lng + dlng;
      
      if (!isPointOnLand(testLat, testLng)) {
        const phi = (90 - testLat) * (Math.PI / 180);
        const theta = (testLng + 180) * (Math.PI / 180);
        
        const x = -(earthRadius * Math.sin(phi) * Math.cos(theta));
        const y = earthRadius * Math.cos(phi);
        const z = earthRadius * Math.sin(phi) * Math.sin(theta);
        
        const testPos = new THREE.Vector3(x, y, z);
        const distance = position.distanceTo(testPos);
        
        if (distance < minDistance) {
          minDistance = distance;
          nearestWater = testPos;
        }
      }
    }
  }
  
  return nearestWater;
}