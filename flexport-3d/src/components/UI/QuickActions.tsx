import React from 'react';
import { useGameStore } from '../../store/gameStore';
import { ShipType } from '../../types/game.types';
import './QuickActions.css';

export const QuickActions: React.FC = () => {
  const { 
    money, 
    fleet, 
    ports,
    purchaseShip,
    pauseGame,
    resumeGame,
    isPaused
  } = useGameStore();

  const canAffordShip = (type: ShipType) => {
    const costs = {
      [ShipType.CONTAINER]: 20000000,
      [ShipType.BULK]: 15000000,
      [ShipType.TANKER]: 25000000,
      [ShipType.CARGO_PLANE]: 50000000,
    };
    return money >= costs[type];
  };

  const handlePurchaseShip = (type: ShipType) => {
    const shipNames = {
      [ShipType.CONTAINER]: `Container Ship ${fleet.length + 1}`,
      [ShipType.BULK]: `Bulk Carrier ${fleet.length + 1}`,
      [ShipType.TANKER]: `Oil Tanker ${fleet.length + 1}`,
      [ShipType.CARGO_PLANE]: `Cargo Plane ${fleet.length + 1}`,
    };
    
    purchaseShip(type, shipNames[type]);
  };

  return (
    <div className="quick-actions">
      <h3>Quick Actions</h3>
      
      <div className="action-group">
        <h4>Purchase Ships</h4>
        <div className="ship-buttons">
          <button
            onClick={() => handlePurchaseShip(ShipType.CONTAINER)}
            disabled={!canAffordShip(ShipType.CONTAINER)}
            title="Container Ship - $20M"
          >
            🚢 Container
          </button>
          <button
            onClick={() => handlePurchaseShip(ShipType.BULK)}
            disabled={!canAffordShip(ShipType.BULK)}
            title="Bulk Carrier - $15M"
          >
            🚢 Bulk
          </button>
          <button
            onClick={() => handlePurchaseShip(ShipType.TANKER)}
            disabled={!canAffordShip(ShipType.TANKER)}
            title="Oil Tanker - $25M"
          >
            🛢️ Tanker
          </button>
          <button
            onClick={() => handlePurchaseShip(ShipType.CARGO_PLANE)}
            disabled={!canAffordShip(ShipType.CARGO_PLANE)}
            title="Cargo Plane - $50M"
          >
            ✈️ Plane
          </button>
        </div>
      </div>

      <div className="action-group">
        <h4>Game Control</h4>
        <button 
          className="pause-button"
          onClick={isPaused ? resumeGame : pauseGame}
        >
          {isPaused ? '▶️ Resume' : '⏸️ Pause'}
        </button>
      </div>
    </div>
  );
};