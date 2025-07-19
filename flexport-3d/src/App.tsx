import React, { useEffect } from 'react';
import { useGameStateStore, GameState } from './store/gameStateStore';
import { LoadingScreen } from './components/screens/LoadingScreen';
import { TitleScreen } from './components/screens/TitleScreen';
import { LobbyScreen } from './components/screens/LobbyScreen';
import { GameDashboard } from './components/GameDashboard';
import { MultiplayerLobby } from './components/UI/MultiplayerLobby';
import { initializeTouchOptimizations, optimizeMobilePerformance } from './utils/touchOptimizations';
import './App.css';
import './components/UI/ui-fixes.css';
import './components/UI/zindex.css';
import './components/mobile/mobile-styles.css';

function App() {
  const { currentState } = useGameStateStore();
  
  useEffect(() => {
    // Initialize touch optimizations on mount
    initializeTouchOptimizations();
    optimizeMobilePerformance();
  }, []);
  
  const renderScreen = () => {
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
