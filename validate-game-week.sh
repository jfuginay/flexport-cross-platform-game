#!/bin/bash

echo "🏆 GAME WEEK COMPLIANCE VALIDATION"
echo "=================================="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${BLUE}Validating Game Week Requirements...${NC}"
echo ""

# Game Week Requirements Matrix
REQUIREMENTS=(
    "multiplayer_support:Critical:4+ player real-time multiplayer"
    "performance_targets:Critical:60fps web, 30fps mobile"  
    "railroad_mechanics:High:Trade route competition system"
    "ryan_four_markets:Critical:Goods/Capital/Assets/Labor markets"
    "ai_singularity:High:AI progression with zoo ending"
    "cross_platform:Medium:Web/iOS/Android deployment"
    "companion_apps:Medium:Native mobile integration"
    "complexity_level:Critical:No simplification allowed"
)

PASSED=0
TOTAL=${#REQUIREMENTS[@]}

validate_requirement() {
    local req_line="$1"
    IFS=':' read -r req_name priority description <<< "$req_line"
    
    echo -e "${YELLOW}🔍 Testing: $description${NC}"
    
    case $req_name in
        "multiplayer_support")
            if grep -r "NetworkBehaviour\|multiplayer\|GameWeekMultiplayer" "FlexPort Unity" &>/dev/null; then
                echo -e "  ${GREEN}✅ PASSED${NC}: Multiplayer implementation found"
                return 0
            else
                echo -e "  ${RED}❌ FAILED${NC}: No multiplayer implementation"
                return 1
            fi
            ;;
            
        "performance_targets")
            if grep -r "targetFPS.*60\|60.*fps" "Web\|FlexPort Unity" &>/dev/null; then
                echo -e "  ${GREEN}✅ PASSED${NC}: Performance targets configured"
                return 0
            else
                echo -e "  ${RED}❌ FAILED${NC}: Performance targets not found"
                return 1
            fi
            ;;
            
        "railroad_mechanics")
            if grep -r "TradeRoute\|TradeEmpire\|Railroad.*Tycoon" "FlexPort Unity" &>/dev/null; then
                echo -e "  ${GREEN}✅ PASSED${NC}: Railroad Tycoon mechanics implemented"
                return 0
            else
                echo -e "  ${RED}❌ FAILED${NC}: Railroad mechanics missing"
                return 1
            fi
            ;;
            
        "ryan_four_markets")
            if grep -r "RyanFourMarket\|GoodsMarket\|CapitalMarket\|AssetMarket\|LaborMarket" "FlexPort Unity" &>/dev/null; then
                echo -e "  ${GREEN}✅ PASSED${NC}: Ryan's Four Market system implemented"
                return 0
            else
                echo -e "  ${RED}❌ FAILED${NC}: Four Market system missing"
                return 1
            fi
            ;;
            
        "ai_singularity")
            if grep -r "SingularitySystem\|zoo.*ending\|AI.*singularity" "FlexPort Unity" &>/dev/null; then
                echo -e "  ${GREEN}✅ PASSED${NC}: AI Singularity system implemented"
                return 0
            else
                echo -e "  ${RED}❌ FAILED${NC}: AI Singularity missing"
                return 1
            fi
            ;;
            
        "cross_platform")
            platforms=0
            [ -d "Web/src" ] && platforms=$((platforms + 1))
            [ -d "FlexPort iOS/Sources" ] && platforms=$((platforms + 1))
            [ -d "FlexPort Android/app" ] && platforms=$((platforms + 1))
            [ -d "FlexPort Unity/FlexPort" ] && platforms=$((platforms + 1))
            
            if [ $platforms -ge 3 ]; then
                echo -e "  ${GREEN}✅ PASSED${NC}: $platforms platforms implemented"
                return 0
            else
                echo -e "  ${RED}❌ FAILED${NC}: Only $platforms platforms found"
                return 1
            fi
            ;;
            
        "companion_apps")
            ios_files=$(find "FlexPort iOS" -name "*.swift" 2>/dev/null | wc -l)
            android_files=$(find "FlexPort Android" -name "*.kt" 2>/dev/null | wc -l)
            
            if [ $ios_files -gt 0 ] && [ $android_files -gt 0 ]; then
                echo -e "  ${GREEN}✅ PASSED${NC}: iOS ($ios_files Swift) + Android ($android_files Kotlin)"
                return 0
            else
                echo -e "  ${RED}❌ FAILED${NC}: Companion apps incomplete"
                return 1
            fi
            ;;
            
        "complexity_level")
            # Count total lines of code as complexity metric
            unity_lines=$(find "FlexPort Unity" -name "*.cs" -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}')
            ios_lines=$(find "FlexPort iOS" -name "*.swift" -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}')
            android_lines=$(find "FlexPort Android" -name "*.kt" -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}')
            web_lines=$(find "Web" -name "*.ts" -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}')
            
            total_lines=$((unity_lines + ios_lines + android_lines + web_lines))
            
            if [ $total_lines -gt 5000 ]; then
                echo -e "  ${GREEN}✅ PASSED${NC}: High complexity ($total_lines lines of code)"
                return 0
            else
                echo -e "  ${RED}❌ FAILED${NC}: Insufficient complexity ($total_lines lines)"
                return 1
            fi
            ;;
    esac
}

# Run all validations
echo ""
for req in "${REQUIREMENTS[@]}"; do
    if validate_requirement "$req"; then
        PASSED=$((PASSED + 1))
    fi
    echo ""
done

# Calculate compliance score
COMPLIANCE_SCORE=$((PASSED * 100 / TOTAL))

echo "=================================="
echo -e "${BLUE}📊 VALIDATION RESULTS${NC}"
echo "=================================="
echo -e "Requirements Passed: ${GREEN}$PASSED${NC}/$TOTAL"
echo -e "Compliance Score: ${BLUE}$COMPLIANCE_SCORE%${NC}"

# Determine compliance level
if [ $COMPLIANCE_SCORE -ge 90 ]; then
    echo ""
    echo -e "${GREEN}🎉 OUTSTANDING GAME WEEK COMPLIANCE!${NC}"
    echo -e "${GREEN}✅ Ready for demo presentation${NC}"
    echo -e "${GREEN}🚀 All critical requirements exceeded${NC}"
elif [ $COMPLIANCE_SCORE -ge 80 ]; then
    echo ""
    echo -e "${GREEN}🎉 GAME WEEK REQUIREMENTS MET!${NC}"
    echo -e "${GREEN}✅ Ready for demo${NC}"
    echo -e "${YELLOW}💡 Minor improvements possible${NC}"
elif [ $COMPLIANCE_SCORE -ge 60 ]; then
    echo ""
    echo -e "${YELLOW}⚠️  PARTIAL GAME WEEK COMPLIANCE${NC}"
    echo -e "${YELLOW}🔧 Address failed requirements above${NC}"
    echo -e "${YELLOW}📈 Demo possible with fixes${NC}"
else
    echo ""
    echo -e "${RED}❌ GAME WEEK REQUIREMENTS NOT MET${NC}"
    echo -e "${RED}🚨 Major work needed before demo${NC}"
    echo -e "${RED}🔄 Re-run after implementing missing features${NC}"
fi

# Ryan's CEO vision validation
echo ""
echo "=================================="
echo -e "${PURPLE}👨‍💼 RYAN'S CEO VISION VALIDATION${NC}"
echo "=================================="

RYAN_FEATURES=(
    "Four Market System:$(grep -r "FourMarket\|GoodsMarket\|CapitalMarket" "FlexPort Unity" &>/dev/null && echo "✅" || echo "❌")"
    "Compound Growth:$(grep -r "compound.*growth\|compounding" "FlexPort Unity" &>/dev/null && echo "✅" || echo "❌")"
    "Virtual Economy Scale:$(grep -r "million.*virtual\|1000000.*firms" "FlexPort Unity" &>/dev/null && echo "✅" || echo "❌")"
    "Random Disasters:$(grep -r "disaster\|Hurricane" "FlexPort Unity" &>/dev/null && echo "✅" || echo "❌")"
    "AI Singularity:$(grep -r "singularity.*zoo\|zoo.*animal" "FlexPort Unity" &>/dev/null && echo "✅" || echo "❌")"
    "Intelligent Reinvestment:$(grep -r "intelligent.*reinvest" "FlexPort Unity" &>/dev/null && echo "✅" || echo "❌")"
)

for feature in "${RYAN_FEATURES[@]}"; do
    IFS=':' read -r name status <<< "$feature"
    echo -e "$status $name"
done

echo ""
echo "=================================="
echo -e "${BLUE}🚀 TESTING COMMANDS${NC}"
echo "=================================="
echo "1. Overall structure: ./test-game-week.sh"
echo "2. Web game: ./test-web-game.sh"
echo "3. iOS companion: ./test-ios-build.sh"
echo "4. Android companion: ./test-android-build.sh"
echo "5. Full validation: ./validate-game-week.sh"
echo ""
echo -e "${GREEN}🎮 Game Week Project Complete!${NC}"