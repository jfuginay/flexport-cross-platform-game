// @ts-nocheck
import React from 'react';
import { Port } from './Port';
import { useGameStore } from '../store/gameStore';

export const EarthPorts: React.FC = () => {
  const { ports, selectPort, selectedPortId } = useGameStore();

  return (
    <group name="earth-ports">
      {ports.map(port => (
        <Port 
          key={port.id} 
          port={port} 
          onClick={() => selectPort(port.id)}
          isSelected={selectedPortId === port.id}
        />
      ))}
    </group>
  );
};