// Water navigation service for ships
// Uses pre-defined shipping lanes and avoids land masses

interface LatLng {
  lat: number;
  lng: number;
}

// Major shipping lane waypoints
const SHIPPING_LANES = {
  // Atlantic routes
  NORTH_ATLANTIC: [
    { lat: 40.7128, lng: -74.0060 }, // New York
    { lat: 45.0, lng: -50.0 }, // Mid Atlantic
    { lat: 51.5074, lng: -0.1278 }, // London
  ],
  SOUTH_ATLANTIC: [
    { lat: -22.9068, lng: -43.1729 }, // Rio
    { lat: -30.0, lng: -20.0 }, // Mid Atlantic
    { lat: -33.9249, lng: 18.4241 }, // Cape Town
  ],
  // Pacific routes
  TRANS_PACIFIC: [
    { lat: 35.6762, lng: 139.6503 }, // Tokyo
    { lat: 30.0, lng: 180.0 }, // Mid Pacific
    { lat: 30.0, lng: -150.0 }, // Mid Pacific
    { lat: 34.0522, lng: -118.2437 }, // Los Angeles
  ],
  // Indian Ocean routes
  INDIAN_OCEAN: [
    { lat: 1.3521, lng: 103.8198 }, // Singapore
    { lat: -10.0, lng: 90.0 }, // Mid Indian
    { lat: -20.0, lng: 70.0 }, // Mid Indian
    { lat: 18.9756, lng: 72.8257 }, // Mumbai
  ],
  // Mediterranean
  MEDITERRANEAN: [
    { lat: 36.1408, lng: -5.3536 }, // Gibraltar
    { lat: 36.8, lng: 3.0 }, // Algiers region
    { lat: 35.0, lng: 18.0 }, // Mid Med
    { lat: 31.2001, lng: 29.9187 }, // Port Said
  ],
  // Suez Canal
  SUEZ_ROUTE: [
    { lat: 31.2001, lng: 29.9187 }, // Port Said
    { lat: 30.0, lng: 32.5 }, // Canal
    { lat: 29.9668, lng: 32.5499 }, // Suez
  ],
  // Panama Canal
  PANAMA_ROUTE: [
    { lat: 9.3773, lng: -79.9205 }, // Colon
    { lat: 9.0, lng: -79.5 }, // Canal
    { lat: 8.9936, lng: -79.5198 }, // Panama City
  ],
};

// Check if a direct path crosses land (simplified)
function crossesLand(start: LatLng, end: LatLng): boolean {
  // Simplified check - in reality would use more sophisticated geography data
  
  // Check if crossing Africa
  if (start.lng < 20 && end.lng > 20 && 
      start.lat > -35 && start.lat < 37 &&
      end.lat > -35 && end.lat < 37) {
    return true;
  }
  
  // Check if crossing Americas
  if ((start.lng < -30 && end.lng > -120) || 
      (start.lng > -120 && end.lng < -30)) {
    if (start.lat > -56 && start.lat < 72 &&
        end.lat > -56 && end.lat < 72) {
      // Allow Panama Canal crossing
      if (Math.abs(start.lat - 9) < 5 && Math.abs(end.lat - 9) < 5) {
        return false;
      }
      return true;
    }
  }
  
  // Check if crossing Asia
  if (start.lng > 60 && start.lng < 150 &&
      end.lng > 60 && end.lng < 150 &&
      start.lat > 0 && start.lat < 70) {
    return true;
  }
  
  return false;
}

// Find nearest shipping lane waypoint
function findNearestWaypoint(pos: LatLng, waypoints: LatLng[]): number {
  let minDist = Infinity;
  let nearestIdx = 0;
  
  waypoints.forEach((wp, idx) => {
    const dist = Math.sqrt(
      Math.pow(wp.lat - pos.lat, 2) + 
      Math.pow(wp.lng - pos.lng, 2)
    );
    if (dist < minDist) {
      minDist = dist;
      nearestIdx = idx;
    }
  });
  
  return nearestIdx;
}

// Get water route between two points
export function getWaterRoute(start: LatLng, end: LatLng): LatLng[] {
  const route: LatLng[] = [start];
  
  // Check if direct route is possible
  if (!crossesLand(start, end)) {
    // Add some intermediate points for smoother animation
    const steps = 20;
    for (let i = 1; i < steps; i++) {
      const t = i / steps;
      route.push({
        lat: start.lat + (end.lat - start.lat) * t,
        lng: start.lng + (end.lng - start.lng) * t
      });
    }
    route.push(end);
    return route;
  }
  
  // Find appropriate shipping lane
  let bestRoute: LatLng[] = [];
  let minDistance = Infinity;
  
  // Check all shipping lanes
  Object.values(SHIPPING_LANES).forEach(lane => {
    const startIdx = findNearestWaypoint(start, lane);
    const endIdx = findNearestWaypoint(end, lane);
    
    if (startIdx !== endIdx) {
      const routeSegment = startIdx < endIdx 
        ? lane.slice(startIdx, endIdx + 1)
        : lane.slice(endIdx, startIdx + 1).reverse();
      
      const totalDist = 
        Math.sqrt(Math.pow(lane[startIdx].lat - start.lat, 2) + 
                  Math.pow(lane[startIdx].lng - start.lng, 2)) +
        Math.sqrt(Math.pow(lane[endIdx].lat - end.lat, 2) + 
                  Math.pow(lane[endIdx].lng - end.lng, 2));
      
      if (totalDist < minDistance) {
        minDistance = totalDist;
        bestRoute = [...routeSegment];
      }
    }
  });
  
  // If found a shipping lane route
  if (bestRoute.length > 0) {
    // Connect start to first waypoint
    const steps = 10;
    for (let i = 1; i < steps; i++) {
      const t = i / steps;
      route.push({
        lat: start.lat + (bestRoute[0].lat - start.lat) * t,
        lng: start.lng + (bestRoute[0].lng - start.lng) * t
      });
    }
    
    // Add shipping lane waypoints
    route.push(...bestRoute);
    
    // Connect last waypoint to end
    const lastWp = bestRoute[bestRoute.length - 1];
    for (let i = 1; i <= steps; i++) {
      const t = i / steps;
      route.push({
        lat: lastWp.lat + (end.lat - lastWp.lat) * t,
        lng: lastWp.lng + (end.lng - lastWp.lng) * t
      });
    }
  } else {
    // Fallback: go around Africa or Americas
    if (start.lng < 0 && end.lng > 50) {
      // Go around Africa
      route.push(...SHIPPING_LANES.SOUTH_ATLANTIC);
      route.push(...SHIPPING_LANES.INDIAN_OCEAN);
    } else {
      // Use Panama canal
      route.push(...SHIPPING_LANES.PANAMA_ROUTE);
    }
    route.push(end);
  }
  
  return route;
}

// Calculate bearing between two points
export function calculateBearing(start: LatLng, end: LatLng): number {
  const dLng = (end.lng - start.lng) * Math.PI / 180;
  const lat1 = start.lat * Math.PI / 180;
  const lat2 = end.lat * Math.PI / 180;
  
  const y = Math.sin(dLng) * Math.cos(lat2);
  const x = Math.cos(lat1) * Math.sin(lat2) -
            Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLng);
  
  const bearing = Math.atan2(y, x) * 180 / Math.PI;
  return (bearing + 360) % 360;
}