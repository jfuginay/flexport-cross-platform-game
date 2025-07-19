// @ts-nocheck
import React, { useState } from 'react';
import { Canvas } from '@react-three/fiber';
import { OrbitControls } from '@react-three/drei';
import { useGameStateStore, GameState } from '../../store/gameStateStore';
import { World } from '../World';
import './TitleScreen.css';

interface MenuOption {
  label: string;
  action: () => void;
  disabled?: boolean;
}

export const TitleScreen: React.FC = () => {
  const { setGameState } = useGameStateStore();
  const [selectedOption, setSelectedOption] = useState(0);
  
  const menuOptions: MenuOption[] = [
    {
      label: 'New Game',
      action: () => setGameState(GameState.LOBBY)
    },
    {
      label: 'Continue',
      action: () => setGameState(GameState.PLAYING),
      disabled: true // No save game yet
    },
    {
      label: 'Multiplayer',
      action: () => setGameState(GameState.MULTIPLAYER_LOBBY)
    },
    {
      label: 'Settings',
      action: () => console.log('Settings clicked')
    },
    {
      label: 'Credits',
      action: () => console.log('Credits clicked')
    },
    {
      label: 'Exit',
      action: () => window.close()
    }
  ];
  
  const handleKeyDown = (e: KeyboardEvent) => {
    if (e.key === 'ArrowUp') {
      setSelectedOption((prev) => (prev - 1 + menuOptions.length) % menuOptions.length);
    } else if (e.key === 'ArrowDown') {
      setSelectedOption((prev) => (prev + 1) % menuOptions.length);
    } else if (e.key === 'Enter') {
      const option = menuOptions[selectedOption];
      if (!option.disabled) {
        option.action();
      }
    }
  };
  
  React.useEffect(() => {
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [selectedOption]);
  
  return (
    <div className="title-screen">
      {/* 3D Background */}
      <div className="title-background">
        <Canvas camera={{ position: [300, 150, 300], fov: 50 }}>
          <ambientLight intensity={0.3} />
          <directionalLight position={[100, 100, 50]} intensity={0.8} />
          <World isEarthRotating={true} timeOfDay={12} />
          <OrbitControls 
            enablePan={false} 
            enableZoom={false}
            autoRotate
            autoRotateSpeed={0.5}
            minPolarAngle={Math.PI / 3}
            maxPolarAngle={Math.PI / 2}
          />
        </Canvas>
      </div>
      
      {/* Title Content */}
      <div className="title-content">
        <div className="title-header">
          <h1 className="main-title">
            <span className="title-flex">FLEX</span>
            <span className="title-port">PORT</span>
            <span className="title-global">GLOBAL</span>
          </h1>
          <div className="title-subtitle">Command the Seas. Dominate Trade. Build an Empire.</div>
        </div>
        
        {/* Main Menu */}
        <div className="main-menu">
          {menuOptions.map((option, index) => (
            <button
              key={option.label}
              className={`menu-option ${selectedOption === index ? 'selected' : ''} ${option.disabled ? 'disabled' : ''}`}
              onClick={() => !option.disabled && option.action()}
              onMouseEnter={() => setSelectedOption(index)}
              disabled={option.disabled}
            >
              <span className="option-indicator">{selectedOption === index ? '▶' : ''}</span>
              <span className="option-label">{option.label}</span>
              {option.disabled && <span className="coming-soon">Coming Soon</span>}
            </button>
          ))}
        </div>
        
        {/* Version Info */}
        <div className="version-info">
          <span>Version 1.0.0</span>
          <span className="separator">•</span>
          <span>© 2024 FlexPort Global</span>
        </div>
      </div>
      
      {/* Animated Elements */}
      <div className="animated-elements">
        <div className="ship ship-1">🚢</div>
        <div className="ship ship-2">✈️</div>
        <div className="ship ship-3">🚢</div>
        <div className="particle particle-1"></div>
        <div className="particle particle-2"></div>
        <div className="particle particle-3"></div>
      </div>
    </div>
  );
};