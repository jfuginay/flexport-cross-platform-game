#!/bin/bash

# SSL Setup Script for EC2 with Let's Encrypt and Nginx
# This script sets up SSL for flexportglobal.engindearing.soy

echo "🔒 Setting up SSL for FlexPort Multiplayer Server"
echo "================================================="

# Update system
echo "1. Updating system packages..."
sudo apt update
sudo apt upgrade -y

# Install Nginx and Certbot
echo "2. Installing Nginx and Certbot..."
sudo apt install -y nginx certbot python3-certbot-nginx

# Stop Nginx to configure
echo "3. Configuring Nginx..."
sudo systemctl stop nginx

# Create Nginx configuration for the domain
echo "4. Creating Nginx configuration..."
sudo tee /etc/nginx/sites-available/flexportglobal.engindearing.soy > /dev/null <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name flexportglobal.engindearing.soy;

    # For Let's Encrypt verification
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name flexportglobal.engindearing.soy;

    # SSL certificates will be added by Certbot
    
    # WebSocket proxy configuration
    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket specific timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        proxy_buffering off;
    }

    # Health check endpoint
    location /health {
        proxy_pass http://localhost:3001/health;
        proxy_set_header Host \$host;
    }
}
EOF

# Enable the site
echo "5. Enabling site configuration..."
sudo ln -sf /etc/nginx/sites-available/flexportglobal.engindearing.soy /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
echo "6. Testing Nginx configuration..."
sudo nginx -t

# Start Nginx
echo "7. Starting Nginx..."
sudo systemctl start nginx
sudo systemctl enable nginx

# Get SSL certificate
echo "8. Obtaining SSL certificate from Let's Encrypt..."
echo "   Make sure flexportglobal.engindearing.soy points to this server's IP!"
echo "   Current server IP: $(curl -s ifconfig.me)"
echo ""
read -p "Press Enter when DNS is configured correctly..."

# Run Certbot
sudo certbot --nginx -d flexportglobal.engindearing.soy --non-interactive --agree-tos --email admin@engindearing.soy

# Set up auto-renewal
echo "9. Setting up SSL auto-renewal..."
sudo systemctl enable certbot.timer

# Configure firewall
echo "10. Configuring firewall..."
sudo ufw allow 'Nginx Full'
sudo ufw allow OpenSSH
sudo ufw --force enable

# Test the setup
echo ""
echo "✅ SSL Setup Complete!"
echo "================================================="
echo "Your multiplayer server is now available at:"
echo "https://flexportglobal.engindearing.soy"
echo ""
echo "Testing HTTPS endpoint..."
curl -s https://flexportglobal.engindearing.soy/health | jq '.'
echo ""
echo "To check SSL certificate:"
echo "sudo certbot certificates"
echo ""
echo "To manually renew certificate:"
echo "sudo certbot renew --dry-run"