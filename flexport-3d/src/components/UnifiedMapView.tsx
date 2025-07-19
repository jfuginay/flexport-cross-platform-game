// @ts-nocheck
import React, { useState } from 'react';
import { MapboxTerrain } from './MapboxTerrain';
import { Globe3DView } from './Globe3DView';
import { ViewToggle } from './UI/ViewToggle';

interface UnifiedMapViewProps {
  className?: string;
}

export const UnifiedMapView: React.FC<UnifiedMapViewProps> = ({ className }) => {
  const [viewMode, setViewMode] = useState<'2D' | '3D'>('3D'); // Start with 3D view

  return (
    <div className={className} style={{ position: 'relative', width: '100%', height: '100%' }}>
      {/* View Toggle */}
      <div style={{ 
        position: 'absolute', 
        top: 20, 
        left: 20, 
        zIndex: 1000 
      }}>
        <ViewToggle 
          currentView={viewMode} 
          onViewChange={setViewMode} 
        />
      </div>

      {/* Map Views */}
      {viewMode === '2D' ? (
        <MapboxTerrain className={className} />
      ) : (
        <Globe3DView className={className} />
      )}
    </div>
  );
};