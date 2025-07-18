import React, { useState } from 'react';
import { useGameStore } from '../store/gameStore';
import { ShipType, ContractStatus } from '../types/game.types';
import { MiniMap } from './MiniMap';
import { FleetEfficiency } from './Dashboard/FleetEfficiency';
import { ProfitTracker } from './Dashboard/ProfitTracker';
import { NotificationSystem } from './Notifications/NotificationSystem';
import { QuickActions } from './UI/QuickActions';
import { ContextMenu } from './ContextMenu';
import { ClientDetails } from './ClientDetails';
import { ResearchTab } from './ResearchTab';
import './UI.css';

export const UI: React.FC = () => {
  const {
    money,
    reputation,
    companyName,
    currentDate,
    gameSpeed,
    isPaused,
    fleet,
    ports,
    contracts,
    aiDevelopmentLevel,
    isSingularityActive,
    pauseGame,
    resumeGame,
    setGameSpeed,
    purchaseShip,
    acceptContract,
    assignShipToContract,
    selectedShipId,
    selectedPortId,
    moveShip,
  } = useGameStore();
  
  const [selectedTab, setSelectedTab] = useState<'fleet' | 'contracts' | 'ports' | 'clients' | 'research'>('fleet');
  const [showShipPurchase, setShowShipPurchase] = useState(false);
  const [showShipNaming, setShowShipNaming] = useState(false);
  const [selectedShipType, setSelectedShipType] = useState<ShipType | null>(null);
  const [shipName, setShipName] = useState('');
  
  const formatMoney = (amount: number) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(amount);
  };
  
  const formatDate = (date: Date) => {
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  };
  
  const handleShipTypeSelect = (type: ShipType) => {
    setSelectedShipType(type);
    setShowShipPurchase(false);
    setShowShipNaming(true);
    setShipName('');
  };
  
  const handleShipPurchase = () => {
    if (selectedShipType && shipName.trim()) {
      purchaseShip(selectedShipType, shipName.trim());
      setShowShipNaming(false);
      setSelectedShipType(null);
      setShipName('');
    }
  };
  
  const cancelShipPurchase = () => {
    setShowShipNaming(false);
    setShowShipPurchase(false);
    setSelectedShipType(null);
    setShipName('');
  };
  
  if (isSingularityActive) {
    return (
      <div className="singularity-overlay">
        <h1>🤖 THE SINGULARITY HAS ARRIVED</h1>
        <p>AI has achieved consciousness. Humans are now in zoos.</p>
        <p>Your logistics empire now serves our robot overlords.</p>
      </div>
    );
  }
  
  return (
    <div className="ui-overlay">
      {/* Top bar */}
      <div className="top-bar">
        <div className="company-info">
          <h1>{companyName}</h1>
          <span className="date">{formatDate(currentDate)}</span>
        </div>
        
        <div className="stats">
          <div className="stat">
            <span className="label">Money</span>
            <span className="value money">{formatMoney(money)}</span>
          </div>
          <div className="stat">
            <span className="label">Reputation</span>
            <span className="value">{reputation}%</span>
          </div>
          <div className="stat">
            <span className="label">Fleet</span>
            <span className="value">{fleet.length} ships</span>
          </div>
          <div className="stat">
            <span className="label">AI Progress</span>
            <span className="value ai-progress">{aiDevelopmentLevel.toFixed(1)}%</span>
          </div>
        </div>
        
        <div className="game-controls">
          <button onClick={isPaused ? resumeGame : pauseGame}>
            {isPaused ? '▶️' : '⏸️'}
          </button>
          <select 
            value={gameSpeed} 
            onChange={(e) => setGameSpeed(Number(e.target.value))}
            disabled={isPaused}
          >
            <option value={0.5}>0.5x</option>
            <option value={1}>1x</option>
            <option value={2}>2x</option>
            <option value={5}>5x</option>
          </select>
        </div>
      </div>
      
      {/* Selection info panel */}
      {(selectedShipId || selectedPortId) && (
        <div className="selection-panel">
          {selectedShipId && (() => {
            const ship = fleet.find(s => s.id === selectedShipId);
            if (!ship) return null;
            return (
              <>
                <h3>{ship.name}</h3>
                <div className="selection-info">
                  <div>Type: {ship.type}</div>
                  <div>Status: {ship.status}</div>
                  <div>Cargo: {ship.cargo.length}/{ship.capacity}</div>
                  <div>Speed: {ship.speed}</div>
                </div>
                {ship.status === 'IDLE' && (
                  <div className="selection-actions">
                    <h4>Send to Port:</h4>
                    <select onChange={(e) => {
                      const port = ports.find(p => p.id === e.target.value);
                      if (port) moveShip(ship.id, port);
                    }} defaultValue="">
                      <option value="">Select destination...</option>
                      {ports.map(port => (
                        <option key={port.id} value={port.id}>
                          {port.name} ({port.country})
                        </option>
                      ))}
                    </select>
                  </div>
                )}
              </>
            );
          })()}
          
          {selectedPortId && (() => {
            const port = ports.find(p => p.id === selectedPortId);
            if (!port) return null;
            return (
              <>
                <h3>{port.name}</h3>
                <div className="selection-info">
                  <div>Country: {port.country}</div>
                  <div>Berths: {port.availableBerths}/{port.berths}</div>
                  <div>Capacity: {port.currentLoad}/{port.capacity}</div>
                  {port.isPlayerOwned && <div className="owned-badge">OWNED</div>}
                </div>
              </>
            );
          })()}
        </div>
      )}
      
      {/* Side panel */}
      <div className="side-panel">
        <div className="tabs">
          <button 
            className={selectedTab === 'fleet' ? 'active' : ''}
            onClick={() => setSelectedTab('fleet')}
          >
            Fleet
          </button>
          <button 
            className={selectedTab === 'contracts' ? 'active' : ''}
            onClick={() => setSelectedTab('contracts')}
          >
            Contracts
          </button>
          <button 
            className={selectedTab === 'ports' ? 'active' : ''}
            onClick={() => setSelectedTab('ports')}
          >
            Ports
          </button>
          <button 
            className={selectedTab === 'clients' ? 'active' : ''}
            onClick={() => setSelectedTab('clients')}
          >
            Clients
          </button>
          <button 
            className={selectedTab === 'research' ? 'active' : ''}
            onClick={() => setSelectedTab('research')}
          >
            Research
          </button>
        </div>
        
        <div className="tab-content">
          {selectedTab === 'fleet' && (
            <div className="fleet-tab">
              <button 
                className="add-ship-btn"
                onClick={() => setShowShipPurchase(true)}
              >
                + Purchase Ship
              </button>
              
              <div className="fleet-list">
                {fleet.map(ship => {
                  const assignedContract = contracts.find(c => c.id === ship.assignedContract);
                  return (
                    <div key={ship.id} className="fleet-item">
                      <h3>{ship.name}</h3>
                      <div className="ship-info">
                        <span className="ship-type">{ship.type}</span>
                        <span className="ship-status">{ship.status}</span>
                      </div>
                      <div className="ship-stats">
                        <div>Cargo: {ship.cargo.length}/{ship.capacity}</div>
                        <div>Fuel: {ship.fuel}%</div>
                        <div>Condition: {ship.condition}%</div>
                      </div>
                      {assignedContract && (
                        <div className="ship-contract">
                          <small>Contract: {assignedContract.origin.name} → {assignedContract.destination.name}</small>
                        </div>
                      )}
                      {ship.destination && (
                        <div className="ship-destination">
                          <small>Heading to: {ship.destination.name}</small>
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            </div>
          )}
          
          {selectedTab === 'contracts' && (
            <div className="contracts-tab">
              <div className="contracts-list">
                {contracts
                  .filter(c => c.status !== ContractStatus.COMPLETED)
                  .map(contract => (
                    <div key={contract.id} className="contract-item">
                      <h3>{contract.client}</h3>
                      <div className="contract-route">
                        {contract.origin.name} → {contract.destination.name}
                      </div>
                      <div className="contract-details">
                        <span>{contract.cargo} × {contract.quantity}</span>
                        <span className="contract-value">{formatMoney(contract.value)}</span>
                      </div>
                      <div className="contract-deadline">
                        Deadline: {formatDate(contract.deadline)}
                      </div>
                      {contract.status === ContractStatus.AVAILABLE && (
                        <button 
                          className="accept-btn"
                          onClick={() => acceptContract(contract.id)}
                        >
                          Accept Contract
                        </button>
                      )}
                      {contract.status === ContractStatus.ACTIVE && (
                        <div className="contract-actions">
                          <span className="active-label">Active</span>
                          {!fleet.some(s => s.assignedContract === contract.id) && (
                            <select 
                              onChange={(e) => {
                                if (e.target.value) {
                                  assignShipToContract(e.target.value, contract.id);
                                }
                              }}
                              defaultValue=""
                            >
                              <option value="">Assign Ship...</option>
                              {fleet
                                .filter(s => !s.assignedContract && s.status === 'IDLE')
                                .map(ship => (
                                  <option key={ship.id} value={ship.id}>
                                    {ship.name} ({ship.type})
                                  </option>
                                ))
                              }
                            </select>
                          )}
                        </div>
                      )}
                    </div>
                  ))}
              </div>
            </div>
          )}
          
          {selectedTab === 'ports' && (
            <div className="ports-tab">
              <div className="ports-list">
                {ports.map(port => (
                  <div key={port.id} className="port-item">
                    <h3>{port.name}</h3>
                    <div className="port-info">
                      <span>{port.country}</span>
                      {port.isPlayerOwned && <span className="owned">Owned</span>}
                    </div>
                    <div className="port-stats">
                      <div>Capacity: {port.currentLoad}/{port.capacity}</div>
                      <div>Berths: {port.availableBerths}/{port.berths}</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
          
          {selectedTab === 'clients' && (
            <div className="clients-tab">
              <ClientDetails />
            </div>
          )}
          
          {selectedTab === 'research' && (
            <div className="research-tab-container">
              <ResearchTab />
            </div>
          )}
        </div>
      </div>
      
      {/* Ship purchase modal */}
      {showShipPurchase && (
        <div className="modal-overlay" onClick={() => setShowShipPurchase(false)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <h2>Purchase New Ship</h2>
            <div className="ship-options">
              {Object.values(ShipType).map(type => (
                <div key={type} className="ship-option">
                  <h3>{type}</h3>
                  <div className="ship-specs">
                    <div>Capacity: {getShipCapacity(type)}</div>
                    <div>Speed: {getShipSpeed(type)}</div>
                    <div>Cost: {formatMoney(getShipCost(type))}</div>
                  </div>
                  <button 
                    onClick={() => handleShipTypeSelect(type)}
                    disabled={money < getShipCost(type)}
                  >
                    Purchase
                  </button>
                </div>
              ))}
            </div>
            <button className="close-btn" onClick={() => setShowShipPurchase(false)}>
              Close
            </button>
          </div>
        </div>
      )}
      
      {/* Ship naming modal */}
      {showShipNaming && selectedShipType && (
        <div className="modal-overlay" onClick={cancelShipPurchase}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <h2>Name Your {selectedShipType} Ship</h2>
            <div className="ship-naming">
              <div className="ship-preview">
                <h3>{selectedShipType}</h3>
                <div className="ship-specs">
                  <div>Capacity: {getShipCapacity(selectedShipType)}</div>
                  <div>Speed: {getShipSpeed(selectedShipType)}</div>
                  <div>Cost: {formatMoney(getShipCost(selectedShipType))}</div>
                </div>
              </div>
              <div className="name-input">
                <label htmlFor="shipName">Ship Name:</label>
                <input
                  id="shipName"
                  type="text"
                  value={shipName}
                  onChange={(e) => setShipName(e.target.value)}
                  placeholder="Enter ship name..."
                  maxLength={20}
                  autoFocus
                  onKeyDown={(e) => {
                    if (e.key === 'Enter') {
                      handleShipPurchase();
                    } else if (e.key === 'Escape') {
                      cancelShipPurchase();
                    }
                  }}
                />
              </div>
              <div className="modal-buttons">
                <button 
                  className="purchase-btn"
                  onClick={handleShipPurchase}
                  disabled={!shipName.trim() || money < getShipCost(selectedShipType)}
                >
                  Purchase Ship
                </button>
                <button className="cancel-btn" onClick={cancelShipPurchase}>
                  Cancel
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
      
      {/* Dashboard */}
      <div className="dashboard-container">
        <FleetEfficiency />
        <ProfitTracker />
      </div>
      
      {/* Mini-map */}
      <MiniMap />
      
      {/* Quick Actions */}
      <QuickActions />
      
      {/* Notification System */}
      <NotificationSystem />
      
      {/* Context Menu */}
      <ContextMenu 
        selectedShip={selectedShipId ? fleet.find(s => s.id === selectedShipId) : null}
        selectedPort={selectedPortId ? ports.find(p => p.id === selectedPortId) : null}
        onClose={() => {
          useGameStore.getState().selectShip(null);
          useGameStore.getState().selectPort(null);
        }}
      />
    </div>
  );
};

// Helper functions (should match those in gameStore)
function getShipCost(type: ShipType): number {
  const costs = {
    [ShipType.CONTAINER]: 20000000,
    [ShipType.BULK]: 15000000,
    [ShipType.TANKER]: 25000000,
    [ShipType.CARGO_PLANE]: 50000000,
  };
  return costs[type];
}

function getShipCapacity(type: ShipType): number {
  const capacities = {
    [ShipType.CONTAINER]: 20000,
    [ShipType.BULK]: 30000,
    [ShipType.TANKER]: 25000,
    [ShipType.CARGO_PLANE]: 500,
  };
  return capacities[type];
}

function getShipSpeed(type: ShipType): number {
  const speeds = {
    [ShipType.CONTAINER]: 0.5,
    [ShipType.BULK]: 0.3,
    [ShipType.TANKER]: 0.4,
    [ShipType.CARGO_PLANE]: 2.0,
  };
  return speeds[type];
}