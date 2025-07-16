# FlexPort iOS Map & Gameplay Enhancement PRD
## 5-Container Claude Swarm for Immediate Improvements

### Executive Summary
Deploy 5 specialized Claude containers to dramatically enhance the current working FlexPort iOS game with advanced map rendering, gameplay mechanics, and user experience improvements.

### Current State Analysis
- ✅ Basic ocean map with 7 ports working
- ✅ Ship purchasing and trade route creation functional  
- ✅ Build system working, app running in simulator
- ❌ Map needs realistic geography and Metal rendering
- ❌ Ships need movement animation and AI
- ❌ Economic simulation needs depth
- ❌ UI needs polish and advanced interactions
- ❌ Game needs progression systems

### Container Architecture

#### Container 1: Advanced Metal Map Renderer
**Responsibility**: Transform basic ocean view into realistic world map
- Implement real Earth geography with continent shapes
- Add Gerstner wave ocean simulation with realistic physics
- Create dynamic lighting and weather systems
- Add zoom levels with different detail (satellite → tactical → port view)
- Implement ship wake effects and trail rendering
- Add day/night cycle with city lights

**Target**: Replace BasicWorldMapView with full Metal-rendered Earth

#### Container 2: Ship AI & Movement System  
**Responsibility**: Bring ships to life with intelligent movement
- Create realistic ship movement physics (acceleration, turning, momentum)
- Implement AI pathfinding between ports using A* algorithm
- Add ship behavior states (loading, traveling, docking, waiting)
- Create collision avoidance and traffic management
- Add ship formations and convoy systems
- Implement weather effects on ship movement

**Target**: Ships move realistically between ports with smart AI

#### Container 3: Advanced Economic Engine
**Responsibility**: Create sophisticated market simulation
- Implement supply/demand for 20+ goods types
- Add dynamic pricing based on port distance and scarcity
- Create market events (storms, port strikes, trade wars)
- Add futures contracts and speculation mechanics
- Implement company reputation and relationship systems
- Create economic indicators and market analysis tools

**Target**: Deep economic simulation driving strategic decisions

#### Container 4: UI/UX Enhancement & Interactions
**Responsibility**: Polish interface and add advanced interactions
- Create glass morphism design system for all UI elements
- Add smooth animations and transitions between screens
- Implement gesture-based ship selection and multi-touch commands
- Create contextual menus and radial interaction systems
- Add tutorial system and onboarding flow
- Implement settings, preferences, and accessibility features

**Target**: Premium mobile game interface with intuitive interactions

#### Container 5: Game Progression & Content
**Responsibility**: Add depth and progression systems
- Create technology research tree (faster ships, better ports, AI systems)
- Add achievements and milestone tracking
- Implement story mode with scenarios and challenges
- Create sandbox mode with customizable parameters
- Add multiplayer lobby and competitive modes
- Implement save/load system and game statistics

**Target**: Complete game experience with progression and replayability

### Coordination Protocol

Each container will:
1. Pull latest code and analyze current state
2. Create feature branch `enhancement-container-X`
3. Report progress every 20 minutes to shared status file
4. Coordinate through `ENHANCEMENT_PROGRESS.md`
5. Test changes with simulator before committing
6. Handle merge conflicts through shared coordination

### Success Metrics
- Map renders realistic Earth geography at 60 FPS
- Ships move smoothly with realistic physics
- Economic simulation with 20+ goods and dynamic pricing
- Polished UI with smooth animations
- Complete game progression system

### Timeline
- Minutes 1-30: Containers 1-2 (Core rendering and movement)
- Minutes 31-60: Containers 3-4 (Economics and UI)
- Minutes 61-90: Container 5 (Game progression)
- Minutes 91-120: Integration testing and bug fixes

### Launch Commands

```bash
# Container 1: Advanced Metal Map Renderer
docker run -d --name flexport-metal-renderer \
  -v "$(pwd)":/workspace \
  -e CONTAINER_ID=1 \
  -e TASK="Advanced Metal Map Renderer" \
  -w /workspace \
  anthropic/claude-3-5-sonnet:latest

# Container 2: Ship AI & Movement System
docker run -d --name flexport-ship-ai \
  -v "$(pwd)":/workspace \
  -e CONTAINER_ID=2 \
  -e TASK="Ship AI & Movement System" \
  -w /workspace \
  anthropic/claude-3-5-sonnet:latest

# Container 3: Advanced Economic Engine
docker run -d --name flexport-economics \
  -v "$(pwd)":/workspace \
  -e CONTAINER_ID=3 \
  -e TASK="Advanced Economic Engine" \
  -w /workspace \
  anthropic/claude-3-5-sonnet:latest

# Container 4: UI/UX Enhancement & Interactions
docker run -d --name flexport-ui-ux \
  -v "$(pwd)":/workspace \
  -e CONTAINER_ID=4 \
  -e TASK="UI/UX Enhancement & Interactions" \
  -w /workspace \
  anthropic/claude-3-5-sonnet:latest

# Container 5: Game Progression & Content
docker run -d --name flexport-progression \
  -v "$(pwd)":/workspace \
  -e CONTAINER_ID=5 \
  -e TASK="Game Progression & Content" \
  -w /workspace \
  anthropic/claude-3-5-sonnet:latest
```

### Integration Points
- All containers will enhance the existing working app
- Metal renderer will replace BasicWorldMapView
- Ship AI will animate existing ship entities
- Economic engine will drive trade route profitability
- UI enhancements will improve existing interactions
- Game progression will add depth to current mechanics