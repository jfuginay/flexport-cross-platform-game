#!/bin/bash

echo "📱 TESTING iOS COMPANION APP"
echo "============================"

cd "FlexPort iOS"

# Check if Xcode is available
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode not found. Please install Xcode from the App Store."
    echo "💡 Alternative: Open FlexPort.xcodeproj in Xcode manually"
    exit 1
fi

echo "✅ Xcode build tools available"

# Check if project file exists
if [ ! -f "FlexPort.xcodeproj/project.pbxproj" ]; then
    echo "❌ Xcode project file not found"
    echo "🔍 Looking for project files..."
    find . -name "*.xcodeproj" -type d
    exit 1
fi

echo "✅ Xcode project found: FlexPort.xcodeproj"

# Clean build folder
echo ""
echo "🧹 Cleaning build folder..."
xcodebuild clean -project FlexPort.xcodeproj -scheme FlexPort

# Build for iOS Simulator
echo ""
echo "🔨 Building for iOS Simulator..."
xcodebuild build -project FlexPort.xcodeproj -scheme FlexPort -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest'

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ iOS build completed successfully!"
    echo ""
    echo "🎮 COMPANION APP FEATURES TO TEST:"
    echo "================================="
    echo "1. ✅ Unity connection status"
    echo "2. ✅ Game Week dashboard"
    echo "3. ✅ Trade empire management"
    echo "4. ✅ Market monitoring (Ryan's 4 markets)"
    echo "5. ✅ AI singularity tracker"
    echo "6. ✅ Real-time sync with Unity game"
    echo ""
    echo "🚀 TO RUN IN SIMULATOR:"
    echo "1. Open Xcode: open FlexPort.xcodeproj"
    echo "2. Select iPhone simulator"
    echo "3. Press Cmd+R to run"
    echo ""
else
    echo ""
    echo "❌ iOS build failed"
    echo ""
    echo "🔍 Common fixes:"
    echo "1. Update iOS deployment target in Xcode"
    echo "2. Check Swift package dependencies"
    echo "3. Verify signing certificates"
    echo "4. Open project in Xcode for detailed errors"
    echo ""
    echo "🚀 Manual testing:"
    echo "1. Open: open FlexPort.xcodeproj"
    echo "2. Fix any Xcode errors"
    echo "3. Run on simulator or device"
fi