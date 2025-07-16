import Foundation
import CryptoKit

/// Represents a multiplayer game room with state management
class GameRoom {
    let id: String
    let mode: GameMode
    let maxPlayers: Int
    private(set) var players: [Player] = []
    private(set) var currentTurn: Int = 0
    private(set) var currentTurnPlayer: UUID?
    
    // Game state management
    private var gameState: GameState
    private var stateHistory: [StateSnapshot] = []
    private let stateQueue = DispatchQueue(label: "gameroom.state", attributes: .concurrent)
    
    // Action history for rollback
    private var actionHistory: [TimestampedAction] = []
    private let maxHistorySize = 1000
    
    // State synchronization
    private var lastStateHash: String = ""
    private var stateVersion: Int = 0
    
    init(id: String, mode: GameMode, maxPlayers: Int) {
        self.id = id
        self.mode = mode
        self.maxPlayers = maxPlayers
        self.gameState = GameState()
    }
    
    // MARK: - Player Management
    
    func addPlayer(_ player: Player) {
        stateQueue.async(flags: .barrier) {
            guard self.players.count < self.maxPlayers else { return }
            
            self.players.append(player)
            
            // Initialize player in game state
            self.gameState.initializePlayer(playerId: player.id.uuidString)
            
            // Set first player as current turn player in turn-based mode
            if self.mode == .turnBased && self.currentTurnPlayer == nil {
                self.currentTurnPlayer = player.id
            }
        }
    }
    
    func removePlayer(_ playerId: UUID) {
        stateQueue.async(flags: .barrier) {
            self.players.removeAll { $0.id == playerId }
            
            // Handle turn transition if needed
            if self.currentTurnPlayer == playerId {
                self.advanceTurn()
            }
            
            // Mark player as disconnected in game state
            self.gameState.markPlayerDisconnected(playerId: playerId.uuidString)
        }
    }
    
    // MARK: - Action Processing
    
    func applyAction(_ action: GameAction) {
        stateQueue.async(flags: .barrier) {
            // Store action in history
            let timestampedAction = TimestampedAction(
                action: action,
                timestamp: Date(),
                stateVersion: self.stateVersion
            )
            self.actionHistory.append(timestampedAction)
            
            // Trim history if needed
            if self.actionHistory.count > self.maxHistorySize {
                self.actionHistory.removeFirst()
            }
            
            // Apply action to game state
            let result = self.gameState.applyAction(action)
            
            if result.success {
                // Update state version
                self.stateVersion += 1
                
                // Update player's last action
                if let playerIndex = self.players.firstIndex(where: { $0.id.uuidString == action.playerId }) {
                    self.players[playerIndex].lastAction = action
                }
                
                // Create state snapshot periodically
                if self.stateVersion % 10 == 0 {
                    self.createStateSnapshot()
                }
            }
        }
    }
    
    func applyStateUpdate(_ update: GameStateUpdate) {
        stateQueue.async(flags: .barrier) {
            // Apply update to game state
            self.gameState.applyUpdate(update)
            
            // Advance turn in turn-based mode
            if self.mode == .turnBased {
                self.advanceTurn()
            }
            
            self.stateVersion += 1
        }
    }
    
    // MARK: - State Management
    
    var compressedGameState: Data {
        stateQueue.sync {
            do {
                let encoder = JSONEncoder()
                let stateData = try encoder.encode(gameState)
                return try (stateData as NSData).compressed(using: .zlib) as Data
            } catch {
                print("Failed to compress game state: \(error)")
                return Data()
            }
        }
    }
    
    var stateChecksum: String {
        stateQueue.sync {
            let stateData = (try? JSONEncoder().encode(gameState)) ?? Data()
            let hash = SHA256.hash(data: stateData)
            return hash.compactMap { String(format: "%02x", $0) }.joined()
        }
    }
    
    func getCorrectAction(for action: GameAction) -> GameAction {
        // In case of prediction mismatch, return the server's authoritative action
        // This would involve looking up the actual game state and determining
        // what the correct action should have been
        return action // Simplified for now
    }
    
    private func createStateSnapshot() {
        let snapshot = StateSnapshot(
            version: stateVersion,
            timestamp: Date(),
            state: gameState.copy(),
            checksum: stateChecksum
        )
        
        stateHistory.append(snapshot)
        
        // Keep only last 10 snapshots
        if stateHistory.count > 10 {
            stateHistory.removeFirst()
        }
    }
    
    private func advanceTurn() {
        guard mode == .turnBased else { return }
        
        currentTurn += 1
        
        // Find next active player
        if let currentIndex = players.firstIndex(where: { $0.id == currentTurnPlayer }) {
            let nextIndex = (currentIndex + 1) % players.count
            currentTurnPlayer = players[nextIndex].id
        } else if !players.isEmpty {
            currentTurnPlayer = players[0].id
        }
    }
    
    // MARK: - Rollback Support
    
    func rollbackToVersion(_ version: Int) {
        stateQueue.async(flags: .barrier) {
            // Find the nearest snapshot
            guard let snapshot = self.stateHistory.last(where: { $0.version <= version }) else {
                print("No snapshot found for version \(version)")
                return
            }
            
            // Restore state from snapshot
            self.gameState = snapshot.state.copy()
            self.stateVersion = snapshot.version
            
            // Replay actions from snapshot to target version
            let actionsToReplay = self.actionHistory.filter {
                $0.stateVersion > snapshot.version && $0.stateVersion <= version
            }
            
            for timestampedAction in actionsToReplay {
                _ = self.gameState.applyAction(timestampedAction.action)
                self.stateVersion += 1
            }
        }
    }
}

// MARK: - Supporting Types

struct Player {
    let id: UUID
    let name: String
    let connection: ClientConnection
    var position: SIMD2<Float> = .zero
    var gameState: PlayerGameState = PlayerGameState()
    var lastAction: GameAction?
}

struct PlayerGameState: Codable {
    var money: Double = 1_000_000
    var ships: [String] = [] // Ship IDs
    var warehouses: [String] = [] // Warehouse IDs
    var reputation: Double = 50.0
    var isActive: Bool = true
}

struct TimestampedAction {
    let action: GameAction
    let timestamp: Date
    let stateVersion: Int
}

struct StateSnapshot {
    let version: Int
    let timestamp: Date
    let state: GameState
    let checksum: String
}

// MARK: - Game State

class GameState: Codable {
    private var entities: [String: Entity] = [:]
    private var playerStates: [String: PlayerGameState] = [:]
    private var marketState: MarketState = MarketState()
    private var worldState: WorldState = WorldState()
    
    func initializePlayer(playerId: String) {
        playerStates[playerId] = PlayerGameState()
    }
    
    func markPlayerDisconnected(playerId: String) {
        playerStates[playerId]?.isActive = false
    }
    
    func applyAction(_ action: GameAction) -> ActionResult {
        // Process different action types
        switch action.actionType {
        case "move_ship":
            return processMoveShip(action)
        case "buy_cargo":
            return processBuyCargo(action)
        case "sell_cargo":
            return processSellCargo(action)
        case "build_warehouse":
            return processBuildWarehouse(action)
        default:
            return ActionResult(success: false, reason: "Unknown action type")
        }
    }
    
    func applyUpdate(_ update: GameStateUpdate) {
        // Apply player state updates
        for (playerId, snapshot) in update.playerStates {
            if var playerState = playerStates[playerId] {
                playerState.money = snapshot.money
                playerState.reputation = snapshot.reputation
                playerStates[playerId] = playerState
            }
        }
        
        // Apply market updates
        marketState.updatePrices(update.marketState.commodityPrices)
        marketState.interestRate = update.marketState.interestRate
    }
    
    func copy() -> GameState {
        // Deep copy implementation
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        guard let data = try? encoder.encode(self),
              let copy = try? decoder.decode(GameState.self, from: data) else {
            return GameState()
        }
        
        return copy
    }
    
    // MARK: - Action Processors
    
    private func processMoveShip(_ action: GameAction) -> ActionResult {
        guard let shipId = action.parameters["shipId"]?.value as? String,
              let targetX = action.parameters["targetX"]?.value as? Double,
              let targetY = action.parameters["targetY"]?.value as? Double else {
            return ActionResult(success: false, reason: "Invalid parameters")
        }
        
        // Update ship position
        if var ship = entities[shipId] {
            ship.position = SIMD2<Float>(Float(targetX), Float(targetY))
            entities[shipId] = ship
            return ActionResult(success: true)
        }
        
        return ActionResult(success: false, reason: "Ship not found")
    }
    
    private func processBuyCargo(_ action: GameAction) -> ActionResult {
        guard let playerId = action.parameters["playerId"]?.value as? String,
              let commodity = action.parameters["commodity"]?.value as? String,
              let quantity = action.parameters["quantity"]?.value as? Int,
              var playerState = playerStates[playerId] else {
            return ActionResult(success: false, reason: "Invalid parameters")
        }
        
        let price = marketState.getPrice(for: commodity) * Double(quantity)
        
        if playerState.money >= price {
            playerState.money -= price
            playerStates[playerId] = playerState
            
            // Update market state
            marketState.recordPurchase(commodity: commodity, quantity: quantity)
            
            return ActionResult(success: true)
        }
        
        return ActionResult(success: false, reason: "Insufficient funds")
    }
    
    private func processSellCargo(_ action: GameAction) -> ActionResult {
        guard let playerId = action.parameters["playerId"]?.value as? String,
              let commodity = action.parameters["commodity"]?.value as? String,
              let quantity = action.parameters["quantity"]?.value as? Int,
              var playerState = playerStates[playerId] else {
            return ActionResult(success: false, reason: "Invalid parameters")
        }
        
        let price = marketState.getPrice(for: commodity) * Double(quantity)
        playerState.money += price
        playerStates[playerId] = playerState
        
        // Update market state
        marketState.recordSale(commodity: commodity, quantity: quantity)
        
        return ActionResult(success: true)
    }
    
    private func processBuildWarehouse(_ action: GameAction) -> ActionResult {
        guard let playerId = action.parameters["playerId"]?.value as? String,
              let locationX = action.parameters["locationX"]?.value as? Double,
              let locationY = action.parameters["locationY"]?.value as? Double,
              var playerState = playerStates[playerId] else {
            return ActionResult(success: false, reason: "Invalid parameters")
        }
        
        let buildCost = 500_000.0
        
        if playerState.money >= buildCost {
            playerState.money -= buildCost
            
            // Create warehouse entity
            let warehouseId = UUID().uuidString
            let warehouse = Entity(
                id: warehouseId,
                type: .warehouse,
                ownerId: playerId,
                position: SIMD2<Float>(Float(locationX), Float(locationY))
            )
            
            entities[warehouseId] = warehouse
            playerState.warehouses.append(warehouseId)
            playerStates[playerId] = playerState
            
            return ActionResult(success: true)
        }
        
        return ActionResult(success: false, reason: "Insufficient funds")
    }
}

// MARK: - Market State

struct MarketState: Codable {
    private var commodityPrices: [String: Double] = [
        "grain": 50.0,
        "oil": 80.0,
        "electronics": 200.0,
        "steel": 120.0
    ]
    var interestRate: Double = 0.05
    
    func getPrice(for commodity: String) -> Double {
        return commodityPrices[commodity] ?? 100.0
    }
    
    mutating func updatePrices(_ newPrices: [String: Double]) {
        for (commodity, price) in newPrices {
            commodityPrices[commodity] = price
        }
    }
    
    mutating func recordPurchase(commodity: String, quantity: Int) {
        // Simple supply/demand adjustment
        if let currentPrice = commodityPrices[commodity] {
            commodityPrices[commodity] = currentPrice * (1.0 + Double(quantity) * 0.001)
        }
    }
    
    mutating func recordSale(commodity: String, quantity: Int) {
        // Simple supply/demand adjustment
        if let currentPrice = commodityPrices[commodity] {
            commodityPrices[commodity] = currentPrice * (1.0 - Double(quantity) * 0.001)
        }
    }
}

// MARK: - World State

struct WorldState: Codable {
    var weather: WeatherState = WeatherState()
    var time: GameTime = GameTime()
    var events: [GameEvent] = []
}

struct WeatherState: Codable {
    var windSpeed: Float = 10.0
    var windDirection: Float = 0.0
    var storms: [Storm] = []
}

struct GameTime: Codable {
    var day: Int = 1
    var hour: Int = 0
    var isPaused: Bool = false
}

struct GameEvent: Codable {
    let id: String
    let type: String
    let location: SIMD2<Float>
    let duration: TimeInterval
    let startTime: Date
}

// MARK: - Entity System

struct Entity: Codable {
    let id: String
    let type: EntityType
    let ownerId: String
    var position: SIMD2<Float>
    var components: [String: Data] = [:] // Component data storage
}

enum EntityType: String, Codable {
    case ship
    case warehouse
    case port
    case cargo
}

struct Storm: Codable {
    let id: String
    let center: SIMD2<Float>
    let radius: Float
    let intensity: Float
}

struct ActionResult {
    let success: Bool
    let reason: String? = nil
}