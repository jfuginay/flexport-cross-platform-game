const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

const server = http.createServer(app);

// Dynamic CORS configuration
const allowedOrigins = [
  "http://localhost:3000",
  "http://localhost:3001",
  "https://flexport-3d.vercel.app",
  "https://flexport-3d.netlify.app",
  "capacitor://localhost", // For iOS app
  "http://localhost", // For Android app
  // Add your production domains here
];

// Allow any origin in development
if (process.env.NODE_ENV !== 'production') {
  allowedOrigins.push("http://localhost:*");
}

const io = new Server(server, {
  cors: {
    origin: (origin, callback) => {
      // Allow requests with no origin (mobile apps, etc.)
      if (!origin) return callback(null, true);
      
      if (allowedOrigins.some(allowed => 
        origin.startsWith(allowed) || 
        allowed.includes('*') && origin.match(new RegExp(allowed.replace('*', '.*')))
      )) {
        callback(null, true);
      } else {
        callback(new Error('Not allowed by CORS'));
      }
    },
    methods: ["GET", "POST"],
    credentials: true
  }
});

// Game rooms storage
const rooms = new Map();
const players = new Map();

// Room structure
class GameRoom {
  constructor(roomCode) {
    this.code = roomCode;
    this.players = [];
    this.host = null;
    this.settings = {
      startingCapital: 50000000,
      gameDuration: '30 minutes',
      mapSize: 'Standard',
      difficulty: 'Normal',
      maxPlayers: 8
    };
    this.state = 'waiting'; // waiting, starting, playing
    this.aiPlayers = [];
    this.chat = [];
  }

  addPlayer(player) {
    if (this.players.length >= this.settings.maxPlayers) {
      return false;
    }
    
    this.players.push(player);
    if (!this.host) {
      this.host = player.id;
    }
    return true;
  }

  removePlayer(playerId) {
    this.players = this.players.filter(p => p.id !== playerId);
    if (this.host === playerId && this.players.length > 0) {
      this.host = this.players[0].id;
    }
  }

  addAIPlayer() {
    const aiNames = ['TradeBot 3000', 'Captain AI', 'LogisticsMaster', 'CargoKing', 'ShipBot Pro', 'Admiral AI', 'FreightMaster', 'OceanTrader'];
    const aiPlayer = {
      id: `ai-${Date.now()}-${Math.random()}`,
      name: aiNames[Math.floor(Math.random() * aiNames.length)],
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
    this.aiPlayers.push(aiPlayer);
    return aiPlayer;
  }

  removeAIPlayer(aiId) {
    this.aiPlayers = this.aiPlayers.filter(ai => ai.id !== aiId);
  }

  getAllPlayers() {
    return [...this.players, ...this.aiPlayers];
  }

  canStart() {
    const totalPlayers = this.players.length + this.aiPlayers.length;
    return totalPlayers >= 2 && totalPlayers <= this.settings.maxPlayers;
  }
}

// Generate room code
function generateRoomCode() {
  return 'FLEX-' + Math.random().toString(36).substr(2, 6).toUpperCase();
}

// Socket.IO connection handling
io.on('connection', (socket) => {
  console.log('User connected:', socket.id);

  // Create or join room
  socket.on('create-room', (playerData) => {
    const roomCode = generateRoomCode();
    const room = new GameRoom(roomCode);
    
    const player = {
      id: socket.id,
      ...playerData,
      isAI: false,
      status: 'waiting'
    };
    
    room.addPlayer(player);
    rooms.set(roomCode, room);
    players.set(socket.id, { roomCode, player });
    
    socket.join(roomCode);
    
    socket.emit('room-created', {
      roomCode,
      room: {
        code: room.code,
        players: room.getAllPlayers(),
        host: room.host,
        settings: room.settings,
        state: room.state
      }
    });
  });

  socket.on('join-room', (data) => {
    const { roomCode, playerData } = data;
    const room = rooms.get(roomCode);
    
    if (!room) {
      socket.emit('error', { message: 'Room not found' });
      return;
    }
    
    if (room.state !== 'waiting') {
      socket.emit('error', { message: 'Game already in progress' });
      return;
    }
    
    const player = {
      id: socket.id,
      ...playerData,
      isAI: false,
      status: 'waiting'
    };
    
    if (!room.addPlayer(player)) {
      socket.emit('error', { message: 'Room is full' });
      return;
    }
    
    players.set(socket.id, { roomCode, player });
    socket.join(roomCode);
    
    // Notify all players in room
    io.to(roomCode).emit('player-joined', {
      player,
      room: {
        code: room.code,
        players: room.getAllPlayers(),
        host: room.host,
        settings: room.settings,
        state: room.state
      }
    });
  });

  // Update player status
  socket.on('update-status', (status) => {
    const playerInfo = players.get(socket.id);
    if (!playerInfo) return;
    
    const { roomCode } = playerInfo;
    const room = rooms.get(roomCode);
    if (!room) return;
    
    const player = room.players.find(p => p.id === socket.id);
    if (player) {
      player.status = status;
      io.to(roomCode).emit('player-status-updated', {
        playerId: socket.id,
        status,
        room: {
          code: room.code,
          players: room.getAllPlayers(),
          host: room.host,
          settings: room.settings,
          state: room.state
        }
      });
    }
  });

  // Add AI player
  socket.on('add-ai-player', () => {
    const playerInfo = players.get(socket.id);
    if (!playerInfo) return;
    
    const { roomCode } = playerInfo;
    const room = rooms.get(roomCode);
    if (!room || room.host !== socket.id) return;
    
    if (room.getAllPlayers().length >= room.settings.maxPlayers) {
      socket.emit('error', { message: 'Room is full' });
      return;
    }
    
    const aiPlayer = room.addAIPlayer();
    io.to(roomCode).emit('ai-player-added', {
      aiPlayer,
      room: {
        code: room.code,
        players: room.getAllPlayers(),
        host: room.host,
        settings: room.settings,
        state: room.state
      }
    });
  });

  // Remove AI player
  socket.on('remove-ai-player', (aiId) => {
    const playerInfo = players.get(socket.id);
    if (!playerInfo) return;
    
    const { roomCode } = playerInfo;
    const room = rooms.get(roomCode);
    if (!room || room.host !== socket.id) return;
    
    room.removeAIPlayer(aiId);
    io.to(roomCode).emit('ai-player-removed', {
      aiId,
      room: {
        code: room.code,
        players: room.getAllPlayers(),
        host: room.host,
        settings: room.settings,
        state: room.state
      }
    });
  });

  // Fill with AI players
  socket.on('fill-with-ai', () => {
    const playerInfo = players.get(socket.id);
    if (!playerInfo) return;
    
    const { roomCode } = playerInfo;
    const room = rooms.get(roomCode);
    if (!room || room.host !== socket.id) return;
    
    const currentPlayerCount = room.getAllPlayers().length;
    const minPlayersToStart = 4; // Minimum players for a good game
    const playersNeeded = Math.max(minPlayersToStart - currentPlayerCount, 0);
    
    for (let i = 0; i < playersNeeded; i++) {
      if (room.getAllPlayers().length < room.settings.maxPlayers) {
        room.addAIPlayer();
      }
    }
    
    io.to(roomCode).emit('room-filled-with-ai', {
      room: {
        code: room.code,
        players: room.getAllPlayers(),
        host: room.host,
        settings: room.settings,
        state: room.state
      }
    });
  });

  // Update game settings
  socket.on('update-settings', (settings) => {
    const playerInfo = players.get(socket.id);
    if (!playerInfo) return;
    
    const { roomCode } = playerInfo;
    const room = rooms.get(roomCode);
    if (!room || room.host !== socket.id) return;
    
    room.settings = { ...room.settings, ...settings };
    io.to(roomCode).emit('settings-updated', {
      settings: room.settings
    });
  });

  // Chat message
  socket.on('chat-message', (message) => {
    const playerInfo = players.get(socket.id);
    if (!playerInfo) return;
    
    const { roomCode, player } = playerInfo;
    const room = rooms.get(roomCode);
    if (!room) return;
    
    const chatMessage = {
      id: Date.now(),
      playerId: socket.id,
      playerName: player.name,
      message,
      timestamp: new Date()
    };
    
    room.chat.push(chatMessage);
    io.to(roomCode).emit('chat-message', chatMessage);
  });

  // Start game
  socket.on('start-game', () => {
    const playerInfo = players.get(socket.id);
    if (!playerInfo) return;
    
    const { roomCode } = playerInfo;
    const room = rooms.get(roomCode);
    if (!room || room.host !== socket.id) return;
    
    if (!room.canStart()) {
      socket.emit('error', { message: 'Not enough players to start' });
      return;
    }
    
    room.state = 'starting';
    
    // Initialize game state with all players
    const gameState = {
      roomCode,
      players: room.getAllPlayers(),
      settings: room.settings,
      startTime: new Date()
    };
    
    io.to(roomCode).emit('game-starting', gameState);
    
    // After countdown, start the actual game
    setTimeout(() => {
      room.state = 'playing';
      io.to(roomCode).emit('game-started', gameState);
    }, 3000);
  });

  // Handle disconnection
  socket.on('disconnect', () => {
    console.log('User disconnected:', socket.id);
    
    const playerInfo = players.get(socket.id);
    if (!playerInfo) return;
    
    const { roomCode } = playerInfo;
    const room = rooms.get(roomCode);
    if (!room) return;
    
    room.removePlayer(socket.id);
    players.delete(socket.id);
    
    // If room is empty, delete it
    if (room.players.length === 0) {
      rooms.delete(roomCode);
    } else {
      // Notify remaining players
      io.to(roomCode).emit('player-left', {
        playerId: socket.id,
        room: {
          code: room.code,
          players: room.getAllPlayers(),
          host: room.host,
          settings: room.settings,
          state: room.state
        }
      });
    }
  });
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    rooms: rooms.size,
    players: players.size 
  });
});

const PORT = process.env.PORT || 3001;
server.listen(PORT, () => {
  console.log(`WebSocket server running on port ${PORT}`);
});