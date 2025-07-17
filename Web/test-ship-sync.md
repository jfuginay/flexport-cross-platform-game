# Real-time Ship Movement Synchronization Test Guide

## Overview
This guide helps test the real-time ship movement synchronization feature implemented for Container 2.

## Setup
1. Start the WebSocket server:
   ```bash
   cd server
   npm install
   npm start
   ```

2. In a new terminal, start the web client:
   ```bash
   npm run dev
   ```

3. Open multiple browser windows/tabs and navigate to the game (http://localhost:5173)

## Testing Steps

### 1. Basic Multiplayer Connection
- Press 'M' in each browser window to open the multiplayer lobby
- Create a room in the first window
- Join the room from other windows
- All players should click "Ready"
- The game should start synchronously

### 2. Ship Movement Synchronization
- Once the game starts, observe the initial ship positions
- In one window, select a ship and assign it to a trade route
- **Expected:** The ship movement should be visible in real-time across all connected clients

### 3. Smooth Interpolation
- Watch ships moving between ports
- **Expected:** Movement should be smooth without jittering or rubber-banding
- Ships should follow curved paths and maintain consistent speed

### 4. Multiple Ships
- Create multiple ships in different clients
- Assign them to different routes
- **Expected:** All ships from all players should be visible and moving smoothly

### 5. Player Colors
- Each player's ships should have a unique color
- Colors should be consistent across all clients

### 6. Network Lag Handling
- Open browser developer tools (F12) → Network tab
- Add throttling (e.g., "Slow 3G")
- **Expected:** Ships should still move smoothly with interpolation
- Some delay is acceptable but movement should not be jerky

### 7. Disconnection/Reconnection
- Close one browser tab while ships are moving
- **Expected:** That player's ships should disappear from other clients
- Rejoin the room
- **Expected:** Ships should reappear and sync correctly

## Performance Metrics
- Open browser console (F12)
- Check for any error messages
- Monitor network traffic in Network tab
- Ship updates should be sent every 100ms
- Updates should use delta compression (only changed values)

## Known Limitations
- Maximum 4 players per room
- Ships may briefly snap to positions after network interruptions
- Trade route assignments are not yet synchronized (only movement)

## Troubleshooting
1. **Ships not appearing:** Check WebSocket connection in browser console
2. **Jerky movement:** Ensure stable network connection
3. **Ships in wrong positions:** May need to refresh all clients

## Success Criteria
✅ Ships move simultaneously across all clients
✅ Movement is smooth with interpolation
✅ <100ms synchronization delay
✅ Handles 4 players with multiple ships each
✅ Efficient network usage (delta updates)
✅ Player-specific ship colors
✅ Graceful handling of disconnections