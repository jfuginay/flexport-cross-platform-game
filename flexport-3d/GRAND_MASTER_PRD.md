# FlexPort Global - Grand Master PRD v1.0
*Unified Product Requirements for Concurrent Web, iOS & Android Development*

## 1. PRODUCT OVERVIEW

### Vision
FlexPort Global is a location-based logistics simulation game where players manage global shipping networks, optimize trade routes, and build their shipping empire.

### Core Value Proposition
- **Web**: Full-featured command center with advanced analytics
- **iOS/Android**: On-the-go fleet management and real-time notifications

### Target Metrics
- 60 FPS performance across all platforms
- <3s initial load time
- 99.9% uptime
- Cross-platform sync within 500ms

## 2. CORE FEATURES & PLATFORM MATRIX

| Feature | Web | iOS | Android | Shared Logic |
|---------|-----|-----|---------|--------------|
| **3D Globe Navigation** | Mapbox GL | Native MapKit/Mapbox | Mapbox Android | Coordinate system |
| **Fleet Management** | Full dashboard | Touch-optimized | Touch-optimized | Fleet state engine |
| **Daily Rewards** | Modal system | Native alerts | Native alerts | Reward logic |
| **Social Sharing** | Web Share API | iOS Share Sheet | Android Intent | Share content gen |
| **Offline Mode** | Service Worker | Core Data | Room DB | Sync protocol |
| **Push Notifications** | Web Push | APNS | FCM | Notification service |
| **AR Port Viewing** | WebXR (future) | ARKit | ARCore | 3D models |

## 3. TECHNICAL ARCHITECTURE

### Shared Core (TypeScript)
```typescript
// Core game engine - platform agnostic
interface GameEngine {
  fleet: FleetManager;
  world: WorldState;
  economy: EconomyEngine;
  social: SocialManager;
}

// Platform adapters
interface PlatformAdapter {
  storage: StorageAdapter;
  network: NetworkAdapter;
  ui: UIAdapter;
  notifications: NotificationAdapter;
}
```

### Platform-Specific Implementation

**Web (React + Vite)**
- Progressive Web App with offline support
- WebGL for 3D rendering
- IndexedDB for local storage
- Web Workers for background sync

**iOS (React Native + Swift)**
- Native navigation (UINavigationController)
- SwiftUI for system integrations
- Core Data for persistence
- WidgetKit for home screen widgets

**Android (React Native + Kotlin)**
- Material Design 3 components
- Room for local database
- WorkManager for background tasks
- Jetpack Compose for native screens

## 4. SHARED COMPONENT SYSTEM

### Component Hierarchy
```
SharedComponents/
├── GameLogic/
│   ├── FleetManager
│   ├── RouteOptimizer
│   ├── EconomyEngine
│   └── RewardSystem
├── DataModels/
│   ├── Ship
│   ├── Port
│   ├── Cargo
│   └── Player
└── NetworkLayer/
    ├── RealtimeSync
    ├── APIClient
    └── OfflineQueue
```

### Platform Bridge API
```typescript
// Each platform implements this interface
interface PlatformBridge {
  // Storage
  saveGameState(state: GameState): Promise<void>;
  loadGameState(): Promise<GameState>;
  
  // UI
  showNotification(notification: GameNotification): void;
  vibrate(pattern: VibrationPattern): void;
  
  // System
  getDeviceInfo(): DeviceInfo;
  requestPermissions(perms: Permission[]): Promise<PermissionStatus>;
}
```

## 5. DEVELOPMENT REQUIREMENTS

### Phase 1: Foundation (Weeks 1-4)
**All Platforms Concurrently:**
- Set up monorepo with shared packages
- Implement core game engine
- Basic authentication flow
- Local storage abstraction

### Phase 2: Core Gameplay (Weeks 5-8)
**Web Lead, Mobile Follow:**
- 3D globe with ports
- Fleet management UI
- Route planning system
- Economy simulation

### Phase 3: Platform Optimization (Weeks 9-12)
**Platform-Specific Teams:**
- Web: PWA features, WebGL optimization
- iOS: Widgets, Siri shortcuts, Apple Watch
- Android: Material You, foldable support, Wear OS

### Phase 4: Advanced Features (Weeks 13-16)
**Feature Teams Across Platforms:**
- Real-time multiplayer
- Social features
- AR port viewing
- Advanced analytics

## 6. SYNCHRONIZATION STRATEGY

### State Management
```typescript
// Unified state across all platforms
type GameState = {
  version: number;
  player: PlayerState;
  fleet: FleetState;
  world: WorldState;
  lastSync: timestamp;
};

// Conflict resolution
enum ConflictStrategy {
  LAST_WRITE_WINS,
  MERGE_CHANGES,
  USER_CHOICE
}
```

### Sync Protocol
1. **Local First**: All actions work offline
2. **Optimistic Updates**: Immediate UI response
3. **Background Sync**: Queue operations when offline
4. **Conflict Resolution**: Automatic merge with user override

## 7. PERFORMANCE TARGETS

### Web
- First Contentful Paint: <1.5s
- Time to Interactive: <3s
- Lighthouse Score: >90

### Mobile
- Cold start: <2s
- Memory usage: <150MB
- Battery drain: <5%/hour active use

## 8. TESTING STRATEGY

### Automated Testing
- Unit tests for game logic (Jest)
- Integration tests for platform bridges
- E2E tests per platform (Cypress/Detox)
- Performance benchmarks

### Manual Testing
- Cross-platform sync scenarios
- Offline/online transitions
- Platform-specific gestures
- Accessibility compliance

## 9. DEPLOYMENT PIPELINE

### Continuous Deployment
```yaml
# Concurrent platform builds
platforms:
  web:
    - Build PWA
    - Deploy to CDN
    - Update service worker
  ios:
    - Build IPA
    - TestFlight distribution
    - App Store submission
  android:
    - Build AAB
    - Play Console upload
    - Staged rollout
```

## 10. SUCCESS METRICS

### Launch Criteria
- [ ] All core features implemented across platforms
- [ ] <0.1% crash rate
- [ ] 4.5+ star rating target
- [ ] 95% positive sync success rate
- [ ] Accessibility WCAG 2.1 AA compliant

### KPIs
- Daily Active Users (DAU)
- Session length by platform
- Cross-platform usage (users on 2+ platforms)
- Retention: D1, D7, D30
- Revenue per platform

## IMPLEMENTATION INSTRUCTIONS FOR CLAUDE CODE

To build this application concurrently for all three platforms:

1. **Start with this PRD** and the existing codebase
2. **Create shared TypeScript modules** for game logic
3. **Implement platform bridges** for each target
4. **Use the existing web version** as the reference implementation
5. **Follow the phased approach** to ensure coordinated development

The codebase already includes:
- Web implementation with React + Vite
- Mobile project structures for iOS and Android
- Testing and deployment guides
- Component architecture ready for sharing

Begin by examining the existing `/src` directory and planning how to extract shared logic into platform-agnostic modules.