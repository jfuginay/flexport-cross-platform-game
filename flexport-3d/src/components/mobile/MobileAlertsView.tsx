import React from 'react';
import { useGameStore } from '../../store/gameStore';
import './MobileAlertsView.css';

interface MobileAlertsViewProps {
  onClose?: () => void;
}

interface Alert {
  id: string;
  type: 'success' | 'warning' | 'info' | 'danger';
  title: string;
  message: string;
  timestamp: Date;
  shipId?: string;
  contractId?: string;
}

export const MobileAlertsView: React.FC<MobileAlertsViewProps> = ({ onClose }) => {
  const { fleet, contracts, ports } = useGameStore();
  
  const generateAlerts = (): Alert[] => {
    const alerts: Alert[] = [];
    
    // Check for completed deliveries
    fleet.forEach(ship => {
      if (ship.status === 'UNLOADING') {
        const port = ports.find(p => p.id === ship.currentPortId);
        alerts.push({
          id: `unloading-${ship.id}`,
          type: 'success',
          title: 'Delivery in Progress',
          message: `${ship.name} is unloading cargo at ${port?.name || 'Unknown Port'}`,
          timestamp: new Date(),
          shipId: ship.id
        });
      }
      
      // Check for idle ships
      if (ship.status === 'IDLE' && ship.cargo.length === 0) {
        const port = ports.find(p => p.id === ship.currentPortId);
        alerts.push({
          id: `idle-${ship.id}`,
          type: 'warning',
          title: 'Ship Idle',
          message: `${ship.name} is idle at ${port?.name || 'Unknown Port'}. Consider accepting a new contract.`,
          timestamp: new Date(),
          shipId: ship.id
        });
      }
    });
    
    // Check for expiring contracts
    contracts.forEach(contract => {
      if (contract.status === 'AVAILABLE') {
        const daysUntilDeadline = Math.ceil((contract.deadline.getTime() - new Date().getTime()) / (1000 * 60 * 60 * 24));
        if (daysUntilDeadline <= 2) {
          alerts.push({
            id: `expiring-${contract.id}`,
            type: 'danger',
            title: 'Contract Expiring Soon',
            message: `Contract from ${contract.origin.name} expires in ${daysUntilDeadline} days!`,
            timestamp: new Date(),
            contractId: contract.id
          });
        }
      }
    });
    
    // Check for new high-value contracts
    const highValueContracts = contracts.filter(
      c => c.status === 'AVAILABLE' && c.value > 50000
    );
    
    highValueContracts.forEach(contract => {
      alerts.push({
        id: `highvalue-${contract.id}`,
        type: 'info',
        title: 'High-Value Contract Available',
        message: `Profitable route: ${contract.origin.name} to ${contract.destination.name} - $${contract.value.toLocaleString()}`,
        timestamp: new Date(),
        contractId: contract.id
      });
    });
    
    return alerts.sort((a, b) => b.timestamp.getTime() - a.timestamp.getTime());
  };
  
  const alerts = generateAlerts();
  
  const getAlertIcon = (type: Alert['type']) => {
    switch (type) {
      case 'success':
        return '✓';
      case 'warning':
        return '!';
      case 'danger':
        return '⚠';
      case 'info':
        return 'i';
    }
  };
  
  const formatTime = (date: Date) => {
    const now = new Date();
    const diff = now.getTime() - date.getTime();
    const minutes = Math.floor(diff / 60000);
    
    if (minutes < 1) return 'Just now';
    if (minutes < 60) return `${minutes}m ago`;
    const hours = Math.floor(minutes / 60);
    if (hours < 24) return `${hours}h ago`;
    return `${Math.floor(hours / 24)}d ago`;
  };

  return (
    <div className="mobile-alerts-view">
      <div className="mobile-header">
        <h2>Alerts & Notifications</h2>
        <button className="mobile-close-btn" onClick={onClose}>×</button>
      </div>
      
      <div className="alerts-list">
        {alerts.map(alert => (
          <div key={alert.id} className={`alert-card alert-${alert.type}`}>
            <div className="alert-icon">
              {getAlertIcon(alert.type)}
            </div>
            <div className="alert-content">
              <div className="alert-header">
                <h3 className="alert-title">{alert.title}</h3>
                <span className="alert-time">{formatTime(alert.timestamp)}</span>
              </div>
              <p className="alert-message">{alert.message}</p>
            </div>
          </div>
        ))}
      </div>
      
      {alerts.length === 0 && (
        <div className="empty-state">
          <p>No alerts at this time</p>
          <p className="empty-hint">You'll see important updates about your fleet here.</p>
        </div>
      )}
    </div>
  );
};