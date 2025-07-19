#!/bin/bash

echo "🚀 EC2 Deployment Helper"
echo "========================"
echo ""

# Server files to deploy
SERVER_DIR="/Users/jfuginay/Documents/dev/FlexPort/flexport-3d/server"
EC2_HOST="34.215.161.218"
PEM_FILE="/Users/jfuginay/Downloads/supersecret.pem"

echo "Testing connection to EC2..."
echo ""

# Test SSH connection
echo "Trying ubuntu user..."
ssh -i "$PEM_FILE" -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$EC2_HOST "echo 'Connected as ubuntu!'" 2>/dev/null

if [ $? -ne 0 ]; then
    echo "Failed with ubuntu, trying ec2-user..."
    ssh -i "$PEM_FILE" -o ConnectTimeout=5 -o StrictHostKeyChecking=no ec2-user@$EC2_HOST "echo 'Connected as ec2-user!'" 2>/dev/null
    
    if [ $? -ne 0 ]; then
        echo "❌ Connection failed!"
        echo ""
        echo "Troubleshooting:"
        echo "1. Is this the correct PEM file for instance i-06dd1a825edc4c4df?"
        echo "2. Check AWS Console > EC2 > Instances > i-06dd1a825edc4c4df"
        echo "3. Click 'Connect' button to see the correct username"
        echo "4. Verify the instance is running"
        echo ""
        echo "Try manually:"
        echo "ssh -i $PEM_FILE -v ubuntu@$EC2_HOST"
        exit 1
    else
        EC2_USER="ec2-user"
    fi
else
    EC2_USER="ubuntu"
fi

echo "✅ Connected successfully as $EC2_USER!"
echo ""

# Create deployment commands
cat > /tmp/deploy-commands.sh << 'EOF'
#!/bin/bash

echo "Setting up FlexPort Multiplayer Server..."

# Install Node.js if needed
if ! command -v node &> /dev/null; then
    echo "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs || sudo yum install -y nodejs
fi

# Install PM2 if needed
if ! command -v pm2 &> /dev/null; then
    echo "Installing PM2..."
    sudo npm install -g pm2
fi

# Setup server
cd ~/server
echo "Installing dependencies..."
npm install

# Start server
echo "Starting server..."
pm2 stop flexport-multiplayer 2>/dev/null
pm2 start index.js --name flexport-multiplayer

# Setup auto-start
pm2 save
pm2 startup | grep sudo | bash

# Show status
echo ""
echo "✅ Server deployed!"
pm2 status
echo ""
echo "Testing health endpoint..."
curl -s http://localhost:3001/health | jq '.' || curl http://localhost:3001/health
EOF

# Deploy
echo "Uploading server files..."
scp -i "$PEM_FILE" -o StrictHostKeyChecking=no -r "$SERVER_DIR" $EC2_USER@$EC2_HOST:~/

echo "Running deployment script..."
scp -i "$PEM_FILE" -o StrictHostKeyChecking=no /tmp/deploy-commands.sh $EC2_USER@$EC2_HOST:~/
ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no $EC2_USER@$EC2_HOST "chmod +x ~/deploy-commands.sh && ~/deploy-commands.sh"

# Cleanup
rm /tmp/deploy-commands.sh

echo ""
echo "🎉 Deployment complete!"
echo "Test URL: http://$EC2_HOST:3001/health"