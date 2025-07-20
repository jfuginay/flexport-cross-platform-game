import React from 'react';
import { useGameStore } from '../../store/gameStore';
import './AICompetitorPanel.css';

export const AICompetitorPanel: React.FC = () => {
  const { aiCompetitors, playerEfficiency } = useGameStore();
  
  // Sort competitors by efficiency
  const sortedCompetitors = [...aiCompetitors].sort((a, b) => b.efficiency - a.efficiency);
  
  return (
    <div className="ai-competitor-panel">
      <h3>Competition Leaderboard</h3>
      
      <div className="competitor-list">
        {/* Player entry */}
        <div className="competitor-entry player">
          <div className="competitor-rank">#</div>
          <div className="competitor-info">
            <div className="competitor-name">
              <span className="name">You (FlexPort Global)</span>
              <span className="tag">HUMAN</span>
            </div>
            <div className="efficiency-bar">
              <div 
                className="efficiency-fill player-fill" 
                style={{ width: `${playerEfficiency}%` }}
              />
              <span className="efficiency-text">{playerEfficiency.toFixed(1)}%</span>
            </div>
          </div>
          <div className="competitor-stats">
            <span className="stat-icon">💰</span>
            <span className="stat-value">${(useGameStore.getState().money / 1000000).toFixed(1)}M</span>
          </div>
        </div>
        
        {/* AI Competitors */}
        {sortedCompetitors.slice(0, 5).map((ai, index) => (
          <div 
            key={ai.id} 
            className={`competitor-entry ${ai.efficiency > playerEfficiency ? 'ahead' : ''}`}
          >
            <div className="competitor-rank">#{index + 1}</div>
            <div className="competitor-info">
              <div className="competitor-name">
                <span className="name">{ai.name}</span>
                <span className="tag">AI</span>
              </div>
              <div className="efficiency-bar">
                <div 
                  className="efficiency-fill" 
                  style={{ 
                    width: `${ai.efficiency}%`,
                    backgroundColor: ai.color 
                  }}
                />
                <span className="efficiency-text">{ai.efficiency.toFixed(1)}%</span>
              </div>
            </div>
            <div className="competitor-stats">
              <span className="stat-icon">🚢</span>
              <span className="stat-value">{ai.shipsOwned}</span>
            </div>
          </div>
        ))}
      </div>
      
      <div className="competition-warning">
        {Math.max(...aiCompetitors.map(ai => ai.efficiency)) > playerEfficiency - 10 && (
          <p className="warning-text">
            ⚠️ AI competitors are catching up! Improve efficiency or face the singularity!
          </p>
        )}
      </div>
    </div>
  );
};