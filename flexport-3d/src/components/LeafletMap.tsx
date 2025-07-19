// @ts-nocheck
import React, { useEffect, useRef } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { useGameStore } from '../store/gameStore';
import { ShipStatus } from '../types/game.types';
import { calculateGreatCircleRoute } from '../utils/mapUtils';
import { fixPacificRoute, createDatelineAwarePolyline } from '../utils/leafletDatelineFix';
import './LeafletMap.css';

// Fix for default markers
delete (L.Icon.Default.prototype as any)._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: require('leaflet/dist/images/marker-icon-2x.png'),
  iconUrl: require('leaflet/dist/images/marker-icon.png'),
  shadowUrl: require('leaflet/dist/images/marker-shadow.png'),
});

export const LeafletMap: React.FC = () => {
  const mapRef = useRef<L.Map | null>(null);
  const markersRef = useRef<{ [key: string]: L.Marker }>({});
  const routesRef = useRef<{ [key: string]: L.Polyline }>({});
  
  const { fleet, ports, selectShip, selectPort, selectedShipId, selectedPortId } = useGameStore();

  // Convert 3D position to lat/lng
  const positionToLatLng = (position: { x: number, y: number, z: number }): [number, number] => {
    const normalized = {
      x: position.x / 100,
      y: position.y / 100,
      z: position.z / 100
    };
    const lat = Math.asin(normalized.y) * (180 / Math.PI);
    const lng = Math.atan2(normalized.z, -normalized.x) * (180 / Math.PI);
    return [lat, lng];
  };

  useEffect(() => {
    if (!mapRef.current) {
      // Initialize map
      const map = L.map('leaflet-map').setView([20, 0], 2.5);
      
      // Add dark tile layer
      L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>',
        subdomains: 'abcd',
        maxZoom: 20
      }).addTo(map);

      mapRef.current = map;
    }

    const map = mapRef.current;

    // Clear existing markers and routes
    Object.values(markersRef.current).forEach(marker => marker.remove());
    Object.values(routesRef.current).forEach(route => route.remove());
    markersRef.current = {};
    routesRef.current = {};

    // Add port markers
    ports.forEach(port => {
      const [lat, lng] = positionToLatLng(port.position);
      
      const portIcon = L.divIcon({
        className: 'port-marker-leaflet',
        html: `
          <div class="port-icon-container ${selectedPortId === port.id ? 'selected' : ''} ${port.isPlayerOwned ? 'owned' : ''}">
            <div class="port-icon">🏢</div>
            <div class="port-label">${port.name}</div>
          </div>
        `,
        iconSize: [80, 40],
        iconAnchor: [40, 20]
      });

      const marker = L.marker([lat, lng], { icon: portIcon })
        .addTo(map)
        .on('click', () => selectPort(port.id));
      
      markersRef.current[`port-${port.id}`] = marker;
    });

    // Add ship markers and routes
    fleet.forEach(ship => {
      const [lat, lng] = positionToLatLng(ship.position);
      
      const shipIcon = L.divIcon({
        className: 'ship-marker-leaflet',
        html: `
          <div class="ship-icon-container ${selectedShipId === ship.id ? 'selected' : ''}">
            <div class="ship-icon">🚢</div>
            <div class="ship-label">${ship.name}</div>
            <div class="ship-status ${ship.status.toLowerCase()}"></div>
          </div>
        `,
        iconSize: [60, 40],
        iconAnchor: [30, 20]
      });

      const marker = L.marker([lat, lng], { icon: shipIcon })
        .addTo(map)
        .on('click', () => selectShip(ship.id));
      
      markersRef.current[`ship-${ship.id}`] = marker;

      // Draw route if ship is sailing
      if (ship.destination && ship.status === ShipStatus.SAILING) {
        const destLatLng = positionToLatLng(ship.destination.position);
        
        // Debug logging
        console.log(`Route from ${ship.name}: [${lat.toFixed(2)}, ${lng.toFixed(2)}] to [${destLatLng[0].toFixed(2)}, ${destLatLng[1].toFixed(2)}]`);
        
        // Use the Pacific route fix for routes that should cross the Pacific
        const routePoints = fixPacificRoute(
          lat, 
          lng, 
          destLatLng[0], 
          destLatLng[1],
          20 // Number of segments for smooth curve
        );
        
        // Log first few waypoints to verify Pacific crossing
        console.log('First waypoints:', routePoints.slice(0, 5).map(p => `[${p[0].toFixed(2)}, ${p[1].toFixed(2)}]`).join(' -> '));
        
        // Create polylines that handle date line crossing
        const polylines = createDatelineAwarePolyline(routePoints, {
          color: '#3b82f6',
          weight: 2,
          opacity: 0.6,
          dashArray: '5, 10',
          smoothFactor: 1.5
        });
        
        // Add all polyline segments to the map
        polylines.forEach((polyline, index) => {
          polyline.addTo(map);
          routesRef.current[`route-${ship.id}-${index}`] = polyline;
        });
      }
    });

  }, [fleet, ports, selectedShipId, selectedPortId, selectShip, selectPort]);

  return <div id="leaflet-map" style={{ width: '100%', height: '100%' }} />;
};