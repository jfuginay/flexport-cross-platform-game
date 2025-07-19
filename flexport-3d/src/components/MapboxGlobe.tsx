import React, { useEffect, useRef, useCallback } from 'react';
import mapboxgl from 'mapbox-gl';
import * as THREE from 'three';
import { useGameStore } from '../store/gameStore';
import { positionToLatLng } from '../utils/geoUtils';
import { ShipStatus, ShipType } from '../types/game.types';
import 'mapbox-gl/dist/mapbox-gl.css';
import './MapboxGlobe.css';

// Set your Mapbox access token
mapboxgl.accessToken = process.env.REACT_APP_MAPBOX_TOKEN || 'pk.eyJ1IjoiamZ1Z2luYXkiLCJhIjoiY21icmNha2hrMGE0azJscHVzdmVuZTVjOSJ9.oiJoYvc_G-tLUmaSzGVsVQ';


interface MapboxGlobeProps {
  className?: string;
}

export const MapboxGlobe: React.FC<MapboxGlobeProps> = ({ className }) => {
  const mapContainer = useRef<HTMLDivElement>(null);
  const map = useRef<mapboxgl.Map | null>(null);
  const shipMarkers = useRef<Map<string, mapboxgl.Marker>>(new Map());
  const [isMapLoaded, setIsMapLoaded] = React.useState(false);
  const [mapError, setMapError] = React.useState<string | null>(null);
  const isInitializing = useRef(false);
  const [showWeather, setShowWeather] = React.useState(false);
  const [showRain, setShowRain] = React.useState(false);
  
  // Camera tracking state
  const [followMode, setFollowMode] = React.useState(true);
  const [cameraMode, setCameraMode] = React.useState<'cinematic' | 'top-down' | 'chase'>('cinematic');
  const lastUserInteraction = useRef<number>(0);
  const cameraAnimationFrame = useRef<number | null>(null);
  const previousShipPositions = useRef<Map<string, { lng: number; lat: number; timestamp: number }>>(new Map());
  
  const { fleet, ports, selectedShipId, selectShip, selectPort } = useGameStore();
  
  // Camera tracking functions
  const calculateShipSpeed = (shipId: string, currentPos: { lng: number; lat: number }) => {
    const prevPos = previousShipPositions.current.get(shipId);
    if (!prevPos) {
      previousShipPositions.current.set(shipId, { ...currentPos, timestamp: Date.now() });
      return 0;
    }
    
    const timeDelta = (Date.now() - prevPos.timestamp) / 1000; // seconds
    if (timeDelta === 0) return 0;
    
    // Calculate distance using Haversine formula
    const R = 6371; // Earth's radius in km
    const dLat = (currentPos.lat - prevPos.lat) * Math.PI / 180;
    const dLon = (currentPos.lng - prevPos.lng) * Math.PI / 180;
    const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
              Math.cos(prevPos.lat * Math.PI / 180) * Math.cos(currentPos.lat * Math.PI / 180) *
              Math.sin(dLon/2) * Math.sin(dLon/2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    const distance = R * c; // Distance in km
    
    const speed = distance / timeDelta * 3600; // km/h
    
    // Update previous position
    previousShipPositions.current.set(shipId, { ...currentPos, timestamp: Date.now() });
    
    return speed;
  };
  
  const calculateDynamicZoom = (speed: number, shipStatus: ShipStatus) => {
    if (shipStatus === ShipStatus.IDLE || shipStatus === ShipStatus.LOADING || shipStatus === ShipStatus.UNLOADING || shipStatus === ShipStatus.MAINTENANCE) {
      return 12; // Close zoom when docked or in maintenance
    }
    
    // Dynamic zoom based on speed (km/h)
    // Cargo planes are much faster, so different scale
    if (speed > 500) { // Likely a plane
      return Math.max(6, Math.min(10, 12 - speed / 200));
    } else { // Ship
      return Math.max(8, Math.min(12, 12 - speed / 10));
    }
  };
  
  const getCameraAngle = (shipType: ShipType, shipStatus: ShipStatus, cameraMode: string) => {
    if (cameraMode === 'top-down') {
      return { pitch: 0, bearing: 0 };
    }
    
    if (cameraMode === 'chase') {
      // Get ship's heading/bearing
      const ship = fleet.find(s => s.id === selectedShipId);
      const rotation = (ship as any)?.rotation || 0;
      return { 
        pitch: 45, 
        bearing: rotation * (180 / Math.PI) - 180 // Behind the ship
      };
    }
    
    // Cinematic mode
    switch (shipStatus) {
      case ShipStatus.IDLE:
      case ShipStatus.LOADING:
      case ShipStatus.UNLOADING:
      case ShipStatus.MAINTENANCE:
        return { pitch: 65, bearing: Date.now() / 100 % 360 }; // Slow orbit when docked or in maintenance
      case ShipStatus.SAILING:
        if (shipType === ShipType.CARGO_PLANE) {
          return { pitch: 35, bearing: 45 }; // Lower angle for planes
        }
        return { pitch: 55, bearing: 20 }; // Dynamic angle for ships
      default:
        return { pitch: 45, bearing: 0 };
    }
  };
  
  const smoothCameraFollow = () => {
    if (!map.current || !followMode || !selectedShipId) return;
    
    const ship = fleet.find(s => s.id === selectedShipId);
    if (!ship) return;
    
    // Check if user has interacted recently (within 3 seconds)
    if (Date.now() - lastUserInteraction.current < 3000) return;
    
    const targetCoords = positionToLatLng(new THREE.Vector3(ship.position.x, ship.position.y, ship.position.z));
    const currentCenter = map.current.getCenter();
    const currentZoom = map.current.getZoom();
    const currentPitch = map.current.getPitch();
    const currentBearing = map.current.getBearing();
    
    // Calculate ship speed
    const speed = calculateShipSpeed(ship.id, targetCoords);
    
    // Get target camera settings
    const targetZoom = calculateDynamicZoom(speed, ship.status);
    const { pitch: targetPitch, bearing: targetBearing } = getCameraAngle(ship.type, ship.status, cameraMode);
    
    // Smooth interpolation factors
    const positionAlpha = 0.1; // Position following smoothness
    const zoomAlpha = 0.05; // Zoom transition smoothness
    const rotationAlpha = 0.08; // Rotation smoothness
    
    // Interpolate position
    const newLng = currentCenter.lng + (targetCoords.lng - currentCenter.lng) * positionAlpha;
    const newLat = currentCenter.lat + (targetCoords.lat - currentCenter.lat) * positionAlpha;
    
    // Interpolate zoom
    const newZoom = currentZoom + (targetZoom - currentZoom) * zoomAlpha;
    
    // Interpolate rotation (handle wrap-around)
    let bearingDiff = targetBearing - currentBearing;
    if (bearingDiff > 180) bearingDiff -= 360;
    if (bearingDiff < -180) bearingDiff += 360;
    const newBearing = currentBearing + bearingDiff * rotationAlpha;
    
    const newPitch = currentPitch + (targetPitch - currentPitch) * rotationAlpha;
    
    // Apply smooth camera movement
    map.current.easeTo({
      center: [newLng, newLat],
      zoom: newZoom,
      pitch: newPitch,
      bearing: newBearing,
      duration: 100,
      easing: (t) => t, // Linear for smooth continuous movement
      essential: false // Can be interrupted by user
    });
    
    // Continue animation
    cameraAnimationFrame.current = requestAnimationFrame(smoothCameraFollow);
  };
  
  // Initialize map
  useEffect(() => {
    if (!mapContainer.current || map.current || isInitializing.current) return;
    
    // Add a small delay to ensure container is fully rendered
    const initTimer = setTimeout(() => {
      if (!mapContainer.current || map.current) return;
    
    isInitializing.current = true;
    
    // Create new map instance with enhanced settings
    console.log('Initializing Mapbox Globe...');
    console.log('Access Token:', mapboxgl.accessToken ? 'Token present' : 'No token!');
    console.log('Container element:', mapContainer.current);
    console.log('Container dimensions:', {
      width: mapContainer.current.offsetWidth,
      height: mapContainer.current.offsetHeight,
      display: window.getComputedStyle(mapContainer.current).display
    });
    
    try {
      map.current = new mapboxgl.Map({
        container: mapContainer.current,
        style: 'mapbox://styles/mapbox/satellite-streets-v12', // Using satellite style
        projection: 'globe', // Enable globe projection
        center: [0, 20],
        zoom: 2.5,
        pitch: 0,
        bearing: 0,
        antialias: true,
        hash: false,
        renderWorldCopies: false, // Single globe
        maxPitch: 85,
        minZoom: 1.5,
        maxZoom: 20
      });
      console.log('Map instance created successfully');
    } catch (error) {
      console.error('Failed to initialize Mapbox:', error);
      const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
      setMapError(`Failed to initialize map: ${errorMessage}`);
      setIsMapLoaded(true); // Hide loading screen to show error
      return;
    }
    
    // Add navigation controls
    map.current.addControl(new mapboxgl.NavigationControl(), 'top-right');
    
    // Add error handler
    map.current.on('error', (e) => {
      console.error('Mapbox error:', e.error);
      // Check if it's a token error
      if (e.error && e.error.message && e.error.message.includes('access token')) {
        console.error('Token validation failed. Please check your Mapbox access token.');
      }
    });
    
    // Configure globe settings
    map.current.on('style.load', () => {
      console.log('Mapbox style loaded');
      if (!map.current) return;
      
      // Set enhanced fog for atmosphere effect
      map.current.setFog({
        color: 'rgb(186, 210, 235)', // Sky color
        'high-color': 'rgb(36, 92, 223)', // Sky color at higher altitudes
        'horizon-blend': 0.02, // Atmosphere thickness
        'space-color': 'rgb(11, 11, 25)', // Space color
        'star-intensity': 0.8 // Star brightness
      });
      
      // Add beautiful lighting
      map.current.setLight({
        anchor: 'viewport',
        color: 'white',
        intensity: 0.4,
        position: [1.5, 90, 80]
      });
      
      // Add 3D terrain for realistic continents
      map.current.addSource('mapbox-dem', {
        type: 'raster-dem',
        url: 'mapbox://mapbox.mapbox-terrain-dem-v1',
        tileSize: 512,
        maxzoom: 14
      });
      
      // Enable 3D terrain with more dramatic exaggeration
      map.current.setTerrain({ 
        source: 'mapbox-dem', 
        exaggeration: 2.0 // Increased for more dramatic mountains
      });
      
      // Ship icons will be HTML markers, not images
      
      // Add ports as a data source
      if (ports.length > 0) {
        addPortsLayer();
      }
      
      // Set up event handlers
      setupEventHandlers();
      
      // Add weather overlay capability
      setupWeatherLayers();
    });
    
    // Smooth globe rotation
    let rotationAnimation: number;
    let isUserInteracting = false;
    let lastInteractionTime = 0;
    
    const rotateGlobe = () => {
      if (!map.current || isUserInteracting) {
        rotationAnimation = requestAnimationFrame(rotateGlobe);
        return;
      }
      
      // Resume rotation after 3 seconds of no interaction
      if (Date.now() - lastInteractionTime > 3000) {
        const center = map.current.getCenter();
        center.lng += 0.05; // Slower, smoother rotation
        map.current.easeTo({
          center: center,
          duration: 100,
          easing: (t) => t // Linear easing
        });
      }
      
      rotationAnimation = requestAnimationFrame(rotateGlobe);
    };
    
    // Start rotation and initial animation after map loads
    map.current.on('load', () => {
      setIsMapLoaded(true);
      
      // Dramatic initial zoom in
      map.current?.flyTo({
        center: [0, 20],
        zoom: 2.5,
        pitch: 45,
        bearing: 0,
        duration: 3000,
        essential: true
      });
      
      // Start rotation animation
      rotationAnimation = requestAnimationFrame(rotateGlobe);
      
      // Map is now loaded
      console.log('Mapbox map fully loaded and ready');
    });
    
    // Handle user interaction
    const handleInteractionStart = () => {
      isUserInteracting = true;
      lastInteractionTime = Date.now();
      lastUserInteraction.current = Date.now();
    };
    
    const handleInteractionEnd = () => {
      isUserInteracting = false;
      lastInteractionTime = Date.now();
    };
    
    map.current.on('mousedown', handleInteractionStart);
    map.current.on('mouseup', handleInteractionEnd);
    map.current.on('touchstart', handleInteractionStart);
    map.current.on('touchend', handleInteractionEnd);
    map.current.on('wheel', () => {
      isUserInteracting = true;
      lastInteractionTime = Date.now();
      lastUserInteraction.current = Date.now();
      setTimeout(() => { isUserInteracting = false; }, 100);
    });
    
    // Also track drag events
    map.current.on('drag', () => {
      lastUserInteraction.current = Date.now();
    });
    }, 100); // End of setTimeout
    
    // Cleanup
    return () => {
      clearTimeout(initTimer);
      cancelAnimationFrame(rotationAnimation);
      if (cameraAnimationFrame.current) {
        cancelAnimationFrame(cameraAnimationFrame.current);
      }
      if (map.current) {
        // Remove all custom sources and layers before removing map
        try {
          ['ship-routes-animated', 'ship-routes', 'port-labels', 'unclustered-ports', 
           'port-cluster-count', 'port-clusters'].forEach(layerId => {
            if (map.current?.getLayer(layerId)) {
              map.current.removeLayer(layerId);
            }
          });
          
          ['ship-routes', 'ports'].forEach(sourceId => {
            if (map.current?.getSource(sourceId)) {
              map.current.removeSource(sourceId);
            }
          });
        } catch (e) {
          // Ignore cleanup errors
        }
        
        map.current.remove();
        map.current = null;
      }
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  
  // Add ports layer
  const addPortsLayer = () => {
    if (!map.current || ports.length === 0) return;
    
    // Remove existing ports layers and source if they exist
    try {
      if (map.current.getLayer('port-labels')) {
        map.current.removeLayer('port-labels');
      }
      if (map.current.getLayer('unclustered-ports')) {
        map.current.removeLayer('unclustered-ports');
      }
      if (map.current.getLayer('port-cluster-count')) {
        map.current.removeLayer('port-cluster-count');
      }
      if (map.current.getLayer('port-clusters')) {
        map.current.removeLayer('port-clusters');
      }
      if (map.current.getSource('ports')) {
        map.current.removeSource('ports');
      }
    } catch (e) {
      // Ignore errors if layers/sources don't exist
    }
    
    // Create GeoJSON from ports
    const portsGeoJSON: GeoJSON.FeatureCollection = {
      type: 'FeatureCollection',
      features: ports.map(port => ({
        type: 'Feature',
        properties: {
          id: port.id,
          name: port.name,
          country: port.country,
          capacity: port.capacity,
          currentLoad: port.currentLoad,
          availableBerths: port.availableBerths,
          isPlayerOwned: port.isPlayerOwned
        },
        geometry: {
          type: 'Point',
          coordinates: (() => {
            const coords = positionToLatLng(new THREE.Vector3(port.position.x, port.position.y, port.position.z));
            return [coords.lng, coords.lat];
          })()
        }
      }))
    };
    
    // Add ports source
    map.current.addSource('ports', {
      type: 'geojson',
      data: portsGeoJSON,
      cluster: true,
      clusterMaxZoom: 10,
      clusterRadius: 50
    });
    
    // Add clustered ports layer
    map.current.addLayer({
      id: 'port-clusters',
      type: 'circle',
      source: 'ports',
      filter: ['has', 'point_count'],
      paint: {
        'circle-color': [
          'step',
          ['get', 'point_count'],
          '#51bbd6',
          10,
          '#f1f075',
          20,
          '#f28cb1'
        ],
        'circle-radius': [
          'step',
          ['get', 'point_count'],
          20,
          10,
          30,
          20,
          40
        ],
        'circle-stroke-width': 2,
        'circle-stroke-color': '#ffffff'
      }
    });
    
    // Add cluster count labels
    map.current.addLayer({
      id: 'port-cluster-count',
      type: 'symbol',
      source: 'ports',
      filter: ['has', 'point_count'],
      layout: {
        'text-field': '{point_count_abbreviated}',
        'text-font': ['DIN Offc Pro Medium', 'Arial Unicode MS Bold'],
        'text-size': 12
      }
    });
    
    // Add individual ports layer with dynamic styling
    map.current.addLayer({
      id: 'unclustered-ports',
      type: 'circle',
      source: 'ports',
      filter: ['!', ['has', 'point_count']],
      paint: {
        'circle-color': [
          'case',
          ['get', 'isPlayerOwned'],
          '#4ade80', // Green for player-owned
          '#3b82f6'  // Blue for other ports
        ],
        'circle-radius': [
          'interpolate',
          ['linear'],
          ['get', 'capacity'],
          0, 6,
          100, 10,
          1000, 15
        ],
        'circle-stroke-width': 2,
        'circle-stroke-color': '#ffffff',
        'circle-stroke-opacity': 0.8,
        'circle-opacity': 0.9
      }
    });
    
    // Add port labels
    map.current.addLayer({
      id: 'port-labels',
      type: 'symbol',
      source: 'ports',
      filter: ['!', ['has', 'point_count']],
      layout: {
        'text-field': ['get', 'name'],
        'text-font': ['DIN Offc Pro Medium', 'Arial Unicode MS Bold'],
        'text-size': 12,
        'text-offset': [0, 1.5],
        'text-anchor': 'top'
      },
      paint: {
        'text-color': '#ffffff',
        'text-halo-color': '#000000',
        'text-halo-width': 1
      }
    });
  };
  
  // Setup weather layers
  const setupWeatherLayers = () => {
    if (!map.current) return;
    
    // Rain overlay will be added dynamically when enabled
    
    // Create rain canvas
    const rainCanvas = document.createElement('canvas');
    rainCanvas.id = 'rain-canvas';
    rainCanvas.width = 1024;
    rainCanvas.height = 512;
    rainCanvas.style.display = 'none';
    document.body.appendChild(rainCanvas);
    
    const ctx = rainCanvas.getContext('2d');
    if (ctx) {
      // Rain animation
      const raindrops: Array<{x: number, y: number, speed: number}> = [];
      for (let i = 0; i < 100; i++) {
        raindrops.push({
          x: Math.random() * rainCanvas.width,
          y: Math.random() * rainCanvas.height,
          speed: 2 + Math.random() * 3
        });
      }
      
      let animationId: number;
      const animateRain = () => {
        ctx.fillStyle = 'rgba(0, 0, 0, 0.05)';
        ctx.fillRect(0, 0, rainCanvas.width, rainCanvas.height);
        
        ctx.strokeStyle = 'rgba(174, 194, 224, 0.5)';
        ctx.lineWidth = 1;
        ctx.lineCap = 'round';
        
        raindrops.forEach(drop => {
          ctx.beginPath();
          ctx.moveTo(drop.x, drop.y);
          ctx.lineTo(drop.x, drop.y + drop.speed * 5);
          ctx.stroke();
          
          drop.y += drop.speed;
          if (drop.y > rainCanvas.height) {
            drop.y = -20;
            drop.x = Math.random() * rainCanvas.width;
          }
        });
        
        // Update the image source with new frame
        if (map.current && map.current.getSource('rain-overlay')) {
          const source = map.current.getSource('rain-overlay') as mapboxgl.ImageSource;
          source.updateImage({ url: rainCanvas.toDataURL() });
        }
        
        animationId = requestAnimationFrame(animateRain);
      };
      
      // Store animation function for later use
      (rainCanvas as any).startAnimation = () => {
        animateRain();
      };
      (rainCanvas as any).stopAnimation = () => {
        if (animationId) cancelAnimationFrame(animationId);
      };
    }
    
    // Weather overlay would be added here with a real weather API
    // Removed placeholder to avoid API errors
  };
  
  // Setup event handlers
  const setupEventHandlers = () => {
    if (!map.current) return;
    
    // Port click handler with popup
    map.current.on('click', 'unclustered-ports', (e) => {
      if (!e.features || !e.features[0]) return;
      
      const feature = e.features[0];
      const portId = feature.properties?.id;
      const coordinates = (feature.geometry as GeoJSON.Point).coordinates.slice() as [number, number];
      
      // Create popup content
      const popupContent = `
        <div class="port-popup">
          <h3>${feature.properties?.name}</h3>
          <div class="port-info">
            <div class="info-row">
              <span class="info-label">Country:</span>
              <span class="info-value">${feature.properties?.country}</span>
            </div>
            <div class="info-row">
              <span class="info-label">Capacity:</span>
              <span class="info-value">${feature.properties?.capacity} TEU</span>
            </div>
            <div class="info-row">
              <span class="info-label">Current Load:</span>
              <span class="info-value">${Math.round((feature.properties?.currentLoad / feature.properties?.capacity) * 100)}%</span>
            </div>
            <div class="info-row">
              <span class="info-label">Available Berths:</span>
              <span class="info-value">${feature.properties?.availableBerths}</span>
            </div>
            ${feature.properties?.isPlayerOwned ? '<div class="info-row"><span class="info-label" style="color: #4ade80;">✓ Player Owned</span></div>' : ''}
          </div>
        </div>
      `;
      
      // Create and show popup
      new mapboxgl.Popup({ 
        closeButton: true,
        closeOnClick: true,
        offset: 25
      })
        .setLngLat(coordinates)
        .setHTML(popupContent)
        .addTo(map.current!);
      
      if (portId) {
        selectPort(portId);
        
        // Smooth fly to port
        map.current?.flyTo({
          center: coordinates,
          zoom: 10,
          pitch: 60,
          bearing: 20,
          duration: 2500,
          essential: true
        });
      }
    });
    
    // Port hover effects
    map.current.on('mouseenter', 'unclustered-ports', () => {
      if (map.current) {
        map.current.getCanvas().style.cursor = 'pointer';
      }
    });
    
    map.current.on('mouseleave', 'unclustered-ports', () => {
      if (map.current) {
        map.current.getCanvas().style.cursor = '';
      }
    });
    
    // Cluster click - zoom in
    map.current.on('click', 'port-clusters', (e) => {
      if (!map.current || !e.features || !e.features[0]) return;
      
      const clusterId = e.features[0].properties?.cluster_id;
      const source = map.current.getSource('ports') as mapboxgl.GeoJSONSource;
      
      source.getClusterExpansionZoom(clusterId, (err, zoom) => {
        if (err || !map.current || zoom === null || zoom === undefined) return;
        
        map.current.easeTo({
          center: (e.features![0].geometry as GeoJSON.Point).coordinates as [number, number],
          zoom: zoom + 1
        });
      });
    });
  };
  
  // Start/stop camera tracking based on selection
  useEffect(() => {
    if (!map.current || !isMapLoaded) return;
    
    if (selectedShipId && followMode) {
      // Start camera tracking
      if (cameraAnimationFrame.current) {
        cancelAnimationFrame(cameraAnimationFrame.current);
      }
      
      // Initial transition to selected ship
      const ship = fleet.find(s => s.id === selectedShipId);
      if (ship) {
        const coords = positionToLatLng(new THREE.Vector3(ship.position.x, ship.position.y, ship.position.z));
        
        // Just do initial camera positioning, disable smooth follow for now
        map.current.flyTo({
          center: [coords.lng, coords.lat],
          zoom: 10,
          pitch: 45,
          bearing: 0,
          duration: 2000,
          essential: true
        });
      }
    } else {
      // Stop camera tracking
      if (cameraAnimationFrame.current) {
        cancelAnimationFrame(cameraAnimationFrame.current);
        cameraAnimationFrame.current = null;
      }
    }
    
    return () => {
      if (cameraAnimationFrame.current) {
        cancelAnimationFrame(cameraAnimationFrame.current);
      }
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedShipId, followMode, isMapLoaded]);
  
  // Auto-focus on single ship - removed to prevent infinite loop
  
  
  // Update ship markers
  useEffect(() => {
    if (!map.current || !isMapLoaded) return;
    
    // Remove old markers that no longer exist
    shipMarkers.current.forEach((marker, shipId) => {
      if (!fleet.find(s => s.id === shipId)) {
        marker.remove();
        shipMarkers.current.delete(shipId);
      }
    });
    
    // Update or create markers for each ship
    fleet.forEach(ship => {
      let marker = shipMarkers.current.get(ship.id);
      
      if (!marker) {
        // Create beautiful ship marker with professional game styling
        const el = document.createElement('div');
        el.className = 'ship-marker';
        el.setAttribute('data-ship-type', ship.type);
        el.style.cssText = `
          width: 80px;
          height: 80px;
          cursor: pointer;
          position: absolute;
          transform: translate(-50%, -50%);
          z-index: 99999 !important;
          pointer-events: auto;
        `;
        
        // Ship type specific configurations
        const shipConfigs = {
          [ShipType.CONTAINER]: {
            color: '#3b82f6', // Blue
            shadowColor: '#60a5fa',
            icon: `<svg viewBox="0 0 100 100" style="width: 100%; height: 100%;">
              <!-- Container ship hull -->
              <path d="M 15 60 L 20 75 L 80 75 L 85 60 Z" fill="#1e40af" stroke="#3b82f6" stroke-width="2"/>
              <!-- Container stacks -->
              <rect x="25" y="50" width="10" height="10" fill="#ef4444" stroke="#dc2626" stroke-width="1"/>
              <rect x="35" y="50" width="10" height="10" fill="#10b981" stroke="#059669" stroke-width="1"/>
              <rect x="45" y="50" width="10" height="10" fill="#f59e0b" stroke="#d97706" stroke-width="1"/>
              <rect x="55" y="50" width="10" height="10" fill="#8b5cf6" stroke="#7c3aed" stroke-width="1"/>
              <rect x="65" y="50" width="10" height="10" fill="#ef4444" stroke="#dc2626" stroke-width="1"/>
              <!-- Second layer -->
              <rect x="30" y="40" width="10" height="10" fill="#10b981" stroke="#059669" stroke-width="1"/>
              <rect x="40" y="40" width="10" height="10" fill="#ef4444" stroke="#dc2626" stroke-width="1"/>
              <rect x="50" y="40" width="10" height="10" fill="#f59e0b" stroke="#d97706" stroke-width="1"/>
              <rect x="60" y="40" width="10" height="10" fill="#8b5cf6" stroke="#7c3aed" stroke-width="1"/>
              <!-- Bridge -->
              <rect x="70" y="35" width="12" height="15" fill="#4b5563" stroke="#374151" stroke-width="1"/>
              <rect x="72" y="37" width="8" height="4" fill="#60a5fa" stroke="#3b82f6" stroke-width="0.5"/>
            </svg>`
          },
          [ShipType.BULK]: {
            color: '#10b981', // Green
            shadowColor: '#34d399',
            icon: `<svg viewBox="0 0 100 100" style="width: 100%; height: 100%;">
              <!-- Bulk carrier hull -->
              <path d="M 10 65 L 15 80 L 85 80 L 90 65 Z" fill="#059669" stroke="#10b981" stroke-width="2"/>
              <!-- Cargo holds -->
              <ellipse cx="25" cy="55" rx="12" ry="8" fill="#065f46" stroke="#059669" stroke-width="2"/>
              <ellipse cx="50" cy="55" rx="12" ry="8" fill="#065f46" stroke="#059669" stroke-width="2"/>
              <ellipse cx="75" cy="55" rx="12" ry="8" fill="#065f46" stroke="#059669" stroke-width="2"/>
              <!-- Cargo -->
              <circle cx="25" cy="52" r="3" fill="#8b4513"/>
              <circle cx="50" cy="52" r="3" fill="#8b4513"/>
              <circle cx="75" cy="52" r="3" fill="#8b4513"/>
              <!-- Bridge -->
              <rect x="78" y="45" width="10" height="10" fill="#4b5563" stroke="#374151" stroke-width="1"/>
              <rect x="80" y="47" width="6" height="3" fill="#34d399" stroke="#10b981" stroke-width="0.5"/>
              <!-- Crane -->
              <line x1="40" y1="55" x2="40" y2="35" stroke="#6b7280" stroke-width="2"/>
              <line x1="40" y1="35" x2="55" y2="40" stroke="#6b7280" stroke-width="2"/>
            </svg>`
          },
          [ShipType.TANKER]: {
            color: '#f97316', // Orange
            shadowColor: '#fb923c',
            icon: `<svg viewBox="0 0 100 100" style="width: 100%; height: 100%;">
              <!-- Tanker hull -->
              <path d="M 12 62 L 18 78 L 82 78 L 88 62 Z" fill="#ea580c" stroke="#f97316" stroke-width="2"/>
              <!-- Cylindrical tanks -->
              <ellipse cx="30" cy="55" rx="15" ry="10" fill="#dc2626" stroke="#ef4444" stroke-width="2"/>
              <ellipse cx="50" cy="55" rx="15" ry="10" fill="#dc2626" stroke="#ef4444" stroke-width="2"/>
              <ellipse cx="70" cy="55" rx="15" ry="10" fill="#dc2626" stroke="#ef4444" stroke-width="2"/>
              <!-- Tank tops -->
              <ellipse cx="30" cy="50" rx="15" ry="10" fill="#ef4444" stroke="#f87171" stroke-width="1"/>
              <ellipse cx="50" cy="50" rx="15" ry="10" fill="#ef4444" stroke="#f87171" stroke-width="1"/>
              <ellipse cx="70" cy="50" rx="15" ry="10" fill="#ef4444" stroke="#f87171" stroke-width="1"/>
              <!-- Bridge -->
              <rect x="75" y="40" width="12" height="12" fill="#4b5563" stroke="#374151" stroke-width="1"/>
              <rect x="77" y="42" width="8" height="3" fill="#fb923c" stroke="#f97316" stroke-width="0.5"/>
              <!-- Safety equipment -->
              <circle cx="20" cy="58" r="2" fill="#fbbf24"/>
              <circle cx="80" cy="58" r="2" fill="#fbbf24"/>
            </svg>`
          },
          [ShipType.CARGO_PLANE]: {
            color: '#8b5cf6', // Purple
            shadowColor: '#a78bfa',
            icon: `<svg viewBox="0 0 100 100" style="width: 100%; height: 100%;">
              <!-- Plane body -->
              <ellipse cx="50" cy="50" rx="35" ry="8" fill="#7c3aed" stroke="#8b5cf6" stroke-width="2"/>
              <!-- Wings -->
              <path d="M 30 50 L 5 45 L 5 55 L 30 50 Z" fill="#6d28d9" stroke="#7c3aed" stroke-width="2"/>
              <path d="M 70 50 L 95 45 L 95 55 L 70 50 Z" fill="#6d28d9" stroke="#7c3aed" stroke-width="2"/>
              <!-- Tail -->
              <path d="M 15 50 L 10 35 L 20 35 L 25 50 Z" fill="#6d28d9" stroke="#7c3aed" stroke-width="2"/>
              <!-- Cockpit -->
              <ellipse cx="75" cy="50" rx="8" ry="6" fill="#4c1d95" stroke="#6d28d9" stroke-width="1"/>
              <ellipse cx="75" cy="50" rx="6" ry="4" fill="#60a5fa" stroke="#3b82f6" stroke-width="0.5"/>
              <!-- Engines (animated) -->
              <g class="plane-engine-1">
                <circle cx="35" cy="40" r="4" fill="#dc2626" stroke="#ef4444" stroke-width="1"/>
                <circle cx="35" cy="40" r="2" fill="#fbbf24" opacity="0.8"/>
              </g>
              <g class="plane-engine-2">
                <circle cx="65" cy="40" r="4" fill="#dc2626" stroke="#ef4444" stroke-width="1"/>
                <circle cx="65" cy="40" r="2" fill="#fbbf24" opacity="0.8"/>
              </g>
              <g class="plane-engine-3">
                <circle cx="35" cy="60" r="4" fill="#dc2626" stroke="#ef4444" stroke-width="1"/>
                <circle cx="35" cy="60" r="2" fill="#fbbf24" opacity="0.8"/>
              </g>
              <g class="plane-engine-4">
                <circle cx="65" cy="60" r="4" fill="#dc2626" stroke="#ef4444" stroke-width="1"/>
                <circle cx="65" cy="60" r="2" fill="#fbbf24" opacity="0.8"/>
              </g>
            </svg>`
          }
        };
        
        const config = shipConfigs[ship.type] || shipConfigs[ShipType.CONTAINER];
        
        // Create ship icon with glow effect and shadow
        el.innerHTML = `
          <div class="ship-icon-container" style="
            width: 100%;
            height: 100%;
            position: relative;
            filter: drop-shadow(0 4px 8px rgba(0,0,0,0.3)) drop-shadow(0 0 20px ${config.shadowColor});
          ">
            <!-- Glow effect -->
            <div class="ship-glow" style="
              position: absolute;
              top: 50%;
              left: 50%;
              transform: translate(-50%, -50%);
              width: 120%;
              height: 120%;
              background: radial-gradient(circle, ${config.shadowColor}40 0%, transparent 70%);
              animation: pulse 2s ease-in-out infinite;
              pointer-events: none;
            "></div>
            
            <!-- Ship icon -->
            <div class="ship-icon" style="
              width: 100%;
              height: 100%;
              position: relative;
              animation: ${ship.type === ShipType.CARGO_PLANE ? 'float' : 'bob'} 3s ease-in-out infinite;
            ">
              ${config.icon}
            </div>
            
            <!-- Status indicator -->
            <div class="ship-status" style="
              position: absolute;
              top: -5px;
              right: -5px;
              width: 16px;
              height: 16px;
              border-radius: 50%;
              background: ${ship.status === ShipStatus.SAILING ? '#10b981' : 
                           ship.status === ShipStatus.IDLE ? '#f59e0b' : 
                           ship.status === ShipStatus.LOADING ? '#3b82f6' : 
                           ship.status === ShipStatus.UNLOADING ? '#3b82f6' : 
                           ship.status === ShipStatus.MAINTENANCE ? '#ef4444' : '#6b7280'};
              border: 2px solid white;
              box-shadow: 0 0 10px ${ship.status === ShipStatus.SAILING ? '#10b981' : 
                                     ship.status === ShipStatus.IDLE ? '#f59e0b' : 
                                     ship.status === ShipStatus.LOADING ? '#3b82f6' : 
                                     ship.status === ShipStatus.UNLOADING ? '#3b82f6' : 
                                     ship.status === ShipStatus.MAINTENANCE ? '#ef4444' : '#6b7280'};
              animation: ${ship.status === ShipStatus.SAILING ? 'statusPulse' : 'none'} 1.5s ease-in-out infinite;
            "></div>
            
            <!-- Wave effect for ships -->
            ${ship.type !== ShipType.CARGO_PLANE ? `
              <div class="ship-wake" style="
                position: absolute;
                bottom: -10px;
                left: 50%;
                transform: translateX(-50%);
                width: 60px;
                height: 20px;
                opacity: ${ship.status === ShipStatus.SAILING ? '1' : '0'};
                transition: opacity 0.3s;
              ">
                <svg viewBox="0 0 60 20" style="width: 100%; height: 100%;">
                  <path d="M 5 10 Q 15 5, 30 10 T 55 10" 
                        fill="none" 
                        stroke="#60a5fa" 
                        stroke-width="2" 
                        opacity="0.6"
                        class="wave-1"/>
                  <path d="M 10 15 Q 20 10, 30 15 T 50 15" 
                        fill="none" 
                        stroke="#93c5fd" 
                        stroke-width="1.5" 
                        opacity="0.4"
                        class="wave-2"/>
                </svg>
              </div>
            ` : ''}
          </div>
          
          <!-- Ship name label -->
          <div class="ship-label" style="
            position: absolute;
            bottom: -25px;
            left: 50%;
            transform: translateX(-50%);
            background: rgba(0, 0, 0, 0.9);
            color: white;
            padding: 4px 12px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: 600;
            white-space: nowrap;
            border: 1px solid ${config.color};
            box-shadow: 0 2px 4px rgba(0,0,0,0.3), 0 0 10px ${config.shadowColor}40;
            backdrop-filter: blur(4px);
          ">
            ${ship.name}
          </div>
        `;
        
        // Add CSS animations
        if (!document.querySelector('#ship-marker-styles')) {
          const style = document.createElement('style');
          style.id = 'ship-marker-styles';
          style.textContent = `
            @keyframes pulse {
              0% { 
                transform: translate(-50%, -50%) scale(1);
                opacity: 0.8;
              }
              50% { 
                transform: translate(-50%, -50%) scale(1.3);
                opacity: 0.4;
              }
              100% { 
                transform: translate(-50%, -50%) scale(1);
                opacity: 0.8;
              }
            }
            
            @keyframes bob {
              0%, 100% { transform: translateY(0); }
              50% { transform: translateY(-3px); }
            }
            
            @keyframes float {
              0%, 100% { transform: translateY(0) scale(1); }
              50% { transform: translateY(-5px) scale(1.02); }
            }
            
            @keyframes statusPulse {
              0%, 100% { 
                transform: scale(1);
                opacity: 1;
              }
              50% { 
                transform: scale(1.2);
                opacity: 0.8;
              }
            }
            
            @keyframes radar {
              0% { 
                transform: scale(1);
                opacity: 1;
              }
              100% { 
                transform: scale(1.5);
                opacity: 0;
              }
            }
            
            /* Wave animations */
            .wave-1 {
              animation: wave1 2s ease-in-out infinite;
            }
            
            .wave-2 {
              animation: wave2 2s ease-in-out infinite 0.5s;
            }
            
            @keyframes wave1 {
              0%, 100% { 
                d: path("M 5 10 Q 15 5, 30 10 T 55 10");
                opacity: 0.6;
              }
              50% { 
                d: path("M 5 10 Q 15 8, 30 10 T 55 10");
                opacity: 0.3;
              }
            }
            
            @keyframes wave2 {
              0%, 100% { 
                d: path("M 10 15 Q 20 10, 30 15 T 50 15");
                opacity: 0.4;
              }
              50% { 
                d: path("M 10 15 Q 20 12, 30 15 T 50 15");
                opacity: 0.2;
              }
            }
            
            /* Engine flame animations for planes */
            .plane-engine-1 circle:last-child,
            .plane-engine-2 circle:last-child,
            .plane-engine-3 circle:last-child,
            .plane-engine-4 circle:last-child {
              animation: engineFlame 0.1s ease-in-out infinite;
            }
            
            @keyframes engineFlame {
              0%, 100% { 
                transform: scale(1);
                opacity: 0.8;
              }
              50% { 
                transform: scale(1.2);
                opacity: 1;
              }
            }
            
            /* Hover effects */
            .ship-marker:hover .ship-icon {
              animation-duration: 1.5s !important;
            }
            
            .ship-marker:hover .ship-glow {
              animation-duration: 1s !important;
            }
          `;
          document.head.appendChild(style);
        }
        
        // Add click handler
        el.addEventListener('click', () => {
          selectShip(ship.id);
          // Camera will automatically follow due to selection change
        });
        
        // Create marker with initial position
        const shipCoords = positionToLatLng(new THREE.Vector3(ship.position.x, ship.position.y, ship.position.z));
        
        console.log(`Creating marker for ship ${ship.name}:`, {
          shipPosition: ship.position,
          convertedCoords: shipCoords,
          shipStatus: ship.status,
          shipType: ship.type
        });
        
        marker = new mapboxgl.Marker({
          element: el,
          rotation: 0,
          pitchAlignment: 'viewport',
          rotationAlignment: 'viewport',
          anchor: 'center',
          offset: [0, 0]
        })
          .setLngLat([shipCoords.lng, shipCoords.lat]);
        
        if (map.current) {
          try {
            marker.addTo(map.current);
            
            // Force marker to be visible
            const markerContainer = marker.getElement();
            if (markerContainer) {
              markerContainer.style.zIndex = '9999';
              markerContainer.style.pointerEvents = 'auto';
              console.log(`Ship marker added successfully for ${ship.name}`);
            }
          } catch (error) {
            console.error(`Failed to add marker for ship ${ship.name}:`, error);
          }
        }
        
        shipMarkers.current.set(ship.id, marker);
      } else {
        // Animate marker position update
        const currentLngLat = marker.getLngLat();
        const shipCoords = positionToLatLng(new THREE.Vector3(ship.position.x, ship.position.y, ship.position.z));
        const targetLng = shipCoords.lng;
        const targetLat = shipCoords.lat;
        
        // Only update if position has changed significantly
        if (Math.abs(currentLngLat.lng - targetLng) > 0.0001 || 
            Math.abs(currentLngLat.lat - targetLat) > 0.0001) {
          marker.setLngLat([targetLng, targetLat]);
          
          // Ensure marker is visible
          const element = marker.getElement();
          if (element) {
            element.style.display = 'block';
            element.style.opacity = '1';
            element.style.visibility = 'visible';
          }
        }
        
        // Update rotation based on ship movement or heading
        if ((ship as any).rotation !== undefined) {
          // Use calculated rotation from game store
          marker.setRotation((ship as any).rotation * (180 / Math.PI));
        } else if (ship.destination) {
          // Calculate rotation based on destination
          const destCoords = positionToLatLng(new THREE.Vector3(ship.destination.position.x, ship.destination.position.y, ship.destination.position.z));
          const dx = destCoords.lng - targetLng;
          const dy = destCoords.lat - targetLat;
          const angle = Math.atan2(dx, -dy) * (180 / Math.PI);
          marker.setRotation(angle);
        }
      }
      
      // Update marker style based on selection and status
      const el = marker.getElement();
      if (el) {
        const iconContainer = el.querySelector('.ship-icon-container') as HTMLElement;
        if (iconContainer) {
          // Get the ship's color based on type
          const shipColors = {
            [ShipType.CONTAINER]: '#60a5fa',
            [ShipType.BULK]: '#34d399',
            [ShipType.TANKER]: '#fb923c',
            [ShipType.CARGO_PLANE]: '#a78bfa'
          };
          const shadowColor = shipColors[ship.type] || '#60a5fa';
          
          if (ship.id === selectedShipId) {
            iconContainer.style.transform = 'scale(1.2)';
            iconContainer.style.filter = `drop-shadow(0 4px 12px rgba(0,0,0,0.4)) drop-shadow(0 0 30px ${shadowColor})`;
            
            // Add selection ring
            if (!el.querySelector('.selection-ring')) {
              const ring = document.createElement('div');
              ring.className = 'selection-ring';
              ring.style.cssText = `
                position: absolute;
                top: 50%;
                left: 50%;
                transform: translate(-50%, -50%);
                width: 120px;
                height: 120px;
                border: 3px solid ${shadowColor};
                border-radius: 50%;
                pointer-events: none;
                animation: selectionPulse 2s ease-in-out infinite;
              `;
              iconContainer.appendChild(ring);
              
              // Add the animation if it doesn't exist
              if (!document.querySelector('#selection-ring-animation')) {
                const style = document.createElement('style');
                style.id = 'selection-ring-animation';
                style.textContent = `
                  @keyframes selectionPulse {
                    0%, 100% {
                      transform: translate(-50%, -50%) scale(1);
                      opacity: 1;
                    }
                    50% {
                      transform: translate(-50%, -50%) scale(1.3);
                      opacity: 0.5;
                    }
                  }
                `;
                document.head.appendChild(style);
              }
            }
          } else {
            iconContainer.style.transform = 'scale(1)';
            iconContainer.style.filter = `drop-shadow(0 4px 8px rgba(0,0,0,0.3)) drop-shadow(0 0 20px ${shadowColor})`;
            
            // Remove selection ring
            const ring = el.querySelector('.selection-ring');
            if (ring) {
              ring.remove();
            }
          }
        }
      }
      
      // Update status indicator
      const statusDiv = el.querySelector('.ship-status') as HTMLElement;
      if (statusDiv) {
        // Update status indicator color based on ShipStatus enum
        const statusColors = {
          [ShipStatus.SAILING]: '#10b981',
          [ShipStatus.IDLE]: '#f59e0b',
          [ShipStatus.LOADING]: '#3b82f6',
          [ShipStatus.UNLOADING]: '#3b82f6',
          [ShipStatus.MAINTENANCE]: '#ef4444'
        };
        const statusColor = statusColors[ship.status] || '#6b7280';
        statusDiv.style.background = statusColor;
        statusDiv.style.boxShadow = `0 0 10px ${statusColor}`;
        statusDiv.style.animation = ship.status === ShipStatus.SAILING ? 'statusPulse 1.5s ease-in-out infinite' : 'none';
      }
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [fleet, selectedShipId]);
  
  // Add ship routes
  useEffect(() => {
    if (!map.current || !isMapLoaded) return;
    
    // Wait for style to be loaded
    if (!map.current.isStyleLoaded()) {
      const checkStyleLoaded = () => {
        if (map.current?.isStyleLoaded()) {
          map.current.off('styledata', checkStyleLoaded);
          updateRoutes();
        }
      };
      map.current.on('styledata', checkStyleLoaded);
      return;
    }
    
    updateRoutes();
    
    function updateRoutes() {
      if (!map.current) return;
      
      // Remove existing routes and layers safely
      try {
        if (map.current.getLayer('ship-routes-animated')) {
          map.current.removeLayer('ship-routes-animated');
        }
        if (map.current.getLayer('ship-routes')) {
          map.current.removeLayer('ship-routes');
        }
        if (map.current.getSource('ship-routes')) {
          map.current.removeSource('ship-routes');
        }
      } catch (e) {
        // Ignore errors if layers/sources don't exist
      }
    
    // Create routes GeoJSON
    const routes: GeoJSON.Feature[] = fleet
      .filter(ship => ship.destination)
      .map(ship => ({
        type: 'Feature',
        properties: {
          shipId: ship.id,
          selected: ship.id === selectedShipId
        },
        geometry: {
          type: 'LineString',
          coordinates: (() => {
            const startCoords = positionToLatLng(new THREE.Vector3(ship.position.x, ship.position.y, ship.position.z));
            const endCoords = positionToLatLng(new THREE.Vector3(ship.destination!.position.x, ship.destination!.position.y, ship.destination!.position.z));
            return [
              [startCoords.lng, startCoords.lat],
              [endCoords.lng, endCoords.lat]
            ];
          })()
        }
      }));
    
    if (routes.length > 0) {
      // Add routes source
      map.current.addSource('ship-routes', {
        type: 'geojson',
        data: {
          type: 'FeatureCollection',
          features: routes
        }
      });
      
      // Add routes layer with gradient effect
      map.current.addLayer({
        id: 'ship-routes',
        type: 'line',
        source: 'ship-routes',
        layout: {
          'line-join': 'round',
          'line-cap': 'round'
        },
        paint: {
          'line-color': [
            'case',
            ['get', 'selected'],
            '#3b82f6',
            '#64748b'
          ],
          'line-width': [
            'case',
            ['get', 'selected'],
            4,
            2
          ],
          'line-opacity': [
            'case',
            ['get', 'selected'],
            0.9,
            0.6
          ],
          'line-dasharray': [0.1, 2],
          'line-blur': 0.5
        }
      });
      
      // Add animated dashed overlay for selected routes
      map.current.addLayer({
        id: 'ship-routes-animated',
        type: 'line',
        source: 'ship-routes',
        filter: ['==', 'selected', true],
        layout: {
          'line-join': 'round',
          'line-cap': 'round'
        },
        paint: {
          'line-color': '#60a5fa',
          'line-width': 2,
          'line-opacity': 0.8,
          'line-dasharray': [2, 4],
          'line-offset': 0
        }
      });
    }
    }
  }, [fleet, selectedShipId, isMapLoaded]);

  return (
    <div style={{ width: '100%', height: '100%', position: 'relative' }}>
      {!isMapLoaded && !mapError && (
        <div style={{ 
          position: 'absolute',
          top: '50%',
          left: '50%',
          transform: 'translate(-50%, -50%)',
          color: '#64748b', 
          textAlign: 'center',
          zIndex: 10
        }}>
          <div className="mapbox-globe-loading"></div>
          <p style={{ marginTop: '20px' }}>Loading map...</p>
        </div>
      )}
      {mapError && (
        <div style={{ 
          position: 'absolute',
          top: '50%',
          left: '50%',
          transform: 'translate(-50%, -50%)',
          color: '#ef4444', 
          textAlign: 'center',
          zIndex: 10,
          maxWidth: '400px',
          padding: '20px',
          background: 'rgba(0, 0, 0, 0.8)',
          borderRadius: '8px',
          border: '1px solid #ef4444'
        }}>
          <h3 style={{ margin: '0 0 10px 0' }}>Map Loading Error</h3>
          <p style={{ margin: '0 0 10px 0' }}>{mapError}</p>
          <p style={{ margin: '0', fontSize: '14px', color: '#94a3b8' }}>
            Please check the browser console for more details.
          </p>
        </div>
      )}
      <div 
        ref={mapContainer} 
        className={`mapbox-globe-container ${className || ''}`}
        style={{ 
          width: '100%', 
          height: '100%'
        }}
      />
      
      {/* Camera Controls */}
      <div style={{
        position: 'absolute',
        top: '20px',
        right: '80px',
        zIndex: 100,
        display: 'flex',
        flexDirection: 'column',
        gap: '10px',
        background: 'rgba(255, 255, 255, 0.1)',
        backdropFilter: 'blur(10px)',
        padding: '15px',
        borderRadius: '12px',
        border: '1px solid rgba(255, 255, 255, 0.2)'
      }}>
        <div style={{ fontSize: '12px', fontWeight: '600', color: '#ffffff', marginBottom: '5px' }}>
          Camera Controls
        </div>
        
        {/* Follow Mode Toggle */}
        <button
          onClick={() => setFollowMode(!followMode)}
          style={{
            padding: '10px 20px',
            background: followMode ? '#3b82f6' : 'rgba(255, 255, 255, 0.9)',
            color: followMode ? 'white' : '#1f2937',
            border: 'none',
            borderRadius: '8px',
            cursor: 'pointer',
            fontSize: '14px',
            fontWeight: '500',
            boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
            transition: 'all 0.2s',
            display: 'flex',
            alignItems: 'center',
            gap: '8px'
          }}
        >
          {followMode ? '🎯' : '🔓'} {followMode ? 'Following Ship' : 'Manual Control'}
        </button>
        
        {/* Camera Mode Selector */}
        <div style={{ display: 'flex', gap: '5px' }}>
          <button
            onClick={() => setCameraMode('cinematic')}
            style={{
              flex: 1,
              padding: '8px',
              background: cameraMode === 'cinematic' ? '#8b5cf6' : 'rgba(255, 255, 255, 0.9)',
              color: cameraMode === 'cinematic' ? 'white' : '#1f2937',
              border: 'none',
              borderRadius: '6px',
              cursor: 'pointer',
              fontSize: '12px',
              fontWeight: '500',
              transition: 'all 0.2s'
            }}
            title="Cinematic camera with dynamic angles"
          >
            🎬
          </button>
          <button
            onClick={() => setCameraMode('top-down')}
            style={{
              flex: 1,
              padding: '8px',
              background: cameraMode === 'top-down' ? '#8b5cf6' : 'rgba(255, 255, 255, 0.9)',
              color: cameraMode === 'top-down' ? 'white' : '#1f2937',
              border: 'none',
              borderRadius: '6px',
              cursor: 'pointer',
              fontSize: '12px',
              fontWeight: '500',
              transition: 'all 0.2s'
            }}
            title="Top-down view"
          >
            🔽
          </button>
          <button
            onClick={() => setCameraMode('chase')}
            style={{
              flex: 1,
              padding: '8px',
              background: cameraMode === 'chase' ? '#8b5cf6' : 'rgba(255, 255, 255, 0.9)',
              color: cameraMode === 'chase' ? 'white' : '#1f2937',
              border: 'none',
              borderRadius: '6px',
              cursor: 'pointer',
              fontSize: '12px',
              fontWeight: '500',
              transition: 'all 0.2s'
            }}
            title="Chase camera behind ship"
          >
            🚁
          </button>
        </div>
        
        {/* Speed indicator when following */}
        {followMode && selectedShipId && (() => {
          const ship = fleet.find(s => s.id === selectedShipId);
          if (ship) {
            const coords = positionToLatLng(new THREE.Vector3(ship.position.x, ship.position.y, ship.position.z));
            const speed = calculateShipSpeed(ship.id, coords);
            return (
              <div style={{
                fontSize: '11px',
                color: '#94a3b8',
                textAlign: 'center',
                marginTop: '5px'
              }}>
                Speed: {speed.toFixed(1)} km/h
              </div>
            );
          }
          return null;
        })()}
      </div>
      
      {/* Weather Controls */}
      <div style={{
        position: 'absolute',
        top: '20px',
        left: '20px',
        zIndex: 100,
        display: 'flex',
        flexDirection: 'column',
        gap: '10px'
      }}>
        <button
          onClick={() => setShowWeather(!showWeather)}
          style={{
            padding: '10px 20px',
            background: showWeather ? '#3b82f6' : 'rgba(255, 255, 255, 0.9)',
            color: showWeather ? 'white' : '#1f2937',
            border: 'none',
            borderRadius: '8px',
            cursor: 'pointer',
            fontSize: '14px',
            fontWeight: '500',
            boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
            transition: 'all 0.2s'
          }}
        >
          🌤️ Weather Forecast
        </button>
        
        <button
          onClick={() => {
            setShowRain(!showRain);
            // Trigger rain animation
            if (!showRain) {
              const canvas = document.getElementById('rain-canvas') as HTMLCanvasElement;
              if (canvas) {
                canvas.style.display = 'block';
                // Add rain source and layer to map
                if (map.current) {
                  if (!map.current.getSource('rain-overlay')) {
                    // Create initial image source
                    const dataUrl = canvas.toDataURL();
                    map.current.addSource('rain-overlay', {
                      type: 'image',
                      url: dataUrl,
                      coordinates: [
                        [-180, 85],
                        [180, 85],
                        [180, -85],
                        [-180, -85]
                      ]
                    });
                  }
                  if (!map.current.getLayer('rain-layer')) {
                    map.current.addLayer({
                      id: 'rain-layer',
                      type: 'raster',
                      source: 'rain-overlay',
                      paint: {
                        'raster-opacity': 0.3,
                        'raster-fade-duration': 0
                      }
                    });
                  }
                  // Start animation
                  if ((canvas as any).startAnimation) {
                    (canvas as any).startAnimation();
                  }
                }
              }
            } else {
              // Remove rain
              const canvas = document.getElementById('rain-canvas') as HTMLCanvasElement;
              if (canvas && (canvas as any).stopAnimation) {
                (canvas as any).stopAnimation();
              }
              if (map.current) {
                if (map.current.getLayer('rain-layer')) {
                  map.current.removeLayer('rain-layer');
                }
                if (map.current.getSource('rain-overlay')) {
                  map.current.removeSource('rain-overlay');
                }
              }
              if (canvas) {
                canvas.style.display = 'none';
              }
            }
          }}
          style={{
            padding: '10px 20px',
            background: showRain ? '#6366f1' : 'rgba(255, 255, 255, 0.9)',
            color: showRain ? 'white' : '#1f2937',
            border: 'none',
            borderRadius: '8px',
            cursor: 'pointer',
            fontSize: '14px',
            fontWeight: '500',
            boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
            transition: 'all 0.2s'
          }}
        >
          🌧️ Rain Effect
        </button>
      </div>
      
      {!isMapLoaded && (
        <div style={{
          position: 'absolute',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          background: '#000814',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 1000
        }}>
          <div className="mapbox-globe-loading"></div>
        </div>
      )}
    </div>
  );
};