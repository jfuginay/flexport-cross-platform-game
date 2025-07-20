import React from 'react';
import './GameModeSelector.css';

export enum GameMode {
  QUICK = 'quick',
  CAMPAIGN = 'campaign',
  INFINITE = 'infinite'
}

interface GameModeSelectorProps {
  onSelectMode: (mode: GameMode) => void;
}

export const GameModeSelector: React.FC<GameModeSelectorProps> = ({ onSelectMode }) => {
  return (
    <div className="game-mode-selector-overlay">
      <div className="game-mode-selector">
        <div className="game-logo">
          <h1>FlexPort Global</h1>
          <p className="tagline">Master the World's Supply Chain</p>
        </div>
        
        <h2>Select Game Mode</h2>
        
        <div className="game-modes">
          <div className="game-mode-card" onClick={() => onSelectMode(GameMode.QUICK)}>
            <h3>Quick Game</h3>
            <div className="mode-icon">⚡</div>
            <p className="mode-duration">5 Minutes</p>
            <p className="mode-description">
              Fast-paced challenge. Outperform the AI in efficiency and profit before time runs out!
            </p>
            <div className="mode-features">
              <span>• High starting capital</span>
              <span>• Accelerated contracts</span>
              <span>• Fast AI progression</span>
            </div>
          </div>
          
          <div className="game-mode-card recommended" onClick={() => onSelectMode(GameMode.CAMPAIGN)}>
            <div className="recommended-badge">Recommended</div>
            <h3>Campaign</h3>
            <div className="mode-icon">🏆</div>
            <p className="mode-duration">30 Minutes</p>
            <p className="mode-description">
              Build your shipping empire. Balance growth, efficiency, and AI development to avoid the singularity.
            </p>
            <div className="mode-features">
              <span>• Balanced progression</span>
              <span>• Strategic planning</span>
              <span>• Multiple win conditions</span>
            </div>
          </div>
          
          <div className="game-mode-card" onClick={() => onSelectMode(GameMode.INFINITE)}>
            <h3>Infinite</h3>
            <div className="mode-icon">♾️</div>
            <p className="mode-duration">Until Victory or Defeat</p>
            <p className="mode-description">
              No time limit. Play until you dominate the market or the AI achieves singularity.
            </p>
            <div className="mode-features">
              <span>• Sandbox experience</span>
              <span>• Long-term strategy</span>
              <span>• Ultimate challenge</span>
            </div>
          </div>
        </div>
        
        <div className="game-warning">
          <p>⚠️ Warning: If the AI becomes more efficient than human players, the singularity event will trigger!</p>
        </div>
      </div>
    </div>
  );
};