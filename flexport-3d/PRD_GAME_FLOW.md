# FlexPort 3D - Product Requirements Document
## Complete Game Flow Implementation

### Overview
Transform FlexPort 3D from a visualization demo into a fully playable shipping empire game with AI advisors, multiplayer lobby, and dynamic world events.

---

## 1. Game Flow Architecture

### 1.1 Screen Flow
```
Loading Screen → Title Screen → Main Menu → Lobby → Game Setup → Main Game → End Game
                                    ↓
                              Settings/Credits
```

### 1.2 Game States
- `LOADING` - Initial asset loading
- `TITLE` - Title screen with animated background
- `MENU` - Main menu selection
- `LOBBY` - Multiplayer/AI lobby
- `GAME_SETUP` - Initial company/difficulty selection
- `PLAYING` - Main game loop
- `PAUSED` - Game paused
- `GAME_OVER` - Victory/defeat screen

---

## 2. Loading Screen

### Requirements
- FlexPort logo animation
- Loading progress bar showing:
  - Assets loaded (models, textures)
  - World data initialized
  - AI systems ready
- Shipping industry facts/tips rotating
- Estimated time remaining

### Technical Implementation
```typescript
interface LoadingState {
  progress: number;
  currentTask: string;
  tips: string[];
  estimatedTime: number;
}
```

---

## 3. Title Screen

### Requirements
- Animated 3D globe in background (slowly rotating)
- FlexPort Global logo
- Particle effects of ships/planes moving
- Main menu options:
  - New Game
  - Continue
  - Multiplayer
  - Settings
  - Credits
  - Exit

### Visual Design
- Cinematic camera slowly orbiting Earth
- Volumetric clouds
- Day/night cycle continues
- Ambient ocean sounds
- Epic orchestral menu music

---

## 4. Game Lobby System

### 4.1 Lobby Creation
- Game name
- Max players (2-8)
- AI difficulty
- Starting capital
- Victory conditions:
  - Economic (reach $X)
  - Domination (control X% of ports)
  - Reputation (maintain X% for Y years)
  - Time limit

### 4.2 Player Slots
```typescript
interface LobbyPlayer {
  id: string;
  name: string;
  isAI: boolean;
  isReady: boolean;
  color: string;
  avatar: string;
  aiPersonality?: 'Aggressive' | 'Balanced' | 'Defensive' | 'Opportunistic';
}
```

### 4.3 AI Player Personalities
- **Aggressive AI**: High-risk, high-reward strategies
- **Balanced AI**: Steady growth, diversified routes
- **Defensive AI**: Conservative, focuses on safe profits
- **Opportunistic AI**: Exploits market gaps and events

---

## 5. Game Start Flow

### 5.1 Company Creation
- Company name
- Starting port selection (affects initial routes)
- Company logo/color selection
- Initial fleet composition:
  - 1 Container Ship (balanced)
  - 2 Bulk Carriers (slow, high capacity)
  - 1 Fast Cargo Ship (expensive to run)

### 5.2 Tutorial Integration
- Optional tutorial for new players
- AI advisor introduces game mechanics
- Guided first contract acceptance
- Ship routing tutorial
- Economic overview

---

## 6. Main Game UI Layout

### 6.1 Screen Regions
```
┌─────────────────────────────────────────────────────────┐
│  News Ticker (toggleable)                               │
├─────────┬────────────────────────────────┬─────────────┤
│         │                                 │             │
│  Left   │      3D Globe View            │    Right    │
│ Sidebar │   (Ships, Ports, Routes)      │   Sidebar   │
│         │                                 │             │
├─────────┴────────────────────────────────┴─────────────┤
│  Bottom Bar (Company Stats, Time Controls)              │
└─────────────────────────────────────────────────────────┘
```

### 6.2 Left Sidebar - Management
- Fleet Overview
- Available Contracts
- Port Information
- Research & Upgrades
- Financial Summary

### 6.3 Right Sidebar - Intelligence
- AI Advisor Panel
- Market Analysis
- Competitor Actions
- Event Notifications
- Strategic Suggestions

---

## 7. Ship Purchase & Management

### 7.1 Ship Purchase Flow
1. Click "Purchase Ship" button
2. Ship catalog opens with 3D preview
3. Select ship type:
   - Container Ship ($500k, 20 knots, 1000 TEU)
   - Bulk Carrier ($300k, 15 knots, 2000 TEU)
   - Tanker ($400k, 18 knots, 1500 TEU)
   - Cargo Plane ($2M, 500 knots, 100 TEU)
4. Choose home port
5. Name your ship
6. Confirm purchase

### 7.2 Ship Management UI
```typescript
interface ShipManagementPanel {
  ship: Ship;
  currentLocation: Port | SeaPosition;
  destination?: Port;
  cargo: Cargo[];
  fuel: number;
  condition: number;
  crew: CrewInfo;
  profitability: number;
  eta?: Date;
}
```

---

## 8. Contract System

### 8.1 Contract Board UI
- Grid/list view toggle
- Filtering options:
  - Origin port
  - Destination port
  - Cargo type
  - Profit margin
  - Deadline
  - Distance

### 8.2 Contract Details
```typescript
interface ContractDetails {
  id: string;
  client: string;
  cargo: {
    type: CargoType;
    amount: number;
    special: boolean; // Fragile, refrigerated, etc.
  };
  origin: Port;
  destination: Port;
  payment: number;
  deadline: Date;
  penalties: {
    late: number;
    damaged: number;
  };
  bonuses: {
    early: number;
    perfect: number;
  };
}
```

### 8.3 Contract Acceptance Flow
1. Click contract from board
2. View detailed modal with:
   - Route visualization on globe
   - Profit calculation
   - Ship availability
   - AI advisor opinion
3. Select ship for contract
4. Confirm acceptance

---

## 9. Ship Routing System

### 9.1 Route Planning
- Click ship → Click destination port
- Or drag ship to port
- Route preview shows:
  - Distance
  - Estimated time
  - Fuel cost
  - Weather along route
  - Profit/loss estimate

### 9.2 Auto-routing
- AI can suggest optimal routes
- Multi-stop routing for efficiency
- Fuel optimization
- Storm avoidance

---

## 10. AI Advisor System

### 10.1 Advisor Panel
```typescript
interface AIAdvisorPanel {
  currentAnalysis: {
    situation: string;
    risks: Risk[];
    opportunities: Opportunity[];
    suggestedActions: Action[];
  };
  historicalAccuracy: number;
  trustLevel: number;
}
```

### 10.2 Advisor Personalities
- **The Analyst**: Data-driven, focuses on numbers
- **The Veteran**: Experience-based, knows industry tricks
- **The Innovator**: Suggests new strategies
- **The Negotiator**: Focuses on relationships and reputation

### 10.3 Advice Types
- Contract recommendations
- Route optimization
- Fleet expansion timing
- Market predictions
- Competitor analysis
- Event response strategies

---

## 11. News Ticker System

### 11.1 Ticker Design
- Scrolls continuously at top of screen
- Semi-transparent background
- Can be toggled on/off with 'N' key
- Click to pause scrolling
- Click on event to zoom to location

### 11.2 Event Types
```typescript
enum NewsEventType {
  STORM = 'Storm brewing in Pacific',
  PIRACY = 'Pirate activity reported',
  PORT_STRIKE = 'Workers strike at port',
  MARKET_BOOM = 'Shipping demand surges',
  ACCIDENT = 'Ship collision reported',
  NEW_ROUTE = 'New trade route opened',
  REGULATION = 'New maritime law passed',
  COMPETITOR = 'Rival company announcement'
}
```

### 11.3 Event Response
- Clicking event triggers:
  1. Globe rotation to event location
  2. Zoom in animation
  3. Event details panel
  4. Visual effects (storm clouds, etc.)
  5. Action options

---

## 12. Natural Disasters & Events

### 12.1 Storm System
- Visual: Dark clouds, lightning, rough seas
- Effects: Ships slow down, risk of damage
- Player actions: Reroute, wait it out, risk it

### 12.2 Port Events
- Strikes: Port closed temporarily
- Boom: Increased contract prices
- Accident: Reduced capacity

### 12.3 Market Events
- Oil price changes affect fuel costs
- Trade wars affect certain routes
- Economic boom/recession cycles

---

## 13. Game Progression

### 13.1 Early Game (Year 1-2)
- Focus on establishing routes
- Building reputation
- Learning market patterns

### 13.2 Mid Game (Year 3-5)
- Fleet expansion
- Port investments
- Competing for contracts

### 13.3 Late Game (Year 5+)
- Market domination
- Advanced strategies
- Victory condition race

---

## 14. Technical Implementation Plan

### Phase 1: Core Systems (Week 1)
- [ ] Game state management
- [ ] Screen routing system
- [ ] Basic loading screen
- [ ] Title menu implementation

### Phase 2: Lobby & Setup (Week 2)
- [ ] Lobby creation/joining
- [ ] AI player generation
- [ ] Company creation flow
- [ ] Starting conditions

### Phase 3: Game Mechanics (Week 3-4)
- [ ] Ship purchase system
- [ ] Contract board
- [ ] Routing system
- [ ] Basic AI advisor

### Phase 4: Events & Polish (Week 5-6)
- [ ] News ticker
- [ ] Natural disasters
- [ ] Event system
- [ ] Visual effects
- [ ] Sound design

### Phase 5: AI & Balance (Week 7-8)
- [ ] AI personalities
- [ ] Advisor improvements
- [ ] Difficulty balancing
- [ ] Tutorial system

---

## 15. Success Metrics

### 15.1 Player Engagement
- Average session length > 30 minutes
- Tutorial completion rate > 80%
- Player retention after 3 sessions > 60%

### 15.2 Gameplay Balance
- Win rate across strategies: 20-30%
- AI provides challenge without frustration
- Economic progression feels rewarding

### 15.3 Technical Performance
- Loading time < 30 seconds
- Stable 60 FPS on medium hardware
- No critical bugs in core loop

---

## 16. Future Expansions

### 16.1 Multiplayer Features
- Real-time multiplayer
- Asynchronous play
- Tournaments
- Leaderboards

### 16.2 Content Additions
- New ship types
- More ports
- Historical scenarios
- Campaign mode

### 16.3 Advanced Features
- Stock market
- Company mergers
- Custom cargo types
- Port ownership

---

This PRD provides a complete roadmap for transforming FlexPort 3D into a fully playable shipping empire game with engaging mechanics, AI assistance, and dynamic world events.