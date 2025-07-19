// @ts-nocheck
import React from 'react';
import { useGameStore } from '../../store/gameStore';
import { Ship } from '../../types/game.types';
import './MobileFleetView.css';

interface MobileFleetViewProps {
  onShipSelect?: (ship: Ship) => void;
  onClose?: () => void;
}

export const MobileFleetView: React.FC<MobileFleetViewProps> = ({ onShipSelect, onClose }) => {
  const { fleet, money, selectedShipId, selectShip, ports } = useGameStore();
  const playerShips = fleet;

  const handleShipClick = (ship: Ship) => {
    selectShip(ship.id);
    onShipSelect?.(ship);
  };

  const getShipStatus = (ship: Ship) => {
    if (ship.status === 'SAILING') {
      return { text: 'In Transit', color: '#4ade80' };
    } else if (ship.status === 'LOADING' || ship.status === 'UNLOADING') {
      return { text: ship.status === 'LOADING' ? 'Loading' : 'Unloading', color: '#60a5fa' };
    } else {
      return { text: 'Idle', color: '#94a3b8' };
    }
  };

  const getShipDestination = (ship: Ship) => {
    if (ship.destination) {
      return ship.destination.name;
    }
    const currentPort = ports.find(p => p.id === ship.currentPortId);
    return currentPort?.name || 'At Sea';
  };

  return (
    <div className="mobile-fleet-view">
      <div className="mobile-header">
        <h2>Your Fleet</h2>
        <button className="mobile-close-btn" onClick={onClose}>×</button>
      </div>
      
      <div className="fleet-summary">
        <div className="summary-item">
          <span className="summary-label">Ships</span>
          <span className="summary-value">{playerShips.length}</span>
        </div>
        <div className="summary-item">
          <span className="summary-label">Balance</span>
          <span className="summary-value">${money.toLocaleString()}</span>
        </div>
      </div>

      <div className="ship-list">
        {playerShips.map(ship => {
          const status = getShipStatus(ship);
          const isSelected = ship.id === selectedShipId;
          
          return (
            <div 
              key={ship.id} 
              className={`ship-card ${isSelected ? 'selected' : ''}`}
              onClick={() => handleShipClick(ship)}
            >
              <div className="ship-header">
                <h3>{ship.name}</h3>
                <span className="ship-status" style={{ color: status.color }}>
                  {status.text}
                </span>
              </div>
              
              <div className="ship-details">
                <div className="detail-row">
                  <span className="detail-label">Capacity:</span>
                  <span className="detail-value">{ship.cargo.length * 1000}/{ship.capacity} TEU</span>
                </div>
                <div className="detail-row">
                  <span className="detail-label">Speed:</span>
                  <span className="detail-value">{(ship.speed * 100).toFixed(0)} knots</span>
                </div>
                <div className="detail-row">
                  <span className="detail-label">Location:</span>
                  <span className="detail-value">{getShipDestination(ship)}</span>
                </div>
              </div>

              {ship.cargo.length > 0 && (
                <div className="cargo-progress">
                  <div className="progress-bar">
                    <div 
                      className="progress-fill" 
                      style={{ width: `${(ship.cargo.length * 1000 / ship.capacity) * 100}%` }}
                    />
                  </div>
                  <span className="cargo-text">
                    {Math.round((ship.cargo.length * 1000 / ship.capacity) * 100)}% Full
                  </span>
                </div>
              )}
            </div>
          );
        })}
      </div>

      {playerShips.length === 0 && (
        <div className="empty-state">
          <p>No ships in your fleet yet!</p>
          <p className="empty-hint">Purchase ships to start building your empire.</p>
        </div>
      )}
    </div>
  );
};