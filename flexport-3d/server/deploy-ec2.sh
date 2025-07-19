#!/bin/bash

# EC2 Deployment Script for FlexPort 3D Multiplayer Server
# Run this on your EC2 instance after SSH-ing in

echo "FlexPort 3D Multiplayer Server - EC2 Deployment"
echo "=============================================="

# Update system
echo "1. Updating system packages..."
sudo apt update -y
sudo apt upgrade -y

# Install Node.js (v18 LTS)
echo "2. Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# Install PM2 for process management
echo "3. Installing PM2..."
sudo npm install -g pm2

# Install git
echo "4. Installing git..."
sudo apt install -y git

# Clone the repository (or pull latest changes)
echo "5. Setting up application..."
cd /home/ubuntu

if [ -d "flexport-3d" ]; then
    echo "Repository exists, pulling latest changes..."
    cd flexport-3d
    git pull
else
    echo "Cloning repository..."
    git clone https://github.com/YOUR_GITHUB_USERNAME/flexport-3d.git
    cd flexport-3d
fi

# Navigate to server directory
cd server

# Install dependencies
echo "6. Installing dependencies..."
npm install

# Create PM2 ecosystem file
echo "7. Creating PM2 configuration..."
cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'flexport-multiplayer',
    script: 'index.js',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 3001
    }
  }]
}
EOF

# Start the server with PM2
echo "8. Starting server with PM2..."
pm2 start ecosystem.config.js

# Setup PM2 to start on boot
echo "9. Setting up auto-start on boot..."
pm2 startup systemd -u ubuntu --hp /home/ubuntu
pm2 save

# Show status
echo "10. Server status:"
pm2 status

echo ""
echo "Deployment complete!"
echo "==================="
echo "Server is running on port 3001"
echo "WebSocket URL: ws://34.215.161.218:3001"
echo ""
echo "Useful PM2 commands:"
echo "  pm2 status        - Check server status"
echo "  pm2 logs          - View server logs"
echo "  pm2 restart all   - Restart server"
echo "  pm2 stop all      - Stop server"
echo ""
echo "IMPORTANT: Configure your security group to allow inbound traffic on port 3001!"