#!/bin/bash

# FlexPort Services Startup Script

echo "🚀 Starting FlexPort Game Services..."

# Check if .env file exists
if [ ! -f "./flexport-3d/.env" ]; then
    echo "⚠️  Warning: .env file not found in flexport-3d directory"
    echo "📝 Creating .env from .env.example..."
    cp ./flexport-3d/.env.example ./flexport-3d/.env
    echo "⚠️  Please add your Mapbox token to ./flexport-3d/.env"
fi

# Stop any running containers
echo "🛑 Stopping existing containers..."
docker-compose down

# Build and start all services
echo "🏗️  Building services..."
docker-compose build

echo "🚀 Starting services..."
docker-compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 10

# Check service health
echo "🏥 Checking service health..."
echo "  - Game Server: http://localhost:3000"
curl -s http://localhost:3000 > /dev/null && echo "    ✅ Running" || echo "    ❌ Not responding"

echo "  - AI Service: http://localhost:5000/health"
curl -s http://localhost:5000/health > /dev/null && echo "    ✅ Running" || echo "    ❌ Not responding"

echo "  - Analytics Service: http://localhost:8080/health"
curl -s http://localhost:8080/health > /dev/null && echo "    ✅ Running" || echo "    ❌ Not responding"

echo "  - PostgreSQL: localhost:5432"
docker exec flexport-postgres pg_isready > /dev/null && echo "    ✅ Running" || echo "    ❌ Not responding"

echo "  - Redis: localhost:6379"
docker exec flexport-redis redis-cli ping > /dev/null && echo "    ✅ Running" || echo "    ❌ Not responding"

echo ""
echo "📊 View logs with: docker-compose logs -f"
echo "🛑 Stop services with: docker-compose down"
echo ""
echo "🎮 Game is available at: http://localhost:3000"