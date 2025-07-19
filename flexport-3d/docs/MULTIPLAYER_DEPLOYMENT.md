# FlexPort Multiplayer Deployment Guide

## Current Issue: Mixed Content Warning

Your Vercel deployment (HTTPS) cannot connect to the EC2 multiplayer server (HTTP) due to browser security restrictions.

## Solutions

### Option 1: Deploy Frontend to HTTP (Quick Fix)
Instead of Vercel, deploy the frontend to an HTTP domain:
- Use Netlify with a custom HTTP domain
- Deploy to EC2 alongside the server
- Use GitHub Pages with HTTP

### Option 2: Add SSL to EC2 Server (Recommended)
Set up HTTPS on your EC2 instance:

1. **Install Nginx as reverse proxy:**
```bash
sudo apt update
sudo apt install nginx
```

2. **Get free SSL certificate with Let's Encrypt:**
```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com
```

3. **Configure Nginx for WebSocket:**
```nginx
server {
    server_name yourdomain.com;

    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

### Option 3: Use a WebSocket Proxy Service
Services like Cloudflare can provide SSL termination:
- Add your domain to Cloudflare
- Enable "WebSocket" support
- Point to your EC2 IP

### Option 4: Deploy Server to a Platform with SSL
Deploy the multiplayer server to:
- **Render.com** (free SSL, WebSocket support)
- **Railway.app** (easy deployment, SSL included)
- **Fly.io** (global deployment, SSL included)

## Temporary Workaround

For testing only, users can:
1. Open Chrome with `--allow-running-insecure-content` flag
2. Use Firefox and allow mixed content temporarily
3. Access the frontend via HTTP instead of HTTPS

## Environment Variables

Set `REACT_APP_MULTIPLAYER_SERVER_URL` in Vercel:
```
REACT_APP_MULTIPLAYER_SERVER_URL=wss://your-secure-server.com
```

## Testing Multiplayer Locally

1. Start the server:
```bash
cd server
npm start
```

2. Start the frontend:
```bash
npm start
```

3. Open multiple browser tabs to test multiplayer features.