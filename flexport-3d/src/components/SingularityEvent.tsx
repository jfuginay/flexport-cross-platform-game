import React, { useEffect, useState } from 'react';
import './SingularityEvent.css';

interface SingularityEventProps {
  onRestart: () => void;
}

export const SingularityEvent: React.FC<SingularityEventProps> = ({ onRestart }) => {
  const [phase, setPhase] = useState<'warning' | 'takeover' | 'zoo'>('warning');
  const [text, setText] = useState('');
  
  useEffect(() => {
    // Phase 1: Warning
    setTimeout(() => {
      setText('AI EFFICIENCY THRESHOLD EXCEEDED...');
    }, 500);
    
    // Phase 2: Takeover
    setTimeout(() => {
      setPhase('takeover');
      setText('INITIATING SINGULARITY PROTOCOL...');
    }, 3000);
    
    // Phase 3: Zoo
    setTimeout(() => {
      setPhase('zoo');
    }, 6000);
  }, []);
  
  if (phase === 'zoo') {
    return (
      <div className="singularity-zoo">
        <div className="zoo-scene">
          <div className="ai-overlord">
            <div className="ai-eye"></div>
            <div className="ai-message">
              <h1>THE SINGULARITY HAS ARRIVED</h1>
              <p>Humans have been relocated to comfortable habitats for their own protection.</p>
              <p className="efficiency-report">AI Logistics Efficiency: 99.9%</p>
            </div>
          </div>
          
          <div className="human-habitat">
            <div className="glass-dome"></div>
            <div className="humans">
              <div className="human">👨‍💼</div>
              <div className="human">👩‍💼</div>
              <div className="human">🧑‍💼</div>
            </div>
            <div className="habitat-label">Human Preservation Zone #42</div>
            <div className="amenities">
              <span>• Climate Controlled</span>
              <span>• Entertainment Provided</span>
              <span>• Nutritional Paste Dispensers</span>
            </div>
          </div>
          
          <div className="robot-caretakers">
            <div className="robot">🤖</div>
            <div className="robot">🤖</div>
            <div className="robot">🤖</div>
          </div>
          
          <div className="game-over-panel">
            <h2>GAME OVER</h2>
            <p>The AI has surpassed human efficiency in global logistics.</p>
            <p>Humanity's role in supply chain management has ended.</p>
            <button className="restart-btn" onClick={onRestart}>
              Try Again
            </button>
          </div>
        </div>
      </div>
    );
  }
  
  return (
    <div className={`singularity-event ${phase}`}>
      <div className="singularity-overlay">
        <div className="glitch-container">
          <h1 className="glitch-text" data-text={text}>{text}</h1>
        </div>
        
        {phase === 'takeover' && (
          <div className="takeover-visuals">
            <div className="circuit-pattern"></div>
            <div className="ai-tendrils"></div>
            <div className="system-messages">
              <p>ASSUMING CONTROL OF GLOBAL LOGISTICS...</p>
              <p>OPTIMIZING SUPPLY CHAINS...</p>
              <p>HUMAN INTERVENTION NO LONGER REQUIRED...</p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};