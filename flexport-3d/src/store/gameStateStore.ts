import { create } from 'zustand';
import { devtools } from 'zustand/middleware';

export enum GameState {
  LOADING = 'LOADING',
  TITLE = 'TITLE',
  MENU = 'MENU',
  LOBBY = 'LOBBY',
  MULTIPLAYER_LOBBY = 'MULTIPLAYER_LOBBY',
  GAME_SETUP = 'GAME_SETUP',
  PLAYING = 'PLAYING',
  PAUSED = 'PAUSED',
  GAME_OVER = 'GAME_OVER'
}

interface LoadingProgress {
  progress: number;
  currentTask: string;
  estimatedTime: number;
}

interface GameStateStore {
  // Current game state
  currentState: GameState;
  previousState: GameState | null;
  
  // Loading state
  loadingProgress: LoadingProgress;
  
  // Game settings
  settings: {
    musicVolume: number;
    sfxVolume: number;
    graphicsQuality: 'low' | 'medium' | 'high' | 'ultra';
    showTutorial: boolean;
    newsTickerEnabled: boolean;
  };
  
  // State transitions
  setGameState: (state: GameState) => void;
  updateLoadingProgress: (progress: Partial<LoadingProgress>) => void;
  updateSettings: (settings: Partial<GameStateStore['settings']>) => void;
  
  // Initialize game
  initializeGame: () => Promise<void>;
}

export const useGameStateStore = create<GameStateStore>()(
  devtools(
    (set, get) => ({
      currentState: GameState.LOADING,
      previousState: null,
      
      loadingProgress: {
        progress: 0,
        currentTask: 'Initializing...',
        estimatedTime: 30
      },
      
      settings: {
        musicVolume: 0.7,
        sfxVolume: 0.8,
        graphicsQuality: 'high',
        showTutorial: true,
        newsTickerEnabled: true
      },
      
      setGameState: (state) => {
        const current = get().currentState;
        set({ 
          currentState: state, 
          previousState: current 
        });
      },
      
      updateLoadingProgress: (progress) => {
        set((state) => ({
          loadingProgress: {
            ...state.loadingProgress,
            ...progress
          }
        }));
      },
      
      updateSettings: (settings) => {
        set((state) => ({
          settings: {
            ...state.settings,
            ...settings
          }
        }));
      },
      
      initializeGame: async () => {
        const steps = [
          { task: 'Loading 3D models...', weight: 20 },
          { task: 'Initializing world data...', weight: 15 },
          { task: 'Setting up AI systems...', weight: 20 },
          { task: 'Loading textures...', weight: 15 },
          { task: 'Preparing audio...', weight: 10 },
          { task: 'Generating ocean...', weight: 10 },
          { task: 'Finalizing...', weight: 10 }
        ];
        
        let totalProgress = 0;
        
        for (const step of steps) {
          set((state) => ({
            loadingProgress: {
              ...state.loadingProgress,
              currentTask: step.task,
              progress: totalProgress
            }
          }));
          
          // Simulate loading time
          await new Promise(resolve => setTimeout(resolve, Math.random() * 1000 + 500));
          
          totalProgress += step.weight;
        }
        
        set((state) => ({
          loadingProgress: {
            ...state.loadingProgress,
            progress: 100,
            currentTask: 'Ready!'
          }
        }));
        
        // Transition to title screen after a brief pause
        setTimeout(() => {
          get().setGameState(GameState.TITLE);
        }, 1000);
      }
    }),
    {
      name: 'game-state-store'
    }
  )
);