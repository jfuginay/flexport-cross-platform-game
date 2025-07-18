#!/bin/bash

echo "🔧 Integrating new components into FlexPort 3D..."

# Update package.json with new dependencies
npm install react-spring @react-spring/web react-toastify recharts

# Update the main UI component to include new components
cat >> /tmp/ui-update.txt << 'EOF'

// Add these imports at the top of UI.tsx
import { MiniMap } from './MiniMap';
import { FleetEfficiency } from './Dashboard/FleetEfficiency';
import { ProfitTracker } from './Dashboard/ProfitTracker';
import { NotificationSystem } from './Notifications/NotificationSystem';
import { QuickActions } from './UI/QuickActions';

// Add these components inside the return statement of UI component:
// After the closing tag of side-panel div:

      {/* New Dashboard */}
      <div className="dashboard-container">
        <FleetEfficiency />
        <ProfitTracker />
      </div>
      
      {/* Mini-map */}
      <MiniMap />
      
      {/* Quick Actions */}
      <QuickActions />
      
      {/* Notifications */}
      <NotificationSystem />
EOF

# Update the Game component to include weather and day/night
cat >> /tmp/game-update.txt << 'EOF'

// Add these imports at the top of Game.tsx
import { Weather, WeatherState } from './Weather';
import { DayNightCycle } from './DayNightCycle';

// Add these state variables in the Game component:
const [weatherState, setWeatherState] = useState(WeatherState.CLEAR);
const [timeOfDay, setTimeOfDay] = useState(12); // Start at noon

// Add weather cycle in useEffect:
useEffect(() => {
  const weatherInterval = setInterval(() => {
    const rand = Math.random();
    if (rand < 0.4) setWeatherState(WeatherState.CLEAR);
    else if (rand < 0.7) setWeatherState(WeatherState.CLOUDY);
    else if (rand < 0.9) setWeatherState(WeatherState.RAINY);
    else setWeatherState(WeatherState.STORMY);
  }, 30000); // Change weather every 30 seconds
  
  return () => clearInterval(weatherInterval);
}, []);

// Add time progression:
useEffect(() => {
  const timeInterval = setInterval(() => {
    setTimeOfDay(prev => (prev + 0.1) % 24);
  }, 1000); // Progress 0.1 hour per second
  
  return () => clearInterval(timeInterval);
}, []);

// Add these components inside the Canvas, after the lighting section:
<DayNightCycle timeOfDay={timeOfDay} />
<Weather weatherState={weatherState} />
EOF

# Update Ship component to include trails
cat >> /tmp/ship-update.txt << 'EOF'

// Add import at the top of Ship.tsx
import { ShipTrail } from './ShipTrail';

// Add inside the ship group, after the mesh:
<ShipTrail 
  shipPosition={new THREE.Vector3(ship.position.x, ship.position.y, ship.position.z)} 
  isMoving={ship.status === ShipStatus.SAILING}
/>
EOF

# Update gameStore to track weather effect on ships
cat >> /tmp/store-update.txt << 'EOF'

// Add to the game store state interface:
weatherState: WeatherState;
timeOfDay: number;

// Add to initial state:
weatherState: WeatherState.CLEAR,
timeOfDay: 12,

// Update ship speed calculation in updateGame to account for weather:
const weatherSpeedModifier = state.weatherState === WeatherState.STORMY ? 0.7 : 1;
const moveDistance = ship.speed * deltaTime * state.gameSpeed * weatherSpeedModifier;
EOF

echo "✅ Integration instructions created!"
echo ""
echo "To complete the integration:"
echo "1. Manually apply the changes from /tmp/*-update.txt files"
echo "2. Import the new CSS files in App.tsx"
echo "3. Test each feature individually"
echo "4. Adjust styling as needed"