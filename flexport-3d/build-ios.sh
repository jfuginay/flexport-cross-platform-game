#!/bin/bash

echo "🚀 Building FlexPort for iOS"
echo "=========================="

# Build the React app
echo "Building React app..."
npm run build

# Sync with Capacitor
echo "Syncing with Capacitor..."
npx cap sync ios

# Open in Xcode
echo "Opening in Xcode..."
npx cap open ios

echo "✅ Done! You can now run the app in the iOS Simulator"