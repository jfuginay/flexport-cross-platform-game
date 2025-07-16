import Foundation
import Network
import Combine

/// WebSocket server implementation for FlexPort multiplayer
/// Handles up to 16 concurrent players with optimized state synchronization
@available(iOS 14.0, *)
class FlexPortWebSocketServer {
    // Server configuration
    private let port: UInt16
    private let maxPlayers = 16
    private var listener: NWListener?
    private let serverQueue = DispatchQueue(label: "flexport.websocket.server", qos: .userInteractive)
    
    // Connected clients management
    private var clients: [UUID: ClientConnection] = [:]
    private var gameRooms: [String: GameRoom] = [:]
    
    // State synchronization
    private let stateSync = StateSync()
    private let lagCompensation = LagCompensationSystem()
    private let predictionValidator = ClientPredictionValidator()
    
    // Security and validation
    private let securityManager = SecurityManager.shared
    private let antiCheat = AntiCheatSystem()
    
    // Performance monitoring
    private let performanceMonitor = ServerPerformanceMonitor()
    private var syncTimer: Timer?
    
    // Publishers
    private let connectionSubject = PassthroughSubject<ClientConnectionEvent, Never>()
    var connectionPublisher: AnyPublisher<ClientConnectionEvent, Never> {
        connectionSubject.eraseToAnyPublisher()
    }
    
    init(port: UInt16 = 8080) {
        self.port = port
    }
    
    // MARK: - Server Lifecycle
    
    /// Start the WebSocket server
    func start() throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        
        // Configure WebSocket options
        let wsOptions = NWProtocolWebSocket.Options()
        wsOptions.autoReplyPing = true
        parameters.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)
        
        listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: port))
        
        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleNewConnection(connection)
        }
        
        listener?.stateUpdateHandler = { [weak self] state in
            self?.handleStateUpdate(state)
        }
        
        listener?.start(queue: serverQueue)
        
        // Start synchronization timer
        startSyncTimer()
        
        print("FlexPort WebSocket server started on port \(port)")
    }
    
    /// Stop the server
    func stop() {
        stopSyncTimer()
        
        // Disconnect all clients
        clients.values.forEach { $0.disconnect() }
        clients.removeAll()
        
        // Clear game rooms
        gameRooms.removeAll()
        
        listener?.cancel()
        listener = nil
    }
    
    // MARK: - Connection Management
    
    private func handleNewConnection(_ connection: NWConnection) {
        let clientId = UUID()
        let client = ClientConnection(
            id: clientId,
            connection: connection,
            delegate: self
        )
        
        serverQueue.async { [weak self] in
            self?.clients[clientId] = client
            client.start()
        }
        
        connectionSubject.send(.connected(clientId))
    }
    
    private func handleStateUpdate(_ state: NWListener.State) {
        switch state {
        case .ready:
            print("Server is ready")
        case .failed(let error):
            print("Server failed with error: \(error)")
            // Attempt to restart
            try? start()
        case .cancelled:
            print("Server cancelled")
        default:
            break
        }
    }
    
    // MARK: - Game Room Management
    
    /// Create a new game room
    func createGameRoom(mode: GameMode, maxPlayers: Int = 16) -> GameRoom {
        let room = GameRoom(
            id: UUID().uuidString,
            mode: mode,
            maxPlayers: min(maxPlayers, self.maxPlayers)
        )
        
        serverQueue.async { [weak self] in
            self?.gameRooms[room.id] = room
        }
        
        return room
    }
    
    /// Join a client to a game room
    func joinRoom(clientId: UUID, roomId: String) -> Result<Void, ServerError> {
        guard let client = clients[clientId] else {
            return .failure(.clientNotFound)
        }
        
        guard let room = gameRooms[roomId] else {
            return .failure(.roomNotFound)
        }
        
        guard room.players.count < room.maxPlayers else {
            return .failure(.roomFull)
        }
        
        // Validate client authentication
        guard antiCheat.validateClient(client) else {
            return .failure(.authenticationFailed)
        }
        
        // Add player to room
        let player = Player(
            id: clientId,
            name: client.playerName ?? "Player \(room.players.count + 1)",
            connection: client
        )
        
        room.addPlayer(player)
        client.currentRoom = roomId
        
        // Notify other players
        broadcastToRoom(roomId, message: GameMessage(
            id: UUID().uuidString,
            type: .playerJoined,
            timestamp: Date(),
            payload: .playerEvent(PlayerEvent(
                playerId: clientId.uuidString,
                eventType: "joined",
                isJoining: true
            ))
        ), excludeClient: clientId)
        
        // Send current room state to new player
        sendRoomState(to: clientId, room: room)
        
        return .success(())
    }
    
    // MARK: - Message Handling
    
    func handleMessage(from clientId: UUID, message: Data) {
        guard let client = clients[clientId] else { return }
        
        do {
            let gameMessage = try JSONDecoder().decode(GameMessage.self, from: message)
            
            // Validate message with anti-cheat
            guard antiCheat.validateMessage(gameMessage, from: client) else {
                handleCheatDetection(client: client, reason: "Invalid message")
                return
            }
            
            // Record performance metrics
            performanceMonitor.recordMessage(from: clientId)
            
            // Process based on message type
            switch gameMessage.payload {
            case .action(let action):
                handleGameAction(from: clientId, action: action)
                
            case .stateUpdate(let update):
                handleStateUpdate(from: clientId, update: update)
                
            case .chat(let chatMessage):
                handleChatMessage(from: clientId, message: chatMessage)
                
            default:
                break
            }
            
        } catch {
            print("Failed to decode message: \(error)")
        }
    }
    
    private func handleGameAction(from clientId: UUID, action: GameAction) {
        guard let client = clients[clientId],
              let roomId = client.currentRoom,
              let room = gameRooms[roomId] else { return }
        
        // Apply lag compensation
        let compensatedAction = lagCompensation.compensate(
            action: action,
            clientLatency: client.averageLatency,
            serverTime: Date()
        )
        
        // Validate with prediction system
        if predictionValidator.validate(action: compensatedAction, room: room) {
            // Apply action to server state
            room.applyAction(compensatedAction)
            
            // Broadcast to all clients with prediction acknowledgment
            let ackMessage = GameMessage(
                id: UUID().uuidString,
                type: .gameAction,
                timestamp: Date(),
                payload: .action(compensatedAction)
            )
            
            broadcastToRoom(roomId, message: ackMessage)
            
            // Update state sync
            stateSync.markDirty(room: room)
            
        } else {
            // Send correction to client
            sendCorrection(to: clientId, action: compensatedAction, room: room)
        }
    }
    
    private func handleStateUpdate(from clientId: UUID, update: GameStateUpdate) {
        guard let client = clients[clientId],
              let roomId = client.currentRoom,
              let room = gameRooms[roomId] else { return }
        
        // Only process state updates in turn-based mode
        if room.mode == .turnBased {
            // Validate turn ownership
            if room.currentTurnPlayer == clientId {
                room.applyStateUpdate(update)
                broadcastToRoom(roomId, message: GameMessage(
                    id: UUID().uuidString,
                    type: .stateUpdate,
                    timestamp: Date(),
                    payload: .stateUpdate(update)
                ), excludeClient: clientId)
            }
        }
    }
    
    private func handleChatMessage(from clientId: UUID, message: ChatMessage) {
        guard let client = clients[clientId],
              let roomId = client.currentRoom else { return }
        
        // Apply chat filter
        let filteredMessage = ChatMessage(
            playerId: message.playerId,
            message: filterChatMessage(message.message),
            timestamp: Date()
        )
        
        broadcastToRoom(roomId, message: GameMessage(
            id: UUID().uuidString,
            type: .chatMessage,
            timestamp: Date(),
            payload: .chat(filteredMessage)
        ))
    }
    
    // MARK: - State Synchronization
    
    private func startSyncTimer() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.performStateSync()
        }
    }
    
    private func stopSyncTimer() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    private func performStateSync() {
        serverQueue.async { [weak self] in
            guard let self = self else { return }
            
            for (roomId, room) in self.gameRooms {
                guard self.stateSync.needsSync(room: room) else { continue }
                
                // Create optimized state snapshot
                let snapshot = self.createOptimizedSnapshot(room: room)
                
                // Send delta updates to each client
                for player in room.players {
                    if let client = self.clients[player.id] {
                        let deltaUpdate = self.stateSync.createDeltaUpdate(
                            snapshot: snapshot,
                            lastAck: client.lastAcknowledgedState
                        )
                        
                        self.sendStateUpdate(to: player.id, update: deltaUpdate)
                    }
                }
                
                self.stateSync.markSynced(room: room)
            }
        }
    }
    
    private func createOptimizedSnapshot(room: GameRoom) -> RoomSnapshot {
        return RoomSnapshot(
            roomId: room.id,
            timestamp: Date(),
            players: room.players.map { player in
                PlayerSnapshot(
                    id: player.id,
                    position: player.position,
                    state: player.gameState,
                    lastAction: player.lastAction
                )
            },
            gameState: room.compressedGameState,
            checksum: room.stateChecksum
        )
    }
    
    // MARK: - Broadcasting
    
    private func broadcastToRoom(_ roomId: String, message: GameMessage, excludeClient: UUID? = nil) {
        guard let room = gameRooms[roomId] else { return }
        
        let messageData: Data
        do {
            messageData = try JSONEncoder().encode(message)
        } catch {
            print("Failed to encode message: \(error)")
            return
        }
        
        for player in room.players {
            if player.id != excludeClient,
               let client = clients[player.id] {
                client.send(messageData)
                performanceMonitor.recordBroadcast(to: player.id, size: messageData.count)
            }
        }
    }
    
    private func sendToClient(_ clientId: UUID, message: GameMessage) {
        guard let client = clients[clientId] else { return }
        
        do {
            let messageData = try JSONEncoder().encode(message)
            client.send(messageData)
        } catch {
            print("Failed to encode message: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func sendRoomState(to clientId: UUID, room: GameRoom) {
        let roomState = RoomStateMessage(
            roomId: room.id,
            players: room.players.map { PlayerInfo(id: $0.id, name: $0.name) },
            gameMode: room.mode,
            currentTurn: room.currentTurn
        )
        
        sendToClient(clientId, message: GameMessage(
            id: UUID().uuidString,
            type: .systemMessage,
            timestamp: Date(),
            payload: .system(SystemMessage(
                message: "Room state: \(roomState)",
                severity: "info"
            ))
        ))
    }
    
    private func sendCorrection(to clientId: UUID, action: GameAction, room: GameRoom) {
        let correction = GameMessage(
            id: UUID().uuidString,
            type: .conflictResolution,
            timestamp: Date(),
            payload: .conflict(ConflictResolution(
                conflictId: UUID().uuidString,
                originalActions: [action],
                resolution: room.getCorrectAction(for: action),
                reason: "Client prediction mismatch"
            ))
        )
        
        sendToClient(clientId, message: correction)
    }
    
    private func sendStateUpdate(to clientId: UUID, update: DeltaStateUpdate) {
        guard let client = clients[clientId] else { return }
        
        do {
            let compressed = try stateSync.compressUpdate(update)
            client.send(compressed)
        } catch {
            print("Failed to compress state update: \(error)")
        }
    }
    
    private func handleCheatDetection(client: ClientConnection, reason: String) {
        // Log the incident
        antiCheat.logIncident(clientId: client.id, reason: reason)
        
        // Disconnect the client
        client.disconnect()
        clients.removeValue(forKey: client.id)
        
        // Notify room
        if let roomId = client.currentRoom {
            broadcastToRoom(roomId, message: GameMessage(
                id: UUID().uuidString,
                type: .systemMessage,
                timestamp: Date(),
                payload: .system(SystemMessage(
                    message: "Player disconnected for suspicious activity",
                    severity: "warning"
                ))
            ))
        }
    }
    
    private func filterChatMessage(_ message: String) -> String {
        // Basic profanity filter - in production, use more sophisticated filtering
        let blockedWords = ["cheat", "hack", "exploit"] // Example list
        var filtered = message
        
        for word in blockedWords {
            filtered = filtered.replacingOccurrences(
                of: word,
                with: String(repeating: "*", count: word.count),
                options: .caseInsensitive
            )
        }
        
        return filtered
    }
}

// MARK: - ClientConnectionDelegate

extension FlexPortWebSocketServer: ClientConnectionDelegate {
    func clientDidConnect(_ client: ClientConnection) {
        print("Client connected: \(client.id)")
    }
    
    func clientDidDisconnect(_ client: ClientConnection) {
        serverQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Remove from active clients
            self.clients.removeValue(forKey: client.id)
            
            // Remove from game room
            if let roomId = client.currentRoom,
               let room = self.gameRooms[roomId] {
                room.removePlayer(client.id)
                
                // Notify other players
                self.broadcastToRoom(roomId, message: GameMessage(
                    id: UUID().uuidString,
                    type: .playerLeft,
                    timestamp: Date(),
                    payload: .playerEvent(PlayerEvent(
                        playerId: client.id.uuidString,
                        eventType: "left",
                        isJoining: false
                    ))
                ))
                
                // Clean up empty rooms
                if room.players.isEmpty {
                    self.gameRooms.removeValue(forKey: roomId)
                }
            }
            
            self.connectionSubject.send(.disconnected(client.id))
        }
    }
    
    func client(_ client: ClientConnection, didReceiveMessage message: Data) {
        handleMessage(from: client.id, message: message)
    }
}

// MARK: - Supporting Types

enum ServerError: Error {
    case clientNotFound
    case roomNotFound
    case roomFull
    case authenticationFailed
    case invalidMessage
}

enum ClientConnectionEvent {
    case connected(UUID)
    case disconnected(UUID)
}

struct RoomStateMessage: Codable {
    let roomId: String
    let players: [PlayerInfo]
    let gameMode: GameMode
    let currentTurn: Int
}

struct PlayerInfo: Codable {
    let id: UUID
    let name: String
}

struct RoomSnapshot {
    let roomId: String
    let timestamp: Date
    let players: [PlayerSnapshot]
    let gameState: Data // Compressed game state
    let checksum: String
}

struct PlayerSnapshot {
    let id: UUID
    let position: SIMD2<Float>
    let state: PlayerGameState
    let lastAction: GameAction?
}

struct DeltaStateUpdate {
    let baseTimestamp: Date
    let changes: [StateChange]
    let checksum: String
}

struct StateChange {
    let entityId: String
    let componentType: String
    let oldValue: Data
    let newValue: Data
}

// MARK: - Server Performance Monitor

class ServerPerformanceMonitor {
    private var messageCount: [UUID: Int] = [:]
    private var broadcastStats: [BroadcastStat] = []
    private let statsQueue = DispatchQueue(label: "server.performance", attributes: .concurrent)
    
    func recordMessage(from clientId: UUID) {
        statsQueue.async(flags: .barrier) {
            self.messageCount[clientId, default: 0] += 1
        }
    }
    
    func recordBroadcast(to clientId: UUID, size: Int) {
        let stat = BroadcastStat(
            clientId: clientId,
            timestamp: Date(),
            messageSize: size
        )
        
        statsQueue.async(flags: .barrier) {
            self.broadcastStats.append(stat)
            
            // Keep only last 1000 stats
            if self.broadcastStats.count > 1000 {
                self.broadcastStats.removeFirst()
            }
        }
    }
    
    func getStats() -> ServerStats {
        return statsQueue.sync {
            ServerStats(
                totalMessages: messageCount.values.reduce(0, +),
                messagesPerClient: messageCount,
                averageMessageSize: broadcastStats.isEmpty ? 0 :
                    broadcastStats.map { $0.messageSize }.reduce(0, +) / broadcastStats.count,
                totalBandwidth: broadcastStats.map { $0.messageSize }.reduce(0, +)
            )
        }
    }
    
    struct BroadcastStat {
        let clientId: UUID
        let timestamp: Date
        let messageSize: Int
    }
    
    struct ServerStats {
        let totalMessages: Int
        let messagesPerClient: [UUID: Int]
        let averageMessageSize: Int
        let totalBandwidth: Int
    }
}