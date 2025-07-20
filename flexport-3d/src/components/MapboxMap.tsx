// @ts-nocheck
import React, { useEffect, useRef, useCallback } from 'react';
import mapboxgl from 'mapbox-gl';
import 'mapbox-gl/dist/mapbox-gl.css';
import { useGameStore } from '../store/gameStore';
import { getWaterRoute, calculateBearing } from '../services/waterNavigation';

// Set Mapbox access token
mapboxgl.accessToken = process.env.REACT_APP_MAPBOX_TOKEN || '';

// Realistic ship speeds in knots (nautical miles per hour)
const SHIP_SPEEDS = {
  CONTAINER: 24,  // Modern container ships
  BULK: 15,       // Bulk carriers
  TANKER: 16,     // Oil tankers
  CARGO_PLANE: 500 // Cargo planes (much faster)
};

// Convert knots to degrees per second for map movement
const KNOTS_TO_DEGREES_PER_SECOND = 0.000005; // Adjusted for visual appeal on map

interface MapboxMapProps {
  className?: string;
}

export const MapboxMap: React.FC<MapboxMapProps> = ({ className }) => {
  const mapContainerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<mapboxgl.Map | null>(null);
  const animationRef = useRef<number | null>(null);
  const shipAnimationsRef = useRef<Map<string, any>>(new Map());
  const lastUpdateRef = useRef<number>(Date.now());
  const { fleet, ports } = useGameStore();

  useEffect(() => {
    if (!mapContainerRef.current || mapRef.current) return;

    // Small delay to ensure container has dimensions
    const initMap = () => {
      if (!mapContainerRef.current) return;
      
      // console.log('Initializing MapboxMap with token:', mapboxgl.accessToken ? 'Token set' : 'No token');
      // console.log('Container element:', mapContainerRef.current);
      // console.log('Container dimensions:', mapContainerRef.current.offsetWidth, mapContainerRef.current.offsetHeight);
      
      // Clear any existing map content
      mapContainerRef.current.innerHTML = '';
      
      // Initialize map with globe projection
      const map = new mapboxgl.Map({
        container: mapContainerRef.current,
        style: 'mapbox://styles/mapbox/satellite-v9',
        center: [-90, 40],
        zoom: 1.5,
        projection: 'globe' as any,
        pitch: 0,
        bearing: 0
      });

      mapRef.current = map;
      
      map.on('load', () => {
        // console.log('MapboxMap loaded successfully');
        // Set fog for atmosphere effect
        map.setFog({
          color: 'rgb(186, 210, 235)', // Light blue-gray
          'high-color': 'rgb(36, 92, 223)', // Upper atmosphere color
          'horizon-blend': 0.02, // Sharpness of horizon
          'space-color': 'rgb(11, 11, 25)', // Color of space
          'star-intensity': 0.6 // Stars visibility
        });
      });
      
      map.on('error', (e) => {
        console.error('MapboxMap error:', e);
      });

      // Add navigation controls
      map.addControl(new mapboxgl.NavigationControl({
        showCompass: true,
        visualizePitch: true
      }), 'top-right');
      
      // Globe rotation settings
      const secondsPerRevolution = 120;
      const maxSpinZoom = 5;
      const slowSpinZoom = 3;
      let userInteracting = false;
      let spinEnabled = true;
      
      // Spin globe function
      const spinGlobe = () => {
        const zoom = map.getZoom();
        if (spinEnabled && !userInteracting && zoom < maxSpinZoom) {
          let distancePerSecond = 360 / secondsPerRevolution;
          if (zoom > slowSpinZoom) {
            // Slow spinning at higher zooms
            const zoomDif = (maxSpinZoom - zoom) / (maxSpinZoom - slowSpinZoom);
            distancePerSecond *= zoomDif;
          }
          const center = map.getCenter();
          center.lng -= distancePerSecond;
          // Smoothly animate the map over one second
          map.easeTo({ center, duration: 1000, easing: (n: number) => n });
        }
      };
      
      // Pause spinning on interaction
      map.on('mousedown', () => { userInteracting = true; });
      map.on('touchstart', () => { userInteracting = true; });
      
      // Restart spinning when interaction is complete
      map.on('mouseup', () => { userInteracting = false; spinGlobe(); });
      map.on('touchend', () => { userInteracting = false; spinGlobe(); });
      map.on('dragend', () => { userInteracting = false; spinGlobe(); });
      map.on('pitchend', () => { userInteracting = false; spinGlobe(); });
      map.on('rotateend', () => { userInteracting = false; spinGlobe(); });
      
      // When animation is complete, start spinning if there is no ongoing interaction
      map.on('moveend', () => { spinGlobe(); });
      
      // Store spin control functions on map instance for toggle button
      (map as any)._spinEnabled = spinEnabled;
      (map as any)._spinGlobe = spinGlobe;
      (map as any)._toggleSpin = () => {
        spinEnabled = !spinEnabled;
        (map as any)._spinEnabled = spinEnabled;
        if (spinEnabled) {
          spinGlobe();
        } else {
          map.stop();
        }
        return spinEnabled;
      };

      // Initialize ship animations
      initializeShipAnimations();

      // Add atmosphere styling
      map.on('style.load', () => {
        // console.log('MapboxMap style loaded - adding layers');
        
        // Start globe rotation after style loads
        spinGlobe();
        
        // Check if we already initialized layers to prevent duplicate image additions
        if (map._layersInitialized) return;
        map._layersInitialized = true;
        
        // Disable fog for now to see ports clearly
        // map.setFog({
        //   color: 'rgb(186, 210, 235)', // Light blue-gray
        //   'high-color': 'rgb(36, 92, 223)', // Upper atmosphere color
        //   'horizon-blend': 0.02, // Sharpness of horizon
        //   'space-color': 'rgb(11, 11, 25)', // Color of space
        //   'star-intensity': 0.6 // Stars visibility
        // });
        
        // Test ports removed - actual game ports are loaded from game store
        
        // Create professional container ship icon
        const createCargoShipIcon = (color: string, status: string) => {
          const size = 64;
          const canvas = document.createElement('canvas');
          canvas.width = size;
          canvas.height = size;
          const ctx = canvas.getContext('2d');
          if (!ctx) return null;
          
          // Clear canvas
          ctx.clearRect(0, 0, size, size);
          
          ctx.save();
          ctx.translate(size / 2, size / 2);
          ctx.scale(1.2, 1.2);
          
          // Hull
          ctx.beginPath();
          ctx.moveTo(-25, 5);
          ctx.lineTo(25, 5);
          ctx.lineTo(20, 15);
          ctx.lineTo(-20, 15);
          ctx.closePath();
          ctx.fillStyle = '#3B3B3B';
          ctx.fill();
          
          // Container layers
          ctx.fillStyle = '#E74C3C';
          ctx.fillRect(-20, -5, 40, 10);
          ctx.fillStyle = '#3498DB';
          ctx.fillRect(-15, -10, 30, 5);
          ctx.fillStyle = '#2ECC71';
          ctx.fillRect(-10, -15, 20, 5);
          
          // Bridge windows
          ctx.fillStyle = '#ECF0F1';
          ctx.fillRect(-5, 0, 2, 5);
          ctx.fillRect(3, 0, 2, 5);
          
          // Status effects
          if (status === 'SAILING') {
            ctx.strokeStyle = 'rgba(255, 255, 255, 0.6)';
            ctx.lineWidth = 2;
            ctx.setLineDash([2, 2]);
            ctx.beginPath();
            ctx.moveTo(0, 15);
            ctx.lineTo(-5, 20);
            ctx.moveTo(0, 15);
            ctx.lineTo(5, 20);
            ctx.stroke();
            ctx.setLineDash([]);
          }
          
          ctx.restore();
          
          // Return ImageData instead of canvas
          return ctx.getImageData(0, 0, size, size);
        };
        
        // Create professional bulk carrier icon
        const createBulkCarrierIcon = (color: string, status: string) => {
          const size = 64;
          const canvas = document.createElement('canvas');
          canvas.width = size;
          canvas.height = size;
          const ctx = canvas.getContext('2d');
          if (!ctx) return null;
          
          ctx.clearRect(0, 0, size, size);
          
          ctx.save();
          ctx.translate(size / 2, size / 2);
          ctx.scale(1.2, 1.2);
          
          // Hull
          ctx.beginPath();
          ctx.moveTo(-22, 5);
          ctx.lineTo(22, 5);
          ctx.lineTo(18, 15);
          ctx.lineTo(-18, 15);
          ctx.closePath();
          ctx.fillStyle = '#34495E';
          ctx.fill();
          
          // Cargo hold area
          ctx.fillStyle = '#95A5A6';
          ctx.strokeStyle = '#7F8C8D';
          ctx.lineWidth = 1;
          ctx.fillRect(-18, -5, 36, 10);
          ctx.strokeRect(-18, -5, 36, 10);
          
          // Bulk cargo circles
          ctx.fillStyle = '#F39C12';
          ctx.beginPath();
          ctx.arc(-10, 0, 3, 0, Math.PI * 2);
          ctx.fill();
          ctx.beginPath();
          ctx.arc(0, 0, 3, 0, Math.PI * 2);
          ctx.fill();
          ctx.beginPath();
          ctx.arc(10, 0, 3, 0, Math.PI * 2);
          ctx.fill();
          
          // Bridge
          ctx.fillStyle = '#E74C3C';
          ctx.fillRect(-5, -10, 10, 5);
          
          // Status effects
          if (status === 'SAILING') {
            ctx.strokeStyle = 'rgba(255, 255, 255, 0.6)';
            ctx.lineWidth = 2;
            ctx.setLineDash([2, 2]);
            ctx.beginPath();
            ctx.moveTo(0, 15);
            ctx.lineTo(-5, 20);
            ctx.moveTo(0, 15);
            ctx.lineTo(5, 20);
            ctx.stroke();
            ctx.setLineDash([]);
          }
          
          ctx.restore();
          return ctx.getImageData(0, 0, size, size);
        };
        
        // Create professional tanker icon
        const createTankerIcon = (color: string, status: string) => {
          const size = 64;
          const canvas = document.createElement('canvas');
          canvas.width = size;
          canvas.height = size;
          const ctx = canvas.getContext('2d');
          if (!ctx) return null;
          
          ctx.clearRect(0, 0, size, size);
          
          ctx.save();
          ctx.translate(size / 2, size / 2);
          ctx.scale(1.2, 1.2);
          
          // Hull
          ctx.beginPath();
          ctx.moveTo(-20, 5);
          ctx.lineTo(20, 5);
          ctx.lineTo(15, 15);
          ctx.lineTo(-15, 15);
          ctx.closePath();
          ctx.fillStyle = '#2C3E50';
          ctx.fill();
          
          // Tank (main)
          ctx.beginPath();
          ctx.ellipse(0, 0, 18, 5, 0, 0, Math.PI * 2);
          ctx.fillStyle = '#E74C3C';
          ctx.fill();
          
          // Tank (top)
          ctx.beginPath();
          ctx.ellipse(0, -5, 15, 4, 0, 0, Math.PI * 2);
          ctx.fillStyle = '#C0392B';
          ctx.fill();
          
          // Bridge/Tower
          ctx.fillStyle = '#ECF0F1';
          ctx.fillRect(-2, -10, 4, 5);
          
          // Beacon
          ctx.fillStyle = '#F39C12';
          ctx.beginPath();
          ctx.arc(0, -12, 2, 0, Math.PI * 2);
          ctx.fill();
          
          // Status effects
          if (status === 'SAILING') {
            ctx.strokeStyle = 'rgba(255, 255, 255, 0.6)';
            ctx.lineWidth = 2;
            ctx.setLineDash([2, 2]);
            ctx.beginPath();
            ctx.moveTo(0, 15);
            ctx.lineTo(-5, 20);
            ctx.moveTo(0, 15);
            ctx.lineTo(5, 20);
            ctx.stroke();
            ctx.setLineDash([]);
          }
          
          ctx.restore();
          return ctx.getImageData(0, 0, size, size);
        };
        
        // Create cargo plane icon
        const createCargoPlaneIcon = (color: string, status: string) => {
          const size = 64;
          const canvas = document.createElement('canvas');
          canvas.width = size;
          canvas.height = size;
          const ctx = canvas.getContext('2d');
          if (!ctx) return null;
          
          ctx.clearRect(0, 0, size, size);
          
          ctx.save();
          ctx.translate(size / 2, size / 2);
          ctx.scale(1.2, 1.2);
          
          // Fuselage
          ctx.beginPath();
          ctx.moveTo(0, -24);
          ctx.lineTo(4, -20);
          ctx.lineTo(4, 16);
          ctx.lineTo(0, 20);
          ctx.lineTo(-4, 16);
          ctx.lineTo(-4, -20);
          ctx.closePath();
          
          ctx.fillStyle = color;
          ctx.fill();
          ctx.strokeStyle = '#ffffff';
          ctx.lineWidth = 2;
          ctx.stroke();
          
          // Wings
          ctx.beginPath();
          ctx.moveTo(-20, -4);
          ctx.lineTo(-6, -2);
          ctx.lineTo(-6, 2);
          ctx.lineTo(-20, 0);
          ctx.closePath();
          ctx.fill();
          ctx.stroke();
          
          ctx.beginPath();
          ctx.moveTo(20, -4);
          ctx.lineTo(6, -2);
          ctx.lineTo(6, 2);
          ctx.lineTo(20, 0);
          ctx.closePath();
          ctx.fill();
          ctx.stroke();
          
          // Tail
          ctx.beginPath();
          ctx.moveTo(0, 16);
          ctx.lineTo(-6, 14);
          ctx.lineTo(-6, 18);
          ctx.lineTo(0, 20);
          ctx.lineTo(6, 18);
          ctx.lineTo(6, 14);
          ctx.closePath();
          ctx.fill();
          ctx.stroke();
          
          ctx.restore();
          return ctx.getImageData(0, 0, size, size);
        };
        
        // Create ship icons for different statuses and types
        // Container ships
        const containerIdle = createCargoShipIcon('#6b7280', 'IDLE');
        const containerSailing = createCargoShipIcon('#10b981', 'SAILING');
        const containerLoading = createCargoShipIcon('#f59e0b', 'LOADING');
        
        // Bulk carriers
        const bulkIdle = createBulkCarrierIcon('#6b7280', 'IDLE');
        const bulkSailing = createBulkCarrierIcon('#10b981', 'SAILING');
        const bulkLoading = createBulkCarrierIcon('#f59e0b', 'LOADING');
        
        // Tankers
        const tankerIdle = createTankerIcon('#6b7280', 'IDLE');
        const tankerSailing = createTankerIcon('#10b981', 'SAILING');
        const tankerLoading = createTankerIcon('#f59e0b', 'LOADING');
        
        // Cargo planes
        const planeIdle = createCargoPlaneIcon('#6b7280', 'IDLE');
        const planeSailing = createCargoPlaneIcon('#10b981', 'SAILING');
        const planeLoading = createCargoPlaneIcon('#f59e0b', 'LOADING');
        
        // Check if images already exist before adding
        const addImageSafely = (name: string, image: HTMLCanvasElement | ImageData | null) => {
          if (!image) return;
          try {
            if (map.hasImage(name)) {
              map.removeImage(name);
            }
            map.addImage(name, image);
          } catch (error) {
            console.error(`Error adding image ${name}:`, error);
          }
        };
        
        // Add all ship icons to map safely
        addImageSafely('container-idle', containerIdle);
        addImageSafely('container-sailing', containerSailing);
        addImageSafely('container-loading', containerLoading);
        
        addImageSafely('bulk-idle', bulkIdle);
        addImageSafely('bulk-sailing', bulkSailing);
        addImageSafely('bulk-loading', bulkLoading);
        
        addImageSafely('tanker-idle', tankerIdle);
        addImageSafely('tanker-sailing', tankerSailing);
        addImageSafely('tanker-loading', tankerLoading);
        
        addImageSafely('plane-idle', planeIdle);
        addImageSafely('plane-sailing', planeSailing);
        addImageSafely('plane-loading', planeLoading);
        
        // Add port source first
        // Adding ports source
        map.addSource('ports', {
          type: 'geojson',
          data: {
            type: 'FeatureCollection',
            features: []
          }
        });
        // Ports source added
        
        // Add ship source
        // Adding ships source
        map.addSource('ships', {
          type: 'geojson',
          data: {
            type: 'FeatureCollection',
            features: []
          }
        });
        // Ships source added
        
        // Add ship routes source
        // Adding ship-routes source
        map.addSource('ship-routes', {
          type: 'geojson',
          data: {
            type: 'FeatureCollection',
            features: []
          }
        });
        // Ship-routes source added
        
        // Add ship routes layer
        if (!map.getLayer('ship-routes')) {
          map.addLayer({
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
              ['==', ['get', 'shipType'], 'CARGO_PLANE'], '#8b5cf6',
              ['==', ['get', 'shipType'], 'TANKER'], '#ef4444',
              ['==', ['get', 'shipType'], 'BULK'], '#f59e0b',
              '#3b82f6' // Default for container ships
            ],
            'line-width': [
              'interpolate',
              ['linear'],
              ['zoom'],
              2, 1,
              6, 2,
              10, 3
            ],
            'line-opacity': 0.6,
            'line-dasharray': [2, 4]
          }
        });
        }
        
        // Add ship layer with cargo ship icons
        if (!map.getLayer('ships-layer')) {
          map.addLayer({
          id: 'ships-layer',
          type: 'symbol',
          source: 'ships',
          layout: {
            'icon-image': [
              'let', 'shipType', ['downcase', ['get', 'type']],
              ['let', 'status', ['downcase', ['get', 'status']],
                [
                  'case',
                  // Container ships
                  ['all', ['==', ['var', 'shipType'], 'container'], ['==', ['var', 'status'], 'sailing']], 'container-sailing',
                  ['all', ['==', ['var', 'shipType'], 'container'], ['in', ['var', 'status'], ['literal', ['loading', 'unloading']]]], 'container-loading',
                  ['==', ['var', 'shipType'], 'container'], 'container-idle',
                  // Bulk carriers
                  ['all', ['==', ['var', 'shipType'], 'bulk'], ['==', ['var', 'status'], 'sailing']], 'bulk-sailing',
                  ['all', ['==', ['var', 'shipType'], 'bulk'], ['in', ['var', 'status'], ['literal', ['loading', 'unloading']]]], 'bulk-loading',
                  ['==', ['var', 'shipType'], 'bulk'], 'bulk-idle',
                  // Tankers
                  ['all', ['==', ['var', 'shipType'], 'tanker'], ['==', ['var', 'status'], 'sailing']], 'tanker-sailing',
                  ['all', ['==', ['var', 'shipType'], 'tanker'], ['in', ['var', 'status'], ['literal', ['loading', 'unloading']]]], 'tanker-loading',
                  ['==', ['var', 'shipType'], 'tanker'], 'tanker-idle',
                  // Cargo planes
                  ['all', ['==', ['var', 'shipType'], 'cargo_plane'], ['==', ['var', 'status'], 'sailing']], 'plane-sailing',
                  ['all', ['==', ['var', 'shipType'], 'cargo_plane'], ['in', ['var', 'status'], ['literal', ['loading', 'unloading']]]], 'plane-loading',
                  ['==', ['var', 'shipType'], 'cargo_plane'], 'plane-idle',
                  // Default to container ship
                  'container-idle'
                ]
              ]
            ],
            'icon-size': [
              'interpolate',
              ['linear'],
              ['zoom'],
              2, 0.4,
              6, 0.8,
              10, 1.2
            ],
            'icon-rotate': ['get', 'bearing'],
            'icon-rotation-alignment': 'map',
            'icon-allow-overlap': true,
            'icon-anchor': 'center'
          }
        });
        }
        
        // Add ship labels with enhanced visibility
        if (!map.getLayer('ship-labels')) {
          map.addLayer({
          id: 'ship-labels',
          type: 'symbol',
          source: 'ships',
          layout: {
            'text-field': ['get', 'name'],
            'text-font': ['Open Sans Bold', 'Arial Unicode MS Bold'],
            'text-size': [
              'interpolate',
              ['linear'],
              ['zoom'],
              2, 10,
              6, 14,
              10, 16
            ],
            'text-offset': [0, 2.2],
            'text-anchor': 'top',
            'text-allow-overlap': false,
            'text-optional': true,
            'text-variable-anchor': ['top', 'bottom', 'left', 'right'],
            'text-radial-offset': 1.2
          },
          paint: {
            'text-color': [
              'case',
              ['==', ['get', 'status'], 'SAILING'], '#10b981',
              ['==', ['get', 'status'], 'LOADING'], '#f59e0b',
              ['==', ['get', 'status'], 'UNLOADING'], '#f59e0b',
              '#3b82f6'
            ],
            'text-halo-color': 'rgba(0, 0, 0, 0.8)',
            'text-halo-width': 2.5,
            'text-halo-blur': 1
          }
        });
        }
        
        // Create professional port icon
        const createPortIcon = () => {
          const size = 64;
          const canvas = document.createElement('canvas');
          canvas.width = size;
          canvas.height = size;
          const ctx = canvas.getContext('2d');
          if (!ctx) return null;
          
          ctx.clearRect(0, 0, size, size);
          
          ctx.save();
          ctx.translate(size / 2, size / 2);
          
          // Port background circle
          ctx.beginPath();
          ctx.arc(0, 0, 25, 0, Math.PI * 2);
          ctx.fillStyle = '#2ECC71';
          ctx.fill();
          ctx.strokeStyle = '#27AE60';
          ctx.lineWidth = 2;
          ctx.stroke();
          
          // Container crane structure
          ctx.fillStyle = '#ECF0F1';
          ctx.fillRect(-5, -10, 10, 20);
          
          // Crane arm
          ctx.strokeStyle = '#E74C3C';
          ctx.lineWidth = 4;
          ctx.lineCap = 'round';
          ctx.beginPath();
          ctx.moveTo(-10, -5);
          ctx.lineTo(10, -5);
          ctx.lineTo(10, 0);
          ctx.lineTo(-10, 0);
          ctx.closePath();
          ctx.stroke();
          
          // Dock/Platform
          ctx.fillStyle = '#34495E';
          ctx.fillRect(-15, 15, 30, 5);
          
          // Beacon light
          ctx.fillStyle = '#F39C12';
          ctx.beginPath();
          ctx.arc(0, -15, 3, 0, Math.PI * 2);
          ctx.fill();
          
          ctx.restore();
          return ctx.getImageData(0, 0, size, size);
        };
        
        const portIcon = createPortIcon();
        addImageSafely('port-icon', portIcon);
        
        // Add 3D port base layer - commented out for now as we're using Point geometry
        // map.addLayer({
        //   id: 'ports-3d-base',
        //   type: 'fill-extrusion',
        //   source: 'ports',
        //   paint: {
        //     'fill-extrusion-color': [
        //       'interpolate',
        //       ['linear'],
        //       ['zoom'],
        //       10, '#059669',
        //       15, '#047857'
        //     ],
        //     'fill-extrusion-height': [
        //       'interpolate',
        //       ['linear'],
        //       ['zoom'],
        //       10, 200,
        //       15, 500
        //     ],
        //     'fill-extrusion-base': 0,
        //     'fill-extrusion-opacity': 0.8
        //   }
        // });

        // Add port glow layer (outer glow effect)
        if (!map.getLayer('ports-glow')) {
          map.addLayer({
          id: 'ports-glow',
          type: 'circle',
          source: 'ports',
          paint: {
            'circle-radius': [
              'interpolate',
              ['linear'],
              ['zoom'],
              2, 12,
              6, 20,
              10, 30
            ],
            'circle-color': '#059669',
            'circle-blur': 1,
            'circle-opacity': 0.3
          }
        });
        }
        
        // Removed pulse layer due to error

        // Add port circle for all zoom levels
        if (!map.getLayer('ports-circle')) {
          map.addLayer({
          id: 'ports-circle',
          type: 'circle',
          source: 'ports',
          paint: {
            'circle-radius': [
              'interpolate',
              ['linear'],
              ['zoom'],
              2, 15,
              6, 20,
              10, 25
            ],
            'circle-color': [
              'interpolate',
              ['linear'],
              ['zoom'],
              2, '#10b981',
              6, '#059669',
              10, '#047857'
            ],
            'circle-stroke-color': '#ffffff',
            'circle-stroke-width': [
              'interpolate',
              ['linear'],
              ['zoom'],
              2, 2,
              6, 3,
              10, 4
            ],
            'circle-pitch-alignment': 'map'
          }
        });
        }

        // Add port layer
        if (!map.getLayer('ports-layer')) {
          map.addLayer({
          id: 'ports-layer',
          type: 'symbol',
          source: 'ports',
          // Removed filter since we're using Point geometry now
          layout: {
            'icon-image': 'port-icon',
            'icon-size': [
              'interpolate',
              ['linear'],
              ['zoom'],
              2, 1.0,
              6, 1.5,
              10, 1.1
            ],
            'icon-allow-overlap': true,
            'icon-anchor': 'center'
          }
        });
        }
        
        // Add port labels with better visibility
        if (!map.getLayer('port-labels')) {
          map.addLayer({
          id: 'port-labels',
          type: 'symbol',
          source: 'ports',
          layout: {
            'text-field': ['get', 'name'],
            'text-font': ['Open Sans Semibold', 'Arial Unicode MS Bold'],
            'text-size': [
              'interpolate',
              ['linear'],
              ['zoom'],
              2, 9,
              6, 12,
              10, 14
            ],
            'text-offset': [0, 2.5],
            'text-anchor': 'top',
            'text-max-width': 10,
            'text-optional': true,
            'text-variable-anchor': ['top', 'bottom', 'left', 'right'],
            'text-radial-offset': 1.5
          },
          paint: {
            'text-color': '#059669',
            'text-halo-color': 'rgba(255, 255, 255, 0.9)',
            'text-halo-width': 2,
            'text-halo-blur': 0.5
          }
        });
        }
        
        // Debug layers removed - using proper icons now
        
        // Add hover and click interactions
        let hoveredPortId: string | null = null;
        let hoveredShipId: string | null = null;
        
        // Port hover effect
        map.on('mouseenter', 'ports-circle', (e) => {
          try {
            map.getCanvas().style.cursor = 'pointer';
            if (e.features && e.features[0] && map.getLayer('ports-circle')) {
              hoveredPortId = e.features[0].properties?.id;
              // Simple hover effect without complex expressions
              if (hoveredPortId) {
                map.setPaintProperty('ports-circle', 'circle-stroke-width', 6);
              }
            }
          } catch (error) {
            console.error('Port hover error:', error);
          }
        });
        
        map.on('mouseleave', 'ports-circle', () => {
          try {
            map.getCanvas().style.cursor = '';
            if (hoveredPortId && map.getLayer('ports-circle')) {
              map.setPaintProperty('ports-circle', 'circle-stroke-width', [
                'interpolate',
                ['linear'],
                ['zoom'],
                2, 2,
                6, 3,
                10, 4
              ]);
              hoveredPortId = null;
            }
          } catch (error) {
            console.error('Port hover leave error:', error);
          }
        });
        
        // Ship hover effect
        map.on('mouseenter', 'ships-layer', (e) => {
          try {
            map.getCanvas().style.cursor = 'pointer';
            // Simple hover tooltip instead of modifying layer properties
            if (e.features && e.features[0]) {
              hoveredShipId = e.features[0].properties?.id;
            }
          } catch (error) {
            console.error('Ship hover error:', error);
          }
        });
        
        map.on('mouseleave', 'ships-layer', () => {
          try {
            map.getCanvas().style.cursor = '';
            hoveredShipId = null;
          } catch (error) {
            console.error('Ship hover leave error:', error);
          }
        });
        
        // Port click interaction
        map.on('click', 'ports-circle', (e) => {
          if (e.features && e.features[0]) {
            const port = e.features[0].properties;
            new mapboxgl.Popup()
              .setLngLat(e.lngLat)
              .setHTML(`
                <div style="padding: 10px;">
                  <h3 style="margin: 0 0 10px 0; color: #059669;">${port.name}</h3>
                  <p style="margin: 5px 0;">Port ID: ${port.id}</p>
                  <p style="margin: 5px 0;">Status: Active</p>
                  <p style="margin: 5px 0;">Capacity: High</p>
                </div>
              `)
              .addTo(map);
          }
        });
        
        // Ship click interaction
        map.on('click', 'ships-layer', (e) => {
          if (e.features && e.features[0]) {
            const ship = e.features[0].properties;
            const statusColor = ship.status === 'SAILING' ? '#10b981' : 
                              ship.status === 'LOADING' || ship.status === 'UNLOADING' ? '#f59e0b' : '#6b7280';
            new mapboxgl.Popup()
              .setLngLat(e.lngLat)
              .setHTML(`
                <div style="padding: 10px;">
                  <h3 style="margin: 0 0 10px 0; color: ${statusColor};">${ship.name}</h3>
                  <p style="margin: 5px 0;">Type: ${ship.type || 'Container'}</p>
                  <p style="margin: 5px 0;">Status: ${ship.status}</p>
                  <p style="margin: 5px 0;">Speed: ${ship.status === 'SAILING' ? '24 knots' : '0 knots'}</p>
                </div>
              `)
              .addTo(map);
          }
        });
        
        // Pulse animation removed - layer doesn't exist
        
        // Add a simple test to ensure ports are visible
        console.log('All layers initialized. Checking port layers:');
        console.log('ports-glow exists:', !!map.getLayer('ports-glow'));
        console.log('ports-circle exists:', !!map.getLayer('ports-circle'));
        console.log('ports-layer exists:', !!map.getLayer('ports-layer'));
        console.log('port-labels exists:', !!map.getLayer('port-labels'));
      });
    };
    
    // Initialize with a small delay
    setTimeout(initMap, 100);

    // Cleanup
    return () => {
      if (animationRef.current) {
        cancelAnimationFrame(animationRef.current);
      }
      if (mapRef.current) {
        mapRef.current.remove();
        mapRef.current = null;
      }
    };
  }, []);

  // Initialize ship animations
  const initializeShipAnimations = () => {
    const animations = shipAnimationsRef.current;
    
    fleet.forEach(ship => {
      if (!animations.has(ship.id)) {
        const { lat, lng } = convertPositionToLatLng(ship.position);
        animations.set(ship.id, {
          currentPosition: { lat, lng },
          targetPosition: { lat, lng },
          route: [],
          routeIndex: 0,
          progress: 0,
          bearing: 0
        });
      }
    });
  };

  // Check if coordinates are likely on water or a coastal port
  const isLikelyWater = useCallback((lat: number, lng: number) => {
    // Known port locations that might appear inland but are valid
    const knownPorts = [
      { lat: 55.04, lng: 9.42 }, // Aabenraa, Denmark
      { lat: 57.05, lng: 9.92 }, // Aalborg, Denmark
      { lat: 27.07, lng: -13.47 }, // Laâyoune, Morocco
      // Add more known ports as needed
    ];
    
    // Check if it's a known port location (within tolerance)
    for (const port of knownPorts) {
      if (Math.abs(lat - port.lat) < 0.1 && Math.abs(lng - port.lng) < 0.1) {
        return true;
      }
    }
    
    // More refined land mass checks - only reject deep inland coordinates
    // Central Asia / Middle East (but allow Mediterranean/Persian Gulf coasts)
    if (lat > 25 && lat < 45 && lng > 40 && lng < 75) return false;
    // Central Africa (but allow coasts)
    if (lat > -25 && lat < 25 && lng > -10 && lng < 40) return false;
    // Central North America
    if (lat > 30 && lat < 60 && lng > -130 && lng < -70) return false;
    // Central South America (Amazon basin)
    if (lat > -20 && lat < 5 && lng > -75 && lng < -45) return false;
    // Central Europe (but allow Baltic/North Sea ports)
    if (lat > 45 && lat < 55 && lng > 10 && lng < 30) return false;
    // Central Asia
    if (lat > 20 && lat < 60 && lng > 60 && lng < 130) return false;
    // Central Australia
    if (lat > -35 && lat < -20 && lng > 125 && lng < 145) return false;
    
    return true;
  }, []);

  // Convert 3D position to lat/lng
  const convertPositionToLatLng = useCallback((position: { x: number; y: number; z: number }) => {
    // Normalize position to unit sphere first
    const length = Math.sqrt(position.x * position.x + position.y * position.y + position.z * position.z);
    const normalized = {
      x: position.x / length,
      y: position.y / length,
      z: position.z / length
    };
    
    // Convert to lat/lng - matching the formula used in worldPortsConverter
    // Reverse the conversion: 
    // y = cos(phi), so phi = acos(y/radius)
    // x = -(sin(phi) * cos(theta))
    // z = sin(phi) * sin(theta)
    
    const phi = Math.acos(normalized.y);
    const lat = 90 - (phi * 180 / Math.PI);
    
    // theta = atan2(z, -x)
    const theta = Math.atan2(normalized.z, -normalized.x);
    const lng = (theta * 180 / Math.PI) - 180;
    
    // Validate position - DISABLED FOR DEBUGGING
    // if (!isLikelyWater(lat, lng)) {
    //   // console.warn('Ship/Port position on land!', { lat, lng, position });
    //   // Return a default ocean position (middle of Pacific)
    //   return { lat: 0, lng: -150 };
    // }
    
    // Position conversion working correctly
    if (!mapRef.current._loggedConversion) {
      mapRef.current._loggedConversion = true;
      
      // Test with sample ports
      const testPorts = [
        { city: 'Aabenraa', lat: 55.04, lng: 9.42 },
        { city: 'Laâyoune', lat: 27.07, lng: -13.47 },
        { city: 'Aalborg', lat: 57.05, lng: 9.92 }
      ];
      // console.log('Test port positions:');
      // testPorts.forEach(port => {
      //   console.log(`${port.city}: lat=${port.lat}, lng=${port.lng}, isWater=${isLikelyWater(port.lat, port.lng)}`);
      // });
    }
    
    return { lat, lng };
  }, [isLikelyWater]);

  // Update ship animations and render
  useEffect(() => {
    // console.log('Ship animation effect triggered, fleet size:', fleet.length);
    if (!mapRef.current) {
      // console.log('Map ref not available');
      return;
    }
    
    const map = mapRef.current;
    
    const startAnimation = () => {
      const animations = shipAnimationsRef.current;
    
    // Initialize animations for new ships
    fleet.forEach(ship => {
      if (!animations.has(ship.id)) {
        const { lat, lng } = convertPositionToLatLng(ship.position);
        // Ship initialized
        animations.set(ship.id, {
          currentPosition: { lat, lng },
          targetPosition: { lat, lng },
          route: [],
          routeIndex: 0,
          progress: 0,
          bearing: 0
        });
      }
      
      // Update destination if ship is sailing
      const anim = animations.get(ship.id);
      if (ship.status === 'SAILING' && ship.destination) {
        const destPos = convertPositionToLatLng(ship.destination.position);
        
        // Calculate route if destination changed
        if (anim.route.length === 0 || 
            anim.targetPosition.lat !== destPos.lat || 
            anim.targetPosition.lng !== destPos.lng) {
          
          // Calculate water route with validation
          try {
            const route = getWaterRoute(anim.currentPosition, destPos);
            
            // Ensure route points are valid
            if (route && route.length > 0) {
              anim.route = route;
              anim.routeIndex = 0;
              anim.progress = 0;
              anim.targetPosition = destPos;
            } else {
              // console.warn('No valid water route found for ship', ship.id);
              // Keep ship at current position
              anim.route = [anim.currentPosition];
            }
          } catch (error) {
            console.error('Error calculating route:', error);
            anim.route = [anim.currentPosition];
          }
        }
      }
    });
    
    // Animation loop
    let frameCount = 0;
    const animate = () => {
      // Check if map still exists
      if (!mapRef.current || !mapRef.current.getSource) {
        console.log('Map removed or invalid, stopping animation');
        return;
      }
      
      frameCount++;
      if (frameCount % 60 === 0) { // Log every second at 60fps
        // console.log('Animation running, frame:', frameCount);
      }
      const now = Date.now();
      const deltaTime = (now - lastUpdateRef.current) / 1000; // Convert to seconds
      lastUpdateRef.current = now;
      
      const features = fleet.map(ship => {
        const anim = animations.get(ship.id);
        if (!anim) return null;
        
        // Update position along route for sailing ships
        if (ship.status === 'SAILING' && anim.route.length > 0 && anim.routeIndex < anim.route.length - 1) {
          const currentWaypoint = anim.route[anim.routeIndex];
          const nextWaypoint = anim.route[anim.routeIndex + 1];
          
          // Calculate speed based on ship type
          const speedKnots = SHIP_SPEEDS[ship.type] || SHIP_SPEEDS.CONTAINER;
          const speedDegreesPerSecond = speedKnots * KNOTS_TO_DEGREES_PER_SECOND;
          
          // Calculate distance between waypoints
          const dx = nextWaypoint.lng - currentWaypoint.lng;
          const dy = nextWaypoint.lat - currentWaypoint.lat;
          const distance = Math.sqrt(dx * dx + dy * dy);
          
          // Update progress
          anim.progress += (speedDegreesPerSecond * deltaTime) / distance;
          
          if (anim.progress >= 1) {
            // Move to next waypoint
            anim.routeIndex++;
            anim.progress = 0;
            if (anim.routeIndex >= anim.route.length - 1) {
              // Reached destination
              anim.currentPosition = anim.targetPosition;
              // Ship status will be updated by game logic
            }
          } else {
            // Interpolate position
            anim.currentPosition = {
              lat: currentWaypoint.lat + dy * anim.progress,
              lng: currentWaypoint.lng + dx * anim.progress
            };
            
            // Calculate bearing
            anim.bearing = calculateBearing(currentWaypoint, nextWaypoint);
          }
        }
        
        return {
          type: 'Feature',
          geometry: {
            type: 'Point',
            coordinates: [anim.currentPosition.lng, anim.currentPosition.lat]
          },
          properties: {
            id: ship.id,
            name: ship.name,
            status: ship.status || 'IDLE',
            bearing: anim.bearing || 0,
            type: ship.type || 'CONTAINER'
          }
        };
      }).filter(f => f !== null);
      
      // Update ship routes
      const routeFeatures = [];
      fleet.forEach(ship => {
        const anim = animations.get(ship.id);
        if (anim && anim.route.length > 1 && ship.status === 'SAILING') {
          // Create route line from current position to destination
          const remainingRoute = anim.route.slice(anim.routeIndex);
          if (remainingRoute.length > 0) {
            routeFeatures.push({
              type: 'Feature',
              geometry: {
                type: 'LineString',
                coordinates: [[anim.currentPosition.lng, anim.currentPosition.lat], ...remainingRoute.map(p => [p.lng, p.lat])]
              },
              properties: {
                shipId: ship.id,
                shipName: ship.name,
                shipType: ship.type
              }
            });
          }
        }
      });
      
      const routesSource = mapRef.current.getSource('ship-routes');
      if (routesSource) {
        routesSource.setData({
          type: 'FeatureCollection',
          features: routeFeatures
        });
      }
      
      // No test ships needed
      
      // Update ships source
      const shipsSource = mapRef.current.getSource('ships');
      if (shipsSource) {
        const data = {
          type: 'FeatureCollection',
          features
        };
        // console.log('Updating ships on map:', features.length, 'ships');
        // if (features.length > 0) {
        //   console.log('First ship:', features[0]);
        // }
        shipsSource.setData(data);
      }
      
      // Continue animation
      animationRef.current = requestAnimationFrame(animate);
    };
    
    // Start animation
    // console.log('Starting ship animation');
    animate();
    
    return () => {
      if (animationRef.current) {
        cancelAnimationFrame(animationRef.current);
      }
    };
    };
    
    if (map.isStyleLoaded()) {
      startAnimation();
    } else {
      map.once('style.load', startAnimation);
    }
  }, [fleet, convertPositionToLatLng]);
  
  // Update ports on the map when ports change
  useEffect(() => {
    console.log('Ports update effect - ports length:', ports.length);
    if (!mapRef.current) return;
    
    const map = mapRef.current;
    
    // If no ports yet, clear the source
    if (!ports.length) {
      const portsSource = map.getSource('ports');
      if (portsSource) {
        portsSource.setData({
          type: 'FeatureCollection',
          features: []
        });
      }
      return;
    }
    
    // Wait for style to load
    const updatePorts = () => {
      // Log port rendering once
      if (!mapRef.current._portsRendered) {
        // Rendering ports
        mapRef.current._portsRendered = true;
      }
      
      // Test port removed - using real ports now
    
    // Convert port positions to GeoJSON
    const portFeatures = ports.map(port => {
      // Convert 3D coordinates back to lat/lng
      const length = Math.sqrt(
        port.position.x * port.position.x + 
        port.position.y * port.position.y + 
        port.position.z * port.position.z
      );
      
      const normalized = {
        x: port.position.x / length,
        y: port.position.y / length,
        z: port.position.z / length
      };
      
      // Calculate lat/lng using consistent formula
      const lat = Math.asin(normalized.y) * (180 / Math.PI);
      const theta = Math.atan2(-normalized.z, normalized.x) + Math.PI;
      const lng = theta * (180 / Math.PI) - 180;
      
      // For now, use Point geometry for compatibility with all layers
      return {
        type: 'Feature',
        geometry: {
          type: 'Point',
          coordinates: [lng, lat]
        },
        properties: {
          id: port.id,
          name: port.name
        }
      };
    });
    
    // No test ports needed
    
    // Update ports source
    const portsSource = map.getSource('ports');
    if (portsSource && portsSource.setData) {
      const data = {
        type: 'FeatureCollection',
        features: portFeatures
      };
      portsSource.setData(data);
      
      // Force map to redraw
      map.triggerRepaint();
    } else {
      console.error('Ports source not found or invalid! Map loaded:', map.loaded());
    }
    };
    
    if (map.isStyleLoaded()) {
      updatePorts();
    } else {
      map.once('style.load', updatePorts);
    }
  }, [ports]);

  return (
    <div style={{ position: 'relative', width: '100%', height: '100%' }}>
      <div 
        ref={mapContainerRef} 
        className={className}
        style={{ 
          width: '100%', 
          height: '100%'
        }} 
      />
      <button
        onClick={() => {
          if (!mapRef.current) return;
          const toggleSpin = (mapRef.current as any)._toggleSpin;
          if (toggleSpin) {
            toggleSpin();
          }
        }}
        style={{
          position: 'absolute',
          top: '20px',
          left: '50%',
          transform: 'translateX(-50%)',
          zIndex: 1,
          backgroundColor: '#3386c0',
          color: '#fff',
          border: 'none',
          padding: '10px 20px',
          borderRadius: '3px',
          cursor: 'pointer',
          fontWeight: 'bold',
          fontSize: '12px'
        }}
        onMouseEnter={(e) => {
          e.currentTarget.style.backgroundColor = '#4ea0da';
        }}
        onMouseLeave={(e) => {
          e.currentTarget.style.backgroundColor = '#3386c0';
        }}
      >
        Toggle Rotation
      </button>
    </div>
  );
};