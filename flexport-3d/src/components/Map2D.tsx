import React, { useRef, useEffect, useState } from 'react';
import { useGameStore } from '../store/gameStore';
import { ShipStatus, ShipType } from '../types/game.types';
import './Map2D.css';

export const Map2D: React.FC = () => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const { fleet, ports, selectShip, selectPort, selectedShipId, selectedPortId } = useGameStore();
  const [hoveredItem, setHoveredItem] = useState<{ type: 'ship' | 'port', id: string } | null>(null);
  
  // Convert lat/lng to 2D map coordinates
  const latLngToXY = (lat: number, lng: number, width: number, height: number) => {
    const x = ((lng + 180) / 360) * width;
    const y = ((90 - lat) / 180) * height;
    return { x, y };
  };
  
  // Convert 3D position to lat/lng
  const positionToLatLng = (position: { x: number, y: number, z: number }) => {
    const normalized = {
      x: position.x / 100,
      y: position.y / 100,
      z: position.z / 100
    };
    const lat = Math.asin(normalized.y) * (180 / Math.PI);
    const lng = Math.atan2(normalized.z, -normalized.x) * (180 / Math.PI);
    return { lat, lng };
  };
  
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    
    const render = () => {
      const width = canvas.width;
      const height = canvas.height;
      
      // Clear canvas
      ctx.clearRect(0, 0, width, height);
      
      // Draw ocean background
      ctx.fillStyle = '#1e3a5f';
      ctx.fillRect(0, 0, width, height);
      
      // Add ocean depth variation
      const oceanGradient = ctx.createRadialGradient(width/2, height/2, 0, width/2, height/2, Math.max(width, height));
      oceanGradient.addColorStop(0, 'rgba(30, 58, 95, 0)');
      oceanGradient.addColorStop(0.7, 'rgba(20, 40, 60, 0.3)');
      oceanGradient.addColorStop(1, 'rgba(10, 20, 30, 0.5)');
      ctx.fillStyle = oceanGradient;
      ctx.fillRect(0, 0, width, height);
      
      // Add subtle wave patterns
      ctx.globalAlpha = 0.05;
      ctx.strokeStyle = '#4682B4';
      ctx.lineWidth = 1;
      for (let y = 0; y < height; y += 40) {
        ctx.beginPath();
        for (let x = 0; x < width; x += 10) {
          const waveY = y + Math.sin((x / 100) + (Date.now() / 3000)) * 5;
          if (x === 0) {
            ctx.moveTo(x, waveY);
          } else {
            ctx.lineTo(x, waveY);
          }
        }
        ctx.stroke();
      }
      ctx.globalAlpha = 1;
      
      // Draw grid lines (latitude/longitude)
      ctx.strokeStyle = 'rgba(100, 149, 237, 0.15)'; // Cornflower blue
      ctx.lineWidth = 0.3;
      ctx.setLineDash([5, 10]);
      
      // Latitude lines (every 15 degrees for finer grid)
      for (let lat = -75; lat <= 75; lat += 15) {
        const y = ((90 - lat) / 180) * height;
        ctx.beginPath();
        ctx.moveTo(0, y);
        ctx.lineTo(width, y);
        ctx.stroke();
      }
      
      // Longitude lines (every 15 degrees)
      for (let lng = -165; lng <= 165; lng += 15) {
        const x = ((lng + 180) / 360) * width;
        ctx.beginPath();
        ctx.moveTo(x, 0);
        ctx.lineTo(x, height);
        ctx.stroke();
      }
      
      // Equator and Prime Meridian (more prominent)
      ctx.strokeStyle = 'rgba(100, 149, 237, 0.3)';
      ctx.lineWidth = 1;
      ctx.setLineDash([]);
      
      // Equator
      ctx.beginPath();
      ctx.moveTo(0, height / 2);
      ctx.lineTo(width, height / 2);
      ctx.stroke();
      
      // Prime Meridian
      ctx.beginPath();
      ctx.moveTo(width / 2, 0);
      ctx.lineTo(width / 2, height);
      ctx.stroke();
      
      ctx.setLineDash([]);
      
      // Draw continents
      drawContinents(ctx, width, height);
      
      // Draw shipping lanes
      drawShippingLanes(ctx, width, height);
      
      // Draw ports
      ports.forEach(port => {
        const { lat, lng } = positionToLatLng(port.position);
        const { x, y } = latLngToXY(lat, lng, width, height);
        
        // Port glow effect
        if (selectedPortId === port.id) {
          const glowGradient = ctx.createRadialGradient(x, y, 0, x, y, 20);
          glowGradient.addColorStop(0, 'rgba(255, 215, 0, 0.3)');
          glowGradient.addColorStop(1, 'rgba(255, 215, 0, 0)');
          ctx.fillStyle = glowGradient;
          ctx.fillRect(x - 20, y - 20, 40, 40);
        }
        
        // Port icon
        ctx.save();
        ctx.translate(x, y);
        
        // Port building
        ctx.fillStyle = port.isPlayerOwned ? '#10b981' : '#6366f1';
        ctx.fillRect(-8, -8, 16, 16);
        
        // Port details
        ctx.fillStyle = 'rgba(0, 0, 0, 0.3)';
        ctx.fillRect(-6, -6, 12, 12);
        
        // Port center
        ctx.fillStyle = port.isPlayerOwned ? '#34d399' : '#818cf8';
        ctx.fillRect(-4, -4, 8, 8);
        
        // Port name
        ctx.fillStyle = 'white';
        ctx.font = '10px Arial';
        ctx.textAlign = 'center';
        ctx.fillText(port.name, 0, -12);
        
        ctx.restore();
      });
      
      // Draw ships
      fleet.forEach(ship => {
        const { lat, lng } = positionToLatLng(ship.position);
        const { x, y } = latLngToXY(lat, lng, width, height);
        
        // Ship trail
        if (ship.destination && ship.status === ShipStatus.SAILING) {
          const destLatLng = positionToLatLng(ship.destination.position);
          const dest = latLngToXY(destLatLng.lat, destLatLng.lng, width, height);
          
          ctx.strokeStyle = 'rgba(59, 130, 246, 0.3)';
          ctx.lineWidth = 2;
          ctx.setLineDash([5, 5]);
          ctx.beginPath();
          ctx.moveTo(x, y);
          ctx.lineTo(dest.x, dest.y);
          ctx.stroke();
          ctx.setLineDash([]);
        }
        
        // Ship selection glow
        if (selectedShipId === ship.id) {
          const glowGradient = ctx.createRadialGradient(x, y, 0, x, y, 15);
          glowGradient.addColorStop(0, 'rgba(59, 130, 246, 0.4)');
          glowGradient.addColorStop(1, 'rgba(59, 130, 246, 0)');
          ctx.fillStyle = glowGradient;
          ctx.fillRect(x - 15, y - 15, 30, 30);
        }
        
        // Draw ship based on type
        ctx.save();
        ctx.translate(x, y);
        
        if (ship.type === ShipType.CARGO_PLANE) {
          // Draw plane
          ctx.fillStyle = '#87CEEB';
          ctx.beginPath();
          ctx.moveTo(0, -8);
          ctx.lineTo(-12, 4);
          ctx.lineTo(-2, 2);
          ctx.lineTo(-2, 6);
          ctx.lineTo(2, 6);
          ctx.lineTo(2, 2);
          ctx.lineTo(12, 4);
          ctx.closePath();
          ctx.fill();
        } else {
          // Draw ship
          const shipColor = {
            [ShipType.CONTAINER]: '#4169E1',
            [ShipType.BULK]: '#8B4513',
            [ShipType.TANKER]: '#FF6347',
          }[ship.type] || '#4169E1';
          
          ctx.fillStyle = shipColor;
          ctx.beginPath();
          ctx.moveTo(0, -6);
          ctx.lineTo(-4, 6);
          ctx.lineTo(4, 6);
          ctx.closePath();
          ctx.fill();
          
          // Ship detail
          ctx.fillStyle = 'rgba(255, 255, 255, 0.3)';
          ctx.fillRect(-2, -2, 4, 4);
        }
        
        // Ship name
        ctx.fillStyle = 'white';
        ctx.font = '9px Arial';
        ctx.textAlign = 'center';
        ctx.fillText(ship.name, 0, 15);
        
        // Status indicator
        const statusColor = {
          [ShipStatus.IDLE]: '#10b981',
          [ShipStatus.SAILING]: '#3b82f6',
          [ShipStatus.LOADING]: '#f59e0b',
          [ShipStatus.UNLOADING]: '#f59e0b',
          [ShipStatus.MAINTENANCE]: '#ef4444',
        }[ship.status];
        
        ctx.fillStyle = statusColor;
        ctx.beginPath();
        ctx.arc(8, -8, 3, 0, Math.PI * 2);
        ctx.fill();
        
        ctx.restore();
      });
      
      // Draw hover info
      if (hoveredItem) {
        ctx.fillStyle = 'rgba(0, 0, 0, 0.8)';
        ctx.fillRect(10, height - 60, 200, 50);
        ctx.fillStyle = 'white';
        ctx.font = '12px Arial';
        
        if (hoveredItem.type === 'ship') {
          const ship = fleet.find(s => s.id === hoveredItem.id);
          if (ship) {
            ctx.fillText(`Ship: ${ship.name}`, 20, height - 40);
            ctx.fillText(`Status: ${ship.status}`, 20, height - 25);
          }
        } else {
          const port = ports.find(p => p.id === hoveredItem.id);
          if (port) {
            ctx.fillText(`Port: ${port.name}`, 20, height - 40);
            ctx.fillText(`Country: ${port.country}`, 20, height - 25);
          }
        }
      }
    };
    
    // Animation loop
    const animate = () => {
      render();
      requestAnimationFrame(animate);
    };
    animate();
    
  }, [fleet, ports, selectedShipId, selectedPortId, hoveredItem]);
  
  const drawContinents = (ctx: CanvasRenderingContext2D, width: number, height: number) => {
    // Save context state
    ctx.save();
    
    // Set up common styles for land
    const landGradient = ctx.createLinearGradient(0, 0, 0, height);
    landGradient.addColorStop(0, '#8B7355'); // Light brown
    landGradient.addColorStop(0.3, '#7A6449'); // Medium brown
    landGradient.addColorStop(0.5, '#6B5637'); // Darker brown
    landGradient.addColorStop(0.7, '#7A6449'); // Medium brown
    landGradient.addColorStop(1, '#8B7355'); // Light brown
    
    ctx.fillStyle = landGradient;
    ctx.strokeStyle = 'rgba(0, 0, 0, 0.2)';
    ctx.lineWidth = 0.5;
    
    // Alaska
    ctx.beginPath();
    ctx.moveTo(width * 0.02, height * 0.15);
    ctx.lineTo(width * 0.08, height * 0.12);
    ctx.lineTo(width * 0.12, height * 0.15);
    ctx.lineTo(width * 0.1, height * 0.18);
    ctx.lineTo(width * 0.05, height * 0.17);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    
    // Canada and USA
    ctx.beginPath();
    ctx.moveTo(width * 0.08, height * 0.18);
    ctx.quadraticCurveTo(width * 0.15, height * 0.12, width * 0.28, height * 0.15);
    ctx.lineTo(width * 0.32, height * 0.18);
    ctx.lineTo(width * 0.3, height * 0.25);
    ctx.lineTo(width * 0.28, height * 0.32);
    ctx.lineTo(width * 0.24, height * 0.35);
    ctx.quadraticCurveTo(width * 0.2, height * 0.38, width * 0.15, height * 0.37);
    ctx.lineTo(width * 0.12, height * 0.33);
    ctx.lineTo(width * 0.1, height * 0.28);
    ctx.quadraticCurveTo(width * 0.08, height * 0.22, width * 0.08, height * 0.18);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    
    // Mexico and Central America
    ctx.beginPath();
    ctx.moveTo(width * 0.15, height * 0.37);
    ctx.lineTo(width * 0.18, height * 0.42);
    ctx.quadraticCurveTo(width * 0.2, height * 0.46, width * 0.22, height * 0.5);
    ctx.lineTo(width * 0.2, height * 0.48);
    ctx.lineTo(width * 0.16, height * 0.43);
    ctx.lineTo(width * 0.14, height * 0.39);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    
    // Greenland
    ctx.fillStyle = '#d4e4ec';
    ctx.beginPath();
    ctx.moveTo(width * 0.32, height * 0.05);
    ctx.quadraticCurveTo(width * 0.35, height * 0.08, width * 0.34, height * 0.12);
    ctx.lineTo(width * 0.32, height * 0.14);
    ctx.lineTo(width * 0.3, height * 0.12);
    ctx.quadraticCurveTo(width * 0.3, height * 0.08, width * 0.32, height * 0.05);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    
    // South America
    ctx.fillStyle = landGradient;
    ctx.beginPath();
    ctx.moveTo(width * 0.22, height * 0.5);
    ctx.quadraticCurveTo(width * 0.26, height * 0.52, width * 0.28, height * 0.56);
    ctx.lineTo(width * 0.26, height * 0.65);
    ctx.quadraticCurveTo(width * 0.24, height * 0.72, width * 0.22, height * 0.82);
    ctx.lineTo(width * 0.2, height * 0.85);
    ctx.quadraticCurveTo(width * 0.18, height * 0.82, width * 0.18, height * 0.75);
    ctx.lineTo(width * 0.17, height * 0.65);
    ctx.lineTo(width * 0.18, height * 0.58);
    ctx.quadraticCurveTo(width * 0.2, height * 0.52, width * 0.22, height * 0.5);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    
    // Europe
    ctx.beginPath();
    ctx.moveTo(width * 0.45, height * 0.2);
    ctx.lineTo(width * 0.48, height * 0.18);
    ctx.lineTo(width * 0.52, height * 0.2);
    ctx.lineTo(width * 0.54, height * 0.25);
    ctx.lineTo(width * 0.52, height * 0.28);
    ctx.lineTo(width * 0.48, height * 0.27);
    ctx.lineTo(width * 0.46, height * 0.25);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    
    // Scandinavia
    ctx.beginPath();
    ctx.moveTo(width * 0.5, height * 0.12);
    ctx.lineTo(width * 0.52, height * 0.1);
    ctx.lineTo(width * 0.54, height * 0.15);
    ctx.lineTo(width * 0.52, height * 0.18);
    ctx.lineTo(width * 0.5, height * 0.16);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    
    // British Isles
    ctx.beginPath();
    ctx.moveTo(width * 0.44, height * 0.18);
    ctx.lineTo(width * 0.45, height * 0.16);
    ctx.lineTo(width * 0.46, height * 0.18);
    ctx.lineTo(width * 0.45, height * 0.2);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    
    // Africa
    ctx.beginPath();
    ctx.moveTo(width * 0.46, height * 0.3);
    ctx.quadraticCurveTo(width * 0.5, height * 0.32, width * 0.54, height * 0.35);
    ctx.lineTo(width * 0.56, height * 0.4);
    ctx.quadraticCurveTo(width * 0.57, height * 0.5, width * 0.55, height * 0.6);
    ctx.quadraticCurveTo(width * 0.52, height * 0.68, width * 0.48, height * 0.7);
    ctx.lineTo(width * 0.45, height * 0.68);
    ctx.quadraticCurveTo(width * 0.43, height * 0.6, width * 0.43, height * 0.5);
    ctx.lineTo(width * 0.44, height * 0.4);
    ctx.quadraticCurveTo(width * 0.45, height * 0.35, width * 0.46, height * 0.3);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    
    // Madagascar
    ctx.beginPath();
    ctx.moveTo(width * 0.57, height * 0.6);
    ctx.lineTo(width * 0.58, height * 0.62);
    ctx.lineTo(width * 0.57, height * 0.65);
    ctx.lineTo(width * 0.56, height * 0.63);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    
    // Middle East
    ctx.beginPath();
    ctx.moveTo(width * 0.54, height * 0.28);
    ctx.lineTo(width * 0.58, height * 0.3);
    ctx.lineTo(width * 0.6, height * 0.35);
    ctx.lineTo(width * 0.58, height * 0.37);
    ctx.lineTo(width * 0.55, height * 0.35);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    
    // Asia - Main landmass
    ctx.beginPath();
    ctx.moveTo(width * 0.54, height * 0.15);
    ctx.lineTo(width * 0.65, height * 0.12);
    ctx.quadraticCurveTo(width * 0.75, height * 0.15, width * 0.85, height * 0.2);
    ctx.lineTo(width * 0.82, height * 0.28);
    ctx.lineTo(width * 0.78, height * 0.32);
    ctx.lineTo(width * 0.72, height * 0.35);
    ctx.lineTo(width * 0.65, height * 0.38);
    ctx.lineTo(width * 0.6, height * 0.35);
    ctx.lineTo(width * 0.58, height * 0.3);
    ctx.quadraticCurveTo(width * 0.55, height * 0.22, width * 0.54, height * 0.15);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    
    // India
    ctx.beginPath();
    ctx.moveTo(width * 0.62, height * 0.38);
    ctx.lineTo(width * 0.65, height * 0.42);
    ctx.quadraticCurveTo(width * 0.66, height * 0.48, width * 0.64, height * 0.52);
    ctx.lineTo(width * 0.62, height * 0.5);
    ctx.lineTo(width * 0.61, height * 0.45);
    ctx.lineTo(width * 0.6, height * 0.4);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    
    // Southeast Asia
    ctx.beginPath();
    ctx.moveTo(width * 0.68, height * 0.4);
    ctx.lineTo(width * 0.72, height * 0.45);
    ctx.lineTo(width * 0.7, height * 0.5);
    ctx.lineTo(width * 0.68, height * 0.48);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    
    // Indonesia
    ctx.beginPath();
    // Java
    ctx.moveTo(width * 0.72, height * 0.55);
    ctx.lineTo(width * 0.76, height * 0.56);
    ctx.lineTo(width * 0.74, height * 0.57);
    ctx.lineTo(width * 0.71, height * 0.56);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    
    // Sumatra
    ctx.beginPath();
    ctx.moveTo(width * 0.68, height * 0.52);
    ctx.lineTo(width * 0.7, height * 0.54);
    ctx.lineTo(width * 0.69, height * 0.56);
    ctx.lineTo(width * 0.67, height * 0.54);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    
    // Borneo
    ctx.beginPath();
    ctx.moveTo(width * 0.74, height * 0.52);
    ctx.lineTo(width * 0.76, height * 0.53);
    ctx.lineTo(width * 0.75, height * 0.55);
    ctx.lineTo(width * 0.73, height * 0.54);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    
    // Philippines
    ctx.beginPath();
    ctx.moveTo(width * 0.76, height * 0.44);
    ctx.lineTo(width * 0.77, height * 0.48);
    ctx.lineTo(width * 0.76, height * 0.48);
    ctx.lineTo(width * 0.75, height * 0.45);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    
    // Japan
    ctx.beginPath();
    ctx.moveTo(width * 0.82, height * 0.28);
    ctx.quadraticCurveTo(width * 0.84, height * 0.3, width * 0.83, height * 0.33);
    ctx.lineTo(width * 0.82, height * 0.32);
    ctx.lineTo(width * 0.81, height * 0.3);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    
    // Australia
    ctx.beginPath();
    ctx.moveTo(width * 0.72, height * 0.65);
    ctx.quadraticCurveTo(width * 0.78, height * 0.64, width * 0.82, height * 0.68);
    ctx.quadraticCurveTo(width * 0.82, height * 0.72, width * 0.78, height * 0.74);
    ctx.quadraticCurveTo(width * 0.72, height * 0.74, width * 0.7, height * 0.7);
    ctx.quadraticCurveTo(width * 0.7, height * 0.66, width * 0.72, height * 0.65);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    
    // Tasmania
    ctx.beginPath();
    ctx.moveTo(width * 0.78, height * 0.75);
    ctx.lineTo(width * 0.79, height * 0.76);
    ctx.lineTo(width * 0.78, height * 0.77);
    ctx.lineTo(width * 0.77, height * 0.76);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    
    // New Zealand
    ctx.beginPath();
    ctx.moveTo(width * 0.86, height * 0.72);
    ctx.lineTo(width * 0.87, height * 0.75);
    ctx.lineTo(width * 0.86, height * 0.76);
    ctx.lineTo(width * 0.85, height * 0.74);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    
    // Antarctica
    ctx.fillStyle = '#e0e8ec';
    ctx.fillRect(0, height * 0.92, width, height * 0.08);
    
    // Restore context state
    ctx.restore();
  };
  
  const drawShippingLanes = (ctx: CanvasRenderingContext2D, width: number, height: number) => {
    ctx.strokeStyle = 'rgba(59, 130, 246, 0.2)';
    ctx.lineWidth = 1;
    ctx.setLineDash([10, 5]);
    
    // Trans-Atlantic
    ctx.beginPath();
    ctx.moveTo(width * 0.3, height * 0.3);
    ctx.quadraticCurveTo(width * 0.4, height * 0.25, width * 0.5, height * 0.3);
    ctx.stroke();
    
    // Trans-Pacific
    ctx.beginPath();
    ctx.moveTo(width * 0.7, height * 0.35);
    ctx.quadraticCurveTo(width * 0.85, height * 0.3, width * 0.25, height * 0.3);
    ctx.stroke();
    
    // Suez route
    ctx.beginPath();
    ctx.moveTo(width * 0.5, height * 0.3);
    ctx.lineTo(width * 0.53, height * 0.35);
    ctx.lineTo(width * 0.7, height * 0.35);
    ctx.stroke();
    
    ctx.setLineDash([]);
  };
  
  const handleCanvasClick = (e: React.MouseEvent<HTMLCanvasElement>) => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    
    const rect = canvas.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    
    // Check if clicked on a ship
    for (const ship of fleet) {
      const { lat, lng } = positionToLatLng(ship.position);
      const pos = latLngToXY(lat, lng, canvas.width, canvas.height);
      
      if (Math.abs(pos.x - x) < 10 && Math.abs(pos.y - y) < 10) {
        selectShip(ship.id);
        return;
      }
    }
    
    // Check if clicked on a port
    for (const port of ports) {
      const { lat, lng } = positionToLatLng(port.position);
      const pos = latLngToXY(lat, lng, canvas.width, canvas.height);
      
      if (Math.abs(pos.x - x) < 10 && Math.abs(pos.y - y) < 10) {
        selectPort(port.id);
        return;
      }
    }
    
    // Deselect if clicked on empty space
    selectShip(null);
    selectPort(null);
  };
  
  const handleCanvasMove = (e: React.MouseEvent<HTMLCanvasElement>) => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    
    const rect = canvas.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    
    // Check hover on ships
    for (const ship of fleet) {
      const { lat, lng } = positionToLatLng(ship.position);
      const pos = latLngToXY(lat, lng, canvas.width, canvas.height);
      
      if (Math.abs(pos.x - x) < 10 && Math.abs(pos.y - y) < 10) {
        setHoveredItem({ type: 'ship', id: ship.id });
        canvas.style.cursor = 'pointer';
        return;
      }
    }
    
    // Check hover on ports
    for (const port of ports) {
      const { lat, lng } = positionToLatLng(port.position);
      const pos = latLngToXY(lat, lng, canvas.width, canvas.height);
      
      if (Math.abs(pos.x - x) < 10 && Math.abs(pos.y - y) < 10) {
        setHoveredItem({ type: 'port', id: port.id });
        canvas.style.cursor = 'pointer';
        return;
      }
    }
    
    setHoveredItem(null);
    canvas.style.cursor = 'default';
  };
  
  useEffect(() => {
    const handleResize = () => {
      const canvas = canvasRef.current;
      if (canvas) {
        canvas.width = canvas.offsetWidth;
        canvas.height = canvas.offsetHeight;
      }
    };
    
    handleResize();
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);
  
  return (
    <canvas
      ref={canvasRef}
      className="map-2d"
      onClick={handleCanvasClick}
      onMouseMove={handleCanvasMove}
    />
  );
};