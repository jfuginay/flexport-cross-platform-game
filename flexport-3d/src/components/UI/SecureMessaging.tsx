import React, { useState, useEffect } from 'react';
import { Lock, AlertTriangle, Clock, Shield, X, Send } from 'lucide-react';
import { executiveNotificationService, SecureMessage } from '../../services/executiveNotificationService';
import './SecureMessaging.css';

interface SecureMessagingProps {
  isOpen: boolean;
  onClose: () => void;
}

export const SecureMessaging: React.FC<SecureMessagingProps> = ({ isOpen, onClose }) => {
  const [messages, setMessages] = useState<SecureMessage[]>([]);
  const [selectedMessage, setSelectedMessage] = useState<SecureMessage | null>(null);
  const [isAnimating, setIsAnimating] = useState(false);

  useEffect(() => {
    const unsubscribe = executiveNotificationService.subscribe((newMessage) => {
      setMessages(prev => [newMessage, ...prev]);
      setIsAnimating(true);
      setTimeout(() => setIsAnimating(false), 500);
    });

    setMessages(executiveNotificationService.getMessages());

    return unsubscribe;
  }, []);

  const handleAction = (messageId: string, action: string) => {
    executiveNotificationService.respondToMessage(messageId, action);
    setSelectedMessage(null);
  };

  const formatTime = (date: Date) => {
    const now = new Date();
    const diff = now.getTime() - new Date(date).getTime();
    const minutes = Math.floor(diff / 60000);
    
    if (minutes < 1) return 'Just now';
    if (minutes < 60) return `${minutes}m ago`;
    if (minutes < 1440) return `${Math.floor(minutes / 60)}h ago`;
    return `${Math.floor(minutes / 1440)}d ago`;
  };

  if (!isOpen) return null;

  return (
    <div className="secure-messaging-overlay">
      <div className={`secure-messaging-container ${isAnimating ? 'pulse' : ''}`}>
        <div className="secure-header">
          <div className="header-left">
            <Shield className="shield-icon" />
            <h2>Secure Executive Channel</h2>
            <Lock className="lock-icon" />
          </div>
          <button className="close-button" onClick={onClose}>
            <X />
          </button>
        </div>

        <div className="messages-container">
          <div className="message-list">
            {messages.map((message) => (
              <div
                key={message.id}
                className={`message-item ${message.priority} ${selectedMessage?.id === message.id ? 'selected' : ''}`}
                onClick={() => setSelectedMessage(message)}
              >
                <div className="message-header">
                  <div className="sender-info">
                    <span className="sender-name">{message.sender}</span>
                    <span className="sender-title">{message.senderTitle}</span>
                  </div>
                  <div className="message-meta">
                    {message.priority === 'URGENT' && <AlertTriangle className="urgent-icon" />}
                    <span className="timestamp">{formatTime(message.timestamp)}</span>
                  </div>
                </div>
                <div className="message-subject">{message.subject}</div>
                {message.expiresAt && (
                  <div className="expires-warning">
                    <Clock size={14} />
                    <span>Response required within {Math.floor((new Date(message.expiresAt).getTime() - Date.now()) / 60000)} minutes</span>
                  </div>
                )}
              </div>
            ))}
          </div>

          {selectedMessage && (
            <div className="message-detail">
              <div className="detail-header">
                <h3>{selectedMessage.subject}</h3>
                <div className="encryption-badge">
                  <Lock size={14} />
                  <span>End-to-End Encrypted</span>
                </div>
              </div>
              
              <div className="detail-sender">
                <div className="sender-avatar">
                  {selectedMessage.sender.split(' ').map(n => n[0]).join('')}
                </div>
                <div>
                  <div className="sender-name">{selectedMessage.sender}</div>
                  <div className="sender-title">{selectedMessage.senderTitle}</div>
                </div>
              </div>

              <div className="message-content">
                <p>{selectedMessage.message}</p>
              </div>

              {selectedMessage.actions && selectedMessage.actions.length > 0 && (
                <div className="action-buttons">
                  {selectedMessage.actions.map((action, index) => (
                    <button
                      key={index}
                      className={`action-button ${action.action}`}
                      onClick={() => handleAction(selectedMessage.id, action.action)}
                    >
                      <Send size={16} />
                      <span>{action.label}</span>
                    </button>
                  ))}
                </div>
              )}
            </div>
          )}
        </div>

        <div className="secure-footer">
          <div className="security-indicators">
            <div className="indicator active">
              <div className="indicator-dot"></div>
              <span>Encrypted</span>
            </div>
            <div className="indicator active">
              <div className="indicator-dot"></div>
              <span>Authenticated</span>
            </div>
            <div className="indicator active">
              <div className="indicator-dot"></div>
              <span>Secure Channel</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};