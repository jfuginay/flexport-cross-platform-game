#!/bin/bash

# Quick EC2 deployment commands
# Replace 'your-key.pem' with your actual PEM file path

echo "🚀 Quick EC2 Deployment Steps for FlexPort Multiplayer Server"
echo "============================================================="
echo ""
echo "Step 1: Upload server files to EC2"
echo "Run this command (replace with your PEM file):"
echo ""
echo "scp -i your-key.pem -r server ubuntu@34.215.161.218:~/"
echo ""
echo "Step 2: SSH into EC2"
echo "Run this command (replace with your PEM file):"
echo ""
echo "ssh -i your-key.pem ubuntu@34.215.161.218"
echo ""
echo "Step 3: Once connected to EC2, run these commands:"
echo ""
cat << 'EOF'
# Install Node.js if not already installed
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# Install PM2
sudo npm install -g pm2

# Go to server directory
cd ~/server

# Install dependencies
npm install

# Start the server
pm2 start index.js --name flexport-multiplayer

# Save PM2 configuration
pm2 save
pm2 startup

# Check if running
pm2 status

# View logs
pm2 logs flexport-multiplayer --lines 20
EOF

echo ""
echo "Step 4: Test the server"
echo "From your local machine, run:"
echo ""
echo "curl http://34.215.161.218:3001/health"
echo ""
echo "You should see: {\"status\":\"ok\",\"rooms\":0,\"players\":0}"