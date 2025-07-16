# FlexPort Claude Development Monitor

## Quick Start

### Command Line Monitoring
```bash
# View current status
cd ~/Documents/dev/Flexport
./claude_monitor.sh

# Watch continuously (updates every 30 seconds)
./claude_monitor.sh watch

# Log to file
./claude_monitor.sh log
```

### Web Dashboard (SSH Access)
```bash
# Start the dashboard server
python3 ssh_dashboard.py

# From your phone, create SSH tunnel:
ssh -L 8080:localhost:8080 your-username@your-mac-ip

# Then open browser to: http://localhost:8080
```

## What It Monitors

### iOS Project (`FlexPort iOS/`)
- Swift file count and recent changes
- Git status and recent commits
- Build status (if available)
- Last modified files

### Android Project (`FlexPort Android/`)
- Kotlin/Java file count and recent changes
- Git status and recent commits
- Gradle build status (if available)
- Last modified files

### System Status
- Running Claude processes
- System load average
- Development tool processes

## SSH Setup for Phone Access

1. Enable Remote Login on your Mac:
   ```bash
   sudo systemsetup -setremotelogin on
   ```

2. Find your Mac's IP address:
   ```bash
   ifconfig | grep "inet " | grep -v 127.0.0.1
   ```

3. From your phone's SSH app, connect with:
   ```
   ssh -L 8080:localhost:8080 your-username@your-mac-ip
   ```

4. Open browser to `http://localhost:8080`

## Dashboard Features

- Real-time project statistics
- Auto-refresh every 30 seconds
- Mobile-friendly terminal-style interface
- Git status monitoring
- File change tracking
- Process monitoring

The dashboard shows you exactly what both Claude instances are working on!