import React from 'react';
import { GameResult } from '../types/game.types';
import './GameEndScreen.css';

interface GameEndScreenProps {
  result: GameResult;
  onRestart: () => void;
  onMainMenu: () => void;
}

export const GameEndScreen: React.FC<GameEndScreenProps> = ({ result, onRestart, onMainMenu }) => {
  const formatDuration = (ms: number) => {
    const seconds = Math.floor(ms / 1000);
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = seconds % 60;
    return `${minutes}:${remainingSeconds.toString().padStart(2, '0')}`;
  };
  
  const isVictory = result.winner === 'player';
  
  return (
    <div className={`game-end-screen ${isVictory ? 'victory' : 'defeat'}`}>
      <div className="end-screen-content">
        <div className="result-header">
          <h1 className={`result-title ${isVictory ? 'victory-text' : 'defeat-text'}`}>
            {isVictory ? 'VICTORY!' : 'DEFEAT'}
          </h1>
          <p className="result-subtitle">{result.reason}</p>
        </div>
        
        <div className="score-comparison">
          <div className="score-card player">
            <h3>Your Performance</h3>
            <div className="efficiency-meter">
              <div className="meter-fill" style={{ width: `${result.finalScore.player}%` }}>
                <span className="efficiency-value">{result.finalScore.player.toFixed(1)}%</span>
              </div>
            </div>
            <p className="score-label">Efficiency Rating</p>
          </div>
          
          <div className="vs-divider">VS</div>
          
          <div className="score-card ai">
            <h3>AI Performance</h3>
            <div className="efficiency-meter">
              <div className="meter-fill ai-fill" style={{ width: `${result.finalScore.ai}%` }}>
                <span className="efficiency-value">{result.finalScore.ai.toFixed(1)}%</span>
              </div>
            </div>
            <p className="score-label">Peak AI Efficiency</p>
          </div>
        </div>
        
        <div className="game-stats">
          <div className="stat">
            <span className="stat-label">Game Duration</span>
            <span className="stat-value">{formatDuration(result.duration)}</span>
          </div>
          <div className="stat">
            <span className="stat-label">Efficiency Gap</span>
            <span className="stat-value">
              {Math.abs(result.finalScore.player - result.finalScore.ai).toFixed(1)}%
            </span>
          </div>
        </div>
        
        {isVictory ? (
          <div className="victory-message">
            <p>🎉 Congratulations! You've proven human ingenuity still matters in logistics!</p>
            <p>The AI remains a tool, not our replacement... for now.</p>
          </div>
        ) : (
          <div className="defeat-message">
            <p>💔 The AI has surpassed human capabilities in supply chain management.</p>
            <p>Perhaps it's time to embrace our new algorithmic overlords...</p>
          </div>
        )}
        
        <div className="end-screen-actions">
          <button className="action-btn primary" onClick={onRestart}>
            Play Again
          </button>
          <button className="action-btn secondary" onClick={onMainMenu}>
            Main Menu
          </button>
        </div>
      </div>
    </div>
  );
};