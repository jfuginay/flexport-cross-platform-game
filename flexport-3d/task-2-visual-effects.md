# Task 2: Visual Effects (Ship Trails, Weather, Day/Night)

## Objective
Add impressive visual effects including ship wake trails, weather system, and day/night cycle.

## Requirements

### 1. Ship Wake Trails
- White foam trails that fade over time as ships move through water
- Use particle system or geometry for the trail
- Trail should follow ship movement path
- Fade out gradually over 10-15 seconds

### 2. Weather System
- Implement weather states: Clear, Cloudy, Rainy, Stormy
- Rain particles during rain/storm (use THREE.Points)
- Darker lighting during storms
- Weather affects ship speed (storms slow ships by 30%)
- Atmospheric fog that changes with weather

### 3. Day/Night Cycle
- Smooth transition between day and night
- Sun/moon movement across the sky
- Adjust ambient and directional light colors
- Port lights that turn on at night (add point lights to ports)
- Ocean shader should reflect time of day

## Technical Details

### Weather Implementation
```tsx
// Create new file: src/components/Weather.tsx
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';

// Weather states enum
enum WeatherState {
  CLEAR,
  CLOUDY,
  RAINY,
  STORMY
}

// Update gameStore to include weather state
// Add weather effects using particles
// Modify ship speed calculations based on weather
```

### Ship Trails
```tsx
// Update Ship.tsx to include trail system
// Use THREE.BufferGeometry to create trail mesh
// Store trail positions in a circular buffer
// Update positions each frame based on ship movement
```

### Day/Night Cycle
```tsx
// Create new file: src/components/DayNightCycle.tsx
// Use useFrame to update sun position
// Interpolate light colors based on time
// Add moon mesh that follows opposite path
```

## Files to Modify/Create
- Create: `src/components/Weather.tsx`
- Create: `src/components/DayNightCycle.tsx`
- Create: `src/components/ShipTrail.tsx`
- Update: `src/components/Ship.tsx` (add trail component)
- Update: `src/components/World.tsx` (update ocean shader)
- Update: `src/components/Port.tsx` (add night lights)
- Update: `src/store/gameStore.ts` (add weather state)
- Update: `src/components/Game.tsx` (include new components)

## Performance Considerations
- Use instanced meshes for rain particles
- Limit trail vertex count (max 100 points)
- LOD system for distant effects
- Reduce particle count on lower-end devices