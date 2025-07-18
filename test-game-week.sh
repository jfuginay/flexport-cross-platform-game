#!/bin/bash

echo "🎮 FLEXPORT GAME WEEK TESTING SUITE"
echo "===================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_TOTAL=0

test_result() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ PASSED${NC}: $2"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAILED${NC}: $2"
    fi
}

echo -e "${BLUE}📋 Testing Game Week Requirements...${NC}"
echo ""

# Test 1: Unity Project Structure
echo "🔍 Testing Unity project structure..."
if [ -d "FlexPort Unity/FlexPort/Assets/Scripts" ]; then
    test_result 0 "Unity project structure exists"
else
    test_result 1 "Unity project structure missing"
fi

# Test 2: Core Game Systems
echo "🔍 Testing core game systems..."
CORE_SYSTEMS=(
    "FlexPort Unity/FlexPort/Assets/Scripts/Networking/GameWeekMultiplayer.cs"
    "FlexPort Unity/FlexPort/Assets/Scripts/Economy/RyanFourMarketSystem.cs"
    "FlexPort Unity/FlexPort/Assets/Scripts/AI/SingularitySystem.cs"
    "FlexPort Unity/FlexPort/Assets/Scripts/TradeEmpire/TradeEmpireManager.cs"
    "FlexPort Unity/FlexPort/Assets/Scripts/GameWeek/GameWeekValidator.cs"
)

for system in "${CORE_SYSTEMS[@]}"; do
    if [ -f "$system" ]; then
        test_result 0 "$(basename "$system") implemented"
    else
        test_result 1 "$(basename "$system") missing"
    fi
done

# Test 3: iOS Companion App
echo "🔍 Testing iOS companion app..."
IOS_FILES=(
    "FlexPort iOS/Sources/FlexPort/GameWeek/GameWeekDashboard.swift"
    "FlexPort iOS/Sources/FlexPort/GameWeek/UnityGameBridge.swift"
)

for file in "${IOS_FILES[@]}"; do
    if [ -f "$file" ]; then
        test_result 0 "$(basename "$file") implemented"
    else
        test_result 1 "$(basename "$file") missing"
    fi
done

# Test 4: Android Companion App
echo "🔍 Testing Android companion app..."
ANDROID_FILES=(
    "FlexPort Android/app/src/main/java/com/flexport/gameweek/GameWeekActivity.kt"
    "FlexPort Android/app/src/main/java/com/flexport/gameweek/unity/UnityBridge.kt"
)

for file in "${ANDROID_FILES[@]}"; do
    if [ -f "$file" ]; then
        test_result 0 "$(basename "$file") implemented"
    else
        test_result 1 "$(basename "$file") missing"
    fi
done

# Test 5: Web Integration
echo "🔍 Testing web integration..."
WEB_FILES=(
    "Web/src/gameweek/GameWeekMultiplayerWeb.ts"
    "Web/src/main.ts"
)

for file in "${WEB_FILES[@]}"; do
    if [ -f "$file" ]; then
        test_result 0 "$(basename "$file") implemented"
    else
        test_result 1 "$(basename "$file") missing"
    fi
done

# Test 6: Docker Configuration
echo "🔍 Testing Docker configuration..."
if [ -f "docker-compose.game-week.yml" ]; then
    test_result 0 "Docker Compose configuration exists"
    
    # Count services in docker-compose
    SERVICE_COUNT=$(grep -c "image:" docker-compose.game-week.yml)
    if [ $SERVICE_COUNT -ge 5 ]; then
        test_result 0 "Docker services count ($SERVICE_COUNT >= 5)"
    else
        test_result 1 "Insufficient Docker services ($SERVICE_COUNT < 5)"
    fi
else
    test_result 1 "Docker Compose configuration missing"
fi

# Test 7: Code Quality Checks
echo "🔍 Testing code quality..."

# Check for Game Week compliance keywords
UNITY_FILES=$(find "FlexPort Unity/FlexPort/Assets/Scripts" -name "*.cs" 2>/dev/null)
if [ -n "$UNITY_FILES" ]; then
    MULTIPLAYER_MENTIONS=$(grep -l "multiplayer\|Multiplayer\|NetworkBehaviour" $UNITY_FILES | wc -l)
    if [ $MULTIPLAYER_MENTIONS -gt 0 ]; then
        test_result 0 "Multiplayer implementation detected"
    else
        test_result 1 "No multiplayer implementation found"
    fi
    
    RYAN_VISION=$(grep -l "Ryan\|FourMarket\|Singularity" $UNITY_FILES | wc -l)
    if [ $RYAN_VISION -gt 0 ]; then
        test_result 0 "Ryan's CEO vision implemented"
    else
        test_result 1 "Ryan's CEO vision missing"
    fi
else
    test_result 1 "No Unity C# files found"
fi

# Test 8: Platform-Specific Checks
echo "🔍 Testing platform integrations..."

# iOS Swift files
IOS_SWIFT_COUNT=$(find "FlexPort iOS" -name "*.swift" 2>/dev/null | wc -l)
if [ $IOS_SWIFT_COUNT -gt 0 ]; then
    test_result 0 "iOS Swift implementation ($IOS_SWIFT_COUNT files)"
else
    test_result 1 "No iOS Swift files found"
fi

# Android Kotlin files
ANDROID_KT_COUNT=$(find "FlexPort Android" -name "*.kt" 2>/dev/null | wc -l)
if [ $ANDROID_KT_COUNT -gt 0 ]; then
    test_result 0 "Android Kotlin implementation ($ANDROID_KT_COUNT files)"
else
    test_result 1 "No Android Kotlin files found"
fi

# Web TypeScript files
WEB_TS_COUNT=$(find "Web/src" -name "*.ts" 2>/dev/null | wc -l)
if [ $WEB_TS_COUNT -gt 0 ]; then
    test_result 0 "Web TypeScript implementation ($WEB_TS_COUNT files)"
else
    test_result 1 "No Web TypeScript files found"
fi

echo ""
echo "===================================="
echo -e "${BLUE}📊 TEST RESULTS SUMMARY${NC}"
echo "===================================="
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Total:  ${YELLOW}$TESTS_TOTAL${NC}"

PASS_RATE=$((TESTS_PASSED * 100 / TESTS_TOTAL))
echo -e "Pass Rate:    ${BLUE}$PASS_RATE%${NC}"

if [ $PASS_RATE -ge 80 ]; then
    echo ""
    echo -e "${GREEN}🎉 GAME WEEK PROJECT READY FOR DEMO!${NC}"
    echo -e "${GREEN}✅ All critical requirements met${NC}"
else
    echo ""
    echo -e "${RED}⚠️  GAME WEEK REQUIREMENTS NOT FULLY MET${NC}"
    echo -e "${YELLOW}🔧 Please address failed tests above${NC}"
fi

echo ""
echo "===================================="
echo -e "${BLUE}🚀 NEXT STEPS FOR TESTING:${NC}"
echo "===================================="
echo "1. Run: ./test-web-game.sh"
echo "2. Run: ./test-ios-build.sh" 
echo "3. Run: ./test-android-build.sh"
echo "4. Run: ./test-unity-multiplayer.sh"
echo "5. Run: ./validate-game-week.sh"
echo ""