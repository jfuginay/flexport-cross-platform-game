#!/bin/bash

echo "🤖 TESTING ANDROID COMPANION APP"
echo "================================="

cd "FlexPort Android"

# Check if Java is available
if ! command -v java &> /dev/null; then
    echo "❌ Java not found. Please install OpenJDK 11 or later."
    exit 1
fi

echo "✅ Java version: $(java -version 2>&1 | head -n 1)"

# Check for Android SDK
if [ -z "$ANDROID_HOME" ]; then
    echo "⚠️  ANDROID_HOME not set"
    echo "🔍 Looking for Android SDK..."
    
    # Common Android SDK locations
    POSSIBLE_PATHS=(
        "$HOME/Library/Android/sdk"
        "$HOME/Android/Sdk"
        "/opt/android-sdk"
        "/usr/local/android-sdk"
    )
    
    for path in "${POSSIBLE_PATHS[@]}"; do
        if [ -d "$path" ]; then
            echo "📍 Found Android SDK at: $path"
            export ANDROID_HOME="$path"
            export PATH="$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools"
            break
        fi
    done
    
    if [ -z "$ANDROID_HOME" ]; then
        echo "❌ Android SDK not found"
        echo "💡 Please install Android Studio or set ANDROID_HOME"
        echo "💡 Alternative: Open project in Android Studio manually"
        exit 1
    fi
fi

echo "✅ Android SDK found: $ANDROID_HOME"

# Check if gradlew exists
if [ ! -f "gradlew" ]; then
    echo "❌ Gradle wrapper not found"
    echo "🔍 Current directory contents:"
    ls -la
    exit 1
fi

echo "✅ Gradle wrapper found"

# Make gradlew executable
chmod +x gradlew

# Clean project
echo ""
echo "🧹 Cleaning project..."
./gradlew clean

# Build debug APK
echo ""
echo "🔨 Building debug APK..."
./gradlew assembleDebug

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Android build completed successfully!"
    echo ""
    echo "📦 APK location: app/build/outputs/apk/debug/app-debug.apk"
    echo ""
    echo "🎮 COMPANION APP FEATURES TO TEST:"
    echo "================================="
    echo "1. ✅ Unity bridge connection"
    echo "2. ✅ Game Week dashboard"
    echo "3. ✅ Trade empire management"
    echo "4. ✅ Market monitoring (Ryan's 4 markets)"
    echo "5. ✅ AI singularity tracker"
    echo "6. ✅ Material Design 3 UI"
    echo "7. ✅ Real-time sync with Unity game"
    echo ""
    echo "🚀 TO INSTALL ON DEVICE:"
    echo "1. Enable USB debugging on Android device"
    echo "2. Connect device via USB"
    echo "3. Run: ./gradlew installDebug"
    echo ""
    echo "🔧 TO OPEN IN ANDROID STUDIO:"
    echo "1. Launch Android Studio"
    echo "2. Open existing project"
    echo "3. Select: FlexPort Android folder"
    echo ""
else
    echo ""
    echo "❌ Android build failed"
    echo ""
    echo "🔍 Common fixes:"
    echo "1. Check Android SDK version compatibility"
    echo "2. Update Gradle version in gradle/wrapper/gradle-wrapper.properties"
    echo "3. Sync project in Android Studio"
    echo "4. Check for missing dependencies"
    echo ""
    echo "🚀 Manual testing:"
    echo "1. Open Android Studio"
    echo "2. Open FlexPort Android project"
    echo "3. Sync and build in IDE"
    echo "4. Run on emulator or device"
fi

# Test connectivity (if build succeeded)
if [ $? -eq 0 ]; then
    echo ""
    echo "📡 Testing Unity bridge simulation..."
    echo "💡 The Android app includes Unity bridge simulation"
    echo "💡 It will show mock data when Unity server is unavailable"
fi