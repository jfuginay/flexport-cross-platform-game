// @ts-nocheck
import React from 'react';
import { useGameStore } from '../../store/gameStore';
import { ShipStatus } from '../../types/game.types';
import './ShipJourneyTracker.css';

export const ShipJourneyTracker: React.FC = () => {
  const { fleet, contracts } = useGameStore();
  
  const shipsOnMission = fleet.filter(ship => 
    ship.status !== ShipStatus.IDLE || (ship as any).assignedContract
  );

  const getShipStage = (ship: any) => {
    if (ship.status === ShipStatus.LOADING) return 'Loading Cargo';
    if (ship.status === ShipStatus.UNLOADING) return 'Unloading Cargo';
    if (ship.status === ShipStatus.SAILING) {
      if (ship.contractStage === 'pickup') return 'Sailing to Pickup';
      if (ship.contractStage === 'delivery') return 'Delivering Cargo';
      return 'In Transit';
    }
    return 'Idle';
  };

  const getShipProgress = (ship: any) => {
    if (ship.status === ShipStatus.LOADING || ship.status === ShipStatus.UNLOADING) {
      return 50; // Loading/unloading animations
    }
    if (ship.routeProgress !== undefined) {
      return ship.routeProgress * 100;
    }
    return 0;
  };

  if (shipsOnMission.length === 0) {
    return null;
  }

  return (
    <div className="ship-journey-tracker">
      <h3>🚢 Active Journeys</h3>
      {shipsOnMission.map(ship => {
        const contract = contracts.find(c => c.id === (ship as any).assignedContract);
        const stage = getShipStage(ship);
        const progress = getShipProgress(ship);
        
        return (
          <div key={ship.id} className="journey-card">
            <div className="journey-header">
              <span className="ship-name">{ship.name}</span>
              <span className={`ship-status ${ship.status.toLowerCase()}`}>
                {stage}
              </span>
            </div>
            
            {contract && (
              <div className="journey-route">
                <div className="route-info">
                  <span className="origin">{contract.origin.name}</span>
                  <span className="arrow">→</span>
                  <span className="destination">{contract.destination.name}</span>
                </div>
                <div className="cargo-info">
                  📦 {contract.cargo} ({contract.quantity} units)
                </div>
              </div>
            )}
            
            <div className="journey-progress">
              <div className="progress-bar">
                <div 
                  className="progress-fill"
                  style={{ width: `${progress}%` }}
                />
              </div>
              <div className="progress-stages">
                <div className={`stage ${(ship as any).contractStage !== 'delivery' ? 'active' : 'completed'}`}>
                  <div className="stage-dot" />
                  <span>Pickup</span>
                </div>
                <div className={`stage ${(ship as any).contractStage === 'delivery' ? 'active' : ''}`}>
                  <div className="stage-dot" />
                  <span>Delivery</span>
                </div>
              </div>
            </div>
            
            {ship.destination && (
              <div className="current-destination">
                📍 Heading to: {ship.destination.name}
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
};