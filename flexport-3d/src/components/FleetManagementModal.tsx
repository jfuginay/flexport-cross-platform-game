import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { X, Ship, Anchor, TrendingUp, AlertCircle, Navigation, Package, DollarSign, Clock, MapPin, Activity } from 'lucide-react';
import { useGameStore } from '../store/gameStore';
import { Ship as ShipType, ShipStatus } from '../types/game.types';
import './FleetManagementModal.css';

interface FleetManagementModalProps {
  isOpen: boolean;
  onClose: () => void;
}

interface FleetStats {
  totalShips: number;
  activeShips: number;
  idleShips: number;
  totalCapacity: number;
  totalRevenue: number;
  maintenanceCost: number;
}

export const FleetManagementModal: React.FC<FleetManagementModalProps> = ({ isOpen, onClose }) => {
  const { fleet: ships, ports, contracts } = useGameStore();
  const [selectedShip, setSelectedShip] = useState<string | null>(null);
  const [fleetStats, setFleetStats] = useState<FleetStats>({
    totalShips: 0,
    activeShips: 0,
    idleShips: 0,
    totalCapacity: 0,
    totalRevenue: 0,
    maintenanceCost: 0
  });

  useEffect(() => {
    // Calculate fleet statistics
    const stats: FleetStats = {
      totalShips: ships.length,
      activeShips: ships.filter((s: ShipType) => s.status === ShipStatus.SAILING || s.status === ShipStatus.LOADING).length,
      idleShips: ships.filter((s: ShipType) => s.status === ShipStatus.IDLE).length,
      totalCapacity: ships.reduce((sum: number, ship: ShipType) => sum + ship.capacity, 0),
      totalRevenue: ships.reduce((sum: number, ship: ShipType) => sum + (ship.totalEarnings || 0), 0),
      maintenanceCost: ships.reduce((sum: number, ship: ShipType) => sum + (ship.maintenanceCost || 10000), 0)
    };
    setFleetStats(stats);
  }, [ships]);

  const getShipStatusColor = (status: ShipStatus) => {
    switch (status) {
      case ShipStatus.SAILING: return '#4ade80';
      case ShipStatus.LOADING: return '#60a5fa';
      case ShipStatus.IDLE: return '#fbbf24';
      case ShipStatus.MAINTENANCE: return '#f87171';
      case ShipStatus.UNLOADING: return '#8b5cf6';
      default: return '#9ca3af';
    }
  };

  const getShipStatusIcon = (status: ShipStatus) => {
    switch (status) {
      case ShipStatus.SAILING: return <Navigation className="w-4 h-4" />;
      case ShipStatus.LOADING: return <Package className="w-4 h-4" />;
      case ShipStatus.IDLE: return <Anchor className="w-4 h-4" />;
      case ShipStatus.MAINTENANCE: return <AlertCircle className="w-4 h-4" />;
      case ShipStatus.UNLOADING: return <Package className="w-4 h-4" />;
      default: return <Ship className="w-4 h-4" />;
    }
  };

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0
    }).format(amount);
  };

  const formatDistance = (distance: number) => {
    return `${Math.round(distance).toLocaleString()} km`;
  };

  return (
    <AnimatePresence>
      {isOpen && (
        <>
          {/* Backdrop */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fleet-modal-backdrop"
            onClick={onClose}
          />

          {/* Modal */}
          <motion.div
            initial={{ opacity: 0, scale: 0.9, y: 20 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.9, y: 20 }}
            className="fleet-modal"
          >
            {/* Header */}
            <div className="fleet-modal-header">
              <div>
                <h2 className="fleet-modal-title">Fleet Management</h2>
                <p className="fleet-modal-subtitle">Monitor and manage your shipping fleet</p>
              </div>
              <button onClick={onClose} className="fleet-modal-close">
                <X />
              </button>
            </div>

            {/* Stats Overview */}
            <div className="fleet-stats-grid">
              <div className="fleet-stat-card">
                <div className="fleet-stat-icon">
                  <Ship />
                </div>
                <div className="fleet-stat-content">
                  <p className="fleet-stat-label">Total Fleet</p>
                  <p className="fleet-stat-value">{fleetStats.totalShips}</p>
                  <p className="fleet-stat-detail">{fleetStats.activeShips} active</p>
                </div>
              </div>

              <div className="fleet-stat-card">
                <div className="fleet-stat-icon" style={{ backgroundColor: '#4ade80' }}>
                  <Activity />
                </div>
                <div className="fleet-stat-content">
                  <p className="fleet-stat-label">Utilization</p>
                  <p className="fleet-stat-value">
                    {fleetStats.totalShips > 0 
                      ? Math.round((fleetStats.activeShips / fleetStats.totalShips) * 100)
                      : 0}%
                  </p>
                  <p className="fleet-stat-detail">{fleetStats.idleShips} idle</p>
                </div>
              </div>

              <div className="fleet-stat-card">
                <div className="fleet-stat-icon" style={{ backgroundColor: '#60a5fa' }}>
                  <Package />
                </div>
                <div className="fleet-stat-content">
                  <p className="fleet-stat-label">Total Capacity</p>
                  <p className="fleet-stat-value">{fleetStats.totalCapacity.toLocaleString()}</p>
                  <p className="fleet-stat-detail">TEU</p>
                </div>
              </div>

              <div className="fleet-stat-card">
                <div className="fleet-stat-icon" style={{ backgroundColor: '#a855f7' }}>
                  <DollarSign />
                </div>
                <div className="fleet-stat-content">
                  <p className="fleet-stat-label">Total Revenue</p>
                  <p className="fleet-stat-value">{formatCurrency(fleetStats.totalRevenue)}</p>
                  <p className="fleet-stat-detail">-{formatCurrency(fleetStats.maintenanceCost)} costs</p>
                </div>
              </div>
            </div>

            {/* Fleet List */}
            <div className="fleet-list-container">
              <h3 className="fleet-section-title">Your Fleet</h3>
              <div className="fleet-grid">
                {ships.map((ship: ShipType) => {
                  const currentPort = ports.find(p => p.id === ship.currentPortId);
                  const destinationPort = ship.destination || (ship.destinationPortId 
                    ? ports.find(p => p.id === ship.destinationPortId)
                    : null);
                  const contract = ship.contractId 
                    ? contracts.find(c => c.id === ship.contractId)
                    : null;
                  const currentCapacityUsed = ship.currentCapacityUsed || ship.cargo?.length || 0;

                  return (
                    <motion.div
                      key={ship.id}
                      layout
                      initial={{ opacity: 0, scale: 0.8 }}
                      animate={{ opacity: 1, scale: 1 }}
                      whileHover={{ scale: 1.02 }}
                      className={`fleet-card ${selectedShip === ship.id ? 'selected' : ''}`}
                      onClick={() => setSelectedShip(ship.id)}
                    >
                      <div className="fleet-card-header">
                        <div className="fleet-card-title">
                          <Ship className="w-5 h-5" />
                          <span>{ship.name}</span>
                        </div>
                        <div 
                          className="fleet-card-status"
                          style={{ backgroundColor: getShipStatusColor(ship.status) }}
                        >
                          {getShipStatusIcon(ship.status)}
                          <span>{ship.status.toLowerCase()}</span>
                        </div>
                      </div>

                      <div className="fleet-card-body">
                        <div className="fleet-card-info">
                          <div className="fleet-info-item">
                            <MapPin className="w-4 h-4" />
                            <span>
                              {currentPort?.name || 'In Transit'}
                              {destinationPort && ` → ${destinationPort.name}`}
                            </span>
                          </div>

                          <div className="fleet-info-item">
                            <Package className="w-4 h-4" />
                            <span>
                              {currentCapacityUsed} / {ship.capacity} TEU
                            </span>
                          </div>

                          {contract && (
                            <div className="fleet-info-item">
                              <DollarSign className="w-4 h-4" />
                              <span>{formatCurrency(contract.payment)}</span>
                            </div>
                          )}

                          {ship.speed && (
                            <div className="fleet-info-item">
                              <Clock className="w-4 h-4" />
                              <span>{ship.speed} knots</span>
                            </div>
                          )}
                        </div>

                        <div className="fleet-card-progress">
                          <div className="progress-bar">
                            <div 
                              className="progress-fill"
                              style={{ 
                                width: `${(currentCapacityUsed / ship.capacity) * 100}%`,
                                backgroundColor: currentCapacityUsed > 0 ? '#4ade80' : '#6b7280'
                              }}
                            />
                          </div>
                          <span className="progress-label">
                            {Math.round((currentCapacityUsed / ship.capacity) * 100)}% loaded
                          </span>
                        </div>

                        {ship.totalEarnings !== undefined && (
                          <div className="fleet-card-earnings">
                            <TrendingUp className="w-4 h-4" />
                            <span>Lifetime: {formatCurrency(ship.totalEarnings)}</span>
                          </div>
                        )}
                      </div>

                      {selectedShip === ship.id && (
                        <motion.div
                          initial={{ height: 0, opacity: 0 }}
                          animate={{ height: 'auto', opacity: 1 }}
                          exit={{ height: 0, opacity: 0 }}
                          className="fleet-card-details"
                        >
                          <div className="detail-item">
                            <span className="detail-label">Type:</span>
                            <span className="detail-value">{ship.type}</span>
                          </div>
                          <div className="detail-item">
                            <span className="detail-label">Health:</span>
                            <span className="detail-value">{ship.health}%</span>
                          </div>
                          <div className="detail-item">
                            <span className="detail-label">Fuel:</span>
                            <span className="detail-value">{ship.fuel}%</span>
                          </div>
                          {ship.totalDistance !== undefined && (
                            <div className="detail-item">
                              <span className="detail-label">Distance Traveled:</span>
                              <span className="detail-value">{formatDistance(ship.totalDistance)}</span>
                            </div>
                          )}
                        </motion.div>
                      )}
                    </motion.div>
                  );
                })}

                {/* Add New Ship Card */}
                <motion.div
                  layout
                  whileHover={{ scale: 1.02 }}
                  className="fleet-card add-ship-card"
                  onClick={() => {
                    // Handle add ship action
                    console.log('Add new ship');
                  }}
                >
                  <div className="add-ship-content">
                    <div className="add-ship-icon">+</div>
                    <span>Purchase New Ship</span>
                  </div>
                </motion.div>
              </div>
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
};