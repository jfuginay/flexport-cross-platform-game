# FlexPort 3D Multiplayer Server

WebSocket server for FlexPort 3D multiplayer functionality using Socket.io.

## Local Development

```bash
npm install
npm run dev
```

Server runs on http://localhost:3001

## Deployment

### Option 1: Render.com
1. Push to GitHub
2. Create new Web Service on Render
3. Connect GitHub repo
4. Set root directory: `server`
5. Build Command: `npm install`
6. Start Command: `npm start`

### Option 2: Railway
1. Install Railway CLI: `npm install -g @railway/cli`
2. Run: `railway login`
3. Run: `railway init`
4. Run: `railway up`

### Option 3: AWS EC2
1. Launch EC2 instance (t2.micro)
2. Install Node.js
3. Clone repo and install dependencies
4. Use PM2 for process management
5. Configure security group for port 3001

## Environment Variables

No environment variables required for basic operation.

## API Endpoints

- WebSocket connection: `ws://your-server:3001`
- Health check: `GET /health`