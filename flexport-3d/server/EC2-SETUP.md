# EC2 Setup Guide for FlexPort 3D Multiplayer Server

## Prerequisites
1. EC2 instance running (✓ You have: i-06dd1a825edc4c4df)
2. SSH key pair configured
3. Security group configured for ports 22 (SSH) and 3001 (WebSocket)

## Step 1: Configure Security Group

In AWS Console:
1. Go to EC2 > Security Groups
2. Find your instance's security group
3. Edit inbound rules and add:
   - Type: Custom TCP
   - Port: 3001
   - Source: 0.0.0.0/0 (or restrict as needed)
   - Description: FlexPort Multiplayer Server

## Step 2: Connect to EC2

```bash
ssh -i your-key.pem ubuntu@34.215.161.218
```

## Step 3: Quick Deploy (One Command)

Run this command after SSH-ing into your EC2:

```bash
curl -sL https://raw.githubusercontent.com/YOUR_USERNAME/flexport-3d/main/server/deploy-ec2.sh | bash
```

OR manually:

```bash
# 1. Upload the server folder to EC2
scp -i your-key.pem -r server ubuntu@34.215.161.218:~/

# 2. SSH into EC2
ssh -i your-key.pem ubuntu@34.215.161.218

# 3. Run deployment
cd ~/server
chmod +x deploy-ec2.sh
./deploy-ec2.sh
```

## Step 4: Manual Setup (Alternative)

If you prefer manual setup:

```bash
# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# Install PM2
sudo npm install -g pm2

# Create app directory
mkdir -p ~/flexport-server
cd ~/flexport-server

# Upload your server files here, then:
npm install
pm2 start index.js --name flexport-multiplayer
pm2 save
pm2 startup
```

## Step 5: Verify Deployment

1. Check server status:
   ```bash
   pm2 status
   pm2 logs
   ```

2. Test health endpoint:
   ```bash
   curl http://localhost:3001/health
   ```

3. From your local machine:
   ```bash
   curl http://34.215.161.218:3001/health
   ```

## Server URLs

- WebSocket: `ws://34.215.161.218:3001`
- HTTP: `http://34.215.161.218:3001`

## Troubleshooting

1. **Cannot connect**: Check security group rules
2. **Server not starting**: Check logs with `pm2 logs`
3. **Port already in use**: `sudo lsof -i :3001` and kill the process

## Updating the Server

```bash
cd ~/flexport-server
git pull  # or upload new files
pm2 restart flexport-multiplayer
```