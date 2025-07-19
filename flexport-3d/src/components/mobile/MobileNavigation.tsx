// @ts-nocheck
import React, { useState } from 'react';
import { useGameStore } from '../../store/gameStore';
import './MobileNavigation.css';

interface MobileNavigationProps {
  onFleetClick: () => void;
  onContractsClick: () => void;
  onAlertsClick: () => void;
}

export const MobileNavigation: React.FC<MobileNavigationProps> = ({
  onFleetClick,
  onContractsClick,
  onAlertsClick
}) => {
  const { fleet, contracts, money } = useGameStore();
  const [activeTab, setActiveTab] = useState<string>('map');
  
  const availableContracts = contracts.filter(c => c.status === 'AVAILABLE').length;
  const activeShips = fleet.filter(ship => ship.status === 'SAILING').length;
  
  const handleTabClick = (tab: string, callback?: () => void) => {
    setActiveTab(tab);
    callback?.();
  };

  return (
    <>
      <div className="mobile-top-bar">
        <div className="balance-display">
          <span className="balance-label">Balance</span>
          <span className="balance-value">${money.toLocaleString()}</span>
        </div>
        <div className="stats-row">
          <div className="stat-item">
            <span className="stat-value">{fleet.length}</span>
            <span className="stat-label">Ships</span>
          </div>
          <div className="stat-item">
            <span className="stat-value">{activeShips}</span>
            <span className="stat-label">Active</span>
          </div>
          <div className="stat-item">
            <span className="stat-value">{availableContracts}</span>
            <span className="stat-label">Contracts</span>
          </div>
        </div>
      </div>

      <div className="mobile-bottom-nav">
        <button 
          className={`nav-item ${activeTab === 'map' ? 'active' : ''}`}
          onClick={() => handleTabClick('map')}
        >
          <svg className="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <circle cx="12" cy="12" r="10" />
            <path d="M12 2v20M2 12h20" />
          </svg>
          <span className="nav-label">Map</span>
        </button>
        
        <button 
          className={`nav-item ${activeTab === 'fleet' ? 'active' : ''}`}
          onClick={() => handleTabClick('fleet', onFleetClick)}
        >
          <svg className="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M21 8V5a2 2 0 00-2-2H5a2 2 0 00-2 2v3m18 0l-9 4-9-4m18 0v8a2 2 0 01-2 2H5a2 2 0 01-2-2V8" />
          </svg>
          <span className="nav-label">Fleet</span>
          {fleet.length > 0 && <span className="nav-badge">{fleet.length}</span>}
        </button>
        
        <button 
          className={`nav-item ${activeTab === 'contracts' ? 'active' : ''}`}
          onClick={() => handleTabClick('contracts', onContractsClick)}
        >
          <svg className="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
          </svg>
          <span className="nav-label">Contracts</span>
          {availableContracts > 0 && <span className="nav-badge">{availableContracts}</span>}
        </button>
        
        <button 
          className={`nav-item ${activeTab === 'alerts' ? 'active' : ''}`}
          onClick={() => handleTabClick('alerts', onAlertsClick)}
        >
          <svg className="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
          </svg>
          <span className="nav-label">Alerts</span>
        </button>
      </div>
    </>
  );
};