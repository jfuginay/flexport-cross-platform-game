// @ts-nocheck
import React, { useEffect, useState } from 'react';
import { useGameStore } from '../store/gameStore';
import { ShipStatus } from '../types/game.types';
import './VesselTracker.css';

interface VesselSignal {
  id: string;
  name: string;
  type: string;
  position: { lat: number; lng: number };
  altitude: number;
  speed: number;
  heading: number;
  status: ShipStatus;
  destination?: string;
  eta?: Date;
  lastUpdate: Date;
}

export const VesselTracker: React.FC = () => {
  const { fleet, ports } = useGameStore();
  const [vesselSignals, setVesselSignals] = useState<VesselSignal[]>([]);
  const [selectedSignal, setSelectedSignal] = useState<string | null>(null);

  // Convert 3D position to lat/lng
  const positionToLatLng = (position: { x: number, y: number, z: number }): { lat: number; lng: number } => {
    const normalized = {
      x: position.x / 100,
      y: position.y / 100,
      z: position.z / 100
    };
    const lat = Math.asin(normalized.y) * (180 / Math.PI);
    const lng = Math.atan2(normalized.z, -normalized.x) * (180 / Math.PI);
    return { lat, lng };
  };

  // Simulate vessels transmitting their positions
  useEffect(() => {
    const updateSignals = () => {
      const signals: VesselSignal[] = fleet.map(ship => {
        const { lat, lng } = positionToLatLng(ship.position);
        const destination = ship.destination ? 
          ports.find(p => p.id === ship.destination?.id)?.name : undefined;
        
        // Calculate heading based on movement
        let heading = 0;
        if (ship.destination) {
          const destPos = positionToLatLng(ship.destination.position);
          heading = calculateHeading(lat, lng, destPos.lat, destPos.lng);
        }

        return {
          id: ship.id,
          name: ship.name,
          type: ship.type,
          position: { lat, lng },
          altitude: ship.type === 'CARGO_PLANE' ? 35000 : 0, // feet
          speed: ship.speed * 20, // Convert to knots
          heading,
          status: ship.status,
          destination,
          eta: ship.destination ? new Date(Date.now() + Math.random() * 24 * 60 * 60 * 1000) : undefined,
          lastUpdate: new Date()
        };
      });

      setVesselSignals(signals);
    };

    // Initial update
    updateSignals();

    // Update every 2 seconds (simulating real-time updates)
    const interval = setInterval(updateSignals, 2000);

    return () => clearInterval(interval);
  }, [fleet, ports]);

  // Calculate heading between two points
  const calculateHeading = (lat1: number, lng1: number, lat2: number, lng2: number): number => {
    const dLng = (lng2 - lng1) * Math.PI / 180;
    const lat1Rad = lat1 * Math.PI / 180;
    const lat2Rad = lat2 * Math.PI / 180;
    
    const y = Math.sin(dLng) * Math.cos(lat2Rad);
    const x = Math.cos(lat1Rad) * Math.sin(lat2Rad) -
              Math.sin(lat1Rad) * Math.cos(lat2Rad) * Math.cos(dLng);
    
    const heading = (Math.atan2(y, x) * 180 / Math.PI + 360) % 360;
    return heading;
  };

  return (
    <div className="vessel-tracker">
      <div className="tracker-header">
        <h3>🛰️ Vessel Tracking System</h3>
        <span className="signal-status">● LIVE</span>
      </div>

      <div className="signal-list">
        {vesselSignals.map(signal => (
          <div 
            key={signal.id}
            className={`signal-item ${selectedSignal === signal.id ? 'selected' : ''} ${signal.status.toLowerCase()}`}
            onClick={() => setSelectedSignal(signal.id)}
          >
            <div className="signal-header">
              <span className="vessel-icon">
                {signal.type === 'CARGO_PLANE' ? '✈️' : '🚢'}
              </span>
              <span className="vessel-id">{signal.name}</span>
              <span className={`status-indicator ${signal.status.toLowerCase()}`}>
                {signal.status}
              </span>
            </div>
            
            <div className="signal-data">
              <div className="data-row">
                <span className="label">POS:</span>
                <span className="value">
                  {signal.position.lat.toFixed(2)}°, {signal.position.lng.toFixed(2)}°
                </span>
              </div>
              <div className="data-row">
                <span className="label">HDG:</span>
                <span className="value">{signal.heading.toFixed(0)}°</span>
                <span className="label">SPD:</span>
                <span className="value">{signal.speed.toFixed(0)}kt</span>
              </div>
              {signal.altitude > 0 && (
                <div className="data-row">
                  <span className="label">ALT:</span>
                  <span className="value">{signal.altitude.toLocaleString()}ft</span>
                </div>
              )}
              {signal.destination && (
                <div className="data-row">
                  <span className="label">DEST:</span>
                  <span className="value">{signal.destination}</span>
                </div>
              )}
              <div className="data-row">
                <span className="label">UPDATE:</span>
                <span className="value">
                  {new Date().toLocaleTimeString()}
                </span>
              </div>
            </div>
          </div>
        ))}
      </div>

      {selectedSignal && (
        <div className="signal-details">
          {vesselSignals.find(s => s.id === selectedSignal) && (
            <>
              <h4>Detailed Tracking</h4>
              <div className="tracking-grid">
                {/* Add more detailed tracking info here */}
              </div>
            </>
          )}
        </div>
      )}
    </div>
  );
};