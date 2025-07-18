import * as THREE from 'three';

export interface GeoCoords {
  lat: number;
  lng: number;
}

export interface PortLocation {
  name: string;
  country: string;
  coords: GeoCoords;
}

// Convert latitude/longitude to 3D position on sphere
// Updated to match Three.js coordinate system with Mapbox textures
export function latLngToPosition(lat: number, lng: number, radius: number): THREE.Vector3 {
  // Convert to radians
  const latRad = lat * (Math.PI / 180);
  const lngRad = lng * (Math.PI / 180);
  
  // Calculate position
  // Note: In Three.js, Y is up, and we need to adjust for texture mapping
  const x = radius * Math.cos(latRad) * Math.sin(lngRad);
  const y = radius * Math.sin(latRad);
  const z = radius * Math.cos(latRad) * Math.cos(lngRad);
  
  return new THREE.Vector3(x, y, z);
}

// Real-world port locations (exact coordinates)
export const realPortLocations: PortLocation[] = [
  { name: 'Los Angeles', country: 'USA', coords: { lat: 33.7405, lng: -118.2723 } },
  { name: 'Shanghai', country: 'China', coords: { lat: 31.2304, lng: 121.4737 } },
  { name: 'Singapore', country: 'Singapore', coords: { lat: 1.3521, lng: 103.8198 } },
  { name: 'Rotterdam', country: 'Netherlands', coords: { lat: 51.9244, lng: 4.4777 } },
  { name: 'Dubai', country: 'UAE', coords: { lat: 25.2048, lng: 55.2708 } },
  { name: 'Hong Kong', country: 'China', coords: { lat: 22.3193, lng: 114.1694 } },
  { name: 'Hamburg', country: 'Germany', coords: { lat: 53.5511, lng: 9.9937 } },
  { name: 'New York', country: 'USA', coords: { lat: 40.7128, lng: -74.0060 } },
  { name: 'Tokyo', country: 'Japan', coords: { lat: 35.6762, lng: 139.6503 } },
  { name: 'Sydney', country: 'Australia', coords: { lat: -33.8688, lng: 151.2093 } },
  { name: 'Antwerp', country: 'Belgium', coords: { lat: 51.2194, lng: 4.4025 } },
  { name: 'Busan', country: 'South Korea', coords: { lat: 35.1796, lng: 129.0756 } },
  { name: 'Panama City', country: 'Panama', coords: { lat: 8.9824, lng: -79.5199 } },
  { name: 'Santos', country: 'Brazil', coords: { lat: -23.9608, lng: -46.3336 } },
  { name: 'Cape Town', country: 'South Africa', coords: { lat: -33.9249, lng: 18.4241 } },
];

// Get 3D position for a port
export function getPortPosition(portName: string, radius: number): THREE.Vector3 {
  const port = realPortLocations.find(p => p.name === portName);
  if (!port) {
    console.warn(`Port ${portName} not found, using default position`);
    return new THREE.Vector3(0, radius, 0);
  }
  
  const position = latLngToPosition(port.coords.lat, port.coords.lng, radius);
  // Elevate ports above surface to prevent z-fighting
  const elevated = position.clone().normalize().multiplyScalar(radius + 0.5);
  return elevated;
}

// Calculate great circle distance between two points on sphere
export function calculateDistance(pos1: THREE.Vector3, pos2: THREE.Vector3, radius: number): number {
  const angle = pos1.angleTo(pos2);
  return angle * radius;
}

// Get interpolated position along great circle route
export function interpolateRoute(start: THREE.Vector3, end: THREE.Vector3, t: number): THREE.Vector3 {
  // Quaternion slerp for smooth interpolation along sphere surface
  const startQuat = new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 1, 0), start.clone().normalize());
  const endQuat = new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 1, 0), end.clone().normalize());
  
  const interpQuat = new THREE.Quaternion().slerpQuaternions(startQuat, endQuat, t);
  const interpVector = new THREE.Vector3(0, 1, 0).applyQuaternion(interpQuat);
  
  return interpVector.multiplyScalar(start.length());
}