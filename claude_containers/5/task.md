# Container 5: iOS Multiplayer + Dual-View Implementation

## Priority: MEDIUM - iOS Platform
## Objective: Port web multiplayer features to iOS with dual orientation support

### Requirements:
- Swift/Combine integration with multiplayer systems
- iOS-specific networking optimizations
- Integration with existing MultiplayerManager.swift
- Background/foreground handling
- **DUAL VIEW SUPPORT:**
  - **Portrait Mode**: Fleet overview, port management, dashboard UI
  - **Landscape Mode**: Map-centric view with enhanced graphics (Google Maps-style gameplay)

### Focus Areas:
1. `FlexPort iOS/Sources/FlexPort/Networking/MultiplayerManager.swift`
2. `FlexPort iOS/Sources/FlexPort/Networking/WebSocketHandler.swift`
3. **Dual-View Architecture:**
   - `PortraitGameView.swift` - Fleet management and overview
   - `LandscapeMapView.swift` - Enhanced map with zoom/pan
   - `OrientationCoordinator.swift` - Seamless transitions
4. SwiftUI orientation handling and state preservation

### Success Criteria:
- iOS can join web-hosted multiplayer games
- Cross-platform compatibility
- Proper iOS lifecycle handling
- **Portrait**: Clear fleet overview and management interface
- **Landscape**: Immersive map experience with enhanced graphics
- Smooth orientation transitions with state preservation
- 60 FPS performance in both orientations

### Dual-View Specifications:
**Portrait Mode (Fleet Command Center):**
- Fleet status dashboard
- Port information panels
- Economic performance charts
- Quick action buttons
- Compact multiplayer lobby

**Landscape Mode (Tactical Map View):**
- Full-screen map with enhanced ocean graphics
- Detailed ship sprites with wake effects
- Interactive port markers with info overlays
- Gesture-based zoom and pan (pinch, drag)
- Floating UI elements for key actions
- Real-time multiplayer ship movements

### Files to Focus On:
- FlexPort iOS/Sources/FlexPort/Networking/
- FlexPort iOS/Sources/FlexPort/Core/GameManager.swift
- FlexPort iOS/Sources/FlexPort/UI/GameView.swift (orientation handling)
- New dual-view SwiftUI components
