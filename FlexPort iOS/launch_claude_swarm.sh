#!/bin/bash

# FlexPort iOS Claude Container Swarm Launcher
# This script launches 10 specialized Claude containers for advanced feature development

PROJECT_DIR="/Users/jfuginay/Documents/dev/FlexPort/FlexPort iOS"
PRD_FILE="$PROJECT_DIR/FlexPort_iOS_Advanced_Features_PRD.md"

echo "🚀 Launching FlexPort iOS Claude Container Swarm..."
echo "📁 Project Directory: $PROJECT_DIR"
echo "📋 PRD: $PRD_FILE"
echo ""

# Container definitions
declare -A CONTAINERS=(
    ["1"]="Metal Graphics Pipeline Master|Implement advanced Metal rendering with real-world geography, ocean shaders, weather systems"
    ["2"]="Sprite & Animation System|Create 50+ ship sprites, port visualizations, wake effects, damage states"
    ["3"]="Gesture & Camera Control|Implement pinch-zoom, pan, double-tap focus, 3D camera, minimap"
    ["4"]="ECS Architecture|Build high-performance ECS supporting 10k+ entities with spatial indexing"
    ["5"]="Multiplayer Networking|Create WebSocket multiplayer with prediction, lag compensation, matchmaking"
    ["6"]="Economic Simulation|Implement supply/demand for 100+ goods, dynamic pricing, futures markets"
    ["7"]="AI Singularity System|Build AI progression, neural net visualization, quantum computing upgrades"
    ["8"]="Audio & Haptics|Add procedural ocean sounds, dynamic music, spatial audio, haptic feedback"
    ["9"]="UI/UX Polish|Create glass morphism UI, AR mode, animated transitions, accessibility"
    ["10"]="Performance & Analytics|Optimize Metal shaders, implement memory pooling, analytics, A/B testing"
)

# Create progress tracking file
cat > "$PROJECT_DIR/PROGRESS.md" << EOF
# FlexPort iOS Development Progress

## Container Status
| Container | Role | Status | Last Update |
|-----------|------|--------|-------------|
EOF

# Launch containers
for i in {1..10}; do
    IFS='|' read -r ROLE TASK <<< "${CONTAINERS[$i]}"
    
    echo "🐳 Launching Container $i: $ROLE"
    
    # Add to progress file
    echo "| Container $i | $ROLE | Starting | $(date) |" >> "$PROJECT_DIR/PROGRESS.md"
    
    # Create container-specific instruction file
    cat > "$PROJECT_DIR/container_${i}_instructions.md" << EOF
# Container $i Instructions

## Role: $ROLE

## Primary Task
$TASK

## Key Requirements
1. Read the full PRD at: $PRD_FILE
2. Focus on your specific section (Container $i)
3. Create feature branch: claude-container-${i}-feature
4. Update PROGRESS.md every 30 minutes
5. Coordinate with other containers through PROGRESS.md
6. Ensure all code follows existing patterns
7. Test thoroughly before committing
8. Handle merge conflicts collaboratively

## Dependencies
- Check PROGRESS.md for status of dependent containers
- Wait for dependencies before starting if needed
- Communicate blockers immediately

## Output Location
- Follow the directory structure specified in PRD
- Commit frequently with clear messages
- Tag important milestones

## Success Criteria
- Feature fully implemented per PRD specs
- All tests passing
- Performance targets met
- Integrated with other container outputs
EOF

    # Launch the container
    docker run -d \
        --name flexport-claude-$i \
        --mount type=bind,source="$PROJECT_DIR",target=/workspace \
        -e CONTAINER_ID=$i \
        -e CONTAINER_ROLE="$ROLE" \
        -e TASK_DESCRIPTION="$TASK" \
        -e INSTRUCTION_FILE="/workspace/container_${i}_instructions.md" \
        -e PROGRESS_FILE="/workspace/PROGRESS.md" \
        -e PRD_FILE="/workspace/FlexPort_iOS_Advanced_Features_PRD.md" \
        -w /workspace \
        anthropic/claude-code:latest \
        /bin/bash -c "echo 'Container $i: $ROLE started' && tail -f /dev/null"
    
    echo "✅ Container $i launched"
    echo ""
    
    # Small delay between launches
    sleep 2
done

echo "🎯 All containers launched!"
echo ""
echo "📊 Monitor progress:"
echo "   watch -n 30 'cat \"$PROJECT_DIR/PROGRESS.md\"'"
echo ""
echo "📝 View container logs:"
echo "   docker logs -f flexport-claude-[1-10]"
echo ""
echo "🛑 Stop all containers:"
echo "   docker stop \$(docker ps -q --filter name=flexport-claude)"
echo ""
echo "🗑️  Remove all containers:"
echo "   docker rm \$(docker ps -aq --filter name=flexport-claude)"
echo ""
echo "Happy coding! 🚢"