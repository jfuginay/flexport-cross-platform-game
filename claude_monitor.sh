#!/bin/bash

# Claude Progress Monitor for FlexPort iOS and Android Development
# Usage: ./claude_monitor.sh [watch|status|log]

FLEXPORT_DIR="/Users/jfuginay/Documents/dev/Flexport"
IOS_DIR="$FLEXPORT_DIR/FlexPort iOS"
ANDROID_DIR="$FLEXPORT_DIR/FlexPort Android"
LOG_FILE="/tmp/claude_monitor.log"

# Function to get git status if available
get_git_status() {
    local dir=$1
    if [ -d "$dir/.git" ]; then
        cd "$dir"
        echo "Git Status:"
        git status --porcelain | head -10
        echo "Recent commits:"
        git log --oneline -5
    else
        echo "No git repository found"
    fi
}

# Function to get recent file modifications
get_recent_changes() {
    local dir=$1
    echo "Recent file changes (last 2 hours):"
    find "$dir" -type f \( -name "*.swift" -o -name "*.kt" -o -name "*.java" \) -mtime -2h -exec ls -la {} \; 2>/dev/null | head -20
}

# Function to check for running processes
get_running_processes() {
    echo "Claude/Development processes:"
    ps aux | grep -E "(claude|xcode|gradle|swift)" | grep -v grep | head -10
}

# Function to get build status
get_build_status() {
    local project_type=$1
    local dir=$2
    
    echo "=== $project_type Build Status ==="
    if [ "$project_type" = "iOS" ]; then
        if [ -f "$dir/build.log" ]; then
            echo "Last build output:"
            tail -20 "$dir/build.log"
        fi
        # Check for Xcode project
        if [ -f "$dir"/*.xcodeproj/project.pbxproj ]; then
            echo "Xcode project found: $(basename "$dir"/*.xcodeproj)"
        fi
    elif [ "$project_type" = "Android" ]; then
        if [ -f "$dir/app/build.gradle.kts" ]; then
            echo "Gradle project found"
            if [ -f "$dir/app/build/outputs/logs/build.log" ]; then
                echo "Last build output:"
                tail -20 "$dir/app/build/outputs/logs/build.log"
            fi
        fi
    fi
}

# Function to display full status
show_status() {
    echo "$(date): FlexPort Development Monitor"
    echo "=========================================="
    
    echo ""
    echo "📱 iOS Project Status:"
    echo "----------------------"
    cd "$IOS_DIR"
    get_git_status "$IOS_DIR"
    echo ""
    get_recent_changes "$IOS_DIR"
    echo ""
    get_build_status "iOS" "$IOS_DIR"
    
    echo ""
    echo "🤖 Android Project Status:"
    echo "-------------------------"
    cd "$ANDROID_DIR"
    get_git_status "$ANDROID_DIR"
    echo ""
    get_recent_changes "$ANDROID_DIR"
    echo ""
    get_build_status "Android" "$ANDROID_DIR"
    
    echo ""
    echo "💻 System Status:"
    echo "----------------"
    get_running_processes
    
    echo ""
    echo "📊 Project Statistics:"
    echo "---------------------"
    echo "iOS Swift files: $(find "$IOS_DIR" -name "*.swift" | wc -l)"
    echo "Android Kotlin files: $(find "$ANDROID_DIR" -name "*.kt" | wc -l)"
    echo "Android Java files: $(find "$ANDROID_DIR" -name "*.java" | wc -l)"
}

# Function to watch continuously
watch_status() {
    while true; do
        clear
        show_status
        echo ""
        echo "Refreshing in 30 seconds... (Ctrl+C to stop)"
        sleep 30
    done
}

# Function to log status
log_status() {
    echo "$(date): Logging status to $LOG_FILE"
    show_status >> "$LOG_FILE"
    echo "Status logged. View with: tail -f $LOG_FILE"
}

# Main script logic
case "${1:-status}" in
    "watch")
        watch_status
        ;;
    "log")
        log_status
        ;;
    "status"|*)
        show_status
        ;;
esac