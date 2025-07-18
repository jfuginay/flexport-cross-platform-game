import React, { useEffect, useRef, useState } from 'react';
import * as d3 from 'd3';
import { geoOrthographic, geoPath, GeoPermissibleObjects } from 'd3-geo';
import { useGameStore } from '../store/gameStore';
import { ShipStatus, ShipType } from '../types/game.types';
import './GlobeMap.css';

// Import world topology
import worldData from '../data/world-110m.json';

interface VesselIcon {
  id: string;
  type: 'ship' | 'plane';
  lat: number;
  lng: number;
  heading: number;
  status: ShipStatus;
  name: string;
}

export const GlobeMap: React.FC = () => {
  const svgRef = useRef<SVGSVGElement>(null);
  const { fleet, ports, selectShip, selectPort, selectedShipId, selectedPortId, isPaused } = useGameStore();
  const [rotation, setRotation] = useState<[number, number, number]>([0, -20, 0]);
  const [zoomScale, setZoomScale] = useState(250);
  const animationRef = useRef<number>(0);
  
  // Natural Earth rotation speed (360 degrees per 24 hours = 15 degrees per hour)
  // In game time at 1x speed, we'll make it visible but realistic
  const ROTATION_SPEED = 0.25; // degrees per frame at 60fps (~15 degrees per minute)
  
  // Convert 3D position to lat/lng
  const positionToLatLng = (position: { x: number, y: number, z: number }): [number, number] => {
    const normalized = {
      x: position.x / 100,
      y: position.y / 100,
      z: position.z / 100
    };
    const lat = Math.asin(normalized.y) * (180 / Math.PI);
    const lng = Math.atan2(normalized.z, -normalized.x) * (180 / Math.PI);
    return [lng, lat]; // Note: D3 uses [lng, lat] order
  };

  // Natural Earth rotation animation
  useEffect(() => {
    let lastTime = 0;
    const animate = (time: number) => {
      if (!lastTime) lastTime = time;
      const delta = time - lastTime;
      
      if (!isPaused && delta > 16) { // Limit to ~60fps
        setRotation(prev => [
          (prev[0] - ROTATION_SPEED) % 360, // Rotate west to east
          prev[1],
          prev[2]
        ]);
        lastTime = time;
      }
      animationRef.current = requestAnimationFrame(animate);
    };
    
    animationRef.current = requestAnimationFrame(animate);
    
    return () => {
      if (animationRef.current) {
        cancelAnimationFrame(animationRef.current);
      }
    };
  }, [isPaused]);

  // Zoom to selected ship or port
  useEffect(() => {
    if (selectedShipId) {
      const ship = fleet.find(s => s.id === selectedShipId);
      if (ship) {
        const [lng, lat] = positionToLatLng(ship.position);
        // Smoothly rotate to center on the ship
        setRotation([-lng, -lat, 0]);
        setZoomScale(400); // Zoom in
      }
    } else if (selectedPortId) {
      const port = ports.find(p => p.id === selectedPortId);
      if (port) {
        const [lng, lat] = positionToLatLng(port.position);
        // Smoothly rotate to center on the port
        setRotation([-lng, -lat, 0]);
        setZoomScale(400); // Zoom in
      }
    } else {
      // Reset zoom when nothing selected
      setZoomScale(250);
    }
  }, [selectedShipId, selectedPortId, fleet, ports]);

  useEffect(() => {
    if (!svgRef.current) return;

    const width = 900;
    const height = 600;

    // Clear previous content
    d3.select(svgRef.current).selectAll('*').remove();

    // Set up SVG
    const svg = d3.select(svgRef.current)
      .attr('width', width)
      .attr('height', height);

    // Create globe projection
    const projection = geoOrthographic()
      .scale(zoomScale)
      .center([0, 0])
      .rotate(rotation)
      .translate([width / 2, height / 2])
      .clipAngle(90);

    const path = geoPath().projection(projection);

    // Create globe outline
    svg.append('defs').append('radialGradient')
      .attr('id', 'ocean-gradient')
      .selectAll('stop')
      .data([
        { offset: '0%', color: '#0a1929' },
        { offset: '100%', color: '#1e3a5f' }
      ])
      .enter().append('stop')
      .attr('offset', d => d.offset)
      .attr('stop-color', d => d.color);

    // Ocean background
    svg.append('circle')
      .attr('cx', width / 2)
      .attr('cy', height / 2)
      .attr('r', projection.scale())
      .attr('fill', 'url(#ocean-gradient)')
      .attr('stroke', '#2c5282')
      .attr('stroke-width', 2);

    // Grid lines
    const graticule = d3.geoGraticule();
    svg.append('path')
      .datum(graticule)
      .attr('class', 'graticule')
      .attr('d', path as any)
      .attr('fill', 'none')
      .attr('stroke', '#1e3a5f')
      .attr('stroke-width', 0.5)
      .attr('opacity', 0.5);

    // Land masses from real world data
    const land = svg.append('g').attr('class', 'land');
    
    // Draw continents from world data
    worldData.features.forEach(feature => {
      land.append('path')
        .datum(feature as any)
        .attr('d', path as any)
        .attr('fill', '#4a5568')
        .attr('stroke', '#2d3748')
        .attr('stroke-width', 1)
        .attr('class', `continent ${feature.properties.name.toLowerCase().replace(' ', '-')}`);
    });

    // Port markers
    const portGroup = svg.append('g').attr('class', 'ports');
    
    ports.forEach(port => {
      const coords = positionToLatLng(port.position);
      const projected = projection(coords);
      
      if (projected && projection.invert && projection.invert(projected)) {
        const portMarker = portGroup.append('g')
          .attr('transform', `translate(${projected[0]}, ${projected[1]})`)
          .attr('class', 'port-marker')
          .style('cursor', 'pointer')
          .on('click', () => selectPort(port.id));

        // Port icon
        portMarker.append('rect')
          .attr('x', -10)
          .attr('y', -10)
          .attr('width', 20)
          .attr('height', 20)
          .attr('fill', port.isPlayerOwned ? '#10b981' : '#6366f1')
          .attr('stroke', selectedPortId === port.id ? '#fbbf24' : '#fff')
          .attr('stroke-width', selectedPortId === port.id ? 3 : 1)
          .attr('rx', 3);

        // Port name
        portMarker.append('text')
          .attr('y', -15)
          .attr('text-anchor', 'middle')
          .attr('fill', 'white')
          .attr('font-size', '10px')
          .attr('font-weight', 'bold')
          .text(port.name);
      }
    });

    // Vessel tracking system
    const vesselGroup = svg.append('g').attr('class', 'vessels');
    
    // Create vessel icons
    const vessels: VesselIcon[] = fleet.map(ship => {
      const [lng, lat] = positionToLatLng(ship.position);
      return {
        id: ship.id,
        type: ship.type === ShipType.CARGO_PLANE ? 'plane' : 'ship',
        lat,
        lng,
        heading: 0, // Calculate from movement direction
        status: ship.status,
        name: ship.name
      };
    });

    // Draw vessels
    vessels.forEach(vessel => {
      const coords: [number, number] = [vessel.lng, vessel.lat];
      const projected = projection(coords);
      
      if (projected && projection.invert && projection.invert(projected)) {
        const vesselMarker = vesselGroup.append('g')
          .attr('transform', `translate(${projected[0]}, ${projected[1]})`)
          .attr('class', 'vessel-marker')
          .style('cursor', 'pointer')
          .on('click', () => selectShip(vessel.id));

        if (vessel.type === 'ship') {
          // Ship SVG icon
          vesselMarker.append('path')
            .attr('d', 'M0,-8 L-4,8 L4,8 Z')
            .attr('fill', '#3b82f6')
            .attr('stroke', selectedShipId === vessel.id ? '#fbbf24' : '#1e40af')
            .attr('stroke-width', selectedShipId === vessel.id ? 2 : 1)
            .attr('transform', `rotate(${vessel.heading})`);
        } else {
          // Plane SVG icon
          vesselMarker.append('path')
            .attr('d', 'M0,-10 L-8,5 L-2,3 L-2,8 L2,8 L2,3 L8,5 Z')
            .attr('fill', '#ef4444')
            .attr('stroke', selectedShipId === vessel.id ? '#fbbf24' : '#991b1b')
            .attr('stroke-width', selectedShipId === vessel.id ? 2 : 1)
            .attr('transform', `rotate(${vessel.heading})`);
        }

        // Status indicator
        vesselMarker.append('circle')
          .attr('cx', 8)
          .attr('cy', -8)
          .attr('r', 3)
          .attr('fill', getStatusColor(vessel.status));

        // Vessel name
        vesselMarker.append('text')
          .attr('y', 15)
          .attr('text-anchor', 'middle')
          .attr('fill', 'white')
          .attr('font-size', '9px')
          .text(vessel.name);
      }
    });

    // Draw routes
    fleet.forEach(ship => {
      if (ship.destination && ship.status === ShipStatus.SAILING) {
        const startCoords = positionToLatLng(ship.position);
        const endCoords = positionToLatLng(ship.destination.position);
        
        // Create great circle path
        const route = {
          type: 'LineString' as const,
          coordinates: generateGreatCirclePoints(startCoords, endCoords)
        };

        svg.append('path')
          .datum(route as any)
          .attr('d', path as any)
          .attr('fill', 'none')
          .attr('stroke', '#3b82f6')
          .attr('stroke-width', 2)
          .attr('stroke-dasharray', '5,5')
          .attr('opacity', 0.6);
      }
    });

  }, [fleet, ports, rotation, selectedShipId, selectedPortId, selectShip, selectPort, zoomScale]);

  // Helper function to get status color
  const getStatusColor = (status: ShipStatus): string => {
    const colors = {
      [ShipStatus.IDLE]: '#10b981',
      [ShipStatus.SAILING]: '#3b82f6',
      [ShipStatus.LOADING]: '#f59e0b',
      [ShipStatus.UNLOADING]: '#f59e0b',
      [ShipStatus.MAINTENANCE]: '#ef4444',
    };
    return colors[status] || '#6b7280';
  };

  // Generate great circle points with Pacific crossing support
  const generateGreatCirclePoints = (
    start: [number, number], 
    end: [number, number], 
    numPoints: number = 50
  ): [number, number][] => {
    const points: [number, number][] = [];
    const [startLng, startLat] = start;
    const [endLng, endLat] = end;
    
    // Handle Pacific crossing
    let adjustedEndLng = endLng;
    const directDistance = Math.abs(endLng - startLng);
    
    if (directDistance > 180) {
      // Cross the date line
      if (startLng < 0 && endLng > 0) {
        adjustedEndLng = endLng - 360;
      } else if (startLng > 0 && endLng < 0) {
        adjustedEndLng = endLng + 360;
      }
    }
    
    // Generate interpolated points
    for (let i = 0; i <= numPoints; i++) {
      const t = i / numPoints;
      const lat = startLat + (endLat - startLat) * t;
      let lng = startLng + (adjustedEndLng - startLng) * t;
      
      // Normalize longitude
      while (lng > 180) lng -= 360;
      while (lng < -180) lng += 360;
      
      points.push([lng, lat]);
    }
    
    return points;
  };

  return (
    <div className="globe-map-container">
      <div className="globe-controls">
        <button onClick={() => { setRotation([0, -20, 0]); setZoomScale(250); }}>🌍 Reset View</button>
        <span className="zoom-indicator">Zoom: {Math.round((zoomScale / 250) * 100)}%</span>
      </div>
      <svg ref={svgRef} className="globe-map" />
      <div className="tracking-info">
        <h3>🛩️ Air Traffic Control</h3>
        <div className="vessel-count">
          <span>Active Vessels: {fleet.filter(s => s.status === ShipStatus.SAILING).length}</span>
          <span>Ships: {fleet.filter(s => s.type !== ShipType.CARGO_PLANE).length}</span>
          <span>Planes: {fleet.filter(s => s.type === ShipType.CARGO_PLANE).length}</span>
        </div>
      </div>
    </div>
  );
};