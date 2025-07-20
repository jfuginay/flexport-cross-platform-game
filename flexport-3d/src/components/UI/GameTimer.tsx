import React, { useEffect, useState } from 'react';
import { useGameStore } from '../../store/gameStore';
import { GameMode } from '../../types/game.types';
import './GameTimer.css';

export const GameTimer: React.FC = () => {
  const { gameMode, gameStartTime, gameDuration } = useGameStore();
  const [timeRemaining, setTimeRemaining] = useState<number | null>(null);
  
  useEffect(() => {
    if (!gameMode || !gameStartTime || gameMode === GameMode.INFINITE) {
      setTimeRemaining(null);
      return;
    }
    
    const updateTimer = () => {
      const elapsed = (Date.now() - gameStartTime) / 1000;
      const remaining = (gameDuration || 0) - elapsed;
      setTimeRemaining(Math.max(0, remaining));
    };
    
    updateTimer();
    const interval = setInterval(updateTimer, 1000);
    
    return () => clearInterval(interval);
  }, [gameMode, gameStartTime, gameDuration]);
  
  if (!timeRemaining || gameMode === GameMode.INFINITE) {
    return null;
  }
  
  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };
  
  const isUrgent = timeRemaining < 60; // Last minute
  const isCritical = timeRemaining < 10; // Last 10 seconds
  
  return (
    <div className={`game-timer ${isUrgent ? 'urgent' : ''} ${isCritical ? 'critical' : ''}`}>
      <div className="timer-label">Time Remaining</div>
      <div className="timer-value">{formatTime(timeRemaining)}</div>
      {isUrgent && (
        <div className="timer-warning">
          ⚡ Hurry! Time is running out!
        </div>
      )}
    </div>
  );
};