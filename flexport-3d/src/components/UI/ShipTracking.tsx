// @ts-nocheck
import React from 'react';
import { useGameStore } from '../../store/gameStore';
import { ShipStatus } from '../../types/game.types';
import './ShipTracking.css';

export const ShipTracking: React.FC = () => {
  const { fleet, selectShip, selectedShipId } = useGameStore();
  
  const getStatusColor = (status: ShipStatus) => {
    switch (status) {
      case ShipStatus.SAILING:
        return '#10b981'; // Green
      case ShipStatus.LOADING:
      case ShipStatus.UNLOADING:
        return '#f59e0b'; // Yellow
      case ShipStatus.IDLE:
        return '#3b82f6'; // Blue
      case ShipStatus.MAINTENANCE:
        return '#ef4444'; // Red
      default:
        return '#6b7280'; // Gray
    }
  };
  
  const getStatusIcon = (status: ShipStatus) => {
    switch (status) {
      case ShipStatus.SAILING:
        return '⛵';
      case ShipStatus.LOADING:
        return '📦';
      case ShipStatus.UNLOADING:
        return '📤';
      case ShipStatus.IDLE:
        return '⚓';
      case ShipStatus.MAINTENANCE:
        return '🔧';
      default:
        return '🚢';
    }
  };

  return (
    <div className="ship-tracking">
      <h3>🚢 Fleet Tracking</h3>
      <div className="ship-list">
        {fleet.map(ship => {
          const isSelected = ship.id === selectedShipId;
          const assignedContract = (ship as any).assignedContract;
          
          return (
            <div 
              key={ship.id} 
              className={`ship-item ${isSelected ? 'selected' : ''}`}
              onClick={() => selectShip(ship.id)}
            >
              <div className="ship-header">
                <span className="ship-name">{ship.name}</span>
                <span 
                  className="ship-status-badge" 
                  style={{ backgroundColor: getStatusColor(ship.status) }}
                >
                  {getStatusIcon(ship.status)} {ship.status}
                </span>
              </div>
              
              <div className="ship-details">
                <div className="ship-detail">
                  <span className="detail-label">Type:</span>
                  <span className="detail-value">{ship.type}</span>
                </div>
                <div className="ship-detail">
                  <span className="detail-label">Speed:</span>
                  <span className="detail-value">{ship.speed} knots</span>
                </div>
                <div className="ship-detail">
                  <span className="detail-label">Capacity:</span>
                  <span className="detail-value">{ship.cargo.length}/{ship.capacity}</span>
                </div>
              </div>
              
              {ship.destination && (
                <div className="ship-route">
                  <span className="route-icon">📍</span>
                  <span className="route-text">En route to {ship.destination.name}</span>
                </div>
              )}
              
              {assignedContract && (
                <div className="ship-contract">
                  <span className="contract-icon">📋</span>
                  <span className="contract-text">Assigned to contract</span>
                </div>
              )}
            </div>
          );
        })}
        
        {fleet.length === 0 && (
          <div className="no-ships">
            No ships in fleet. Purchase your first ship to start trading!
          </div>
        )}
      </div>
    </div>
  );
};