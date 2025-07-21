// @ts-nocheck
import React from 'react';
import { useGameStore } from '../../store/gameStore';
import { ShipStatus } from '../../types/game.types';
import './ShipTracking.css';

export const ShipTracking: React.FC = () => {
  const { fleet, contracts, ports, selectShip, selectedShipId } = useGameStore();
  
  // Filter to show only player ships
  const playerShips = fleet.filter(ship => ship.ownerId === 'player' || !ship.ownerId);
  
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
        {playerShips.map(ship => {
          const isSelected = ship.id === selectedShipId;
          const assignedContract = (ship as any).assignedContract;
          const contract = contracts.find(c => c.id === assignedContract);
          const currentPort = ports.find(p => p.id === ship.currentPortId);
          const progress = (ship as any).routeProgress || 0;
          
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
                  <span className="detail-label">Location:</span>
                  <span className="detail-value">
                    {currentPort ? currentPort.name : ship.destination ? 'At Sea' : 'Unknown'}
                  </span>
                </div>
                <div className="ship-detail">
                  <span className="detail-label">Cargo:</span>
                  <span className="detail-value">
                    {ship.cargo.length > 0 
                      ? `${Math.round((ship.cargo.length / ship.capacity) * 100)}% Full`
                      : 'Empty'}
                  </span>
                </div>
                <div className="ship-detail">
                  <span className="detail-label">Fuel:</span>
                  <span className="detail-value">{ship.fuel}%</span>
                </div>
                <div className="ship-detail">
                  <span className="detail-label">Health:</span>
                  <span className="detail-value">{ship.health || ship.condition || 100}%</span>
                </div>
              </div>
              
              {ship.destination && (
                <div className="ship-route">
                  <span className="route-icon">📍</span>
                  <span className="route-text">
                    {ship.status === ShipStatus.SAILING && 'En route to '}
                    {ship.status === ShipStatus.LOADING && 'Loading at '}
                    {ship.status === ShipStatus.UNLOADING && 'Unloading at '}
                    {ship.destination.name}
                  </span>
                  {ship.status === ShipStatus.SAILING && (
                    <div className="route-progress">
                      <div className="progress-bar">
                        <div 
                          className="progress-fill" 
                          style={{ width: `${progress * 100}%` }}
                        />
                      </div>
                      <span className="progress-text">{Math.round(progress * 100)}%</span>
                    </div>
                  )}
                </div>
              )}
              
              {contract && (
                <div className="ship-contract">
                  <span className="contract-icon">📋</span>
                  <span className="contract-text">
                    {contract.origin.name} → {contract.destination.name}
                    {(ship as any).contractStage === 'delivery' && ' (Delivering)'}
                    {(ship as any).contractStage === 'pickup' && ' (Picking up)'}
                  </span>
                  <span className="contract-value">${contract.value.toLocaleString()}</span>
                </div>
              )}
            </div>
          );
        })}
        
        {playerShips.length === 0 && (
          <div className="no-ships">
            No ships in fleet. Purchase your first ship to start trading!
          </div>
        )}
      </div>
    </div>
  );
};