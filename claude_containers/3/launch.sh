#!/bin/bash
echo "🚀 Launching Claude Container 3"
echo "Task: $(head -1 claude_containers/3/task.md | sed 's/# //')"
echo "Working Directory: /Users/jfuginay/Documents/dev/FlexPort"
echo "Task File: $(pwd)/claude_containers/3/task.md"
echo ""
echo "📋 Task Details:"
cat claude_containers/3/task.md
echo ""
echo "🤖 Ready for Claude development..."
