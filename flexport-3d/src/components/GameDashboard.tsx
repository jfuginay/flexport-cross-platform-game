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
// import { GrandOrganizer } from './GrandOrganizer';
// Mobile components
import { MobileNavigation } from './mobile/MobileNavigation';
import { MobileFleetView } from './mobile/MobileFleetView';
import { MobileContractsView } from './mobile/MobileContractsView';
import { MobileAlertsView } from './mobile/MobileAlertsView';
// Map components
import { MapboxGlobe } from './MapboxGlobe';
import { SimpleMapboxTest } from './SimpleMapboxTest';
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
  const [isMobile, setIsMobile] = useState(false);
  const [mobileView, setMobileView] = useState<'map' | 'fleet' | 'contracts' | 'alerts'>('map');
  const [viewMode, setViewMode] = useState<'3d' | '2d'>('2d'); // Start with 2D map view to see ships
  
  // Initialize game world when component mounts
  useEffect(() => {
    if (!isInitialized && ports.length === 0) {
      console.log('Initializing game world...');
      startGame();
      setIsInitialized(true);
      // Delay scene visibility to prevent flicker
      setTimeout(() => setIsSceneReady(true), 100);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  
  // Check if device is mobile
  useEffect(() => {
    const checkMobile = () => {
      setIsMobile(window.innerWidth <= 768);
    };
    
    checkMobile();
    window.addEventListener('resize', checkMobile);
    
    return () => window.removeEventListener('resize', checkMobile);
  }, []);
  
  // Game update loop
  useEffect(() => {
    let lastTime = Date.now();
    let animationFrameId: number;
    let accumulatedTime = 0;
    const MIN_UPDATE_INTERVAL = 1000 / 60; // Cap at 60 FPS
    
    const gameLoop = () => {
      const currentTime = Date.now();
      const frameTime = currentTime - lastTime;
      lastTime = currentTime;
      
      // Accumulate time to ensure consistent updates
      accumulatedTime += frameTime;
      
      // Only update if enough time has passed (prevents excessive updates)
      if (accumulatedTime >= MIN_UPDATE_INTERVAL) {
        const deltaTime = accumulatedTime / 1000; // Convert to seconds
        accumulatedTime = 0;
        
        // Update game state
        useGameStore.getState().updateGame(deltaTime);
      }
      
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
  
  // Mobile views
  if (isMobile) {
    return (
      <div className="game-dashboard mobile">
        <MobileNavigation 
          onFleetClick={() => setMobileView('fleet')}
          onContractsClick={() => setMobileView('contracts')}
          onAlertsClick={() => setMobileView('alerts')}
        />
        
        {/* Mobile 3D View */}
        <div className="mobile-game-view" style={{ 
          position: 'fixed',
          top: '100px',
          bottom: '72px',
          left: 0,
          right: 0,
          background: '#000814'
        }}>
          <Canvas 
            shadows 
            gl={{ 
              antialias: true, 
              alpha: false,
              toneMapping: THREE.ACESFilmicToneMapping,
              toneMappingExposure: 1.0
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
              shadow-mapSize={[1024, 1024]}
              color={0xffffff}
            />
            
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
          </Canvas>
        </div>
        
        {/* Mobile Overlays */}
        {mobileView === 'fleet' && (
          <MobileFleetView onClose={() => setMobileView('map')} />
        )}
        {mobileView === 'contracts' && (
          <MobileContractsView onClose={() => setMobileView('map')} />
        )}
        {mobileView === 'alerts' && (
          <MobileAlertsView onClose={() => setMobileView('map')} />
        )}
      </div>
    );
  }
  
  // Desktop view
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
        
        {/* Game View - 3D or 2D */}
        <div className="game-view" style={{ opacity: isSceneReady ? 1 : 0, transition: 'opacity 0.5s ease-in-out' }}>
          {/* View Mode Toggle */}
          <div style={{
            position: 'absolute',
            top: '20px',
            right: '20px',
            zIndex: 100,
            display: 'flex',
            gap: '5px',
            background: 'rgba(20, 20, 30, 0.9)',
            padding: '5px',
            borderRadius: '8px',
            border: '1px solid rgba(255, 255, 255, 0.1)',
            backdropFilter: 'blur(10px)'
          }}>
            <button
              onClick={() => setViewMode('3d')}
              style={{
                padding: '8px 16px',
                background: viewMode === '3d' ? '#3b82f6' : 'transparent',
                color: 'white',
                border: 'none',
                borderRadius: '6px',
                cursor: 'pointer',
                fontSize: '14px',
                fontWeight: '500',
                transition: 'all 0.2s'
              }}
            >
              🌍 3D Globe
            </button>
            <button
              onClick={() => setViewMode('2d')}
              style={{
                padding: '8px 16px',
                background: viewMode === '2d' ? '#3b82f6' : 'transparent',
                color: 'white',
                border: 'none',
                borderRadius: '6px',
                cursor: 'pointer',
                fontSize: '14px',
                fontWeight: '500',
                transition: 'all 0.2s'
              }}
            >
              🗺️ 2D Map
            </button>
          </div>

          <div style={{ width: '100%', height: '100%', position: 'relative', background: '#000814' }}>
            {/* 2D Map View */}
            {viewMode === '2d' && (
              <SimpleMapboxTest />
              // <MapboxGlobe className="map-view" />
            )}
            
            {/* 3D Canvas View */}
            {viewMode === '3d' && (
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
            )}
          </div>
          
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
      
      {/* Grand Organizer - Advisor System */}
      {/* <GrandOrganizer /> */}
    </div>
  );
};