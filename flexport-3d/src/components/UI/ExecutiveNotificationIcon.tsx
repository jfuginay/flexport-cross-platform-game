import React, { useState, useEffect } from 'react';
import { Shield, Bell } from 'lucide-react';
import { executiveNotificationService } from '../../services/executiveNotificationService';
import './ExecutiveNotificationIcon.css';

interface ExecutiveNotificationIconProps {
  onClick: () => void;
}

export const ExecutiveNotificationIcon: React.FC<ExecutiveNotificationIconProps> = ({ onClick }) => {
  const [hasUnread, setHasUnread] = useState(false);
  const [urgentCount, setUrgentCount] = useState(0);
  const [isAnimating, setIsAnimating] = useState(false);

  useEffect(() => {
    const unsubscribe = executiveNotificationService.subscribe((message) => {
      setHasUnread(true);
      if (message.priority === 'URGENT') {
        setUrgentCount(prev => prev + 1);
        setIsAnimating(true);
        setTimeout(() => setIsAnimating(false), 1000);
      }
    });

    return unsubscribe;
  }, []);

  const handleClick = () => {
    onClick();
    setHasUnread(false);
    setUrgentCount(0);
  };

  return (
    <button 
      className={`executive-notification-icon ${hasUnread ? 'has-unread' : ''} ${isAnimating ? 'animating' : ''}`}
      onClick={handleClick}
      title="Secure Executive Messages"
    >
      <Shield className="shield-base" />
      {urgentCount > 0 && (
        <div className="urgent-badge">{urgentCount}</div>
      )}
      {hasUnread && (
        <div className="notification-pulse"></div>
      )}
    </button>
  );
};