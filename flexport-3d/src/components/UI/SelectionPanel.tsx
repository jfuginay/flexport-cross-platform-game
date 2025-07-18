import React from 'react';
import { useGameStore } from '../../store/gameStore';
import './SelectionPanel.css';

export const SelectionPanel: React.FC = () => {
  const { 
    selectedShipId, 
    selectedPortId, 
    fleet, 
    ports, 
    contracts,
    sendShipToPort,
    selectShip,
    selectPort 
  } = useGameStore();

  const selectedShip = fleet.find(s => s.id === selectedShipId);
  const selectedPort = ports.find(p => p.id === selectedPortId);

  if (!selectedShip && !selectedPort) return null;

  const handleClose = () => {
    selectShip(null);
    selectPort(null);
  };

  if (selectedShip) {
    const assignedContract = contracts.find(c => c.id === (selectedShip as any).assignedContract);
    
    return (
      <div className="selection-panel">
        <div className="panel-header">
          <h3>🚢 {selectedShip.name}</h3>
          <button className="close-button" onClick={handleClose}>×</button>
        </div>
        
        <div className="ship-details">
          <div className="detail-row">
            <span>Type</span>
            <span>{selectedShip.type}</span>
          </div>
          <div className="detail-row">
            <span>Status</span>
            <span className={`status ${selectedShip.status.toLowerCase()}`}>
              {selectedShip.status.replace('_', ' ')}
            </span>
          </div>
          <div className="detail-row">
            <span>Health</span>
            <div className="health-bar">
              <div 
                className="health-fill" 
                style={{ 
                  width: `${selectedShip.health}%`,
                  background: selectedShip.health > 70 ? '#10b981' : 
                             selectedShip.health > 30 ? '#f59e0b' : '#ef4444'
                }}
              />
            </div>
            <span>{selectedShip.health}%</span>
          </div>
          <div className="detail-row">
            <span>Capacity</span>
            <span>{selectedShip.cargo.length} / {selectedShip.capacity} TEU</span>
          </div>
          <div className="detail-row">
            <span>Speed</span>
            <span>{(selectedShip.speed * 10).toFixed(1)} knots</span>
          </div>
          {assignedContract && (
            <div className="detail-row">
              <span>Contract</span>
              <span className="contract-info">
                {assignedContract.origin.name} → {assignedContract.destination.name}
              </span>
            </div>
          )}
        </div>

        <div className="action-buttons">
          <h4>Send to Port</h4>
          <div className="port-buttons">
            {ports.map(port => (
              <button
                key={port.id}
                className="port-button"
                onClick={() => sendShipToPort(selectedShip.id, port.id)}
                disabled={selectedShip.status !== 'IDLE'}
              >
                {port.name}
              </button>
            ))}
          </div>
        </div>
      </div>
    );
  }

  if (selectedPort) {
    const portContracts = contracts.filter(
      c => c.origin.id === selectedPort.id || c.destination.id === selectedPort.id
    );

    return (
      <div className="selection-panel">
        <div className="panel-header">
          <h3>🏢 {selectedPort.name}</h3>
          <button className="close-button" onClick={handleClose}>×</button>
        </div>
        
        <div className="port-details">
          <div className="detail-row">
            <span>Country</span>
            <span>{selectedPort.country}</span>
          </div>
          <div className="detail-row">
            <span>Ownership</span>
            <span className={selectedPort.isPlayerOwned ? 'owned' : 'not-owned'}>
              {selectedPort.isPlayerOwned ? 'Player Owned' : 'Independent'}
            </span>
          </div>
          <div className="detail-row">
            <span>Berths</span>
            <span>{selectedPort.availableBerths} / {selectedPort.berths} available</span>
          </div>
          <div className="detail-row">
            <span>Loading Speed</span>
            <span>{selectedPort.loadingSpeed} TEU/hour</span>
          </div>
          <div className="detail-row">
            <span>Current Load</span>
            <div className="load-bar">
              <div 
                className="load-fill" 
                style={{ width: `${(selectedPort.currentLoad / selectedPort.capacity) * 100}%` }}
              />
            </div>
            <span>{Math.round(selectedPort.currentLoad)} / {selectedPort.capacity}</span>
          </div>
        </div>

        {portContracts.length > 0 && (
          <div className="port-contracts">
            <h4>Available Contracts</h4>
            {portContracts.slice(0, 3).map(contract => (
              <div key={contract.id} className="contract-item">
                <div className="contract-route">
                  {contract.origin.name} → {contract.destination.name}
                </div>
                <div className="contract-value">${contract.value.toLocaleString()}</div>
              </div>
            ))}
          </div>
        )}
      </div>
    );
  }

  return null;
};