import React from 'react';
import { Map, Globe3D } from 'lucide-react';
import './ViewToggle.css';

interface ViewToggleProps {
  currentView: '2D' | '3D';
  onViewChange: (view: '2D' | '3D') => void;
}

export const ViewToggle: React.FC<ViewToggleProps> = ({ currentView, onViewChange }) => {
  return (
    <div className="view-toggle-container">
      <button
        className={`view-toggle-btn ${currentView === '2D' ? 'active' : ''}`}
        onClick={() => onViewChange('2D')}
        title="2D Map View"
      >
        <Map size={20} />
        <span>2D</span>
      </button>
      <button
        className={`view-toggle-btn ${currentView === '3D' ? 'active' : ''}`}
        onClick={() => onViewChange('3D')}
        title="3D Globe View"
      >
        <Globe3D size={20} />
        <span>3D</span>
      </button>
    </div>
  );
};