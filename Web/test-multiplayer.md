# Multiplayer Testing Guide

## Quick Test Instructions

### 1. Start the Development Environment
```bash
cd /Users/jfuginay/Documents/dev/FlexPort/Web
npm run dev:full
```

This will start both the WebSocket server (port 8080) and the web client (port 3000).

### 2. Test Local Multiplayer

**Step 1: Open Multiple Browser Windows**
- Open http://localhost:3000 in 2-3 browser windows or tabs
- Each represents a different player

**Step 2: Access Multiplayer Lobby**
- In any window, press the **M** key OR click "Play Multiplayer" button
- The lobby should open and show "Connected" status

**Step 3: Create a Room**
- In the first window, click "Create New Room"
- Enter a room name (e.g., "Test Game")
- Leave settings as default
- Click "Create Room"

**Step 4: Join the Room**
- In other windows, press **M** to open multiplayer lobby
- You should see the created room in the "Available Rooms" list
- Click on the room to join it

**Step 5: Ready Up and Start**
- In each window, click "Ready Up" button
- When 2+ players are ready, the host can click "Start Game"
- All players should be redirected to the game simultaneously

### Expected Results

✅ **Connection**: All clients show "Connected" status
✅ **Room Creation**: Room appears in available rooms list
✅ **Room Joining**: Multiple players can join the same room
✅ **Player List**: Real-time updates of players in the room
✅ **Ready Status**: Ready/not ready status updates in real-time
✅ **Game Start**: Synchronized game launch across all clients

### Troubleshooting

**"Connection Failed" or "Disconnected"**
- Ensure WebSocket server is running: `npm run server`
- Check console for detailed error messages
- Verify no firewall blocking port 8080

**Room Not Visible**
- Click "Refresh" button in lobby
- Check if room was created successfully in first window
- Ensure room is not private (default is public)

**Players Not Syncing**
- Check browser console for WebSocket errors
- Verify all players joined the same room ID
- Restart server if issues persist

### Console Commands for Debugging

In browser console, access the game engine:
```javascript
// Check multiplayer status
window.gameEngine.getMultiplayerSystem().getConnectionStats()

// Check current room
window.gameEngine.getMultiplayerSystem().getCurrentRoom()

// Check multiplayer state
window.gameEngine.getMultiplayerSystem().getMultiplayerState()
```

### Architecture Validation

The implementation includes:
- ✅ Real-time WebSocket communication
- ✅ Room-based multiplayer lobbies
- ✅ Player synchronization and ready states
- ✅ Game start coordination
- ✅ Connection resilience with reconnection
- ✅ Clean UI with modern design
- ✅ TypeScript type safety
- ✅ Integration with existing PIXI.js game engine

### Performance Benchmarks

Expected performance on localhost:
- Message round-trip: <10ms
- Room updates: Real-time (<100ms)
- Connection establishment: <2 seconds
- Game synchronization: Instant across clients

This multiplayer system meets all Game Week requirements for real-time 2+ player interaction and provides a solid foundation for logistics simulation competition.