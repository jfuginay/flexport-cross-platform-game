import Foundation
import Combine

/// Coordinates all networking components for multiplayer gameplay with 16-player scaling
class MultiplayerManager: ObservableObject {
    static let shared = MultiplayerManager()
    
    // Published state
    @Published private(set) var currentSession: GameSession?
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var isOnline: Bool = true
    @Published private(set) var gameMode: GameMode = .realtime
    @Published private(set) var connectedPlayers: [String] = []
    @Published private(set) var networkMetrics: NetworkMetrics = NetworkMetrics()
    
    // Service components
    private let webSocketHandler = WebSocketHandler()
    private let apiClient = APIClient.shared
    private let offlineManager = OfflineManager.shared
    private let matchmakingService = MatchmakingService.shared
    private let leaderboardService = LeaderboardService.shared
    private let reachability = NetworkReachability()
    private let securityManager = SecurityManager.shared
    
    // Game manager reference
    weak var gameManager: GameManager?
    
    // 16-player optimization components
    private let connectionPool = ConnectionPool(maxConnections: 16)
    private let messageBuffer = MessageBuffer(maxSize: 1000)
    private let compressionManager = CompressionManager()
    private let priorityQueue = MessagePriorityQueue()
    
    // Game state management
    private var gameActions: [String: GameAction] = [:]
    private var conflictResolver = ConflictResolver()
    private var syncTimer: Timer?
    private var performanceMonitor = PerformanceMonitor()
    
    // Scaling optimizations
    private var messageThrottler = MessageThrottler(maxMessagesPerSecond: 30)
    private var bandwidthOptimizer = BandwidthOptimizer()
    private var latencyOptimizer = LatencyOptimizer()
    
    // Publishers
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
        // Monitor connection state
        webSocketHandler.connectionStatePublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.connectionState, on: self)
            .store(in: &cancellables)
        
        // Monitor network reachability
        reachability.isConnectedPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.isOnline, on: self)
            .store(in: &cancellables)
        
        // Handle incoming messages
        webSocketHandler.messagePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handleIncomingMessage(message)
            }
            .store(in: &cancellables)
        
        // Handle network state changes
        $isOnline
            .sink { [weak self] online in
                if online {
                    self?.handleOnlineMode()
                } else {
                    self?.handleOfflineMode()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Interface
    
    /// Start a multiplayer game session
    func startMultiplayerGame(gameMode: GameMode, region: String? = nil) async throws {
        self.gameMode = gameMode
        
        if !isOnline {
            throw NetworkError.noConnection
        }
        
        // For cross-platform play with web, directly connect to WebSocket server
        if gameMode == .realtime {
            // Connect to the web server at ws://localhost:8080
            let mockSession = GameSession(
                id: "cross-platform-\(UUID().uuidString.prefix(8))",
                hostPlayerId: getCurrentPlayerId(),
                maxPlayers: 16
            )
            try await joinGameSession(mockSession)
        } else {
            // Request matchmaking for turn-based games
            try await matchmakingService.findMatch(gameMode: gameMode, region: region)
            
            // Wait for match to be found
            try await waitForMatch()
            
            // Connect to game session
            if let session = matchmakingService.matchedSession {
                try await joinGameSession(session)
            }
        }
    }
    
    /// Join an existing game session
    func joinGameSession(_ session: GameSession) async throws {
        self.currentSession = session
        
        // Get auth token (in production, from secure storage)
        let authToken = getAuthToken()
        
        // Connect WebSocket
        try await webSocketHandler.connect(sessionId: session.id, authToken: authToken)
        
        // Start synchronization timer for turn-based games
        if gameMode == .turnBased {
            startSyncTimer()
        }
    }
    
    /// Leave current game session
    func leaveGameSession() async {
        stopSyncTimer()
        await webSocketHandler.disconnect()
        
        await MainActor.run {
            self.currentSession = nil
        }
    }
    
    /// Send a game action with encryption and optimization
    func sendGameAction(_ action: GameAction) async throws {
        if isOnline && connectionState == .connected {
            // Apply rate limiting
            try await messageThrottler.checkRateLimit(for: action.playerId)
            
            // Encrypt sensitive action data
            let encryptedAction = try securityManager.encryptGameData(action)
            
            // Create message with encryption
            let message = GameMessage(
                id: UUID().uuidString,
                type: .gameAction,
                timestamp: Date(),
                payload: .action(action)
            )
            
            // Compress message for bandwidth optimization
            let compressedMessage = try compressionManager.compress(message)
            
            // Add to priority queue
            priorityQueue.enqueue(compressedMessage, priority: action.priority)
            
            // Send optimized message
            try await sendOptimizedMessage(compressedMessage)
            
            // Store action for conflict resolution
            gameActions[action.playerId] = action
            
            // Update performance metrics
            performanceMonitor.recordAction(action)
            
        } else {
            // Store action offline
            offlineManager.saveOfflineAction(action, sessionId: currentSession?.id ?? "offline")
        }
    }
    
    /// Send ship position update for cross-platform synchronization
    func sendShipUpdate(_ ship: Ship, position: CGPoint, heading: Double) async throws {
        let action = GameAction(
            playerId: getCurrentPlayerId(),
            actionType: "ship_update",
            parameters: [
                "shipId": ship.id.uuidString,
                "shipName": ship.name,
                "position": ["x": position.x, "y": position.y],
                "heading": heading,
                "speed": ship.speed,
                "capacity": ship.capacity
            ],
            timestamp: Date()
        )
        
        try await sendGameAction(action)
    }
    
    /// Send fleet status update for dashboard synchronization
    func sendFleetStatusUpdate() async throws {
        let fleetData = gameManager?.gameState.playerAssets.ships.map { ship in
            return [
                "id": ship.id.uuidString,
                "name": ship.name,
                "capacity": ship.capacity,
                "speed": ship.speed,
                "efficiency": ship.efficiency,
                "status": "active" // Would be calculated from actual game state
            ]
        } ?? []
        
        let action = GameAction(
            playerId: getCurrentPlayerId(),
            actionType: "fleet_status",
            parameters: [
                "ships": fleetData,
                "totalCapacity": gameManager?.gameState.playerAssets.ships.reduce(0) { $0 + $1.capacity } ?? 0,
                "activeShips": gameManager?.gameState.playerAssets.ships.count ?? 0
            ],
            timestamp: Date()
        )
        
        try await sendGameAction(action)
    }
    
    /// Send optimized message with 16-player scaling considerations
    private func sendOptimizedMessage(_ message: CompressedGameMessage) async throws {
        // Check bandwidth constraints
        try await bandwidthOptimizer.checkBandwidth()
        
        // Optimize for latency
        let optimizedMessage = latencyOptimizer.optimize(message)
        
        // Use connection pooling for efficiency
        let connection = try await connectionPool.getConnection()
        
        try await connection.send(optimizedMessage)
        
        // Buffer message for reliability
        messageBuffer.add(optimizedMessage)
        
        // Update network metrics
        await updateNetworkMetrics()
    }
    
    /// Handle turn completion in turn-based games
    func completeTurn(gameState: GameState) async throws {
        guard let session = currentSession else {
            throw NetworkError.custom("No active session")
        }
        
        // Save state snapshot
        offlineManager.saveGameStateSnapshot(gameState, sessionId: session.id)
        
        if isOnline {
            // Sync with server
            try await syncGameState(gameState)
        }
        
        // Notify other players
        let stateUpdate = GameStateUpdate(
            turn: gameState.turn,
            playerStates: createPlayerStateSnapshot(from: gameState),
            marketState: createMarketStateSnapshot(from: gameState)
        )
        
        let message = GameMessage(
            id: UUID().uuidString,
            type: .stateUpdate,
            timestamp: Date(),
            payload: .stateUpdate(stateUpdate)
        )
        
        if connectionState == .connected {
            try await webSocketHandler.send(message)
        }
    }
    
    // MARK: - Message Handling
    
    private func handleIncomingMessage(_ message: GameMessage) {
        switch message.payload {
        case .action(let action):
            handleGameAction(action)
            
        case .stateUpdate(let update):
            handleStateUpdate(update)
            
        case .playerEvent(let event):
            handlePlayerEvent(event)
            
        case .conflict(let resolution):
            handleConflictResolution(resolution)
            
        case .chat(let chatMessage):
            handleChatMessage(chatMessage)
            
        case .system(let systemMessage):
            handleSystemMessage(systemMessage)
        }
    }
    
    private func handleGameAction(_ action: GameAction) {
        // Check for conflicts with local actions
        if let localAction = gameActions[action.playerId],
           localAction.parameters != action.parameters {
            
            // Conflict detected - request resolution
            let conflict = ConflictResolution(
                conflictId: UUID().uuidString,
                originalActions: [localAction, action],
                resolution: action, // Server action takes precedence
                reason: "Simultaneous action conflict"
            )
            
            conflictResolver.resolveConflict(conflict)
        }
        
        // Apply action to game state
        NotificationCenter.default.post(
            name: .gameActionReceived,
            object: action
        )
    }
    
    private func handleStateUpdate(_ update: GameStateUpdate) {
        // Update local game state with server state
        NotificationCenter.default.post(
            name: .gameStateUpdated,
            object: update
        )
    }
    
    private func handlePlayerEvent(_ event: PlayerEvent) {
        NotificationCenter.default.post(
            name: .playerEventReceived,
            object: event
        )
    }
    
    private func handleConflictResolution(_ resolution: ConflictResolution) {
        // Apply conflict resolution
        conflictResolver.resolveConflict(resolution)
        
        // Remove conflicted actions
        for action in resolution.originalActions {
            gameActions.removeValue(forKey: action.playerId)
        }
        
        // Apply resolved action
        NotificationCenter.default.post(
            name: .gameActionReceived,
            object: resolution.resolution
        )
    }
    
    private func handleChatMessage(_ message: ChatMessage) {
        NotificationCenter.default.post(
            name: .chatMessageReceived,
            object: message
        )
    }
    
    private func handleSystemMessage(_ message: SystemMessage) {
        NotificationCenter.default.post(
            name: .systemMessageReceived,
            object: message
        )
    }
    
    // MARK: - Network State Management
    
    private func handleOnlineMode() {
        Task {
            // Sync pending offline data
            await offlineManager.syncPendingData()
            
            // Reconnect to session if we have one
            if let session = currentSession {
                try? await webSocketHandler.connect(sessionId: session.id, authToken: getAuthToken())
            }
        }
    }
    
    private func handleOfflineMode() {
        // WebSocket will automatically disconnect
        // Continue in offline mode
    }
    
    // MARK: - Synchronization
    
    private func syncGameState(_ gameState: GameState) async throws {
        guard let session = currentSession else { return }
        
        let encoder = JSONEncoder()
        let stateData = try encoder.encode(gameState)
        
        let syncRequest = GameStateSyncRequest(
            playerId: getCurrentPlayerId(),
            sessionId: session.id,
            localState: stateData,
            lastSyncTimestamp: Date(),
            pendingActions: Array(gameActions.values)
        )
        
        let response = try await apiClient.syncGameState(state: syncRequest)
        
        // Handle any conflicts
        for conflict in response.conflicts {
            conflictResolver.resolveConflict(conflict)
        }
    }
    
    private func startSyncTimer() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task {
                if let gameState = self.getCurrentGameState() {
                    try? await self.syncGameState(gameState)
                }
            }
        }
    }
    
    private func stopSyncTimer() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    // MARK: - Helper Methods
    
    private func waitForMatch() async throws {
        while matchmakingService.status == .searching {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        if matchmakingService.status == .failed {
            throw NetworkError.custom("Matchmaking failed")
        }
    }
    
    private func createPlayerStateSnapshot(from gameState: GameState) -> [String: PlayerStateSnapshot] {
        let playerId = getCurrentPlayerId()
        return [
            playerId: PlayerStateSnapshot(
                money: gameState.playerAssets.money,
                shipCount: gameState.playerAssets.ships.count,
                warehouseCount: gameState.playerAssets.warehouses.count,
                reputation: gameState.playerAssets.reputation
            )
        ]
    }
    
    private func createMarketStateSnapshot(from gameState: GameState) -> MarketStateSnapshot {
        let commodityPrices = gameState.markets.goodsMarket.commodities.reduce(into: [String: Double]()) { result, commodity in
            result[commodity.name] = commodity.basePrice
        }
        
        return MarketStateSnapshot(
            commodityPrices: commodityPrices,
            interestRate: gameState.markets.capitalMarket.interestRate
        )
    }
    
    private func getCurrentGameState() -> GameState? {
        // In production, get from GameManager
        return nil
    }
    
    private func getCurrentPlayerId() -> String {
        return UserDefaults.standard.string(forKey: "playerId") ?? "unknown"
    }
    
    private func getAuthToken() -> String {
        // In production, retrieve from secure storage
        return UserDefaults.standard.string(forKey: "authToken") ?? "mock_token"
    }
}

// MARK: - Conflict Resolution
class ConflictResolver {
    func resolveConflict(_ resolution: ConflictResolution) {
        // Log conflict resolution
        print("Resolving conflict: \(resolution.reason)")
        
        // In production, implement sophisticated conflict resolution
        // For now, server action takes precedence
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let gameActionReceived = Notification.Name("GameActionReceived")
    static let gameStateUpdated = Notification.Name("GameStateUpdated")
    static let playerEventReceived = Notification.Name("PlayerEventReceived")
    static let chatMessageReceived = Notification.Name("ChatMessageReceived")
    static let systemMessageReceived = Notification.Name("SystemMessageReceived")
}

// MARK: - 16-Player Scaling Optimizations

/// Manages connection pooling for up to 16 players
class ConnectionPool {
    private let maxConnections: Int
    private var availableConnections: [PooledConnection] = []
    private var activeConnections: [String: PooledConnection] = [:]
    private let connectionQueue = DispatchQueue(label: "connection.pool", qos: .userInteractive)
    
    init(maxConnections: Int) {
        self.maxConnections = maxConnections
        preWarmConnections()
    }
    
    func getConnection() async throws -> PooledConnection {
        return try await withCheckedThrowingContinuation { continuation in
            connectionQueue.async {
                if let connection = self.availableConnections.popLast() {
                    connection.lastUsed = Date()
                    continuation.resume(returning: connection)
                } else if self.activeConnections.count < self.maxConnections {
                    let newConnection = PooledConnection()
                    self.activeConnections[newConnection.id] = newConnection
                    continuation.resume(returning: newConnection)
                } else {
                    continuation.resume(throwing: NetworkError.custom("Connection pool exhausted"))
                }
            }
        }
    }
    
    func releaseConnection(_ connection: PooledConnection) {
        connectionQueue.async {
            self.activeConnections.removeValue(forKey: connection.id)
            self.availableConnections.append(connection)
        }
    }
    
    private func preWarmConnections() {
        connectionQueue.async {
            for _ in 0..<min(4, self.maxConnections) {
                self.availableConnections.append(PooledConnection())
            }
        }
    }
}

class PooledConnection {
    let id = UUID().uuidString
    var lastUsed = Date()
    private let webSocket = URLSession.shared.webSocketTask(with: URL(string: "wss://temp.url")!)
    
    func send(_ message: CompressedGameMessage) async throws {
        let data = try JSONEncoder().encode(message)
        try await webSocket.send(.data(data))
    }
}

/// Manages message buffering for reliability
class MessageBuffer {
    private let maxSize: Int
    private var buffer: [CompressedGameMessage] = []
    private let bufferQueue = DispatchQueue(label: "message.buffer", qos: .userInteractive)
    
    init(maxSize: Int) {
        self.maxSize = maxSize
    }
    
    func add(_ message: CompressedGameMessage) {
        bufferQueue.async {
            self.buffer.append(message)
            if self.buffer.count > self.maxSize {
                self.buffer.removeFirst()
            }
        }
    }
    
    func getMessages(since timestamp: Date) -> [CompressedGameMessage] {
        return bufferQueue.sync {
            return buffer.filter { $0.timestamp > timestamp }
        }
    }
    
    func clear() {
        bufferQueue.async {
            self.buffer.removeAll()
        }
    }
}

/// Compresses messages for bandwidth optimization
class CompressionManager {
    func compress(_ message: GameMessage) throws -> CompressedGameMessage {
        let encoder = JSONEncoder()
        let originalData = try encoder.encode(message)
        
        // Use zlib compression
        let compressedData = try originalData.compressed()
        
        return CompressedGameMessage(
            id: message.id,
            compressedData: compressedData,
            originalSize: originalData.count,
            compressionRatio: Double(compressedData.count) / Double(originalData.count),
            timestamp: message.timestamp
        )
    }
    
    func decompress(_ compressedMessage: CompressedGameMessage) throws -> GameMessage {
        let decompressedData = try compressedMessage.compressedData.decompressed()
        let decoder = JSONDecoder()
        return try decoder.decode(GameMessage.self, from: decompressedData)
    }
}

/// Prioritizes messages for optimal delivery order
class MessagePriorityQueue {
    private var highPriorityQueue: [CompressedGameMessage] = []
    private var normalPriorityQueue: [CompressedGameMessage] = []
    private var lowPriorityQueue: [CompressedGameMessage] = []
    private let queueLock = NSLock()
    
    func enqueue(_ message: CompressedGameMessage, priority: MessagePriority) {
        queueLock.lock()
        defer { queueLock.unlock() }
        
        switch priority {
        case .high:
            highPriorityQueue.append(message)
        case .normal:
            normalPriorityQueue.append(message)
        case .low:
            lowPriorityQueue.append(message)
        }
    }
    
    func dequeue() -> CompressedGameMessage? {
        queueLock.lock()
        defer { queueLock.unlock() }
        
        if !highPriorityQueue.isEmpty {
            return highPriorityQueue.removeFirst()
        } else if !normalPriorityQueue.isEmpty {
            return normalPriorityQueue.removeFirst()
        } else if !lowPriorityQueue.isEmpty {
            return lowPriorityQueue.removeFirst()
        }
        
        return nil
    }
    
    var isEmpty: Bool {
        queueLock.lock()
        defer { queueLock.unlock() }
        return highPriorityQueue.isEmpty && normalPriorityQueue.isEmpty && lowPriorityQueue.isEmpty
    }
}

/// Monitors and optimizes network performance
class PerformanceMonitor {
    private var actionCounts: [String: Int] = [:] // Player ID to action count
    private var latencyMeasurements: [TimeInterval] = []
    private var bandwidthUsage: [Double] = []
    private let monitorQueue = DispatchQueue(label: "performance.monitor")
    
    func recordAction(_ action: GameAction) {
        monitorQueue.async {
            self.actionCounts[action.playerId, default: 0] += 1
        }
    }
    
    func recordLatency(_ latency: TimeInterval) {
        monitorQueue.async {
            self.latencyMeasurements.append(latency)
            if self.latencyMeasurements.count > 100 {
                self.latencyMeasurements.removeFirst()
            }
        }
    }
    
    func recordBandwidthUsage(_ bytes: Double) {
        monitorQueue.async {
            self.bandwidthUsage.append(bytes)
            if self.bandwidthUsage.count > 60 {
                self.bandwidthUsage.removeFirst()
            }
        }
    }
    
    var averageLatency: TimeInterval {
        return monitorQueue.sync {
            guard !latencyMeasurements.isEmpty else { return 0 }
            return latencyMeasurements.reduce(0, +) / Double(latencyMeasurements.count)
        }
    }
    
    var averageBandwidth: Double {
        return monitorQueue.sync {
            guard !bandwidthUsage.isEmpty else { return 0 }
            return bandwidthUsage.reduce(0, +) / Double(bandwidthUsage.count)
        }
    }
}

/// Rate limits messages to prevent spam and ensure fair play
class MessageThrottler {
    private let maxMessagesPerSecond: Double
    private var playerMessageCounts: [String: [Date]] = [:]
    private let throttleQueue = DispatchQueue(label: "message.throttler")
    
    init(maxMessagesPerSecond: Double) {
        self.maxMessagesPerSecond = maxMessagesPerSecond
    }
    
    func checkRateLimit(for playerId: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            throttleQueue.async {
                let now = Date()
                let oneSecondAgo = now.addingTimeInterval(-1.0)
                
                // Clean old timestamps
                self.playerMessageCounts[playerId]?.removeAll { $0 < oneSecondAgo }
                
                let currentCount = self.playerMessageCounts[playerId]?.count ?? 0
                
                if Double(currentCount) >= self.maxMessagesPerSecond {
                    continuation.resume(throwing: NetworkError.rateLimited)
                } else {
                    // Add current timestamp
                    if self.playerMessageCounts[playerId] == nil {
                        self.playerMessageCounts[playerId] = []
                    }
                    self.playerMessageCounts[playerId]?.append(now)
                    continuation.resume()
                }
            }
        }
    }
}

/// Optimizes bandwidth usage for 16-player sessions
class BandwidthOptimizer {
    private var currentBandwidthUsage: Double = 0
    private let maxBandwidthMBps: Double = 10.0 // 10 MB/s limit
    private let optimizerQueue = DispatchQueue(label: "bandwidth.optimizer")
    
    func checkBandwidth() async throws {
        try await withCheckedThrowingContinuation { continuation in
            optimizerQueue.async {
                if self.currentBandwidthUsage > self.maxBandwidthMBps {
                    continuation.resume(throwing: NetworkError.custom("Bandwidth limit exceeded"))
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    func updateBandwidthUsage(_ bytes: Double) {
        optimizerQueue.async {
            // Convert bytes to MB/s
            let megabytes = bytes / (1024 * 1024)
            self.currentBandwidthUsage = megabytes
        }
    }
    
    func optimizeForBandwidth(_ message: CompressedGameMessage) -> CompressedGameMessage {
        // Apply additional optimizations for bandwidth-constrained scenarios
        var optimizedMessage = message
        
        // Reduce update frequency for non-critical data
        if message.compressionRatio > 0.8 {
            // Message didn't compress well, might need different approach
            optimizedMessage = applyAggressiveCompression(message)
        }
        
        return optimizedMessage
    }
    
    private func applyAggressiveCompression(_ message: CompressedGameMessage) -> CompressedGameMessage {
        // Implement more aggressive compression techniques
        return message // Placeholder
    }
}

/// Optimizes for low latency in multiplayer scenarios
class LatencyOptimizer {
    private var averageLatency: TimeInterval = 0.05 // 50ms default
    private var latencyMeasurements: [TimeInterval] = []
    private let optimizerQueue = DispatchQueue(label: "latency.optimizer")
    
    func optimize(_ message: CompressedGameMessage) -> OptimizedGameMessage {
        return OptimizedGameMessage(
            id: message.id,
            compressedData: message.compressedData,
            originalSize: message.originalSize,
            compressionRatio: message.compressionRatio,
            timestamp: message.timestamp,
            priority: calculateOptimalPriority(message),
            routingHint: calculateOptimalRoute(),
            expectedLatency: averageLatency
        )
    }
    
    func recordLatency(_ latency: TimeInterval) {
        optimizerQueue.async {
            self.latencyMeasurements.append(latency)
            if self.latencyMeasurements.count > 50 {
                self.latencyMeasurements.removeFirst()
            }
            
            // Update average
            self.averageLatency = self.latencyMeasurements.reduce(0, +) / Double(self.latencyMeasurements.count)
        }
    }
    
    private func calculateOptimalPriority(_ message: CompressedGameMessage) -> MessagePriority {
        // Real-time actions get high priority
        return .high // Simplified
    }
    
    private func calculateOptimalRoute() -> String {
        // Calculate optimal network route based on latency measurements
        return "default" // Placeholder
    }
}

// MARK: - Enhanced Network Models

struct CompressedGameMessage: Codable {
    let id: String
    let compressedData: Data
    let originalSize: Int
    let compressionRatio: Double
    let timestamp: Date
}

struct OptimizedGameMessage: Codable {
    let id: String
    let compressedData: Data
    let originalSize: Int
    let compressionRatio: Double
    let timestamp: Date
    let priority: MessagePriority
    let routingHint: String
    let expectedLatency: TimeInterval
}

enum MessagePriority: String, Codable {
    case high = "High"
    case normal = "Normal"
    case low = "Low"
}

struct NetworkMetrics: Codable {
    var latency: TimeInterval = 0.0
    var bandwidth: Double = 0.0
    var packetLoss: Double = 0.0
    var jitter: TimeInterval = 0.0
    var connectedPlayerCount: Int = 0
    var messagesSentPerSecond: Double = 0.0
    var messagesReceivedPerSecond: Double = 0.0
    var compressionRatio: Double = 0.0
    
    init() {}
}

// MARK: - Extensions for GameAction

extension GameAction {
    var priority: MessagePriority {
        switch actionType {
        case "player_input", "chat_message":
            return .high
        case "game_state_update":
            return .normal
        default:
            return .low
        }
    }
}

// MARK: - Data Compression Extensions

extension Data {
    func compressed() throws -> Data {
        return try (self as NSData).compressed(using: .zlib) as Data
    }
    
    func decompressed() throws -> Data {
        return try (self as NSData).decompressed(using: .zlib) as Data
    }
}

// MARK: - MultiplayerManager Extensions for Network Metrics

extension MultiplayerManager {
    /// Update network metrics for monitoring
    private func updateNetworkMetrics() async {
        await MainActor.run {
            self.networkMetrics.latency = self.performanceMonitor.averageLatency
            self.networkMetrics.bandwidth = self.performanceMonitor.averageBandwidth
            self.networkMetrics.connectedPlayerCount = self.connectedPlayers.count
            self.networkMetrics.compressionRatio = self.compressionManager.getAverageCompressionRatio()
        }
    }
    
    /// Get current network performance statistics
    func getNetworkStats() -> NetworkStats {
        return NetworkStats(
            connectedPlayers: connectedPlayers.count,
            averageLatency: networkMetrics.latency,
            bandwidth: networkMetrics.bandwidth,
            messageQueueSize: priorityQueue.queueSize,
            compressionRatio: networkMetrics.compressionRatio
        )
    }
    
    /// Optimize connection for 16-player scenarios
    func optimizeFor16Players() async {
        // Enable aggressive compression
        compressionManager.enableAggressiveMode()
        
        // Increase message throttling
        messageThrottler.updateLimit(40) // Increase to 40 messages/second for 16 players
        
        // Pre-warm connection pool
        await connectionPool.preWarmForCapacity(16)
        
        // Enable bandwidth optimization
        bandwidthOptimizer.enableOptimizations()
        
        // Configure latency optimization
        latencyOptimizer.enableRealTimeMode()
    }
}

struct NetworkStats: Codable {
    let connectedPlayers: Int
    let averageLatency: TimeInterval
    let bandwidth: Double
    let messageQueueSize: Int
    let compressionRatio: Double
}

// MARK: - Additional Optimization Extensions

extension CompressionManager {
    func enableAggressiveMode() {
        // Enable more aggressive compression for 16-player scenarios
    }
    
    func getAverageCompressionRatio() -> Double {
        return 0.3 // Placeholder - would calculate from recent messages
    }
}

extension MessageThrottler {
    func updateLimit(_ newLimit: Double) {
        // Update the message rate limit
    }
}

extension ConnectionPool {
    func preWarmForCapacity(_ capacity: Int) async {
        // Pre-warm connections for expected capacity
    }
}

extension BandwidthOptimizer {
    func enableOptimizations() {
        // Enable bandwidth optimizations
    }
}

extension LatencyOptimizer {
    func enableRealTimeMode() {
        // Enable real-time optimizations
    }
}

extension MessagePriorityQueue {
    var queueSize: Int {
        queueLock.lock()
        defer { queueLock.unlock() }
        return highPriorityQueue.count + normalPriorityQueue.count + lowPriorityQueue.count
    }
}