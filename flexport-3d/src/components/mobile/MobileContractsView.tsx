// @ts-nocheck
import React, { useState } from 'react';
import { useGameStore } from '../../store/gameStore';
import { Contract } from '../../types/game.types';
import './MobileContractsView.css';

interface MobileContractsViewProps {
  onClose?: () => void;
}

export const MobileContractsView: React.FC<MobileContractsViewProps> = ({ onClose }) => {
  const { contracts, acceptContract, fleet, ports, assignShipToContract } = useGameStore();
  const [selectedContract, setSelectedContract] = useState<string | null>(null);
  
  const playerShips = fleet.filter(ship => ship.cargo.length === 0);
  const availableContracts = contracts.filter(c => c.status === 'AVAILABLE');

  const handleAcceptContract = (contractId: string, shipId: string) => {
    acceptContract(contractId);
    // Assign ship to contract after accepting
    assignShipToContract(shipId, contractId);
    setSelectedContract(null);
  };

  const getPortName = (portId: string) => {
    const port = ports.find(p => p.id === portId);
    return port?.name || portId;
  };

  const calculateProfit = (contract: Contract) => {
    return contract.value;
  };

  const calculateDistance = (contract: Contract) => {
    const originPort = contract.origin;
    const destPort = contract.destination;
    
    if (!originPort || !destPort) return 0;
    
    const dx = destPort.position.x - originPort.position.x;
    const dy = destPort.position.y - originPort.position.y;
    const dz = destPort.position.z - originPort.position.z;
    
    return Math.sqrt(dx * dx + dy * dy + dz * dz) * 1000;
  };

  return (
    <div className="mobile-contracts-view">
      <div className="mobile-header">
        <h2>Available Contracts</h2>
        <button className="mobile-close-btn" onClick={onClose}>×</button>
      </div>
      
      <div className="contracts-list">
        {availableContracts.map(contract => {
          const profit = calculateProfit(contract);
          const distance = calculateDistance(contract);
          const isSelected = contract.id === selectedContract;
          
          return (
            <div key={contract.id} className="contract-section">
              <div 
                className={`contract-card ${isSelected ? 'expanded' : ''}`}
                onClick={() => setSelectedContract(isSelected ? null : contract.id)}
              >
                <div className="contract-header">
                  <div className="contract-route">
                    <span className="port-name">{contract.origin.name}</span>
                    <span className="route-arrow">→</span>
                    <span className="port-name">{contract.destination.name}</span>
                  </div>
                  <div className={`contract-profit ${profit > 0 ? 'positive' : 'negative'}`}>
                    ${profit.toLocaleString()}
                  </div>
                </div>
                
                <div className="contract-details">
                  <div className="detail-grid">
                    <div className="detail-item">
                      <span className="detail-label">Cargo</span>
                      <span className="detail-value">{contract.cargo || 'General'}</span>
                    </div>
                    <div className="detail-item">
                      <span className="detail-label">Volume</span>
                      <span className="detail-value">{contract.quantity || '1000'} TEU</span>
                    </div>
                    <div className="detail-item">
                      <span className="detail-label">Payment</span>
                      <span className="detail-value">${contract.value.toLocaleString()}</span>
                    </div>
                    <div className="detail-item">
                      <span className="detail-label">Distance</span>
                      <span className="detail-value">{distance.toFixed(0)} km</span>
                    </div>
                  </div>
                  
                  <div className="deadline-info">
                    <span className="deadline-label">Deadline:</span>
                    <span className="deadline-value">{Math.ceil((contract.deadline.getTime() - new Date().getTime()) / (1000 * 60 * 60 * 24))} days</span>
                  </div>
                </div>
              </div>
              
              {isSelected && (
                <div className="ship-selection">
                  <h4>Select a ship:</h4>
                  {playerShips.length > 0 ? (
                    <div className="ship-options">
                      {playerShips.map(ship => (
                        <button
                          key={ship.id}
                          className="ship-option"
                          onClick={(e) => {
                            e.stopPropagation();
                            handleAcceptContract(contract.id, ship.id);
                          }}
                          disabled={ship.capacity < (contract.quantity || 1000)}
                        >
                          <div className="ship-option-name">{ship.name}</div>
                          <div className="ship-option-info">
                            {ship.capacity >= (contract.quantity || 1000) ? (
                              `${ship.capacity} TEU capacity`
                            ) : (
                              <span className="insufficient">Insufficient capacity</span>
                            )}
                          </div>
                        </button>
                      ))}
                    </div>
                  ) : (
                    <p className="no-ships">No available ships. Ships with cargo cannot accept new contracts.</p>
                  )}
                </div>
              )}
            </div>
          );
        })}
      </div>

      {availableContracts.length === 0 && (
        <div className="empty-state">
          <p>No contracts available</p>
          <p className="empty-hint">Check back later for new opportunities!</p>
        </div>
      )}
    </div>
  );
};