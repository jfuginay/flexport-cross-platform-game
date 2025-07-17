import { Ship, GameState } from '@/types';
import { WebSocketManager } from '@/networking/WebSocketManager';
import { getPerformanceMonitor } from '@/utils/Performance';

interface NetworkedShip extends Ship {
  lastServerUpdate: number;
  serverPosition: { lat: number; lng: number };
  predictedPosition: { lat: number; lng: number };
  interpolationFactor: number;
}

interface PlayerInput {
  shipId: string;
  action: string;
  data: any;
  timestamp: number;
  sequenceNumber: number;
}

interface ServerUpdate {
  shipId: string;
  position: { lat: number; lng: number };
  velocity: { lat: number; lng: number };
  timestamp: number;
  sequenceNumber: number;
}

export class NetworkSystem {
  private gameState: GameState;
  private wsManager: WebSocketManager;
  private networkedShips: Map<string, NetworkedShip> = new Map();
  private inputBuffer: PlayerInput[] = [];
  private serverUpdateBuffer: ServerUpdate[] = [];
  private lastProcessedSequence = 0;
  private clientSequenceNumber = 0;
  private serverTimeOffset = 0;
  private latencyBuffer: number[] = [];
  private maxLatencyBufferSize = 10;
  private interpolationDelay = 100; // 100ms interpolation delay
  private predictionEnabled = true;
  private reconciliationEnabled = true;
  private compressionEnabled = true;
  private performanceMonitor = getPerformanceMonitor();

  // Lag compensation parameters
  private readonly MAX_PREDICTION_TIME = 500; // Max 500ms prediction
  private readonly POSITION_CORRECTION_RATE = 0.1;
  private readonly MIN_CORRECTION_DISTANCE = 5;
  private readonly INPUT_RATE_LIMIT = 60; // 60 updates per second max
  private lastInputTime = 0;
  
  // Enhanced lag compensation
  private readonly EXTRAPOLATION_LIMIT = 200; // Max 200ms extrapolation
  private readonly INTERPOLATION_BUFFER_SIZE = 5;
  private snapshotBuffer: Map<string, Array<{position: any, velocity: any, timestamp: number}>> = new Map();
  private inputHistory: PlayerInput[] = [];
  private readonly MAX_INPUT_HISTORY = 120; // 2 seconds at 60 FPS
  private jitterBuffer = 50; // 50ms jitter buffer
  private adaptiveInterpolationDelay = 100;
  private bandwidthOptimizer = {
    lastFullSync: 0,
    fullSyncInterval: 5000, // Full sync every 5 seconds
    deltaThreshold: 0.01, // Minimum position change to send
    priorityShips: new Set<string>() // Ships that need high-frequency updates
  };

  constructor(gameState: GameState, wsManager: WebSocketManager) {
    this.gameState = gameState;
    this.wsManager = wsManager;
    this.setupNetworkHandlers();
  }

  private setupNetworkHandlers(): void {
    // Handle ship position updates from server
    this.wsManager.onMessage('ship_position_update', (message) => {
      const update: ServerUpdate = message.payload;
      this.handleServerUpdate(update);
    });

    // Handle batch updates for efficiency
    this.wsManager.onMessage('ship_position_batch', (message) => {
      const updates: ServerUpdate[] = message.payload.updates;
      updates.forEach(update => this.handleServerUpdate(update));
    });

    // Handle latency measurement
    this.wsManager.onMessage('ping_response', (message) => {
      const latency = Date.now() - message.payload.clientTime;
      this.updateLatency(latency);
    });

    // Periodic latency measurement
    setInterval(() => {
      this.measureLatency();
    }, 1000);
  }

  private measureLatency(): void {
    this.wsManager.sendMessage('ping', {
      clientTime: Date.now()
    }).catch(() => {
      // Handle ping failure
      this.performanceMonitor.setNetworkLatency(999);
    });
  }

  private updateLatency(latency: number): void {
    this.latencyBuffer.push(latency);
    if (this.latencyBuffer.length > this.maxLatencyBufferSize) {
      this.latencyBuffer.shift();
    }

    const avgLatency = this.latencyBuffer.reduce((a, b) => a + b, 0) / this.latencyBuffer.length;
    this.performanceMonitor.setNetworkLatency(avgLatency);

    // Update server time offset
    this.serverTimeOffset = latency / 2;
  }

  public getAverageLatency(): number {
    if (this.latencyBuffer.length === 0) return 0;
    return this.latencyBuffer.reduce((a, b) => a + b, 0) / this.latencyBuffer.length;
  }

  // Client-side prediction
  public predictShipMovement(ship: Ship, deltaTime: number): void {
    if (!this.predictionEnabled) return;

    const networkedShip = this.networkedShips.get(ship.id);
    if (!networkedShip) {
      this.initializeNetworkedShip(ship);
      return;
    }

    // Only predict if ship is moving
    if (ship.status !== 'traveling' || !ship.destination) return;

    // Calculate predicted position based on velocity and time
    const timeSinceLastUpdate = Date.now() - networkedShip.lastServerUpdate;
    if (timeSinceLastUpdate > this.MAX_PREDICTION_TIME) {
      // Too much time has passed, wait for server update
      return;
    }

    // Simple linear prediction
    const velocity = this.calculateVelocity(ship);
    networkedShip.predictedPosition = {
      lat: ship.currentLocation.latitude + velocity.lat * deltaTime,
      lng: ship.currentLocation.longitude + velocity.lng * deltaTime
    };

    // Apply predicted position with smoothing
    ship.currentLocation.latitude = this.lerp(
      ship.currentLocation.latitude,
      networkedShip.predictedPosition.lat,
      this.POSITION_CORRECTION_RATE
    );
    ship.currentLocation.longitude = this.lerp(
      ship.currentLocation.longitude,
      networkedShip.predictedPosition.lng,
      this.POSITION_CORRECTION_RATE
    );
  }

  // Server reconciliation
  private handleServerUpdate(update: ServerUpdate): void {
    const ship = this.findShipById(update.shipId);
    if (!ship) return;

    const networkedShip = this.networkedShips.get(ship.id);
    if (!networkedShip) {
      this.initializeNetworkedShip(ship);
      return;
    }

    // Update server position
    networkedShip.serverPosition = update.position;
    networkedShip.lastServerUpdate = update.timestamp;
    
    // Add to snapshot buffer for interpolation
    if (!this.snapshotBuffer.has(ship.id)) {
      this.snapshotBuffer.set(ship.id, []);
    }
    
    const snapshots = this.snapshotBuffer.get(ship.id)!;
    snapshots.push({
      position: update.position,
      velocity: update.velocity || { lat: 0, lng: 0 },
      timestamp: update.timestamp
    });
    
    // Keep only recent snapshots
    const cutoffTime = Date.now() - 2000; // Keep 2 seconds of history
    while (snapshots.length > 0 && snapshots[0].timestamp < cutoffTime) {
      snapshots.shift();
    }
    
    // Limit buffer size
    if (snapshots.length > this.INTERPOLATION_BUFFER_SIZE) {
      snapshots.shift();
    }
    
    // Update adaptive interpolation delay based on jitter
    this.updateAdaptiveDelay(update.timestamp);

    // If this is our ship, perform reconciliation
    if (this.isLocalShip(ship) && this.reconciliationEnabled) {
      this.reconcilePosition(ship, networkedShip, update);
    } else {
      // For remote ships, interpolate to server position
      this.interpolateToServerPosition(ship, networkedShip);
    }

    // Update last processed sequence
    if (update.sequenceNumber > this.lastProcessedSequence) {
      this.lastProcessedSequence = update.sequenceNumber;
    }
  }
  
  private updateAdaptiveDelay(serverTimestamp: number): void {
    const localTimestamp = Date.now();
    const latency = localTimestamp - serverTimestamp;
    
    // Adjust interpolation delay based on network conditions
    if (latency > 150) {
      this.adaptiveInterpolationDelay = Math.min(200, this.adaptiveInterpolationDelay + 10);
    } else if (latency < 50 && this.adaptiveInterpolationDelay > 50) {
      this.adaptiveInterpolationDelay = Math.max(50, this.adaptiveInterpolationDelay - 5);
    }
  }

  private reconcilePosition(ship: Ship, networkedShip: NetworkedShip, update: ServerUpdate): void {
    // Calculate error between predicted and server position
    const errorDistance = this.calculateDistance(
      ship.currentLocation,
      update.position
    );

    // Only correct if error is significant
    if (errorDistance > this.MIN_CORRECTION_DISTANCE) {
      // Remove processed inputs from buffer
      this.inputBuffer = this.inputBuffer.filter(
        input => input.sequenceNumber > update.sequenceNumber
      );

      // Set position to server authoritative position
      ship.currentLocation.latitude = update.position.lat;
      ship.currentLocation.longitude = update.position.lng;

      // Replay unprocessed inputs
      this.inputBuffer.forEach(input => {
        if (input.shipId === ship.id) {
          this.applyInput(ship, input);
        }
      });
    }
  }

  private interpolateToServerPosition(ship: Ship, networkedShip: NetworkedShip): void {
    const currentTime = Date.now() - this.serverTimeOffset;
    const renderTime = currentTime - this.adaptiveInterpolationDelay;
    
    // Get snapshot buffer for this ship
    let snapshots = this.snapshotBuffer.get(ship.id);
    if (!snapshots || snapshots.length < 2) {
      // Fallback to simple interpolation
      this.simpleInterpolation(ship, networkedShip);
      return;
    }
    
    // Find the two snapshots to interpolate between
    let older: any = null;
    let newer: any = null;
    
    for (let i = 0; i < snapshots.length - 1; i++) {
      if (snapshots[i].timestamp <= renderTime && snapshots[i + 1].timestamp >= renderTime) {
        older = snapshots[i];
        newer = snapshots[i + 1];
        break;
      }
    }
    
    if (!older || !newer) {
      // Extrapolate if we're ahead of the latest snapshot
      if (renderTime > snapshots[snapshots.length - 1].timestamp) {
        this.extrapolatePosition(ship, snapshots[snapshots.length - 1], renderTime);
      } else {
        this.simpleInterpolation(ship, networkedShip);
      }
      return;
    }
    
    // Interpolate between snapshots
    const timeDiff = newer.timestamp - older.timestamp;
    const interpolationFactor = (renderTime - older.timestamp) / timeDiff;
    
    ship.currentLocation.latitude = this.lerp(
      older.position.lat,
      newer.position.lat,
      interpolationFactor
    );
    ship.currentLocation.longitude = this.lerp(
      older.position.lng,
      newer.position.lng,
      interpolationFactor
    );
  }
  
  private simpleInterpolation(ship: Ship, networkedShip: NetworkedShip): void {
    const currentTime = Date.now();
    const timeSinceUpdate = currentTime - networkedShip.lastServerUpdate;
    const interpolationTime = Math.min(timeSinceUpdate / this.interpolationDelay, 1);

    ship.currentLocation.latitude = this.lerp(
      ship.currentLocation.latitude,
      networkedShip.serverPosition.lat,
      interpolationTime * this.POSITION_CORRECTION_RATE
    );
    ship.currentLocation.longitude = this.lerp(
      ship.currentLocation.longitude,
      networkedShip.serverPosition.lng,
      interpolationTime * this.POSITION_CORRECTION_RATE
    );
  }
  
  private extrapolatePosition(ship: Ship, lastSnapshot: any, targetTime: number): void {
    const timeDelta = Math.min(targetTime - lastSnapshot.timestamp, this.EXTRAPOLATION_LIMIT);
    
    ship.currentLocation.latitude = lastSnapshot.position.lat + 
      (lastSnapshot.velocity.lat * timeDelta / 1000);
    ship.currentLocation.longitude = lastSnapshot.position.lng + 
      (lastSnapshot.velocity.lng * timeDelta / 1000);
  }

  // Input handling with rate limiting
  public sendShipInput(ship: Ship, action: string, data: any): void {
    const now = Date.now();
    const timeSinceLastInput = now - this.lastInputTime;
    
    // Rate limit inputs
    if (timeSinceLastInput < 1000 / this.INPUT_RATE_LIMIT) {
      return;
    }

    this.lastInputTime = now;
    this.clientSequenceNumber++;

    const input: PlayerInput = {
      shipId: ship.id,
      action,
      data,
      timestamp: now,
      sequenceNumber: this.clientSequenceNumber
    };

    // Store input for reconciliation
    this.inputBuffer.push(input);

    // Compress and send input
    const compressedData = this.compressionEnabled ? 
      this.compressInput(input) : input;

    this.wsManager.sendMessage('ship_input', compressedData).catch(error => {
      console.error('Failed to send ship input:', error);
    });

    // Apply input locally for prediction
    if (this.predictionEnabled) {
      this.applyInput(ship, input);
    }
  }

  // Message batching for efficiency
  private batchedUpdates: any[] = [];
  private batchTimer: ReturnType<typeof setTimeout> | null = null;
  private readonly BATCH_INTERVAL = 50; // 50ms batching

  public queueUpdate(update: any): void {
    this.batchedUpdates.push(update);

    if (!this.batchTimer) {
      this.batchTimer = setTimeout(() => {
        this.flushBatchedUpdates();
      }, this.BATCH_INTERVAL);
    }
  }

  private flushBatchedUpdates(): void {
    if (this.batchedUpdates.length === 0) return;

    const compressed = this.compressionEnabled ?
      this.compressBatch(this.batchedUpdates) : this.batchedUpdates;

    this.wsManager.sendMessage('batch_update', {
      updates: compressed,
      timestamp: Date.now()
    }).catch(error => {
      console.error('Failed to send batched updates:', error);
    });

    this.batchedUpdates = [];
    this.batchTimer = null;
  }

  // Compression utilities
  private compressInput(input: PlayerInput): any {
    // Simple compression: use short keys
    return {
      s: input.shipId,
      a: input.action,
      d: input.data,
      t: input.timestamp,
      n: input.sequenceNumber
    };
  }

  private compressBatch(updates: any[]): any[] {
    // Compress batch by removing redundant data
    const compressed: any[] = [];
    let lastUpdate: any = null;

    updates.forEach(update => {
      const compressedUpdate: any = {};

      // Only include changed fields
      if (!lastUpdate || update.shipId !== lastUpdate.shipId) {
        compressedUpdate.s = update.shipId;
      }
      if (!lastUpdate || update.action !== lastUpdate.action) {
        compressedUpdate.a = update.action;
      }
      
      // Always include data and timestamp
      compressedUpdate.d = update.data;
      compressedUpdate.t = update.timestamp;

      compressed.push(compressedUpdate);
      lastUpdate = update;
    });

    return compressed;
  }

  // Utility methods
  private initializeNetworkedShip(ship: Ship): void {
    const networkedShip: NetworkedShip = {
      ...ship,
      lastServerUpdate: Date.now(),
      serverPosition: {
        lat: ship.currentLocation.latitude,
        lng: ship.currentLocation.longitude
      },
      predictedPosition: {
        lat: ship.currentLocation.latitude,
        lng: ship.currentLocation.longitude
      },
      interpolationFactor: 0
    };

    this.networkedShips.set(ship.id, networkedShip);
  }

  private findShipById(shipId: string): Ship | undefined {
    // Check local player ships
    const localShip = this.gameState.player.ships.find(s => s.id === shipId);
    if (localShip) return localShip;

    // Check AI ships
    for (const ai of this.gameState.aiCompetitors) {
      const aiShip = ai.ships.find(s => s.id === shipId);
      if (aiShip) return aiShip;
    }

    return undefined;
  }

  private isLocalShip(ship: Ship): boolean {
    return this.gameState.player.ships.some(s => s.id === ship.id);
  }

  private calculateVelocity(ship: Ship): { lat: number; lng: number } {
    // Simple velocity calculation based on destination
    if (!ship.destination || typeof ship.destination !== 'string') {
      return { lat: 0, lng: 0 };
    }

    const destinationPort = this.gameState.world.ports.find(p => p.id === ship.destination);
    if (!destinationPort) {
      return { lat: 0, lng: 0 };
    }

    const dx = destinationPort.coordinates.latitude - ship.currentLocation.latitude;
    const dy = destinationPort.coordinates.longitude - ship.currentLocation.longitude;
    const distance = Math.sqrt(dx * dx + dy * dy);

    if (distance < 0.01) {
      return { lat: 0, lng: 0 };
    }

    // Normalize and apply ship speed
    const speed = 0.5; // Adjust based on ship type
    return {
      lat: (dx / distance) * speed,
      lng: (dy / distance) * speed
    };
  }

  private calculateDistance(pos1: { latitude: number; longitude: number }, pos2: { lat: number; lng: number }): number {
    const dx = pos1.latitude - pos2.lat;
    const dy = pos1.longitude - pos2.lng;
    return Math.sqrt(dx * dx + dy * dy);
  }

  private applyInput(ship: Ship, input: PlayerInput): void {
    // Apply the input to the ship based on action type
    switch (input.action) {
      case 'set_destination':
        ship.destination = input.data.destination;
        ship.status = 'traveling';
        break;
      case 'dock':
        ship.status = 'docked';
        break;
      case 'load_cargo':
        ship.status = 'loading';
        break;
      case 'unload_cargo':
        ship.status = 'unloading';
        break;
    }
  }

  private lerp(start: number, end: number, factor: number): number {
    return start + (end - start) * factor;
  }

  // Public methods for configuration
  public setPredictionEnabled(enabled: boolean): void {
    this.predictionEnabled = enabled;
  }

  public setReconciliationEnabled(enabled: boolean): void {
    this.reconciliationEnabled = enabled;
  }

  public setCompressionEnabled(enabled: boolean): void {
    this.compressionEnabled = enabled;
  }

  public setInterpolationDelay(delay: number): void {
    this.interpolationDelay = Math.max(0, Math.min(delay, 500));
  }

  // Update method called by game engine
  public update(deltaTime: number): void {
    // Update all networked ships
    this.gameState.player.ships.forEach(ship => {
      this.predictShipMovement(ship, deltaTime);
      
      // Check if ship needs priority updates
      if (ship.status === 'traveling' || this.isShipNearOtherPlayers(ship)) {
        this.bandwidthOptimizer.priorityShips.add(ship.id);
      } else {
        this.bandwidthOptimizer.priorityShips.delete(ship.id);
      }
    });
    
    // Send optimized updates
    this.sendOptimizedUpdates();

    // Flush any pending batched updates
    if (this.batchedUpdates.length > 10) { // Force flush if too many updates
      this.flushBatchedUpdates();
    }
    
    // Clean old input history
    const cutoffTime = Date.now() - 2000;
    this.inputHistory = this.inputHistory.filter(input => input.timestamp > cutoffTime);
  }
  
  private sendOptimizedUpdates(): void {
    const now = Date.now();
    const shouldSendFullSync = now - this.bandwidthOptimizer.lastFullSync > this.bandwidthOptimizer.fullSyncInterval;
    
    if (shouldSendFullSync) {
      this.sendFullShipSync();
      this.bandwidthOptimizer.lastFullSync = now;
    } else {
      this.sendDeltaUpdates();
    }
  }
  
  private sendDeltaUpdates(): void {
    const updates: any[] = [];
    
    this.gameState.player.ships.forEach(ship => {
      const networkedShip = this.networkedShips.get(ship.id);
      if (!networkedShip) return;
      
      const positionDelta = this.calculateDistance(
        ship.currentLocation,
        { lat: networkedShip.lastServerUpdate, lng: networkedShip.serverPosition.lng }
      );
      
      // Only send update if position changed significantly or ship is priority
      if (positionDelta > this.bandwidthOptimizer.deltaThreshold || 
          this.bandwidthOptimizer.priorityShips.has(ship.id)) {
        updates.push({
          id: ship.id,
          p: { // position
            la: Math.round(ship.currentLocation.latitude * 10000) / 10000,
            lo: Math.round(ship.currentLocation.longitude * 10000) / 10000
          },
          s: ship.status === 'traveling' ? 1 : 0, // status as number
          t: Date.now()
        });
      }
    });
    
    if (updates.length > 0) {
      this.queueUpdate({
        type: 'delta_update',
        ships: updates
      });
    }
  }
  
  private sendFullShipSync(): void {
    const shipData = this.gameState.player.ships.map(ship => ({
      id: ship.id,
      position: {
        latitude: ship.currentLocation.latitude,
        longitude: ship.currentLocation.longitude
      },
      status: ship.status,
      destination: ship.destination,
      cargo: ship.cargo,
      timestamp: Date.now()
    }));
    
    this.wsManager.sendMessage('ship_full_sync', {
      ships: shipData,
      sequenceNumber: this.clientSequenceNumber
    }).catch(error => {
      console.error('Failed to send full ship sync:', error);
    });
  }
  
  private isShipNearOtherPlayers(ship: Ship): boolean {
    // Check if ship is near any other player's ships
    for (const ai of this.gameState.aiCompetitors) {
      for (const otherShip of ai.ships) {
        const distance = this.calculateDistance(ship.currentLocation, {
          lat: otherShip.currentLocation.latitude,
          lng: otherShip.currentLocation.longitude
        });
        if (distance < 50) return true; // Within visual range
      }
    }
    return false;
  }

  public destroy(): void {
    if (this.batchTimer) {
      clearTimeout(this.batchTimer);
      this.batchTimer = null;
    }
    this.networkedShips.clear();
    this.inputBuffer = [];
    this.serverUpdateBuffer = [];
    this.batchedUpdates = [];
  }
}