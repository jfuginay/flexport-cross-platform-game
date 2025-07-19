// @ts-nocheck
import React, { useEffect, useRef, useState, useCallback } from 'react';
import mapboxgl from 'mapbox-gl';
import * as THREE from 'three';
import { useGameStore } from '../store/gameStore';
import { positionToLatLng } from '../utils/geoUtils';
import { ShipStatus, ShipType } from '../types/game.types';
import { createShip3DModel, createShip3DModelLOD } from './mapbox3D/Ship3DModel';
import { createPort3DModel, createPort3DModelLOD } from './mapbox3D/Port3DModel';
import 'mapbox-gl/dist/mapbox-gl.css';
import './MapboxGlobe.css';

// Set your Mapbox access token
mapboxgl.accessToken = process.env.REACT_APP_MAPBOX_TOKEN || 'pk.eyJ1IjoiamZ1Z2luYXkiLCJhIjoiY21icmNha2hrMGE0azJscHVzdmVuZTVjOSJ9.oiJoYvc_G-tLUmaSzGVsVQ';

interface MapboxGlobeCombinedProps {
  className?: string;
}

export const MapboxGlobeCombined: React.FC<MapboxGlobeCombinedProps> = ({ className }) => {
  const mapContainer = useRef<HTMLDivElement>(null);
  const map = useRef<mapboxgl.Map | null>(null);
  const shipMarkers = useRef<Map<string, mapboxgl.Marker>>(new Map());
  const [isMapLoaded, setIsMapLoaded] = useState(false);
  const [isAdvancedMode, setIsAdvancedMode] = useState(false);
  const [showWeather, setShowWeather] = useState(false);
  const [showRain, setShowRain] = useState(false);
  
  // 3D model references
  const shipMeshes = useRef<Map<string, THREE.Group>>(new Map());
  const portMeshes = useRef<Map<string, THREE.Group>>(new Map());
  const previousPositions = useRef<Map<string, {lng: number, lat: number}>>(new Map());
  const customLayer3D = useRef<any>(null);
  
  const { fleet, ports, selectedShipId, selectShip, selectPort } = useGameStore();
  
  // Add custom 3D layer for advanced mode
  const addCustom3DLayer = useCallback(() => {
    if (!map.current || customLayer3D.current) return;
    
    customLayer3D.current = {
      id: '3d-models',
      type: 'custom',
      renderingMode: '3d',
      onAdd: function(map, gl) {
        this.camera = new THREE.Camera();
        this.scene = new THREE.Scene();
        this.map = map;

        // Lighting setup
        const ambientLight = new THREE.AmbientLight(0xffffff, 0.6);
        this.scene.add(ambientLight);

        const directionalLight = new THREE.DirectionalLight(0xffffff, 0.8);
        directionalLight.position.set(50, 100, 50).normalize();
        directionalLight.castShadow = true;
        this.scene.add(directionalLight);

        // Renderer
        this.renderer = new THREE.WebGLRenderer({
          canvas: map.getCanvas(),
          context: gl,
          antialias: true
        });

        this.renderer.autoClear = false;
        this.renderer.shadowMap.enabled = true;
        this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
      },
      
      render: function(gl, matrix) {
        const rotationX = new THREE.Matrix4().makeRotationAxis(
          new THREE.Vector3(1, 0, 0),
          Math.PI / 2
        );

        const m = new THREE.Matrix4().fromArray(matrix);
        this.camera.projectionMatrix = m.multiply(rotationX);

        // Update ships
        fleet.forEach(ship => {
          let shipMesh = shipMeshes.current.get(ship.id);
          
          if (!shipMesh) {
            // Create new ship mesh with LOD
            const zoom = map.current.getZoom();
            shipMesh = zoom > 10 ? 
              createShip3DModel(ship.type) : 
              createShip3DModelLOD(ship.type);
            
            this.scene.add(shipMesh);
            shipMeshes.current.set(ship.id, shipMesh);
          }

          // Convert position
          const coords = positionToLatLng(new THREE.Vector3(
            ship.position.x, 
            ship.position.y, 
            ship.position.z
          ));
          
          const modelAsMercatorCoordinate = mapboxgl.MercatorCoordinate.fromLngLat(
            [coords.lng, coords.lat],
            0
          );

          // Calculate rotation based on movement
          const prevPos = previousPositions.current.get(ship.id);
          if (prevPos) {
            const dlng = coords.lng - prevPos.lng;
            const dlat = coords.lat - prevPos.lat;
            
            if (Math.abs(dlng) > 0.0001 || Math.abs(dlat) > 0.0001) {
              const angle = Math.atan2(dlat, dlng);
              shipMesh.rotation.z = -angle + Math.PI / 2;
            }
          }
          previousPositions.current.set(ship.id, coords);

          // Update position and scale
          const scale = modelAsMercatorCoordinate.meterInMercatorCoordinateUnits() * 30;
          
          shipMesh.position.set(
            modelAsMercatorCoordinate.x,
            modelAsMercatorCoordinate.y,
            modelAsMercatorCoordinate.z
          );
          shipMesh.scale.set(scale, -scale, scale);
          
          // Highlight selected ship
          if (ship.id === selectedShipId) {
            shipMesh.traverse((child) => {
              if (child.isMesh) {
                child.material.emissive = new THREE.Color(0x00ff00);
                child.material.emissiveIntensity = 0.3;
              }
            });
          } else {
            shipMesh.traverse((child) => {
              if (child.isMesh && child.material.emissive) {
                child.material.emissiveIntensity = 0;
              }
            });
          }
        });

        // Update ports
        ports.forEach(port => {
          let portMesh = portMeshes.current.get(port.id);
          
          if (!portMesh) {
            // Create new port mesh with LOD
            const zoom = map.current.getZoom();
            portMesh = zoom > 8 ? 
              createPort3DModel(port.capacity) : 
              createPort3DModelLOD();
            
            this.scene.add(portMesh);
            portMeshes.current.set(port.id, portMesh);
          }

          const modelAsMercatorCoordinate = mapboxgl.MercatorCoordinate.fromLngLat(
            [port.position.lng, port.position.lat],
            0
          );

          // Update position and scale
          const scale = modelAsMercatorCoordinate.meterInMercatorCoordinateUnits() * 50;
          
          portMesh.position.set(
            modelAsMercatorCoordinate.x,
            modelAsMercatorCoordinate.y,
            modelAsMercatorCoordinate.z
          );
          portMesh.scale.set(scale, -scale, scale);
          
          // Animate cranes
          const time = Date.now() * 0.001;
          const cranes = portMesh.children.filter(child => child.name === 'crane');
          cranes.forEach((crane, index) => {
            crane.rotation.y = Math.sin(time * 0.5 + index) * 0.3;
          });
        });

        // Clean up removed entities
        shipMeshes.current.forEach((mesh, id) => {
          if (!fleet.find(s => s.id === id)) {
            this.scene.remove(mesh);
            shipMeshes.current.delete(id);
            previousPositions.current.delete(id);
          }
        });

        portMeshes.current.forEach((mesh, id) => {
          if (!ports.find(p => p.id === id)) {
            this.scene.remove(mesh);
            portMeshes.current.delete(id);
          }
        });

        this.renderer.resetState();
        this.renderer.render(this.scene, this.camera);
        this.map.triggerRepaint();
      }
    };
    
    map.current.addLayer(customLayer3D.current);
  }, [fleet, ports, selectedShipId]);

  // Initialize map - ONLY ONCE
  useEffect(() => {
    if (!mapContainer.current || map.current) return;

    try {
      map.current = new mapboxgl.Map({
        container: mapContainer.current,
        style: 'mapbox://styles/mapbox/satellite-streets-v12',
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

      // Add navigation controls
      map.current.addControl(new mapboxgl.NavigationControl(), 'top-right');

      map.current.on('load', () => {
        console.log('Map loaded successfully');
        setIsMapLoaded(true);

        // Basic globe configuration
        if (map.current) {
          map.current.setFog({
            color: 'rgb(186, 210, 235)',
            'high-color': 'rgb(36, 92, 223)',
            'horizon-blend': 0.02,
            'space-color': 'rgb(11, 11, 25)',
            'star-intensity': 0.8
          });

          map.current.setLight({
            anchor: 'viewport',
            color: 'white',
            intensity: 0.4,
            position: [1.5, 90, 80]
          });

          // Add 3D terrain if in advanced mode
          if (isAdvancedMode) {
            map.current.addSource('mapbox-dem', {
              type: 'raster-dem',
              url: 'mapbox://mapbox.mapbox-terrain-dem-v1',
              tileSize: 512,
              maxzoom: 14
            });
            
            map.current.setTerrain({ 
              source: 'mapbox-dem', 
              exaggeration: 2.0
            });
            
            // Add 3D models layer
            addCustom3DLayer();
          }
        }
      });

      map.current.on('error', (e) => {
        console.error('Mapbox error:', e);
      });

    } catch (error) {
      console.error('Failed to initialize map:', error);
    }

    // Cleanup
    return () => {
      // Clear all markers
      shipMarkers.current.forEach(marker => marker.remove());
      shipMarkers.current.clear();
      
      if (map.current) {
        map.current.remove();
        map.current = null;
      }
    };
  }, []); // Empty dependency array - run only once

  // Toggle between simple and advanced modes
  const toggleMode = useCallback(() => {
    if (!map.current || !isMapLoaded) return;

    setIsAdvancedMode(prev => {
      const newMode = !prev;
      
      if (newMode) {
        // Enable advanced features
        if (!map.current!.getSource('mapbox-dem')) {
          map.current!.addSource('mapbox-dem', {
            type: 'raster-dem',
            url: 'mapbox://mapbox.mapbox-terrain-dem-v1',
            tileSize: 512,
            maxzoom: 14
          });
        }
        map.current!.setTerrain({ 
          source: 'mapbox-dem', 
          exaggeration: 2.0
        });
        
        // Add 3D models layer
        addCustom3DLayer();
        
        // Remove HTML markers (will be replaced by 3D models)
        shipMarkers.current.forEach(marker => marker.remove());
        shipMarkers.current.clear();
      } else {
        // Disable advanced features
        if (map.current!.getTerrain()) {
          map.current!.setTerrain(null);
        }
        
        // Remove 3D layer
        if (customLayer3D.current && map.current!.getLayer('3d-models')) {
          map.current!.removeLayer('3d-models');
          customLayer3D.current = null;
          
          // Clear 3D meshes
          shipMeshes.current.clear();
          portMeshes.current.clear();
          previousPositions.current.clear();
        }
        // Keep the dem source for potential re-enabling
      }
      
      return newMode;
    });
  }, [isMapLoaded, addCustom3DLayer]);

  // Add ports to map
  useEffect(() => {
    if (!map.current || !isMapLoaded || ports.length === 0 || !isAdvancedMode) return;

    // Wait for style to load
    if (!map.current.isStyleLoaded()) {
      const checkStyleLoaded = () => {
        if (map.current?.isStyleLoaded()) {
          addPortsLayer();
        } else {
          setTimeout(checkStyleLoaded, 100);
        }
      };
      checkStyleLoaded();
    } else {
      addPortsLayer();
    }

    function addPortsLayer() {
      if (!map.current || map.current.getSource('ports')) return;

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
            availableBerths: port.availableBerths
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

      // Add port markers
      map.current.addLayer({
        id: 'unclustered-ports',
        type: 'circle',
        source: 'ports',
        filter: ['!', ['has', 'point_count']],
        paint: {
          'circle-radius': 8,
          'circle-color': '#3b82f6',
          'circle-stroke-color': '#ffffff',
          'circle-stroke-width': 2,
          'circle-opacity': 0.9
        }
      });

      // Port click handler
      map.current.on('click', 'unclustered-ports', (e) => {
        if (e.features && e.features[0]) {
          const portId = e.features[0].properties?.id;
          if (portId) {
            selectPort(portId);
          }
        }
      });

      // Port hover effect
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
    }
  }, [ports, isMapLoaded, isAdvancedMode, selectPort]);

  // Update ship markers
  useEffect(() => {
    if (!map.current || !isMapLoaded) return;

    // If using 3D models in advanced mode, hide HTML markers
    if (isAdvancedMode && customLayer3D.current) {
      shipMarkers.current.forEach(marker => marker.remove());
      shipMarkers.current.clear();
      return;
    }

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
        // Create ship marker element
        const el = document.createElement('div');
        el.className = 'ship-marker';
        
        if (isAdvancedMode) {
          // Advanced ship marker with detailed graphics
          el.setAttribute('data-ship-type', ship.type);
          el.style.cssText = `
            width: 80px;
            height: 80px;
            cursor: pointer;
            position: absolute;
            transform: translate(-50%, -50%);
          `;
          
          // Add ship icon based on type
          const shipIcon = getShipIcon(ship.type);
          el.innerHTML = `
            <div style="
              width: 100%;
              height: 100%;
              position: relative;
              filter: drop-shadow(0 2px 4px rgba(0,0,0,0.3));
            ">
              ${shipIcon}
              <div style="
                position: absolute;
                bottom: -20px;
                left: 50%;
                transform: translateX(-50%);
                background: rgba(0,0,0,0.8);
                color: white;
                padding: 2px 6px;
                border-radius: 3px;
                font-size: 11px;
                white-space: nowrap;
              ">${ship.name}</div>
            </div>
          `;
        } else {
          // Simple ship marker
          el.style.cssText = `
            width: 40px;
            height: 40px;
            background: #3b82f6;
            border: 2px solid white;
            border-radius: 50%;
            cursor: pointer;
            box-shadow: 0 2px 4px rgba(0,0,0,0.3);
          `;
        }

        el.addEventListener('click', () => {
          selectShip(ship.id);
        });

        const coords = positionToLatLng(new THREE.Vector3(ship.position.x, ship.position.y, ship.position.z));
        
        marker = new mapboxgl.Marker({
          element: el,
          anchor: 'center'
        })
          .setLngLat([coords.lng, coords.lat])
          .addTo(map.current!);
        
        shipMarkers.current.set(ship.id, marker);
      } else {
        // Update existing marker position
        const coords = positionToLatLng(new THREE.Vector3(ship.position.x, ship.position.y, ship.position.z));
        marker.setLngLat([coords.lng, coords.lat]);
        
        // Update selection state
        const el = marker.getElement();
        if (ship.id === selectedShipId) {
          el.classList.add('selected');
        } else {
          el.classList.remove('selected');
        }
      }
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [fleet, selectedShipId, isMapLoaded, isAdvancedMode]);

  // Helper function to get ship icon SVG
  const getShipIcon = (shipType: ShipType): string => {
    const icons = {
      [ShipType.CONTAINER]: `<svg viewBox="0 0 40 40" style="width: 100%; height: 100%;">
        <rect x="10" y="15" width="20" height="10" fill="#3b82f6" stroke="#2563eb" stroke-width="2"/>
        <rect x="12" y="12" width="16" height="3" fill="#ef4444"/>
        <rect x="15" y="9" width="10" height="3" fill="#10b981"/>
      </svg>`,
      [ShipType.BULK]: `<svg viewBox="0 0 40 40" style="width: 100%; height: 100%;">
        <ellipse cx="20" cy="20" rx="15" ry="8" fill="#10b981" stroke="#059669" stroke-width="2"/>
        <circle cx="15" cy="18" r="2" fill="#8b4513"/>
        <circle cx="20" cy="18" r="2" fill="#8b4513"/>
        <circle cx="25" cy="18" r="2" fill="#8b4513"/>
      </svg>`,
      [ShipType.TANKER]: `<svg viewBox="0 0 40 40" style="width: 100%; height: 100%;">
        <ellipse cx="20" cy="20" rx="15" ry="10" fill="#f97316" stroke="#ea580c" stroke-width="2"/>
        <ellipse cx="20" cy="17" rx="12" ry="7" fill="#ef4444"/>
      </svg>`,
      [ShipType.CARGO_PLANE]: `<svg viewBox="0 0 40 40" style="width: 100%; height: 100%;">
        <path d="M 20 10 L 15 25 L 20 22 L 25 25 Z" fill="#8b5cf6" stroke="#7c3aed" stroke-width="2"/>
        <path d="M 10 20 L 5 18 L 5 22 Z" fill="#6d28d9"/>
        <path d="M 30 20 L 35 18 L 35 22 Z" fill="#6d28d9"/>
      </svg>`
    };
    return icons[shipType] || icons[ShipType.CONTAINER];
  };

  return (
    <div style={{ width: '100%', height: '100%', position: 'relative' }}>
      {/* Loading indicator */}
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
      
      {/* Map container */}
      <div 
        ref={mapContainer} 
        className={`mapbox-globe-container ${className || ''}`}
        style={{ 
          width: '100%', 
          height: '100%'
        }}
      />
      
      {/* Mode toggle button */}
      <div style={{
        position: 'absolute',
        top: '20px',
        right: '80px',
        zIndex: 100
      }}>
        <button
          onClick={toggleMode}
          style={{
            padding: '10px 20px',
            background: isAdvancedMode ? '#8b5cf6' : '#3b82f6',
            color: 'white',
            border: 'none',
            borderRadius: '8px',
            cursor: 'pointer',
            fontSize: '14px',
            fontWeight: '500',
            boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
            transition: 'all 0.2s'
          }}
        >
          {isAdvancedMode ? '🌍 Advanced Mode' : '🗺️ Simple Mode'}
        </button>
      </div>

      {/* Weather controls (advanced mode only) */}
      {isAdvancedMode && (
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
            onClick={() => setShowRain(!showRain)}
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
      )}
    </div>
  );
};