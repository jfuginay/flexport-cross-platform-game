// @ts-nocheck
import React, { useEffect, useRef, useState } from 'react';
import mapboxgl from 'mapbox-gl';
import * as THREE from 'three';
import { useGameStore } from '../store/gameStore';
import { positionToLatLng } from '../utils/geoUtils';
import { createShip3DModel, createShip3DModelLOD } from './mapbox3D/Ship3DModel';
import { createPort3DModel, createPort3DModelLOD } from './mapbox3D/Port3DModel';
import 'mapbox-gl/dist/mapbox-gl.css';

mapboxgl.accessToken = process.env.REACT_APP_MAPBOX_TOKEN || 'pk.eyJ1IjoiamZ1Z2luYXkiLCJhIjoiY21icmNha2hrMGE0azJscHVzdmVuZTVjOSJ9.oiJoYvc_G-tLUmaSzGVsVQ';

interface MapboxGlobe3DProps {
  className?: string;
}

export const MapboxGlobe3D: React.FC<MapboxGlobe3DProps> = ({ className }) => {
  const mapContainer = useRef<HTMLDivElement>(null);
  const map = useRef<mapboxgl.Map | null>(null);
  const [isMapLoaded, setIsMapLoaded] = useState(false);
  
  const { fleet, ports, selectedShipId, selectShip, selectPort } = useGameStore();
  
  // Store references to 3D objects
  const shipMeshes = useRef<Map<string, THREE.Group>>(new Map());
  const portMeshes = useRef<Map<string, THREE.Group>>(new Map());
  const previousPositions = useRef<Map<string, {lng: number, lat: number}>>(new Map());
  
  // Initialize map
  useEffect(() => {
    if (!mapContainer.current || map.current) return;

    map.current = new mapboxgl.Map({
      container: mapContainer.current,
      style: 'mapbox://styles/mapbox/standard',
      config: {
        basemap: {
          theme: 'default',
          show3dObjects: false // Turn off default 3D buildings
        }
      },
      projection: 'globe',
      center: [0, 20],
      zoom: 2.5,
      pitch: 45,
      bearing: 0,
      antialias: true
    });

    map.current.on('style.load', () => {
      console.log('Map loaded, adding 3D layer');
      setIsMapLoaded(true);

      // Set fog and atmosphere
      map.current.setFog({
        color: 'rgb(186, 210, 235)',
        'high-color': 'rgb(36, 92, 223)',
        'horizon-blend': 0.02,
        'space-color': 'rgb(11, 11, 25)',
        'star-intensity': 0.8
      });

      // Add custom 3D layer
      const customLayer = {
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
            
            const translateX = modelAsMercatorCoordinate.x;
            const translateY = modelAsMercatorCoordinate.y; 
            const translateZ = modelAsMercatorCoordinate.z;

            shipMesh.position.set(translateX, translateY, translateZ);
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

          // Remove meshes for deleted entities
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

      map.current.addLayer(customLayer);
    });

    // Add click handlers for 3D objects
    map.current.on('click', (e) => {
      const features = map.current.queryRenderedFeatures(e.point);
      
      // Since 3D objects don't have features, we need to use raycasting
      // For now, we'll use a simple distance-based selection
      const clickedLngLat = e.lngLat;
      
      // Check ships
      let closestShip = null;
      let closestDistance = Infinity;
      
      fleet.forEach(ship => {
        const coords = positionToLatLng(new THREE.Vector3(
          ship.position.x, 
          ship.position.y, 
          ship.position.z
        ));
        
        const distance = Math.sqrt(
          Math.pow(coords.lng - clickedLngLat.lng, 2) + 
          Math.pow(coords.lat - clickedLngLat.lat, 2)
        );
        
        if (distance < closestDistance && distance < 2) { // Within 2 degrees
          closestDistance = distance;
          closestShip = ship;
        }
      });
      
      if (closestShip) {
        selectShip(closestShip.id);
        return;
      }
      
      // Check ports
      let closestPort = null;
      closestDistance = Infinity;
      
      ports.forEach(port => {
        const distance = Math.sqrt(
          Math.pow(port.position.lng - clickedLngLat.lng, 2) + 
          Math.pow(port.position.lat - clickedLngLat.lat, 2)
        );
        
        if (distance < closestDistance && distance < 2) { // Within 2 degrees
          closestDistance = distance;
          closestPort = port;
        }
      });
      
      if (closestPort) {
        selectPort(closestPort.id);
      }
    });

    // Navigation controls
    map.current.addControl(new mapboxgl.NavigationControl(), 'top-right');

    return () => {
      map.current?.remove();
    };
  }, []);

  // Update layer when data changes
  useEffect(() => {
    if (!map.current || !isMapLoaded) return;
    map.current.triggerRepaint();
  }, [fleet, ports, selectedShipId, isMapLoaded]);

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
          <div className="loading-spinner"></div>
          <p style={{ marginTop: '20px' }}>Loading 3D map...</p>
        </div>
      )}
      
      <div 
        ref={mapContainer} 
        className={className}
        style={{ 
          width: '100%', 
          height: '100%'
        }}
      />
      
      {/* Controls overlay */}
      <div style={{
        position: 'absolute',
        bottom: '20px',
        left: '20px',
        background: 'rgba(0,0,0,0.8)',
        color: 'white',
        padding: '10px',
        borderRadius: '8px',
        fontSize: '12px'
      }}>
        <div>🚢 Ships: {fleet.length}</div>
        <div>🏭 Ports: {ports.length}</div>
        <div>Click on ships or ports to select</div>
      </div>
    </div>
  );
};