#!/bin/bash

echo "🔧 Adding WebSocket port 3001 to EC2 Security Group"
echo "=================================================="
echo ""

SECURITY_GROUP="sg-0e49ccb1da4107159"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Install it with:"
    echo "brew install awscli"
    echo ""
    echo "Or add the rule manually in AWS Console:"
    echo "1. Go to EC2 > Security Groups"
    echo "2. Select $SECURITY_GROUP"
    echo "3. Edit inbound rules"
    echo "4. Add rule: Custom TCP, Port 3001, Source 0.0.0.0/0"
    exit 1
fi

# Add the security group rule
echo "Adding port 3001..."
aws ec2 authorize-security-group-ingress \
    --group-id $SECURITY_GROUP \
    --protocol tcp \
    --port 3001 \
    --cidr 0.0.0.0/0 \
    --region us-west-2 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ Port 3001 added successfully!"
else
    echo "⚠️  Port might already be open or AWS credentials not configured"
    echo ""
    echo "To configure AWS CLI:"
    echo "aws configure"
    echo ""
    echo "Or add the rule manually in the AWS Console"
fi

echo ""
echo "Current security group rules:"
aws ec2 describe-security-groups --group-ids $SECURITY_GROUP --region us-west-2 --query "SecurityGroups[0].IpPermissions[?ToPort==\`3001\`]" 2>/dev/null || echo "Check AWS Console"