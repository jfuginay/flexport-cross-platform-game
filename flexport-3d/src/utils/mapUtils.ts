// Utilities for 2D map visualization

/**
 * Calculate great circle route points for 2D map display
 * Handles International Date Line crossing properly
 */
export function calculateGreatCircleRoute(
  startLat: number,
  startLng: number,
  endLat: number,
  endLng: number,
  segments: number = 20
): [number, number][] {
  const points: [number, number][] = [];
  
  // For Pacific crossing (LA to Asia), we need to handle the date line
  // LA is around -118°, Tokyo is around 139°
  // Direct difference: 139 - (-118) = 257° (going east through Americas)
  // Pacific route: -118 to -180, then 180 to 139 = 62° + 41° = 103° (going west)
  
  let adjustedEndLng = endLng;
  const directDistance = Math.abs(endLng - startLng);
  
  // If direct distance is > 180°, we should cross the date line
  if (directDistance > 180) {
    // Adjust the end longitude to create the shorter route
    if (startLng < 0 && endLng > 0) {
      // Western hemisphere to Eastern hemisphere (e.g., LA to Tokyo)
      // Make endLng negative by subtracting 360
      adjustedEndLng = endLng - 360;
    } else if (startLng > 0 && endLng < 0) {
      // Eastern hemisphere to Western hemisphere
      // Make endLng positive by adding 360
      adjustedEndLng = endLng + 360;
    }
  }
  
  // Now interpolate between start and adjusted end
  for (let i = 0; i <= segments; i++) {
    const t = i / segments;
    
    // Simple linear interpolation for this case
    const lat = startLat + (endLat - startLat) * t;
    let lng = startLng + (adjustedEndLng - startLng) * t;
    
    // Normalize longitude to [-180, 180] for display
    while (lng > 180) lng -= 360;
    while (lng < -180) lng += 360;
    
    points.push([lat, lng]);
  }
  
  return points;
}

/**
 * Determine if a route should cross the Pacific or Atlantic
 * Returns true if Pacific route is shorter
 */
export function shouldCrossPacific(startLng: number, endLng: number): boolean {
  const directDistance = Math.abs(endLng - startLng);
  const pacificDistance = startLng < 0 && endLng > 0 
    ? 360 - directDistance 
    : directDistance;
  
  return pacificDistance < directDistance;
}

/**
 * Get ocean name for a given lat/lng coordinate
 */
export function getOceanName(lat: number, lng: number): string {
  // Pacific Ocean (roughly)
  if ((lng < -60 && lng > -180) || (lng > 120 && lng < 180)) {
    if (lat > -60 && lat < 60) return 'Pacific Ocean';
  }
  
  // Atlantic Ocean
  if (lng > -60 && lng < 20) {
    if (lat > -60 && lat < 60) return 'Atlantic Ocean';
  }
  
  // Indian Ocean
  if (lng > 20 && lng < 120) {
    if (lat > -60 && lat < 30) return 'Indian Ocean';
  }
  
  // Arctic Ocean
  if (lat > 60) return 'Arctic Ocean';
  
  // Southern Ocean
  if (lat < -60) return 'Southern Ocean';
  
  return 'Ocean';
}