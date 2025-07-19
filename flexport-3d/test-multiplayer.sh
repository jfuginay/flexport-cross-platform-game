#!/bin/bash

echo "🧪 FlexPort 3D Multiplayer Test Suite"
echo "====================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SERVER_URL="http://34.215.161.218:3001"
WS_URL="ws://34.215.161.218:3001"

# Test 1: Check if server is reachable
echo "1️⃣  Testing server connectivity..."
if curl -s -o /dev/null -w "%{http_code}" "$SERVER_URL/health" | grep -q "200"; then
    echo -e "${GREEN}✅ Server is reachable${NC}"
    
    # Get health status
    echo "   Health check response:"
    curl -s "$SERVER_URL/health" | jq '.' 2>/dev/null || curl -s "$SERVER_URL/health"
    echo ""
else
    echo -e "${RED}❌ Server is not reachable${NC}"
    echo "   Please check:"
    echo "   - Is the server running on EC2?"
    echo "   - Is port 3001 open in security group?"
    echo "   - Run on EC2: pm2 status"
    exit 1
fi

# Test 2: Test WebSocket connection
echo "2️⃣  Testing WebSocket connection..."
echo "   Installing wscat if needed..."
if ! command -v wscat &> /dev/null; then
    npm install -g wscat
fi

echo "   Attempting WebSocket connection..."
timeout 5 wscat -c "$WS_URL" &
WS_PID=$!
sleep 2

if ps -p $WS_PID > /dev/null; then
    echo -e "${GREEN}✅ WebSocket connection successful${NC}"
    kill $WS_PID 2>/dev/null
else
    echo -e "${YELLOW}⚠️  WebSocket connection test inconclusive${NC}"
fi
echo ""

# Test 3: Test from browser
echo "3️⃣  Browser test URLs:"
echo "   Production app: https://flexport-3d.vercel.app"
echo "   Local app: http://localhost:3000"
echo ""

# Test 4: Quick WebSocket test from Node.js
echo "4️⃣  Running Node.js WebSocket test..."
cat > /tmp/test-ws.js << 'EOF'
const io = require('socket.io-client');
const socket = io('http://34.215.161.218:3001');

console.log('Connecting to multiplayer server...');

socket.on('connect', () => {
    console.log('✅ Connected! Socket ID:', socket.id);
    
    // Test creating a room
    socket.emit('create-room', {
        name: 'Test Player',
        avatar: '🧪',
        rating: 1200,
        stats: {
            gamesPlayed: 0,
            winRate: 0,
            avgProfit: 0
        }
    });
});

socket.on('room-created', (data) => {
    console.log('✅ Room created successfully!');
    console.log('   Room code:', data.roomCode);
    console.log('   Players:', data.room.players.length);
    socket.disconnect();
    process.exit(0);
});

socket.on('error', (error) => {
    console.error('❌ Error:', error);
    process.exit(1);
});

socket.on('connect_error', (error) => {
    console.error('❌ Connection error:', error.message);
    process.exit(1);
});

setTimeout(() => {
    console.log('❌ Connection timeout');
    process.exit(1);
}, 10000);
EOF

# Check if socket.io-client is installed
if ! npm list socket.io-client &>/dev/null; then
    echo "   Installing socket.io-client..."
    npm install socket.io-client
fi

node /tmp/test-ws.js
rm /tmp/test-ws.js
echo ""

# Test 5: Manual browser test instructions
echo "5️⃣  Manual browser test:"
echo "   1. Open: https://flexport-3d.vercel.app"
echo "   2. Click 'Multiplayer'"
echo "   3. You should see the multiplayer lobby"
echo "   4. Try creating a room"
echo ""

# Test 6: Check EC2 server logs
echo "6️⃣  To check server logs on EC2:"
echo "   ssh -i your-key.pem ubuntu@34.215.161.218"
echo "   pm2 logs flexport-multiplayer"
echo ""

echo "====================================="
echo "🎮 Test Summary:"
echo "If all tests passed, your multiplayer is ready!"
echo "WebSocket URL: $WS_URL"
echo "Health Check: $SERVER_URL/health"
echo ""
echo "Next steps:"
echo "1. Update Vercel environment variable:"
echo "   REACT_APP_MULTIPLAYER_SERVER_URL=$SERVER_URL"
echo "2. Test multiplayer features in the app"