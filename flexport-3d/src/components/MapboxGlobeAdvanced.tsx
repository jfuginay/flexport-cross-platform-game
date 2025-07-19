import React, { useEffect, useRef, useState } from 'react';
import mapboxgl from 'mapbox-gl';
import * as THREE from 'three';
import { useGameStore } from '../store/gameStore';
import { positionToLatLng } from '../utils/geoUtils';
import { ShipStatus, ShipType } from '../types/game.types';
import { isShipOverWater, getWaterRouteBetweenPorts } from '../utils/routeValidation';
import 'mapbox-gl/dist/mapbox-gl.css';
import './MapboxGlobe.css';

// Set your Mapbox access token
mapboxgl.accessToken = process.env.REACT_APP_MAPBOX_TOKEN || 'pk.eyJ1IjoiamZ1Z2luYXkiLCJhIjoiY21icmNha2hrMGE0azJscHVzdmVuZTVjOSJ9.oiJoYvc_G-tLUmaSzGVsVQ';

interface MapboxGlobeAdvancedProps {
  className?: string;
}

// Available map styles
const MAP_STYLES = {
  satellite: {
    url: 'mapbox://styles/mapbox/satellite-streets-v12',
    name: '🛰️ Satellite',
    fog: {
      color: 'rgb(186, 210, 235)',
      'high-color': 'rgb(36, 92, 223)',
      'horizon-blend': 0.02,
      'space-color': 'rgb(11, 11, 25)',
      'star-intensity': 0.8
    }
  },
  streets: {
    url: 'mapbox://styles/mapbox/streets-v12',
    name: '🗺️ Streets',
    fog: {
      color: 'rgb(220, 220, 220)',
      'high-color': 'rgb(180, 180, 200)',
      'horizon-blend': 0.1,
      'space-color': 'rgb(200, 200, 220)',
      'star-intensity': 0.3
    }
  },
  dark: {
    url: 'mapbox://styles/mapbox/dark-v11',
    name: '🌑 Dark',
    fog: {
      color: 'rgb(30, 30, 40)',
      'high-color': 'rgb(20, 20, 30)',
      'horizon-blend': 0.05,
      'space-color': 'rgb(5, 5, 15)',
      'star-intensity': 1.0
    }
  },
  navigation: {
    url: 'mapbox://styles/mapbox/navigation-day-v1',
    name: '🧭 Navigation',
    fog: {
      color: 'rgb(240, 240, 245)',
      'high-color': 'rgb(200, 200, 220)',
      'horizon-blend': 0.1,
      'space-color': 'rgb(220, 220, 240)',
      'star-intensity': 0.2
    }
  }
};

export const MapboxGlobeAdvanced: React.FC<MapboxGlobeAdvancedProps> = ({ className }) => {
  const mapContainer = useRef<HTMLDivElement>(null);
  const map = useRef<mapboxgl.Map | null>(null);
  const shipMarkers = useRef<Map<string, mapboxgl.Marker>>(new Map());
  const [isMapLoaded, setIsMapLoaded] = React.useState(false);
  const isInitializing = useRef(false);
  
  // Map controls state
  const [currentStyle, setCurrentStyle] = useState<keyof typeof MAP_STYLES>('satellite');
  const [showShippingLanes, setShowShippingLanes] = useState(true);
  const [showHeatmap, setShowHeatmap] = useState(false);
  const [show3DTerrain, setShow3DTerrain] = useState(true);
  
  // Camera tracking state
  const [followMode, setFollowMode] = React.useState(true);
  const [cameraMode, setCameraMode] = React.useState<'cinematic' | 'top-down' | 'chase'>('cinematic');
  const lastUserInteraction = useRef<number>(0);
  const cameraAnimationFrame = useRef<number | null>(null);
  const previousShipPositions = useRef<Map<string, { lng: number; lat: number; timestamp: number }>>(new Map());
  
  const { fleet, ports, selectedShipId, selectShip, selectPort } = useGameStore();
  
  // Calculate ship speed for dynamic camera zoom
  const calculateShipSpeed = (shipId: string, currentPos: { lng: number; lat: number }) => {
    const prevPos = previousShipPositions.current.get(shipId);
    if (!prevPos) {
      previousShipPositions.current.set(shipId, { ...currentPos, timestamp: Date.now() });
      return 0;
    }
    
    const timeDelta = (Date.now() - prevPos.timestamp) / 1000;
    if (timeDelta === 0) return 0;
    
    const R = 6371;
    const dLat = (currentPos.lat - prevPos.lat) * Math.PI / 180;
    const dLon = (currentPos.lng - prevPos.lng) * Math.PI / 180;
    const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
              Math.cos(prevPos.lat * Math.PI / 180) * Math.cos(currentPos.lat * Math.PI / 180) *
              Math.sin(dLon/2) * Math.sin(dLon/2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    const distance = R * c;
    
    const speed = distance / timeDelta * 3600;
    previousShipPositions.current.set(shipId, { ...currentPos, timestamp: Date.now() });
    
    return speed;
  };
  
  const calculateDynamicZoom = (speed: number, shipStatus: ShipStatus) => {
    if (shipStatus === ShipStatus.IDLE || shipStatus === ShipStatus.LOADING || 
        shipStatus === ShipStatus.UNLOADING || shipStatus === ShipStatus.MAINTENANCE) {
      return 12;
    }
    
    if (speed > 500) {
      return Math.max(6, Math.min(10, 12 - speed / 200));
    } else {
      return Math.max(8, Math.min(12, 12 - speed / 10));
    }
  };
  
  const getCameraAngle = (shipType: ShipType, shipStatus: ShipStatus, cameraMode: string) => {
    if (cameraMode === 'top-down') {
      return { pitch: 0, bearing: 0 };
    }
    
    if (cameraMode === 'chase') {
      const ship = fleet.find(s => s.id === selectedShipId);
      const rotation = (ship as any)?.rotation || 0;
      return { 
        pitch: 45, 
        bearing: rotation * (180 / Math.PI) - 180
      };
    }
    
    // Cinematic mode
    switch (shipStatus) {
      case ShipStatus.IDLE:
      case ShipStatus.LOADING:
      case ShipStatus.UNLOADING:
      case ShipStatus.MAINTENANCE:
        return { pitch: 65, bearing: Date.now() / 100 % 360 };
      case ShipStatus.SAILING:
        if (shipType === ShipType.CARGO_PLANE) {
          return { pitch: 35, bearing: 45 };
        }
        return { pitch: 55, bearing: 20 };
      default:
        return { pitch: 45, bearing: 0 };
    }
  };
  
  const smoothCameraFollow = () => {
    if (!map.current || !followMode || !selectedShipId) return;
    
    const ship = fleet.find(s => s.id === selectedShipId);
    if (!ship) return;
    
    if (Date.now() - lastUserInteraction.current < 3000) return;
    
    const targetCoords = positionToLatLng(new THREE.Vector3(ship.position.x, ship.position.y, ship.position.z));
    const currentCenter = map.current.getCenter();
    const currentZoom = map.current.getZoom();
    const currentPitch = map.current.getPitch();
    const currentBearing = map.current.getBearing();
    
    const speed = calculateShipSpeed(ship.id, targetCoords);
    const targetZoom = calculateDynamicZoom(speed, ship.status);
    const { pitch: targetPitch, bearing: targetBearing } = getCameraAngle(ship.type, ship.status, cameraMode);
    
    const positionAlpha = 0.1;
    const zoomAlpha = 0.05;
    const rotationAlpha = 0.08;
    
    const newLng = currentCenter.lng + (targetCoords.lng - currentCenter.lng) * positionAlpha;
    const newLat = currentCenter.lat + (targetCoords.lat - currentCenter.lat) * positionAlpha;
    const newZoom = currentZoom + (targetZoom - currentZoom) * zoomAlpha;
    
    let bearingDiff = targetBearing - currentBearing;
    if (bearingDiff > 180) bearingDiff -= 360;
    if (bearingDiff < -180) bearingDiff += 360;
    const newBearing = currentBearing + bearingDiff * rotationAlpha;
    
    const newPitch = currentPitch + (targetPitch - currentPitch) * rotationAlpha;
    
    map.current.easeTo({
      center: [newLng, newLat],
      zoom: newZoom,
      pitch: newPitch,
      bearing: newBearing,
      duration: 100,
      easing: (t) => t,
      essential: false
    });
    
    cameraAnimationFrame.current = requestAnimationFrame(smoothCameraFollow);
  };
  
  // Change map style
  const changeMapStyle = (style: keyof typeof MAP_STYLES) => {
    if (!map.current || style === currentStyle) return;
    
    setCurrentStyle(style);
    map.current.setStyle(MAP_STYLES[style].url);
    
    // Re-apply fog settings after style change
    map.current.once('style.load', () => {
      if (!map.current) return;
      
      map.current.setFog(MAP_STYLES[style].fog);
      
      // Re-add 3D terrain if enabled
      if (show3DTerrain) {
        add3DTerrain();
      }
      
      // Re-add custom layers
      addPortsLayer();
      if (showShippingLanes) {
        addShippingLanes();
      }
      if (showHeatmap) {
        addHeatmapLayer();
      }
    });
  };
  
  // Add 3D terrain
  const add3DTerrain = () => {
    if (!map.current) return;
    
    if (!map.current.getSource('mapbox-dem')) {
      map.current.addSource('mapbox-dem', {
        type: 'raster-dem',
        url: 'mapbox://mapbox.mapbox-terrain-dem-v1',
        tileSize: 512,
        maxzoom: 14
      });
    }
    
    map.current.setTerrain({ 
      source: 'mapbox-dem', 
      exaggeration: 2.0
    });
  };
  
  // Add shipping lanes visualization
  const addShippingLanes = () => {
    if (!map.current) return;
    
    // Major shipping routes
    const shippingRoutes = {
      type: 'FeatureCollection',
      features: [
        // Trans-Pacific
        {
          type: 'Feature',
          properties: { name: 'Trans-Pacific', traffic: 'high' },
          geometry: {
            type: 'LineString',
            coordinates: [
              [121.47, 31.23], // Shanghai
              [139.65, 35.68], // Tokyo
              [-118.27, 33.74], // LA
            ]
          }
        },
        // Trans-Atlantic
        {
          type: 'Feature',
          properties: { name: 'Trans-Atlantic', traffic: 'high' },
          geometry: {
            type: 'LineString',
            coordinates: [
              [4.48, 51.92], // Rotterdam
              [-74.01, 40.71], // NYC
            ]
          }
        },
        // Asia-Europe via Suez
        {
          type: 'Feature',
          properties: { name: 'Asia-Europe', traffic: 'very-high' },
          geometry: {
            type: 'LineString',
            coordinates: [
              [121.47, 31.23], // Shanghai
              [103.82, 1.35], // Singapore
              [55.27, 25.20], // Dubai
              [32.33, 30.12], // Suez
              [4.48, 51.92], // Rotterdam
            ]
          }
        }
      ]
    };
    
    if (!map.current.getSource('shipping-lanes')) {
      map.current.addSource('shipping-lanes', {
        type: 'geojson',
        data: shippingRoutes as any
      });
    }
    
    if (!map.current.getLayer('shipping-lanes')) {
      map.current.addLayer({
        id: 'shipping-lanes',
        type: 'line',
        source: 'shipping-lanes',
        layout: {
          'line-join': 'round',
          'line-cap': 'round'
        },
        paint: {
          'line-color': [
            'case',
            ['==', ['get', 'traffic'], 'very-high'],
            '#ff6b6b',
            ['==', ['get', 'traffic'], 'high'],
            '#4ecdc4',
            '#95e1d3'
          ],
          'line-width': [
            'case',
            ['==', ['get', 'traffic'], 'very-high'],
            3,
            2
          ],
          'line-opacity': 0.6,
          'line-dasharray': [2, 4]
        }
      });
    }
  };
  
  // Add port activity heatmap
  const addHeatmapLayer = () => {
    if (!map.current || ports.length === 0) return;
    
    const heatmapData = {
      type: 'FeatureCollection',
      features: ports.map(port => {
        const coords = positionToLatLng(new THREE.Vector3(port.position.x, port.position.y, port.position.z));
        return {
          type: 'Feature',
          properties: {
            activity: port.currentLoad / port.capacity
          },
          geometry: {
            type: 'Point',
            coordinates: [coords.lng, coords.lat]
          }
        };
      })
    };
    
    if (!map.current.getSource('port-heatmap')) {
      map.current.addSource('port-heatmap', {
        type: 'geojson',
        data: heatmapData as any
      });
    }
    
    if (!map.current.getLayer('port-heatmap')) {
      map.current.addLayer({
        id: 'port-heatmap',
        type: 'heatmap',
        source: 'port-heatmap',
        maxzoom: 15,
        paint: {
          'heatmap-weight': ['get', 'activity'],
          'heatmap-intensity': 1,
          'heatmap-color': [
            'interpolate',
            ['linear'],
            ['heatmap-density'],
            0, 'rgba(33,102,172,0)',
            0.2, 'rgb(103,169,207)',
            0.4, 'rgb(209,229,240)',
            0.6, 'rgb(253,219,199)',
            0.8, 'rgb(239,138,98)',
            1, 'rgb(178,24,43)'
          ],
          'heatmap-radius': 30,
          'heatmap-opacity': 0.7
        }
      });
    }
  };
  
  // Initialize map
  useEffect(() => {
    if (!mapContainer.current || map.current || isInitializing.current) return;
    
    isInitializing.current = true;
    
    try {
      map.current = new mapboxgl.Map({
        container: mapContainer.current,
        style: MAP_STYLES[currentStyle].url,
        projection: 'globe',
        center: [0, 20],
        zoom: 2.5,
        pitch: 0,
        bearing: 0,
        antialias: true,
        hash: false,
        renderWorldCopies: false,
        maxPitch: 85,
        minZoom: 1.5,
        maxZoom: 20
      });
    } catch (error) {
      console.error('Failed to initialize Mapbox:', error);
      return;
    }
    
    map.current.addControl(new mapboxgl.NavigationControl(), 'top-right');
    
    map.current.on('error', (e) => {
      console.error('Mapbox error:', e.error);
    });
    
    map.current.on('style.load', () => {
      if (!map.current) return;
      
      map.current.setFog(MAP_STYLES[currentStyle].fog);
      
      map.current.setLight({
        anchor: 'viewport',
        color: 'white',
        intensity: 0.4,
        position: [1.5, 90, 80]
      });
      
      if (show3DTerrain) {
        add3DTerrain();
      }
      
      if (ports.length > 0) {
        addPortsLayer();
      }
      
      setupEventHandlers();
      
      if (showShippingLanes) {
        addShippingLanes();
      }
    });
    
    let rotationAnimation: number;
    let isUserInteracting = false;
    let lastInteractionTime = 0;
    
    const rotateGlobe = () => {
      if (!map.current || isUserInteracting || selectedShipId) {
        rotationAnimation = requestAnimationFrame(rotateGlobe);
        return;
      }
      
      if (Date.now() - lastInteractionTime > 3000) {
        const center = map.current.getCenter();
        center.lng += 0.05;
        map.current.easeTo({
          center: center,
          duration: 100,
          easing: (t) => t
        });
      }
      
      rotationAnimation = requestAnimationFrame(rotateGlobe);
    };
    
    map.current.on('load', () => {
      setIsMapLoaded(true);
      
      map.current?.flyTo({
        center: [0, 20],
        zoom: 2.5,
        pitch: 45,
        bearing: 0,
        duration: 3000,
        essential: true
      });
      
      rotationAnimation = requestAnimationFrame(rotateGlobe);
    });
    
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
    
    map.current.on('drag', () => {
      lastUserInteraction.current = Date.now();
    });
    
    return () => {
      cancelAnimationFrame(rotationAnimation);
      if (cameraAnimationFrame.current) {
        cancelAnimationFrame(cameraAnimationFrame.current);
      }
      if (map.current) {
        map.current.remove();
        map.current = null;
      }
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  
  // Add ports layer
  const addPortsLayer = () => {
    if (!map.current || ports.length === 0) return;
    
    try {
      ['port-labels', 'unclustered-ports', 'port-cluster-count', 'port-clusters'].forEach(layerId => {
        if (map.current?.getLayer(layerId)) {
          map.current.removeLayer(layerId);
        }
      });
      
      if (map.current.getSource('ports')) {
        map.current.removeSource('ports');
      }
    } catch (e) {
      // Ignore errors
    }
    
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
    
    map.current.addSource('ports', {
      type: 'geojson',
      data: portsGeoJSON,
      cluster: true,
      clusterMaxZoom: 10,
      clusterRadius: 50
    });
    
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
    
    map.current.addLayer({
      id: 'unclustered-ports',
      type: 'circle',
      source: 'ports',
      filter: ['!', ['has', 'point_count']],
      paint: {
        'circle-color': [
          'case',
          ['get', 'isPlayerOwned'],
          '#4ade80',
          '#3b82f6'
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
  
  // Setup event handlers
  const setupEventHandlers = () => {
    if (!map.current) return;
    
    map.current.on('click', 'unclustered-ports', (e) => {
      if (!e.features || !e.features[0]) return;
      
      const feature = e.features[0];
      const portId = feature.properties?.id;
      const coordinates = (feature.geometry as GeoJSON.Point).coordinates.slice() as [number, number];
      
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
  
  // Start/stop camera tracking
  useEffect(() => {
    if (!map.current || !isMapLoaded) return;
    
    if (selectedShipId && followMode) {
      if (cameraAnimationFrame.current) {
        cancelAnimationFrame(cameraAnimationFrame.current);
      }
      
      const ship = fleet.find(s => s.id === selectedShipId);
      if (ship) {
        const coords = positionToLatLng(new THREE.Vector3(ship.position.x, ship.position.y, ship.position.z));
        
        map.current.flyTo({
          center: [coords.lng, coords.lat],
          zoom: 10,
          pitch: 45,
          bearing: 0,
          duration: 2000,
          essential: true
        });
        
        cameraAnimationFrame.current = requestAnimationFrame(smoothCameraFollow);
      }
    } else {
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
  
  // Update ship markers
  useEffect(() => {
    if (!map.current || !isMapLoaded) return;
    
    // Remove old markers
    shipMarkers.current.forEach((marker, shipId) => {
      if (!fleet.find(s => s.id === shipId)) {
        marker.remove();
        shipMarkers.current.delete(shipId);
      }
    });
    
    // Update or create markers
    fleet.forEach(ship => {
      let marker = shipMarkers.current.get(ship.id);
      
      if (!marker) {
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
        
        const shipConfigs = {
          [ShipType.CONTAINER]: {
            color: '#3b82f6',
            shadowColor: '#60a5fa',
            icon: `<svg viewBox="0 0 100 100" style="width: 100%; height: 100%;">
              <path d="M 15 60 L 20 75 L 80 75 L 85 60 Z" fill="#1e40af" stroke="#3b82f6" stroke-width="2"/>
              <rect x="25" y="50" width="10" height="10" fill="#ef4444" stroke="#dc2626" stroke-width="1"/>
              <rect x="35" y="50" width="10" height="10" fill="#10b981" stroke="#059669" stroke-width="1"/>
              <rect x="45" y="50" width="10" height="10" fill="#f59e0b" stroke="#d97706" stroke-width="1"/>
              <rect x="55" y="50" width="10" height="10" fill="#8b5cf6" stroke="#7c3aed" stroke-width="1"/>
              <rect x="65" y="50" width="10" height="10" fill="#ef4444" stroke="#dc2626" stroke-width="1"/>
              <rect x="30" y="40" width="10" height="10" fill="#10b981" stroke="#059669" stroke-width="1"/>
              <rect x="40" y="40" width="10" height="10" fill="#ef4444" stroke="#dc2626" stroke-width="1"/>
              <rect x="50" y="40" width="10" height="10" fill="#f59e0b" stroke="#d97706" stroke-width="1"/>
              <rect x="60" y="40" width="10" height="10" fill="#8b5cf6" stroke="#7c3aed" stroke-width="1"/>
              <rect x="70" y="35" width="12" height="15" fill="#4b5563" stroke="#374151" stroke-width="1"/>
              <rect x="72" y="37" width="8" height="4" fill="#60a5fa" stroke="#3b82f6" stroke-width="0.5"/>
            </svg>`
          },
          [ShipType.BULK]: {
            color: '#10b981',
            shadowColor: '#34d399',
            icon: `<svg viewBox="0 0 100 100" style="width: 100%; height: 100%;">
              <path d="M 10 65 L 15 80 L 85 80 L 90 65 Z" fill="#059669" stroke="#10b981" stroke-width="2"/>
              <ellipse cx="25" cy="55" rx="12" ry="8" fill="#065f46" stroke="#059669" stroke-width="2"/>
              <ellipse cx="50" cy="55" rx="12" ry="8" fill="#065f46" stroke="#059669" stroke-width="2"/>
              <ellipse cx="75" cy="55" rx="12" ry="8" fill="#065f46" stroke="#059669" stroke-width="2"/>
              <circle cx="25" cy="52" r="3" fill="#8b4513"/>
              <circle cx="50" cy="52" r="3" fill="#8b4513"/>
              <circle cx="75" cy="52" r="3" fill="#8b4513"/>
              <rect x="78" y="45" width="10" height="10" fill="#4b5563" stroke="#374151" stroke-width="1"/>
              <rect x="80" y="47" width="6" height="3" fill="#34d399" stroke="#10b981" stroke-width="0.5"/>
              <line x1="40" y1="55" x2="40" y2="35" stroke="#6b7280" stroke-width="2"/>
              <line x1="40" y1="35" x2="55" y2="40" stroke="#6b7280" stroke-width="2"/>
            </svg>`
          },
          [ShipType.TANKER]: {
            color: '#f97316',
            shadowColor: '#fb923c',
            icon: `<svg viewBox="0 0 100 100" style="width: 100%; height: 100%;">
              <path d="M 12 62 L 18 78 L 82 78 L 88 62 Z" fill="#ea580c" stroke="#f97316" stroke-width="2"/>
              <ellipse cx="30" cy="55" rx="15" ry="10" fill="#dc2626" stroke="#ef4444" stroke-width="2"/>
              <ellipse cx="50" cy="55" rx="15" ry="10" fill="#dc2626" stroke="#ef4444" stroke-width="2"/>
              <ellipse cx="70" cy="55" rx="15" ry="10" fill="#dc2626" stroke="#ef4444" stroke-width="2"/>
              <ellipse cx="30" cy="50" rx="15" ry="10" fill="#ef4444" stroke="#f87171" stroke-width="1"/>
              <ellipse cx="50" cy="50" rx="15" ry="10" fill="#ef4444" stroke="#f87171" stroke-width="1"/>
              <ellipse cx="70" cy="50" rx="15" ry="10" fill="#ef4444" stroke="#f87171" stroke-width="1"/>
              <rect x="75" y="40" width="12" height="12" fill="#4b5563" stroke="#374151" stroke-width="1"/>
              <rect x="77" y="42" width="8" height="3" fill="#fb923c" stroke="#f97316" stroke-width="0.5"/>
              <circle cx="20" cy="58" r="2" fill="#fbbf24"/>
              <circle cx="80" cy="58" r="2" fill="#fbbf24"/>
            </svg>`
          },
          [ShipType.CARGO_PLANE]: {
            color: '#8b5cf6',
            shadowColor: '#a78bfa',
            icon: `<svg viewBox="0 0 100 100" style="width: 100%; height: 100%;">
              <ellipse cx="50" cy="50" rx="35" ry="8" fill="#7c3aed" stroke="#8b5cf6" stroke-width="2"/>
              <path d="M 30 50 L 5 45 L 5 55 L 30 50 Z" fill="#6d28d9" stroke="#7c3aed" stroke-width="2"/>
              <path d="M 70 50 L 95 45 L 95 55 L 70 50 Z" fill="#6d28d9" stroke="#7c3aed" stroke-width="2"/>
              <path d="M 15 50 L 10 35 L 20 35 L 25 50 Z" fill="#6d28d9" stroke="#7c3aed" stroke-width="2"/>
              <ellipse cx="75" cy="50" rx="8" ry="6" fill="#4c1d95" stroke="#6d28d9" stroke-width="1"/>
              <ellipse cx="75" cy="50" rx="6" ry="4" fill="#60a5fa" stroke="#3b82f6" stroke-width="0.5"/>
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
        
        // Water validation indicator
        const shipCoords = positionToLatLng(new THREE.Vector3(ship.position.x, ship.position.y, ship.position.z));
        const isOverWater = ship.type === ShipType.CARGO_PLANE || 
                           isShipOverWater(new THREE.Vector3(ship.position.x, ship.position.y, ship.position.z), 100);
        
        el.innerHTML = `
          <div class="ship-icon-container" style="
            width: 100%;
            height: 100%;
            position: relative;
            filter: drop-shadow(0 4px 8px rgba(0,0,0,0.3)) drop-shadow(0 0 20px ${config.shadowColor});
            ${!isOverWater && ship.type !== ShipType.CARGO_PLANE ? 'opacity: 0.6;' : ''}
          ">
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
            
            <div class="ship-icon" style="
              width: 100%;
              height: 100%;
              position: relative;
              animation: ${ship.type === ShipType.CARGO_PLANE ? 'float' : 'bob'} 3s ease-in-out infinite;
            ">
              ${config.icon}
            </div>
            
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
            
            ${ship.type !== ShipType.CARGO_PLANE ? `
              <div class="ship-wake" style="
                position: absolute;
                bottom: -10px;
                left: 50%;
                transform: translateX(-50%);
                width: 60px;
                height: 20px;
                opacity: ${ship.status === ShipStatus.SAILING && isOverWater ? '1' : '0'};
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
            
            ${!isOverWater && ship.type !== ShipType.CARGO_PLANE ? `
              <div style="
                position: absolute;
                bottom: -40px;
                left: 50%;
                transform: translateX(-50%);
                background: rgba(239, 68, 68, 0.9);
                color: white;
                padding: 2px 6px;
                border-radius: 4px;
                font-size: 10px;
                font-weight: 600;
                white-space: nowrap;
              ">
                ⚠️ Not in water!
              </div>
            ` : ''}
          </div>
          
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
        
        el.addEventListener('click', () => {
          selectShip(ship.id);
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
            shipMarkers.current.set(ship.id, marker);
          } catch (error) {
            console.error(`Failed to add marker for ship ${ship.name}:`, error);
          }
        }
      } else {
        // Update existing marker
        const currentLngLat = marker.getLngLat();
        const shipCoords = positionToLatLng(new THREE.Vector3(ship.position.x, ship.position.y, ship.position.z));
        const targetLng = shipCoords.lng;
        const targetLat = shipCoords.lat;
        
        if (Math.abs(currentLngLat.lng - targetLng) > 0.0001 || 
            Math.abs(currentLngLat.lat - targetLat) > 0.0001) {
          marker.setLngLat([targetLng, targetLat]);
        }
        
        if ((ship as any).rotation !== undefined) {
          marker.setRotation((ship as any).rotation * (180 / Math.PI));
        } else if (ship.destination) {
          const destCoords = positionToLatLng(new THREE.Vector3(ship.destination.position.x, ship.destination.position.y, ship.destination.position.z));
          const dx = destCoords.lng - targetLng;
          const dy = destCoords.lat - targetLat;
          const angle = Math.atan2(dx, -dy) * (180 / Math.PI);
          marker.setRotation(angle);
        }
        
        // Update water validation status
        const el = marker.getElement();
        if (el) {
          const isOverWater = ship.type === ShipType.CARGO_PLANE || 
                             isShipOverWater(new THREE.Vector3(ship.position.x, ship.position.y, ship.position.z), 100);
          const iconContainer = el.querySelector('.ship-icon-container') as HTMLElement;
          if (iconContainer) {
            iconContainer.style.opacity = !isOverWater && ship.type !== ShipType.CARGO_PLANE ? '0.6' : '1';
          }
        }
      }
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [fleet, selectedShipId, isMapLoaded]);
  
  // Add ship routes with water validation
  useEffect(() => {
    if (!map.current || !isMapLoaded) return;
    
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
        // Ignore errors
      }
      
      const routes: GeoJSON.Feature[] = fleet
        .filter(ship => ship.destination)
        .map(ship => {
          const startCoords = positionToLatLng(new THREE.Vector3(ship.position.x, ship.position.y, ship.position.z));
          const endCoords = positionToLatLng(new THREE.Vector3(ship.destination!.position.x, ship.destination!.position.y, ship.destination!.position.z));
          
          // Get waypoints for water route
          let coordinates: number[][];
          if (ship.type !== ShipType.CARGO_PLANE) {
            const waypoints = (ship as any).waypoints || getWaterRouteBetweenPorts(
              new THREE.Vector3(ship.position.x, ship.position.y, ship.position.z),
              new THREE.Vector3(ship.destination!.position.x, ship.destination!.position.y, ship.destination!.position.z),
              100
            );
            
            coordinates = waypoints.map((wp: THREE.Vector3) => {
              const wpCoords = positionToLatLng(wp);
              return [wpCoords.lng, wpCoords.lat];
            });
          } else {
            // Direct route for planes
            coordinates = [
              [startCoords.lng, startCoords.lat],
              [endCoords.lng, endCoords.lat]
            ];
          }
          
          return {
            type: 'Feature',
            properties: {
              shipId: ship.id,
              selected: ship.id === selectedShipId,
              shipType: ship.type
            },
            geometry: {
              type: 'LineString',
              coordinates: coordinates
            }
          };
        });
      
      if (routes.length > 0) {
        map.current.addSource('ship-routes', {
          type: 'geojson',
          data: {
            type: 'FeatureCollection',
            features: routes
          }
        });
        
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
            'line-dasharray': [
              'case',
              ['==', ['get', 'shipType'], 'CARGO_PLANE'],
              [0.5, 1.5],
              [0.1, 2]
            ],
            'line-blur': 0.5
          }
        });
        
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
      {!isMapLoaded && (
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
      <div 
        ref={mapContainer} 
        className={`mapbox-globe-container ${className || ''}`}
        style={{ 
          width: '100%', 
          height: '100%'
        }}
      />
      
      {/* Map Style Switcher */}
      <div style={{
        position: 'absolute',
        bottom: '20px',
        left: '20px',
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
          Map Style
        </div>
        <div style={{ display: 'flex', gap: '5px', flexWrap: 'wrap', maxWidth: '200px' }}>
          {Object.entries(MAP_STYLES).map(([key, style]) => (
            <button
              key={key}
              onClick={() => changeMapStyle(key as keyof typeof MAP_STYLES)}
              style={{
                padding: '8px 12px',
                background: currentStyle === key ? '#3b82f6' : 'rgba(255, 255, 255, 0.9)',
                color: currentStyle === key ? 'white' : '#1f2937',
                border: 'none',
                borderRadius: '6px',
                cursor: 'pointer',
                fontSize: '12px',
                fontWeight: '500',
                transition: 'all 0.2s'
              }}
            >
              {style.name}
            </button>
          ))}
        </div>
      </div>
      
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
      </div>
      
      {/* Map Features */}
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
          onClick={() => {
            setShowShippingLanes(!showShippingLanes);
            if (!showShippingLanes && map.current) {
              addShippingLanes();
            } else if (map.current && map.current.getLayer('shipping-lanes')) {
              map.current.removeLayer('shipping-lanes');
            }
          }}
          style={{
            padding: '10px 20px',
            background: showShippingLanes ? '#3b82f6' : 'rgba(255, 255, 255, 0.9)',
            color: showShippingLanes ? 'white' : '#1f2937',
            border: 'none',
            borderRadius: '8px',
            cursor: 'pointer',
            fontSize: '14px',
            fontWeight: '500',
            boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
            transition: 'all 0.2s'
          }}
        >
          🚢 Shipping Lanes
        </button>
        
        <button
          onClick={() => {
            setShowHeatmap(!showHeatmap);
            if (!showHeatmap && map.current) {
              addHeatmapLayer();
            } else if (map.current && map.current.getLayer('port-heatmap')) {
              map.current.removeLayer('port-heatmap');
            }
          }}
          style={{
            padding: '10px 20px',
            background: showHeatmap ? '#ef4444' : 'rgba(255, 255, 255, 0.9)',
            color: showHeatmap ? 'white' : '#1f2937',
            border: 'none',
            borderRadius: '8px',
            cursor: 'pointer',
            fontSize: '14px',
            fontWeight: '500',
            boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
            transition: 'all 0.2s'
          }}
        >
          🔥 Port Activity
        </button>
        
        <button
          onClick={() => {
            setShow3DTerrain(!show3DTerrain);
            if (!show3DTerrain && map.current) {
              add3DTerrain();
            } else if (map.current) {
              map.current.setTerrain(null);
            }
          }}
          style={{
            padding: '10px 20px',
            background: show3DTerrain ? '#10b981' : 'rgba(255, 255, 255, 0.9)',
            color: show3DTerrain ? 'white' : '#1f2937',
            border: 'none',
            borderRadius: '8px',
            cursor: 'pointer',
            fontSize: '14px',
            fontWeight: '500',
            boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
            transition: 'all 0.2s'
          }}
        >
          🏔️ 3D Terrain
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