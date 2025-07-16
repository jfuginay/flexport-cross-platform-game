import Foundation
import Compression

/// Manages efficient state synchronization between server and clients
class StateSync {
    
    // Synchronization configuration
    private let syncRate: TimeInterval = 0.05 // 20Hz for real-time, adjusted for turn-based
    private let deltaCompressionThreshold: Float = 0.9 // Use delta if < 90% of full state
    
    // State tracking
    private var dirtyRooms: Set<String> = []
    private var lastSyncTime: [String: Date] = [:] // Room ID to last sync time
    private var stateVersions: [String: Int] = [:] // Room ID to version
    
    // Client acknowledgments
    private var clientAcks: [UUID: ClientSyncState] = [:]
    
    // Compression
    private let compressionAlgorithm = COMPRESSION_ZLIB
    
    // MARK: - State Management
    
    /// Mark a room as needing synchronization
    func markDirty(room: GameRoom) {
        dirtyRooms.insert(room.id)
    }
    
    /// Check if a room needs synchronization
    func needsSync(room: GameRoom) -> Bool {
        guard dirtyRooms.contains(room.id) else { return false }
        
        let lastSync = lastSyncTime[room.id] ?? Date.distantPast
        let timeSinceSync = Date().timeIntervalSince(lastSync)
        
        // Adjust sync rate based on game mode
        let requiredInterval = room.mode == .realtime ? syncRate : 1.0
        
        return timeSinceSync >= requiredInterval
    }
    
    /// Mark room as synchronized
    func markSynced(room: GameRoom) {
        dirtyRooms.remove(room.id)
        lastSyncTime[room.id] = Date()
        stateVersions[room.id] = (stateVersions[room.id] ?? 0) + 1
    }
    
    // MARK: - Delta Updates
    
    /// Create delta update for a specific client
    func createDeltaUpdate(snapshot: RoomSnapshot, lastAck: Date) -> DeltaStateUpdate {
        let changes = calculateChanges(snapshot: snapshot, since: lastAck)
        
        return DeltaStateUpdate(
            baseTimestamp: lastAck,
            changes: changes,
            checksum: snapshot.checksum
        )
    }
    
    /// Calculate state changes since a timestamp
    private func calculateChanges(snapshot: RoomSnapshot, since: Date) -> [StateChange] {
        var changes: [StateChange] = []
        
        // Compare current snapshot with client's last acknowledged state
        for player in snapshot.players {
            if player.lastAction?.timestamp ?? Date.distantPast > since {
                // Player state has changed
                let change = StateChange(
                    entityId: player.id.uuidString,
                    componentType: "PlayerState",
                    oldValue: Data(), // Would contain previous state
                    newValue: encodePlayerState(player)
                )
                changes.append(change)
            }
        }
        
        return changes
    }
    
    private func encodePlayerState(_ player: PlayerSnapshot) -> Data {
        let encoder = JSONEncoder()
        return (try? encoder.encode(player)) ?? Data()
    }
    
    // MARK: - Compression
    
    /// Compress state update for network transmission
    func compressUpdate(_ update: DeltaStateUpdate) throws -> Data {
        let encoder = JSONEncoder()
        let uncompressed = try encoder.encode(update)
        
        // Decide whether to use delta or full state
        let compressionRatio = Float(update.changes.count) / 100.0 // Rough estimate
        
        if compressionRatio < deltaCompressionThreshold {
            // Use delta compression
            return try compress(data: uncompressed)
        } else {
            // Send full state instead
            return try compressFullState(for: update)
        }
    }
    
    private func compress(data: Data) throws -> Data {
        return try data.compressed(using: compressionAlgorithm)
    }
    
    private func compressFullState(for update: DeltaStateUpdate) throws -> Data {
        // In practice, would fetch and compress full room state
        return try compress(data: Data())
    }
    
    // MARK: - Client Acknowledgments
    
    /// Record client acknowledgment of state
    func recordClientAck(clientId: UUID, version: Int, timestamp: Date) {
        clientAcks[clientId] = ClientSyncState(
            lastAckedVersion: version,
            lastAckTime: timestamp,
            pendingUpdates: []
        )
    }
    
    /// Get client's sync state
    func getClientSyncState(_ clientId: UUID) -> ClientSyncState? {
        return clientAcks[clientId]
    }
    
    /// Queue update for unreliable clients
    func queueUpdateForClient(_ clientId: UUID, update: DeltaStateUpdate) {
        clientAcks[clientId]?.pendingUpdates.append(update)
        
        // Limit queue size
        if clientAcks[clientId]?.pendingUpdates.count ?? 0 > 10 {
            clientAcks[clientId]?.pendingUpdates.removeFirst()
        }
    }
}

// MARK: - Network Protocol

/// Handles the network protocol for state synchronization
class StateSyncProtocol {
    
    // Protocol version for compatibility
    static let protocolVersion: UInt8 = 1
    
    // Message types
    enum MessageType: UInt8 {
        case fullState = 0x01
        case deltaUpdate = 0x02
        case acknowledge = 0x03
        case requestSync = 0x04
        case heartbeat = 0x05
    }
    
    // MARK: - Encoding
    
    /// Encode a state sync message
    static func encode(type: MessageType, payload: Data) -> Data {
        var message = Data()
        
        // Header: [Version: 1 byte][Type: 1 byte][Length: 4 bytes]
        message.append(protocolVersion)
        message.append(type.rawValue)
        
        // Payload length (big-endian)
        var length = UInt32(payload.count).bigEndian
        message.append(Data(bytes: &length, count: 4))
        
        // Payload
        message.append(payload)
        
        return message
    }
    
    /// Decode a state sync message
    static func decode(_ data: Data) -> (type: MessageType, payload: Data)? {
        guard data.count >= 6 else { return nil }
        
        let version = data[0]
        guard version == protocolVersion else { return nil }
        
        guard let type = MessageType(rawValue: data[1]) else { return nil }
        
        // Extract length
        let lengthData = data[2..<6]
        let length = lengthData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        
        guard data.count >= 6 + Int(length) else { return nil }
        
        let payload = data[6..<(6 + Int(length))]
        
        return (type: type, payload: payload)
    }
    
    // MARK: - Message Creation
    
    /// Create full state message
    static func createFullStateMessage(state: Data) -> Data {
        return encode(type: .fullState, payload: state)
    }
    
    /// Create delta update message
    static func createDeltaUpdateMessage(delta: DeltaStateUpdate) throws -> Data {
        let encoder = JSONEncoder()
        let payload = try encoder.encode(delta)
        return encode(type: .deltaUpdate, payload: payload)
    }
    
    /// Create acknowledgment message
    static func createAckMessage(version: Int, checksum: String) throws -> Data {
        let ack = StateAcknowledgment(
            version: version,
            checksum: checksum,
            timestamp: Date()
        )
        let encoder = JSONEncoder()
        let payload = try encoder.encode(ack)
        return encode(type: .acknowledge, payload: payload)
    }
}

// MARK: - Interest Management

/// Manages which parts of game state each client needs
class InterestManagement {
    
    // Interest radius for different entity types
    private let shipViewRadius: Float = 1000.0
    private let portViewRadius: Float = 2000.0
    private let defaultViewRadius: Float = 500.0
    
    // Client interest areas
    private var clientInterests: [UUID: InterestArea] = [:]
    
    /// Update client's area of interest
    func updateClientInterest(clientId: UUID, position: SIMD2<Float>, viewRadius: Float? = nil) {
        let radius = viewRadius ?? defaultViewRadius
        
        clientInterests[clientId] = InterestArea(
            center: position,
            radius: radius,
            lastUpdated: Date()
        )
    }
    
    /// Filter entities based on client interest
    func filterEntitiesForClient(_ entities: [Entity], clientId: UUID) -> [Entity] {
        guard let interest = clientInterests[clientId] else {
            return entities // No interest area defined, send all
        }
        
        return entities.filter { entity in
            isEntityInInterest(entity, interest: interest)
        }
    }
    
    /// Check if entity is within interest area
    private func isEntityInInterest(_ entity: Entity, interest: InterestArea) -> Bool {
        // Always include player's own entities
        if entity.ownerId == interest.playerId {
            return true
        }
        
        // Check distance
        let distance = simd_distance(entity.position, interest.center)
        
        // Use different radius based on entity type
        let effectiveRadius: Float
        switch entity.type {
        case .ship:
            effectiveRadius = max(interest.radius, shipViewRadius)
        case .port:
            effectiveRadius = max(interest.radius, portViewRadius)
        default:
            effectiveRadius = interest.radius
        }
        
        return distance <= effectiveRadius
    }
    
    /// Get priority for entity updates
    func getUpdatePriority(entity: Entity, clientId: UUID) -> UpdatePriority {
        guard let interest = clientInterests[clientId] else {
            return .normal
        }
        
        let distance = simd_distance(entity.position, interest.center)
        
        // Prioritize based on distance and entity type
        if entity.ownerId == interest.playerId {
            return .critical
        } else if distance < interest.radius * 0.3 {
            return .high
        } else if distance < interest.radius * 0.7 {
            return .normal
        } else {
            return .low
        }
    }
}

// MARK: - Supporting Types

struct ClientSyncState {
    var lastAckedVersion: Int
    var lastAckTime: Date
    var pendingUpdates: [DeltaStateUpdate]
}

struct StateAcknowledgment: Codable {
    let version: Int
    let checksum: String
    let timestamp: Date
}

struct InterestArea {
    let center: SIMD2<Float>
    let radius: Float
    let lastUpdated: Date
    var playerId: String?
}

enum UpdatePriority: Int {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3
}

// MARK: - Bandwidth Optimization

/// Optimizes state updates for bandwidth constraints
class BandwidthOptimizer {
    
    private let targetBandwidthPerClient: Int = 50_000 // 50KB/s per client
    private var clientBandwidthUsage: [UUID: BandwidthTracker] = [:]
    
    /// Optimize update for client's bandwidth
    func optimizeUpdate(_ update: DeltaStateUpdate, for clientId: UUID) -> DeltaStateUpdate? {
        let tracker = clientBandwidthUsage[clientId] ?? BandwidthTracker()
        
        // Check if client is over bandwidth limit
        if tracker.currentUsage > targetBandwidthPerClient {
            // Apply more aggressive filtering
            return filterUpdate(update, aggressiveness: 0.5)
        }
        
        return update
    }
    
    /// Record bandwidth usage
    func recordBandwidthUsage(clientId: UUID, bytes: Int) {
        if clientBandwidthUsage[clientId] == nil {
            clientBandwidthUsage[clientId] = BandwidthTracker()
        }
        
        clientBandwidthUsage[clientId]?.recordUsage(bytes)
    }
    
    private func filterUpdate(_ update: DeltaStateUpdate, aggressiveness: Float) -> DeltaStateUpdate {
        // Filter out low-priority changes
        let filtered = update.changes.filter { change in
            // Keep only important changes when bandwidth limited
            return change.componentType == "PlayerState" ||
                   change.componentType == "CombatState"
        }
        
        return DeltaStateUpdate(
            baseTimestamp: update.baseTimestamp,
            changes: filtered,
            checksum: update.checksum
        )
    }
}

struct BandwidthTracker {
    private var usageHistory: [(timestamp: Date, bytes: Int)] = []
    private let windowSize: TimeInterval = 1.0 // 1 second window
    
    var currentUsage: Int {
        let now = Date()
        let windowStart = now.addingTimeInterval(-windowSize)
        
        // Remove old entries
        let recent = usageHistory.filter { $0.timestamp > windowStart }
        
        // Sum bytes in window
        return recent.reduce(0) { $0 + $1.bytes }
    }
    
    mutating func recordUsage(_ bytes: Int) {
        usageHistory.append((timestamp: Date(), bytes: bytes))
        
        // Clean old entries
        let cutoff = Date().addingTimeInterval(-windowSize * 2)
        usageHistory.removeAll { $0.timestamp < cutoff }
    }
}

// MARK: - Data Compression Extension

extension Data {
    func compressed(using algorithm: compression_algorithm) throws -> Data {
        return try self.compressed(using: algorithm, level: 5)
    }
    
    func compressed(using algorithm: compression_algorithm, level: Int) throws -> Data {
        guard !self.isEmpty else { return self }
        
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
        defer { destinationBuffer.deallocate() }
        
        let compressedSize = compression_encode_buffer(
            destinationBuffer, count,
            self.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }, count,
            nil, algorithm
        )
        
        guard compressedSize > 0 else {
            throw CompressionError.compressionFailed
        }
        
        return Data(bytes: destinationBuffer, count: compressedSize)
    }
}

enum CompressionError: Error {
    case compressionFailed
    case decompressionFailed
}