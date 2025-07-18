import React, { useEffect, useRef } from 'react';
import mapboxgl from 'mapbox-gl';
import { useGameStore } from '../store/gameStore';
import 'mapbox-gl/dist/mapbox-gl.css';
import './MapboxGlobe.css';

// Set your Mapbox access token
mapboxgl.accessToken = process.env.REACT_APP_MAPBOX_TOKEN || 'pk.eyJ1IjoiamZ1Z2luYXkiLCJhIjoiY21icmNha2hrMGE0azJscHVzdmVuZTVjOSJ9.oiJoYvc_G-tLUmaSzGVsVQ';

interface MapboxGlobeProps {
  className?: string;
}

export const MapboxGlobe: React.FC<MapboxGlobeProps> = ({ className }) => {
  const mapContainer = useRef<HTMLDivElement>(null);
  const map = useRef<mapboxgl.Map | null>(null);
  const shipMarkers = useRef<Map<string, mapboxgl.Marker>>(new Map());
  const [isMapLoaded, setIsMapLoaded] = React.useState(false);
  
  const { fleet, ports, selectedShipId, selectShip, selectPort } = useGameStore();
  
  // Initialize map
  useEffect(() => {
    if (!mapContainer.current || map.current) return;
    
    // Create new map instance with enhanced settings
    map.current = new mapboxgl.Map({
      container: mapContainer.current,
      style: 'mapbox://styles/mapbox/satellite-streets-v12', // Using satellite style
      projection: 'globe', // Enable globe projection
      center: [0, 20],
      zoom: 2.5,
      pitch: 0,
      bearing: 0,
      antialias: true,
      hash: false,
      renderWorldCopies: false, // Single globe
      maxPitch: 85,
      minZoom: 1.5,
      maxZoom: 20
    });
    
    // Add navigation controls
    map.current.addControl(new mapboxgl.NavigationControl(), 'top-right');
    
    // Configure globe settings
    map.current.on('style.load', () => {
      if (!map.current) return;
      
      // Set enhanced fog for atmosphere effect
      map.current.setFog({
        color: 'rgb(186, 210, 235)', // Sky color
        'high-color': 'rgb(36, 92, 223)', // Sky color at higher altitudes
        'horizon-blend': 0.02, // Atmosphere thickness
        'space-color': 'rgb(11, 11, 25)', // Space color
        'star-intensity': 0.8 // Star brightness
      });
      
      // Add beautiful lighting
      map.current.setLight({
        anchor: 'viewport',
        color: 'white',
        intensity: 0.4,
        position: [1.5, 90, 80]
      });
      
      // Add 3D terrain if available
      map.current.addSource('mapbox-dem', {
        type: 'raster-dem',
        url: 'mapbox://mapbox.mapbox-terrain-dem-v1',
        tileSize: 512,
        maxzoom: 14
      });
      
      // Enable 3D terrain
      map.current.setTerrain({ source: 'mapbox-dem', exaggeration: 1.5 });
      
      // Add ports as a data source
      if (ports.length > 0) {
        addPortsLayer();
      }
      
      // Set up event handlers
      setupEventHandlers();
    });
    
    // Smooth globe rotation
    let rotationAnimation: number;
    let isUserInteracting = false;
    let lastInteractionTime = 0;
    
    const rotateGlobe = () => {
      if (!map.current || isUserInteracting) {
        rotationAnimation = requestAnimationFrame(rotateGlobe);
        return;
      }
      
      // Resume rotation after 3 seconds of no interaction
      if (Date.now() - lastInteractionTime > 3000) {
        const center = map.current.getCenter();
        center.lng += 0.05; // Slower, smoother rotation
        map.current.easeTo({
          center: center,
          duration: 100,
          easing: (t) => t // Linear easing
        });
      }
      
      rotationAnimation = requestAnimationFrame(rotateGlobe);
    };
    
    // Start rotation and initial animation after map loads
    map.current.on('load', () => {
      setIsMapLoaded(true);
      
      // Dramatic initial zoom in
      map.current?.flyTo({
        center: [0, 20],
        zoom: 2.5,
        pitch: 45,
        bearing: 0,
        duration: 3000,
        essential: true
      });
      
      // Start rotation animation
      rotationAnimation = requestAnimationFrame(rotateGlobe);
    });
    
    // Handle user interaction
    const handleInteractionStart = () => {
      isUserInteracting = true;
      lastInteractionTime = Date.now();
    };
    
    const handleInteractionEnd = () => {
      isUserInteracting = false;
      lastInteractionTime = Date.now();
    };
    
    map.current.on('mousedown', handleInteractionStart);
    map.current.on('mouseup', handleInteractionEnd);
    map.current.on('touchstart', handleInteractionStart);
    map.current.on('touchend', handleInteractionEnd);
    map.current.on('wheel', () => {
      isUserInteracting = true;
      lastInteractionTime = Date.now();
      setTimeout(() => { isUserInteracting = false; }, 100);
    });
    
    // Cleanup
    return () => {
      cancelAnimationFrame(rotationAnimation);
      map.current?.remove();
      map.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  
  // Add ports layer
  const addPortsLayer = () => {
    if (!map.current || ports.length === 0) return;
    
    // Create GeoJSON from ports
    const portsGeoJSON: GeoJSON.FeatureCollection = {
      type: 'FeatureCollection',
      features: ports.map(port => ({
        type: 'Feature',
        properties: {
          id: port.id,
          name: port.name,
          country: port.country,
          capacity: port.capacity,
          currentLoad: port.currentLoad,
          availableBerths: port.availableBerths,
          isPlayerOwned: port.isPlayerOwned
        },
        geometry: {
          type: 'Point',
          coordinates: [port.position.x, port.position.z] // Using x as lng, z as lat
        }
      }))
    };
    
    // Add ports source
    map.current.addSource('ports', {
      type: 'geojson',
      data: portsGeoJSON,
      cluster: true,
      clusterMaxZoom: 10,
      clusterRadius: 50
    });
    
    // Add clustered ports layer
    map.current.addLayer({
      id: 'port-clusters',
      type: 'circle',
      source: 'ports',
      filter: ['has', 'point_count'],
      paint: {
        'circle-color': [
          'step',
          ['get', 'point_count'],
          '#51bbd6',
          10,
          '#f1f075',
          20,
          '#f28cb1'
        ],
        'circle-radius': [
          'step',
          ['get', 'point_count'],
          20,
          10,
          30,
          20,
          40
        ],
        'circle-stroke-width': 2,
        'circle-stroke-color': '#ffffff'
      }
    });
    
    // Add cluster count labels
    map.current.addLayer({
      id: 'port-cluster-count',
      type: 'symbol',
      source: 'ports',
      filter: ['has', 'point_count'],
      layout: {
        'text-field': '{point_count_abbreviated}',
        'text-font': ['DIN Offc Pro Medium', 'Arial Unicode MS Bold'],
        'text-size': 12
      }
    });
    
    // Add individual ports layer with dynamic styling
    map.current.addLayer({
      id: 'unclustered-ports',
      type: 'circle',
      source: 'ports',
      filter: ['!', ['has', 'point_count']],
      paint: {
        'circle-color': [
          'case',
          ['get', 'isPlayerOwned'],
          '#4ade80', // Green for player-owned
          '#3b82f6'  // Blue for other ports
        ],
        'circle-radius': [
          'interpolate',
          ['linear'],
          ['get', 'capacity'],
          0, 6,
          100, 10,
          1000, 15
        ],
        'circle-stroke-width': 2,
        'circle-stroke-color': '#ffffff',
        'circle-stroke-opacity': 0.8,
        'circle-opacity': 0.9
      }
    });
    
    // Add port labels
    map.current.addLayer({
      id: 'port-labels',
      type: 'symbol',
      source: 'ports',
      filter: ['!', ['has', 'point_count']],
      layout: {
        'text-field': ['get', 'name'],
        'text-font': ['DIN Offc Pro Medium', 'Arial Unicode MS Bold'],
        'text-size': 12,
        'text-offset': [0, 1.5],
        'text-anchor': 'top'
      },
      paint: {
        'text-color': '#ffffff',
        'text-halo-color': '#000000',
        'text-halo-width': 1
      }
    });
  };
  
  // Setup event handlers
  const setupEventHandlers = () => {
    if (!map.current) return;
    
    // Port click handler with popup
    map.current.on('click', 'unclustered-ports', (e) => {
      if (!e.features || !e.features[0]) return;
      
      const feature = e.features[0];
      const portId = feature.properties?.id;
      const coordinates = (feature.geometry as GeoJSON.Point).coordinates.slice() as [number, number];
      
      // Create popup content
      const popupContent = `
        <div class="port-popup">
          <h3>${feature.properties?.name}</h3>
          <div class="port-info">
            <div class="info-row">
              <span class="info-label">Country:</span>
              <span class="info-value">${feature.properties?.country}</span>
            </div>
            <div class="info-row">
              <span class="info-label">Capacity:</span>
              <span class="info-value">${feature.properties?.capacity} TEU</span>
            </div>
            <div class="info-row">
              <span class="info-label">Current Load:</span>
              <span class="info-value">${Math.round((feature.properties?.currentLoad / feature.properties?.capacity) * 100)}%</span>
            </div>
            <div class="info-row">
              <span class="info-label">Available Berths:</span>
              <span class="info-value">${feature.properties?.availableBerths}</span>
            </div>
            ${feature.properties?.isPlayerOwned ? '<div class="info-row"><span class="info-label" style="color: #4ade80;">✓ Player Owned</span></div>' : ''}
          </div>
        </div>
      `;
      
      // Create and show popup
      new mapboxgl.Popup({ 
        closeButton: true,
        closeOnClick: true,
        offset: 25
      })
        .setLngLat(coordinates)
        .setHTML(popupContent)
        .addTo(map.current!);
      
      if (portId) {
        selectPort(portId);
        
        // Smooth fly to port
        map.current?.flyTo({
          center: coordinates,
          zoom: 10,
          pitch: 60,
          bearing: 20,
          duration: 2500,
          essential: true
        });
      }
    });
    
    // Port hover effects
    map.current.on('mouseenter', 'unclustered-ports', () => {
      if (map.current) {
        map.current.getCanvas().style.cursor = 'pointer';
      }
    });
    
    map.current.on('mouseleave', 'unclustered-ports', () => {
      if (map.current) {
        map.current.getCanvas().style.cursor = '';
      }
    });
    
    // Cluster click - zoom in
    map.current.on('click', 'port-clusters', (e) => {
      if (!map.current || !e.features || !e.features[0]) return;
      
      const clusterId = e.features[0].properties?.cluster_id;
      const source = map.current.getSource('ports') as mapboxgl.GeoJSONSource;
      
      source.getClusterExpansionZoom(clusterId, (err, zoom) => {
        if (err || !map.current || zoom === null || zoom === undefined) return;
        
        map.current.easeTo({
          center: (e.features![0].geometry as GeoJSON.Point).coordinates as [number, number],
          zoom: zoom + 1
        });
      });
    });
  };
  
  // Update ship markers
  useEffect(() => {
    if (!map.current) return;
    
    // Remove old markers that no longer exist
    shipMarkers.current.forEach((marker, shipId) => {
      if (!fleet.find(s => s.id === shipId)) {
        marker.remove();
        shipMarkers.current.delete(shipId);
      }
    });
    
    // Update or create markers for each ship
    fleet.forEach(ship => {
      let marker = shipMarkers.current.get(ship.id);
      
      if (!marker) {
        // Create custom ship element with enhanced design
        const el = document.createElement('div');
        el.className = 'ship-marker';
        el.innerHTML = `
          <div style="
            width: 40px;
            height: 40px;
            background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
            border-radius: 50%;
            box-shadow: 0 4px 12px rgba(59, 130, 246, 0.4);
            display: flex;
            align-items: center;
            justify-content: center;
            position: relative;
            animation: pulse 2s infinite;
          ">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="white">
              <path d="M12 2L2 7v10c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V7l-10-5z"/>
            </svg>
            ${ship.status === 'SAILING' ? `
              <div style="
                position: absolute;
                width: 100%;
                height: 100%;
                border: 2px solid #3b82f6;
                border-radius: 50%;
                animation: radar 2s infinite;
              "></div>
            ` : ''}
          </div>
        `;
        el.style.cursor = 'pointer';
        
        // Add CSS animations
        if (!document.querySelector('#ship-marker-styles')) {
          const style = document.createElement('style');
          style.id = 'ship-marker-styles';
          style.textContent = `
            @keyframes pulse {
              0% { transform: scale(1); }
              50% { transform: scale(1.05); }
              100% { transform: scale(1); }
            }
            @keyframes radar {
              0% { 
                transform: scale(1);
                opacity: 1;
              }
              100% { 
                transform: scale(1.5);
                opacity: 0;
              }
            }
          `;
          document.head.appendChild(style);
        }
        
        // Add click handler
        el.addEventListener('click', () => {
          selectShip(ship.id);
          
          // Fly to ship
          map.current?.flyTo({
            center: [ship.position.x, ship.position.z],
            zoom: 10,
            pitch: 0,
            bearing: 0,
            duration: 1500
          });
        });
        
        // Create marker
        marker = new mapboxgl.Marker({
          element: el,
          rotation: 0,
          pitchAlignment: 'viewport',
          rotationAlignment: 'viewport'
        })
          .setLngLat([ship.position.x, ship.position.z]);
        
        if (map.current) {
          marker.addTo(map.current);
        }
        
        shipMarkers.current.set(ship.id, marker);
      } else {
        // Update marker position
        marker.setLngLat([ship.position.x, ship.position.z]);
        
        // Rotate marker based on ship heading
        if (ship.destination) {
          const dx = ship.destination.position.x - ship.position.x;
          const dy = ship.destination.position.z - ship.position.z;
          const angle = Math.atan2(dx, -dy) * (180 / Math.PI);
          marker.setRotation(angle);
        }
      }
      
      // Update marker style based on selection
      const el = marker.getElement();
      if (ship.id === selectedShipId) {
        el.style.filter = 'drop-shadow(0 0 10px #3b82f6)';
        el.style.transform = 'scale(1.2)';
      } else {
        el.style.filter = '';
        el.style.transform = '';
      }
    });
  }, [fleet, selectedShipId, selectShip]);
  
  // Add ship routes
  useEffect(() => {
    if (!map.current) return;
    
    // Remove existing routes
    if (map.current.getSource('ship-routes')) {
      map.current.removeLayer('ship-routes');
      map.current.removeSource('ship-routes');
    }
    
    // Create routes GeoJSON
    const routes: GeoJSON.Feature[] = fleet
      .filter(ship => ship.destination)
      .map(ship => ({
        type: 'Feature',
        properties: {
          shipId: ship.id,
          selected: ship.id === selectedShipId
        },
        geometry: {
          type: 'LineString',
          coordinates: [
            [ship.position.x, ship.position.z],
            [ship.destination!.position.x, ship.destination!.position.z]
          ]
        }
      }));
    
    if (routes.length > 0) {
      // Add routes source
      map.current.addSource('ship-routes', {
        type: 'geojson',
        data: {
          type: 'FeatureCollection',
          features: routes
        }
      });
      
      // Add routes layer with gradient effect
      map.current.addLayer({
        id: 'ship-routes',
        type: 'line',
        source: 'ship-routes',
        layout: {
          'line-join': 'round',
          'line-cap': 'round'
        },
        paint: {
          'line-color': [
            'case',
            ['get', 'selected'],
            '#3b82f6',
            '#64748b'
          ],
          'line-width': [
            'case',
            ['get', 'selected'],
            4,
            2
          ],
          'line-opacity': [
            'case',
            ['get', 'selected'],
            0.9,
            0.6
          ],
          'line-dasharray': [0.1, 2],
          'line-blur': 0.5
        }
      });
      
      // Add animated dashed overlay for selected routes
      map.current.addLayer({
        id: 'ship-routes-animated',
        type: 'line',
        source: 'ship-routes',
        filter: ['==', 'selected', true],
        layout: {
          'line-join': 'round',
          'line-cap': 'round'
        },
        paint: {
          'line-color': '#60a5fa',
          'line-width': 2,
          'line-opacity': 0.8,
          'line-dasharray': [2, 4],
          'line-offset': 0
        }
      });
    }
  }, [fleet, selectedShipId]);
  
  return (
    <div style={{ width: '100%', height: '100%', position: 'relative' }}>
      <div 
        ref={mapContainer} 
        className={`mapbox-globe-container ${className || ''}`}
        style={{ width: '100%', height: '100%' }}
      />
      {!isMapLoaded && (
        <div style={{
          position: 'absolute',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          background: '#000814',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 1000
        }}>
          <div className="mapbox-globe-loading"></div>
        </div>
      )}
    </div>
  );
};