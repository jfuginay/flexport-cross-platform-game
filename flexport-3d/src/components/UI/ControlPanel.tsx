// @ts-nocheck
import React, { useState } from 'react';
import { useGameStore } from '../../store/gameStore';
import './ControlPanel.css';

interface ControlPanelProps {
  isEarthRotating: boolean;
  onToggleRotation: () => void;
  gameSpeed: number;
  onSpeedChange: (speed: number) => void;
}

export const ControlPanel: React.FC<ControlPanelProps> = ({
  isEarthRotating,
  onToggleRotation,
  gameSpeed,
  onSpeedChange
}) => {
  const { isPaused, pauseGame, resumeGame } = useGameStore();
  const [isCollapsed, setIsCollapsed] = useState(false);

  return (
    <div className={`control-panel ${isCollapsed ? 'collapsed' : ''}`}>
      <div className="panel-header">
        <h3>Game Controls</h3>
        <button 
          className="collapse-button"
          onClick={() => setIsCollapsed(!isCollapsed)}
          title={isCollapsed ? 'Expand' : 'Collapse'}
        >
          {isCollapsed ? '▶' : '◀'}
        </button>
      </div>
      
      {!isCollapsed && (
        <>
          <div className="control-section">
        
        <div className="control-item">
          <label>Game Speed</label>
          <div className="speed-controls">
            <button 
              className={gameSpeed === 0.5 ? 'active' : ''}
              onClick={() => onSpeedChange(0.5)}
              title="Half speed"
            >
              0.5x
            </button>
            <button 
              className={gameSpeed === 1 ? 'active' : ''}
              onClick={() => onSpeedChange(1)}
              title="Normal speed"
            >
              1x
            </button>
            <button 
              className={gameSpeed === 2 ? 'active' : ''}
              onClick={() => onSpeedChange(2)}
              title="Double speed"
            >
              2x
            </button>
            <button 
              className={gameSpeed === 5 ? 'active' : ''}
              onClick={() => onSpeedChange(5)}
              title="Fast forward"
            >
              5x
            </button>
          </div>
        </div>

        <div className="control-item">
          <button 
            className="pause-button"
            onClick={isPaused ? resumeGame : pauseGame}
          >
            {isPaused ? '▶️ Resume' : '⏸️ Pause'}
          </button>
        </div>
      </div>

      <div className="control-section">
        <h3>View Options</h3>
        
        <div className="control-item">
          <label className="toggle-label">
            <input 
              type="checkbox" 
              checked={isEarthRotating}
              onChange={onToggleRotation}
            />
            <span className="toggle-slider"></span>
            <span className="toggle-text">Earth Rotation</span>
          </label>
        </div>

        <div className="control-tip">
          <p>🌍 Earth rotates in sync with game time</p>
          <p>🖱️ Left click + drag to orbit</p>
          <p>🔍 Scroll to zoom</p>
        </div>
      </div>

      <div className="control-section">
        <h3>Keyboard Shortcuts</h3>
        <div className="shortcuts">
          <div><kbd>Space</kbd> Pause/Resume</div>
          <div><kbd>1-5</kbd> Change Speed</div>
          <div><kbd>R</kbd> Toggle Rotation</div>
          <div><kbd>ESC</kbd> Deselect</div>
        </div>
      </div>
        </>
      )}
    </div>
  );
};