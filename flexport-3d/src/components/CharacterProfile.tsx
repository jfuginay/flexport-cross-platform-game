import React from 'react';
import CharacterIcon from './CharacterIcon';
import './CharacterProfile.css';

interface CharacterProfileProps {
  name: string;
  role: string;
  level: number;
  experience: number;
  nextLevelExp: number;
  stats: {
    contracts: number;
    routesOptimized: number;
    profit: number;
  };
}

const CharacterProfile: React.FC<CharacterProfileProps> = ({
  name,
  role,
  level,
  experience,
  nextLevelExp,
  stats
}) => {
  const expProgress = (experience / nextLevelExp) * 100;

  return (
    <div className="character-profile">
      <div className="profile-header">
        <CharacterIcon 
          character="rebecca" 
          size="large" 
          showStatus={true} 
          status="online"
        />
        <div className="profile-info">
          <h2>{name}</h2>
          <p className="role">{role}</p>
          <div className="level-badge">Level {level}</div>
        </div>
      </div>

      <div className="experience-bar">
        <div className="exp-label">
          <span>Experience</span>
          <span>{experience} / {nextLevelExp}</span>
        </div>
        <div className="exp-track">
          <div 
            className="exp-fill" 
            style={{ width: `${expProgress}%` }}
          />
        </div>
      </div>

      <div className="stats-grid">
        <div className="stat-card">
          <div className="stat-value">{stats.contracts}</div>
          <div className="stat-label">Contracts</div>
        </div>
        <div className="stat-card">
          <div className="stat-value">{stats.routesOptimized}</div>
          <div className="stat-label">Routes</div>
        </div>
        <div className="stat-card">
          <div className="stat-value">${stats.profit.toLocaleString()}</div>
          <div className="stat-label">Profit</div>
        </div>
      </div>
    </div>
  );
};

export default CharacterProfile;