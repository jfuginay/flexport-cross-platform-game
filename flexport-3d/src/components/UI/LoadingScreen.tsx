// @ts-nocheck
import React from 'react';
import './LoadingScreen.css';

export const LoadingScreen: React.FC = () => {
  return (
    <div className="loading-screen">
      <div className="loading-content">
        <div className="loading-logo">
          <div className="globe-container">
            <div className="globe"></div>
            <div className="orbit"></div>
          </div>
        </div>
        <h1>FlexPort Global</h1>
        <p>Loading your shipping empire...</p>
        <div className="loading-bar">
          <div className="loading-progress"></div>
        </div>
      </div>
    </div>
  );
};