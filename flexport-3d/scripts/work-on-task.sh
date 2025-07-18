#!/bin/bash

TASK=$1

case $TASK in
  minimap)
    echo "🗺️  Working on Mini-map and Route Visualization..."
    echo "Creating MiniMap component..."
    
    # Create MiniMap component
    cat > /app/src/components/MiniMap.tsx << 'EOF'
import React, { useRef, useEffect, useState } from 'react';
import { useGameStore } from '../store/gameStore';
import { ShipType } from '../types/game.types';
import './MiniMap.css';

export const MiniMap: React.FC = () => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [zoom, setZoom] = useState(1);
  const { ports, fleet, selectedShipId, selectedPortId, selectShip, selectPort } = useGameStore();
  
  const worldBounds = {
    minX: -100,
    maxX: 100,
    minZ: -50,
    maxZ: 50
  };
  
  const mapSize = { width: 300, height: 200 };
  
  const worldToMap = (worldX: number, worldZ: number) => {
    const x = ((worldX - worldBounds.minX) / (worldBounds.maxX - worldBounds.minX)) * mapSize.width;
    const y = ((worldZ - worldBounds.minZ) / (worldBounds.maxZ - worldBounds.minZ)) * mapSize.height;
    return { x: x * zoom, y: y * zoom };
  };
  
  const mapToWorld = (mapX: number, mapY: number) => {
    const worldX = (mapX / (mapSize.width * zoom)) * (worldBounds.maxX - worldBounds.minX) + worldBounds.minX;
    const worldZ = (mapY / (mapSize.height * zoom)) * (worldBounds.maxZ - worldBounds.minZ) + worldBounds.minZ;
    return { x: worldX, z: worldZ };
  };
  
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
  }, [fleet, ports, selectedShipId, selectedPortId, zoom]);
  
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
EOF

    # Create MiniMap CSS
    cat > /app/src/components/MiniMap.css << 'EOF'
.minimap-container {
  position: fixed;
  bottom: 20px;
  right: 20px;
  background: rgba(0, 10, 20, 0.9);
  border: 2px solid rgba(255, 255, 255, 0.2);
  border-radius: 8px;
  padding: 10px;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.5);
  z-index: 100;
}

.minimap-header {
  color: #ffffff;
  font-size: 14px;
  font-weight: bold;
  margin-bottom: 8px;
  text-align: center;
  text-transform: uppercase;
  letter-spacing: 1px;
}

.minimap-canvas {
  border: 1px solid rgba(255, 255, 255, 0.3);
  border-radius: 4px;
  cursor: pointer;
  display: block;
}

.minimap-controls {
  display: flex;
  justify-content: center;
  align-items: center;
  gap: 10px;
  margin-top: 8px;
}

.minimap-controls button {
  width: 24px;
  height: 24px;
  border: 1px solid rgba(255, 255, 255, 0.3);
  background: rgba(255, 255, 255, 0.1);
  color: #ffffff;
  border-radius: 4px;
  cursor: pointer;
  font-size: 16px;
  line-height: 1;
  transition: all 0.2s;
}

.minimap-controls button:hover {
  background: rgba(255, 255, 255, 0.2);
  border-color: rgba(255, 255, 255, 0.5);
}

.minimap-controls span {
  color: #ffffff;
  font-size: 12px;
  min-width: 40px;
  text-align: center;
}
EOF

    echo "✅ Mini-map component created successfully!"
    ;;
    
  effects)
    echo "🌟 Working on Visual Effects..."
    echo "Creating Weather, DayNight, and ShipTrail components..."
    
    # Create Weather component
    cat > /app/src/components/Weather.tsx << 'EOF'
import React, { useRef, useMemo } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';
import { useGameStore } from '../store/gameStore';

export enum WeatherState {
  CLEAR = 'CLEAR',
  CLOUDY = 'CLOUDY',
  RAINY = 'RAINY',
  STORMY = 'STORMY'
}

interface WeatherProps {
  weatherState: WeatherState;
}

export const Weather: React.FC<WeatherProps> = ({ weatherState }) => {
  const rainRef = useRef<THREE.Points>(null);
  
  const rainGeometry = useMemo(() => {
    const geometry = new THREE.BufferGeometry();
    const particleCount = weatherState === WeatherState.STORMY ? 5000 : 2000;
    const positions = new Float32Array(particleCount * 3);
    const velocities = new Float32Array(particleCount);
    
    for (let i = 0; i < particleCount; i++) {
      positions[i * 3] = (Math.random() - 0.5) * 200;
      positions[i * 3 + 1] = Math.random() * 100;
      positions[i * 3 + 2] = (Math.random() - 0.5) * 200;
      velocities[i] = 0.5 + Math.random() * 0.5;
    }
    
    geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    geometry.setAttribute('velocity', new THREE.BufferAttribute(velocities, 1));
    
    return geometry;
  }, [weatherState]);
  
  const rainMaterial = useMemo(() => {
    return new THREE.PointsMaterial({
      color: 0xaaaaaa,
      size: weatherState === WeatherState.STORMY ? 0.3 : 0.2,
      transparent: true,
      opacity: weatherState === WeatherState.STORMY ? 0.8 : 0.6,
      blending: THREE.AdditiveBlending,
    });
  }, [weatherState]);
  
  useFrame((state, delta) => {
    if (!rainRef.current || (weatherState !== WeatherState.RAINY && weatherState !== WeatherState.STORMY)) return;
    
    const positions = rainRef.current.geometry.attributes.position;
    const velocities = rainRef.current.geometry.attributes.velocity;
    
    for (let i = 0; i < positions.count; i++) {
      positions.array[i * 3 + 1] -= velocities.array[i] * delta * 50;
      
      if (positions.array[i * 3 + 1] < -10) {
        positions.array[i * 3 + 1] = 100;
        positions.array[i * 3] = (Math.random() - 0.5) * 200;
        positions.array[i * 3 + 2] = (Math.random() - 0.5) * 200;
      }
    }
    
    positions.needsUpdate = true;
  });
  
  if (weatherState === WeatherState.CLEAR || weatherState === WeatherState.CLOUDY) {
    return null;
  }
  
  return (
    <>
      <points ref={rainRef} geometry={rainGeometry} material={rainMaterial} />
      {weatherState === WeatherState.STORMY && (
        <fog attach="fog" args={['#333333', 10, 150]} />
      )}
    </>
  );
};
EOF

    # Create DayNightCycle component
    cat > /app/src/components/DayNightCycle.tsx << 'EOF'
import React, { useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';

interface DayNightCycleProps {
  timeOfDay: number; // 0-24 hours
}

export const DayNightCycle: React.FC<DayNightCycleProps> = ({ timeOfDay }) => {
  const sunRef = useRef<THREE.DirectionalLight>(null);
  const moonRef = useRef<THREE.PointLight>(null);
  const ambientRef = useRef<THREE.AmbientLight>(null);
  
  useFrame(() => {
    if (!sunRef.current || !moonRef.current || !ambientRef.current) return;
    
    // Calculate sun position
    const sunAngle = (timeOfDay / 24) * Math.PI * 2 - Math.PI / 2;
    const sunHeight = Math.sin(sunAngle) * 50;
    const sunDistance = Math.cos(sunAngle) * 50;
    
    sunRef.current.position.set(sunDistance, Math.max(0, sunHeight), 25);
    
    // Calculate moon position (opposite of sun)
    moonRef.current.position.set(-sunDistance, Math.max(0, -sunHeight), 25);
    
    // Adjust light intensities based on time
    const dayIntensity = Math.max(0, Math.sin(sunAngle));
    const nightIntensity = Math.max(0, -Math.sin(sunAngle));
    
    sunRef.current.intensity = dayIntensity;
    moonRef.current.intensity = nightIntensity * 0.3;
    
    // Adjust ambient light
    ambientRef.current.intensity = 0.3 + dayIntensity * 0.2;
    
    // Adjust colors
    const sunColor = new THREE.Color();
    if (timeOfDay >= 6 && timeOfDay <= 7) {
      // Sunrise
      sunColor.setHSL(30 / 360, 1, 0.5);
    } else if (timeOfDay >= 17 && timeOfDay <= 19) {
      // Sunset
      sunColor.setHSL(15 / 360, 1, 0.5);
    } else if (timeOfDay >= 8 && timeOfDay <= 16) {
      // Day
      sunColor.setHSL(60 / 360, 0.5, 1);
    } else {
      // Night
      sunColor.setHSL(220 / 360, 0.3, 0.7);
    }
    
    sunRef.current.color = sunColor;
    ambientRef.current.color = sunColor;
  });
  
  return (
    <>
      <ambientLight ref={ambientRef} intensity={0.5} />
      <directionalLight
        ref={sunRef}
        castShadow
        shadow-mapSize={[2048, 2048]}
        shadow-camera-far={150}
        shadow-camera-left={-100}
        shadow-camera-right={100}
        shadow-camera-top={100}
        shadow-camera-bottom={-100}
      />
      <pointLight ref={moonRef} color="#8888ff" />
      
      {/* Sun sphere */}
      <mesh position={[50, 30, 25]}>
        <sphereGeometry args={[2, 16, 16]} />
        <meshBasicMaterial color="#ffff00" emissive="#ffff00" emissiveIntensity={2} />
      </mesh>
      
      {/* Moon sphere */}
      <mesh position={[-50, 30, 25]}>
        <sphereGeometry args={[1.5, 16, 16]} />
        <meshBasicMaterial color="#ffffff" emissive="#8888ff" emissiveIntensity={0.5} />
      </mesh>
    </>
  );
};
EOF

    # Create ShipTrail component
    cat > /app/src/components/ShipTrail.tsx << 'EOF'
import React, { useRef, useMemo } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';

interface ShipTrailProps {
  shipPosition: THREE.Vector3;
  isMoving: boolean;
}

export const ShipTrail: React.FC<ShipTrailProps> = ({ shipPosition, isMoving }) => {
  const trailRef = useRef<THREE.Mesh>(null);
  const trailPositions = useRef<THREE.Vector3[]>([]);
  const maxTrailLength = 50;
  
  const trailGeometry = useMemo(() => {
    const geometry = new THREE.BufferGeometry();
    const positions = new Float32Array(maxTrailLength * 6 * 3); // 2 triangles per segment
    geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    
    const uvs = new Float32Array(maxTrailLength * 6 * 2);
    geometry.setAttribute('uv', new THREE.BufferAttribute(uvs, 2));
    
    return geometry;
  }, []);
  
  const trailMaterial = useMemo(() => {
    return new THREE.ShaderMaterial({
      transparent: true,
      side: THREE.DoubleSide,
      uniforms: {
        time: { value: 0 },
      },
      vertexShader: `
        varying vec2 vUv;
        void main() {
          vUv = uv;
          gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
        }
      `,
      fragmentShader: `
        uniform float time;
        varying vec2 vUv;
        void main() {
          float foam = sin(vUv.x * 10.0 + time * 2.0) * 0.5 + 0.5;
          float alpha = (1.0 - vUv.x) * 0.6 * foam;
          gl_FragColor = vec4(1.0, 1.0, 1.0, alpha);
        }
      `,
    });
  }, []);
  
  useFrame((state, delta) => {
    if (!trailRef.current || !isMoving) return;
    
    // Update trail positions
    trailPositions.current.unshift(shipPosition.clone());
    if (trailPositions.current.length > maxTrailLength) {
      trailPositions.current.pop();
    }
    
    // Update geometry
    const positions = trailRef.current.geometry.attributes.position;
    const uvs = trailRef.current.geometry.attributes.uv;
    
    for (let i = 0; i < trailPositions.current.length - 1; i++) {
      const current = trailPositions.current[i];
      const next = trailPositions.current[i + 1];
      
      const direction = new THREE.Vector3().subVectors(next, current).normalize();
      const perpendicular = new THREE.Vector3(-direction.z, 0, direction.x);
      
      const width = 2 * (1 - i / trailPositions.current.length);
      
      const v1 = current.clone().add(perpendicular.clone().multiplyScalar(width));
      const v2 = current.clone().sub(perpendicular.clone().multiplyScalar(width));
      const v3 = next.clone().add(perpendicular.clone().multiplyScalar(width));
      const v4 = next.clone().sub(perpendicular.clone().multiplyScalar(width));
      
      const index = i * 6;
      
      // First triangle
      positions.setXYZ(index, v1.x, 0.1, v1.z);
      positions.setXYZ(index + 1, v2.x, 0.1, v2.z);
      positions.setXYZ(index + 2, v3.x, 0.1, v3.z);
      
      // Second triangle
      positions.setXYZ(index + 3, v2.x, 0.1, v2.z);
      positions.setXYZ(index + 4, v4.x, 0.1, v4.z);
      positions.setXYZ(index + 5, v3.x, 0.1, v3.z);
      
      // UVs
      const u = i / trailPositions.current.length;
      uvs.setXY(index, u, 0);
      uvs.setXY(index + 1, u, 1);
      uvs.setXY(index + 2, u + 1 / trailPositions.current.length, 0);
      uvs.setXY(index + 3, u, 1);
      uvs.setXY(index + 4, u + 1 / trailPositions.current.length, 1);
      uvs.setXY(index + 5, u + 1 / trailPositions.current.length, 0);
    }
    
    positions.needsUpdate = true;
    uvs.needsUpdate = true;
    
    // Update time uniform
    trailMaterial.uniforms.time.value = state.clock.elapsedTime;
  });
  
  return <mesh ref={trailRef} geometry={trailGeometry} material={trailMaterial} />;
};
EOF

    echo "✅ Visual effects components created successfully!"
    ;;
    
  ui)
    echo "📊 Working on UI Polish and Dashboard..."
    echo "Creating Dashboard and Notification components..."
    
    # Create Dashboard directory
    mkdir -p /app/src/components/Dashboard
    
    # Create FleetEfficiency component
    cat > /app/src/components/Dashboard/FleetEfficiency.tsx << 'EOF'
import React, { useMemo } from 'react';
import { useSpring, animated } from '@react-spring/web';
import { useGameStore } from '../../store/gameStore';
import { ShipStatus } from '../../types/game.types';
import './Dashboard.css';

export const FleetEfficiency: React.FC = () => {
  const { fleet, contracts } = useGameStore();
  
  const stats = useMemo(() => {
    const activeShips = fleet.filter(ship => ship.status !== ShipStatus.IDLE).length;
    const efficiency = fleet.length > 0 ? (activeShips / fleet.length) * 100 : 0;
    
    const activeContracts = contracts.filter(c => c.status === 'ACTIVE').length;
    const avgDeliveryTime = 48; // Mock data - would calculate from actual deliveries
    
    const totalCapacity = fleet.reduce((sum, ship) => sum + ship.capacity, 0);
    const usedCapacity = fleet.reduce((sum, ship) => sum + ship.cargo.length, 0);
    const capacityUtilization = totalCapacity > 0 ? (usedCapacity / totalCapacity) * 100 : 0;
    
    return {
      efficiency,
      activeShips,
      totalShips: fleet.length,
      activeContracts,
      avgDeliveryTime,
      capacityUtilization
    };
  }, [fleet, contracts]);
  
  const efficiencySpring = useSpring({
    number: stats.efficiency,
    from: { number: 0 }
  });
  
  const capacitySpring = useSpring({
    number: stats.capacityUtilization,
    from: { number: 0 }
  });
  
  return (
    <div className="fleet-efficiency">
      <h3>Fleet Performance</h3>
      
      <div className="efficiency-grid">
        <div className="stat-card">
          <div className="stat-label">Fleet Efficiency</div>
          <animated.div className="stat-value large">
            {efficiencySpring.number.to(n => `${n.toFixed(1)}%`)}
          </animated.div>
          <div className="stat-detail">{stats.activeShips} of {stats.totalShips} ships active</div>
        </div>
        
        <div className="stat-card">
          <div className="stat-label">Capacity Utilization</div>
          <animated.div className="stat-value">
            {capacitySpring.number.to(n => `${n.toFixed(1)}%`)}
          </animated.div>
        </div>
        
        <div className="stat-card">
          <div className="stat-label">Active Contracts</div>
          <div className="stat-value">{stats.activeContracts}</div>
        </div>
        
        <div className="stat-card">
          <div className="stat-label">Avg Delivery Time</div>
          <div className="stat-value">{stats.avgDeliveryTime}h</div>
        </div>
      </div>
      
      <div className="efficiency-bar">
        <div 
          className="efficiency-fill"
          style={{ width: `${stats.efficiency}%` }}
        />
      </div>
    </div>
  );
};
EOF

    # Create ProfitTracker component
    cat > /app/src/components/Dashboard/ProfitTracker.tsx << 'EOF'
import React, { useState, useEffect } from 'react';
import { useSpring, animated } from '@react-spring/web';
import { useGameStore } from '../../store/gameStore';
import './Dashboard.css';

export const ProfitTracker: React.FC = () => {
  const { money } = useGameStore();
  const [previousMoney, setPreviousMoney] = useState(money);
  const [profitHistory, setProfitHistory] = useState<number[]>([]);
  
  const profit = money - previousMoney;
  const isProfitable = profit >= 0;
  
  useEffect(() => {
    const timer = setTimeout(() => {
      setPreviousMoney(money);
      setProfitHistory(prev => [...prev.slice(-19), profit].filter(p => p !== 0));
    }, 5000);
    
    return () => clearTimeout(timer);
  }, [money, profit]);
  
  const profitSpring = useSpring({
    number: Math.abs(profit),
    from: { number: 0 },
    config: { tension: 280, friction: 60 }
  });
  
  return (
    <div className="profit-tracker">
      <h3>Financial Performance</h3>
      
      <div className="profit-display">
        <div className="profit-label">Recent P&L</div>
        <animated.div 
          className={`profit-value ${isProfitable ? 'positive' : 'negative'}`}
        >
          {isProfitable ? '+' : '-'}$
          {profitSpring.number.to(n => n.toLocaleString('en-US', { maximumFractionDigits: 0 }))}
        </animated.div>
      </div>
      
      <div className="profit-chart">
        {profitHistory.map((value, index) => (
          <div
            key={index}
            className={`profit-bar ${value >= 0 ? 'positive' : 'negative'}`}
            style={{
              height: `${Math.abs(value) / 10000}px`,
              maxHeight: '40px'
            }}
          />
        ))}
      </div>
      
      <div className="profit-indicators">
        <div className="indicator">
          <span className="dot positive"></span>
          <span>Revenue</span>
        </div>
        <div className="indicator">
          <span className="dot negative"></span>
          <span>Expenses</span>
        </div>
      </div>
    </div>
  );
};
EOF

    # Create Dashboard CSS
    cat > /app/src/components/Dashboard/Dashboard.css << 'EOF'
.dashboard-container {
  position: fixed;
  top: 80px;
  left: 20px;
  width: 320px;
  background: rgba(0, 10, 20, 0.95);
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 8px;
  padding: 20px;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.5);
  z-index: 90;
  backdrop-filter: blur(10px);
}

.fleet-efficiency,
.profit-tracker {
  margin-bottom: 20px;
}

.fleet-efficiency h3,
.profit-tracker h3 {
  color: #ffffff;
  font-size: 16px;
  margin-bottom: 15px;
  text-transform: uppercase;
  letter-spacing: 1px;
}

.efficiency-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
  margin-bottom: 15px;
}

.stat-card {
  background: rgba(255, 255, 255, 0.05);
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 4px;
  padding: 10px;
  text-align: center;
}

.stat-label {
  color: rgba(255, 255, 255, 0.6);
  font-size: 11px;
  text-transform: uppercase;
  margin-bottom: 5px;
}

.stat-value {
  color: #ffffff;
  font-size: 20px;
  font-weight: bold;
}

.stat-value.large {
  font-size: 28px;
  color: #00ff88;
}

.stat-detail {
  color: rgba(255, 255, 255, 0.5);
  font-size: 10px;
  margin-top: 5px;
}

.efficiency-bar {
  width: 100%;
  height: 8px;
  background: rgba(255, 255, 255, 0.1);
  border-radius: 4px;
  overflow: hidden;
}

.efficiency-fill {
  height: 100%;
  background: linear-gradient(90deg, #00ff88, #00aa55);
  transition: width 0.5s ease;
}

.profit-display {
  text-align: center;
  margin-bottom: 15px;
}

.profit-label {
  color: rgba(255, 255, 255, 0.6);
  font-size: 12px;
  margin-bottom: 5px;
}

.profit-value {
  font-size: 24px;
  font-weight: bold;
}

.profit-value.positive {
  color: #00ff88;
}

.profit-value.negative {
  color: #ff4444;
}

.profit-chart {
  display: flex;
  align-items: flex-end;
  justify-content: center;
  height: 50px;
  gap: 2px;
  margin-bottom: 10px;
}

.profit-bar {
  width: 8px;
  transition: height 0.3s ease;
}

.profit-bar.positive {
  background: #00ff88;
}

.profit-bar.negative {
  background: #ff4444;
}

.profit-indicators {
  display: flex;
  justify-content: center;
  gap: 20px;
}

.indicator {
  display: flex;
  align-items: center;
  gap: 5px;
  font-size: 11px;
  color: rgba(255, 255, 255, 0.6);
}

.dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
}

.dot.positive {
  background: #00ff88;
}

.dot.negative {
  background: #ff4444;
}
EOF

    # Create NotificationSystem
    mkdir -p /app/src/components/Notifications
    cat > /app/src/components/Notifications/NotificationSystem.tsx << 'EOF'
import React, { useEffect } from 'react';
import { toast, ToastContainer } from 'react-toastify';
import { useGameStore } from '../../store/gameStore';
import 'react-toastify/dist/ReactToastify.css';
import './Toast.css';

export const NotificationSystem: React.FC = () => {
  const { fleet, contracts } = useGameStore();
  
  useEffect(() => {
    // Monitor ship arrivals
    const checkShipArrivals = () => {
      fleet.forEach(ship => {
        if (ship.status === 'IDLE' && ship.destination === null) {
          // Ship has just arrived
          toast.info(`🚢 ${ship.name} has arrived at destination`, {
            position: "bottom-left",
            autoClose: 3000,
          });
        }
      });
    };
    
    const interval = setInterval(checkShipArrivals, 2000);
    return () => clearInterval(interval);
  }, [fleet]);
  
  useEffect(() => {
    // Monitor contract completions
    contracts.forEach(contract => {
      if (contract.status === 'COMPLETED') {
        toast.success(`✅ Contract completed! Earned ${contract.value.toLocaleString()}`, {
          position: "bottom-left",
          autoClose: 5000,
        });
      }
    });
  }, [contracts]);
  
  return (
    <ToastContainer
      theme="dark"
      style={{
        fontSize: '14px'
      }}
    />
  );
};
EOF

    # Create QuickActions component
    cat > /app/src/components/UI/QuickActions.tsx << 'EOF'
import React from 'react';
import { useGameStore } from '../../store/gameStore';
import './QuickActions.css';

export const QuickActions: React.FC = () => {
  const { fleet, contracts, ports, assignShipToContract, moveShip } = useGameStore();
  
  const autoAssignShips = () => {
    const availableShips = fleet.filter(ship => 
      ship.status === 'IDLE' && !ship.assignedContract
    );
    
    const activeContracts = contracts.filter(c => 
      c.status === 'ACTIVE' && !fleet.some(s => s.assignedContract === c.id)
    );
    
    availableShips.forEach((ship, index) => {
      if (activeContracts[index]) {
        assignShipToContract(ship.id, activeContracts[index].id);
      }
    });
  };
  
  const recallIdleShips = () => {
    const homePort = ports.find(p => p.isPlayerOwned) || ports[0];
    fleet
      .filter(ship => ship.status === 'IDLE' && !ship.assignedContract)
      .forEach(ship => moveShip(ship.id, homePort));
  };
  
  return (
    <div className="quick-actions">
      <button 
        className="quick-action-btn"
        onClick={autoAssignShips}
        title="Auto-assign ships to contracts"
      >
        🤖 Auto Assign
      </button>
      <button 
        className="quick-action-btn"
        onClick={recallIdleShips}
        title="Recall all idle ships to home port"
      >
        🏠 Recall Ships
      </button>
    </div>
  );
};
EOF

    # Create QuickActions CSS
    cat > /app/src/components/UI/QuickActions.css << 'EOF'
.quick-actions {
  position: fixed;
  bottom: 20px;
  left: 50%;
  transform: translateX(-50%);
  display: flex;
  gap: 10px;
  z-index: 100;
}

.quick-action-btn {
  background: rgba(0, 20, 40, 0.9);
  border: 2px solid rgba(255, 255, 255, 0.3);
  color: #ffffff;
  padding: 10px 20px;
  border-radius: 20px;
  font-size: 14px;
  cursor: pointer;
  transition: all 0.3s ease;
  backdrop-filter: blur(10px);
}

.quick-action-btn:hover {
  background: rgba(0, 40, 80, 0.9);
  border-color: rgba(255, 255, 255, 0.5);
  transform: translateY(-2px);
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.5);
}

.quick-action-btn:active {
  transform: translateY(0);
}
EOF

    echo "✅ UI Dashboard components created successfully!"
    ;;
esac

# Keep container running for development
tail -f /dev/null
EOF