# Task 1: Mini-map and Route Visualization

## Objective
Implement a mini-map showing global operations and ship routes with animated dotted lines.

## Requirements
1. Create a new `MiniMap.tsx` component that shows a 2D top-down view of all ports and ships
2. Add animated dotted lines showing ship routes from current position to destination
3. Make the mini-map interactive - clicking on ships/ports should select them in the main view
4. Position the mini-map in the bottom-right corner with a semi-transparent background
5. Add zoom controls for the mini-map
6. Show ship icons that match their type (container, bulk, tanker, plane)
7. Color-code ports (green for owned, blue for others)
8. Update the UI component to include the mini-map

## Technical Details
- Use HTML Canvas or SVG for the 2D rendering
- Access game state from `useGameStore` hook
- Position calculation: Convert 3D world coordinates to 2D mini-map coordinates
- Use CSS animations for the dotted line movement
- React Three Fiber's `useThree` hook might be useful for camera sync

## File Locations
- Create new file: `src/components/MiniMap.tsx`
- Create new file: `src/components/MiniMap.css`
- Update: `src/components/UI.tsx` to include MiniMap
- Game state is in: `src/store/gameStore.ts`

## Example Structure
```tsx
// MiniMap.tsx
import React, { useRef, useEffect } from 'react';
import { useGameStore } from '../store/gameStore';
import './MiniMap.css';

export const MiniMap: React.FC = () => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const { ports, fleet, selectedShipId, selectedPortId, selectShip, selectPort } = useGameStore();
  
  // Implement canvas drawing logic
  // Add click handlers for selection
  // Animate routes
  
  return (
    <div className="minimap-container">
      <canvas ref={canvasRef} />
      <div className="minimap-controls">
        {/* Zoom controls */}
      </div>
    </div>
  );
};
```