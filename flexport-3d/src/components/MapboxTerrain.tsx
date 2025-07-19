import React, { useEffect, useRef, useCallback } from 'react';
import mapboxgl from 'mapbox-gl';
import 'mapbox-gl/dist/mapbox-gl.css';
import { useGameStore } from '../store/gameStore';
import { getWaterRoute, calculateBearing } from '../services/waterNavigation';
import { ShipStatus } from '../types/game.types';

interface MapboxTerrainProps {
  className?: string;
}

// You should replace this with your own Mapbox access token
mapboxgl.accessToken = 'pk.eyJ1IjoiamZ1Z2luYXkiLCJhIjoiY21icmNha2hrMGE0azJscHVzdmVuZTVjOSJ9.oiJoYvc_G-tLUmaSzGVsVQ';

// Ship emoji icon with pulsing animation
const createShipIcon = () => {
  const size = 100;
  const icon: any = {
    width: size,
    height: size,
    data: new Uint8Array(size * size * 4),
    context: null as CanvasRenderingContext2D | null,

    onAdd: function() {
      const canvas = document.createElement('canvas');
      canvas.width = this.width;
      canvas.height = this.height;
      this.context = canvas.getContext('2d');
    },

    render: function() {
      const duration = 2000;
      const t = (performance.now() % duration) / duration;
      const scale = 1 + 0.1 * Math.sin(t * Math.PI * 2);
      
      const context = this.context;
      if (!context) return false;

      // Clear canvas
      context.clearRect(0, 0, this.width, this.height);

      // Draw pulsing circle behind ship
      const radius = 20;
      const outerRadius = radius * 1.5 * (1 + t * 0.5);
      
      context.beginPath();
      context.arc(this.width / 2, this.height / 2, outerRadius, 0, Math.PI * 2);
      context.fillStyle = `rgba(59, 130, 246, ${0.3 * (1 - t)})`;
      context.fill();

      // Draw ship emoji
      context.font = `${30 * scale}px Arial`;
      context.textAlign = 'center';
      context.textBaseline = 'middle';
      context.fillText('🚢', this.width / 2, this.height / 2);

      this.data = context.getImageData(0, 0, this.width, this.height).data;
      return true;
    }
  };
  
  return icon;
};

export const MapboxTerrain: React.FC<MapboxTerrainProps> = ({ className }) => {
  const mapContainerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<mapboxgl.Map | null>(null);
  const animationRef = useRef<number | null>(null);
  const shipAnimationsRef = useRef<Map<string, any>>(new Map());
  
  const { fleet, ports, selectedShipId, selectShip } = useGameStore();

  // Convert 3D position to lat/lng
  const positionToLatLng = useCallback((position: { x: number; y: number; z: number }) => {
    const lat = Math.asin(position.y / 100) * (180 / Math.PI);
    const lng = Math.atan2(position.z, -position.x) * (180 / Math.PI);
    return { lat, lng };
  }, []);

  // Initialize map
  useEffect(() => {
    if (!mapContainerRef.current || mapRef.current) return;

    const map = new mapboxgl.Map({
      container: mapContainerRef.current,
      style: 'mapbox://styles/mapbox/standard-satellite',
      center: [0, 20],
      zoom: 2.5,
      pitch: 45,
      bearing: 0,
      projection: 'globe' as any
    });

    mapRef.current = map;

    map.on('style.load', () => {
      // Add 3D terrain
      map.addSource('mapbox-dem', {
        type: 'raster-dem',
        url: 'mapbox://mapbox.mapbox-terrain-dem-v1',
        tileSize: 512,
        maxzoom: 14
      });
      
      map.setTerrain({ source: 'mapbox-dem', exaggeration: 1.5 });

      // Add custom ship icon
      map.addImage('ship-icon', createShipIcon() as any, { pixelRatio: 2 });

      // Add atmosphere
      map.setFog({
        color: 'rgb(186, 210, 235)',
        'high-color': 'rgb(36, 92, 223)',
        'horizon-blend': 0.02,
        'space-color': 'rgb(11, 11, 25)',
        'star-intensity': 0.6
      });

      // Initialize ship sources and layers
      map.addSource('ships', {
        type: 'geojson',
        data: {
          type: 'FeatureCollection',
          features: []
        }
      });

      map.addLayer({
        id: 'ships-layer',
        type: 'symbol',
        source: 'ships',
        layout: {
          'icon-image': 'ship-icon',
          'icon-size': 1,
          'icon-rotate': ['get', 'bearing'],
          'icon-rotation-alignment': 'map',
          'icon-allow-overlap': true
        }
      });

      // Add ports
      ports.forEach(port => {
        const { lat, lng } = positionToLatLng(port.position);
        
        const el = document.createElement('div');
        el.className = 'port-marker';
        el.style.cssText = `
          width: 30px;
          height: 30px;
          background: #10b981;
          border: 3px solid white;
          border-radius: 50%;
          cursor: pointer;
          box-shadow: 0 2px 8px rgba(0,0,0,0.3);
        `;

        new mapboxgl.Marker(el)
          .setLngLat([lng, lat])
          .setPopup(new mapboxgl.Popup().setHTML(`
            <div style="padding: 8px;">
              <h3 style="margin: 0 0 4px 0; font-size: 16px;">${port.name}</h3>
              <p style="margin: 0; color: #666;">${port.country}</p>
              <p style="margin: 4px 0 0 0; font-size: 12px;">Capacity: ${port.capacity}</p>
            </div>
          `))
          .addTo(map);
      });

      // Handle click on ships
      map.on('click', 'ships-layer', (e) => {
        if (e.features && e.features[0]) {
          const shipId = e.features[0].properties?.id;
          if (shipId) {
            selectShip(shipId);
          }
        }
      });

      // Change cursor on hover
      map.on('mouseenter', 'ships-layer', () => {
        map.getCanvas().style.cursor = 'pointer';
      });
      map.on('mouseleave', 'ships-layer', () => {
        map.getCanvas().style.cursor = '';
      });
    });

    // Cleanup
    return () => {
      if (animationRef.current) {
        cancelAnimationFrame(animationRef.current);
      }
      map.remove();
    };
  }, [ports, selectShip, positionToLatLng]);

  // Animate ships
  useEffect(() => {
    if (!mapRef.current || !mapRef.current.isStyleLoaded()) return;

    const map = mapRef.current;
    const animations = shipAnimationsRef.current;

    // Initialize ship animations
    fleet.forEach(ship => {
      if (!animations.has(ship.id)) {
        const startPos = positionToLatLng(ship.position);
        
        animations.set(ship.id, {
          currentPosition: startPos,
          targetPosition: startPos,
          route: [],
          routeIndex: 0,
          progress: 0,
          speed: 0.02 // Adjust speed as needed
        });
      }

      const anim = animations.get(ship.id);
      
      // Update route if ship has new destination
      if (ship.destination && ship.status === ShipStatus.SAILING) {
        const destPos = positionToLatLng(ship.destination.position);
        
        if (anim.route.length === 0 || 
            anim.targetPosition.lat !== destPos.lat || 
            anim.targetPosition.lng !== destPos.lng) {
          
          // Calculate water route
          anim.route = getWaterRoute(anim.currentPosition, destPos);
          anim.routeIndex = 0;
          anim.progress = 0;
          anim.targetPosition = destPos;
        }
      }
    });

    // Animation loop with timing
    let lastTime = 0;
    const animate = (timestamp: number) => {
      if (!lastTime) lastTime = timestamp;
      const deltaTime = (timestamp - lastTime) / 1000; // Convert to seconds
      lastTime = timestamp;

      const features = fleet.map(ship => {
        const anim = animations.get(ship.id);
        if (!anim) return null;

        // Update position along route
        if (anim.route.length > 0 && anim.routeIndex < anim.route.length - 1) {
          const from = anim.route[anim.routeIndex];
          const to = anim.route[anim.routeIndex + 1];
          
          // Calculate distance and adjust speed based on it
          const distance = Math.sqrt(
            Math.pow(to.lat - from.lat, 2) + 
            Math.pow(to.lng - from.lng, 2)
          );
          
          // Speed normalized by distance and time
          const normalizedSpeed = anim.speed / (distance || 1);
          
          // Update progress based on actual time passed
          anim.progress += normalizedSpeed * deltaTime * 60;
          
          if (anim.progress >= 1) {
            anim.progress = 0;
            anim.routeIndex++;
            
            // Check if we've reached the destination
            if (anim.routeIndex >= anim.route.length - 1) {
              anim.route = [];
              anim.routeIndex = 0;
            }
          }
          
          // Interpolate position
          const t = Math.min(anim.progress, 1);
          anim.currentPosition = {
            lat: from.lat + (to.lat - from.lat) * t,
            lng: from.lng + (to.lng - from.lng) * t
          };
          
          // Calculate bearing for ship rotation
          const bearing = calculateBearing(from, to);
          anim.bearing = bearing;
          
          return {
            type: 'Feature',
            geometry: {
              type: 'Point',
              coordinates: [anim.currentPosition.lng, anim.currentPosition.lat]
            },
            properties: {
              id: ship.id,
              name: ship.name,
              bearing: bearing,
              status: ship.status
            }
          };
        } else {
          // Ship at rest
          return {
            type: 'Feature',
            geometry: {
              type: 'Point',
              coordinates: [anim.currentPosition.lng, anim.currentPosition.lat]
            },
            properties: {
              id: ship.id,
              name: ship.name,
              bearing: anim.bearing || 0,
              status: ship.status
            }
          };
        }
      }).filter(f => f !== null);

      // Update map source
      const source = map.getSource('ships') as mapboxgl.GeoJSONSource;
      if (source) {
        source.setData({
          type: 'FeatureCollection',
          features: features as any
        });
      }

      // Trigger repaint for animated icon
      map.triggerRepaint();

      animationRef.current = requestAnimationFrame(animate);
    };

    animate(0);

    return () => {
      if (animationRef.current) {
        cancelAnimationFrame(animationRef.current);
      }
    };
  }, [fleet, positionToLatLng]);

  // Follow selected ship
  useEffect(() => {
    if (!mapRef.current || !selectedShipId) return;

    const ship = fleet.find(s => s.id === selectedShipId);
    if (!ship) return;

    const anim = shipAnimationsRef.current.get(ship.id);
    if (!anim) return;

    // Camera follow animation
    const followShip = () => {
      const map = mapRef.current;
      if (!map) return;

      const camera = map.getFreeCameraOptions();
      
      // Position camera behind and above the ship
      const altitude = 5000;
      const distance = 0.05; // degrees
      const bearing = anim.bearing || 0;
      
      const cameraLng = anim.currentPosition.lng - distance * Math.sin(bearing * Math.PI / 180);
      const cameraLat = anim.currentPosition.lat - distance * Math.cos(bearing * Math.PI / 180);
      
      camera.position = mapboxgl.MercatorCoordinate.fromLngLat(
        [cameraLng, cameraLat],
        altitude
      );
      camera.lookAtPoint([anim.currentPosition.lng, anim.currentPosition.lat]);
      
      map.setFreeCameraOptions(camera);
    };

    // Initial camera position
    mapRef.current.flyTo({
      center: [anim.currentPosition.lng, anim.currentPosition.lat],
      zoom: 8,
      pitch: 75,
      bearing: 0,
      duration: 2000
    });

    // Set up follow interval if ship is sailing
    if (ship.status === ShipStatus.SAILING) {
      const interval = setInterval(followShip, 100);
      return () => clearInterval(interval);
    }
  }, [selectedShipId, fleet]);

  return (
    <div 
      ref={mapContainerRef} 
      className={className}
      style={{ 
        width: '100%', 
        height: '100%',
        position: 'relative'
      }}
    />
  );
};