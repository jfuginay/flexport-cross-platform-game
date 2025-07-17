# FlexPort Performance & Lag Compensation Test Guide

This guide helps you verify that the performance optimizations and lag compensation systems are working correctly for 4+ concurrent players at 60 FPS.

## Performance Optimizations Implemented

### 1. Enhanced Lag Compensation (NetworkSystem.ts)
- **Client-side prediction**: Ships move smoothly without waiting for server confirmation
- **Server reconciliation**: Corrects prediction errors when server updates arrive
- **Interpolation & extrapolation**: Smooth movement for remote players with up to 200ms extrapolation
- **Adaptive jitter buffer**: Dynamically adjusts interpolation delay based on network conditions
- **Snapshot buffering**: Maintains history for accurate interpolation between states

### 2. Bandwidth Optimization
- **Delta compression**: Only sends changed data (position, status)
- **Message batching**: Groups updates every 50ms to reduce overhead
- **Priority-based updates**: Ships in combat or near other players get higher update rates
- **Full sync intervals**: Complete state sync every 5 seconds with deltas in between
- **Bandwidth monitoring**: Tracks usage to stay under 500KB/s per player

### 3. Rendering Performance (OptimizedRenderSystem.ts)
- **Frame budget management**: Allocates time for each rendering phase
- **Dynamic quality adjustment**: Automatically reduces quality to maintain 60 FPS
- **Intelligent culling**: Only renders visible objects with spatial indexing
- **Object pooling**: Reuses sprites and particles to reduce garbage collection
- **LOD system**: Reduces detail for distant ships
- **Particle limits**: Dynamically adjusts particle count based on performance
- **Dynamic resolution**: Scales rendering resolution when needed

### 4. Server Optimizations (websocket-server.js)
- **Efficient message routing**: Direct broadcast to room members
- **Sequence numbering**: Ensures proper order for lag compensation
- **Ping/latency tracking**: Measures real-time network conditions
- **Compressed message formats**: Minimal data transfer

## Testing Instructions

### Setup
1. Start the WebSocket server:
   ```bash
   cd server
   npm install
   npm start
   ```

2. Start the game server:
   ```bash
   npm run dev
   ```

3. Open 4+ browser windows/tabs at `http://localhost:5173`

### Performance Tests

#### Test 1: Frame Rate Stability
1. Press **F3** in each window to show performance monitor
2. Create a multiplayer room and have all players join
3. Start the game and have all players move their ships
4. **Expected**: All clients maintain 55-60 FPS
5. **Monitor**: FPS graph should be stable (green line)

#### Test 2: Lag Compensation
1. Open browser dev tools Network tab
2. Set network throttling to "Fast 3G" for one player
3. Move ships and observe movement
4. **Expected**: 
   - Local ship moves immediately (prediction)
   - Remote ships move smoothly (interpolation)
   - No jerky corrections under 100ms latency

#### Test 3: Bandwidth Usage
1. Check bandwidth monitor in performance UI
2. Have all players actively move ships
3. **Expected**: 
   - Bandwidth stays under 500KB/s per player
   - Delta updates show in network traffic
   - Full sync every 5 seconds

#### Test 4: Dynamic Quality
1. Open many browser tabs to stress the system
2. Observe quality settings in performance monitor
3. **Expected**:
   - Quality automatically drops from Ultra → High → Medium → Low
   - FPS recovers to 60 when quality drops
   - Particles and effects reduce appropriately

#### Test 5: Stress Test
1. Have all players create maximum ships (10 each)
2. Set all ships to travel between distant ports
3. Enable trade route visualization
4. **Expected**:
   - System maintains playable performance (>30 FPS)
   - Culling removes off-screen ships
   - LOD reduces detail for distant ships

### Performance Metrics to Monitor

1. **FPS**: Should stay at 60 (±5) during normal gameplay
2. **Frame Time**: Should be under 16.67ms consistently
3. **Network Latency**: Compensation works up to 100ms
4. **Draw Calls**: Should stay under 50 for good performance
5. **Sprite Count**: Should match visible ships (culling working)
6. **Particle Count**: Should respect quality limits
7. **Bandwidth**: Under 500KB/s per player

### Debugging Performance Issues

If performance is poor:

1. **Check Console**: Look for errors or warnings
2. **Network Tab**: Verify WebSocket messages are compressed
3. **Performance Profiler**: Use Chrome DevTools to find bottlenecks
4. **Quality Settings**: Manually adjust in code if auto-adjust fails

### Configuration Options

In `NetworkSystem.ts`:
- `MAX_PREDICTION_TIME`: Maximum prediction window (default: 500ms)
- `INTERPOLATION_DELAY`: Base interpolation delay (default: 100ms)
- `INPUT_RATE_LIMIT`: Maximum inputs per second (default: 60)

In `OptimizedRenderSystem.ts`:
- `frameBudget`: Target frame time (default: 16.67ms)
- `MAX_FRAME_SKIP`: Maximum consecutive frames to skip (default: 2)

In `Performance.ts`:
- Quality presets: low, medium, high, ultra
- Auto-quality thresholds

## Verification Checklist

- [ ] 4 players can connect and play simultaneously
- [ ] All players maintain 55-60 FPS during normal gameplay
- [ ] Ship movement is smooth with <100ms latency
- [ ] Bandwidth usage stays under 500KB/s per player
- [ ] No visual glitches or jerky movement
- [ ] Quality automatically adjusts to maintain performance
- [ ] Performance monitor shows accurate real-time metrics
- [ ] Game remains playable even under stress conditions

## Known Optimizations

1. **Prediction works best for linear movement** - Complex paths may show more correction
2. **Interpolation delay is adaptive** - May increase slightly on poor connections
3. **Particle effects are first to be reduced** - This is intentional for performance
4. **Resolution scaling is subtle** - You may not notice it happening

## Troubleshooting

**Problem**: Low FPS on all clients
- Check if V-Sync is enabled in browser
- Verify hardware acceleration is on
- Close other resource-intensive applications

**Problem**: Jerky ship movement
- Check network latency in performance monitor
- Verify lag compensation is enabled
- Ensure server is running on same network

**Problem**: High bandwidth usage
- Check if delta compression is working
- Verify message batching is enabled
- Look for unnecessary state updates

**Problem**: Ships teleporting
- This indicates prediction errors
- Check if server reconciliation is working
- May need to tune POSITION_CORRECTION_RATE