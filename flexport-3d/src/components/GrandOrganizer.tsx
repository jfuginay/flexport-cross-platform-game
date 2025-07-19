import React, { useState, useEffect, useCallback } from 'react';
import { useGameStore } from '../store/gameStore';
import './GrandOrganizer.css';

interface AdvisorMessage {
  id: string;
  type: 'tip' | 'warning' | 'disaster' | 'congratulation' | 'technical' | 'strategic';
  title: string;
  message: string;
  priority: number;
  duration?: number;
  advisor: 'ryan' | 'austen' | 'ash' | 'rebecca';
}

interface Advisor {
  id: string;
  name: string;
  title: string;
  role: string;
  avatarColor: string;
  borderColor: string;
}

export const GrandOrganizer: React.FC = () => {
  const [isVisible, setIsVisible] = useState(false);
  const [currentMessage, setCurrentMessage] = useState<AdvisorMessage | null>(null);
  const [messageQueue, setMessageQueue] = useState<AdvisorMessage[]>([]);
  const [hasIntroduced, setHasIntroduced] = useState({
    ryan: false,
    austen: false,
    ash: false,
    rebecca: false
  });
  
  const { 
    money, 
    fleet, 
    contracts, 
    reputation 
  } = useGameStore();

  // Advisor configurations
  const advisors: Record<string, Advisor> = {
    ryan: {
      id: 'ryan',
      name: 'Ryan Petersen',
      title: 'Chairman & CEO of FlexPort',
      role: 'Supply Chain Revolution & Industry Leadership',
      avatarColor: '#10b981',
      borderColor: '#059669'
    },
    austen: {
      id: 'austen',
      name: 'Austen Allred',
      title: 'Grand Master Orchestrator',
      role: 'AI Engineering Excellence',
      avatarColor: '#8b5cf6',
      borderColor: '#7c3aed'
    },
    ash: {
      id: 'ash',
      name: 'Ash Furrow',
      title: 'Chief Technical Strategist',
      role: 'System Architecture & Innovation',
      avatarColor: '#06b6d4',
      borderColor: '#0891b2'
    },
    rebecca: {
      id: 'rebecca',
      name: 'Rebecca Metters',
      title: 'Grand Organizer',
      role: 'Operations & Logistics',
      avatarColor: '#3b82f6',
      borderColor: '#2563eb'
    }
  };

  // Add message to queue
  const addMessage = useCallback((message: AdvisorMessage) => {
    setMessageQueue(prev => [...prev, message].sort((a, b) => b.priority - a.priority));
  }, []);

  // Introduction messages - FlexPort CEO first, then cascade down
  useEffect(() => {
    if (!hasIntroduced.ryan) {
      setTimeout(() => {
        const ryanIntro: AdvisorMessage = {
          id: 'intro-ryan',
          type: 'strategic',
          title: 'Welcome to FlexPort',
          message: "Welcome to FlexPort! I'm Ryan Petersen, CEO. We're revolutionizing global trade by making it easy to move freight anywhere in the world. With our AI-powered platform and expert team, you'll build the most efficient shipping empire ever created. Let's fix the user experience of global trade together!",
          priority: 10,
          duration: 10000,
          advisor: 'ryan'
        };
        addMessage(ryanIntro);
        setHasIntroduced(prev => ({ ...prev, ryan: true }));
      }, 1000);
    } else if (hasIntroduced.ryan && !hasIntroduced.austen) {
      setTimeout(() => {
        const austenIntro: AdvisorMessage = {
          id: 'intro-austen',
          type: 'technical',
          title: 'AI Systems Online',
          message: "Greetings! I'm Austen Allred, your Grand Master Orchestrator of AI Engineering. I'll ensure our AI systems optimize every aspect of your fleet. Let's build something extraordinary together.",
          priority: 9,
          duration: 8000,
          advisor: 'austen'
        };
        addMessage(austenIntro);
        setHasIntroduced(prev => ({ ...prev, austen: true }));
      }, 12000);
    } else if (hasIntroduced.austen && !hasIntroduced.ash) {
      setTimeout(() => {
        const ashIntro: AdvisorMessage = {
          id: 'intro-ash',
          type: 'technical',
          title: 'Technical Systems Ready',
          message: "Hey there! Ash Furrow here, Chief Technical Strategist. I'll help you architect efficient shipping routes and maintain your fleet's technical excellence. Let's optimize!",
          priority: 8,
          duration: 7000,
          advisor: 'ash'
        };
        addMessage(ashIntro);
        setHasIntroduced(prev => ({ ...prev, ash: true }));
      }, 21000);
    } else if (hasIntroduced.ash && !hasIntroduced.rebecca) {
      setTimeout(() => {
        const rebeccaIntro: AdvisorMessage = {
          id: 'intro-rebecca',
          type: 'tip',
          title: 'Operations Support Ready',
          message: "Hi! I'm Rebecca Metters, your Grand Organizer. I'll handle the day-to-day operations and keep you informed about weather, port conditions, and opportunities. Let's get your first ship!",
          priority: 7,
          duration: 7000,
          advisor: 'rebecca'
        };
        addMessage(rebeccaIntro);
        setHasIntroduced(prev => ({ ...prev, rebecca: true }));
      }, 29000);
    }
  }, [hasIntroduced, addMessage]);

  // Process message queue
  useEffect(() => {
    if (!currentMessage && messageQueue.length > 0) {
      const [next, ...rest] = messageQueue;
      setCurrentMessage(next);
      setMessageQueue(rest);
      setIsVisible(true);

      // Auto-hide after duration
      if (next.duration) {
        const timer = setTimeout(() => {
          setIsVisible(false);
          setTimeout(() => setCurrentMessage(null), 300);
        }, next.duration);
        return () => clearTimeout(timer);
      }
    }
  }, [currentMessage, messageQueue]);

  // Monitor game state for advice
  useEffect(() => {
    // Strategic advice from CEO for major milestones
    if (money > 10000000 && fleet.length > 5 && !messageQueue.find(m => m.id === 'ceo-milestone')) {
      addMessage({
        id: 'ceo-milestone',
        type: 'strategic',
        title: 'Exceptional Progress',
        message: "Outstanding work building your fleet. You've proven yourself capable of handling complex operations. Now let's scale globally and dominate the shipping industry. The world is waiting for FlexPort's innovation.",
        priority: 9,
        duration: 10000,
        advisor: 'ryan'
      });
    }

    // Technical optimization from Austen
    if (fleet.length > 3 && !messageQueue.find(m => m.id === 'ai-optimization')) {
      addMessage({
        id: 'ai-optimization',
        type: 'technical',
        title: 'AI Optimization Available',
        message: 'Your fleet has reached critical mass. I can now deploy advanced AI algorithms to optimize routes and reduce fuel consumption by up to 15%. Check the Research panel for AI upgrades.',
        priority: 6,
        duration: 8000,
        advisor: 'austen'
      });
    }

    // Architecture advice from Ash
    if (contracts.filter(c => c.status === 'ACTIVE').length > 5) {
      addMessage({
        id: 'route-architecture',
        type: 'technical',
        title: 'Route Architecture Analysis',
        message: "I've analyzed your shipping routes. Consider implementing a hub-and-spoke model to reduce transit times. Shanghai and Rotterdam would make excellent hub ports for your operations.",
        priority: 5,
        duration: 7000,
        advisor: 'ash'
      });
    }

    // Operational advice from Rebecca
    if (money < 100000 && fleet.length > 0) {
      addMessage({
        id: 'low-balance',
        type: 'warning',
        title: 'Low Balance Alert!',
        message: 'Your funds are running low. Consider completing more contracts or selling underperforming ships to improve cash flow.',
        priority: 7,
        duration: 6000,
        advisor: 'rebecca'
      });
    }

    // No active contracts
    if (contracts.filter(c => c.status === 'ACTIVE').length === 0 && fleet.length > 0) {
      addMessage({
        id: 'no-contracts',
        type: 'tip',
        title: 'No Active Contracts',
        message: 'You have ships but no active contracts! Visit the contracts panel to find profitable routes for your fleet.',
        priority: 6,
        duration: 5000,
        advisor: 'rebecca'
      });
    }
  }, [money, fleet.length, contracts, reputation, addMessage, messageQueue]);

  // Disaster warnings (mock implementation - integrate with actual disaster system)
  useEffect(() => {
    const disasterCheck = setInterval(() => {
      const random = Math.random();
      
      // 5% chance of storm warning
      if (random < 0.05) {
        addMessage({
          id: `storm-${Date.now()}`,
          type: 'disaster',
          title: '🌪️ Storm Warning!',
          message: 'Severe weather detected in the Pacific Ocean! Ships in the area may experience delays. Consider rerouting to safer waters.',
          priority: 9,
          duration: 8000,
          advisor: 'rebecca'
        });
      }
      
      // 3% chance of port congestion
      if (random > 0.95 && random < 0.98) {
        addMessage({
          id: `congestion-${Date.now()}`,
          type: 'warning',
          title: '🚢 Port Congestion',
          message: 'Shanghai port is experiencing heavy congestion. Expect loading delays of 2-3 days for ships docking there.',
          priority: 6,
          duration: 7000,
          advisor: 'rebecca'
        });
      }
    }, 30000); // Check every 30 seconds

    return () => clearInterval(disasterCheck);
  }, [addMessage]);

  const handleClose = () => {
    setIsVisible(false);
    setTimeout(() => setCurrentMessage(null), 300);
  };

  if (!currentMessage) return null;

  return (
    <div className={`grand-organizer ${isVisible ? 'visible' : ''} ${currentMessage.type}`}>
      <div className="advisor-portrait">
        <div className="portrait-frame">
          <div 
            className="portrait-image"
            style={{ 
              background: advisors[currentMessage.advisor].avatarColor,
              boxShadow: `0 0 20px ${advisors[currentMessage.advisor].borderColor}80`
            }}
          >
            {/* Animated character representation */}
            <div className="advisor-avatar">
              <div className="avatar-head">
                <div className="avatar-hair"></div>
                <div className="avatar-face">
                  <div className="avatar-eyes">
                    <div className="eye left"></div>
                    <div className="eye right"></div>
                  </div>
                  <div className="avatar-mouth"></div>
                </div>
              </div>
              <div 
                className="avatar-body"
                style={{ background: advisors[currentMessage.advisor].avatarColor }}
              ></div>
            </div>
          </div>
          <div className="portrait-name">{advisors[currentMessage.advisor].name}</div>
          <div className="portrait-title">{advisors[currentMessage.advisor].title}</div>
        </div>
      </div>
      
      <div className="advisor-message">
        <div className="message-header">
          <h3>{currentMessage.title}</h3>
          <button className="close-btn" onClick={handleClose}>×</button>
        </div>
        <div className="message-content">
          <p>{currentMessage.message}</p>
        </div>
        
        {currentMessage.type === 'disaster' && (
          <div className="message-actions">
            <button className="action-btn primary">View Map</button>
            <button className="action-btn secondary">Dismiss</button>
          </div>
        )}
      </div>
      
      {/* Message queue indicator */}
      {messageQueue.length > 0 && (
        <div className="queue-indicator">
          +{messageQueue.length} more messages
        </div>
      )}
    </div>
  );
};