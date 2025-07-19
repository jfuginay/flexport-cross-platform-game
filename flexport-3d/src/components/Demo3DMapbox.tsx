// @ts-nocheck
import React, { useEffect } from 'react';
import { MapboxGlobeCombined } from './MapboxGlobeCombined';
import { useGameStore } from '../store/gameStore';
import { ShipType } from '../types/game.types';

export const Demo3DMapbox: React.FC = () => {
  const { addShip, addPort } = useGameStore();
  
  useEffect(() => {
    // Add demo ports
    addPort({
      id: 'port-singapore',
      name: 'Singapore Port',
      position: { lat: 1.2897, lng: 103.8501 },
      capacity: 10000,
      owner: 'player1',
      color: '#3498db'
    });
    
    addPort({
      id: 'port-shanghai',
      name: 'Shanghai Port',
      position: { lat: 31.2304, lng: 121.4737 },
      capacity: 8000,
      owner: 'player1',
      color: '#e74c3c'
    });
    
    addPort({
      id: 'port-la',
      name: 'Los Angeles Port',
      position: { lat: 33.7281, lng: -118.2620 },
      capacity: 7000,
      owner: 'player2',
      color: '#2ecc71'
    });
    
    // Add demo ships
    addShip({
      id: 'ship-container-1',
      name: 'MSC Oscar',
      type: ShipType.CONTAINER,
      position: { x: 0, y: 0, z: 0 }, // Will be converted to lat/lng
      capacity: 5000,
      currentCargo: 3000,
      speed: 20,
      owner: 'player1',
      status: 'sailing'
    });
    
    addShip({
      id: 'ship-tanker-1',
      name: 'Seawise Giant',
      type: ShipType.TANKER,
      position: { x: 1000000, y: 0, z: 1000000 },
      capacity: 6000,
      currentCargo: 4000,
      speed: 18,
      owner: 'player1',
      status: 'sailing'
    });
    
    addShip({
      id: 'ship-bulk-1',
      name: 'Berge Stahl',
      type: ShipType.BULK,
      position: { x: -1000000, y: 0, z: 500000 },
      capacity: 4000,
      currentCargo: 2000,
      speed: 16,
      owner: 'player2',
      status: 'sailing'
    });
    
    // Simulate ship movement
    const interval = setInterval(() => {
      const store = useGameStore.getState();
      store.fleet.forEach(ship => {
        // Simple circular movement for demo
        const time = Date.now() * 0.0001;
        const radius = 2000000;
        const newX = Math.cos(time + parseInt(ship.id.slice(-1))) * radius;
        const newZ = Math.sin(time + parseInt(ship.id.slice(-1))) * radius;
        
        store.updateShipPosition(ship.id, {
          x: newX,
          y: 0,
          z: newZ
        });
      });
    }, 100);
    
    return () => clearInterval(interval);
  }, []);
  
  return (
    <div style={{ 
      width: '100vw', 
      height: '100vh',
      position: 'relative'
    }}>
      <MapboxGlobeCombined />
      
      {/* Instructions overlay */}
      <div style={{
        position: 'absolute',
        top: '20px',
        left: '20px',
        background: 'rgba(0,0,0,0.8)',
        color: 'white',
        padding: '20px',
        borderRadius: '8px',
        maxWidth: '300px'
      }}>
        <h3 style={{ margin: '0 0 10px 0' }}>3D Ships & Ports Demo</h3>
        <p style={{ margin: '5px 0' }}>🎮 Click "Advanced Mode" button to see 3D models</p>
        <p style={{ margin: '5px 0' }}>🚢 Ships rotate based on movement direction</p>
        <p style={{ margin: '5px 0' }}>🏭 Port cranes are animated</p>
        <p style={{ margin: '5px 0' }}>📍 Click on ships or ports to select them</p>
        <p style={{ margin: '5px 0' }}>🔍 Zoom in to see more detail (LOD system)</p>
      </div>
    </div>
  );
};