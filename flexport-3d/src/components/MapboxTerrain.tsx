// @ts-nocheck
import React, { useEffect, useRef, useCallback } from 'react';
import mapboxgl from 'mapbox-gl';
import 'mapbox-gl/dist/mapbox-gl.css';
import './MapboxTerrain.css';
import { useGameStore } from '../store/gameStore';
import { getWaterRoute, calculateBearing } from '../services/waterNavigation';
import { ShipStatus } from '../types/game.types';

interface MapboxTerrainProps {
  className?: string;
}

// Mapbox access token
const MAPBOX_TOKEN = process.env.REACT_APP_MAPBOX_TOKEN || 'pk.eyJ1IjoiamZ1Z2luYXkiLCJhIjoiY21icmNha2hrMGE0azJscHVzdmVuZTVjOSJ9.oiJoYvc_G-tLUmaSzGVsVQ';

if (!MAPBOX_TOKEN) {
  console.error('Mapbox token is not set');
} else {
  mapboxgl.accessToken = MAPBOX_TOKEN;
  console.log('Mapbox token set successfully');
}

// Ship emoji icon with pulsing animation
const createShipIcon = (status: string = 'idle') => {
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

      // Draw pulsing circle behind ship with status-based color
      const radius = 25;
      const outerRadius = radius * 1.5 * (1 + t * 0.5);
      
      // Different colors for different statuses
      let color = 'rgba(59, 130, 246, '; // Blue for idle
      if (status === 'SAILING') {
        color = 'rgba(16, 185, 129, '; // Green for sailing
      } else if (status === 'LOADING' || status === 'UNLOADING') {
        color = 'rgba(251, 191, 36, '; // Yellow for loading/unloading
      }
      
      context.beginPath();
      context.arc(this.width / 2, this.height / 2, outerRadius, 0, Math.PI * 2);
      context.fillStyle = color + `${0.4 * (1 - t)})`;
      context.fill();
      
      // Draw solid background circle
      context.beginPath();
      context.arc(this.width / 2, this.height / 2, radius, 0, Math.PI * 2);
      context.fillStyle = color + '0.8)';
      context.fill();

      // Draw ship emoji
      context.font = `${35 * scale}px Arial`;
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

    // Add a small delay to ensure container is ready
    setTimeout(() => {
      // Wait for container to have dimensions
      const checkContainer = () => {
        const container = mapContainerRef.current;
        if (!container) return false;
        
        const rect = container.getBoundingClientRect();
        console.log('Container dimensions:', rect.width, 'x', rect.height);
        return rect.width > 0 && rect.height > 0;
      };

      // If container doesn't have dimensions yet, wait
      if (!checkContainer()) {
        const checkInterval = setInterval(() => {
          if (checkContainer()) {
            clearInterval(checkInterval);
            initializeMap();
          }
        }, 100);
        
        // Timeout after 5 seconds
        setTimeout(() => {
          clearInterval(checkInterval);
          console.error('Mapbox container never got valid dimensions');
        }, 5000);
        return;
      }

      initializeMap();
    }, 100);

    function initializeMap() {
      if (!mapContainerRef.current) {
        console.error('Mapbox container ref is null');
        return;
      }
      
      const rect = mapContainerRef.current.getBoundingClientRect();
      console.log('Initializing Mapbox map with dimensions:', rect.width, 'x', rect.height);
      
      try {
        // Configure Mapbox to handle WebGL context loss better
        const map = new mapboxgl.Map({
          container: mapContainerRef.current,
          style: 'mapbox://styles/mapbox/standard-satellite',
          center: [0, 20],
          zoom: 2.5,
          pitch: 45,
          bearing: 0,
          projection: 'globe' as any,
          preserveDrawingBuffer: true,
          failIfMajorPerformanceCaveat: false,
          refreshExpiredTiles: false,
          maxTileCacheSize: 100,
          antialias: true,
          fadeDuration: 0,
          interactive: true
        });
        
        console.log('Mapbox map created successfully');

    mapRef.current = map;

    // Handle WebGL context loss
    const canvas = map.getCanvas();
    let contextLostTimeout: NodeJS.Timeout | null = null;
    
    const handleContextLost = (e: Event) => {
      console.warn('WebGL context lost, preventing default behavior');
      e.preventDefault();
      
      // Clear any existing timeout
      if (contextLostTimeout) {
        clearTimeout(contextLostTimeout);
      }
      
      // Try to restore context after a delay
      contextLostTimeout = setTimeout(() => {
        if (mapRef.current && !mapRef.current.isRemoved()) {
          console.log('Attempting to restore WebGL context...');
          mapRef.current.triggerRepaint();
          // Try to recreate the map if context is still lost
          const gl = canvas.getContext('webgl') || canvas.getContext('experimental-webgl');
          if (!gl || gl.isContextLost()) {
            console.log('Context still lost, will retry...');
          }
        }
      }, 2000);
    };
    
    const handleContextRestored = () => {
      console.log('WebGL context restored');
      if (contextLostTimeout) {
        clearTimeout(contextLostTimeout);
        contextLostTimeout = null;
      }
      // Force map to re-render
      if (mapRef.current && !mapRef.current.isRemoved()) {
        mapRef.current.triggerRepaint();
      }
    };
    
    canvas.addEventListener('webglcontextlost', handleContextLost);
    canvas.addEventListener('webglcontextrestored', handleContextRestored);

    map.on('style.load', () => {
      // Add 3D terrain
      map.addSource('mapbox-dem', {
        type: 'raster-dem',
        url: 'mapbox://mapbox.mapbox-terrain-dem-v1',
        tileSize: 512,
        maxzoom: 14
      });
      
      map.setTerrain({ source: 'mapbox-dem', exaggeration: 1.0 });

      // Add custom ship icons for different statuses
      map.addImage('ship-icon-idle', createShipIcon('IDLE') as any, { pixelRatio: 2 });
      map.addImage('ship-icon-sailing', createShipIcon('SAILING') as any, { pixelRatio: 2 });
      map.addImage('ship-icon-loading', createShipIcon('LOADING') as any, { pixelRatio: 2 });

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
          'icon-image': [
            'case',
            ['==', ['get', 'status'], 'SAILING'], 'ship-icon-sailing',
            ['==', ['get', 'status'], 'LOADING'], 'ship-icon-loading',
            ['==', ['get', 'status'], 'UNLOADING'], 'ship-icon-loading',
            'ship-icon-idle'
          ],
          'icon-size': 1.2,
          'icon-rotate': ['get', 'bearing'],
          'icon-rotation-alignment': 'map',
          'icon-allow-overlap': true,
          'icon-pitch-alignment': 'map',
          'text-field': ['get', 'name'],
          'text-font': ['Open Sans Bold', 'Arial Unicode MS Bold'],
          'text-size': 12,
          'text-offset': [0, 2],
          'text-anchor': 'top',
          'text-allow-overlap': true
        },
        paint: {
          'text-color': '#ffffff',
          'text-halo-color': '#000000',
          'text-halo-width': 2,
          'text-opacity': 0.9
        }
      });

      // Ports will be added separately when they're available

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

    // Add error handling
    map.on('error', (e) => {
      console.error('Mapbox error:', e);
      if (e.error && e.error.status === 401) {
        console.error('Mapbox token may be invalid or expired');
      }
      // Try to recover by triggering a repaint
      if (map && !map.isRemoved()) {
        setTimeout(() => {
          map.triggerRepaint();
        }, 1000);
      }
    });
    
    // Add load event to confirm map is ready
    map.on('load', () => {
      console.log('Mapbox map fully loaded');
    });

      } catch (error) {
        console.error('Failed to initialize Mapbox:', error);
        // Check if it's a token issue
        if (error.message && error.message.includes('401')) {
          console.error('Mapbox access token is invalid');
        }
      }
    }
    
    // Cleanup
    return () => {
      if (animationRef.current) {
        cancelAnimationFrame(animationRef.current);
      }
      if (mapRef.current) {
        // Remove event listeners
        const canvas = mapRef.current.getCanvas();
        if (canvas) {
          canvas.removeEventListener('webglcontextlost', handleContextLost);
          canvas.removeEventListener('webglcontextrestored', handleContextRestored);
        }
        if (contextLostTimeout) {
          clearTimeout(contextLostTimeout);
        }
        mapRef.current.remove();
        mapRef.current = null;
      }
    };
  }, [selectShip, positionToLatLng]);

  // Add ports when they're available
  useEffect(() => {
    if (!mapRef.current || !mapRef.current.isStyleLoaded() || ports.length === 0) return;
    
    const map = mapRef.current;
    console.log(`Adding ${ports.length} ports to the map`);
    
    // Remove existing port markers if any
    const existingMarkers = document.querySelectorAll('.port-marker');
    existingMarkers.forEach(marker => marker.remove());
    
    // Add port markers
    ports.forEach(port => {
      const { lat, lng } = positionToLatLng(port.position);
      
      const el = document.createElement('div');
      el.className = 'port-marker';
      el.style.cssText = `
        width: 30px;
        height: 30px;
        background: ${port.isPlayerOwned ? '#3b82f6' : '#10b981'};
        border: 3px solid white;
        border-radius: 50%;
        cursor: pointer;
        box-shadow: 0 2px 8px rgba(0,0,0,0.3);
        transition: all 0.2s;
      `;
      
      // Add hover effect
      el.addEventListener('mouseenter', () => {
        el.style.transform = 'scale(1.2)';
        el.style.boxShadow = '0 4px 12px rgba(0,0,0,0.5)';
      });
      
      el.addEventListener('mouseleave', () => {
        el.style.transform = 'scale(1)';
        el.style.boxShadow = '0 2px 8px rgba(0,0,0,0.3)';
      });

      const popup = new mapboxgl.Popup({ offset: 25 }).setHTML(`
        <div style="padding: 12px; min-width: 200px;">
          <h3 style="margin: 0 0 8px 0; font-size: 16px; font-weight: bold;">${port.name}</h3>
          <p style="margin: 0 0 4px 0; color: #666; font-size: 14px;">${port.country}</p>
          <hr style="margin: 8px 0; border: none; border-top: 1px solid #e5e5e5;">
          <div style="font-size: 13px;">
            <p style="margin: 2px 0;"><strong>Capacity:</strong> ${port.capacity.toLocaleString()} TEU</p>
            <p style="margin: 2px 0;"><strong>Available Berths:</strong> ${port.availableBerths}/${port.berths}</p>
            <p style="margin: 2px 0;"><strong>Loading Speed:</strong> ${port.loadingSpeed} TEU/hr</p>
            ${port.isPlayerOwned ? '<p style="margin: 4px 0; color: #3b82f6; font-weight: bold;">🏠 Your Port</p>' : ''}
          </div>
        </div>
      `);

      new mapboxgl.Marker(el)
        .setLngLat([lng, lat])
        .setPopup(popup)
        .addTo(map);
    });
  }, [ports, positionToLatLng]);

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
      className={`mapbox-container ${className || ''}`}
      style={{ 
        width: '100%', 
        height: '100%',
        position: 'absolute',
        top: 0,
        left: 0
      }}
    />
  );
};