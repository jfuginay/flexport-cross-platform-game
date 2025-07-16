#!/usr/bin/env python3
"""
FlexPort Claude Progress Dashboard
A simple web-based dashboard accessible via SSH tunnel for monitoring Claude progress
"""

import os
import subprocess
import json
import time
from datetime import datetime
from http.server import HTTPServer, BaseHTTPRequestHandler
import threading

FLEXPORT_DIR = "/Users/jfuginay/Documents/dev/Flexport"
IOS_DIR = f"{FLEXPORT_DIR}/FlexPort iOS"
ANDROID_DIR = f"{FLEXPORT_DIR}/FlexPort Android"
LOGS_DIR = f"{FLEXPORT_DIR}/terminal_logs"

def get_terminal_logs():
    """Get recent terminal logs from Claude instances"""
    logs = {}
    
    if os.path.exists(LOGS_DIR):
        for log_file in os.listdir(LOGS_DIR):
            if log_file.endswith('.log'):
                log_path = os.path.join(LOGS_DIR, log_file)
                try:
                    # Get last 50 lines of each log
                    with open(log_path, 'r') as f:
                        lines = f.readlines()
                        logs[log_file] = lines[-50:] if len(lines) > 50 else lines
                except Exception as e:
                    logs[log_file] = [f"Error reading log: {str(e)}"]
    
    return logs

def get_project_stats():
    """Get current project statistics"""
    stats = {
        "timestamp": datetime.now().isoformat(),
        "ios": {},
        "android": {},
        "system": {},
        "terminal_logs": get_terminal_logs()
    }
    
    # iOS stats
    try:
        ios_swift_count = len([f for f in os.listdir(IOS_DIR) if f.endswith('.swift')])
        stats["ios"]["swift_files"] = ios_swift_count
        stats["ios"]["last_modified"] = get_last_modified(IOS_DIR, ['.swift'])
        stats["ios"]["git_status"] = get_git_info(IOS_DIR)
    except Exception as e:
        stats["ios"]["error"] = str(e)
    
    # Android stats
    try:
        android_kt_count = len([f for f in os.listdir(ANDROID_DIR) if f.endswith('.kt')])
        android_java_count = len([f for f in os.listdir(ANDROID_DIR) if f.endswith('.java')])
        stats["android"]["kotlin_files"] = android_kt_count
        stats["android"]["java_files"] = android_java_count
        stats["android"]["last_modified"] = get_last_modified(ANDROID_DIR, ['.kt', '.java'])
        stats["android"]["git_status"] = get_git_info(ANDROID_DIR)
    except Exception as e:
        stats["android"]["error"] = str(e)
    
    # System stats
    try:
        result = subprocess.run(['ps', 'aux'], capture_output=True, text=True)
        claude_processes = [line for line in result.stdout.split('\n') if 'claude' in line.lower()]
        stats["system"]["claude_processes"] = len(claude_processes)
        stats["system"]["load_avg"] = os.getloadavg()
    except Exception as e:
        stats["system"]["error"] = str(e)
    
    return stats

def get_last_modified(directory, extensions):
    """Get the most recently modified file with given extensions"""
    try:
        latest_time = 0
        latest_file = None
        
        for root, dirs, files in os.walk(directory):
            for file in files:
                if any(file.endswith(ext) for ext in extensions):
                    filepath = os.path.join(root, file)
                    mtime = os.path.getmtime(filepath)
                    if mtime > latest_time:
                        latest_time = mtime
                        latest_file = filepath
        
        if latest_file:
            return {
                "file": latest_file.replace(directory, ""),
                "time": datetime.fromtimestamp(latest_time).isoformat()
            }
    except Exception:
        pass
    return None

def get_git_info(directory):
    """Get git information for a directory"""
    try:
        if os.path.exists(os.path.join(directory, '.git')):
            # Get current branch
            result = subprocess.run(['git', '-C', directory, 'branch', '--show-current'], 
                                  capture_output=True, text=True)
            branch = result.stdout.strip() if result.returncode == 0 else "unknown"
            
            # Get status
            result = subprocess.run(['git', '-C', directory, 'status', '--porcelain'], 
                                  capture_output=True, text=True)
            changes = len(result.stdout.strip().split('\n')) if result.stdout.strip() else 0
            
            # Get last commit
            result = subprocess.run(['git', '-C', directory, 'log', '-1', '--oneline'], 
                                  capture_output=True, text=True)
            last_commit = result.stdout.strip() if result.returncode == 0 else "No commits"
            
            return {
                "branch": branch,
                "uncommitted_changes": changes,
                "last_commit": last_commit
            }
    except Exception:
        pass
    return {"status": "No git repository"}

class DashboardHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.serve_dashboard()
        elif self.path == '/api/stats':
            self.serve_stats()
        elif self.path == '/api/logs':
            self.serve_logs()
        elif self.path == '/api/terminal':
            self.serve_terminal_logs()
        else:
            self.send_error(404)
    
    def serve_dashboard(self):
        html = """
<!DOCTYPE html>
<html>
<head>
    <title>FlexPort Claude Monitor</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { font-family: monospace; margin: 20px; background: #1a1a1a; color: #00ff00; }
        .container { max-width: 1200px; margin: 0 auto; }
        .project { border: 1px solid #00ff00; margin: 20px 0; padding: 15px; border-radius: 5px; }
        .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 10px; }
        .stat { background: #2a2a2a; padding: 10px; border-radius: 3px; }
        .error { color: #ff4444; }
        .timestamp { color: #ffff00; }
        h1, h2 { color: #00ffff; }
        h3 { color: #ffaa00; font-size: 1em; margin: 10px 0 5px 0; }
        .refresh-btn { background: #00ff00; color: #000; border: none; padding: 10px 20px; cursor: pointer; }
        .status { font-size: 0.9em; color: #888; }
        .terminal-log { background: #1a1a1a; margin: 10px 0; padding: 10px; border-radius: 5px; border: 1px solid #333; }
        .log-content { max-height: 300px; overflow-y: auto; font-family: 'Courier New', monospace; font-size: 0.8em; }
        .log-line { padding: 2px 0; color: #ddd; white-space: pre-wrap; word-wrap: break-word; }
        .log-line:nth-child(even) { background: #222; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚢 FlexPort Claude Development Monitor</h1>
        <button class="refresh-btn" onclick="loadStats()">Refresh</button>
        <div id="last-update" class="timestamp"></div>
        
        <div id="content">
            <p>Loading...</p>
        </div>
    </div>

    <script>
        function escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }
        
        function loadStats() {
            fetch('/api/stats')
                .then(response => response.json())
                .then(data => {
                    document.getElementById('last-update').textContent = 
                        'Last updated: ' + new Date(data.timestamp).toLocaleString();
                    
                    let html = '';
                    
                    // iOS Project
                    html += '<div class="project">';
                    html += '<h2>📱 iOS Project</h2>';
                    html += '<div class="stats">';
                    if (data.ios.error) {
                        html += '<div class="stat error">Error: ' + data.ios.error + '</div>';
                    } else {
                        html += '<div class="stat">Swift Files: ' + (data.ios.swift_files || 0) + '</div>';
                        if (data.ios.last_modified) {
                            html += '<div class="stat">Last Modified: ' + data.ios.last_modified.file + '<br>' + 
                                   new Date(data.ios.last_modified.time).toLocaleString() + '</div>';
                        }
                        if (data.ios.git_status) {
                            html += '<div class="stat">Git: ' + data.ios.git_status.branch + 
                                   ' (' + data.ios.git_status.uncommitted_changes + ' changes)</div>';
                        }
                    }
                    html += '</div></div>';
                    
                    // Android Project
                    html += '<div class="project">';
                    html += '<h2>🤖 Android Project</h2>';
                    html += '<div class="stats">';
                    if (data.android.error) {
                        html += '<div class="stat error">Error: ' + data.android.error + '</div>';
                    } else {
                        html += '<div class="stat">Kotlin Files: ' + (data.android.kotlin_files || 0) + '</div>';
                        html += '<div class="stat">Java Files: ' + (data.android.java_files || 0) + '</div>';
                        if (data.android.last_modified) {
                            html += '<div class="stat">Last Modified: ' + data.android.last_modified.file + '<br>' + 
                                   new Date(data.android.last_modified.time).toLocaleString() + '</div>';
                        }
                        if (data.android.git_status) {
                            html += '<div class="stat">Git: ' + data.android.git_status.branch + 
                                   ' (' + data.android.git_status.uncommitted_changes + ' changes)</div>';
                        }
                    }
                    html += '</div></div>';
                    
                    // System Status
                    html += '<div class="project">';
                    html += '<h2>💻 System Status</h2>';
                    html += '<div class="stats">';
                    if (data.system.error) {
                        html += '<div class="stat error">Error: ' + data.system.error + '</div>';
                    } else {
                        html += '<div class="stat">Claude Processes: ' + (data.system.claude_processes || 0) + '</div>';
                        if (data.system.load_avg) {
                            html += '<div class="stat">Load Average: ' + data.system.load_avg.map(x => x.toFixed(2)).join(', ') + '</div>';
                        }
                    }
                    html += '</div></div>';
                    
                    // Terminal Logs
                    html += '<div class="project">';
                    html += '<h2>📟 Live Terminal Output</h2>';
                    if (data.terminal_logs && Object.keys(data.terminal_logs).length > 0) {
                        for (const [logFile, lines] of Object.entries(data.terminal_logs)) {
                            html += '<div class="terminal-log">';
                            html += '<h3>' + logFile + '</h3>';
                            html += '<div class="log-content">';
                            if (Array.isArray(lines)) {
                                lines.slice(-20).forEach(line => {
                                    html += '<div class="log-line">' + escapeHtml(line.trim()) + '</div>';
                                });
                            } else {
                                html += '<div class="log-line error">' + escapeHtml(lines) + '</div>';
                            }
                            html += '</div></div>';
                        }
                    } else {
                        html += '<div class="stat">No terminal logs available yet...</div>';
                    }
                    html += '</div>';
                    
                    document.getElementById('content').innerHTML = html;
                })
                .catch(error => {
                    document.getElementById('content').innerHTML = '<div class="error">Error loading data: ' + error + '</div>';
                });
        }
        
        // Auto-refresh every 30 seconds
        setInterval(loadStats, 30000);
        loadStats();
    </script>
</body>
</html>
        """
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        self.wfile.write(html.encode())
    
    def serve_stats(self):
        stats = get_project_stats()
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(stats).encode())
    
    def serve_logs(self):
        # Placeholder for logs endpoint
        logs = {"logs": "Log functionality coming soon"}
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(logs).encode())
    
    def serve_terminal_logs(self):
        terminal_logs = get_terminal_logs()
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(terminal_logs).encode())

def run_server(port=8080):
    server = HTTPServer(('localhost', port), DashboardHandler)
    print(f"Dashboard running on http://localhost:{port}")
    print(f"Access via SSH tunnel: ssh -L {port}:localhost:{port} username@your-mac-ip")
    server.serve_forever()

if __name__ == "__main__":
    run_server()