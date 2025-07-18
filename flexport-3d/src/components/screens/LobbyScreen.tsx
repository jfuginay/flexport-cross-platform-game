import React, { useState, useEffect } from 'react';
import { useGameStateStore, GameState } from '../../store/gameStateStore';
import './LobbyScreen.css';

interface LobbyPlayer {
  id: string;
  name: string;
  isAI: boolean;
  isReady: boolean;
  color: string;
  avatar: string;
  aiPersonality?: 'Aggressive' | 'Balanced' | 'Defensive' | 'Opportunistic';
}

const AI_NAMES = [
  'Neptune Logistics',
  'Poseidon Shipping',
  'Atlas Cargo Co.',
  'Horizon Maritime',
  'Pacific Traders',
  'Global Freight Inc.',
  'SeaLink Transport',
  'OceanBridge Corp'
];

const PLAYER_COLORS = [
  '#3b82f6', // Blue
  '#10b981', // Green
  '#f59e0b', // Amber
  '#ef4444', // Red
  '#8b5cf6', // Purple
  '#ec4899', // Pink
  '#14b8a6', // Teal
  '#f97316'  // Orange
];

export const LobbyScreen: React.FC = () => {
  const { setGameState } = useGameStateStore();
  const [players, setPlayers] = useState<LobbyPlayer[]>([
    {
      id: '1',
      name: 'You',
      isAI: false,
      isReady: false,
      color: PLAYER_COLORS[0],
      avatar: '👤'
    }
  ]);
  
  const [lobbySettings, setLobbySettings] = useState({
    maxPlayers: 4,
    startingCapital: 1000000,
    difficulty: 'Normal',
    victoryCondition: 'Economic'
  });
  
  // Auto-fill with AI players
  useEffect(() => {
    const fillWithAI = () => {
      const currentPlayerCount = players.length;
      const aiNeeded = lobbySettings.maxPlayers - currentPlayerCount;
      
      if (aiNeeded > 0) {
        const newAIPlayers: LobbyPlayer[] = [];
        const usedNames = new Set(players.map(p => p.name));
        const availableNames = AI_NAMES.filter(name => !usedNames.has(name));
        
        for (let i = 0; i < aiNeeded && i < availableNames.length; i++) {
          const personality = ['Aggressive', 'Balanced', 'Defensive', 'Opportunistic'][
            Math.floor(Math.random() * 4)
          ] as LobbyPlayer['aiPersonality'];
          
          newAIPlayers.push({
            id: `ai-${Date.now()}-${i}`,
            name: availableNames[i],
            isAI: true,
            isReady: true,
            color: PLAYER_COLORS[currentPlayerCount + i],
            avatar: '🤖',
            aiPersonality: personality
          });
        }
        
        setPlayers([...players, ...newAIPlayers]);
      }
    };
    
    const timer = setTimeout(fillWithAI, 1000);
    return () => clearTimeout(timer);
  }, [lobbySettings.maxPlayers, players.length]);
  
  const handleReady = () => {
    setPlayers(players.map(p => 
      p.id === '1' ? { ...p, isReady: !p.isReady } : p
    ));
  };
  
  const handleStartGame = () => {
    if (players.every(p => p.isReady)) {
      // Store game setup in game store
      setGameState(GameState.PLAYING);
    }
  };
  
  const canStart = players.every(p => p.isReady) && players.length >= 2;
  
  return (
    <div className="lobby-screen">
      <div className="lobby-container">
        {/* Header */}
        <div className="lobby-header">
          <h1>Game Lobby</h1>
          <button 
            className="back-button"
            onClick={() => setGameState(GameState.TITLE)}
          >
            ← Back
          </button>
        </div>
        
        {/* Main Content */}
        <div className="lobby-content">
          {/* Players List */}
          <div className="players-section">
            <h2>Players ({players.length}/{lobbySettings.maxPlayers})</h2>
            <div className="players-list">
              {Array.from({ length: lobbySettings.maxPlayers }).map((_, index) => {
                const player = players[index];
                return (
                  <div 
                    key={index} 
                    className={`player-slot ${player ? 'occupied' : 'empty'}`}
                  >
                    {player ? (
                      <>
                        <div className="player-avatar" style={{ color: player.color }}>
                          {player.avatar}
                        </div>
                        <div className="player-info">
                          <div className="player-name">{player.name}</div>
                          {player.isAI && (
                            <div className="player-personality">
                              AI: {player.aiPersonality}
                            </div>
                          )}
                        </div>
                        <div className={`ready-status ${player.isReady ? 'ready' : 'not-ready'}`}>
                          {player.isReady ? '✓ Ready' : '○ Not Ready'}
                        </div>
                      </>
                    ) : (
                      <div className="empty-slot">Waiting for player...</div>
                    )}
                  </div>
                );
              })}
            </div>
          </div>
          
          {/* Settings */}
          <div className="settings-section">
            <h2>Game Settings</h2>
            
            <div className="setting-item">
              <label>Max Players</label>
              <select 
                value={lobbySettings.maxPlayers}
                onChange={(e) => setLobbySettings({
                  ...lobbySettings,
                  maxPlayers: parseInt(e.target.value)
                })}
              >
                {[2, 3, 4, 5, 6, 7, 8].map(n => (
                  <option key={n} value={n}>{n} Players</option>
                ))}
              </select>
            </div>
            
            <div className="setting-item">
              <label>Starting Capital</label>
              <select 
                value={lobbySettings.startingCapital}
                onChange={(e) => setLobbySettings({
                  ...lobbySettings,
                  startingCapital: parseInt(e.target.value)
                })}
              >
                <option value={500000}>$500,000 (Hard)</option>
                <option value={1000000}>$1,000,000 (Normal)</option>
                <option value={2000000}>$2,000,000 (Easy)</option>
              </select>
            </div>
            
            <div className="setting-item">
              <label>AI Difficulty</label>
              <select 
                value={lobbySettings.difficulty}
                onChange={(e) => setLobbySettings({
                  ...lobbySettings,
                  difficulty: e.target.value
                })}
              >
                <option value="Easy">Easy</option>
                <option value="Normal">Normal</option>
                <option value="Hard">Hard</option>
                <option value="Extreme">Extreme</option>
              </select>
            </div>
            
            <div className="setting-item">
              <label>Victory Condition</label>
              <select 
                value={lobbySettings.victoryCondition}
                onChange={(e) => setLobbySettings({
                  ...lobbySettings,
                  victoryCondition: e.target.value
                })}
              >
                <option value="Economic">Economic - $50M</option>
                <option value="Domination">Domination - 60% Ports</option>
                <option value="Reputation">Reputation - 95% for 2 years</option>
                <option value="Time">Time Limit - 10 years</option>
              </select>
            </div>
          </div>
        </div>
        
        {/* Actions */}
        <div className="lobby-actions">
          <button 
            className={`ready-button ${players[0].isReady ? 'ready' : ''}`}
            onClick={handleReady}
          >
            {players[0].isReady ? '✓ Ready' : 'Ready Up'}
          </button>
          <button 
            className="start-button"
            onClick={handleStartGame}
            disabled={!canStart}
          >
            Start Game
          </button>
        </div>
      </div>
    </div>
  );
};