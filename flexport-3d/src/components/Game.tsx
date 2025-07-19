// @ts-nocheck
import React, { useEffect, useState } from 'react';
import { useGameStore } from '../store/gameStore';
import { useAIPlayerStore } from '../store/aiPlayerStore';
import { LoadingScreen } from './UI/LoadingScreen';
import { GameDashboard } from './GameDashboard';
import { FleetManagement } from './UI/FleetManagement';
import { AIResearchTab } from './UI/AIResearchTab';
import { ContractNotifications } from './UI/ContractNotifications';
import { MultiplayerLobby } from './UI/MultiplayerLobby';
import { SelectionPanel } from './UI/SelectionPanel';

export const Game: React.FC = () => {
  const { updateGame, startGame } = useGameStore();
  const [isLoading, setIsLoading] = useState(true);
  
  useEffect(() => {
    startGame();
    
    // Initialize AI players for multiplayer
    const aiStore = useAIPlayerStore.getState();
    aiStore.initializeAIPlayers(3); // Start with 3 AI players
    
    // Simulate loading time
    setTimeout(() => setIsLoading(false), 2000);
  }, [startGame]);
  
  useEffect(() => {
    let lastTime = Date.now();
    const gameLoop = setInterval(() => {
      const currentTime = Date.now();
      const deltaTime = (currentTime - lastTime) / 1000; // Convert to seconds
      updateGame(deltaTime);
      lastTime = currentTime;
    }, 1000 / 60); // 60 FPS
    
    return () => clearInterval(gameLoop);
  }, [updateGame]);
  
  
  return (
    <>
      {isLoading && <LoadingScreen />}
      
      <GameDashboard />
    </>
  );
};