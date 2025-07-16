#!/bin/bash

# FlexPort iOS Enhancement Container Launcher
# Spins up 5 Claude containers to enhance map and gameplay

PROJECT_DIR="/Users/jfuginay/Documents/dev/FlexPort/FlexPort iOS"
PRD_FILE="$PROJECT_DIR/FlexPort_Map_Enhancement_PRD.md"

echo "🚀 Launching FlexPort iOS Enhancement Container Swarm..."
echo "📁 Project Directory: $PROJECT_DIR"
echo "📋 PRD: $PRD_FILE"
echo ""

# Create enhancement progress tracking file
cat > "$PROJECT_DIR/ENHANCEMENT_PROGRESS.md" << EOF
# FlexPort iOS Enhancement Progress

## Container Status
| Container | Task | Status | Progress | Last Update |
|-----------|------|--------|----------|-------------|
| Container 1 | Advanced Metal Map Renderer | Starting | 0% | $(date) |
| Container 2 | Ship AI & Movement System | Starting | 0% | $(date) |
| Container 3 | Advanced Economic Engine | Starting | 0% | $(date) |
| Container 4 | UI/UX Enhancement & Interactions | Starting | 0% | $(date) |
| Container 5 | Game Progression & Content | Starting | 0% | $(date) |

## Current App State
- ✅ BasicWorldMapView working with 7 ports
- ✅ Ship purchasing and trade routes functional
- ✅ Build system working, app running in simulator
- 🔄 Ready for enhancement by container swarm

## Enhancement Targets
- 🎯 Realistic Earth geography with Metal rendering
- 🎯 Animated ship movement with AI pathfinding
- 🎯 Deep economic simulation with 20+ goods
- 🎯 Polished UI with glass morphism design
- 🎯 Game progression with research tree
EOF

# Container definitions
declare -A CONTAINERS=(
    ["1"]="Advanced Metal Map Renderer|Transform basic ocean view into realistic world map with Metal rendering"
    ["2"]="Ship AI & Movement System|Bring ships to life with intelligent movement and pathfinding"
    ["3"]="Advanced Economic Engine|Create sophisticated market simulation with supply/demand"
    ["4"]="UI/UX Enhancement & Interactions|Polish interface with glass morphism and advanced interactions"
    ["5"]="Game Progression & Content|Add depth with research tree and progression systems"
)

# Launch containers
for i in {1..5}; do
    IFS='|' read -r TASK DESCRIPTION <<< "${CONTAINERS[$i]}"
    
    echo "🐳 Launching Container $i: $TASK"
    
    # Create container-specific instruction file
    cat > "$PROJECT_DIR/container_${i}_enhancement_instructions.md" << EOF
# Container $i Enhancement Instructions

## Task: $TASK

## Description
$DESCRIPTION

## Current Working State
- BasicWorldMapView at: Sources/FlexPort/UI/GameView.swift (lines 445-528)
- Ship models at: Sources/FlexPort/Core/GameManager.swift (lines 84-99)
- Trade route creation working in BasicPortDetailsView
- App successfully builds and runs in simulator

## Your Mission
1. Analyze current working code
2. Enhance/replace with advanced implementation
3. Test in simulator before committing
4. Update ENHANCEMENT_PROGRESS.md every 20 minutes
5. Create feature branch: enhancement-container-${i}
6. Coordinate with other containers through progress file

## Key Requirements
- Maintain compatibility with existing working systems
- Test thoroughly in iOS simulator
- Follow iOS development best practices
- Update progress regularly
- Handle any merge conflicts collaboratively

## Files to Focus On
- Container 1: Sources/FlexPort/UI/Metal/* and GameView.swift
- Container 2: Sources/FlexPort/Core/GameManager.swift and new AI systems
- Container 3: Sources/FlexPort/Core/Economics/* (create new)
- Container 4: Sources/FlexPort/UI/* (enhance existing)
- Container 5: Sources/FlexPort/Game/* (create progression)

## Success Criteria
- Feature works in iOS simulator
- Integrates with existing working systems
- Performance maintained (60 FPS)
- Code follows Swift/iOS conventions
EOF

    # Launch the container with Claude
    docker run -d \
        --name flexport-enhancement-$i \
        -v "$PROJECT_DIR":/workspace \
        -e CONTAINER_ID=$i \
        -e CONTAINER_TASK="$TASK" \
        -e TASK_DESCRIPTION="$DESCRIPTION" \
        -e INSTRUCTION_FILE="/workspace/container_${i}_enhancement_instructions.md" \
        -e PROGRESS_FILE="/workspace/ENHANCEMENT_PROGRESS.md" \
        -e PRD_FILE="/workspace/FlexPort_Map_Enhancement_PRD.md" \
        -w /workspace \
        ubuntu:latest \
        /bin/bash -c "
            # Install dependencies
            apt-get update && apt-get install -y curl python3 python3-pip git nano
            
            # Install Claude CLI (simulated - would use actual Claude API)
            echo 'Container $i: $TASK started and ready for Claude commands'
            echo 'Working directory: /workspace'
            echo 'Current files:' && ls -la
            
            # Keep container running
            tail -f /dev/null
        "
    
    echo "✅ Container $i launched: $TASK"
    echo ""
    
    # Small delay between launches
    sleep 3
done

echo "🎯 All 5 enhancement containers launched!"
echo ""
echo "📊 Monitor progress:"
echo "   watch -n 30 'cat \"$PROJECT_DIR/ENHANCEMENT_PROGRESS.md\"'"
echo ""
echo "📝 View container logs:"
echo "   docker logs -f flexport-enhancement-[1-5]"
echo ""
echo "🔗 Connect to container:"
echo "   docker exec -it flexport-enhancement-1 /bin/bash"
echo ""
echo "🛑 Stop all containers:"
echo "   docker stop \$(docker ps -q --filter name=flexport-enhancement)"
echo ""
echo "🗑️  Remove all containers:"
echo "   docker rm \$(docker ps -aq --filter name=flexport-enhancement)"
echo ""
echo "Now use the Task tool to simulate Claude work in each container!"
echo "🚢 Ready to enhance FlexPort iOS!"