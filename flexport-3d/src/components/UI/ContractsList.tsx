import React, { useState } from 'react';
import { useGameStore } from '../../store/gameStore';
import { ContractStatus, CargoType } from '../../types/game.types';
import './ContractsList.css';

export const ContractsList: React.FC = () => {
  const { contracts, fleet, acceptContract, assignShipToContract } = useGameStore();
  const [filter, setFilter] = useState<'all' | 'available' | 'active' | 'completed'>('all');
  
  const filteredContracts = contracts.filter(contract => {
    if (filter === 'all') return true;
    return contract.status.toLowerCase() === filter;
  });
  
  const getCargoIcon = (type: CargoType) => {
    const icons = {
      [CargoType.STANDARD]: '📦',
      [CargoType.REFRIGERATED]: '🧊',
      [CargoType.HAZARDOUS]: '☢️',
      [CargoType.VALUABLE]: '💎',
    };
    return icons[type] || '📦';
  };
  
  const getStatusColor = (status: ContractStatus) => {
    const colors = {
      [ContractStatus.AVAILABLE]: '#10b981',
      [ContractStatus.ACTIVE]: '#3b82f6',
      [ContractStatus.COMPLETED]: '#6b7280',
      [ContractStatus.FAILED]: '#ef4444',
    };
    return colors[status];
  };
  
  const handleAcceptContract = (contractId: string) => {
    acceptContract(contractId);
  };
  
  const idleShips = fleet.filter(ship => ship.status === 'IDLE');
  
  return (
    <div className="contracts-list">
      <h3>Contracts Management</h3>
      
      <div className="contracts-filter">
        <button 
          className={`filter-btn ${filter === 'all' ? 'active' : ''}`}
          onClick={() => setFilter('all')}
        >
          All ({contracts.length})
        </button>
        <button 
          className={`filter-btn ${filter === 'available' ? 'active' : ''}`}
          onClick={() => setFilter('available')}
        >
          Available ({contracts.filter(c => c.status === ContractStatus.AVAILABLE).length})
        </button>
        <button 
          className={`filter-btn ${filter === 'active' ? 'active' : ''}`}
          onClick={() => setFilter('active')}
        >
          Active ({contracts.filter(c => c.status === ContractStatus.ACTIVE).length})
        </button>
        <button 
          className={`filter-btn ${filter === 'completed' ? 'active' : ''}`}
          onClick={() => setFilter('completed')}
        >
          Completed ({contracts.filter(c => c.status === ContractStatus.COMPLETED).length})
        </button>
      </div>
      
      <div className="contracts-grid">
        {filteredContracts.map(contract => (
          <div key={contract.id} className="contract-card">
            <div className="contract-header">
              <span className="cargo-icon">{getCargoIcon(contract.cargo)}</span>
              <span 
                className="contract-status"
                style={{ backgroundColor: getStatusColor(contract.status) }}
              >
                {contract.status}
              </span>
            </div>
            
            <div className="contract-route">
              <div className="route-point">
                <span className="point-label">From</span>
                <span className="point-name">{contract.origin.name}</span>
              </div>
              <div className="route-arrow">→</div>
              <div className="route-point">
                <span className="point-label">To</span>
                <span className="point-name">{contract.destination.name}</span>
              </div>
            </div>
            
            <div className="contract-details">
              <div className="detail">
                <span className="detail-label">Cargo</span>
                <span className="detail-value">{contract.cargo}</span>
              </div>
              <div className="detail">
                <span className="detail-label">Quantity</span>
                <span className="detail-value">{contract.quantity} TEU</span>
              </div>
              <div className="detail">
                <span className="detail-label">Value</span>
                <span className="detail-value value">${contract.value.toLocaleString()}</span>
              </div>
              <div className="detail">
                <span className="detail-label">Deadline</span>
                <span className="detail-value">{new Date(contract.deadline).toLocaleDateString()}</span>
              </div>
            </div>
            
            {contract.status === ContractStatus.AVAILABLE && (
              <div className="contract-actions">
                <button 
                  className="accept-btn"
                  onClick={() => handleAcceptContract(contract.id)}
                >
                  Accept Contract
                </button>
              </div>
            )}
            
            {contract.status === ContractStatus.ACTIVE && idleShips.length > 0 && (
              <div className="ship-assignment">
                <select 
                  onChange={(e) => {
                    if (e.target.value) {
                      assignShipToContract(e.target.value, contract.id);
                    }
                  }}
                  defaultValue=""
                >
                  <option value="">Assign Ship...</option>
                  {idleShips.map(ship => (
                    <option key={ship.id} value={ship.id}>
                      {ship.name} ({ship.capacity} TEU)
                    </option>
                  ))}
                </select>
              </div>
            )}
          </div>
        ))}
      </div>
      
      {filteredContracts.length === 0 && (
        <div className="empty-state">
          <p>No contracts found</p>
        </div>
      )}
    </div>
  );
};