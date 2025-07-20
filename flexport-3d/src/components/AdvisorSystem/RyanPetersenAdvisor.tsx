// @ts-nocheck
import React, { useState, useEffect } from 'react';
import { useGameStore } from '../../store/gameStore';
import { ContractStatus } from '../../types/game.types';
import './RyanPetersenAdvisor.css';

interface AdvisorMessage {
  id: string;
  type: 'greeting' | 'tutorial' | 'advice' | 'warning' | 'crisis' | 'gameover';
  message: string;
  priority: 'low' | 'medium' | 'high' | 'critical';
  actions?: Array<{
    label: string;
    callback: () => void;
  }>;
}

export const RyanPetersenAdvisor: React.FC = () => {
  const [messages, setMessages] = useState<AdvisorMessage[]>([]);
  const [currentMessage, setCurrentMessage] = useState<AdvisorMessage | null>(null);
  const [isMinimized, setIsMinimized] = useState(false);
  const [hasShownTutorial, setHasShownTutorial] = useState(false);
  
  const { 
    fleet, 
    contracts, 
    money, 
    reputation, 
    aiDevelopmentLevel,
    isSingularityActive,
    currentDate 
  } = useGameStore();

  // Initial greeting and tutorial
  useEffect(() => {
    if (!hasShownTutorial) {
      const greeting: AdvisorMessage = {
        id: 'intro-1',
        type: 'greeting',
        priority: 'critical',
        message: `Welcome to FlexPort Global! I'm Ryan Petersen, founder and CEO of Flexport. I'll be your advisor in this game.

Here's the situation: You have a limited time to build a global shipping empire before AI achieves singularity. Once that happens... well, let's just say humans won't be running logistics anymore.

Your mission: Dominate global trade before the AI development reaches 100%. Currently at ${aiDevelopmentLevel.toFixed(1)}%.`,
        actions: [
          {
            label: "Tell me more",
            callback: () => showTutorial()
          }
        ]
      };
      
      addMessage(greeting);
      setHasShownTutorial(true);
    }
  }, [hasShownTutorial, aiDevelopmentLevel]);

  const showTutorial = () => {
    const tutorial: AdvisorMessage = {
      id: 'tutorial-1',
      type: 'tutorial',
      priority: 'high',
      message: `Here's how to win:

1. 📦 CONTRACTS: Accept and fulfill shipping contracts to earn money
2. 🚢 FLEET: Buy ships and assign them to routes
3. 📈 GROWTH: Expand to more ports and increase capacity
4. ⚠️ CRISIS: Handle weather, strikes, and other disruptions wisely
5. 🤖 TIME LIMIT: Beat the AI singularity (currently at ${aiDevelopmentLevel.toFixed(1)}%)

Remember: In logistics, reliability beats speed. Don't overextend your fleet!`,
      actions: [
        {
          label: "Got it!",
          callback: () => setCurrentMessage(null)
        }
      ]
    };
    
    setCurrentMessage(tutorial);
  };

  // Contract evaluation
  useEffect(() => {
    const availableContracts = contracts.filter(c => c.status === ContractStatus.AVAILABLE);
    
    availableContracts.forEach(contract => {
      const profitMargin = contract.value / (contract.quantity * 100); // Rough calculation
      const daysUntilDeadline = Math.ceil((contract.deadline.getTime() - Date.now()) / (1000 * 60 * 60 * 24));
      
      if (profitMargin > 50 && daysUntilDeadline > 10) {
        const advice: AdvisorMessage = {
          id: `contract-advice-${contract.id}`,
          type: 'advice',
          priority: 'medium',
          message: `💡 Great opportunity! The ${contract.cargo} contract from ${contract.origin.name} to ${contract.destination.name} has excellent margins ($${contract.value.toLocaleString()}). With ${daysUntilDeadline} days until deadline, this is very achievable.`,
        };
        
        addMessage(advice);
      } else if (daysUntilDeadline < 5 && fleet.filter(s => s.status === 'IDLE').length > 0) {
        const warning: AdvisorMessage = {
          id: `contract-warning-${contract.id}`,
          type: 'warning',
          priority: 'medium',
          message: `⚠️ Tight deadline on the ${contract.origin.name} contract - only ${daysUntilDeadline} days! Only take this if you have a fast ship nearby.`,
        };
        
        addMessage(warning);
      }
    });
  }, [contracts, fleet]);

  // Fleet management advice
  useEffect(() => {
    const idleShips = fleet.filter(s => s.status === 'IDLE').length;
    const totalShips = fleet.length;
    
    if (idleShips > totalShips * 0.5 && totalShips > 2) {
      const advice: AdvisorMessage = {
        id: 'fleet-idle-warning',
        type: 'warning',
        priority: 'high',
        message: `📊 You have ${idleShips} idle ships! That's burning money. Either assign them to contracts or consider selling some to reduce maintenance costs.`,
      };
      
      addMessage(advice);
    }
    
    if (money > 10000000 && fleet.length < 3) {
      const advice: AdvisorMessage = {
        id: 'fleet-expansion',
        type: 'advice',
        priority: 'medium',
        message: `💰 You have $${(money / 1000000).toFixed(1)}M in cash. Consider expanding your fleet to handle more contracts. Remember: in logistics, capacity is king!`,
      };
      
      addMessage(advice);
    }
  }, [fleet, money]);

  // AI singularity warnings
  useEffect(() => {
    if (aiDevelopmentLevel > 90) {
      const warning: AdvisorMessage = {
        id: 'ai-critical',
        type: 'warning',
        priority: 'critical',
        message: `🚨 CRITICAL: AI development at ${aiDevelopmentLevel.toFixed(1)}%! You're running out of time. Focus on high-value contracts and rapid expansion NOW!`,
      };
      
      addMessage(warning);
    } else if (aiDevelopmentLevel > 75) {
      const warning: AdvisorMessage = {
        id: 'ai-warning',
        type: 'warning',
        priority: 'high',
        message: `⏰ AI development at ${aiDevelopmentLevel.toFixed(1)}%. The singularity is approaching faster than expected. Pick up the pace!`,
      };
      
      addMessage(warning);
    }
  }, [aiDevelopmentLevel]);

  // Game over analysis
  useEffect(() => {
    if (isSingularityActive) {
      const gameOver: AdvisorMessage = {
        id: 'game-over',
        type: 'gameover',
        priority: 'critical',
        message: `Well, the AI has achieved singularity. Humans are now in zoos, as I warned.

Your final stats:
💰 Money: $${money.toLocaleString()}
⭐ Reputation: ${reputation}%
🚢 Fleet Size: ${fleet.length} ships

What you could have done better:
${analyzePerformance()}

Want to try again? Remember: move fast and break things... except ships!`,
        actions: [
          {
            label: "Try Again",
            callback: () => window.location.reload()
          }
        ]
      };
      
      setCurrentMessage(gameOver);
    }
  }, [isSingularityActive, money, reputation, fleet]);

  const analyzePerformance = (): string => {
    const tips = [];
    
    if (fleet.length < 5) {
      tips.push("• Build a larger fleet earlier - you needed more capacity");
    }
    if (reputation < 70) {
      tips.push("• Handle crisis events better to maintain reputation");
    }
    if (money < 100000000) {
      tips.push("• Focus on high-margin contracts and efficient routes");
    }
    
    const completedContracts = contracts.filter(c => c.status === 'COMPLETED').length;
    if (completedContracts < 20) {
      tips.push("• Complete more contracts - volume drives growth");
    }
    
    return tips.join('\n') || "• You played well, but the AI was just too fast this time";
  };

  const addMessage = (message: AdvisorMessage) => {
    setMessages(prev => {
      // Don't duplicate messages
      if (prev.some(m => m.id === message.id)) return prev;
      
      // Keep only last 10 messages
      const updated = [...prev, message].slice(-10);
      
      // Auto-show high priority messages
      if (message.priority === 'critical' || message.priority === 'high') {
        setCurrentMessage(message);
        setIsMinimized(false);
      }
      
      return updated;
    });
  };

  // Crisis response analysis
  const handleCrisisResponse = (crisisType: string, choice: string, outcome: any) => {
    const analysis: AdvisorMessage = {
      id: `crisis-analysis-${Date.now()}`,
      type: 'crisis',
      priority: 'medium',
      message: `📊 Crisis Analysis: ${crisisType}

Your choice: ${choice}
Outcome: ${outcome.financial > 0 ? 'Profit' : 'Loss'} of $${Math.abs(outcome.financial).toLocaleString()}

${getCrisisAdvice(crisisType, choice, outcome)}`,
    };
    
    addMessage(analysis);
  };

  const getCrisisAdvice = (type: string, choice: string, outcome: any): string => {
    if (type === 'UNION_NEGOTIATION') {
      if (choice === 'pay_off_leader') {
        return "Paying off leaders works short-term but breeds corruption. Consider fair wages next time.";
      } else if (choice === 'raise_wages') {
        return "Good choice! Happy workers are productive workers. This will pay off long-term.";
      } else {
        return "Calling their bluff rarely works. Labor has more power than you think.";
      }
    }
    return "Every crisis is a learning opportunity. Analyze what worked and adapt.";
  };

  if (!currentMessage && isMinimized) {
    return (
      <button 
        className="advisor-toggle"
        onClick={() => setIsMinimized(false)}
        title="Ryan Petersen - Advisor"
      >
        <img src="/ryan-petersen-avatar.svg" alt="Ryan" />
        {messages.filter(m => m.priority === 'high' || m.priority === 'critical').length > 0 && (
          <span className="notification-badge">!</span>
        )}
      </button>
    );
  }

  if (!currentMessage) {
    return (
      <div className="advisor-panel">
        <div className="advisor-header">
          <img src="/ryan-petersen-avatar.svg" alt="Ryan Petersen" className="advisor-avatar" />
          <div className="advisor-info">
            <h3>Ryan Petersen</h3>
            <p>CEO & Founder, Flexport</p>
          </div>
          <button className="minimize-btn" onClick={() => setIsMinimized(true)}>−</button>
        </div>
        
        <div className="advisor-status">
          <div className="status-item">
            <span className="label">AI Progress:</span>
            <div className="ai-progress-bar">
              <div 
                className="ai-progress-fill"
                style={{ width: `${aiDevelopmentLevel}%` }}
              />
            </div>
            <span className="value">{aiDevelopmentLevel.toFixed(1)}%</span>
          </div>
        </div>
        
        <div className="recent-messages">
          <h4>Recent Advice</h4>
          {messages.slice(-3).reverse().map(msg => (
            <div 
              key={msg.id} 
              className={`message-preview ${msg.priority}`}
              onClick={() => setCurrentMessage(msg)}
            >
              <span className="message-type">{msg.type}</span>
              <p>{msg.message.substring(0, 100)}...</p>
            </div>
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className={`advisor-modal ${currentMessage.priority}`}>
      <div className="advisor-modal-content">
        <div className="advisor-modal-header">
          <img src="/ryan-petersen-avatar.svg" alt="Ryan Petersen" className="advisor-avatar-large" />
          <div>
            <h2>Ryan Petersen</h2>
            <p>Strategic Advisor</p>
          </div>
        </div>
        
        <div className="advisor-message">
          <p>{currentMessage.message}</p>
        </div>
        
        <div className="advisor-actions">
          {currentMessage.actions ? (
            currentMessage.actions.map((action, index) => (
              <button 
                key={index}
                className="advisor-action-btn"
                onClick={() => {
                  action.callback();
                  setCurrentMessage(null);
                }}
              >
                {action.label}
              </button>
            ))
          ) : (
            <button 
              className="advisor-action-btn"
              onClick={() => setCurrentMessage(null)}
            >
              Got it
            </button>
          )}
        </div>
      </div>
    </div>
  );
};