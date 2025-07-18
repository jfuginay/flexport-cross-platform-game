#!/bin/bash

# Run UI improvements using Claude Task Master
echo "Starting parallel UI improvements for FlexPort 3D game..."
echo "This will spawn 3 Claude instances working on:"
echo "1. Mini-map and Route Visualization"
echo "2. Visual Effects (Ship Trails, Weather, Day/Night)"
echo "3. Advanced UI Overlay and Dashboard"
echo ""

# Navigate to task master directory
cd /Users/jfuginay/Documents/dev/FlexPort/flexport-3d/claude-task-master

# Run the task master with our configuration
npx task-master run ../flexport-ui-tasks.json

echo ""
echo "Tasks completed! Check flexport-ui-improvements-results.md for details."