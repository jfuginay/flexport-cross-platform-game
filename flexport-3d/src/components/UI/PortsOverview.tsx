import React from 'react';
import { useGameStore } from '../../store/gameStore';
import './PortsOverview.css';

export const PortsOverview: React.FC = () => {
  const { ports, selectPort } = useGameStore();
  
  const playerPorts = ports.filter(p => p.isPlayerOwned);
  const availablePorts = ports.filter(p => !p.isPlayerOwned);
  
  return (
    <div className="ports-overview">
      <h3>Ports Management</h3>
      
      <div className="ports-summary">
        <div className="summary-item">
          <span className="summary-value">{playerPorts.length}</span>
          <span className="summary-label">Owned Ports</span>
        </div>
        <div className="summary-item">
          <span className="summary-value">{availablePorts.length}</span>
          <span className="summary-label">Available Ports</span>
        </div>
      </div>
      
      <div className="ports-section">
        <h4>Your Ports</h4>
        <div className="ports-list">
          {playerPorts.map(port => (
            <div 
              key={port.id} 
              className="port-item owned"
              onClick={() => selectPort(port.id)}
            >
              <div className="port-header">
                <span className="port-icon">🏢</span>
                <div className="port-info">
                  <h5>{port.name}</h5>
                  <p>{port.country}</p>
                </div>
              </div>
              
              <div className="port-stats">
                <div className="stat">
                  <span className="stat-label">Capacity</span>
                  <div className="progress-bar">
                    <div 
                      className="progress-fill"
                      style={{ width: `${(port.currentLoad / port.capacity) * 100}%` }}
                    />
                  </div>
                  <span className="stat-value">
                    {Math.round(port.currentLoad)} / {port.capacity}
                  </span>
                </div>
                
                <div className="stat">
                  <span className="stat-label">Berths</span>
                  <span className="stat-value">
                    {port.availableBerths} / {port.berths} available
                  </span>
                </div>
                
                <div className="stat">
                  <span className="stat-label">Loading Speed</span>
                  <span className="stat-value">{port.loadingSpeed} TEU/hr</span>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
      
      <div className="ports-section">
        <h4>Available Ports</h4>
        <div className="ports-list">
          {availablePorts.map(port => (
            <div 
              key={port.id} 
              className="port-item"
              onClick={() => selectPort(port.id)}
            >
              <div className="port-header">
                <span className="port-icon">🏢</span>
                <div className="port-info">
                  <h5>{port.name}</h5>
                  <p>{port.country}</p>
                </div>
              </div>
              
              <div className="port-stats compact">
                <span className="stat-value">{port.berths} berths</span>
                <span className="stat-value">{port.loadingSpeed} TEU/hr</span>
              </div>
              
              <button className="acquire-btn">
                💰 Acquire Port
              </button>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};