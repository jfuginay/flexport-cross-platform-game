# Parallel Development Guide for FlexPort 3D UI Improvements

Since Claude Task Master requires API keys, here's how to work on these improvements in parallel:

## Option 1: Using Multiple Claude Instances

1. Open 3 separate Claude conversations (browser tabs or Claude desktop instances)
2. In each conversation, paste the following base context:

```
I'm working on the FlexPort 3D logistics game built with React Three Fiber. 
The game is located at /Users/jfuginay/Documents/dev/FlexPort/flexport-3d/

Key files:
- src/components/Game.tsx - Main game component
- src/components/UI.tsx - UI overlay
- src/components/Ship.tsx - Ship component
- src/components/World.tsx - Ocean and environment
- src/store/gameStore.ts - Zustand store with game state
- src/types/game.types.ts - TypeScript types

The game currently has:
- 3D world with ports and ships
- Fleet management
- Contract system
- Basic UI overlay
```

3. Then in each conversation, add one of these specific tasks:
   - **Claude 1**: Copy contents of `task-1-minimap.md`
   - **Claude 2**: Copy contents of `task-2-visual-effects.md`
   - **Claude 3**: Copy contents of `task-3-ui-polish.md`

## Option 2: Using Terminal Sessions

If you prefer working in terminals:

1. Open 3 terminal windows/tabs
2. In each terminal, navigate to the project:
   ```bash
   cd /Users/jfuginay/Documents/dev/FlexPort/flexport-3d
   ```

3. Start working on each task independently

## Option 3: Using VS Code/Cursor with Multiple Windows

1. Open the project in 3 separate VS Code/Cursor windows
2. In each window, focus on one specific task
3. Use the AI assistant in each window to work on that task

## Coordination Tips

1. **Avoid Conflicts**: Each task works on mostly separate files:
   - Task 1: Creates MiniMap component
   - Task 2: Creates Weather, DayNightCycle, and ShipTrail components
   - Task 3: Creates Dashboard and Notification components

2. **Integration Points**: The main integration happens in:
   - `src/components/UI.tsx` - All tasks update this
   - `src/components/Game.tsx` - Task 2 updates this
   - `src/store/gameStore.ts` - Tasks 2 & 3 might update this

3. **Testing**: Keep the game running (`npm start`) and refresh to see changes

## Quick Commands

```bash
# Terminal 1 - Mini-map Development
npm start  # If not already running

# Terminal 2 - Git status monitoring
watch git status

# Terminal 3 - Test changes
npm test  # If tests exist
```

## Merge Strategy

After completing the tasks:

1. Test each feature independently
2. Commit each feature to separate branches:
   ```bash
   git checkout -b feature/minimap
   git add -A && git commit -m "Add interactive minimap with route visualization"
   
   git checkout -b feature/visual-effects
   git add -A && git commit -m "Add weather system, day/night cycle, and ship trails"
   
   git checkout -b feature/ui-dashboard
   git add -A && git commit -m "Add fleet dashboard and notification system"
   ```

3. Merge features one by one to main branch

Good luck with the parallel development!