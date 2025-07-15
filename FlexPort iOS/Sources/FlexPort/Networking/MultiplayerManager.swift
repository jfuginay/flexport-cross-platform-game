import Foundation
import Combine

/// Coordinates all networking components for multiplayer gameplay
class MultiplayerManager: ObservableObject {
    static let shared = MultiplayerManager()
    
    // Published state
    @Published private(set) var currentSession: GameSession?
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var isOnline: Bool = true
    @Published private(set) var gameMode: GameMode = .realtime
    
    // Service components
    private let webSocketHandler = WebSocketHandler()
    private let apiClient = APIClient.shared
    private let offlineManager = OfflineManager.shared
    private let matchmakingService = MatchmakingService.shared
    private let leaderboardService = LeaderboardService.shared
    private let reachability = NetworkReachability()
    
    // Game state management
    private var gameActions: [String: GameAction] = [:]
    private var conflictResolver = ConflictResolver()
    private var syncTimer: Timer?
    
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
        
        // Request matchmaking
        try await matchmakingService.findMatch(gameMode: gameMode, region: region)
        
        // Wait for match to be found
        try await waitForMatch()
        
        // Connect to game session
        if let session = matchmakingService.matchedSession {
            try await joinGameSession(session)
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
    
    /// Send a game action
    func sendGameAction(_ action: GameAction) async throws {
        if isOnline && connectionState == .connected {
            // Send via WebSocket for real-time games
            let message = GameMessage(
                id: UUID().uuidString,
                type: .gameAction,
                timestamp: Date(),
                payload: .action(action)
            )
            
            try await webSocketHandler.send(message)
            
            // Store action for conflict resolution
            gameActions[action.playerId] = action
            
        } else {
            // Store action offline
            offlineManager.saveOfflineAction(action, sessionId: currentSession?.id ?? "offline")
        }
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