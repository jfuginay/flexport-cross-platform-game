import { Ship, Coordinates, ShipStatus, MessageType, WebSocketMessage } from '@/types';
import { WebSocketManager } from './WebSocketManager';

interface ShipUpdate {
  shipId: string;
  playerId: string;
  position: Coordinates;
  destination?: string;
  status: ShipStatus;
  rotation: number;
  speed: number;
  timestamp: number;
}

interface ShipDelta {
  shipId: string;
  playerId: string;
  changes: Partial<{
    position: Coordinates;
    destination: string | null;
    status: ShipStatus;
    rotation: number;
    speed: number;
  }>;
  timestamp: number;
}

interface InterpolatedShip {
  ship: Ship;
  targetPosition: Coordinates;
  targetRotation: number;
  lastUpdate: number;
  interpolationProgress: number;
  velocity: { lat: number; lng: number };
}

export class StateSynchronization {
  private wsManager: WebSocketManager;
  private localShips: Map<string, Ship> = new Map();
  private remoteShips: Map<string, Map<string, InterpolatedShip>> = new Map(); // playerId -> shipId -> ship
  private lastShipStates: Map<string, ShipUpdate> = new Map();
  private updateInterval: number = 50; // 50ms = 20 updates per second
  private syncInterval: number = 100; // Send updates every 100ms
  private interpolationDuration: number = 150; // Interpolate over 150ms
  private lastSyncTime: number = 0;
  private updateTimer: NodeJS.Timeout | null = null;
  private syncTimer: NodeJS.Timeout | null = null;
  private onShipUpdateCallback: ((ships: Map<string, Ship[]>) => void) | null = null;
  private reconciliationBuffer: Map<string, ShipUpdate[]> = new Map();
  private sequenceNumber: number = 0;
  private clientPrediction: boolean = true;
  private serverReconciliation: boolean = true;
  private interpolationEnabled: boolean = true;

  constructor(wsManager: WebSocketManager) {
    this.wsManager = wsManager;
    this.setupMessageHandlers();
  }

  private setupMessageHandlers(): void {
    // Handle ship state updates from other players
    this.wsManager.onMessage('ship_update' as MessageType, (message: WebSocketMessage) => {
      this.handleShipUpdate(message.payload as ShipUpdate);
    });

    // Handle batch ship updates
    this.wsManager.onMessage('ship_batch_update' as MessageType, (message: WebSocketMessage) => {
      this.handleBatchShipUpdate(message.payload as { updates: ShipDelta[] });
    });

    // Handle full state sync (for new players joining)
    this.wsManager.onMessage('ship_full_sync' as MessageType, (message: WebSocketMessage) => {
      this.handleFullStateSync(message.payload as { ships: ShipUpdate[] });
    });

    // Handle ship reconciliation from server
    this.wsManager.onMessage('ship_reconciliation' as MessageType, (message: WebSocketMessage) => {
      this.handleReconciliation(message.payload as { shipId: string; authoritative: ShipUpdate });
    });
  }

  public start(): void {
    // Start update loop for interpolation
    this.updateTimer = setInterval(() => {
      this.updateInterpolation();
    }, this.updateInterval);

    // Start sync loop for sending updates
    this.syncTimer = setInterval(() => {
      this.sendShipUpdates();
    }, this.syncInterval);
  }

  public stop(): void {
    if (this.updateTimer) {
      clearInterval(this.updateTimer);
      this.updateTimer = null;
    }
    if (this.syncTimer) {
      clearInterval(this.syncTimer);
      this.syncTimer = null;
    }
  }

  public registerLocalShips(ships: Ship[]): void {
    this.localShips.clear();
    ships.forEach(ship => {
      this.localShips.set(ship.id, ship);
      // Initialize last state for delta compression
      this.lastShipStates.set(ship.id, this.createShipUpdate(ship));
    });
  }

  public updateLocalShip(ship: Ship): void {
    this.localShips.set(ship.id, ship);
    
    if (this.clientPrediction) {
      // Store update for potential reconciliation
      const update = this.createShipUpdate(ship);
      update.timestamp = Date.now();
      
      if (!this.reconciliationBuffer.has(ship.id)) {
        this.reconciliationBuffer.set(ship.id, []);
      }
      this.reconciliationBuffer.get(ship.id)!.push(update);
      
      // Keep only last 1 second of updates
      const cutoff = Date.now() - 1000;
      const buffer = this.reconciliationBuffer.get(ship.id)!;
      this.reconciliationBuffer.set(ship.id, buffer.filter(u => u.timestamp > cutoff));
    }
  }

  public onShipUpdate(callback: (ships: Map<string, Ship[]>) => void): void {
    this.onShipUpdateCallback = callback;
  }

  private createShipUpdate(ship: Ship): ShipUpdate {
    return {
      shipId: ship.id,
      playerId: this.wsManager.getPlayerId(),
      position: ship.currentLocation,
      destination: ship.destination,
      status: ship.status,
      rotation: 0, // Will be calculated based on movement direction
      speed: ship.speed,
      timestamp: Date.now()
    };
  }

  private sendShipUpdates(): void {
    if (!this.wsManager.isConnected() || this.localShips.size === 0) return;

    const now = Date.now();
    const deltas: ShipDelta[] = [];

    this.localShips.forEach((ship, shipId) => {
      const currentUpdate = this.createShipUpdate(ship);
      const lastUpdate = this.lastShipStates.get(shipId);

      if (!lastUpdate || this.hasSignificantChange(lastUpdate, currentUpdate)) {
        const delta = this.createDelta(lastUpdate, currentUpdate);
        deltas.push(delta);
        this.lastShipStates.set(shipId, currentUpdate);
      }
    });

    if (deltas.length > 0) {
      this.wsManager.sendMessage('ship_batch_update' as MessageType, {
        updates: deltas,
        sequence: this.sequenceNumber++,
        timestamp: now
      }, this.wsManager.getConnectionStats().playerId);

      this.lastSyncTime = now;
    }
  }

  private hasSignificantChange(oldUpdate: ShipUpdate, newUpdate: ShipUpdate): boolean {
    const positionThreshold = 0.001; // ~111 meters at equator
    const rotationThreshold = 0.1; // radians

    return (
      Math.abs(oldUpdate.position.latitude - newUpdate.position.latitude) > positionThreshold ||
      Math.abs(oldUpdate.position.longitude - newUpdate.position.longitude) > positionThreshold ||
      oldUpdate.status !== newUpdate.status ||
      oldUpdate.destination !== newUpdate.destination ||
      Math.abs(oldUpdate.rotation - newUpdate.rotation) > rotationThreshold
    );
  }

  private createDelta(lastUpdate: ShipUpdate | undefined, currentUpdate: ShipUpdate): ShipDelta {
    const delta: ShipDelta = {
      shipId: currentUpdate.shipId,
      playerId: currentUpdate.playerId,
      changes: {},
      timestamp: currentUpdate.timestamp
    };

    if (!lastUpdate) {
      // Full update for new ship
      delta.changes = {
        position: currentUpdate.position,
        destination: currentUpdate.destination || null,
        status: currentUpdate.status,
        rotation: currentUpdate.rotation,
        speed: currentUpdate.speed
      };
    } else {
      // Only send changed fields
      if (lastUpdate.position.latitude !== currentUpdate.position.latitude ||
          lastUpdate.position.longitude !== currentUpdate.position.longitude) {
        delta.changes.position = currentUpdate.position;
      }
      if (lastUpdate.destination !== currentUpdate.destination) {
        delta.changes.destination = currentUpdate.destination || null;
      }
      if (lastUpdate.status !== currentUpdate.status) {
        delta.changes.status = currentUpdate.status;
      }
      if (lastUpdate.rotation !== currentUpdate.rotation) {
        delta.changes.rotation = currentUpdate.rotation;
      }
      if (lastUpdate.speed !== currentUpdate.speed) {
        delta.changes.speed = currentUpdate.speed;
      }
    }

    return delta;
  }

  private handleShipUpdate(update: ShipUpdate): void {
    if (update.playerId === this.wsManager.getPlayerId()) {
      // Handle reconciliation for our own ships
      if (this.serverReconciliation) {
        this.reconcileLocalShip(update);
      }
      return;
    }

    // Update remote ship
    if (!this.remoteShips.has(update.playerId)) {
      this.remoteShips.set(update.playerId, new Map());
    }

    const playerShips = this.remoteShips.get(update.playerId)!;
    const existingShip = playerShips.get(update.shipId);

    if (existingShip) {
      // Update existing ship with interpolation
      this.updateRemoteShip(existingShip, update);
    } else {
      // Create new ship
      const newShip = this.createRemoteShip(update);
      playerShips.set(update.shipId, newShip);
    }

    this.notifyShipUpdate();
  }

  private handleBatchShipUpdate(payload: { updates: ShipDelta[] }): void {
    payload.updates.forEach(delta => {
      const update = this.applyDelta(delta);
      this.handleShipUpdate(update);
    });
  }

  private handleFullStateSync(payload: { ships: ShipUpdate[] }): void {
    // Clear all remote ships and rebuild from full sync
    this.remoteShips.clear();
    
    payload.ships.forEach(update => {
      if (update.playerId !== this.wsManager.getPlayerId()) {
        this.handleShipUpdate(update);
      }
    });
  }

  private handleReconciliation(payload: { shipId: string; authoritative: ShipUpdate }): void {
    if (!this.serverReconciliation) return;

    const localShip = this.localShips.get(payload.shipId);
    if (!localShip) return;

    // Apply server correction
    localShip.currentLocation = payload.authoritative.position;
    localShip.status = payload.authoritative.status;
    localShip.destination = payload.authoritative.destination;

    // Re-apply unacknowledged inputs
    const buffer = this.reconciliationBuffer.get(payload.shipId) || [];
    const authoritativeTime = payload.authoritative.timestamp;
    
    // Find and replay inputs after the authoritative update
    const unacknowledged = buffer.filter(u => u.timestamp > authoritativeTime);
    
    // This is simplified - in a real implementation, you'd replay the physics
    // for each unacknowledged input to get the corrected position
  }

  private applyDelta(delta: ShipDelta): ShipUpdate {
    // Find the last known state for this ship
    const lastUpdate = this.lastShipStates.get(delta.shipId) || {
      shipId: delta.shipId,
      playerId: delta.playerId,
      position: { latitude: 0, longitude: 0 },
      status: 'docked' as ShipStatus,
      rotation: 0,
      speed: 0,
      timestamp: delta.timestamp
    };

    // Apply changes
    const update: ShipUpdate = { ...lastUpdate, timestamp: delta.timestamp };
    
    if (delta.changes.position !== undefined) {
      update.position = delta.changes.position;
    }
    if (delta.changes.destination !== undefined) {
      update.destination = delta.changes.destination || undefined;
    }
    if (delta.changes.status !== undefined) {
      update.status = delta.changes.status;
    }
    if (delta.changes.rotation !== undefined) {
      update.rotation = delta.changes.rotation;
    }
    if (delta.changes.speed !== undefined) {
      update.speed = delta.changes.speed;
    }

    return update;
  }

  private createRemoteShip(update: ShipUpdate): InterpolatedShip {
    const ship: Ship = {
      id: update.shipId,
      name: `Player ${update.playerId.substring(0, 8)}`,
      type: 'container_ship', // Default type - could be sent in update
      capacity: 0,
      speed: update.speed,
      efficiency: 1,
      maintenanceCost: 0,
      currentLocation: update.position,
      destination: update.destination,
      status: update.status,
      cargo: [],
      crew: [],
      fuel: 1000,
      condition: 100
    };

    return {
      ship,
      targetPosition: update.position,
      targetRotation: update.rotation,
      lastUpdate: update.timestamp,
      interpolationProgress: 1,
      velocity: { lat: 0, lng: 0 }
    };
  }

  private updateRemoteShip(interpolatedShip: InterpolatedShip, update: ShipUpdate): void {
    const timeDelta = update.timestamp - interpolatedShip.lastUpdate;
    
    // Calculate velocity for dead reckoning
    if (timeDelta > 0) {
      interpolatedShip.velocity = {
        lat: (update.position.latitude - interpolatedShip.targetPosition.latitude) / timeDelta * 1000,
        lng: (update.position.longitude - interpolatedShip.targetPosition.longitude) / timeDelta * 1000
      };
    }

    // Update target values
    interpolatedShip.targetPosition = update.position;
    interpolatedShip.targetRotation = update.rotation;
    interpolatedShip.ship.destination = update.destination;
    interpolatedShip.ship.status = update.status;
    interpolatedShip.ship.speed = update.speed;
    interpolatedShip.lastUpdate = update.timestamp;
    interpolatedShip.interpolationProgress = 0;
  }

  private updateInterpolation(): void {
    if (!this.interpolationEnabled) return;

    const now = Date.now();
    
    this.remoteShips.forEach(playerShips => {
      playerShips.forEach(interpolatedShip => {
        const timeSinceUpdate = now - interpolatedShip.lastUpdate;
        
        if (interpolatedShip.ship.status === 'traveling') {
          // Apply dead reckoning for ships in motion
          if (timeSinceUpdate > this.interpolationDuration) {
            // Extrapolate position based on velocity
            const extrapolationTime = (timeSinceUpdate - this.interpolationDuration) / 1000;
            interpolatedShip.ship.currentLocation = {
              latitude: interpolatedShip.targetPosition.latitude + interpolatedShip.velocity.lat * extrapolationTime,
              longitude: interpolatedShip.targetPosition.longitude + interpolatedShip.velocity.lng * extrapolationTime
            };
          } else {
            // Interpolate to target position
            const progress = Math.min(timeSinceUpdate / this.interpolationDuration, 1);
            interpolatedShip.interpolationProgress = progress;
            
            // Cubic interpolation for smoother movement
            const t = this.easeInOutCubic(progress);
            
            interpolatedShip.ship.currentLocation = {
              latitude: this.lerp(
                interpolatedShip.ship.currentLocation.latitude,
                interpolatedShip.targetPosition.latitude,
                t
              ),
              longitude: this.lerp(
                interpolatedShip.ship.currentLocation.longitude,
                interpolatedShip.targetPosition.longitude,
                t
              )
            };
          }
        } else {
          // Snap to position for docked ships
          interpolatedShip.ship.currentLocation = interpolatedShip.targetPosition;
        }
      });
    });

    this.notifyShipUpdate();
  }

  private lerp(start: number, end: number, t: number): number {
    return start + (end - start) * t;
  }

  private easeInOutCubic(t: number): number {
    return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
  }

  private reconcileLocalShip(serverUpdate: ShipUpdate): void {
    const localShip = this.localShips.get(serverUpdate.shipId);
    if (!localShip) return;

    const positionError = this.calculateDistance(
      localShip.currentLocation,
      serverUpdate.position
    );

    // Only reconcile if error is significant
    if (positionError > 0.001) { // ~111 meters
      // Smooth correction instead of snapping
      const correctionFactor = 0.1;
      localShip.currentLocation = {
        latitude: this.lerp(
          localShip.currentLocation.latitude,
          serverUpdate.position.latitude,
          correctionFactor
        ),
        longitude: this.lerp(
          localShip.currentLocation.longitude,
          serverUpdate.position.longitude,
          correctionFactor
        )
      };
    }
  }

  private calculateDistance(from: Coordinates, to: Coordinates): number {
    const R = 6371; // Earth's radius in kilometers
    const dLat = (to.latitude - from.latitude) * Math.PI / 180;
    const dLon = (to.longitude - from.longitude) * Math.PI / 180;
    const a = 
      Math.sin(dLat/2) * Math.sin(dLat/2) +
      Math.cos(from.latitude * Math.PI / 180) * Math.cos(to.latitude * Math.PI / 180) * 
      Math.sin(dLon/2) * Math.sin(dLon/2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    return R * c;
  }

  private notifyShipUpdate(): void {
    if (!this.onShipUpdateCallback) return;

    // Combine all ships into a single map
    const allShips = new Map<string, Ship[]>();
    
    // Add local ships
    allShips.set(this.wsManager.getPlayerId(), Array.from(this.localShips.values()));
    
    // Add remote ships
    this.remoteShips.forEach((ships, playerId) => {
      allShips.set(playerId, Array.from(ships.values()).map(is => is.ship));
    });

    this.onShipUpdateCallback(allShips);
  }

  public getRemoteShips(): Map<string, Ship[]> {
    const ships = new Map<string, Ship[]>();
    
    this.remoteShips.forEach((playerShips, playerId) => {
      ships.set(playerId, Array.from(playerShips.values()).map(is => is.ship));
    });
    
    return ships;
  }

  public setClientPrediction(enabled: boolean): void {
    this.clientPrediction = enabled;
  }

  public setServerReconciliation(enabled: boolean): void {
    this.serverReconciliation = enabled;
  }

  public setInterpolation(enabled: boolean): void {
    this.interpolationEnabled = enabled;
  }

  public getNetworkStats(): {
    localShips: number;
    remoteShips: number;
    pendingUpdates: number;
    interpolationDelay: number;
  } {
    let remoteShipCount = 0;
    this.remoteShips.forEach(ships => {
      remoteShipCount += ships.size;
    });

    return {
      localShips: this.localShips.size,
      remoteShips: remoteShipCount,
      pendingUpdates: Array.from(this.reconciliationBuffer.values())
        .reduce((sum, buffer) => sum + buffer.length, 0),
      interpolationDelay: this.interpolationDuration
    };
  }
}