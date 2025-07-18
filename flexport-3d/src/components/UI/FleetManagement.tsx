import React, { useState } from 'react';
import { useGameStore } from '../../store/gameStore';
import { ShipStatus, ShipType } from '../../types/game.types';
import './FleetManagement.css';

interface FleetManagementProps {
  onClose?: () => void;
  embedded?: boolean;
}

export const FleetManagement: React.FC<FleetManagementProps> = ({ onClose, embedded = false }) => {
  const { fleet, ports, sendShipToPort, repairShip, upgradeShip, sellShip, selectShip, purchaseShip, money } = useGameStore();
  const [selectedFilter, setSelectedFilter] = useState<string>('all');
  const [sortBy, setSortBy] = useState<string>('name');
  const [showPurchaseModal, setShowPurchaseModal] = useState(false);
  const [newShipType, setNewShipType] = useState<ShipType>(ShipType.CONTAINER);
  const [newShipName, setNewShipName] = useState('');

  const getStatusColor = (status: ShipStatus) => {
    const colors = {
      [ShipStatus.IDLE]: '#10b981',
      [ShipStatus.SAILING]: '#3b82f6',
      [ShipStatus.LOADING]: '#f59e0b',
      [ShipStatus.UNLOADING]: '#f59e0b',
      [ShipStatus.MAINTENANCE]: '#ef4444',
    };
    return colors[status] || '#6b7280';
  };

  const getShipIcon = (type: ShipType) => {
    const icons = {
      [ShipType.CONTAINER]: '🚢',
      [ShipType.BULK]: '🚢',
      [ShipType.TANKER]: '🛢️',
      [ShipType.CARGO_PLANE]: '✈️',
    };
    return icons[type] || '🚢';
  };

  const filteredFleet = fleet.filter(ship => {
    if (selectedFilter === 'all') return true;
    if (selectedFilter === 'idle') return ship.status === ShipStatus.IDLE;
    if (selectedFilter === 'active') return ship.status !== ShipStatus.IDLE;
    return ship.type === selectedFilter;
  });

  const sortedFleet = [...filteredFleet].sort((a, b) => {
    switch (sortBy) {
      case 'name':
        return a.name.localeCompare(b.name);
      case 'status':
        return a.status.localeCompare(b.status);
      case 'capacity':
        return b.capacity - a.capacity;
      case 'health':
        return a.health - b.health;
      default:
        return 0;
    }
  });

  return (
    <div className={`fleet-management ${embedded ? 'embedded' : ''}`}>
      <div className="fleet-header">
        <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
          <h2>Fleet Management</h2>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '24px' }}>
          <div className="fleet-stats">
            <div className="stat">
              <span className="stat-value">{fleet.length}</span>
              <span className="stat-label">Total Ships</span>
            </div>
            <div className="stat">
              <span className="stat-value">{fleet.filter(s => s.status === ShipStatus.SAILING).length}</span>
              <span className="stat-label">At Sea</span>
            </div>
            <div className="stat">
              <span className="stat-value">{fleet.filter(s => s.status === ShipStatus.IDLE).length}</span>
              <span className="stat-label">Available</span>
            </div>
          </div>
          {onClose && (
            <button className="close-panel-button" onClick={onClose} title="Close Fleet Management">✕</button>
          )}
        </div>
      </div>

      <div className="fleet-controls">
        <button 
          className="purchase-ship-btn"
          onClick={() => setShowPurchaseModal(true)}
        >
          ➕ Purchase New Ship
        </button>
        <div className="filter-group">
          <label>Filter:</label>
          <select value={selectedFilter} onChange={(e) => setSelectedFilter(e.target.value)}>
            <option value="all">All Ships</option>
            <option value="idle">Idle</option>
            <option value="active">Active</option>
            <option value={ShipType.CONTAINER}>Container Ships</option>
            <option value={ShipType.BULK}>Bulk Carriers</option>
            <option value={ShipType.TANKER}>Tankers</option>
            <option value={ShipType.CARGO_PLANE}>Cargo Planes</option>
          </select>
        </div>
        <div className="sort-group">
          <label>Sort by:</label>
          <select value={sortBy} onChange={(e) => setSortBy(e.target.value)}>
            <option value="name">Name</option>
            <option value="status">Status</option>
            <option value="capacity">Capacity</option>
            <option value="health">Health</option>
          </select>
        </div>
      </div>

      <div className="fleet-list">
        {sortedFleet.map(ship => (
          <div key={ship.id} className="ship-card">
            <div className="ship-header">
              <div className="ship-name">
                <span className="ship-icon">{getShipIcon(ship.type)}</span>
                <h3>{ship.name}</h3>
              </div>
              <div className="ship-status" style={{ backgroundColor: getStatusColor(ship.status) }}>
                {ship.status.replace('_', ' ')}
              </div>
            </div>

            <div className="ship-details">
              <div className="detail-row">
                <span>Type:</span>
                <span>{ship.type}</span>
              </div>
              <div className="detail-row">
                <span>Capacity:</span>
                <span>{ship.cargo.length} / {ship.capacity} TEU</span>
              </div>
              <div className="detail-row">
                <span>Health:</span>
                <div className="health-bar">
                  <div 
                    className="health-fill" 
                    style={{ 
                      width: `${ship.health}%`,
                      backgroundColor: ship.health > 70 ? '#10b981' : ship.health > 30 ? '#f59e0b' : '#ef4444'
                    }}
                  />
                </div>
                <span>{ship.health}%</span>
              </div>
              {ship.destination && (
                <div className="detail-row">
                  <span>Destination:</span>
                  <span>{ship.destination.name}</span>
                </div>
              )}
            </div>

            <div className="ship-actions">
              <button 
                className="action-btn locate"
                onClick={() => selectShip(ship.id)}
                title="Locate on map"
              >
                📍 Locate
              </button>
              
              {ship.status === ShipStatus.IDLE && (
                <>
                  <button 
                    className="action-btn repair"
                    onClick={() => repairShip(ship.id)}
                    disabled={ship.health >= 100}
                    title="Repair ship"
                  >
                    🔧 Repair
                  </button>
                  <button 
                    className="action-btn upgrade"
                    onClick={() => upgradeShip(ship.id)}
                    title="Upgrade ship"
                  >
                    ⬆️ Upgrade
                  </button>
                  <button 
                    className="action-btn sell"
                    onClick={() => sellShip(ship.id)}
                    title="Sell ship"
                  >
                    💰 Sell
                  </button>
                </>
              )}
            </div>

            {ship.status === ShipStatus.IDLE && (
              <div className="port-selection">
                <label>Send to port:</label>
                <select 
                  onChange={(e) => {
                    if (e.target.value) {
                      sendShipToPort(ship.id, e.target.value);
                    }
                  }}
                  defaultValue=""
                >
                  <option value="">Select port...</option>
                  {ports.map(port => (
                    <option key={port.id} value={port.id}>
                      {port.name} ({port.country})
                    </option>
                  ))}
                </select>
              </div>
            )}
          </div>
        ))}
      </div>

      {showPurchaseModal && (
        <div className="modal-overlay" onClick={() => setShowPurchaseModal(false)}>
          <div className="purchase-modal" onClick={(e) => e.stopPropagation()}>
            <h3>Purchase New Ship</h3>
            <div className="modal-content">
              <div className="form-group">
                <label>Ship Type:</label>
                <select value={newShipType} onChange={(e) => setNewShipType(e.target.value as ShipType)}>
                  <option value={ShipType.CONTAINER}>Container Ship - $20M (20,000 TEU)</option>
                  <option value={ShipType.BULK}>Bulk Carrier - $15M (30,000 TEU)</option>
                  <option value={ShipType.TANKER}>Tanker - $25M (25,000 TEU)</option>
                  <option value={ShipType.CARGO_PLANE}>Cargo Plane - $50M (500 TEU)</option>
                </select>
              </div>
              <div className="form-group">
                <label>Ship Name:</label>
                <input 
                  type="text" 
                  value={newShipName} 
                  onChange={(e) => setNewShipName(e.target.value)}
                  placeholder="Enter ship name..."
                />
              </div>
              <div className="price-info">
                <span>Price: </span>
                <span className="price">
                  ${newShipType === ShipType.CONTAINER ? '20,000,000' :
                    newShipType === ShipType.BULK ? '15,000,000' :
                    newShipType === ShipType.TANKER ? '25,000,000' : '50,000,000'}
                </span>
              </div>
              <div className="balance-info">
                <span>Your Balance: </span>
                <span className="balance">${money.toLocaleString()}</span>
              </div>
            </div>
            <div className="modal-actions">
              <button 
                className="cancel-btn" 
                onClick={() => {
                  setShowPurchaseModal(false);
                  setNewShipName('');
                }}
              >
                Cancel
              </button>
              <button 
                className="confirm-btn"
                onClick={() => {
                  if (newShipName.trim()) {
                    purchaseShip(newShipType, newShipName.trim());
                    setShowPurchaseModal(false);
                    setNewShipName('');
                  }
                }}
                disabled={!newShipName.trim() || 
                  (newShipType === ShipType.CONTAINER && money < 20000000) ||
                  (newShipType === ShipType.BULK && money < 15000000) ||
                  (newShipType === ShipType.TANKER && money < 25000000) ||
                  (newShipType === ShipType.CARGO_PLANE && money < 50000000)
                }
              >
                Purchase
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};