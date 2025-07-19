// @ts-nocheck
import React from 'react';
import { useGameStore } from '../../store/gameStore';
import { ShipStatus, ContractStatus } from '../../types/game.types';
import './ShipAssignment.css';

export const ShipAssignment: React.FC = () => {
  const { fleet, contracts, assignShipToContract, acceptContract } = useGameStore();
  
  const availableShips = fleet.filter(ship => 
    ship.status === ShipStatus.IDLE && 
    ship.cargo.length === 0 &&
    !(ship as any).assignedContract
  );
  
  const availableContracts = contracts.filter(contract => 
    contract.status === ContractStatus.AVAILABLE
  );
  
  const activeContracts = contracts.filter(contract =>
    contract.status === ContractStatus.ACTIVE
  );

  const handleAssignShip = (shipId: string, contractId: string) => {
    // First accept the contract if it's not active
    const contract = contracts.find(c => c.id === contractId);
    if (contract && contract.status === ContractStatus.AVAILABLE) {
      acceptContract(contractId);
    }
    // Then assign the ship
    assignShipToContract(shipId, contractId);
  };

  return (
    <div className="ship-assignment">
      <h3>📋 Contract Management</h3>
      
      {availableContracts.length > 0 && (
        <div className="contracts-section">
          <h4>Available Contracts</h4>
          {availableContracts.map(contract => (
            <div key={contract.id} className="contract-card">
              <div className="contract-header">
                <span className="contract-cargo">{contract.cargo}</span>
                <span className="contract-value">${contract.value.toLocaleString()}</span>
              </div>
              <div className="contract-route">
                {contract.origin.name} → {contract.destination.name}
              </div>
              <div className="contract-details">
                <span>📦 {contract.quantity} units</span>
                <span>⏱️ {Math.ceil((contract.deadline.getTime() - new Date().getTime()) / (1000 * 60 * 60 * 24))} days</span>
              </div>
              
              {availableShips.length > 0 ? (
                <div className="ship-selector">
                  <select 
                    onChange={(e) => {
                      if (e.target.value) {
                        handleAssignShip(e.target.value, contract.id);
                        e.target.value = '';
                      }
                    }}
                    defaultValue=""
                  >
                    <option value="">Assign Ship...</option>
                    {availableShips.map(ship => (
                      <option key={ship.id} value={ship.id}>
                        🚢 {ship.name} ({ship.type})
                      </option>
                    ))}
                  </select>
                </div>
              ) : (
                <div className="no-ships">No ships available</div>
              )}
            </div>
          ))}
        </div>
      )}
      
      {activeContracts.length > 0 && (
        <div className="contracts-section">
          <h4>Active Contracts</h4>
          {activeContracts.map(contract => {
            const assignedShip = fleet.find(ship => 
              (ship as any).assignedContract === contract.id
            );
            
            return (
              <div key={contract.id} className="contract-card active">
                <div className="contract-header">
                  <span className="contract-cargo">{contract.cargo}</span>
                  <span className="contract-value">${contract.value.toLocaleString()}</span>
                </div>
                <div className="contract-route">
                  {contract.origin.name} → {contract.destination.name}
                </div>
                {assignedShip && (
                  <div className="assigned-ship">
                    🚢 {assignedShip.name} - {assignedShip.status}
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}
      
      {availableContracts.length === 0 && activeContracts.length === 0 && (
        <div className="no-contracts">
          No contracts available. New contracts will appear soon!
        </div>
      )}
    </div>
  );
};