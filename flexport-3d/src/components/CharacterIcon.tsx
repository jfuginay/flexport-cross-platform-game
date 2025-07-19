// @ts-nocheck
import React from 'react';
import rebeccaIcon from '../assets/characters/rebecca-icon.svg';

interface CharacterIconProps {
  character: 'rebecca' | 'captain' | 'trader' | 'engineer';
  size?: 'small' | 'medium' | 'large';
  showStatus?: boolean;
  status?: 'online' | 'busy' | 'offline';
  className?: string;
}

const CharacterIcon: React.FC<CharacterIconProps> = ({ 
  character, 
  size = 'medium', 
  showStatus = false,
  status = 'online',
  className = ''
}) => {
  const sizeMap = {
    small: 40,
    medium: 60,
    large: 100
  };

  const statusColors = {
    online: '#4CAF50',
    busy: '#FF9800',
    offline: '#757575'
  };

  const characterIcons = {
    rebecca: rebeccaIcon,
    captain: rebeccaIcon, // Placeholder - would have different icons
    trader: rebeccaIcon,
    engineer: rebeccaIcon
  };

  const iconSize = sizeMap[size];

  return (
    <div 
      className={`character-icon ${className}`}
      style={{ 
        position: 'relative', 
        width: iconSize, 
        height: iconSize,
        display: 'inline-block'
      }}
    >
      <img 
        src={characterIcons[character]} 
        alt={`${character} icon`}
        style={{ 
          width: '100%', 
          height: '100%',
          borderRadius: '50%',
          border: '2px solid #0f4c75'
        }}
      />
      {showStatus && (
        <div
          style={{
            position: 'absolute',
            bottom: 0,
            right: 0,
            width: iconSize * 0.25,
            height: iconSize * 0.25,
            backgroundColor: statusColors[status],
            borderRadius: '50%',
            border: '2px solid #1a1a2e'
          }}
        />
      )}
    </div>
  );
};

export default CharacterIcon;