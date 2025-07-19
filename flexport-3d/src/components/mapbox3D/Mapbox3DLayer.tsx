// @ts-nocheck
import * as THREE from 'three';
import mapboxgl from 'mapbox-gl';
import { Ship, Port } from '../../types/game.types';
import { createShip3DModel } from './Ship3DModel';
import { createPort3DModel } from './Port3DModel';

export class Mapbox3DLayer {
  id: string;
  type: 'custom';
  renderingMode: '3d';
  
  private camera: THREE.Camera;
  private scene: THREE.Scene;
  private renderer: THREE.WebGLRenderer;
  private map: mapboxgl.Map;
  
  private shipMeshes: Map<string, THREE.Group> = new Map();
  private portMeshes: Map<string, THREE.Group> = new Map();
  
  private previousPositions: Map<string, {x: number, y: number}> = new Map();
  
  constructor(map: mapboxgl.Map) {
    this.id = '3d-models-layer';
    this.type = 'custom';
    this.renderingMode = '3d';
    this.map = map;
    
    this.camera = new THREE.Camera();
    this.scene = new THREE.Scene();
    
    // Add lighting
    const ambientLight = new THREE.AmbientLight(0xffffff, 0.6);
    this.scene.add(ambientLight);
    
    const directionalLight = new THREE.DirectionalLight(0xffffff, 0.8);
    directionalLight.position.set(50, 100, 50);
    directionalLight.castShadow = true;
    directionalLight.shadow.mapSize.width = 2048;
    directionalLight.shadow.mapSize.height = 2048;
    this.scene.add(directionalLight);
    
    // Add subtle fog for atmosphere
    this.scene.fog = new THREE.Fog(0x87CEEB, 5000, 50000);
  }
  
  onAdd(map: mapboxgl.Map, gl: WebGLRenderingContext) {
    this.renderer = new THREE.WebGLRenderer({
      canvas: map.getCanvas(),
      context: gl,
      antialias: true
    });
    
    this.renderer.autoClear = false;
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  }
  
  updateShips(ships: Ship[]) {
    // Remove ships that no longer exist
    this.shipMeshes.forEach((mesh, id) => {
      if (!ships.find(s => s.id === id)) {
        this.scene.remove(mesh);
        this.shipMeshes.delete(id);
        this.previousPositions.delete(id);
      }
    });
    
    // Update or create ship meshes
    ships.forEach(ship => {
      let shipMesh = this.shipMeshes.get(ship.id);
      
      if (!shipMesh) {
        // Create new ship mesh
        shipMesh = createShip3DModel(ship.type);
        this.scene.add(shipMesh);
        this.shipMeshes.set(ship.id, shipMesh);
      }
      
      // Convert lat/lng to Mercator coordinates
      const modelOrigin = [ship.position.lng, ship.position.lat];
      const modelAsMercatorCoordinate = mapboxgl.MercatorCoordinate.fromLngLat(
        modelOrigin,
        0
      );
      
      // Update position
      shipMesh.position.set(
        modelAsMercatorCoordinate.x,
        modelAsMercatorCoordinate.y,
        modelAsMercatorCoordinate.z
      );
      
      // Calculate rotation based on movement direction
      const prevPos = this.previousPositions.get(ship.id);
      if (prevPos) {
        const dx = modelAsMercatorCoordinate.x - prevPos.x;
        const dy = modelAsMercatorCoordinate.y - prevPos.y;
        
        if (Math.abs(dx) > 0.00001 || Math.abs(dy) > 0.00001) {
          const angle = Math.atan2(dy, dx);
          shipMesh.rotation.z = angle - Math.PI / 2; // Adjust for model orientation
        }
      }
      
      // Store current position for next frame
      this.previousPositions.set(ship.id, {
        x: modelAsMercatorCoordinate.x,
        y: modelAsMercatorCoordinate.y
      });
      
      // Update scale based on zoom level
      const scale = modelAsMercatorCoordinate.meterInMercatorCoordinateUnits() * 50;
      shipMesh.scale.set(scale, scale, scale);
    });
  }
  
  updatePorts(ports: Port[]) {
    // Remove ports that no longer exist
    this.portMeshes.forEach((mesh, id) => {
      if (!ports.find(p => p.id === id)) {
        this.scene.remove(mesh);
        this.portMeshes.delete(id);
      }
    });
    
    // Update or create port meshes
    ports.forEach(port => {
      let portMesh = this.portMeshes.get(port.id);
      
      if (!portMesh) {
        // Create new port mesh
        portMesh = createPort3DModel(port.capacity);
        this.scene.add(portMesh);
        this.portMeshes.set(port.id, portMesh);
      }
      
      // Convert lat/lng to Mercator coordinates
      const modelOrigin = [port.position.lng, port.position.lat];
      const modelAsMercatorCoordinate = mapboxgl.MercatorCoordinate.fromLngLat(
        modelOrigin,
        0
      );
      
      // Update position
      portMesh.position.set(
        modelAsMercatorCoordinate.x,
        modelAsMercatorCoordinate.y,
        modelAsMercatorCoordinate.z
      );
      
      // Update scale based on zoom level
      const scale = modelAsMercatorCoordinate.meterInMercatorCoordinateUnits() * 100;
      portMesh.scale.set(scale, scale, scale);
    });
  }
  
  render(gl: WebGLRenderingContext, matrix: number[]) {
    const m = new THREE.Matrix4().fromArray(matrix);
    this.camera.projectionMatrix = m;
    
    // Animate cranes and other elements
    const time = Date.now() * 0.001;
    this.portMeshes.forEach((portMesh) => {
      // Animate cranes
      const cranes = portMesh.children.filter(child => child.name === 'crane');
      cranes.forEach((crane, index) => {
        crane.rotation.y = Math.sin(time + index) * 0.3;
      });
    });
    
    this.renderer.resetState();
    this.renderer.render(this.scene, this.camera);
    this.map.triggerRepaint();
  }
}