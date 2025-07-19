import React from 'react';
import { MapboxTerrain } from './MapboxTerrain';

interface UnifiedMapViewProps {
  className?: string;
}

export const UnifiedMapView: React.FC<UnifiedMapViewProps> = ({ className }) => {
  return <MapboxTerrain className={className} />;
};