#!/bin/bash

# EC2 Deployment Script for FlexPort 3D Multiplayer Server
# Usage: ./deploy-to-ec2.sh your-key.pem

if [ $# -eq 0 ]; then
    echo "Usage: $0 <path-to-pem-file>"
    exit 1
fi

PEM_FILE=$1
EC2_HOST="ubuntu@34.215.161.218"

echo "🚀 Deploying FlexPort 3D Multiplayer Server to EC2..."
echo "=============================================="

# Upload server files
echo "1. Uploading server files..."
scp -i "$PEM_FILE" -r server "$EC2_HOST:~/"

# Connect and run deployment
echo "2. Connecting to EC2 and running deployment..."
ssh -i "$PEM_FILE" "$EC2_HOST" << 'ENDSSH'
cd ~/server

# Make deployment script executable
chmod +x deploy-ec2.sh

# Run deployment
./deploy-ec2.sh

echo ""
echo "✅ Deployment complete!"
echo ""
echo "Testing server..."
curl -s http://localhost:3001/health | jq '.'

echo ""
echo "Server logs (last 20 lines):"
pm2 logs flexport-multiplayer --lines 20 --nostream
ENDSSH

echo ""
echo "🎉 Deployment finished!"
echo "=============================================="
echo "WebSocket URL: ws://34.215.161.218:3001"
echo "Health Check: http://34.215.161.218:3001/health"
echo ""
echo "⚠️  IMPORTANT: Make sure port 3001 is open in your EC2 security group!"