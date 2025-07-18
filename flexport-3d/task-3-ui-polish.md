# Task 3: Advanced UI Overlay and Information Dashboard

## Objective
Enhance the UI overlay with better information architecture, animations, and real-time indicators.

## Requirements

### 1. Fleet Efficiency Dashboard
- Real-time profit/loss ticker
- Fleet utilization percentage (active ships / total ships)
- Average delivery time tracking
- Fuel costs tracker
- Charts showing performance over time

### 2. Enhanced Contract Display
- Urgency indicators (color-coded by deadline)
- Profit margin calculations
- Progress bars for active contracts
- Estimated completion time
- Sort/filter options

### 3. Smooth Animations
- Panel slide-in/out transitions using React Spring
- Number counter animations for money changes
- Pulse animations for urgent items
- Smooth hover effects
- Loading states with skeletons

### 4. Notification System
- Toast notifications for important events
- Sound effects for notifications
- Notification history/log
- Configurable notification preferences

### 5. Quick Action Buttons
- Auto-assign best ship to contract
- Recall all idle ships to home port
- Pause all ship movements
- One-click contract acceptance for profitable routes

## Technical Implementation

### Dependencies to Add
```bash
npm install react-spring @react-spring/web react-toastify recharts
```

### File Structure
```
src/components/
  ├── Dashboard/
  │   ├── FleetEfficiency.tsx
  │   ├── ProfitTracker.tsx
  │   └── Dashboard.css
  ├── Notifications/
  │   ├── NotificationSystem.tsx
  │   └── Toast.css
  └── UI/
      ├── QuickActions.tsx
      └── AnimatedNumber.tsx
```

### Example Implementation
```tsx
// FleetEfficiency.tsx
import { useSpring, animated } from '@react-spring/web';
import { LineChart, Line, XAxis, YAxis } from 'recharts';

export const FleetEfficiency = () => {
  const efficiency = calculateFleetEfficiency();
  
  const props = useSpring({
    number: efficiency,
    from: { number: 0 }
  });
  
  return (
    <div className="fleet-efficiency">
      <animated.div className="efficiency-number">
        {props.number.to(n => `${n.toFixed(1)}%`)}
      </animated.div>
      <LineChart data={efficiencyHistory}>
        {/* Chart implementation */}
      </LineChart>
    </div>
  );
};
```

### Notification System
```tsx
// NotificationSystem.tsx
import { toast, ToastContainer } from 'react-toastify';
import useSound from 'use-sound';

// Subscribe to game events in useEffect
// Show toasts for important events
// Play sound effects
```

## Files to Update/Create
- Create: `src/components/Dashboard/` directory with components
- Create: `src/components/Notifications/NotificationSystem.tsx`
- Create: `src/components/UI/QuickActions.tsx`
- Create: `src/components/UI/AnimatedNumber.tsx`
- Update: `src/components/UI.tsx` (integrate new components)
- Update: `src/components/UI.css` (add animations and new styles)
- Update: `src/store/gameStore.ts` (add tracking data)
- Add: Sound effect files in `public/sounds/`

## UI/UX Best Practices
- Keep animations under 300ms for responsiveness
- Use consistent color scheme for urgency (red/yellow/green)
- Ensure all interactive elements have hover states
- Add keyboard shortcuts for quick actions
- Make dashboard collapsible to not obstruct 3D view