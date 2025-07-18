const WebSocket = require('ws');
const { v4: uuidv4 } = require('uuid');

class MultiplayerServer {
  constructor(port = 8080) {
    this.port = port;
    this.server = new WebSocket.Server({ port });
    this.clients = new Map(); // clientId -> WebSocket
    this.players = new Map(); // playerId -> player data
    this.rooms = new Map(); // roomId -> room data
    this.playerRooms = new Map(); // playerId -> roomId
    
    console.log(`🚢 FlexPort Multiplayer Server starting on port ${port}...`);
    this.setupEventHandlers();
  }

  setupEventHandlers() {
    this.server.on('connection', (ws, req) => {
      const clientId = uuidv4();
      this.clients.set(clientId, ws);
      
      console.log(`Client connected: ${clientId}`);
      
      ws.on('message', (data) => {
        try {
          const message = JSON.parse(data.toString());
          this.handleMessage(clientId, message);
        } catch (error) {
          console.error('Failed to parse message:', error);
          this.sendError(ws, 'Invalid message format');
        }
      });

      ws.on('close', () => {
        console.log(`Client disconnected: ${clientId}`);
        this.handleDisconnect(clientId);
      });

      ws.on('error', (error) => {
        console.error(`WebSocket error for client ${clientId}:`, error);
        this.handleDisconnect(clientId);
      });

      // Send welcome message
      this.sendMessage(ws, {
        type: 'connection_established',
        payload: { clientId },
        timestamp: Date.now(),
        messageId: uuidv4()
      });
    });

    console.log(`✅ FlexPort Multiplayer Server ready on ws://localhost:${this.port}`);
  }

  handleMessage(clientId, message) {
    const { type, payload, playerId, roomId } = message;
    
    console.log(`Message from ${clientId}: ${type}`);

    switch (type) {
      case 'create_room':
        this.handleCreateRoom(clientId, payload, playerId);
        break;
      case 'join_room':
        this.handleJoinRoom(clientId, payload, playerId);
        break;
      case 'leave_room':
        this.handleLeaveRoom(clientId, playerId);
        break;
      case 'player_ready':
        this.handlePlayerReady(clientId, payload, playerId);
        break;
      case 'room_list':
        this.handleRoomList(clientId);
        break;
      case 'game_action':
        this.handleGameAction(clientId, payload, playerId, roomId);
        break;
      case 'game_state_sync':
        this.handleGameStateSync(clientId, payload, playerId, roomId);
        break;
      case 'heartbeat':
        this.handleHeartbeat(clientId, playerId);
        break;
      case 'ship_update':
        this.handleShipUpdate(clientId, payload, playerId, roomId);
        break;
      case 'ship_batch_update':
        this.handleShipBatchUpdate(clientId, payload, playerId, roomId);
        break;
      case 'ship_full_sync':
        this.handleShipFullSync(clientId, payload, playerId, roomId);
        break;
      case 'ship_reconciliation':
        this.handleShipReconciliation(clientId, payload, playerId, roomId);
        break;
      case 'ping':
        this.handlePing(clientId, payload, playerId);
        break;
      case 'ship_position_update':
        this.handleShipPositionUpdate(clientId, payload, playerId, roomId);
        break;
      case 'ship_position_batch':
        this.handleShipPositionBatch(clientId, payload, playerId, roomId);
        break;
      case 'ship_input':
        this.handleShipInput(clientId, payload, playerId, roomId);
        break;
      case 'batch_update':
        this.handleBatchUpdate(clientId, payload, playerId, roomId);
        break;
      case 'delta_update':
        this.handleDeltaUpdate(clientId, payload, playerId, roomId);
        break;
      default:
        console.warn(`Unknown message type: ${type}`);
    }
  }

  handleCreateRoom(clientId, payload, playerId) {
    const { name, settings } = payload;
    const roomId = uuidv4();
    
    const room = {
      id: roomId,
      name,
      hostId: playerId,
      players: [],
      maxPlayers: 4,
      status: 'waiting',
      gameMode: 'competitive',
      settings: {
        maxTurns: 100,
        startingCash: 1000000,
        aiDifficulty: 1,
        enabledFeatures: ['trading', 'shipping', 'markets'],
        privateRoom: false,
        ...settings
      },
      createdAt: Date.now()
    };

    this.rooms.set(roomId, room);
    
    // Add player to room
    this.addPlayerToRoom(clientId, playerId, roomId, true);
    
    const ws = this.clients.get(clientId);
    this.sendMessage(ws, {
      type: 'create_room',
      payload: { room },
      timestamp: Date.now(),
      messageId: uuidv4()
    });
  }

  handleJoinRoom(clientId, payload, playerId) {
    const { roomId, password } = payload;
    const room = this.rooms.get(roomId);
    
    if (!room) {
      const ws = this.clients.get(clientId);
      this.sendError(ws, 'Room not found');
      return;
    }

    if (room.players.length >= room.maxPlayers) {
      const ws = this.clients.get(clientId);
      this.sendError(ws, 'Room is full');
      return;
    }

    if (room.settings.privateRoom && room.settings.password !== password) {
      const ws = this.clients.get(clientId);
      this.sendError(ws, 'Invalid password');
      return;
    }

    this.addPlayerToRoom(clientId, playerId, roomId, false);
    
    const ws = this.clients.get(clientId);
    this.sendMessage(ws, {
      type: 'join_room',
      payload: { room: this.rooms.get(roomId) },
      timestamp: Date.now(),
      messageId: uuidv4()
    });

    // Notify other players
    this.broadcastToRoom(roomId, {
      type: 'player_join',
      payload: {
        player: this.players.get(playerId),
        room: this.rooms.get(roomId)
      }
    }, clientId);
  }

  handleLeaveRoom(clientId, playerId) {
    const roomId = this.playerRooms.get(playerId);
    if (!roomId) return;

    this.removePlayerFromRoom(playerId, roomId);
    
    const room = this.rooms.get(roomId);
    if (room) {
      // Notify other players
      this.broadcastToRoom(roomId, {
        type: 'player_leave',
        payload: { playerId, room }
      });

      // If room is empty, delete it
      if (room.players.length === 0) {
        this.rooms.delete(roomId);
        console.log(`Room deleted: ${roomId}`);
      }
    }
  }

  handlePlayerReady(clientId, payload, playerId) {
    const { isReady } = payload;
    const player = this.players.get(playerId);
    const roomId = this.playerRooms.get(playerId);
    
    if (!player || !roomId) return;

    player.isReady = isReady;
    const room = this.rooms.get(roomId);
    
    // Update player in room
    const playerIndex = room.players.findIndex(p => p.id === playerId);
    if (playerIndex >= 0) {
      room.players[playerIndex] = player;
    }

    // Broadcast room update
    this.broadcastToRoom(roomId, {
      type: 'room_update',
      payload: { room }
    });

    // Check if all players are ready and game can start
    if (room.players.length >= 2 && room.players.every(p => p.isReady)) {
      this.startGame(roomId);
    }
  }

  handleRoomList(clientId) {
    const publicRooms = Array.from(this.rooms.values())
      .filter(room => !room.settings.privateRoom && room.status === 'waiting')
      .map(room => ({
        ...room,
        players: room.players.map(p => ({ id: p.id, name: p.name, isReady: p.isReady }))
      }));

    const ws = this.clients.get(clientId);
    this.sendMessage(ws, {
      type: 'room_list',
      payload: { rooms: publicRooms },
      timestamp: Date.now(),
      messageId: uuidv4()
    });
  }

  handleGameAction(clientId, payload, playerId, roomId) {
    // Broadcast game action to other players in the room
    this.broadcastToRoom(roomId, {
      type: 'game_action',
      payload
    }, clientId);
  }

  handleGameStateSync(clientId, payload, playerId, roomId) {
    const room = this.rooms.get(roomId);
    if (!room || room.hostId !== playerId) return;

    // Only host can sync game state
    this.broadcastToRoom(roomId, {
      type: 'game_state_sync',
      payload
    }, clientId);
  }

  handleHeartbeat(clientId, playerId) {
    const player = this.players.get(playerId);
    if (player) {
      player.lastHeartbeat = Date.now();
      player.connectionStatus = 'connected';
    }

    const ws = this.clients.get(clientId);
    this.sendMessage(ws, {
      type: 'heartbeat',
      payload: { playerId },
      timestamp: Date.now(),
      messageId: uuidv4()
    });
  }

  handleShipUpdate(clientId, payload, playerId, roomId) {
    if (!roomId) return;
    
    // Broadcast ship update to all other players in the room
    this.broadcastToRoom(roomId, {
      type: 'ship_update',
      payload: { ...payload, playerId }
    }, clientId);
  }

  handleShipBatchUpdate(clientId, payload, playerId, roomId) {
    if (!roomId) return;
    
    // Add playerId to each update
    const updatesWithPlayerId = {
      ...payload,
      updates: payload.updates.map(update => ({
        ...update,
        playerId
      }))
    };
    
    // Broadcast batch update to all other players in the room
    this.broadcastToRoom(roomId, {
      type: 'ship_batch_update',
      payload: updatesWithPlayerId
    }, clientId);
  }

  handleShipFullSync(clientId, payload, playerId, roomId) {
    if (!roomId) return;
    
    const room = this.rooms.get(roomId);
    if (!room) return;
    
    // Store ship state for this player
    if (!room.shipStates) {
      room.shipStates = new Map();
    }
    room.shipStates.set(playerId, payload.ships);
    
    // When a new player joins, send them the full ship state
    const ws = this.clients.get(clientId);
    if (ws) {
      // Collect all ships from all players
      const allShips = [];
      room.shipStates.forEach((ships, pid) => {
        ships.forEach(ship => {
          allShips.push({ ...ship, playerId: pid });
        });
      });
      
      this.sendMessage(ws, {
        type: 'ship_full_sync',
        payload: { ships: allShips },
        timestamp: Date.now(),
        messageId: uuidv4()
      });
    }
  }

  handleShipReconciliation(clientId, payload, playerId, roomId) {
    if (!roomId) return;
    
    // Server-authoritative reconciliation
    // In a real implementation, the server would validate the ship position
    // For now, we'll just broadcast the reconciliation to the affected player
    const targetPlayer = this.players.get(payload.targetPlayerId);
    if (targetPlayer) {
      const ws = this.clients.get(targetPlayer.clientId);
      if (ws) {
        this.sendMessage(ws, {
          type: 'ship_reconciliation',
          payload
        });
      }
    }
  }

  handleDisconnect(clientId) {
    // Find player associated with this client
    let disconnectedPlayerId = null;
    for (const [playerId, player] of this.players.entries()) {
      if (player.clientId === clientId) {
        disconnectedPlayerId = playerId;
        player.connectionStatus = 'disconnected';
        break;
      }
    }

    if (disconnectedPlayerId) {
      const roomId = this.playerRooms.get(disconnectedPlayerId);
      if (roomId) {
        const room = this.rooms.get(roomId);
        if (room) {
          // Notify other players
          this.broadcastToRoom(roomId, {
            type: 'player_leave',
            payload: { playerId: disconnectedPlayerId, room }
          });

          // Remove player from room
          this.removePlayerFromRoom(disconnectedPlayerId, roomId);
          
          // Delete room if empty
          if (room.players.length === 0) {
            this.rooms.delete(roomId);
          }
        }
      }
    }

    this.clients.delete(clientId);
  }

  addPlayerToRoom(clientId, playerId, roomId, isHost) {
    const playerColors = ['#3b82f6', '#ef4444', '#10b981', '#f59e0b', '#8b5cf6', '#06b6d4', '#f97316', '#ec4899'];
    const room = this.rooms.get(roomId);
    const usedColors = room.players.map(p => p.color);
    const availableColor = playerColors.find(color => !usedColors.includes(color)) || playerColors[0];

    const player = {
      id: playerId,
      name: `Player ${playerId.substring(0, 8)}`,
      isHost,
      isReady: false,
      color: availableColor,
      connectionStatus: 'connected',
      lastHeartbeat: Date.now(),
      clientId
    };

    this.players.set(playerId, player);
    this.playerRooms.set(playerId, roomId);
    
    room.players.push(player);
  }

  removePlayerFromRoom(playerId, roomId) {
    const room = this.rooms.get(roomId);
    if (room) {
      room.players = room.players.filter(p => p.id !== playerId);
      
      // If host left, assign new host
      if (room.hostId === playerId && room.players.length > 0) {
        room.hostId = room.players[0].id;
        room.players[0].isHost = true;
      }
    }

    this.players.delete(playerId);
    this.playerRooms.delete(playerId);
  }

  startGame(roomId) {
    const room = this.rooms.get(roomId);
    if (!room) return;

    room.status = 'starting';
    room.startedAt = Date.now();

    // Create player assignments
    const playerAssignments = {};
    room.players.forEach((player, index) => {
      playerAssignments[player.id] = `player-${index + 1}`;
    });

    // Create initial multiplayer game state
    const gameState = {
      gameTime: 0,
      turn: 1,
      // Add other necessary game state here
    };

    // Broadcast game start
    this.broadcastToRoom(roomId, {
      type: 'game_start',
      payload: { gameState, playerAssignments }
    });

    room.status = 'in_progress';
  }

  broadcastToRoom(roomId, message, excludeClientId = null) {
    const room = this.rooms.get(roomId);
    if (!room) return;

    room.players.forEach(player => {
      if (player.clientId !== excludeClientId) {
        const ws = this.clients.get(player.clientId);
        if (ws && ws.readyState === WebSocket.OPEN) {
          this.sendMessage(ws, {
            ...message,
            timestamp: Date.now(),
            messageId: uuidv4()
          });
        }
      }
    });
  }

  sendMessage(ws, message) {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify(message));
    }
  }

  sendError(ws, error) {
    this.sendMessage(ws, {
      type: 'error',
      payload: { error },
      timestamp: Date.now(),
      messageId: uuidv4()
    });
  }

  getStats() {
    return {
      connectedClients: this.clients.size,
      totalPlayers: this.players.size,
      totalRooms: this.rooms.size,
      activeGames: Array.from(this.rooms.values()).filter(r => r.status === 'in_progress').length
    };
  }
  
  // New optimized message handlers
  handlePing(clientId, payload, playerId) {
    const ws = this.clients.get(clientId);
    if (!ws) return;
    
    this.sendMessage(ws, {
      type: 'ping_response',
      payload: {
        clientTime: payload.clientTime,
        serverTime: Date.now()
      },
      timestamp: Date.now(),
      messageId: uuidv4()
    });
  }
  
  handleShipPositionUpdate(clientId, payload, playerId, roomId) {
    if (!roomId) return;
    
    // Add server timestamp and sequence number
    const update = {
      ...payload,
      playerId,
      timestamp: Date.now(),
      sequenceNumber: this.getNextSequenceNumber(roomId)
    };
    
    // Broadcast to room with lag compensation data
    this.broadcastToRoom(roomId, {
      type: 'ship_position_update',
      payload: update
    }, clientId);
  }
  
  handleShipPositionBatch(clientId, payload, playerId, roomId) {
    if (!roomId) return;
    
    const timestamp = Date.now();
    const updates = payload.updates.map(update => ({
      ...update,
      playerId,
      timestamp,
      sequenceNumber: this.getNextSequenceNumber(roomId)
    }));
    
    this.broadcastToRoom(roomId, {
      type: 'ship_position_batch',
      payload: { updates }
    }, clientId);
  }
  
  handleShipInput(clientId, payload, playerId, roomId) {
    if (!roomId) return;
    
    // Process input and calculate resulting state
    const processedInput = {
      ...payload,
      playerId,
      timestamp: Date.now(),
      sequenceNumber: payload.sequenceNumber || this.getNextSequenceNumber(roomId)
    };
    
    // Send acknowledgment back to sender
    const ws = this.clients.get(clientId);
    if (ws) {
      this.sendMessage(ws, {
        type: 'ship_input_ack',
        payload: processedInput
      });
    }
    
    // Broadcast to other players
    this.broadcastToRoom(roomId, {
      type: 'ship_input_received',
      payload: processedInput
    }, clientId);
  }
  
  handleBatchUpdate(clientId, payload, playerId, roomId) {
    if (!roomId) return;
    
    // Process batched updates efficiently
    const timestamp = Date.now();
    this.broadcastToRoom(roomId, {
      type: 'batch_update',
      payload: {
        ...payload,
        playerId,
        timestamp
      }
    }, clientId);
  }
  
  handleDeltaUpdate(clientId, payload, playerId, roomId) {
    if (!roomId) return;
    
    // Handle compressed delta updates
    this.broadcastToRoom(roomId, {
      type: 'delta_update',
      payload: {
        ships: payload.ships,
        playerId,
        timestamp: Date.now()
      }
    }, clientId);
  }
  
  // Sequence number management for lag compensation
  roomSequenceNumbers = new Map();
  
  getNextSequenceNumber(roomId) {
    let seq = this.roomSequenceNumbers.get(roomId) || 0;
    seq++;
    this.roomSequenceNumbers.set(roomId, seq);
    return seq;
  }
}

// Start server
const server = new MultiplayerServer(8080);

// Log stats every 30 seconds
setInterval(() => {
  const stats = server.getStats();
  console.log(`📊 Server Stats: ${stats.connectedClients} clients, ${stats.totalPlayers} players, ${stats.totalRooms} rooms, ${stats.activeGames} active games`);
}, 30000);

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\n🛑 Shutting down multiplayer server...');
  server.server.close(() => {
    console.log('✅ Server shut down gracefully');
    process.exit(0);
  });
});

process.on('SIGTERM', () => {
  console.log('\n🛑 Received SIGTERM, shutting down...');
  server.server.close(() => {
    console.log('✅ Server shut down gracefully');
    process.exit(0);
  });
});