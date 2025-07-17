import { GameEngine } from '@/core/GameEngine';
import { GameConfig } from '@/types';
import '@/utils/ProgressionDemo';

const gameConfig: GameConfig = {
  targetFPS: 60,
  maxShips: 100,
  startingCash: 1000000,
  difficultyLevel: 1,
  mapBounds: {
    minLat: -60,
    maxLat: 80,
    minLng: -180,
    maxLng: 180,
  },
};

async function initializeGame(): Promise<void> {
  try {
    // Get the canvas container
    const canvasContainer = document.getElementById('game-canvas');
    if (!canvasContainer) {
      throw new Error('Game canvas container not found');
    }

    // Create and initialize the game engine
    console.log('🚢 Initializing Flexport: The Video Game...');
    const gameEngine = new GameEngine(canvasContainer, gameConfig);
    
    // Wait for the game engine to finish initializing
    await gameEngine.waitForInitialization();
    
    // Attempt to load saved game
    const gameLoaded = gameEngine.loadGame();
    if (gameLoaded) {
      console.log('📁 Saved game loaded successfully');
    } else {
      console.log('🆕 Starting new game');
    }

    // Start the game loop
    gameEngine.start();
    console.log('🎮 Game started successfully!');

    // Set up periodic save
    setInterval(() => {
      gameEngine.saveGame();
    }, 30000); // Save every 30 seconds

    // Make game engine globally accessible for debugging
    (window as any).gameEngine = gameEngine;

    // Set up CSS styles dynamically
    setupGameStyles();

    // Show welcome message
    showWelcomeMessage();

  } catch (error) {
    console.error('Failed to initialize game:', error);
    showErrorMessage('Failed to initialize game. Please refresh the page.');
  }
}

function setupGameStyles(): void {
  const style = document.createElement('style');
  style.textContent = `
    .btn {
      padding: 8px 16px;
      background: linear-gradient(135deg, #3b82f6, #1d4ed8);
      border: none;
      border-radius: 6px;
      color: white;
      cursor: pointer;
      font-size: 14px;
      font-weight: 500;
      transition: all 0.2s ease;
      font-family: inherit;
    }
    
    .btn:hover {
      background: linear-gradient(135deg, #2563eb, #1e40af);
      transform: translateY(-1px);
      box-shadow: 0 4px 12px rgba(59, 130, 246, 0.4);
    }
    
    .btn:active {
      transform: translateY(0);
    }
    
    .btn-primary {
      background: linear-gradient(135deg, #3b82f6, #1d4ed8);
    }
    
    .btn-secondary {
      background: linear-gradient(135deg, #6b7280, #374151);
    }
    
    .btn-secondary:hover {
      background: linear-gradient(135deg, #4b5563, #1f2937);
    }
    
    .ui-panel {
      backdrop-filter: blur(10px);
      -webkit-backdrop-filter: blur(10px);
    }
    
    /* Scrollbar styling */
    .ui-panel *::-webkit-scrollbar {
      width: 6px;
    }
    
    .ui-panel *::-webkit-scrollbar-track {
      background: rgba(59, 130, 246, 0.1);
      border-radius: 3px;
    }
    
    .ui-panel *::-webkit-scrollbar-thumb {
      background: rgba(59, 130, 246, 0.5);
      border-radius: 3px;
    }
    
    .ui-panel *::-webkit-scrollbar-thumb:hover {
      background: rgba(59, 130, 246, 0.7);
    }
    
    /* Animation for UI panels */
    .ui-panel {
      animation: slideIn 0.3s ease-out;
    }
    
    @keyframes slideIn {
      from {
        opacity: 0;
        transform: translateY(-10px);
      }
      to {
        opacity: 1;
        transform: translateY(0);
      }
    }
    
    /* Mobile responsive adjustments */
    @media (max-width: 768px) {
      .ui-panel {
        max-width: 90vw !important;
        font-size: 14px;
      }
      
      .btn {
        padding: 6px 12px;
        font-size: 12px;
      }
    }
    
    /* High DPI display optimizations */
    @media (-webkit-min-device-pixel-ratio: 2), (min-resolution: 192dpi) {
      .ui-panel {
        border-width: 0.5px;
      }
    }
  `;
  document.head.appendChild(style);
}

function showWelcomeMessage(): void {
  const welcome = document.createElement('div');
  welcome.style.cssText = `
    position: fixed;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    background: linear-gradient(135deg, rgba(15, 23, 42, 0.98), rgba(30, 41, 59, 0.98));
    backdrop-filter: blur(15px);
    border: 2px solid rgba(59, 130, 246, 0.5);
    border-radius: 20px;
    padding: 40px;
    color: white;
    text-align: center;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    box-shadow: 0 25px 50px rgba(0, 0, 0, 0.5);
    z-index: 10000;
    max-width: 600px;
    animation: welcomeSlideIn 0.6s ease-out;
  `;

  welcome.innerHTML = `
    <div style="font-size: 48px; margin-bottom: 20px;">🚢</div>
    <h1 style="margin: 0 0 16px 0; font-size: 28px; background: linear-gradient(135deg, #3b82f6, #8b5cf6); -webkit-background-clip: text; -webkit-text-fill-color: transparent; background-clip: text;">
      Welcome to Flexport: The Video Game
    </h1>
    <p style="margin: 0 0 24px 0; font-size: 16px; line-height: 1.6; color: #cbd5e1;">
      Build your logistics empire in a world racing toward AI singularity. 
      Trade goods across global ports, manage your fleet, level up to unlock 
      new ships and features, and compete against increasingly intelligent AI systems.
    </p>
    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-bottom: 24px; font-size: 14px; text-align: left;">
      <div>
        <h3 style="margin: 0 0 8px 0; color: #3b82f6;">🎯 Your Mission</h3>
        <ul style="margin: 0; padding-left: 16px; color: #94a3b8; line-height: 1.5;">
          <li>Level up from 1 to 50</li>
          <li>Unlock new ship types</li>
          <li>Create profitable trade routes</li>
          <li>Navigate 4 interconnected markets</li>
          <li>Earn achievements</li>
          <li>Survive the AI singularity</li>
        </ul>
      </div>
      <div>
        <h3 style="margin: 0 0 8px 0; color: #f59e0b;">⚡ Quick Controls</h3>
        <ul style="margin: 0; padding-left: 16px; color: #94a3b8; line-height: 1.5;">
          <li>Drag to pan the map</li>
          <li>Scroll to zoom</li>
          <li>Click ports for details</li>
          <li>Press A for achievements</li>
          <li>Press H for help</li>
        </ul>
      </div>
    </div>
    <div style="display: flex; gap: 16px; justify-content: center;">
      <button id="start-game-btn" class="btn" style="font-size: 16px; padding: 12px 24px; background: linear-gradient(135deg, #10b981, #059669);">
        Start Solo Game
      </button>
      <button id="multiplayer-btn" class="btn" style="font-size: 16px; padding: 12px 24px; background: linear-gradient(135deg, #3b82f6, #1d4ed8);">
        Play Multiplayer
      </button>
    </div>
  `;

  const style = document.createElement('style');
  style.textContent = `
    @keyframes welcomeSlideIn {
      from {
        opacity: 0;
        transform: translate(-50%, -60%);
      }
      to {
        opacity: 1;
        transform: translate(-50%, -50%);
      }
    }
  `;
  document.head.appendChild(style);

  document.body.appendChild(welcome);

  // Add button functionality
  const startBtn = welcome.querySelector('#start-game-btn');
  if (startBtn) {
    startBtn.addEventListener('click', () => {
      console.log('Start game button clicked');
      welcome.style.animation = 'welcomeSlideIn 0.4s ease-out reverse';
      setTimeout(() => {
        welcome.remove();
        style.remove();
        // Ensure we start in single-player mode
        const gameEngine = (window as any).gameEngine;
        if (gameEngine) {
          // Make sure multiplayer lobby is hidden
          if (gameEngine.lobbyComponent && gameEngine.lobbyComponent.isShown()) {
            gameEngine.lobbyComponent.hide();
          }
          gameEngine.resume();
        }
      }, 400);
    });
  } else {
    console.error('Start game button not found');
  }

  welcome.querySelector('#multiplayer-btn')?.addEventListener('click', () => {
    welcome.style.animation = 'welcomeSlideIn 0.4s ease-out reverse';
    setTimeout(() => {
      welcome.remove();
      style.remove();
      // Open multiplayer lobby
      const gameEngine = (window as any).gameEngine;
      if (gameEngine) {
        gameEngine.toggleMultiplayerLobby();
      }
    }, 400);
  });

  // Auto-hide after 10 seconds and start single player
  setTimeout(() => {
    if (welcome.parentNode) {
      welcome.style.animation = 'welcomeSlideIn 0.4s ease-out reverse';
      setTimeout(() => {
        welcome.remove();
        style.remove();
        // Start single player mode automatically
        const gameEngine = (window as any).gameEngine;
        if (gameEngine) {
          if (gameEngine.lobbyComponent && gameEngine.lobbyComponent.isShown()) {
            gameEngine.lobbyComponent.hide();
          }
          gameEngine.resume();
        }
      }, 400);
    }
  }, 10000);
}

function showErrorMessage(message: string): void {
  const error = document.createElement('div');
  error.style.cssText = `
    position: fixed;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    background: linear-gradient(135deg, rgba(239, 68, 68, 0.95), rgba(185, 28, 28, 0.95));
    backdrop-filter: blur(10px);
    border: 2px solid rgba(239, 68, 68, 0.8);
    border-radius: 16px;
    padding: 24px;
    color: white;
    text-align: center;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    box-shadow: 0 20px 40px rgba(0, 0, 0, 0.5);
    z-index: 10000;
    max-width: 400px;
  `;

  error.innerHTML = `
    <div style="font-size: 48px; margin-bottom: 16px;">❌</div>
    <h2 style="margin: 0 0 16px 0; font-size: 20px;">Game Error</h2>
    <p style="margin: 0 0 20px 0; font-size: 14px; line-height: 1.5;">${message}</p>
    <button class="btn" onclick="window.location.reload()">Reload Page</button>
  `;

  document.body.appendChild(error);
}

// Initialize the game when the page loads
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initializeGame);
} else {
  initializeGame();
}

// Handle page visibility changes
document.addEventListener('visibilitychange', () => {
  const gameEngine = (window as any).gameEngine;
  if (gameEngine) {
    if (document.hidden) {
      gameEngine.pause();
    } else {
      gameEngine.resume();
    }
  }
});

// Global error handling
window.addEventListener('error', (event) => {
  console.error('Global error:', event.error);
  showErrorMessage('An unexpected error occurred. The game may not function properly.');
});

window.addEventListener('unhandledrejection', (event) => {
  console.error('Unhandled promise rejection:', event.reason);
  showErrorMessage('A network or loading error occurred. Please check your connection.');
});

// Performance monitoring
if ('performance' in window && 'mark' in window.performance) {
  window.performance.mark('game-init-start');
  
  window.addEventListener('load', () => {
    window.performance.mark('game-init-end');
    window.performance.measure('game-init', 'game-init-start', 'game-init-end');
    
    const measure = window.performance.getEntriesByName('game-init')[0];
    if (measure) {
      console.log(`🚀 Game initialization took ${measure.duration.toFixed(2)}ms`);
    }
  });
}

// Export for debugging
export { initializeGame };