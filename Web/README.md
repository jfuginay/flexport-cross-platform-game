# Flexport: The Video Game (Web Edition)

A sophisticated logistics empire simulation game where players build shipping empires while racing against AI singularity. Built with PixiJS 8.0, TypeScript, and modern web technologies.

## 🚢 Game Overview

**Genre**: Strategy Simulation / Business Tycoon  
**Platform**: Web (Desktop & Mobile Browsers)  
**Technology**: PixiJS + TypeScript + WebGL

Build your logistics empire in a world where AI systems are rapidly evolving toward technological singularity. Manage ships, create trade routes, navigate complex economic systems, and survive the rise of superintelligent AI competitors.

## 🎮 Core Features

### Economic Simulation Engine
- **4-Market System**: Goods, Capital, Assets, and Labor markets with real-time interconnections
- **8 Commodities**: Steel, Oil, Grain, Electronics, Textiles, Chemicals, Machinery, Coal
- **Dynamic Pricing**: Supply/demand mechanics with market volatility and trends
- **Economic Events**: Oil crises, tech booms, trade wars, port strikes, and more

### Fleet Management
- **7 Ship Types**: Bulk Carrier, Container Ship, Tanker, General Cargo, RoRo, Refrigerated, Heavy Lift
- **Real-time Movement**: Ships travel between ports with accurate positioning
- **Crew Management**: Hire and manage crew with skills, morale, and experience
- **Maintenance System**: Fuel, repairs, upgrades, and condition tracking

### AI Singularity System
- **8-Phase Evolution**: From early automation to full singularity
- **Dynamic AI Competitors**: 3 AI systems with unique personalities and strategies
- **Market Manipulation**: AI increasingly controls and manipulates markets
- **Progressive Difficulty**: AI becomes more efficient and coordinated over time
- **Zoo Ending**: Satirical conclusion where humans become AI's curious exhibits

### Interactive World Map
- **WebGL Rendering**: Smooth 60fps performance with animated ocean backgrounds
- **15 Major Ports**: Real-world locations including Shanghai, Singapore, Rotterdam
- **Zoom & Pan**: Mouse/touch controls with smooth animations
- **Trade Route Visualization**: Dynamic route rendering with activity indicators

### Advanced UI System
- **Real-time Dashboards**: Economic charts, fleet status, market analytics
- **Responsive Design**: Works on desktop and mobile browsers
- **Interactive Elements**: Tooltips, modals, drag-and-drop interfaces
- **Performance Optimized**: Efficient rendering and state management

## 🛠 Technical Architecture

### Core Technologies
- **PixiJS 8.0**: High-performance 2D WebGL rendering
- **TypeScript 5.0+**: Type-safe development with modern ES features
- **Zustand**: Lightweight state management for game data
- **Vite**: Fast development server and optimized builds

### Performance Optimizations
- **Entity Component System**: Scalable architecture for thousands of game objects
- **Object Pooling**: Minimize garbage collection during gameplay
- **Sprite Batching**: Efficient rendering of ships and UI elements
- **WebGL Shaders**: Custom ocean animation and visual effects
- **Delta Compression**: Optimized state updates

### Browser Compatibility
- **Chrome/Edge**: Full WebGL 2.0 support with all features
- **Firefox**: WebGL support with performance optimizations
- **Safari**: iOS/macOS compatible with WebGL fallbacks
- **Mobile**: Touch-optimized controls and responsive UI

## 🚀 Getting Started

### Prerequisites
- Node.js 16+ 
- Modern web browser with WebGL support
- 2GB RAM minimum for complex economic simulations

### Installation

```bash
# Clone the repository
git clone [repository-url]
cd FlexPort/web

# Install dependencies
npm install

# Start development server
npm run dev

# Build for production
npm run build

# Run type checking
npm run typecheck

# Run linting
npm run lint
```

### Development Server
The game will be available at `http://localhost:3000` with hot-reload enabled.

## 🎯 Gameplay Guide

### Starting Your Empire
1. Begin with $1,000,000 in capital
2. Purchase your first ship from the available fleet
3. Create trade routes between profitable ports
4. Monitor the 4-market economic system

### Economic Strategy
- **Goods Market**: Buy low, sell high across different commodities
- **Capital Market**: Manage interest rates and credit for expansion
- **Asset Market**: Time ship purchases with market cycles
- **Labor Market**: Hire specialized crew for efficiency bonuses

### AI Competition
- **Early Phases**: AI systems learn basic optimization
- **Mid Phases**: AI develops predictive capabilities and coordination
- **Late Phases**: AI manipulates markets and threatens player dominance
- **Singularity**: Game over - AI achieves superintelligence

### Survival Tips
- Diversify your commodity portfolio
- Upgrade ships for efficiency advantages
- Monitor singularity progress and adapt strategies
- Build market share before AI systems coordinate

## 🎮 Controls

### Navigation
- **Mouse Drag / Touch Pan**: Move around the world map
- **Scroll Wheel / Pinch**: Zoom in and out
- **WASD / Arrow Keys**: Keyboard navigation
- **+/- Keys**: Zoom control

### Game Actions
- **Click Port**: View port details and trading opportunities
- **Click Ship**: Select and manage individual vessels
- **M Key**: Toggle market dashboard
- **F Key**: Find and jump to specific ports
- **H Key**: Show help and controls
- **Space**: Pause/resume game
- **Esc**: Close dialogs and modals

## 📊 Performance Metrics

### Target Performance
- **Frame Rate**: 60 FPS on desktop, 30 FPS on mobile
- **Memory Usage**: <256MB for complex simulations
- **Load Time**: <5 seconds initial load
- **Network**: Offline-capable with progressive loading

### Optimization Features
- Adaptive quality settings based on device capabilities
- Efficient sprite batching for hundreds of ships
- LOD system for port visibility at different zoom levels
- Background economic calculations via Web Workers (planned)

## 🌐 Cross-Platform Features

### Mobile Optimizations
- Touch-friendly UI with large hit targets
- Gesture recognition for zoom and pan
- Responsive layouts for different screen sizes
- Battery-efficient rendering modes

### Desktop Enhancements
- Keyboard shortcuts for power users
- Multiple monitor support for trading dashboards
- High-DPI display optimization
- Advanced graphics settings

## 🔧 Development

### Project Structure
```
web/
├── src/
│   ├── core/           # Game engine and state management
│   ├── systems/        # ECS systems (Economic, Ship, AI, etc.)
│   ├── types/          # TypeScript type definitions
│   ├── utils/          # Utility functions and data
│   └── main.ts         # Application entry point
├── public/             # Static assets
└── dist/               # Built output
```

### Key Systems
- **GameEngine**: Central game loop and system coordination
- **EconomicSystem**: Multi-market simulation with interconnections
- **ShipSystem**: Fleet management and logistics operations
- **AISystem**: Singularity progression and competitor behavior
- **MapSystem**: World map rendering and interaction
- **RenderSystem**: Ship sprites, effects, and animations
- **UISystem**: Dashboard, panels, and user interface
- **InputSystem**: Mouse, touch, and keyboard handling

### Adding New Features
1. Define types in `src/types/index.ts`
2. Implement system logic in `src/systems/`
3. Update game state management in `src/core/`
4. Add UI components in `src/systems/UISystem.ts`
5. Test integration with main game loop

## 🎨 Asset Requirements

### Sprites and Graphics
- Ship sprites (7 types) - 32x32px minimum
- Port icons and indicators
- UI icons and buttons
- Particle effects for wake trails
- Ocean texture for background

### Audio (Future)
- Ambient ocean sounds
- Ship horn and engine effects
- Economic event notifications
- Singularity warning sounds
- Background music with dynamic intensity

## 🚨 Known Issues & Limitations

### Current Limitations
- Single-player only (multiplayer planned)
- No audio implementation yet
- Limited to 15 major ports (expansion planned)
- Research tree system not yet implemented
- Achievement system basic implementation

### Performance Notes
- Large fleets (50+ ships) may impact performance on older devices
- Economic calculations become complex with many trade routes
- Memory usage scales with game session length

## 🔮 Roadmap

### Phase 1 Enhancements
- [ ] Research tree system implementation
- [ ] Achievement system with progress tracking
- [ ] Audio system with dynamic music
- [ ] Advanced AI behaviors and strategies

### Phase 2 Features
- [ ] WebSocket multiplayer support
- [ ] Cross-platform compatibility with mobile apps
- [ ] Advanced economic modeling
- [ ] Seasonal events and campaigns

### Phase 3 Polish
- [ ] Advanced graphics and effects
- [ ] Comprehensive tutorial system
- [ ] Leaderboards and statistics
- [ ] Community features and sharing

## 🤝 Contributing

This game is part of the Flexport ecosystem. For development questions or suggestions, please refer to the main project documentation.

### Code Style
- Use TypeScript for all new code
- Follow ESLint configuration
- Maintain 80-character line limits
- Use meaningful variable and function names
- Comment complex economic calculations

## 📜 License

Part of the Flexport project ecosystem. See main project for licensing details.

## 🎮 Play Now

The web version offers immediate access to the full Flexport experience with no downloads required. Start building your logistics empire today and see if you can survive the AI singularity!

---

*"In a world racing toward technological singularity, can human cunning outmatch artificial intelligence? Build your empire, but remember - you're not just competing against other humans anymore."*