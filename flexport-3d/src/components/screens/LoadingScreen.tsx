// @ts-nocheck
import React, { useEffect, useState } from 'react';
import { useGameStateStore } from '../../store/gameStateStore';
import './LoadingScreen.css';

const shippingFacts = [
  "90% of global trade is carried by sea",
  "The largest container ship can carry 24,000 TEU containers",
  "A single large container ship can emit as much CO2 as 50 million cars",
  "The busiest shipping route is between Asia and Europe",
  "Pirates still pose a threat to modern shipping, especially near Somalia",
  "The Panama Canal saves ships 8,000 miles of travel",
  "Container shipping was invented in 1956 by Malcolm McLean",
  "The global shipping industry is worth over $14 trillion",
  "There are over 50,000 merchant ships operating worldwide",
  "The average container ship travels at 20-25 knots"
];

export const LoadingScreen: React.FC = () => {
  const { loadingProgress, initializeGame } = useGameStateStore();
  const [currentFact, setCurrentFact] = useState(0);
  
  useEffect(() => {
    // Start the loading process
    initializeGame();
    
    // Rotate through facts
    const interval = setInterval(() => {
      setCurrentFact((prev) => (prev + 1) % shippingFacts.length);
    }, 4000);
    
    return () => clearInterval(interval);
  }, [initializeGame]);
  
  return (
    <div className="loading-screen">
      <div className="loading-content">
        {/* FlexPort Logo */}
        <div className="logo-container">
          <h1 className="game-logo">
            <span className="logo-flex">FLEX</span>
            <span className="logo-port">PORT</span>
            <span className="logo-global">GLOBAL</span>
          </h1>
          <div className="logo-tagline">Build Your Shipping Empire</div>
        </div>
        
        {/* Loading Bar */}
        <div className="loading-bar-container">
          <div className="loading-task">{loadingProgress.currentTask}</div>
          <div className="loading-bar">
            <div 
              className="loading-progress" 
              style={{ width: `${loadingProgress.progress}%` }}
            />
          </div>
          <div className="loading-percentage">{Math.round(loadingProgress.progress)}%</div>
        </div>
        
        {/* Shipping Facts */}
        <div className="shipping-fact">
          <div className="fact-icon">💡</div>
          <div className="fact-text">{shippingFacts[currentFact]}</div>
        </div>
        
        {/* Animated Ship */}
        <div className="loading-animation">
          <div className="ship-container">
            <div className="ship">🚢</div>
            <div className="waves">
              <div className="wave wave1"></div>
              <div className="wave wave2"></div>
              <div className="wave wave3"></div>
            </div>
          </div>
        </div>
      </div>
      
      {/* Background Effect */}
      <div className="loading-background">
        <div className="grid-overlay"></div>
      </div>
    </div>
  );
};