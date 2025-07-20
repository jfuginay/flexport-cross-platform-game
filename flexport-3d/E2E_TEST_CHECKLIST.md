# FlexPort Global - E2E Test Checklist

## Game Initialization ✅
- [x] Multiplayer lobby loads
- [x] Can start offline game
- [x] Game initializes with ports
- [x] Game timer starts
- [x] Initial money is set correctly
- [x] AI competitors are created

## Map & Visualization
- [x] Mapbox satellite view loads
- [x] Ports are visible on map with labels
- [x] Ships are visible on map with labels
- [ ] Ship movement animation works
- [ ] Camera follows selected ship
- [ ] Map controls (zoom, pan) work

## Fleet Management
- [x] Fleet panel shows ship count
- [ ] Can open fleet management modal
- [ ] Can purchase different ship types
- [ ] Ships appear on map after purchase
- [ ] Ship details display correctly
- [ ] Can select ships on map
- [ ] Can repair ships
- [ ] Can upgrade ships
- [ ] Can sell ships

## Contracts System
- [ ] Contracts list populates
- [ ] Can view contract details
- [ ] Can accept contracts
- [ ] Can assign ships to contracts
- [ ] Ships sail to pickup locations
- [ ] Ships load cargo
- [ ] Ships sail to delivery locations
- [ ] Ships unload cargo
- [ ] Contract completion gives rewards
- [ ] Contract expiration works

## Port Operations
- [ ] Ports overview shows all ports
- [ ] Can view port details
- [ ] Ships dock at ports correctly
- [ ] Loading/unloading animations work
- [ ] Port capacity limits work

## AI & Competition
- [ ] AI competitors move ships
- [ ] AI accepts contracts
- [ ] Competition leaderboard updates
- [ ] AI efficiency calculations work

## Financial System
- [ ] Money updates on transactions
- [ ] Ship purchases deduct money
- [ ] Contract rewards add money
- [ ] Financial panel shows profit/loss
- [ ] Bankruptcy conditions work

## Weather & Events
- [ ] Weather data loads (fixing API errors)
- [ ] Storm warnings appear
- [ ] Crisis events trigger
- [ ] Events affect gameplay
- [ ] Ryan Petersen advisor appears

## Mobile/Responsive
- [ ] Mobile view works
- [ ] Touch controls function
- [ ] Mobile navigation works
- [ ] Responsive layout adapts

## Multiplayer Features
- [ ] Can create rooms
- [ ] Can join rooms
- [ ] Chat system works
- [ ] Room settings apply
- [ ] AI players can be added
- [ ] Game starts synchronously

## Game End Conditions
- [ ] Timer countdown works
- [ ] Game ends at time limit
- [ ] Winner is determined correctly
- [ ] End screen shows results
- [ ] Can restart game

## Known Issues to Fix:
1. Weather API returning 404/400 errors
2. WebSocket connection closing immediately
3. Ships not appearing after purchase (fixed)
4. Ports not initializing (fixed)
5. Map not showing in single player (removed single player)