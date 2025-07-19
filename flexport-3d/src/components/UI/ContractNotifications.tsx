// @ts-nocheck
import React, { useState, useEffect } from 'react';
import { useGameStore } from '../../store/gameStore';
import { Contract, ContractStatus } from '../../types/game.types';
import './ContractNotifications.css';

interface Notification {
  id: string;
  contract: Contract;
  timestamp: Date;
  isNew: boolean;
}

export const ContractNotifications: React.FC = () => {
  const { contracts, acceptContract, fleet } = useGameStore();
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [seenContracts, setSeenContracts] = useState<Set<string>>(new Set());

  useEffect(() => {
    // Track new contracts
    const availableContracts = contracts.filter(c => c.status === ContractStatus.AVAILABLE);
    const newNotifications: Notification[] = [];

    availableContracts.forEach(contract => {
      if (!seenContracts.has(contract.id)) {
        newNotifications.push({
          id: `notif-${contract.id}-${Date.now()}`,
          contract,
          timestamp: new Date(),
          isNew: true
        });
      }
    });

    if (newNotifications.length > 0) {
      setNotifications(prev => [...newNotifications, ...prev].slice(0, 10)); // Keep last 10
      setSeenContracts(prev => {
        const newSet = new Set(prev);
        newNotifications.forEach(n => newSet.add(n.contract.id));
        return newSet;
      });

      // Auto-hide "new" status after 5 seconds
      setTimeout(() => {
        setNotifications(prev => 
          prev.map(n => ({ ...n, isNew: false }))
        );
      }, 5000);
    }
  }, [contracts, seenContracts]);

  const handleAccept = (contract: Contract) => {
    acceptContract(contract.id);
    setNotifications(prev => prev.filter(n => n.contract.id !== contract.id));
  };

  const getTimeAgo = (date: Date) => {
    const seconds = Math.floor((new Date().getTime() - date.getTime()) / 1000);
    if (seconds < 60) return 'Just now';
    if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
    if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
    return `${Math.floor(seconds / 86400)}d ago`;
  };

  const getUrgencyColor = (contract: Contract) => {
    const daysUntilDeadline = Math.floor(
      (contract.deadline.getTime() - new Date().getTime()) / (1000 * 60 * 60 * 24)
    );
    if (daysUntilDeadline < 3) return '#ef4444';
    if (daysUntilDeadline < 7) return '#f59e0b';
    return '#10b981';
  };

  const availableShips = fleet.filter(s => s.status === 'IDLE' && s.capacity >= 100);

  return (
    <div className="contract-notifications">
      <div className="notifications-header">
        <h3>📋 Contract Opportunities</h3>
        <span className="notification-count">{notifications.length}</span>
      </div>

      <div className="notifications-list">
        {notifications.length === 0 ? (
          <div className="no-notifications">
            <p>No new contracts available</p>
          </div>
        ) : (
          notifications.map(notification => (
            <div 
              key={notification.id}
              className={`notification-card ${notification.isNew ? 'new' : ''} ${
                expandedId === notification.id ? 'expanded' : ''
              }`}
            >
              {notification.isNew && <div className="new-badge">NEW</div>}
              
              <div className="notification-header">
                <div className="route-info">
                  <h4>
                    {notification.contract.origin.name} → {notification.contract.destination.name}
                  </h4>
                  <span className="cargo-type">{notification.contract.cargo}</span>
                </div>
                <button
                  className="expand-button"
                  onClick={() => setExpandedId(
                    expandedId === notification.id ? null : notification.id
                  )}
                >
                  {expandedId === notification.id ? '▼' : '▶'}
                </button>
              </div>

              <div className="notification-summary">
                <div className="contract-value">
                  💰 ${notification.contract.value.toLocaleString()}
                </div>
                <div className="contract-volume">
                  📦 {notification.contract.quantity} TEU
                </div>
                <div 
                  className="deadline"
                  style={{ color: getUrgencyColor(notification.contract) }}
                >
                  ⏰ {Math.floor(
                    (notification.contract.deadline.getTime() - new Date().getTime()) / 
                    (1000 * 60 * 60 * 24)
                  )} days
                </div>
              </div>

              {expandedId === notification.id && (
                <div className="notification-details">
                  <div className="detail-row">
                    <span>Client:</span>
                    <span>{notification.contract.client}</span>
                  </div>
                  <div className="detail-row">
                    <span>Payment Terms:</span>
                    <span>On delivery</span>
                  </div>
                  <div className="detail-row">
                    <span>Available Ships:</span>
                    <span className={availableShips.length > 0 ? 'available' : 'unavailable'}>
                      {availableShips.length} ships ready
                    </span>
                  </div>
                  
                  <div className="notification-actions">
                    <button 
                      className="accept-button"
                      onClick={() => handleAccept(notification.contract)}
                      disabled={availableShips.length === 0}
                    >
                      ✅ Accept Contract
                    </button>
                    <button 
                      className="dismiss-button"
                      onClick={() => setNotifications(prev => 
                        prev.filter(n => n.id !== notification.id)
                      )}
                    >
                      ❌ Dismiss
                    </button>
                  </div>
                </div>
              )}

              <div className="notification-time">
                {getTimeAgo(notification.timestamp)}
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
};