# Container 7: Android Multiplayer + Dual-View Implementation

## Priority: MEDIUM - Android Platform
## Objective: Port multiplayer features to Android with dual orientation support

### Requirements:
- Kotlin/Coroutines multiplayer integration
- Android-specific networking with lifecycle awareness
- Integration with existing MultiplayerManager.kt
- Foreground service for background networking
- **DUAL VIEW SUPPORT:**
  - **Portrait Mode**: Fleet overview, port management, Material Design dashboard
  - **Landscape Mode**: Map-centric view with enhanced OpenGL graphics

### Focus Areas:
1. `FlexPort Android/app/src/main/java/com/flexport/game/networking/MultiplayerManager.kt`
2. Android WebSocket implementation
3. **Dual-View Architecture:**
   - `PortraitGameActivity.kt` - Fleet management with Material Design 3
   - `LandscapeMapActivity.kt` - Enhanced map with OpenGL ES rendering
   - `OrientationManager.kt` - Seamless transitions
4. Jetpack Compose orientation handling and OpenGL integration

### Success Criteria:
- Android can join cross-platform games
- Proper Android lifecycle handling
- Material Design 3 multiplayer UI
- Background networking support
- **Portrait**: Clean Material Design fleet overview interface
- **Landscape**: Immersive map experience with high-performance graphics
- Smooth orientation transitions with state preservation
- Consistent performance on various Android devices

### Dual-View Specifications:
**Portrait Mode (Fleet Command Center):**
- Material Design 3 fleet dashboard
- Card-based port information layout
- Economic performance charts with Material charts
- FAB (Floating Action Button) for quick actions
- Bottom sheet multiplayer lobby

**Landscape Mode (Tactical Map View):**
- Full-screen map with OpenGL ES enhanced graphics
- Custom OpenGL ship sprites with animations
- Interactive port markers with Material dialogs
- Gesture-based zoom and pan (ScaleGestureDetector)
- Overlay UI with Material components
- Real-time multiplayer ship movements

### Android-Specific Features:
- Configuration changes handling (orientation)
- Adaptive UI for different screen sizes and densities
- Hardware acceleration optimization
- Battery optimization considerations
- Proper fragment lifecycle management

### Files to Focus On:
- FlexPort Android/app/src/main/java/com/flexport/game/networking/
- FlexPort Android/app/src/main/java/com/flexport/game/ui/screens/
- Android manifest configuration for orientations
- OpenGL ES renderer classes
- Jetpack Compose orientation-aware components
