#!/bin/bash

# FlexPort iOS Simulator Launcher

echo "🚀 Launching FlexPort iOS in Simulator..."

# Build the project
echo "🔨 Building FlexPort iOS..."
cd "/Users/jfuginay/Documents/dev/FlexPort/FlexPort iOS"
xcodebuild -scheme "FlexPort" -destination "platform=iOS Simulator,name=iPhone 16" build

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    
    # Find the app path
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "FlexPort.app" -path "*/Build/Products/Debug-iphonesimulator/*" | head -1)
    
    if [ -n "$APP_PATH" ]; then
        echo "📱 Installing app to simulator..."
        
        # Boot the simulator if needed
        xcrun simctl boot "iPhone 16" 2>/dev/null || true
        
        # Install the app
        xcrun simctl install "iPhone 16" "$APP_PATH"
        
        # Launch the app
        echo "🎮 Launching FlexPort..."
        xcrun simctl launch "iPhone 16" com.flexport.game
        
        # Open the simulator
        open -a Simulator
        
        echo "✨ FlexPort iOS is running!"
    else
        echo "❌ Could not find built app"
        exit 1
    fi
else
    echo "❌ Build failed"
    exit 1
fi