// @ts-nocheck
import React, { useEffect, useRef } from 'react';
import mapboxgl from 'mapbox-gl';
import 'mapbox-gl/dist/mapbox-gl.css';

// Set Mapbox access token
mapboxgl.accessToken = process.env.REACT_APP_MAPBOX_TOKEN || '';

interface MapboxMapProps {
  className?: string;
}

export const MapboxMap: React.FC<MapboxMapProps> = ({ className }) => {
  const mapContainerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<mapboxgl.Map | null>(null);

  useEffect(() => {
    if (!mapContainerRef.current || mapRef.current) return;

    // Initialize map
    const map = new mapboxgl.Map({
      container: mapContainerRef.current,
      style: 'mapbox://styles/mapbox/satellite-v9',
      center: [0, 20],
      zoom: 2,
      projection: 'globe' as any
    });

    mapRef.current = map;

    // Add navigation controls
    map.addControl(new mapboxgl.NavigationControl(), 'top-right');

    // Add atmosphere styling
    map.on('style.load', () => {
      map.setFog({
        'range': [-1, 2],
        'horizon-blend': 0.3,
        'color': 'white',
        'high-color': '#add8e6',
        'space-color': '#d8f2ff',
        'star-intensity': 0.0
      });
    });

    // Cleanup
    return () => {
      map.remove();
      mapRef.current = null;
    };
  }, []);

  return (
    <div 
      ref={mapContainerRef} 
      className={className}
      style={{ 
        width: '100%', 
        height: '100%',
        position: 'absolute',
        top: 0,
        left: 0
      }} 
    />
  );
};