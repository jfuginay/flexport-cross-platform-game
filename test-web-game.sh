#!/bin/bash

echo "🌐 TESTING WEB GAME DEPLOYMENT"
echo "=============================="

cd Web

# Check if Node.js is available
if ! command -v node &> /dev/null; then
    echo "❌ Node.js not found. Please install Node.js first."
    exit 1
fi

# Check if npm is available
if ! command -v npm &> /dev/null; then
    echo "❌ npm not found. Please install npm first."
    exit 1
fi

echo "✅ Node.js version: $(node --version)"
echo "✅ npm version: $(npm --version)"

# Install dependencies
echo ""
echo "📦 Installing dependencies..."
npm install

if [ $? -eq 0 ]; then
    echo "✅ Dependencies installed successfully"
else
    echo "❌ Failed to install dependencies"
    exit 1
fi

# Build the project
echo ""
echo "🔨 Building project..."
npm run build

if [ $? -eq 0 ]; then
    echo "✅ Build completed successfully"
else
    echo "❌ Build failed"
    echo ""
    echo "🔍 Common fixes:"
    echo "1. Check TypeScript errors in console"
    echo "2. Verify all imports are correct"
    echo "3. Run 'npm run dev' for development mode"
    exit 1
fi

# Start development server
echo ""
echo "🚀 Starting development server..."
echo "💡 Game will be available at: http://localhost:5173"
echo "💡 Press Ctrl+C to stop"
echo ""
echo "🎮 GAME FEATURES TO TEST:"
echo "========================"
echo "1. ✅ Multiplayer lobby (click 'Play Multiplayer')"
echo "2. ✅ Trade route mechanics"
echo "3. ✅ AI Singularity progression"
echo "4. ✅ Zoo ending (when AI reaches 100%)"
echo "5. ✅ Four market system integration"
echo "6. ✅ Cross-platform companion app sync"
echo ""

# Start the dev server
npm run dev