#!/bin/bash

echo "🚀 Complete AWS EC2 Deployment for FlexPort Multiplayer"
echo "======================================================"
echo ""

# Configuration
EC2_HOST="34.215.161.218"
PEM_FILE="/Users/jfuginay/Downloads/supersecret.pem"
SECURITY_GROUP="sg-0e49ccb1da4107159"

# Step 1: Add port 3001 to security group
echo "📝 Step 1: Adding port 3001 to security group..."
echo "Run this command to allow WebSocket connections:"
echo ""
echo "aws ec2 authorize-security-group-ingress \\"
echo "  --group-id $SECURITY_GROUP \\"
echo "  --protocol tcp \\"
echo "  --port 3001 \\"
echo "  --cidr 0.0.0.0/0"
echo ""
echo "Press Enter after running the above command..."
read

# Step 2: Test connection
echo "🔌 Step 2: Testing SSH connection..."
ssh -i "$PEM_FILE" -o ConnectTimeout=5 -o StrictHostKeyChecking=no ec2-user@$EC2_HOST "echo '✅ Connected!'" || {
    echo "❌ Connection failed. Check your PEM file and security group."
    exit 1
}

# Step 3: Quick deploy
echo "🚀 Step 3: Quick deployment..."
echo "Uploading server files..."

# Create a minimal deployment script
cat > /tmp/quick-deploy.sh << 'EOF'
#!/bin/bash
cd ~/server
npm install
pm2 stop flexport-multiplayer 2>/dev/null
pm2 start index.js --name flexport-multiplayer
pm2 save
echo "✅ Server running on port 3001"
EOF

# Upload and run
scp -i "$PEM_FILE" -o StrictHostKeyChecking=no /tmp/quick-deploy.sh ec2-user@$EC2_HOST:~/
ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ec2-user@$EC2_HOST "chmod +x ~/quick-deploy.sh && ~/quick-deploy.sh"

# Cleanup
rm /tmp/quick-deploy.sh

echo ""
echo "✅ Deployment complete!"
echo ""
echo "Test your server:"
echo "curl http://$EC2_HOST:3001/health"
echo ""
echo "Update Vercel environment variable:"
echo "REACT_APP_MULTIPLAYER_SERVER_URL=http://$EC2_HOST:3001"