import React, { useState } from 'react';
import { MapboxMap } from './MapboxMap';
import { MapboxGlobeSimple } from './MapboxGlobeSimple';
import { MapboxGlobeAdvanced } from './MapboxGlobeAdvanced';
import { MapboxGlobeCombined } from './MapboxGlobeCombined';
import { SimpleMapboxTest } from './SimpleMapboxTest';
import { LeafletMap } from './LeafletMap';
import { Map2D } from './Map2D';
import { GlobeMap } from './GlobeMap';
import './MapSwitcher.css';

export type MapType = 
  | 'mapbox-globe'
  | 'mapbox-simple'
  | 'mapbox-advanced'
  | 'mapbox-combined'
  | 'mapbox-test'
  | 'leaflet'
  | 'canvas-2d'
  | 'globe-d3';

interface MapOption {
  id: MapType;
  name: string;
  description: string;
  category: 'Mapbox' | '2D Maps' | 'Other';
}

const mapOptions: MapOption[] = [
  // Mapbox variants
  { id: 'mapbox-globe', name: 'Mapbox Globe', description: 'Full-featured Mapbox with ships & weather', category: 'Mapbox' },
  { id: 'mapbox-simple', name: 'Mapbox Simple', description: 'Lightweight Mapbox globe', category: 'Mapbox' },
  { id: 'mapbox-advanced', name: 'Mapbox Advanced', description: 'Advanced features & route validation', category: 'Mapbox' },
  { id: 'mapbox-combined', name: 'Mapbox Combined', description: 'Toggle simple/advanced modes', category: 'Mapbox' },
  { id: 'mapbox-test', name: 'Mapbox Test', description: 'Simple test with ship emojis', category: 'Mapbox' },
  
  // 2D Maps
  { id: 'leaflet', name: 'Leaflet Map', description: 'Dark themed 2D map', category: '2D Maps' },
  { id: 'canvas-2d', name: 'Canvas 2D', description: 'Custom canvas world map', category: '2D Maps' },
  
  // Other
  { id: 'globe-d3', name: 'D3 Globe', description: 'SVG orthographic projection', category: 'Other' },
];

interface MapSwitcherProps {
  className?: string;
}

export const MapSwitcher: React.FC<MapSwitcherProps> = ({ className }) => {
  const [selectedMap, setSelectedMap] = useState<MapType>('mapbox-globe');
  const [showSelector, setShowSelector] = useState(false);

  const renderMap = () => {
    switch (selectedMap) {
      case 'mapbox-globe':
        return <MapboxMap className={className} />;
      case 'mapbox-simple':
        return <MapboxGlobeSimple />;
      case 'mapbox-advanced':
        return <MapboxGlobeAdvanced />;
      case 'mapbox-combined':
        return <MapboxGlobeCombined />;
      case 'mapbox-test':
        return <SimpleMapboxTest />;
      case 'leaflet':
        return <LeafletMap />;
      case 'canvas-2d':
        return <Map2D />;
      case 'globe-d3':
        return <GlobeMap />;
      default:
        return <MapboxMap className={className} />;
    }
  };

  const currentMap = mapOptions.find(m => m.id === selectedMap);

  return (
    <div style={{ width: '100%', height: '100%', position: 'relative' }}>
      {/* Map Selector Button */}
      <button
        onClick={() => setShowSelector(!showSelector)}
        style={{
          position: 'absolute',
          top: '20px',
          right: '20px',
          zIndex: 1000,
          padding: '10px 20px',
          background: 'rgba(20, 20, 30, 0.9)',
          color: '#ffffff',
          border: '1px solid rgba(255, 255, 255, 0.2)',
          borderRadius: '8px',
          cursor: 'pointer',
          fontSize: '14px',
          fontWeight: '500',
          backdropFilter: 'blur(10px)',
          display: 'flex',
          alignItems: 'center',
          gap: '8px',
          boxShadow: '0 4px 12px rgba(0,0,0,0.3)'
        }}
      >
        🗺️ {currentMap?.name || 'Select Map'}
        <span style={{ fontSize: '12px', opacity: 0.7 }}>
          {showSelector ? '▲' : '▼'}
        </span>
      </button>

      {/* Map Selector Panel */}
      {showSelector && (
        <div style={{
          position: 'absolute',
          top: '70px',
          right: '20px',
          zIndex: 1000,
          background: 'rgba(20, 20, 30, 0.95)',
          border: '1px solid rgba(255, 255, 255, 0.2)',
          borderRadius: '12px',
          padding: '20px',
          backdropFilter: 'blur(20px)',
          boxShadow: '0 8px 32px rgba(0,0,0,0.5)',
          maxHeight: '70vh',
          overflowY: 'auto',
          width: '350px'
        }}>
          <h3 style={{ 
            margin: '0 0 20px 0', 
            color: '#ffffff',
            fontSize: '18px',
            fontWeight: '600'
          }}>
            Select Map Type
          </h3>

          {['Mapbox', '2D Maps', 'Other'].map(category => (
            <div key={category} style={{ marginBottom: '20px' }}>
              <h4 style={{ 
                margin: '0 0 10px 0', 
                color: '#64748b',
                fontSize: '12px',
                textTransform: 'uppercase',
                letterSpacing: '1px'
              }}>
                {category}
              </h4>
              
              {mapOptions
                .filter(map => map.category === category)
                .map(map => (
                  <button
                    key={map.id}
                    onClick={() => {
                      setSelectedMap(map.id);
                      setShowSelector(false);
                    }}
                    style={{
                      width: '100%',
                      padding: '12px 16px',
                      marginBottom: '8px',
                      background: selectedMap === map.id 
                        ? 'rgba(59, 130, 246, 0.2)' 
                        : 'rgba(255, 255, 255, 0.05)',
                      border: selectedMap === map.id
                        ? '1px solid #3b82f6'
                        : '1px solid rgba(255, 255, 255, 0.1)',
                      borderRadius: '8px',
                      color: '#ffffff',
                      cursor: 'pointer',
                      textAlign: 'left',
                      transition: 'all 0.2s',
                      display: 'block'
                    }}
                    onMouseEnter={(e) => {
                      if (selectedMap !== map.id) {
                        e.currentTarget.style.background = 'rgba(255, 255, 255, 0.1)';
                      }
                    }}
                    onMouseLeave={(e) => {
                      if (selectedMap !== map.id) {
                        e.currentTarget.style.background = 'rgba(255, 255, 255, 0.05)';
                      }
                    }}
                  >
                    <div style={{ fontWeight: '500', marginBottom: '4px' }}>
                      {map.name}
                    </div>
                    <div style={{ 
                      fontSize: '12px', 
                      color: '#94a3b8',
                      fontWeight: '400'
                    }}>
                      {map.description}
                    </div>
                  </button>
                ))}
            </div>
          ))}

          <div style={{
            marginTop: '20px',
            padding: '12px',
            background: 'rgba(59, 130, 246, 0.1)',
            border: '1px solid rgba(59, 130, 246, 0.3)',
            borderRadius: '8px',
            fontSize: '12px',
            color: '#94a3b8'
          }}>
            💡 <strong>Tip:</strong> Different maps have different features. 
            Mapbox variants support weather and advanced ship tracking.
          </div>
        </div>
      )}

      {/* Current Map Description */}
      {currentMap && (
        <div style={{
          position: 'absolute',
          bottom: '20px',
          right: '20px',
          background: 'rgba(20, 20, 30, 0.9)',
          padding: '8px 16px',
          borderRadius: '6px',
          fontSize: '12px',
          color: '#94a3b8',
          backdropFilter: 'blur(10px)',
          border: '1px solid rgba(255, 255, 255, 0.1)'
        }}>
          {currentMap.description}
        </div>
      )}

      {/* Render Selected Map */}
      {renderMap()}
    </div>
  );
};