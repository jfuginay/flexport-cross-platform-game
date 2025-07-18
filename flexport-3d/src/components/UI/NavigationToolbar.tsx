import React, { useState } from 'react';
import './NavigationToolbar.css';

interface NavigationToolbarProps {
  onNavigate: (section: string) => void;
  activeSection: string;
}

export const NavigationToolbar: React.FC<NavigationToolbarProps> = ({ onNavigate, activeSection }) => {
  const [isExpanded, setIsExpanded] = useState(false);

  const navItems = [
    { id: 'overview', icon: '🌍', label: 'Overview', description: 'World view & status' },
    { id: 'fleet', icon: '🚢', label: 'Fleet', description: 'Manage your ships' },
    { id: 'contracts', icon: '📋', label: 'Contracts', description: 'Available & active contracts' },
    { id: 'research', icon: '🧠', label: 'AI Research', description: 'Market trends & insights' },
    { id: 'ports', icon: '🏢', label: 'Ports', description: 'Port management' },
    { id: 'multiplayer', icon: '👥', label: 'Multiplayer', description: 'Join or create games' },
    { id: 'finances', icon: '💰', label: 'Finances', description: 'Revenue & expenses' },
    { id: 'settings', icon: '⚙️', label: 'Settings', description: 'Game preferences' },
  ];

  return (
    <div className={`navigation-toolbar ${isExpanded ? 'expanded' : ''}`}>
      <button 
        className="toolbar-toggle"
        onClick={() => setIsExpanded(!isExpanded)}
        title={isExpanded ? 'Collapse toolbar' : 'Expand toolbar'}
      >
        {isExpanded ? '◀' : '▶'}
      </button>

      <div className="nav-items">
        {navItems.map(item => (
          <button
            key={item.id}
            className={`nav-item ${activeSection === item.id ? 'active' : ''}`}
            onClick={() => onNavigate(item.id)}
            title={item.description}
          >
            <span className="nav-icon">{item.icon}</span>
            {isExpanded && (
              <>
                <span className="nav-label">{item.label}</span>
                <span className="nav-description">{item.description}</span>
              </>
            )}
          </button>
        ))}
      </div>

      {isExpanded && (
        <div className="toolbar-footer">
          <div className="quick-stats">
            <div className="stat">
              <span className="stat-label">Fleet Status</span>
              <span className="stat-value">12/15 Active</span>
            </div>
            <div className="stat">
              <span className="stat-label">New Contracts</span>
              <span className="stat-value notification-badge">3</span>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};