#!/bin/bash

# Terminal Output Capture for Claude Instances
# Captures stdout/stderr from Claude processes and saves to log files

FLEXPORT_DIR="/Users/jfuginay/Documents/dev/Flexport"
LOGS_DIR="$FLEXPORT_DIR/terminal_logs"
mkdir -p "$LOGS_DIR"

# Claude process IDs (will be detected dynamically)
CLAUDE_PIDS=($(ps aux | grep "claude" | grep -v grep | awk '{print $2}'))

echo "Found ${#CLAUDE_PIDS[@]} Claude processes: ${CLAUDE_PIDS[*]}"

# Function to capture process output
capture_output() {
    local pid=$1
    local log_file="$LOGS_DIR/claude_${pid}.log"
    local working_dir=""
    
    # Get the working directory of the process
    if [ -d "/proc/$pid/cwd" ]; then
        working_dir=$(readlink /proc/$pid/cwd 2>/dev/null || echo "unknown")
    else
        working_dir=$(lsof -p $pid | grep cwd | awk '{print $NF}' 2>/dev/null || echo "unknown")
    fi
    
    echo "$(date): Monitoring Claude PID $pid (working dir: $working_dir)" > "$log_file"
    echo "=======================================================" >> "$log_file"
    
    # Try to attach to the process and capture output
    if command -v strace >/dev/null 2>&1; then
        # Linux method with strace
        strace -p $pid -e write -s 1000 2>&1 | while read line; do
            echo "$(date '+%H:%M:%S'): $line" >> "$log_file"
        done &
    elif command -v dtruss >/dev/null 2>&1; then
        # macOS method with dtruss (requires sudo)
        sudo dtruss -p $pid 2>&1 | grep -E "(write|printf)" | while read line; do
            echo "$(date '+%H:%M:%S'): $line" >> "$log_file"
        done &
    else
        # Fallback: monitor file system changes in Claude's working directory
        if [ "$working_dir" != "unknown" ] && [ -d "$working_dir" ]; then
            echo "$(date '+%H:%M:%S'): Monitoring file changes in $working_dir" >> "$log_file"
            
            # Use fswatch if available
            if command -v fswatch >/dev/null 2>&1; then
                fswatch -r "$working_dir" | while read file; do
                    echo "$(date '+%H:%M:%S'): File changed: $file" >> "$log_file"
                done &
            fi
        fi
        
        # Monitor process status
        while kill -0 $pid 2>/dev/null; do
            echo "$(date '+%H:%M:%S'): Claude $pid still running" >> "$log_file"
            sleep 30
        done &
    fi
}

# Function to monitor Claude command output through terminal history
monitor_terminal_history() {
    local log_file="$LOGS_DIR/terminal_activity.log"
    echo "$(date): Starting terminal history monitoring" > "$log_file"
    
    # Monitor bash/zsh history files
    for hist_file in ~/.bash_history ~/.zsh_history; do
        if [ -f "$hist_file" ]; then
            tail -f "$hist_file" | while read line; do
                if [[ "$line" == *"claude"* ]] || [[ "$line" == *"git"* ]] || [[ "$line" == *"npm"* ]] || [[ "$line" == *"gradle"* ]]; then
                    echo "$(date '+%H:%M:%S'): Command: $line" >> "$log_file"
                fi
            done &
        fi
    done
}

# Function to capture git activity
monitor_git_activity() {
    local log_file="$LOGS_DIR/git_activity.log"
    echo "$(date): Starting git activity monitoring" > "$log_file"
    
    for project_dir in "$FLEXPORT_DIR/FlexPort iOS" "$FLEXPORT_DIR/FlexPort Android"; do
        if [ -d "$project_dir/.git" ]; then
            echo "Monitoring git in: $project_dir" >> "$log_file"
            
            # Watch git refs for commits
            fswatch "$project_dir/.git/refs" "$project_dir/.git/logs" 2>/dev/null | while read file; do
                echo "$(date '+%H:%M:%S'): Git activity in $project_dir: $file" >> "$log_file"
                
                # Get latest commit info
                cd "$project_dir"
                latest_commit=$(git log -1 --oneline 2>/dev/null || echo "No commits")
                echo "$(date '+%H:%M:%S'): Latest commit: $latest_commit" >> "$log_file"
            done &
        fi
    done
}

# Start monitoring
echo "Starting Claude terminal capture..."

# Capture output for each Claude process
for pid in "${CLAUDE_PIDS[@]}"; do
    echo "Starting capture for PID $pid"
    capture_output $pid
done

# Start additional monitoring
monitor_terminal_history
monitor_git_activity

# Keep script running
echo "Terminal capture started. Logs in: $LOGS_DIR"
echo "To stop, run: pkill -f terminal_capture.sh"

# Wait for all background processes
wait