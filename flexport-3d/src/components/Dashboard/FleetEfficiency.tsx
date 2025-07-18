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