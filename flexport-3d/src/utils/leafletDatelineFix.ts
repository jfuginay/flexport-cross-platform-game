import L from 'leaflet';

/**
 * Create a polyline that properly handles International Date Line crossing
 * Leaflet has issues with routes that cross from negative to positive longitude
 */
export function createDatelineAwarePolyline(
  points: [number, number][],
  options: L.PolylineOptions
): L.Polyline[] {
  const polylines: L.Polyline[] = [];
  const segments: [number, number][][] = [];
  let currentSegment: [number, number][] = [];
  
  for (let i = 0; i < points.length; i++) {
    const point = points[i];
    
    if (currentSegment.length > 0) {
      const lastPoint = currentSegment[currentSegment.length - 1];
      const lngDiff = point[1] - lastPoint[1];
      
      // Check if we're crossing the date line
      if (Math.abs(lngDiff) > 180) {
        // Split the segment at the date line
        segments.push(currentSegment);
        currentSegment = [point];
      } else {
        currentSegment.push(point);
      }
    } else {
      currentSegment.push(point);
    }
  }
  
  // Add the last segment
  if (currentSegment.length > 0) {
    segments.push(currentSegment);
  }
  
  // Create polylines for each segment
  segments.forEach(segment => {
    if (segment.length > 1) {
      polylines.push(L.polyline(segment, options));
    }
  });
  
  return polylines;
}

/**
 * Fix route points for Pacific crossing
 * Ensures the route goes west from LA to Asia, not east
 */
export function fixPacificRoute(
  startLat: number,
  startLng: number,
  endLat: number,
  endLng: number,
  segments: number = 20
): [number, number][] {
  const points: [number, number][] = [];
  
  // Special handling for routes that should cross the Pacific
  // LA to Asia: startLng negative (around -118), endLng positive (around 139)
  if (startLng < -100 && endLng > 100) {
    // This is likely LA to Asia - force Pacific crossing
    // We'll create waypoints that explicitly go west
    
    // First segment: from start to near date line on the American side
    for (let i = 0; i <= segments / 2; i++) {
      const t = i / (segments / 2);
      const lat = startLat + (endLat - startLat) * t * 0.5;
      const lng = startLng + (-180 - startLng) * t; // Go to -180
      points.push([lat, lng]);
    }
    
    // Second segment: from date line Asian side to destination
    for (let i = 1; i <= segments / 2; i++) {
      const t = i / (segments / 2);
      const lat = startLat + (endLat - startLat) * (0.5 + t * 0.5);
      const lng = 180 + (endLng - 180) * t; // From 180 to destination
      points.push([lat, lng]);
    }
  } else {
    // For other routes, use simple interpolation
    for (let i = 0; i <= segments; i++) {
      const t = i / segments;
      const lat = startLat + (endLat - startLat) * t;
      const lng = startLng + (endLng - startLng) * t;
      points.push([lat, lng]);
    }
  }
  
  return points;
}