import Foundation
import Combine

/// Coordinates multiplayer functionality with the ECS architecture
class MultiplayerCoordinator: ObservableObject {
    
    // Singleton instance
    static let shared = MultiplayerCoordinator()
    
    // Core systems
    private let multiplayerManager = MultiplayerManager.shared
    private let lobbySystem = LobbySystem()
    private let lagCompensation = LagCompensationSystem()
    private let clientPrediction = ClientPredictionSystem()
    
    // State management
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var currentLobby: GameLobby?
    @Published private(set) var activeMatch: Match?
    @Published private(set) var networkStats: NetworkStats?
    
    // ECS Integration
    private var ecsWorld: World?
    private var networkSystem: NetworkSystem?
    private var syncTimer: Timer?
    
    // Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Monitor connection state
        multiplayerManager.$connectionState
            .assign(to: \.connectionState, on: self)
            .store(in: &cancellables)
        
        // Monitor network stats
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateNetworkStats()
            }
            .store(in: &cancellables)
        
        // Handle lobby events
        lobbySystem.lobbyEventPublisher
            .sink { [weak self] event in
                self?.handleLobbyEvent(event)
            }
            .store(in: &cancellables)
        
        // Handle game messages
        NotificationCenter.default.publisher(for: .gameActionReceived)
            .compactMap { $0.object as? GameAction }
            .sink { [weak self] action in
                self?.handleRemoteAction(action)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .gameStateUpdated)
            .compactMap { $0.object as? GameStateUpdate }
            .sink { [weak self] update in
                self?.handleStateUpdate(update)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Interface
    
    /// Initialize multiplayer with ECS world
    func initialize(with world: World) {
        self.ecsWorld = world
        
        // Create and register network system
        networkSystem = NetworkSystem()
        world.registerSystem(networkSystem!)
        
        // Start synchronization
        startSyncTimer()
    }
    
    /// Host a new game
    func hostGame(settings: LobbySettings) async throws {
        let playerInfo = createLocalPlayerInfo()
        
        // Create lobby
        let result = lobbySystem.createLobby(settings: settings, host: playerInfo)
        
        switch result {
        case .success(let lobby):
            currentLobby = lobby
            
            // Start multiplayer session
            try await multiplayerManager.startMultiplayerGame(
                gameMode: settings.gameMode,
                region: settings.region
            )
            
        case .failure(let error):
            throw error
        }
    }
    
    /// Join a game by code
    func joinGame(code: String) async throws {
        let playerInfo = createLocalPlayerInfo()
        
        // Join lobby
        let result = lobbySystem.joinLobbyByCode(code, player: playerInfo)
        
        switch result {
        case .success(let lobby):
            currentLobby = lobby
            
            // Connect to session when ready
            if let sessionId = lobby.gameSessionId {
                try await multiplayerManager.joinGameSession(
                    GameSession(id: sessionId, mode: lobby.settings.gameMode)
                )
            }
            
        case .failure(let error):
            throw error
        }
    }
    
    /// Start matchmaking
    func startMatchmaking(preferences: MatchmakingPreferences) async throws {
        let playerInfo = createLocalPlayerInfo()
        
        // Enter matchmaking
        let result = lobbySystem.enterMatchmaking(player: playerInfo, preferences: preferences)
        
        switch result {
        case .success(let ticketId):
            // Monitor matchmaking status
            await monitorMatchmaking(ticketId: ticketId)
            
        case .failure(let error):
            throw error
        }
    }
    
    /// Leave current game
    func leaveGame() async {
        if let playerId = getLocalPlayerId() {
            _ = lobbySystem.leaveLobby(playerId: playerId)
        }
        
        await multiplayerManager.leaveGameSession()
        
        currentLobby = nil
        activeMatch = nil
    }
    
    // MARK: - ECS Integration
    
    /// Send local entity action
    func sendEntityAction(_ entity: Entity, action: String, parameters: [String: Any]) async throws {
        guard let world = ecsWorld else { return }
        
        // Create game action
        let gameAction = GameAction(
            playerId: getLocalPlayerId().uuidString,
            actionType: action,
            parameters: parameters.mapValues { AnyCodable($0) }
        )
        
        // Apply client prediction
        if connectionState == .connected {
            let predictedState = clientPrediction.predict(
                action: gameAction,
                currentState: world.createSnapshot()
            )
            
            // Apply predicted state locally
            applyPredictedState(predictedState)
        }
        
        // Send to server
        try await multiplayerManager.sendGameAction(gameAction)
    }
    
    /// Sync local ECS state
    private func syncECSState() {
        guard let world = ecsWorld,
              let networkSystem = networkSystem,
              connectionState == .connected else { return }
        
        Task {
            // Get entities that need syncing
            let dirtyEntities = networkSystem.getDirtyEntities()
            
            for entity in dirtyEntities {
                if let transform = world.getComponent(TransformComponent.self, for: entity),
                   let networkId = world.getComponent(NetworkComponent.self, for: entity) {
                    
                    let action = GameAction(
                        playerId: getLocalPlayerId().uuidString,
                        actionType: "update_position",
                        parameters: [
                            "entityId": AnyCodable(networkId.networkId),
                            "x": AnyCodable(transform.position.x),
                            "y": AnyCodable(transform.position.y),
                            "rotation": AnyCodable(transform.rotation)
                        ]
                    )
                    
                    try? await multiplayerManager.sendGameAction(action)
                }
            }
            
            networkSystem.clearDirtyEntities()
        }
    }
    
    // MARK: - Message Handlers
    
    private func handleRemoteAction(_ action: GameAction) {
        guard let world = ecsWorld else { return }
        
        // Apply lag compensation
        let compensatedAction = lagCompensation.compensate(
            action: action,
            clientLatency: 0.05, // Would get from network stats
            serverTime: Date()
        )
        
        // Apply action to ECS
        switch compensatedAction.actionType {
        case "update_position":
            handlePositionUpdate(compensatedAction)
            
        case "spawn_entity":
            handleEntitySpawn(compensatedAction)
            
        case "destroy_entity":
            handleEntityDestroy(compensatedAction)
            
        default:
            // Handle other action types
            break
        }
    }
    
    private func handlePositionUpdate(_ action: GameAction) {
        guard let world = ecsWorld,
              let entityId = action.parameters["entityId"]?.value as? String,
              let x = action.parameters["x"]?.value as? Float,
              let y = action.parameters["y"]?.value as? Float else { return }
        
        // Find entity by network ID
        if let entity = findEntityByNetworkId(entityId) {
            // Update transform with interpolation
            if var transform = world.getComponent(TransformComponent.self, for: entity) {
                // Store target position for interpolation
                if var network = world.getComponent(NetworkComponent.self, for: entity) {
                    network.targetPosition = SIMD2<Float>(x, y)
                    network.lastUpdateTime = Date()
                    world.addComponent(network, to: entity)
                }
            }
        }
    }
    
    private func handleEntitySpawn(_ action: GameAction) {
        guard let world = ecsWorld,
              let entityType = action.parameters["type"]?.value as? String,
              let networkId = action.parameters["networkId"]?.value as? String,
              let ownerId = action.parameters["ownerId"]?.value as? String else { return }
        
        // Create new entity
        let entity = world.createEntity()
        
        // Add network component
        let networkComponent = NetworkComponent(
            networkId: networkId,
            ownerId: ownerId,
            isLocal: ownerId == getLocalPlayerId().uuidString
        )
        world.addComponent(networkComponent, to: entity)
        
        // Add other components based on type
        switch entityType {
        case "ship":
            createShipComponents(for: entity, from: action)
        case "cargo":
            createCargoComponents(for: entity, from: action)
        default:
            break
        }
    }
    
    private func handleEntityDestroy(_ action: GameAction) {
        guard let world = ecsWorld,
              let entityId = action.parameters["entityId"]?.value as? String else { return }
        
        if let entity = findEntityByNetworkId(entityId) {
            world.destroyEntity(entity)
        }
    }
    
    private func handleStateUpdate(_ update: GameStateUpdate) {
        // Reconcile with client prediction
        if let world = ecsWorld {
            let serverState = convertUpdateToGameState(update)
            clientPrediction.reconcile(
                serverState: serverState,
                serverStateVersion: update.turn
            )
        }
    }
    
    private func handleLobbyEvent(_ event: LobbyEvent) {
        switch event {
        case .matchFound(let lobby, let match):
            currentLobby = lobby
            activeMatch = match
            
            // Auto-join the game session
            Task {
                if let sessionId = lobby.gameSessionId {
                    try? await multiplayerManager.joinGameSession(
                        GameSession(id: sessionId, mode: lobby.settings.gameMode)
                    )
                }
            }
            
        case .gameStarted(let lobby, let sessionId):
            // Initialize game world for multiplayer
            initializeMultiplayerGame(sessionId: sessionId)
            
        default:
            break
        }
    }
    
    // MARK: - Helper Methods
    
    private func createLocalPlayerInfo() -> PlayerInfo {
        return PlayerInfo(
            id: getLocalPlayerId(),
            name: UserDefaults.standard.string(forKey: "playerName") ?? "Player",
            level: UserDefaults.standard.integer(forKey: "playerLevel"),
            rating: UserDefaults.standard.integer(forKey: "playerRating")
        )
    }
    
    private func getLocalPlayerId() -> UUID {
        if let uuidString = UserDefaults.standard.string(forKey: "playerId"),
           let uuid = UUID(uuidString: uuidString) {
            return uuid
        }
        
        let newId = UUID()
        UserDefaults.standard.set(newId.uuidString, forKey: "playerId")
        return newId
    }
    
    private func findEntityByNetworkId(_ networkId: String) -> Entity? {
        guard let world = ecsWorld else { return nil }
        
        // This would use a more efficient lookup in production
        for entity in world.entities {
            if let network = world.getComponent(NetworkComponent.self, for: entity),
               network.networkId == networkId {
                return entity
            }
        }
        
        return nil
    }
    
    private func applyPredictedState(_ state: GameState) {
        // Apply predicted state to ECS world
        // This would update entity positions, states, etc.
    }
    
    private func convertUpdateToGameState(_ update: GameStateUpdate) -> GameState {
        // Convert network update to game state
        return GameState()
    }
    
    private func createShipComponents(for entity: Entity, from action: GameAction) {
        guard let world = ecsWorld else { return }
        
        // Add transform
        if let x = action.parameters["x"]?.value as? Float,
           let y = action.parameters["y"]?.value as? Float {
            let transform = TransformComponent(
                position: SIMD3<Float>(x, y, 0),
                rotation: 0,
                scale: SIMD3<Float>(1, 1, 1)
            )
            world.addComponent(transform, to: entity)
        }
        
        // Add ship component
        if let shipType = action.parameters["shipType"]?.value as? String {
            let ship = ShipComponent(
                shipType: shipType,
                maxSpeed: 50.0,
                cargoCapacity: 1000
            )
            world.addComponent(ship, to: entity)
        }
    }
    
    private func createCargoComponents(for entity: Entity, from action: GameAction) {
        guard let world = ecsWorld else { return }
        
        // Add cargo-specific components
        if let cargoType = action.parameters["cargoType"]?.value as? String,
           let quantity = action.parameters["quantity"]?.value as? Int {
            let cargo = CargoComponent(
                type: cargoType,
                quantity: quantity,
                value: 1000.0
            )
            world.addComponent(cargo, to: entity)
        }
    }
    
    private func initializeMultiplayerGame(sessionId: String) {
        // Initialize game world for multiplayer session
        // This would set up initial entities, state, etc.
    }
    
    private func monitorMatchmaking(ticketId: String) async {
        while true {
            if let status = lobbySystem.getMatchmakingStatus(ticketId: ticketId) {
                switch status.state {
                case .matchFound:
                    return
                    
                case .failed, .cancelled:
                    return
                    
                default:
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                }
            } else {
                return
            }
        }
    }
    
    private func updateNetworkStats() {
        networkStats = multiplayerManager.getNetworkStats()
    }
    
    private func startSyncTimer() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.syncECSState()
        }
    }
}

// MARK: - Network Component

struct NetworkComponent: Component {
    let networkId: String
    let ownerId: String
    let isLocal: Bool
    var targetPosition: SIMD2<Float>?
    var lastUpdateTime: Date = Date()
    var needsSync: Bool = false
}

// MARK: - Network System

class NetworkSystem: System {
    private var dirtyEntities: Set<Entity> = []
    
    override func update(deltaTime: Float, world: World) {
        // Interpolate remote entities
        for entity in world.entities {
            guard let network = world.getComponent(NetworkComponent.self, for: entity),
                  !network.isLocal,
                  let targetPos = network.targetPosition,
                  var transform = world.getComponent(TransformComponent.self, for: entity) else {
                continue
            }
            
            // Smooth interpolation
            let currentPos = SIMD2<Float>(transform.position.x, transform.position.y)
            let t = min(deltaTime * 10.0, 1.0) // Interpolation speed
            let newPos = simd_mix(currentPos, targetPos, SIMD2<Float>(repeating: t))
            
            transform.position = SIMD3<Float>(newPos.x, newPos.y, transform.position.z)
            world.addComponent(transform, to: entity)
        }
        
        // Track local changes
        for entity in world.entities {
            if let network = world.getComponent(NetworkComponent.self, for: entity),
               network.isLocal && network.needsSync {
                dirtyEntities.insert(entity)
            }
        }
    }
    
    func getDirtyEntities() -> Set<Entity> {
        return dirtyEntities
    }
    
    func clearDirtyEntities() {
        dirtyEntities.removeAll()
    }
}

// MARK: - Game Session

struct GameSession {
    let id: String
    let mode: GameMode
}