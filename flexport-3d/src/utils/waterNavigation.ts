// Water navigation utilities for ensuring ships travel only through water

interface Point {
  lat: number;
  lng: number;
}

// Major straits and canals that ships can pass through
const NAVIGABLE_PASSAGES = [
  { name: 'Panama Canal', lat: 9.0, lng: -79.5, radius: 2 },
  { name: 'Suez Canal', lat: 30.0, lng: 32.5, radius: 2 },
  { name: 'Strait of Gibraltar', lat: 36.0, lng: -5.5, radius: 2 },
  { name: 'Strait of Malacca', lat: 2.0, lng: 102.0, radius: 3 },
  { name: 'English Channel', lat: 50.5, lng: 0.0, radius: 2 },
  { name: 'Bosphorus', lat: 41.0, lng: 29.0, radius: 1 },
];

// Simplified land polygons for collision detection
const LAND_MASSES = [
  // North America
  { 
    name: 'North America',
    bounds: [
      { lat: 70, lng: -170 }, { lat: 70, lng: -50 },
      { lat: 25, lng: -50 }, { lat: 25, lng: -170 }
    ]
  },
  // South America
  { 
    name: 'South America',
    bounds: [
      { lat: 12, lng: -80 }, { lat: 12, lng: -35 },
      { lat: -55, lng: -35 }, { lat: -55, lng: -80 }
    ]
  },
  // Africa
  { 
    name: 'Africa',
    bounds: [
      { lat: 37, lng: -18 }, { lat: 37, lng: 52 },
      { lat: -35, lng: 52 }, { lat: -35, lng: -18 }
    ]
  },
  // Eurasia
  { 
    name: 'Eurasia',
    bounds: [
      { lat: 75, lng: -10 }, { lat: 75, lng: 180 },
      { lat: 10, lng: 180 }, { lat: 10, lng: -10 }
    ]
  },
  // Australia
  { 
    name: 'Australia',
    bounds: [
      { lat: -10, lng: 112 }, { lat: -10, lng: 154 },
      { lat: -44, lng: 154 }, { lat: -44, lng: 112 }
    ]
  }
];

/**
 * Check if a point is on land (simplified)
 */
export function isPointOnLand(point: Point): boolean {
  // Check if near a navigable passage
  for (const passage of NAVIGABLE_PASSAGES) {
    const distance = getDistance(point, { lat: passage.lat, lng: passage.lng });
    if (distance < passage.radius) {
      return false; // Allow passage through straits/canals
    }
  }
  
  // Check against land masses
  for (const land of LAND_MASSES) {
    if (isPointInPolygon(point, land.bounds)) {
      return true;
    }
  }
  
  return false;
}

/**
 * Get waypoints for water-only navigation
 */
export function getWaterRoute(start: Point, end: Point): Point[] {
  const waypoints: Point[] = [start];
  
  // Check if direct route crosses land
  if (!routeCrossesLand(start, end)) {
    waypoints.push(end);
    return waypoints;
  }
  
  // Find appropriate waypoints to avoid land
  const strategicWaypoints = findStrategicWaypoints(start, end);
  waypoints.push(...strategicWaypoints);
  waypoints.push(end);
  
  return waypoints;
}

/**
 * Check if a route crosses land
 */
function routeCrossesLand(start: Point, end: Point, segments: number = 20): boolean {
  for (let i = 1; i < segments; i++) {
    const t = i / segments;
    const midPoint = {
      lat: start.lat + (end.lat - start.lat) * t,
      lng: start.lng + (end.lng - start.lng) * t
    };
    
    if (isPointOnLand(midPoint)) {
      return true;
    }
  }
  
  return false;
}

/**
 * Find strategic waypoints for ocean navigation
 */
function findStrategicWaypoints(start: Point, end: Point): Point[] {
  const waypoints: Point[] = [];
  
  // Atlantic to Pacific routes
  if (start.lng < -30 && end.lng > 100) {
    // Route through Panama
    waypoints.push({ lat: 9.0, lng: -79.5 });
  } else if (start.lng > 100 && end.lng < -30) {
    // Reverse Panama route
    waypoints.push({ lat: 9.0, lng: -79.5 });
  }
  
  // Mediterranean to Indian Ocean
  if ((start.lng > -10 && start.lng < 40 && start.lat > 30) &&
      (end.lng > 40 && end.lng < 100)) {
    // Route through Suez
    waypoints.push({ lat: 30.0, lng: 32.5 });
  }
  
  // Europe to Asia around Africa
  if (start.lng < 20 && end.lng > 100 && waypoints.length === 0) {
    // Route around Cape of Good Hope
    waypoints.push({ lat: -34.0, lng: 18.5 });
  }
  
  return waypoints;
}

/**
 * Calculate distance between two points
 */
function getDistance(p1: Point, p2: Point): number {
  const R = 6371; // Earth radius in km
  const dLat = (p2.lat - p1.lat) * Math.PI / 180;
  const dLng = (p2.lng - p1.lng) * Math.PI / 180;
  const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
            Math.cos(p1.lat * Math.PI / 180) * Math.cos(p2.lat * Math.PI / 180) *
            Math.sin(dLng/2) * Math.sin(dLng/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
}

/**
 * Check if point is inside polygon (simplified)
 */
function isPointInPolygon(point: Point, polygon: Point[]): boolean {
  const minLat = Math.min(...polygon.map(p => p.lat));
  const maxLat = Math.max(...polygon.map(p => p.lat));
  const minLng = Math.min(...polygon.map(p => p.lng));
  const maxLng = Math.max(...polygon.map(p => p.lng));
  
  return point.lat >= minLat && point.lat <= maxLat &&
         point.lng >= minLng && point.lng <= maxLng;
}