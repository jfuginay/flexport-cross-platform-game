import React, { useState } from 'react';
import { useGameStore } from '../../store/gameStore';
import './GameInfoPanel.css';

export const GameInfoPanel: React.FC = () => {
  const [isCollapsed, setIsCollapsed] = useState(false);
  const { 
    money, 
    reputation, 
    companyName, 
    currentDate, 
    fleet, 
    contracts,
    ports
  } = useGameStore();

  const activeContracts = contracts.filter(c => c.status === 'ACTIVE').length;
  const ownedPorts = ports.filter(p => p.isPlayerOwned).length;
  const totalCapacity = fleet.reduce((acc, ship) => acc + ship.capacity, 0);

  const formatMoney = (amount: number) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(amount);
  };

  const formatDate = (date: Date) => {
    return new Intl.DateTimeFormat('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    }).format(date);
  };

  return (
    <div className={`game-info-panel ${isCollapsed ? 'collapsed' : ''}`}>
      <div className="panel-header">
        <div className="company-header">
          <h2>{companyName}</h2>
          {!isCollapsed && <div className="date-display">{formatDate(currentDate)}</div>}
        </div>
        <button 
          className="collapse-button"
          onClick={() => setIsCollapsed(!isCollapsed)}
          title={isCollapsed ? 'Expand' : 'Collapse'}
        >
          {isCollapsed ? '▶' : '◀'}
        </button>
      </div>

      {!isCollapsed && (
        <>
          <div className="info-grid">
        <div className="info-item">
          <div className="info-label">Capital</div>
          <div className="info-value money">{formatMoney(money)}</div>
        </div>

        <div className="info-item">
          <div className="info-label">Reputation</div>
          <div className="info-value">
            <div className="reputation-bar">
              <div 
                className="reputation-fill" 
                style={{ width: `${reputation}%` }}
              />
            </div>
            <span className="reputation-text">{reputation}%</span>
          </div>
        </div>

        <div className="info-item">
          <div className="info-label">Fleet</div>
          <div className="info-value">
            <span className="fleet-count">{fleet.length}</span>
            <span className="fleet-capacity">({totalCapacity.toLocaleString()} TEU)</span>
          </div>
        </div>

        <div className="info-item">
          <div className="info-label">Contracts</div>
          <div className="info-value">
            <span className="contract-active">{activeContracts}</span>
            <span className="contract-total">/ {contracts.length}</span>
          </div>
        </div>

        <div className="info-item">
          <div className="info-label">Ports</div>
          <div className="info-value">
            <span className="port-owned">{ownedPorts}</span>
            <span className="port-total">/ {ports.length}</span>
          </div>
        </div>
      </div>

      <div className="quick-stats">
        <div className="stat-item">
          <div className="stat-icon">📈</div>
          <div className="stat-details">
            <div className="stat-label">Daily Revenue</div>
            <div className="stat-value">$2.4M</div>
          </div>
        </div>
        <div className="stat-item">
          <div className="stat-icon">🚢</div>
          <div className="stat-details">
            <div className="stat-label">Ships at Sea</div>
            <div className="stat-value">{fleet.filter(s => s.status === 'SAILING').length}</div>
          </div>
        </div>
      </div>
        </>
      )}
    </div>
  );
};