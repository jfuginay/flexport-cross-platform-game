import React, { useRef, useEffect, useState, useCallback } from 'react';
import { useGameStore } from '../store/gameStore';
import { ShipType } from '../types/game.types';
import './MiniMap.css';

export const MiniMap: React.FC = () => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [zoom, setZoom] = useState(1);
  const { ports, fleet, selectedShipId, selectedPortId, selectShip, selectPort } = useGameStore();
  
  const worldBounds = {
    minX: -150,
    maxX: 150,
    minZ: -150,
    maxZ: 150
  };
  
  const mapSize = { width: 280, height: 280 };
  
  const worldToMap = useCallback((worldX: number, worldZ: number) => {
    // Project 3D sphere coordinates to 2D map
    const centerX = mapSize.width / 2;
    const centerY = mapSize.height / 2;
    const scale = (mapSize.width / 300) * zoom;
    
    return { 
      x: centerX + worldX * scale,
      y: centerY + worldZ * scale
    };
  }, [zoom]);
  
  
  const handleCanvasClick = (e: React.MouseEvent<HTMLCanvasElement>) => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    
    const rect = canvas.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    
    // Check if click is on a ship
    for (const ship of fleet) {
      const pos = worldToMap(ship.position.x, ship.position.z);
      const distance = Math.sqrt((x - pos.x) ** 2 + (y - pos.y) ** 2);
      if (distance < 10) {
        selectShip(ship.id);
        return;
      }
    }
    
    // Check if click is on a port
    for (const port of ports) {
      const pos = worldToMap(port.position.x, port.position.z);
      const distance = Math.sqrt((x - pos.x) ** 2 + (y - pos.y) ** 2);
      if (distance < 12) {
        selectPort(port.id);
        return;
      }
    }
  };
  
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    
    const animate = () => {
      // Clear canvas
      ctx.fillStyle = 'rgba(0, 20, 40, 0.9)';
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      
      // Draw grid
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.1)';
      ctx.lineWidth = 1;
      for (let i = 0; i <= 10; i++) {
        const x = (i / 10) * canvas.width;
        const y = (i / 10) * canvas.height;
        ctx.beginPath();
        ctx.moveTo(x, 0);
        ctx.lineTo(x, canvas.height);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(0, y);
        ctx.lineTo(canvas.width, y);
        ctx.stroke();
      }
      
      // Draw ship routes
      ctx.setLineDash([5, 5]);
      fleet.forEach((ship) => {
        if (ship.destination) {
          const start = worldToMap(ship.position.x, ship.position.z);
          const end = worldToMap(ship.destination.position.x, ship.destination.position.z);
          
          ctx.strokeStyle = selectedShipId === ship.id ? '#ffff00' : 'rgba(255, 255, 255, 0.5)';
          ctx.lineWidth = selectedShipId === ship.id ? 2 : 1;
          ctx.beginPath();
          ctx.moveTo(start.x, start.y);
          ctx.lineTo(end.x, end.y);
          ctx.stroke();
        }
      });
      ctx.setLineDash([]);
      
      // Draw ports
      ports.forEach((port) => {
        const pos = worldToMap(port.position.x, port.position.z);
        
        ctx.fillStyle = port.isPlayerOwned ? '#00ff00' : '#0088ff';
        ctx.strokeStyle = selectedPortId === port.id ? '#ffff00' : '#ffffff';
        ctx.lineWidth = selectedPortId === port.id ? 3 : 1;
        
        ctx.beginPath();
        ctx.arc(pos.x, pos.y, 8, 0, Math.PI * 2);
        ctx.fill();
        ctx.stroke();
        
        // Port name
        ctx.fillStyle = '#ffffff';
        ctx.font = '10px Arial';
        ctx.textAlign = 'center';
        ctx.fillText(port.name, pos.x, pos.y - 12);
      });
      
      // Draw ships
      fleet.forEach((ship) => {
        const pos = worldToMap(ship.position.x, ship.position.z);
        
        // Ship icon based on type
        ctx.save();
        ctx.translate(pos.x, pos.y);
        
        ctx.fillStyle = selectedShipId === ship.id ? '#ffff00' : '#ffffff';
        ctx.strokeStyle = '#000000';
        ctx.lineWidth = 1;
        
        switch (ship.type) {
          case ShipType.CONTAINER:
            // Rectangle for container ships
            ctx.fillRect(-6, -3, 12, 6);
            ctx.strokeRect(-6, -3, 12, 6);
            break;
          case ShipType.BULK:
            // Circle for bulk carriers
            ctx.beginPath();
            ctx.arc(0, 0, 5, 0, Math.PI * 2);
            ctx.fill();
            ctx.stroke();
            break;
          case ShipType.TANKER:
            // Oval for tankers
            ctx.beginPath();
            ctx.ellipse(0, 0, 8, 4, 0, 0, Math.PI * 2);
            ctx.fill();
            ctx.stroke();
            break;
          case ShipType.CARGO_PLANE:
            // Triangle for planes
            ctx.beginPath();
            ctx.moveTo(0, -6);
            ctx.lineTo(-4, 4);
            ctx.lineTo(4, 4);
            ctx.closePath();
            ctx.fill();
            ctx.stroke();
            break;
        }
        
        ctx.restore();
        
        // Ship name
        if (selectedShipId === ship.id) {
          ctx.fillStyle = '#ffff00';
          ctx.font = 'bold 10px Arial';
          ctx.textAlign = 'center';
          ctx.fillText(ship.name, pos.x, pos.y + 15);
        }
      });
      
      requestAnimationFrame(animate);
    };
    
    animate();
  }, [fleet, ports, selectedShipId, selectedPortId, zoom, worldToMap]);
  
  return (
    <div className="minimap-container">
      <div className="minimap-header">World Map</div>
      <canvas 
        ref={canvasRef} 
        width={mapSize.width * zoom} 
        height={mapSize.height * zoom}
        onClick={handleCanvasClick}
        className="minimap-canvas"
      />
      <div className="minimap-controls">
        <button onClick={() => setZoom(Math.max(0.5, zoom - 0.25))}>−</button>
        <span>{Math.round(zoom * 100)}%</span>
        <button onClick={() => setZoom(Math.min(2, zoom + 0.25))}>+</button>
      </div>
    </div>
  );
};