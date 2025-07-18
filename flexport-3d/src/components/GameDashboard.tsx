import React, { useState, useEffect } from 'react';
import { useGameStore } from '../store/gameStore';
import { Canvas } from '@react-three/fiber';
import { PerspectiveCamera } from '@react-three/drei';
import * as THREE from 'three';
import { World } from './World';
import { Ship } from './Ship';
import { SphericalCameraController } from './SphericalCameraController';
import { DayNightCycle } from './DayNightCycle';
import { Weather, WeatherState } from './Weather';
import { VesselTracker } from './VesselTracker';
import { FleetManagement } from './UI/FleetManagement';
import { ContractsList } from './UI/ContractsList';
import { PortsOverview } from './UI/PortsOverview';
import { AIResearchPanel } from './UI/AIResearchPanel';
import { FinancesPanel } from './UI/FinancesPanel';
// import { PostProcessingEffects } from './PostProcessingEffects';
import { NewsTicker } from './UI/NewsTicker';
import { FleetManagementModal } from './FleetManagementModal';
import { MapboxGlobe } from './MapboxGlobe';
import './GameDashboard.css';

interface GameDashboardProps {
  children?: React.ReactNode;
}

export const GameDashboard: React.FC<GameDashboardProps> = ({ children }) => {
  const { 
    money, 
    reputation, 
    companyName, 
    fleet, 
    ports,
    contracts,
    currentDate,
    gameSpeed,
    isPaused,
    setGameSpeed,
    pauseGame,
    resumeGame,
    selectShip,
    selectedShipId,
    selectedPortId,
    startGame
  } = useGameStore();
  
  const [isEarthRotating] = useState(true);
  const [weatherState] = useState<WeatherState>(WeatherState.CLEAR);
  const [timeOfDay] = useState(12);
  const [activePanel, setActivePanel] = useState<string>('overview');
  const [isInitialized, setIsInitialized] = useState(false);
  const [isSceneReady, setIsSceneReady] = useState(false);
  const [isFleetModalOpen, setIsFleetModalOpen] = useState(false);
  const [viewMode, setViewMode] = useState<'3d' | 'mapbox'>('mapbox'); // Default to beautiful Mapbox view
  
  // Initialize game world when component mounts
  useEffect(() => {
    if (!isInitialized && ports.length === 0) {
      console.log('Initializing game world...');
      startGame();
      setIsInitialized(true);
      // Delay scene visibility to prevent flicker
      setTimeout(() => setIsSceneReady(true), 100);
    }
  }, [isInitialized, ports.length, startGame]);
  
  // Game update loop
  useEffect(() => {
    let lastTime = Date.now();
    let animationFrameId: number;
    
    const gameLoop = () => {
      const currentTime = Date.now();
      const deltaTime = (currentTime - lastTime) / 1000; // Convert to seconds
      lastTime = currentTime;
      
      // Update game state
      useGameStore.getState().updateGame(deltaTime);
      
      animationFrameId = requestAnimationFrame(gameLoop);
    };
    
    animationFrameId = requestAnimationFrame(gameLoop);
    
    return () => {
      cancelAnimationFrame(animationFrameId);
    };
  }, []);
  
  const handleSpeedChange = (speed: number) => {
    setGameSpeed(speed);
  };
  
  const togglePause = () => {
    if (isPaused) {
      resumeGame();
    } else {
      pauseGame();
    }
  };
  
  const handleNewsClick = (newsItem: any) => {
    if (newsItem.location) {
      // TODO: Implement zoom to location functionality
      console.log('Zooming to news event:', newsItem);
    }
  };
  
  return (
    <div className="game-dashboard">
      {/* News Ticker */}
      <NewsTicker onNewsClick={handleNewsClick} />
      {/* Top Bar */}
      <div className="top-bar">
        <div className="company-info">
          <h1 className="company-name">{companyName}</h1>
          <div className="game-date">{currentDate.toLocaleDateString()}</div>
        </div>
        
        <div className="resource-bar">
          <div className="resource-item money">
            <span className="resource-icon">💰</span>
            <span className="resource-value">${money.toLocaleString()}</span>
          </div>
          <div className="resource-item reputation">
            <span className="resource-icon">⭐</span>
            <span className="resource-value">{reputation}%</span>
          </div>
          <div className="resource-item fleet-count">
            <span className="resource-icon">🚢</span>
            <span className="resource-value">{fleet.length} Ships</span>
          </div>
          <div className="resource-item contract-count">
            <span className="resource-icon">📋</span>
            <span className="resource-value">{contracts.filter(c => c.status === 'ACTIVE').length} Active</span>
          </div>
        </div>
        
        <div className="game-controls">
          <button 
            className={`control-btn ${isPaused ? 'paused' : ''}`}
            onClick={togglePause}
            title={isPaused ? 'Resume' : 'Pause'}
          >
            {isPaused ? '▶️' : '⏸️'}
          </button>
          
          <div className="speed-controls">
            <button 
              className={`speed-btn ${gameSpeed === 0.5 ? 'active' : ''}`}
              onClick={() => handleSpeedChange(0.5)}
            >
              0.5x
            </button>
            <button 
              className={`speed-btn ${gameSpeed === 1 ? 'active' : ''}`}
              onClick={() => handleSpeedChange(1)}
            >
              1x
            </button>
            <button 
              className={`speed-btn ${gameSpeed === 2 ? 'active' : ''}`}
              onClick={() => handleSpeedChange(2)}
            >
              2x
            </button>
            <button 
              className={`speed-btn ${gameSpeed === 5 ? 'active' : ''}`}
              onClick={() => handleSpeedChange(5)}
            >
              5x
            </button>
          </div>
          
          <div className="view-toggle">
            <button 
              className={`view-btn ${viewMode === '3d' ? 'active' : ''}`}
              onClick={() => setViewMode('3d')}
              title="3D Globe View"
            >
              🌍 3D
            </button>
            <button 
              className={`view-btn ${viewMode === 'mapbox' ? 'active' : ''}`}
              onClick={() => setViewMode('mapbox')}
              title="Mapbox Globe View"
            >
              🗺️ Map
            </button>
          </div>
        </div>
      </div>
      
      {/* Main Game Area */}
      <div className="game-content">
        {/* Left Sidebar */}
        <div className="left-sidebar">
          <div className="sidebar-tabs">
            <button 
              className={`sidebar-tab ${activePanel === 'overview' ? 'active' : ''}`}
              onClick={() => setActivePanel('overview')}
              title="Overview"
            >
              <span className="tab-icon">📊</span>
              <span className="tab-label">Overview</span>
            </button>
            <button 
              className={`sidebar-tab ${activePanel === 'fleet' ? 'active' : ''}`}
              onClick={() => setIsFleetModalOpen(true)}
              title="Fleet Management"
            >
              <span className="tab-icon">🚢</span>
              <span className="tab-label">Fleet</span>
            </button>
            <button 
              className={`sidebar-tab ${activePanel === 'contracts' ? 'active' : ''}`}
              onClick={() => setActivePanel('contracts')}
              title="Contracts"
            >
              <span className="tab-icon">📋</span>
              <span className="tab-label">Contracts</span>
            </button>
            <button 
              className={`sidebar-tab ${activePanel === 'ports' ? 'active' : ''}`}
              onClick={() => setActivePanel('ports')}
              title="Ports"
            >
              <span className="tab-icon">🏢</span>
              <span className="tab-label">Ports</span>
            </button>
            <button 
              className={`sidebar-tab ${activePanel === 'research' ? 'active' : ''}`}
              onClick={() => setActivePanel('research')}
              title="AI Research"
            >
              <span className="tab-icon">🧠</span>
              <span className="tab-label">Research</span>
            </button>
            <button 
              className={`sidebar-tab ${activePanel === 'finances' ? 'active' : ''}`}
              onClick={() => setActivePanel('finances')}
              title="Finances"
            >
              <span className="tab-icon">💰</span>
              <span className="tab-label">Finances</span>
            </button>
          </div>
          
          <div className="sidebar-content">
            {activePanel === 'overview' && (
              <div className="overview-panel">
                <h3>Company Overview</h3>
                <div className="stat-grid">
                  <div className="stat-item">
                    <span className="stat-label">Total Revenue</span>
                    <span className="stat-value">$2.4M</span>
                  </div>
                  <div className="stat-item">
                    <span className="stat-label">Ships at Sea</span>
                    <span className="stat-value">{fleet.filter(s => s.status === 'SAILING').length}</span>
                  </div>
                  <div className="stat-item">
                    <span className="stat-label">Cargo Delivered</span>
                    <span className="stat-value">0 TEU</span>
                  </div>
                  <div className="stat-item">
                    <span className="stat-label">Active Routes</span>
                    <span className="stat-value">{fleet.filter(s => s.destination).length}</span>
                  </div>
                </div>
              </div>
            )}
            
            {activePanel === 'fleet' && (
              <FleetManagement embedded={true} onClose={() => setActivePanel('overview')} />
            )}
            
            {activePanel === 'contracts' && (
              <ContractsList />
            )}
            
            {activePanel === 'ports' && (
              <PortsOverview />
            )}
            
            {activePanel === 'research' && (
              <AIResearchPanel />
            )}
            
            {activePanel === 'finances' && (
              <FinancesPanel />
            )}
          </div>
        </div>
        
        {/* Game View */}
        <div className="game-view" style={{ opacity: isSceneReady ? 1 : 0, transition: 'opacity 0.5s ease-in-out' }}>
          {/* Toggle between 3D Canvas and Mapbox views */}
          {viewMode === 'mapbox' ? (
            <MapboxGlobe className="mapbox-view" />
          ) : (
            <>
              {/* Debug info */}
              <div style={{ position: 'absolute', top: 10, left: 10, color: 'white', zIndex: 1000, background: 'rgba(0,0,0,0.5)', padding: '10px' }}>
                <div>Scene Ready: {isSceneReady ? 'Yes' : 'No'}</div>
                <div>Ports: {ports.length}</div>
                <div>Fleet: {fleet.length}</div>
              </div>
              <div style={{ width: '100%', height: '100%', position: 'relative', background: '#222' }}>
                <Canvas 
              shadows 
              gl={{ 
                antialias: true, 
                alpha: false,
                toneMapping: THREE.ACESFilmicToneMapping,
                toneMappingExposure: 1.0
              }}
              style={{ position: 'absolute', top: 0, left: 0, width: '100%', height: '100%' }}
              onCreated={({ gl, camera, scene }) => {
                console.log('Canvas created!');
                console.log('Camera position:', camera.position);
                console.log('Scene children:', scene.children.length);
                gl.setClearColor(0x87CEEB, 1);
              }}
            >
            <PerspectiveCamera 
              makeDefault 
              position={[400, 300, 400]} 
              fov={45}
              near={1}
              far={10000}
            />
            <SphericalCameraController />
            
            <ambientLight intensity={0.8} />
            <directionalLight
              position={[100, 100, 50]}
              intensity={1.5}
              castShadow
              shadow-mapSize={[2048, 2048]}
              color={0xffffff}
            />
            {/* Additional lights for better Earth visibility */}
            <pointLight position={[-100, 50, -50]} intensity={0.7} color="#ffffff" />
            <pointLight position={[50, -50, 100]} intensity={0.5} color="#aaccff" />
            
            <DayNightCycle timeOfDay={timeOfDay} />
            <Weather weatherState={weatherState} />
            
            <World isEarthRotating={isEarthRotating} timeOfDay={timeOfDay} />
            
            {fleet.map(ship => (
              <Ship
                key={ship.id}
                ship={ship}
                onClick={(ship) => selectShip(ship.id)}
                isSelected={selectedShipId === ship.id}
              />
            ))}
            
            {/* Stats temporarily disabled */}
            {/* {process.env.NODE_ENV === 'development' && <Stats />} */}
            
            {/* Post-processing effects disabled */}
            </Canvas>
              </div>
            </>
          )}
          
          {/* Mini Map Overlay - temporarily disabled due to performance */}
          {/* <div className="minimap-overlay">
            <GlobeMap />
          </div> */}
        </div>
        
        {/* Right Sidebar - Selection & Actions */}
        <div className="right-sidebar">
          {selectedShipId ? (
            <div className="selection-panel">
              <h3>Ship Selected</h3>
              {/* Ship details */}
            </div>
          ) : selectedPortId ? (
            <div className="selection-panel">
              <h3>Port Selected</h3>
              {/* Port details */}
            </div>
          ) : (
            <div className="quick-actions">
              <h3>Quick Actions</h3>
              <button 
                className="action-btn primary"
                onClick={() => setIsFleetModalOpen(true)}
              >
                <span className="btn-icon">➕</span>
                Purchase Ship
              </button>
              <button className="action-btn">
                <span className="btn-icon">📋</span>
                View Contracts
              </button>
              <button className="action-btn">
                <span className="btn-icon">📊</span>
                Market Report
              </button>
            </div>
          )}
          
          {/* Contract Notifications */}
          <div className="notifications-panel">
            <h3>Notifications</h3>
            <div className="notification-list">
              {contracts.filter(c => c.status === 'AVAILABLE').slice(0, 3).map(contract => (
                <div key={contract.id} className="notification-item">
                  <div className="notification-header">
                    <span className="notification-icon">📦</span>
                    <span className="notification-title">New Contract</span>
                  </div>
                  <div className="notification-body">
                    {contract.origin.name} → {contract.destination.name}
                  </div>
                  <div className="notification-value">${contract.value.toLocaleString()}</div>
                </div>
              ))}
            </div>
          </div>
          
          <VesselTracker />
        </div>
      </div>
      
      {/* Bottom Status Bar */}
      <div className="bottom-bar">
        <div className="status-item">
          <span className="status-icon">🌡️</span>
          <span className="status-text">Weather: {weatherState}</span>
        </div>
        <div className="status-item">
          <span className="status-icon">🕐</span>
          <span className="status-text">Time: {Math.floor(timeOfDay)}:00</span>
        </div>
        <div className="status-item">
          <span className="status-icon">🌍</span>
          <span className="status-text">Earth Rotation: {isEarthRotating ? 'ON' : 'OFF'}</span>
        </div>
        <div className="game-tips">
          <span className="tip">💡 Tip: Click on ships or ports to select them</span>
        </div>
      </div>
      
      {/* Fleet Management Modal */}
      <FleetManagementModal 
        isOpen={isFleetModalOpen}
        onClose={() => setIsFleetModalOpen(false)}
      />
    </div>
  );
};