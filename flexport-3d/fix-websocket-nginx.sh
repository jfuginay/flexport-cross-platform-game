#!/bin/bash

echo "🔧 Fixing WebSocket configuration on EC2..."
echo "========================================="

# Check current nginx configuration
echo "1. Current nginx configuration:"
sudo cat /etc/nginx/conf.d/flexport.conf

echo ""
echo "2. Updating nginx configuration for WebSocket support..."

# Create proper nginx configuration
sudo tee /etc/nginx/conf.d/flexport.conf > /dev/null <<'EOF'
server {
    listen 80;
    server_name flexportglobal.engindearing.soy;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name flexportglobal.engindearing.soy;

    ssl_certificate /etc/letsencrypt/live/flexportglobal.engindearing.soy/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/flexportglobal.engindearing.soy/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    # WebSocket support
    location /socket.io/ {
        proxy_pass http://localhost:3001/socket.io/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Disable buffering for WebSocket
        proxy_buffering off;
        
        # WebSocket timeouts
        proxy_connect_timeout 7d;
        proxy_send_timeout 7d;
        proxy_read_timeout 7d;
    }

    # Regular HTTP traffic
    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Health check
    location /health {
        proxy_pass http://localhost:3001/health;
    }
}
EOF

echo ""
echo "3. Testing nginx configuration..."
sudo nginx -t

echo ""
echo "4. Reloading nginx..."
sudo systemctl reload nginx

echo ""
echo "5. Checking if Node.js server is running..."
pm2 status

echo ""
echo "6. Checking Node.js server logs..."
pm2 logs flexport-multiplayer --lines 20 --nostream

echo ""
echo "7. Testing WebSocket connection..."
curl -i -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==" \
  -H "Sec-WebSocket-Version: 13" \
  https://flexportglobal.engindearing.soy/socket.io/

echo ""
echo "✅ WebSocket configuration updated!"
echo "===================================="