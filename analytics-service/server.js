const express = require('express');
const { createServer } = require('http');
const { Server } = require('socket.io');
const redis = require('redis');
const cors = require('cors');

const app = express();
const httpServer = createServer(app);
const io = new Server(httpServer, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

app.use(cors());
app.use(express.json());

// Redis clients
const redisClient = redis.createClient({
  url: process.env.REDIS_URL || 'redis://redis:6379'
});

const redisSub = redis.createClient({
  url: process.env.REDIS_URL || 'redis://redis:6379'
});

// Connect to Redis
(async () => {
  await redisClient.connect();
  await redisSub.connect();
  console.log('Connected to Redis');
})();

// Real-time analytics storage
const analytics = {
  activePlayers: new Set(),
  shipMovements: [],
  contractsCompleted: 0,
  totalRevenue: 0,
  routePopularity: new Map(),
  marketActivity: []
};

// REST endpoints
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'analytics-service' });
});

app.get('/analytics/summary', (req, res) => {
  res.json({
    activePlayers: analytics.activePlayers.size,
    totalShipMovements: analytics.shipMovements.length,
    contractsCompleted: analytics.contractsCompleted,
    totalRevenue: analytics.totalRevenue,
    topRoutes: getTopRoutes(),
    recentActivity: analytics.marketActivity.slice(-10)
  });
});

app.get('/analytics/market-trends', (req, res) => {
  res.json({
    hourlyActivity: generateHourlyActivity(),
    routeHeatmap: generateRouteHeatmap(),
    priceFluctuations: generatePriceData()
  });
});

app.get('/analytics/player/:playerId', (req, res) => {
  const { playerId } = req.params;
  // Get player-specific analytics from Redis
  res.json({
    playerId,
    performance: {
      revenue: Math.random() * 10000000,
      contractsCompleted: Math.floor(Math.random() * 50),
      fleetEfficiency: Math.random() * 100,
      marketShare: Math.random() * 20
    }
  });
});

// Socket.IO for real-time updates
io.on('connection', (socket) => {
  console.log('Client connected:', socket.id);
  
  // Send initial analytics data
  socket.emit('analytics:update', {
    activePlayers: analytics.activePlayers.size,
    recentActivity: analytics.marketActivity.slice(-5)
  });
  
  socket.on('player:join', (playerId) => {
    analytics.activePlayers.add(playerId);
    broadcastAnalytics();
  });
  
  socket.on('player:leave', (playerId) => {
    analytics.activePlayers.delete(playerId);
    broadcastAnalytics();
  });
  
  socket.on('ship:move', (data) => {
    analytics.shipMovements.push({
      ...data,
      timestamp: new Date()
    });
    updateRoutePopularity(data.route);
  });
  
  socket.on('contract:complete', (data) => {
    analytics.contractsCompleted++;
    analytics.totalRevenue += data.value;
    analytics.marketActivity.push({
      type: 'CONTRACT_COMPLETED',
      player: data.playerId,
      value: data.value,
      route: data.route,
      timestamp: new Date()
    });
    broadcastAnalytics();
  });
  
  socket.on('disconnect', () => {
    console.log('Client disconnected:', socket.id);
  });
});

// Redis pub/sub for cross-service communication
redisSub.subscribe('game:events', (message) => {
  const event = JSON.parse(message);
  
  switch (event.type) {
    case 'SHIP_PURCHASED':
      analytics.marketActivity.push({
        type: 'SHIP_PURCHASED',
        player: event.playerId,
        shipType: event.shipType,
        cost: event.cost,
        timestamp: new Date()
      });
      break;
      
    case 'PORT_ACQUIRED':
      analytics.marketActivity.push({
        type: 'PORT_ACQUIRED',
        player: event.playerId,
        port: event.portName,
        cost: event.cost,
        timestamp: new Date()
      });
      break;
      
    case 'AI_DECISION':
      // Track AI player decisions for analysis
      analytics.marketActivity.push({
        type: 'AI_DECISION',
        player: event.playerId,
        decision: event.decision,
        timestamp: new Date()
      });
      break;
  }
  
  broadcastAnalytics();
});

// Helper functions
function broadcastAnalytics() {
  io.emit('analytics:update', {
    activePlayers: analytics.activePlayers.size,
    contractsCompleted: analytics.contractsCompleted,
    totalRevenue: analytics.totalRevenue,
    recentActivity: analytics.marketActivity.slice(-5)
  });
}

function updateRoutePopularity(route) {
  const key = `${route.origin}-${route.destination}`;
  const current = analytics.routePopularity.get(key) || 0;
  analytics.routePopularity.set(key, current + 1);
}

function getTopRoutes() {
  const routes = Array.from(analytics.routePopularity.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([route, count]) => ({ route, count }));
  return routes;
}

function generateHourlyActivity() {
  const hours = [];
  for (let i = 0; i < 24; i++) {
    hours.push({
      hour: i,
      shipments: Math.floor(Math.random() * 100),
      revenue: Math.floor(Math.random() * 1000000)
    });
  }
  return hours;
}

function generateRouteHeatmap() {
  const routes = [
    { origin: 'Shanghai', destination: 'Los Angeles', intensity: 0.9 },
    { origin: 'Singapore', destination: 'Rotterdam', intensity: 0.8 },
    { origin: 'Dubai', destination: 'Shanghai', intensity: 0.7 },
    { origin: 'Rotterdam', destination: 'New York', intensity: 0.6 },
    { origin: 'Los Angeles', destination: 'Shanghai', intensity: 0.85 }
  ];
  return routes;
}

function generatePriceData() {
  const data = [];
  const basePrice = 1000;
  for (let i = 0; i < 30; i++) {
    data.push({
      day: i,
      price: basePrice + (Math.random() - 0.5) * 200
    });
  }
  return data;
}

// Start server
const PORT = process.env.PORT || 8080;
httpServer.listen(PORT, () => {
  console.log(`Analytics service running on port ${PORT}`);
});