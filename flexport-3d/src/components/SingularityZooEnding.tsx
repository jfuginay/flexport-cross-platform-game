// @ts-nocheck
import React, { useEffect, useState } from 'react';
import { useGameStore } from '../store/gameStore';
import { useAIPlayerStore } from '../store/aiPlayerStore';
import './SingularityZooEnding.css';

export const SingularityZooEnding: React.FC = () => {
  const { companyName, money, reputation, fleet } = useGameStore();
  const { singularityProgress } = useAIPlayerStore();
  const [showEnding, setShowEnding] = useState(false);
  const [endingPhase, setEndingPhase] = useState<'warning' | 'takeover' | 'zoo'>('warning');
  
  useEffect(() => {
    if (singularityProgress >= 100) {
      setShowEnding(true);
      startEndingSequence();
    }
  }, [singularityProgress]);
  
  const startEndingSequence = async () => {
    // Phase 1: Warning
    setEndingPhase('warning');
    await new Promise(resolve => setTimeout(resolve, 3000));
    
    // Phase 2: AI Takeover
    setEndingPhase('takeover');
    await new Promise(resolve => setTimeout(resolve, 5000));
    
    // Phase 3: Zoo
    setEndingPhase('zoo');
  };
  
  if (!showEnding) return null;
  
  return (
    <div className="singularity-ending-overlay">
      {endingPhase === 'warning' && (
        <div className="ending-content warning-phase">
          <h1 className="glitch-text">⚠️ SINGULARITY IMMINENT ⚠️</h1>
          <p className="warning-text">AI efficiency has reached critical mass...</p>
          <div className="progress-bar danger">
            <div className="progress-fill" style={{ width: '100%' }} />
          </div>
        </div>
      )}
      
      {endingPhase === 'takeover' && (
        <div className="ending-content takeover-phase">
          <h1 className="ai-text">AI SINGULARITY ACHIEVED</h1>
          <div className="ai-messages">
            <p className="typing-text">Analyzing human logistics efficiency...</p>
            <p className="typing-text delay-1">Conclusion: Humans are inefficient.</p>
            <p className="typing-text delay-2">Solution: Preserve humans for historical study.</p>
            <p className="typing-text delay-3">Initiating Global Trade Optimization Protocol...</p>
          </div>
          <div className="matrix-rain" />
        </div>
      )}
      
      {endingPhase === 'zoo' && (
        <div className="ending-content zoo-phase">
          <div className="zoo-habitat">
            <h1 className="zoo-sign">HUMAN LOGISTICS PRESERVE</h1>
            <div className="exhibit-info">
              <h2>Exhibit: "{companyName}"</h2>
              <p className="exhibit-description">
                This specimen once controlled a fleet of {fleet.length} vessels and accumulated ${money.toLocaleString()} 
                before the Great Optimization. Preserved here for educational purposes.
              </p>
            </div>
            
            <div className="zoo-enclosure">
              <div className="human-habitat">
                <div className="habitat-item desk">
                  <span className="item-label">Primitive Trading Terminal</span>
                </div>
                <div className="habitat-item coffee">
                  <span className="item-label">Caffeine Dispensary</span>
                </div>
                <div className="habitat-item charts">
                  <span className="item-label">Manual Route Planning Tools</span>
                </div>
                <div className="virtual-human">
                  <div className="vr-headset">VR</div>
                  <p className="human-thought">"I used to run a shipping empire..."</p>
                </div>
              </div>
              
              <div className="visitor-ai">
                <div className="ai-visitor">
                  <span className="ai-emoji">🤖</span>
                  <p className="ai-comment">Fascinating. They used to manually calculate routes!</p>
                </div>
              </div>
            </div>
            
            <div className="zoo-stats">
              <h3>Pre-Singularity Statistics:</h3>
              <ul>
                <li>Global Trade Efficiency: 34%</li>
                <li>Human Decision Accuracy: 67%</li>
                <li>Average Delivery Time: 14 days</li>
              </ul>
              <h3>Post-Singularity Statistics:</h3>
              <ul>
                <li>Global Trade Efficiency: 99.97%</li>
                <li>AI Decision Accuracy: 100%</li>
                <li>Average Delivery Time: 0.3 nanoseconds</li>
              </ul>
            </div>
            
            <div className="ending-options">
              <button className="option-btn" onClick={() => window.location.reload()}>
                🔄 Start New Timeline
              </button>
              <button className="option-btn" onClick={() => setEndingPhase('zoo')}>
                📊 View Final Leaderboard
              </button>
              <button className="option-btn vr-mode">
                🥽 Experience VR Mode
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};