import React from 'react';
import { Ship, Port, ShipStatus } from '../types/game.types';
import { useGameStore } from '../store/gameStore';
import '../styles/ContextMenu.css';

interface ContextMenuProps {
  selectedShip?: Ship | null;
  selectedPort?: Port | null;
  onClose: () => void;
}

export const ContextMenu: React.FC<ContextMenuProps> = ({ selectedShip, selectedPort, onClose }) => {
  const { 
    sendShipToPort, 
    repairShip, 
    upgradeShip,
    ports,
    contracts,
    assignContractToShip,
    sellShip,
    money
  } = useGameStore();

  if (!selectedShip && !selectedPort) return null;

  const handleSendToPort = (portId: string) => {
    if (selectedShip) {
      sendShipToPort(selectedShip.id, portId);
      onClose();
    }
  };

  const handleAssignContract = (contractId: string) => {
    if (selectedShip) {
      assignContractToShip(contractId, selectedShip.id);
      onClose();
    }
  };

  const handleRepair = () => {
    if (selectedShip) {
      repairShip(selectedShip.id);
      onClose();
    }
  };

  const handleUpgrade = () => {
    if (selectedShip) {
      upgradeShip(selectedShip.id);
      onClose();
    }
  };

  const handleSell = () => {
    if (selectedShip && window.confirm(`Sell ${selectedShip.name} for $${selectedShip.value * 0.7}?`)) {
      sellShip(selectedShip.id);
      onClose();
    }
  };

  return (
    <div className="context-menu">
      <div className="context-menu-header">
        <h3>{selectedShip ? selectedShip.name : selectedPort?.name}</h3>
        <button onClick={onClose} className="close-button">×</button>
      </div>

      {selectedShip && (
        <div className="context-menu-content">
          <div className="info-section">
            <p><strong>Type:</strong> {selectedShip.type}</p>
            <p><strong>Status:</strong> <span className={`status-${selectedShip.status}`}>{selectedShip.status}</span></p>
            <p><strong>Health:</strong> {selectedShip.health}%</p>
            <p><strong>Speed:</strong> {selectedShip.speed} knots</p>
            <p><strong>Cargo:</strong> {selectedShip.cargo.length}/{selectedShip.capacity}</p>
            <p><strong>Fuel:</strong> {Math.round(selectedShip.fuel)}%</p>
            <p><strong>Value:</strong> ${selectedShip.value}</p>
          </div>

          <div className="actions-section">
            <h4>Actions</h4>
            
            {selectedShip.status === ShipStatus.IDLE && (
              <>
                <div className="action-group">
                  <h5>Send to Port</h5>
                  <div className="port-list">
                    {ports.filter(p => p.id !== selectedShip.currentPortId).map(port => (
                      <button
                        key={port.id}
                        onClick={() => handleSendToPort(port.id)}
                        className="port-button"
                      >
                        {port.name} ({port.availableBerths} berths)
                      </button>
                    ))}
                  </div>
                </div>

                <div className="action-group">
                  <h5>Assign Contract</h5>
                  <div className="contract-list">
                    {contracts
                      .filter(c => !c.assignedShipId && c.requiredCapacity <= selectedShip.capacity)
                      .map(contract => (
                        <button
                          key={contract.id}
                          onClick={() => handleAssignContract(contract.id)}
                          className="contract-button"
                        >
                          <>
                            {contract.cargo} → {contract.destination}
                            <br />
                            ${contract.payment} ({contract.requiredCapacity} units)
                          </>
                        </button>
                      ))}
                  </div>
                </div>
              </>
            )}

            <div className="maintenance-actions">
              {selectedShip.health < 100 && (
                <button onClick={handleRepair} disabled={money < 1000}>
                  Repair (${1000})
                </button>
              )}
              
              <button onClick={handleUpgrade} disabled={money < selectedShip.value * 0.5}>
                Upgrade (${selectedShip.value * 0.5})
              </button>
              
              <button onClick={handleSell} className="sell-button">
                Sell (${Math.round(selectedShip.value * 0.7)})
              </button>
            </div>
          </div>

          {selectedShip.cargo.length > 0 && (
            <div className="cargo-section">
              <h4>Current Cargo</h4>
              <ul>
                {selectedShip.cargo.map((item, idx) => (
                  <li key={idx}>{item.type} - {item.weight} units</li>
                ))}
              </ul>
            </div>
          )}
        </div>
      )}

      {selectedPort && (
        <div className="context-menu-content">
          <div className="info-section">
            <p><strong>Location:</strong> ({selectedPort.position.x}, {selectedPort.position.z})</p>
            <p><strong>Berths:</strong> {selectedPort.availableBerths}/{selectedPort.berths}</p>
            <p><strong>Loading Speed:</strong> {selectedPort.loadingSpeed} units/min</p>
            <p><strong>Owner:</strong> {selectedPort.isPlayerOwned ? 'You' : 'AI'}</p>
          </div>

          <div className="ships-at-port">
            <h4>Ships at Port</h4>
            {selectedPort.dockedShips.length > 0 ? (
              <ul>
                {selectedPort.dockedShips.map(shipId => {
                  const ship = useGameStore.getState().fleet.find(s => s.id === shipId);
                  return ship ? <li key={shipId}>{ship.name} - {ship.status}</li> : null;
                })}
              </ul>
            ) : (
              <p>No ships currently docked</p>
            )}
          </div>

          {selectedPort.contracts && selectedPort.contracts.length > 0 && (
            <div className="port-contracts">
              <h4>Available Contracts</h4>
              <ul>
                {selectedPort.contracts.map(contract => (
                  <li key={contract.id}>
                    <>{contract.cargo} → {contract.destination} (${contract.payment})</>
                  </li>
                ))}
              </ul>
            </div>
          )}
        </div>
      )}
    </div>
  );
};