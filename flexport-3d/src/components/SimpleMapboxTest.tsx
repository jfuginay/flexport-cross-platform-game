// @ts-nocheck
import React, { useRef, useEffect } from 'react';
import mapboxgl from 'mapbox-gl';
import * as THREE from 'three';
import { useGameStore } from '../store/gameStore';
import { ShipType } from '../types/game.types';
import { positionToLatLng } from '../utils/geoUtils';
import 'mapbox-gl/dist/mapbox-gl.css';

// Set token
mapboxgl.accessToken = process.env.REACT_APP_MAPBOX_TOKEN || 'pk.eyJ1IjoiamZ1Z2luYXkiLCJhIjoiY21icmNha2hrMGE0azJscHVzdmVuZTVjOSJ9.oiJoYvc_G-tLUmaSzGVsVQ';

export const SimpleMapboxTest: React.FC = () => {
  const mapContainer = useRef<HTMLDivElement>(null);
  const map = useRef<mapboxgl.Map | null>(null);
  const shipMarkers = useRef<mapboxgl.Marker[]>([]);
  const { fleet, ports, addFreeShip } = useGameStore();

  useEffect(() => {
    if (!mapContainer.current || map.current) return;

    console.log('SimpleMapboxTest: Creating map...');
    console.log('Token:', mapboxgl.accessToken ? 'Present' : 'Missing');
    console.log('Container:', mapContainer.current);

    try {
      map.current = new mapboxgl.Map({
        container: mapContainer.current,
        style: 'mapbox://styles/mapbox/streets-v12',
        center: [0, 0],
        zoom: 2
      });

      map.current.on('load', () => {
        console.log('SimpleMapboxTest: Map loaded successfully!');
        console.log('Fleet size:', fleet.length);
        console.log('Ports:', ports.length);
        
        // Add ports as markers
        ports.forEach(port => {
          const el = document.createElement('div');
          el.style.cssText = `
            width: 30px;
            height: 30px;
            background: #ef4444;
            border-radius: 50%;
            border: 3px solid white;
            cursor: pointer;
            box-shadow: 0 2px 4px rgba(0,0,0,0.3);
          `;
          
          const portVector = new THREE.Vector3(port.position.x, port.position.y, port.position.z);
          const { lat, lng } = positionToLatLng(portVector);
          
          new mapboxgl.Marker(el)
            .setLngLat([lng, lat])
            .setPopup(new mapboxgl.Popup().setHTML(`<h3>${port.name}</h3>`))
            .addTo(map.current!);
        });
        
        // Add ships as cute ship emojis
        fleet.forEach(ship => {
          const el = document.createElement('div');
          el.style.cssText = `
            font-size: 30px;
            cursor: pointer;
            transform: translate(-50%, -50%);
          `;
          el.innerHTML = '🚢';
          
          // Convert ship position to lat/lng
          const shipVector = new THREE.Vector3(ship.position.x, ship.position.y, ship.position.z);
          const { lat, lng } = positionToLatLng(shipVector);
          
          new mapboxgl.Marker(el)
            .setLngLat([lng, lat])
            .setPopup(new mapboxgl.Popup().setHTML(`<h3>${ship.name}</h3><p>Status: ${ship.status}</p>`))
            .addTo(map.current!);
        });
      });

      map.current.on('error', (e) => {
        console.error('SimpleMapboxTest: Map error:', e);
      });
    } catch (error) {
      console.error('SimpleMapboxTest: Failed to create map:', error);
    }

    return () => {
      if (map.current) {
        map.current.remove();
        map.current = null;
      }
    };
  }, []);
  
  // Update ships when fleet changes
  useEffect(() => {
    if (!map.current) return;
    
    // Remove old markers
    shipMarkers.current.forEach(marker => marker.remove());
    shipMarkers.current = [];
    
    // Add new markers
    fleet.forEach(ship => {
      const el = document.createElement('div');
      el.style.cssText = `
        font-size: 30px;
        cursor: pointer;
        transform: translate(-50%, -50%);
      `;
      el.innerHTML = '🚢';
      
      // Convert ship position to lat/lng
      const shipVector = new THREE.Vector3(ship.position.x, ship.position.y, ship.position.z);
      const { lat, lng } = positionToLatLng(shipVector);
      
      const marker = new mapboxgl.Marker(el)
        .setLngLat([lng, lat])
        .setPopup(new mapboxgl.Popup().setHTML(`<h3>${ship.name}</h3><p>Status: ${ship.status}</p>`))
        .addTo(map.current!);
        
      shipMarkers.current.push(marker);
    });
  }, [fleet]);

  return (
    <div style={{ width: '100%', height: '100%', position: 'relative' }}>
      <div
        ref={mapContainer}
        style={{
          position: 'absolute',
          top: 0,
          bottom: 0,
          left: 0,
          right: 0
        }}
      />
      <div style={{
        position: 'absolute',
        top: '10px',
        left: '10px',
        background: 'white',
        padding: '10px',
        borderRadius: '4px',
        zIndex: 1
      }}>
        <div>Simple Mapbox Test</div>
        <div style={{ fontSize: '12px', marginTop: '5px' }}>
          Ships: {fleet.length} | Ports: {ports.length}
        </div>
        <button 
          onClick={() => addFreeShip(ShipType.CONTAINER, 'Test Ship ' + (fleet.length + 1))}
          style={{
            marginTop: '10px',
            padding: '5px 10px',
            background: '#3b82f6',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
            cursor: 'pointer'
          }}
        >
          Add Test Ship 🚢
        </button>
      </div>
    </div>
  );
};