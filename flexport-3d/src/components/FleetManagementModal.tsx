// @ts-nocheck
import React, { useState, useEffect } from 'react';
import ReactDOM from 'react-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { X, Ship, Anchor, TrendingUp, AlertCircle, Navigation, Package, DollarSign, Clock, MapPin, Activity, Truck, Droplet, Plane } from 'lucide-react';
import { useGameStore } from '../store/gameStore';
import { Ship as ShipInterface, ShipStatus, ShipType } from '../types/game.types';
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
  const { fleet: allShips, ports, contracts, money, purchaseShip } = useGameStore();
  const [selectedShip, setSelectedShip] = useState<string | null>(null);
  const [showPurchaseView, setShowPurchaseView] = useState(false);
  const [selectedShipType, setSelectedShipType] = useState<ShipType | null>(null);
  const [newShipName, setNewShipName] = useState('');
  
  // Filter to show only player-owned ships
  const ships = allShips.filter(ship => ship.ownerId === 'player' || !ship.ownerId);
  
  // Auto-show purchase view if player has no ships
  useEffect(() => {
    if (ships.length === 0 && isOpen) {
      setShowPurchaseView(true);
    }
  }, [ships.length, isOpen]);
  
  // Ship type configurations
  const shipTypes = [
    {
      type: ShipType.CONTAINER,
      name: 'Container Ship',
      icon: <Package className="w-8 h-8" />,
      cost: 20000000,
      capacity: 20000,
      speed: 0.5,
      description: 'Standard cargo vessel for containers'
    },
    {
      type: ShipType.BULK,
      name: 'Bulk Carrier',
      icon: <Truck className="w-8 h-8" />,
      cost: 15000000,
      capacity: 30000,
      speed: 0.3,
      description: 'Large capacity for bulk goods'
    },
    {
      type: ShipType.TANKER,
      name: 'Oil Tanker',
      icon: <Droplet className="w-8 h-8" />,
      cost: 25000000,
      capacity: 25000,
      speed: 0.4,
      description: 'Specialized for liquid cargo'
    },
    {
      type: ShipType.CARGO_PLANE,
      name: 'Cargo Plane',
      icon: <Plane className="w-8 h-8" />,
      cost: 50000000,
      capacity: 500,
      speed: 2.0,
      description: 'Fast air transport for urgent cargo'
    }
  ];
  
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
      activeShips: ships.filter((s: ShipInterface) => s.status === ShipStatus.SAILING || s.status === ShipStatus.LOADING).length,
      idleShips: ships.filter((s: ShipInterface) => s.status === ShipStatus.IDLE).length,
      totalCapacity: ships.reduce((sum: number, ship: ShipInterface) => sum + ship.capacity, 0),
      totalRevenue: ships.reduce((sum: number, ship: ShipInterface) => sum + (ship.totalEarnings || 0), 0),
      maintenanceCost: ships.reduce((sum: number, ship: ShipInterface) => sum + (ship.maintenanceCost || 10000), 0)
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

  return ReactDOM.createPortal(
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
            initial={{ x: '100%', opacity: 0 }}
            animate={{ x: 0, opacity: 1 }}
            exit={{ x: '100%', opacity: 0 }}
            transition={{ type: 'spring', damping: 25, stiffness: 200 }}
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

            {/* Fleet List or Purchase View */}
            <div className="fleet-list-container">
              {!showPurchaseView ? (
                <>
                  <h3 className="fleet-section-title">Your Fleet</h3>
                  {ships.length === 0 ? (
                    <div className="empty-fleet-guidance">
                      <div className="guidance-icon">🚢</div>
                      <h3>Welcome to FlexPort Global!</h3>
                      <p>You don't have any ships yet. Every shipping empire starts with a single vessel.</p>
                      <p className="guidance-tip">💡 With your starting capital of $50M, you can afford:</p>
                      <ul className="ship-options">
                        <li>🚢 <strong>2 Container Ships</strong> - Great all-around vessels for general cargo</li>
                        <li>📦 <strong>3 Bulk Carriers</strong> - Perfect for large volume contracts</li>
                        <li>🛢️ <strong>2 Tankers</strong> - Specialized for liquid cargo with premium rates</li>
                        <li>✈️ <strong>1 Cargo Plane</strong> - Fast delivery for time-sensitive contracts</li>
                      </ul>
                      <button 
                        className="purchase-first-ship-button"
                        onClick={() => setShowPurchaseView(true)}
                      >
                        Purchase Your First Ship →
                      </button>
                    </div>
                  ) : (
                  <div className="fleet-grid">
                    {ships.map((ship: ShipInterface) => {
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
                    setShowPurchaseView(true);
                    setSelectedShipType(null);
                    setNewShipName('');
                  }}
                >
                  <div className="add-ship-content">
                    <div className="add-ship-icon">+</div>
                    <span>Purchase New Ship</span>
                  </div>
                </motion.div>
                  </div>
                  )}
                </>
              ) : (
                /* Purchase Ship View */
                <div className="purchase-ship-view">
                  <div className="purchase-header">
                    <button 
                      className="back-button"
                      onClick={() => setShowPurchaseView(false)}
                    >
                      ← Back to Fleet
                    </button>
                    <h3 className="fleet-section-title">Purchase New Ship</h3>
                    <div className="current-money">
                      Balance: {formatCurrency(money)}
                    </div>
                  </div>
                  
                  <div className="ship-types-grid">
                    {shipTypes.map((shipType) => (
                      <motion.div
                        key={shipType.type}
                        whileHover={{ scale: 1.02 }}
                        whileTap={{ scale: 0.98 }}
                        className={`ship-type-card ${selectedShipType === shipType.type ? 'selected' : ''} ${money < shipType.cost ? 'disabled' : ''}`}
                        onClick={() => {
                          if (money >= shipType.cost) {
                            setSelectedShipType(shipType.type);
                            setNewShipName(shipType.name + ' ' + (ships.length + 1));
                          }
                        }}
                      >
                        <div className="ship-type-icon">{shipType.icon}</div>
                        <h4 className="ship-type-name">{shipType.name}</h4>
                        <p className="ship-type-description">{shipType.description}</p>
                        
                        <div className="ship-type-stats">
                          <div className="stat">
                            <span className="stat-label">Capacity</span>
                            <span className="stat-value">{shipType.capacity.toLocaleString()} TEU</span>
                          </div>
                          <div className="stat">
                            <span className="stat-label">Speed</span>
                            <span className="stat-value">{shipType.speed} knots</span>
                          </div>
                        </div>
                        
                        <div className="ship-type-cost">
                          {formatCurrency(shipType.cost)}
                        </div>
                        
                        {money < shipType.cost && (
                          <div className="insufficient-funds">Insufficient funds</div>
                        )}
                      </motion.div>
                    ))}
                  </div>
                  
                  {selectedShipType && (
                    <motion.div
                      initial={{ opacity: 0, y: 20 }}
                      animate={{ opacity: 1, y: 0 }}
                      className="purchase-form"
                    >
                      <div className="ship-name-input">
                        <label>Ship Name</label>
                        <input
                          type="text"
                          value={newShipName}
                          onChange={(e) => setNewShipName(e.target.value)}
                          placeholder="Enter ship name..."
                          maxLength={50}
                        />
                      </div>
                      
                      <button
                        className="purchase-button"
                        onClick={() => {
                          if (selectedShipType && newShipName.trim()) {
                            purchaseShip(selectedShipType, newShipName.trim());
                            setShowPurchaseView(false);
                            setSelectedShipType(null);
                            setNewShipName('');
                          }
                        }}
                        disabled={!newShipName.trim()}
                      >
                        Purchase {shipTypes.find(s => s.type === selectedShipType)?.name}
                      </button>
                    </motion.div>
                  )}
                </div>
              )}
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>,
    document.body
  );
};