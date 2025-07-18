#!/bin/bash
# File: scripts/monitor-for-shortcuts.sh

echo "🔍 SHORTCUT DETECTION SYSTEM ACTIVE"
echo "Monitoring codebase for Game Week requirement violations..."

# Watch for file changes that might indicate shortcuts
monitor_file_changes() {
    inotifywait -m -r /workspace --format '%w%f %e' \
        --include '\.(cs|swift|kt|ts|js)$' 2>/dev/null | \
    while read file event; do
        if [ "$event" = "MODIFY" ] || [ "$event" = "CREATE" ]; then
            echo "📝 File changed: $file"
            
            # Check for simplification keywords in the file
            if grep -qi "TODO.*simple\|FIXME.*basic\|hack\|quick.*fix" "$file" 2>/dev/null; then
                echo "⚠️  SHORTCUT DETECTED in $file"
                echo "File contains simplification markers!"
            fi
            
            # Check for missing multiplayer components
            if grep -qi "SinglePlayer\|OfflineMode" "$file" 2>/dev/null; then
                echo "❌ MULTIPLAYER BYPASS DETECTED in $file"
            fi
            
            # Check for Ryan's economic system implementation
            if [[ "$file" == *"Economic"* ]] && ! grep -qi "FourMarket\|GoodsMarket\|CapitalMarket\|AssetMarket\|LaborMarket" "$file" 2>/dev/null; then
                echo "💰 INCOMPLETE ECONOMIC SYSTEM in $file"
            fi
            
            # Check for AI Singularity implementation
            if [[ "$file" == *"AI"* ]] && ! grep -qi "Singularity\|ZooEnding" "$file" 2>/dev/null; then
                echo "🤖 INCOMPLETE AI SINGULARITY in $file"
            fi
        fi
    done
}

# Monitor build processes for shortcuts
monitor_build_processes() {
    while true; do
        # Check if Unity is building with reduced quality settings
        if pgrep -f "Unity.*-buildTarget.*-quality.*low" > /dev/null; then
            echo "⚡ BUILD QUALITY SHORTCUT DETECTED"
            echo "Unity building with reduced quality settings!"
        fi
        
        # Check for fast build flags that might compromise Game Week standards
        if pgrep -f "Unity.*-development.*-fast" > /dev/null; then
            echo "🚀 DEVELOPMENT BUILD SHORTCUT DETECTED"
        fi
        
        sleep 10
    done
}

# Start monitoring processes
monitor_file_changes &
monitor_build_processes &

echo "Shortcut detection system initialized..."
wait