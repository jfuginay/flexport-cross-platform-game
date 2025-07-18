import React, { useState, useEffect } from 'react';
import './MultiplayerLobby.css';

interface Player {
  id: string;
  name: string;
  isAI: boolean;
  avatar: string;
  rating: number;
  status: 'ready' | 'waiting';
  stats: {
    gamesPlayed: number;
    winRate: number;
    avgProfit: number;
  };
}

interface GameSettings {
  startingCapital: number;
  gameDuration: string;
  mapSize: string;
  difficulty: string;
}

export const MultiplayerLobby: React.FC<{ onStartGame: () => void }> = ({ onStartGame }) => {
  const [players, setPlayers] = useState<Player[]>([]);
  const [gameSettings, setGameSettings] = useState<GameSettings>({
    startingCapital: 50000000,
    gameDuration: '30 minutes',
    mapSize: 'Standard',
    difficulty: 'Normal'
  });
  const [isHost, setIsHost] = useState(true);
  const [chatMessages, setChatMessages] = useState<{ player: string; message: string }[]>([]);
  const [chatInput, setChatInput] = useState('');

  useEffect(() => {
    // Initialize with player and AI players
    const aiNames = ['TradeBot 3000', 'Captain AI', 'LogisticsMaster', 'CargoKing'];
    const aiPersonalities = ['Aggressive', 'Balanced', 'Conservative', 'Opportunistic'];
    
    const initialPlayers: Player[] = [
      {
        id: 'player-1',
        name: 'You',
        isAI: false,
        avatar: '👤',
        rating: 1200,
        status: 'ready',
        stats: {
          gamesPlayed: 42,
          winRate: 65,
          avgProfit: 125000000
        }
      }
    ];

    // Add AI players to fill slots
    for (let i = 0; i < 3; i++) {
      initialPlayers.push({
        id: `ai-${i}`,
        name: aiNames[i],
        isAI: true,
        avatar: '🤖',
        rating: 900 + Math.floor(Math.random() * 500),
        status: 'ready',
        stats: {
          gamesPlayed: Math.floor(Math.random() * 1000),
          winRate: 40 + Math.floor(Math.random() * 30),
          avgProfit: 50000000 + Math.floor(Math.random() * 100000000)
        }
      });
    }

    setPlayers(initialPlayers);

    // Simulate AI chat messages
    const aiMessages = [
      'Ready for some competitive shipping!',
      'May the best logistics company win',
      'I\'ve optimized my route algorithms',
      'Good luck everyone!'
    ];

    setTimeout(() => {
      setChatMessages([{
        player: aiNames[0],
        message: aiMessages[Math.floor(Math.random() * aiMessages.length)]
      }]);
    }, 2000);
  }, []);

  const handleSendMessage = () => {
    if (chatInput.trim()) {
      setChatMessages(prev => [...prev, { player: 'You', message: chatInput }]);
      setChatInput('');

      // AI response
      setTimeout(() => {
        const aiPlayer = players.find(p => p.isAI);
        if (aiPlayer) {
          const responses = [
            'Good luck to you too!',
            'Let\'s see who dominates the seas',
            'My algorithms are ready',
            'Bring it on!'
          ];
          setChatMessages(prev => [...prev, {
            player: aiPlayer.name,
            message: responses[Math.floor(Math.random() * responses.length)]
          }]);
        }
      }, 1000 + Math.random() * 2000);
    }
  };

  const addAIPlayer = () => {
    if (players.length < 8) {
      const aiNames = ['ShipBot Pro', 'Admiral AI', 'FreightMaster', 'OceanTrader'];
      const newAI: Player = {
        id: `ai-${Date.now()}`,
        name: aiNames[Math.floor(Math.random() * aiNames.length)] + ` ${players.length}`,
        isAI: true,
        avatar: '🤖',
        rating: 800 + Math.floor(Math.random() * 600),
        status: 'ready',
        stats: {
          gamesPlayed: Math.floor(Math.random() * 500),
          winRate: 35 + Math.floor(Math.random() * 35),
          avgProfit: 40000000 + Math.floor(Math.random() * 80000000)
        }
      };
      setPlayers(prev => [...prev, newAI]);
    }
  };

  const removePlayer = (playerId: string) => {
    setPlayers(prev => prev.filter(p => p.id !== playerId && !p.isAI));
  };

  return (
    <div className="multiplayer-lobby">
      <div className="lobby-header">
        <h2>Multiplayer Lobby</h2>
        <div className="lobby-code">
          <span>Room Code:</span>
          <code>FLEX-{Math.random().toString(36).substr(2, 6).toUpperCase()}</code>
          <button className="copy-button">📋</button>
        </div>
      </div>

      <div className="lobby-content">
        <div className="players-section">
          <div className="section-header">
            <h3>Players ({players.length}/8)</h3>
            <button className="add-ai-button" onClick={addAIPlayer} disabled={players.length >= 8}>
              + Add AI Player
            </button>
          </div>

          <div className="players-grid">
            {players.map(player => (
              <div key={player.id} className={`player-card ${player.isAI ? 'ai' : 'human'}`}>
                <div className="player-header">
                  <div className="player-info">
                    <span className="player-avatar">{player.avatar}</span>
                    <div>
                      <h4>{player.name}</h4>
                      <div className="player-rating">⭐ {player.rating}</div>
                    </div>
                  </div>
                  <div className={`status-badge ${player.status}`}>
                    {player.status === 'ready' ? '✅ Ready' : '⏳ Waiting'}
                  </div>
                </div>

                <div className="player-stats">
                  <div className="stat">
                    <span className="stat-label">Games</span>
                    <span className="stat-value">{player.stats.gamesPlayed}</span>
                  </div>
                  <div className="stat">
                    <span className="stat-label">Win Rate</span>
                    <span className="stat-value">{player.stats.winRate}%</span>
                  </div>
                  <div className="stat">
                    <span className="stat-label">Avg Profit</span>
                    <span className="stat-value">${(player.stats.avgProfit / 1000000).toFixed(0)}M</span>
                  </div>
                </div>

                {player.isAI && isHost && (
                  <button 
                    className="remove-button"
                    onClick={() => removePlayer(player.id)}
                  >
                    ✕
                  </button>
                )}
              </div>
            ))}
          </div>
        </div>

        <div className="settings-chat-section">
          <div className="game-settings">
            <h3>Game Settings</h3>
            <div className="settings-list">
              <div className="setting-item">
                <label>Starting Capital</label>
                <select 
                  value={gameSettings.startingCapital}
                  onChange={(e) => setGameSettings(prev => ({ ...prev, startingCapital: Number(e.target.value) }))}
                  disabled={!isHost}
                >
                  <option value={25000000}>$25M</option>
                  <option value={50000000}>$50M</option>
                  <option value={100000000}>$100M</option>
                </select>
              </div>
              <div className="setting-item">
                <label>Game Duration</label>
                <select 
                  value={gameSettings.gameDuration}
                  onChange={(e) => setGameSettings(prev => ({ ...prev, gameDuration: e.target.value }))}
                  disabled={!isHost}
                >
                  <option value="15 minutes">15 minutes</option>
                  <option value="30 minutes">30 minutes</option>
                  <option value="60 minutes">60 minutes</option>
                </select>
              </div>
              <div className="setting-item">
                <label>Map Size</label>
                <select 
                  value={gameSettings.mapSize}
                  onChange={(e) => setGameSettings(prev => ({ ...prev, mapSize: e.target.value }))}
                  disabled={!isHost}
                >
                  <option value="Small">Small</option>
                  <option value="Standard">Standard</option>
                  <option value="Large">Large</option>
                </select>
              </div>
              <div className="setting-item">
                <label>AI Difficulty</label>
                <select 
                  value={gameSettings.difficulty}
                  onChange={(e) => setGameSettings(prev => ({ ...prev, difficulty: e.target.value }))}
                  disabled={!isHost}
                >
                  <option value="Easy">Easy</option>
                  <option value="Normal">Normal</option>
                  <option value="Hard">Hard</option>
                </select>
              </div>
            </div>
          </div>

          <div className="chat-section">
            <h3>Chat</h3>
            <div className="chat-messages">
              {chatMessages.map((msg, index) => (
                <div key={index} className="chat-message">
                  <span className="chat-player">{msg.player}:</span>
                  <span className="chat-text">{msg.message}</span>
                </div>
              ))}
            </div>
            <div className="chat-input">
              <input 
                type="text"
                placeholder="Type a message..."
                value={chatInput}
                onChange={(e) => setChatInput(e.target.value)}
                onKeyPress={(e) => e.key === 'Enter' && handleSendMessage()}
              />
              <button onClick={handleSendMessage}>Send</button>
            </div>
          </div>
        </div>
      </div>

      <div className="lobby-actions">
        <button className="cancel-button">Leave Lobby</button>
        <button 
          className="start-button"
          onClick={onStartGame}
          disabled={players.filter(p => p.status === 'ready').length < 2}
        >
          Start Game ({players.filter(p => p.status === 'ready').length} Ready)
        </button>
      </div>
    </div>
  );
};