#!/bin/bash

# FlexPort Game Week - 8 Claude Container Setup
# Priority: Web platform first, then iOS, then Android

echo "🚢 Setting up FlexPort Game Week Claude Swarm..."
echo "Priority: Web → iOS → Android"

# Create container directories
mkdir -p claude_containers/{1..8}

# Container 1: Web Multiplayer Lobby & Matchmaking
cat > claude_containers/1/task.md << 'EOF'
# Container 1: Web Multiplayer Lobby & Matchmaking System

## Priority: CRITICAL - Web Platform
## Objective: Implement real-time multiplayer lobby and matchmaking

### Requirements:
- Create functional lobby system for 2-4 players
- Implement WebSocket-based matchmaking
- Add game room creation and joining
- Real-time player list updates
- Game start coordination

### Focus Areas:
1. `Web/src/systems/MultiplayerSystem.ts` - Core multiplayer logic
2. `Web/src/components/LobbyComponent.ts` - UI components  
3. `Web/src/networking/` - WebSocket handlers
4. Integration with existing game state management

### Success Criteria:
- 2+ players can join same game room
- Real-time lobby updates
- Synchronized game start
- <100ms lobby response time

### Files to Focus On:
- Web/src/systems/
- Web/src/networking/
- Web/package.json (WebSocket dependencies)
EOF

# Container 2: Web Real-time Ship Movement Sync
cat > claude_containers/2/task.md << 'EOF'
# Container 2: Web Real-time Ship Movement Synchronization

## Priority: CRITICAL - Web Platform  
## Objective: Synchronize ship movements between players in real-time

### Requirements:
- Real-time ship position updates across players
- Smooth interpolation for network lag
- Conflict resolution for simultaneous moves
- Efficient delta compression

### Focus Areas:
1. `Web/src/systems/RenderSystem.ts` - Ship rendering updates
2. `Web/src/systems/ShipSystem.ts` - Movement logic
3. `Web/src/networking/StateSynchronization.ts` - Network sync
4. Position interpolation and prediction

### Success Criteria:
- Ships move smoothly across all clients
- <100ms movement synchronization
- No visual glitches or rubber-banding
- Handles 4 concurrent players

### Files to Focus On:
- Web/src/systems/RenderSystem.ts
- Web/src/systems/ShipSystem.ts
- Web/src/types/index.ts (networking types)
EOF

# Container 3: Web Player Progression System
cat > claude_containers/3/task.md << 'EOF'
# Container 3: Web Player Progression & Leveling System

## Priority: HIGH - Web Platform
## Objective: Add character progression and leveling mechanics

### Requirements:
- Player levels based on economic performance
- Experience points for trades and objectives
- Ship upgrades and fleet expansion
- Achievement system with unlocks

### Focus Areas:
1. `Web/src/systems/ProgressionSystem.ts` - New system
2. `Web/src/systems/EconomicSystem.ts` - XP integration
3. `Web/src/components/ProgressionUI.ts` - UI components
4. Persistent progression storage

### Success Criteria:
- Players gain XP from successful trades
- Clear progression path with levels 1-50
- Meaningful upgrades and unlocks
- Visual progression feedback

### Files to Focus On:
- Web/src/systems/ (new ProgressionSystem)
- Web/src/systems/EconomicSystem.ts
- Web/src/types/index.ts (progression types)
EOF

# Container 4: Web Performance & Lag Compensation
cat > claude_containers/4/task.md << 'EOF'
# Container 4: Web Performance Optimization & Lag Compensation

## Priority: HIGH - Web Platform
## Objective: Optimize performance and implement lag compensation

### Requirements:
- Client-side prediction for responsive gameplay
- Server reconciliation for authoritative state
- Bandwidth optimization with compression
- Performance monitoring and metrics

### Focus Areas:
1. `Web/src/systems/NetworkSystem.ts` - Lag compensation
2. `Web/src/utils/Performance.ts` - Monitoring
3. `Web/src/systems/RenderSystem.ts` - FPS optimization
4. WebSocket message compression

### Success Criteria:
- 60 FPS with 4 concurrent players
- <100ms latency compensation
- <500kb/s bandwidth per player
- Real-time performance metrics

### Files to Focus On:
- Web/src/systems/NetworkSystem.ts
- Web/src/systems/RenderSystem.ts
- Web/src/utils/ (performance utilities)
EOF

# Container 5: iOS Multiplayer Implementation
cat > claude_containers/5/task.md << 'EOF'
# Container 5: iOS Multiplayer Implementation

## Priority: MEDIUM - iOS Platform
## Objective: Port web multiplayer features to iOS

### Requirements:
- Swift/Combine integration with multiplayer systems
- iOS-specific networking optimizations
- Integration with existing MultiplayerManager.swift
- Background/foreground handling

### Focus Areas:
1. `FlexPort iOS/Sources/FlexPort/Networking/MultiplayerManager.swift`
2. `FlexPort iOS/Sources/FlexPort/Networking/WebSocketHandler.swift`
3. iOS-specific state management
4. Platform-specific optimizations

### Success Criteria:
- iOS can join web-hosted multiplayer games
- Cross-platform compatibility
- Proper iOS lifecycle handling
- Native iOS UI integration

### Files to Focus On:
- FlexPort iOS/Sources/FlexPort/Networking/
- FlexPort iOS/Sources/FlexPort/Core/GameManager.swift
EOF

# Container 6: iOS Progression Systems
cat > claude_containers/6/task.md << 'EOF'
# Container 6: iOS Progression Systems

## Priority: MEDIUM - iOS Platform
## Objective: Implement progression features for iOS

### Requirements:
- Swift progression system matching web features
- Core Data persistence for player progress
- iOS-specific achievement integration
- Game Center leaderboards

### Focus Areas:
1. iOS progression system implementation
2. Core Data models for persistence
3. Game Center integration
4. SwiftUI progression UI

### Success Criteria:
- Feature parity with web progression
- Persistent progress across sessions
- Native iOS achievement notifications
- Game Center leaderboard integration

### Files to Focus On:
- FlexPort iOS/Sources/FlexPort/Game/Systems/
- iOS Core Data models
- Game Center integration
EOF

# Container 7: Android Multiplayer Implementation  
cat > claude_containers/7/task.md << 'EOF'
# Container 7: Android Multiplayer Implementation

## Priority: MEDIUM - Android Platform
## Objective: Port multiplayer features to Android

### Requirements:
- Kotlin/Coroutines multiplayer integration
- Android-specific networking with lifecycle awareness
- Integration with existing MultiplayerManager.kt
- Foreground service for background networking

### Focus Areas:
1. `FlexPort Android/app/src/main/java/com/flexport/game/networking/MultiplayerManager.kt`
2. Android WebSocket implementation
3. Jetpack Compose multiplayer UI
4. Android-specific optimizations

### Success Criteria:
- Android can join cross-platform games
- Proper Android lifecycle handling
- Material Design 3 multiplayer UI
- Background networking support

### Files to Focus On:
- FlexPort Android/app/src/main/java/com/flexport/game/networking/
- Jetpack Compose UI components
EOF

# Container 8: Android Progression Systems
cat > claude_containers/8/task.md << 'EOF'
# Container 8: Android Progression Systems

## Priority: MEDIUM - Android Platform  
## Objective: Implement progression features for Android

### Requirements:
- Kotlin progression system with feature parity
- Room database persistence
- Android-specific achievement system
- Google Play Games integration

### Focus Areas:
1. Android progression system implementation
2. Room database models
3. Google Play Games Services
4. Jetpack Compose progression UI

### Success Criteria:
- Feature parity with web progression
- Room database persistence
- Google Play achievements
- Material Design progression UI

### Files to Focus On:
- Android progression system implementation
- Room database setup
- Google Play Games integration
EOF

# Create launch commands for each container
for i in {1..8}; do
    cat > claude_containers/$i/launch.sh << EOF
#!/bin/bash
echo "🚀 Launching Claude Container $i"
echo "Task: \$(head -1 claude_containers/$i/task.md | sed 's/# //')"
echo "Working Directory: /Users/jfuginay/Documents/dev/FlexPort"
echo "Task File: \$(pwd)/claude_containers/$i/task.md"
echo ""
echo "📋 Task Details:"
cat claude_containers/$i/task.md
echo ""
echo "🤖 Ready for Claude development..."
EOF
    chmod +x claude_containers/$i/launch.sh
done

# Create master launch script
cat > launch_claude_swarm.sh << 'EOF'
#!/bin/bash

echo "🚢 FlexPort Game Week - Claude Swarm Launch"
echo "========================================="

# Priority order: Web first (containers 1-4), then iOS (5-6), then Android (7-8)
PRIORITY_ORDER=(1 2 3 4 5 6 7 8)
CONTAINER_NAMES=(
    "Web Multiplayer Lobby"
    "Web Ship Sync" 
    "Web Progression"
    "Web Performance"
    "iOS Multiplayer"
    "iOS Progression"
    "Android Multiplayer"
    "Android Progression"
)

echo "📊 Task Priority Matrix:"
echo "1. 🌐 WEB PLATFORM (Critical)"
for i in {0..3}; do
    container_num=${PRIORITY_ORDER[$i]}
    echo "   Container $container_num: ${CONTAINER_NAMES[$i]}"
done

echo ""
echo "2. 📱 iOS PLATFORM (Medium)"
for i in {4..5}; do
    container_num=${PRIORITY_ORDER[$i]}
    echo "   Container $container_num: ${CONTAINER_NAMES[$i]}"
done

echo ""
echo "3. 🤖 ANDROID PLATFORM (Medium)"
for i in {6..7}; do
    container_num=${PRIORITY_ORDER[$i]}
    echo "   Container $container_num: ${CONTAINER_NAMES[$i]}"
done

echo ""
echo "🚀 Launch individual containers with:"
for i in {1..8}; do
    echo "   ./claude_containers/$i/launch.sh"
done

echo ""
echo "📝 Each container has its task definition in:"
echo "   ./claude_containers/[1-8]/task.md"

echo ""
echo "🎯 Focus: Start with Web containers (1-4) for maximum impact!"
EOF

chmod +x launch_claude_swarm.sh

# Create progress tracking
cat > claude_swarm_progress.md << 'EOF'
# FlexPort Claude Swarm Progress Tracker

## Web Platform (Priority 1) 🌐
- [ ] Container 1: Multiplayer Lobby & Matchmaking
- [ ] Container 2: Real-time Ship Movement Sync  
- [ ] Container 3: Player Progression & Leveling
- [ ] Container 4: Performance & Lag Compensation

## iOS Platform (Priority 2) 📱
- [ ] Container 5: iOS Multiplayer Implementation
- [ ] Container 6: iOS Progression Systems

## Android Platform (Priority 3) 🤖
- [ ] Container 7: Android Multiplayer Implementation  
- [ ] Container 8: Android Progression Systems

## Success Metrics
- [ ] 2+ players can play together in real-time
- [ ] <100ms multiplayer latency
- [ ] Working progression system with levels
- [ ] 60 FPS performance with multiple players
- [ ] Cross-platform compatibility

## Timeline
- Day 1-2: Web containers 1-4 (Critical)
- Day 3: iOS containers 5-6 (if web complete)
- Day 4: Android containers 7-8 (if iOS complete)
- Day 5-7: Testing, optimization, polish
EOF

echo "✅ Claude Swarm setup complete!"
echo ""
echo "📁 Created:"
echo "  - 8 container directories with specific tasks"
echo "  - Individual launch scripts for each container"
echo "  - Master launch script (./launch_claude_swarm.sh)"
echo "  - Progress tracker (./claude_swarm_progress.md)"
echo ""
echo "🚀 Next steps:"
echo "1. Run: ./launch_claude_swarm.sh (to see overview)"
echo "2. Start with: ./claude_containers/1/launch.sh (Web Multiplayer Lobby)"
echo "3. Focus on Web platform first for maximum Game Week impact!"
echo ""
echo "🎯 Priority: Web containers 1-4 will give you the biggest wins for Game Week requirements!"