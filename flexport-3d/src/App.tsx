import React from 'react';
import { useGameStateStore, GameState } from './store/gameStateStore';
import { LoadingScreen } from './components/screens/LoadingScreen';
import { TitleScreen } from './components/screens/TitleScreen';
import { LobbyScreen } from './components/screens/LobbyScreen';
import { GameDashboard } from './components/GameDashboard';
import './App.css';
import './components/UI/ui-fixes.css';
import './components/UI/zindex.css';

function App() {
  const { currentState } = useGameStateStore();
  
  const renderScreen = () => {
    switch (currentState) {
      case GameState.LOADING:
        return <LoadingScreen />;
      case GameState.TITLE:
        return <TitleScreen />;
      case GameState.LOBBY:
        return <LobbyScreen />;
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
