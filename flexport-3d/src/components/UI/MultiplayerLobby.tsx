// @ts-nocheck
import React, { useState, useEffect } from 'react';
import { multiplayerService, Player, Room, ChatMessage } from '../../services/multiplayerService';
import './MultiplayerLobby.css';

interface MultiplayerLobbyProps {
  onStartGame: () => void;
  playerName?: string;
  playerAvatar?: string;
}

export const MultiplayerLobby: React.FC<MultiplayerLobbyProps> = ({ 
  onStartGame,
  playerName = 'Player',
  playerAvatar = '👤'
}) => {
  const [isConnecting, setIsConnecting] = useState(true);
  const [connectionError, setConnectionError] = useState<string | null>(null);
  const [room, setRoom] = useState<Room | null>(null);
  const [chatMessages, setChatMessages] = useState<ChatMessage[]>([]);
  const [chatInput, setChatInput] = useState('');
  const [joinRoomCode, setJoinRoomCode] = useState('');
  const [showJoinDialog, setShowJoinDialog] = useState(false);
  const [playerStatus, setPlayerStatus] = useState<'ready' | 'waiting'>('waiting');

  useEffect(() => {
    // Connect to multiplayer server
    const connectToServer = async () => {
      try {
        await multiplayerService.connect();
        setIsConnecting(false);
        
        // Set up event listeners
        multiplayerService.on('room-created', handleRoomUpdate);
        multiplayerService.on('player-joined', handleRoomUpdate);
        multiplayerService.on('player-left', handleRoomUpdate);
        multiplayerService.on('player-status-updated', handleRoomUpdate);
        multiplayerService.on('ai-player-added', handleRoomUpdate);
        multiplayerService.on('ai-player-removed', handleRoomUpdate);
        multiplayerService.on('room-filled-with-ai', handleRoomUpdate);
        multiplayerService.on('settings-updated', handleSettingsUpdate);
        multiplayerService.on('chat-message', handleChatMessage);
        multiplayerService.on('game-starting', handleGameStarting);
        multiplayerService.on('error', handleError);
      } catch (error) {
        setConnectionError('Failed to connect to multiplayer server. Playing offline.');
        setIsConnecting(false);
      }
    };

    connectToServer();

    return () => {
      multiplayerService.disconnect();
    };
  }, []);

  const handleRoomUpdate = (data: { room: Room }) => {
    setRoom(data.room);
  };

  const handleSettingsUpdate = (data: { settings: any }) => {
    if (room) {
      setRoom({ ...room, settings: data.settings });
    }
  };

  const handleChatMessage = (message: ChatMessage) => {
    setChatMessages(prev => [...prev, message]);
  };

  const handleGameStarting = (data: any) => {
    // Show countdown or preparation UI
    setTimeout(() => {
      onStartGame();
    }, 3000);
  };

  const handleError = (data: { message: string }) => {
    alert(data.message);
  };

  const createRoom = async () => {
    const playerData = {
      name: playerName,
      avatar: playerAvatar,
      rating: 1200,
      stats: {
        gamesPlayed: 0,
        winRate: 0,
        avgProfit: 0
      }
    };
    
    await multiplayerService.createRoom(playerData);
  };

  const joinRoom = async () => {
    if (!joinRoomCode) return;
    
    const playerData = {
      name: playerName,
      avatar: playerAvatar,
      rating: 1200,
      stats: {
        gamesPlayed: 0,
        winRate: 0,
        avgProfit: 0
      }
    };
    
    await multiplayerService.joinRoom(joinRoomCode.toUpperCase(), playerData);
    setShowJoinDialog(false);
  };

  const handleSendMessage = () => {
    if (chatInput.trim() && room) {
      multiplayerService.sendChatMessage(chatInput);
      setChatInput('');
    }
  };

  const toggleReady = () => {
    const newStatus = playerStatus === 'ready' ? 'waiting' : 'ready';
    setPlayerStatus(newStatus);
    multiplayerService.updateStatus(newStatus);
  };

  const handleSettingChange = (key: string, value: any) => {
    if (room && multiplayerService.isHost()) {
      multiplayerService.updateSettings({ [key]: value });
    }
  };

  const handleStartGame = () => {
    if (room && multiplayerService.isHost()) {
      multiplayerService.startGame();
    }
  };

  // Loading state
  if (isConnecting) {
    return (
      <div className="multiplayer-lobby">
        <div>
          <div className="loading-container">
            <h2>Connecting to multiplayer server...</h2>
            <div className="spinner"></div>
          </div>
        </div>
      </div>
    );
  }

  // Connection error - fallback to offline mode
  if (connectionError) {
    return (
      <div className="multiplayer-lobby">
        <div>
          <div className="error-container">
            <h3>{connectionError}</h3>
            <button onClick={onStartGame}>Play Offline</button>
          </div>
        </div>
      </div>
    );
  }

  // No room - show create/join options
  if (!room) {
    return (
      <div className="multiplayer-lobby">
        <div>
          <div className="lobby-welcome">
            <h2>🚢 FlexPort Multiplayer</h2>
            <div className="lobby-options">
              <button className="primary-button" onClick={createRoom}>
                Create New Room
              </button>
              <button className="secondary-button" onClick={() => setShowJoinDialog(true)}>
                Join Existing Room
              </button>
            </div>
            
            {showJoinDialog && (
              <div className="join-dialog">
                <input
                  type="text"
                  placeholder="Enter room code (e.g., FLEX-ABC123)"
                  value={joinRoomCode}
                  onChange={(e) => setJoinRoomCode(e.target.value)}
                  onKeyPress={(e) => e.key === 'Enter' && joinRoom()}
                />
                <div className="dialog-buttons">
                  <button onClick={joinRoom}>Join</button>
                  <button onClick={() => setShowJoinDialog(false)}>Cancel</button>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    );
  }

  const isHost = multiplayerService.isHost();
  const allPlayers = room.players || [];
  const readyCount = allPlayers.filter(p => p.status === 'ready').length;
  const canStart = readyCount >= 2 && room.state === 'waiting';

  return (
    <div className="multiplayer-lobby">
      <div>
        <div className="lobby-header">
          <h2>Multiplayer Lobby</h2>
          <div className="lobby-code">
            <span>Room Code:</span>
            <code>{room.code}</code>
            <button className="copy-button" onClick={() => navigator.clipboard.writeText(room.code)}>
              📋
            </button>
          </div>
        </div>

      <div className="lobby-content">
        <div className="players-section">
          <div className="section-header">
            <h3>Players ({allPlayers.length}/{room.settings.maxPlayers})</h3>
            <div className="player-actions">
              {isHost && (
                <>
                  <button 
                    className="add-ai-button" 
                    onClick={() => multiplayerService.addAIPlayer()} 
                    disabled={allPlayers.length >= room.settings.maxPlayers}
                  >
                    + Add AI
                  </button>
                  <button 
                    className="fill-ai-button" 
                    onClick={() => multiplayerService.fillWithAI()}
                    disabled={allPlayers.length >= 4}
                  >
                    Fill with AI
                  </button>
                </>
              )}
            </div>
          </div>

          <div className="players-grid">
            {allPlayers.map(player => (
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
                    onClick={() => multiplayerService.removeAIPlayer(player.id)}
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
                  value={room.settings.startingCapital}
                  onChange={(e) => handleSettingChange('startingCapital', Number(e.target.value))}
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
                  value={room.settings.gameDuration}
                  onChange={(e) => handleSettingChange('gameDuration', e.target.value)}
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
                  value={room.settings.mapSize}
                  onChange={(e) => handleSettingChange('mapSize', e.target.value)}
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
                  value={room.settings.difficulty}
                  onChange={(e) => handleSettingChange('difficulty', e.target.value)}
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
              {chatMessages.map((msg) => (
                <div key={msg.id} className="chat-message">
                  <span className="chat-player">{msg.playerName}:</span>
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
        <button 
          className={`ready-button ${playerStatus}`}
          onClick={toggleReady}
        >
          {playerStatus === 'ready' ? 'Ready ✅' : 'Not Ready ⏳'}
        </button>
        
        {isHost ? (
          <button 
            className="start-button"
            onClick={handleStartGame}
            disabled={!canStart}
          >
            Start Game ({readyCount} Ready)
          </button>
        ) : (
          <div className="waiting-for-host">
            Waiting for host to start... ({readyCount} Ready)
          </div>
        )}
      </div>
      </div>
    </div>
  );
};