import React, { useEffect, useState } from 'react';
import { useGameStateStore, GameState } from './store/gameStateStore';
import { useGameStore } from './store/gameStore';
import { LoadingScreen } from './components/screens/LoadingScreen';
import { TitleScreen } from './components/screens/TitleScreen';
import { LobbyScreen } from './components/screens/LobbyScreen';
import { GameDashboard } from './components/GameDashboard';
import { MultiplayerLobby } from './components/UI/MultiplayerLobby';
import { SingularityEvent } from './components/SingularityEvent';
import { GameEndScreen } from './components/GameEndScreen';
import { initializeTouchOptimizations, optimizeMobilePerformance } from './utils/touchOptimizations';
import './App.css';
import './components/UI/ui-fixes.css';
import './components/UI/zindex.css';
import './components/mobile/mobile-styles.css';

function App() {
  const { currentState, setGameState } = useGameStateStore();
  const { isSingularityActive, gameResult } = useGameStore();
  
  useEffect(() => {
    // Initialize touch optimizations on mount
    initializeTouchOptimizations();
    optimizeMobilePerformance();
  }, []);
  
  const handleRestart = () => {
    setGameState(GameState.MULTIPLAYER_LOBBY);
  };
  
  const handleMainMenu = () => {
    setGameState(GameState.TITLE);
  };
  
  const renderScreen = () => {
    // Show singularity event if active
    if (isSingularityActive && currentState === GameState.PLAYING) {
      return <SingularityEvent onRestart={handleRestart} />;
    }
    
    // Show game end screen if game has ended
    if (gameResult && currentState === GameState.PLAYING) {
      return <GameEndScreen 
        result={gameResult} 
        onRestart={handleRestart}
        onMainMenu={handleMainMenu}
      />;
    }
    
    switch (currentState) {
      case GameState.LOADING:
        return <LoadingScreen />;
      case GameState.TITLE:
        return <TitleScreen />;
      case GameState.LOBBY:
        return <LobbyScreen />;
      case GameState.MULTIPLAYER_LOBBY:
        return <MultiplayerLobby 
          onStartGame={() => useGameStateStore.getState().setGameState(GameState.PLAYING)}
        />;
      case GameState.PLAYING:
      case GameState.PAUSED:
        return <GameDashboard />;
      default:
        return <LoadingScreen />;
    }
  };
  
  return (
    <div className="App">
      {renderScreen()}
    </div>
  );
}

export default App;
