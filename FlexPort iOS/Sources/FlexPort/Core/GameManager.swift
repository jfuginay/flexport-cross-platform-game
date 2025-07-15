import Foundation
import Combine

class GameManager: ObservableObject {
    @Published var currentScreen: GameScreen = .mainMenu
    @Published var gameState: GameState = GameState()
    @Published var singularityProgress: Double = 0.0
    @Published var isMultiplayer: Bool = false
    @Published var multiplayerStatus: String = ""
    
    private var cancellables = Set<AnyCancellable>()
    private let multiplayerManager = MultiplayerManager.shared
    private let offlineManager = OfflineManager.shared
    private let leaderboardService = LeaderboardService.shared
    
    init() {
        setupBindings()
        setupNetworkingObservers()
        initializeGameData()
    }
    
    private func setupBindings() {
        // Monitor game state changes for networking sync
        $gameState
            .dropFirst()
            .sink { [weak self] newState in
                self?.handleGameStateChange(newState)
            }
            .store(in: &cancellables)
    }
    
    private func setupNetworkingObservers() {
        // Monitor multiplayer connection state
        multiplayerManager.$connectionState
            .sink { [weak self] state in
                self?.updateMultiplayerStatus(state)
            }
            .store(in: &cancellables)
        
        // Handle incoming game actions
        NotificationCenter.default.publisher(for: .gameActionReceived)
            .compactMap { $0.object as? GameAction }
            .sink { [weak self] action in
                self?.handleRemoteGameAction(action)
            }
            .store(in: &cancellables)
        
        // Handle game state updates
        NotificationCenter.default.publisher(for: .gameStateUpdated)
            .compactMap { $0.object as? GameStateUpdate }
            .sink { [weak self] update in
                self?.handleRemoteStateUpdate(update)
            }
            .store(in: &cancellables)
    }
    
    func startNewGame() {
        gameState = GameState()
        currentScreen = .game
    }
    
    func startMultiplayerGame(gameMode: GameMode) async throws {
        try await multiplayerManager.startMultiplayerGame(gameMode: gameMode)
        isMultiplayer = true
        currentScreen = .game
    }
    
    func navigateTo(_ screen: GameScreen) {
        currentScreen = screen
    }
    
    private func initializeGameData() {
        // Initialize with sample ships
        gameState.playerAssets.ships = [
            Ship(name: "Pacific Voyager", capacity: 2000, speed: 18.5, efficiency: 0.85, maintenanceCost: 12000),
            Ship(name: "Atlantic Express", capacity: 1500, speed: 22.0, efficiency: 0.78, maintenanceCost: 9500),
            Ship(name: "Container King", capacity: 3000, speed: 16.0, efficiency: 0.92, maintenanceCost: 18000)
        ]
        
        // Initialize available ships in market
        gameState.markets.assetMarket.availableShips = [
            Ship(name: "Ocean Master", capacity: 2500, speed: 20.0, efficiency: 0.88, maintenanceCost: 15000),
            Ship(name: "Swift Trader", capacity: 1200, speed: 25.0, efficiency: 0.75, maintenanceCost: 8000),
            Ship(name: "Mega Hauler", capacity: 4000, speed: 14.0, efficiency: 0.95, maintenanceCost: 25000)
        ]
        
        // Initialize commodities
        gameState.markets.goodsMarket.commodities = [
            Commodity(name: "Electronics", basePrice: 2450, volatility: 0.15, supply: 1000, demand: 1200),
            Commodity(name: "Textiles", basePrice: 890, volatility: 0.08, supply: 800, demand: 750),
            Commodity(name: "Machinery", basePrice: 3200, volatility: 0.12, supply: 600, demand: 700),
            Commodity(name: "Food Products", basePrice: 1100, volatility: 0.20, supply: 1500, demand: 1400),
            Commodity(name: "Automotive Parts", basePrice: 4000, volatility: 0.10, supply: 400, demand: 450)
        ]
        
        // Initialize AI competitors
        gameState.aiCompetitors = [
            AICompetitor(name: "AlphaTrade", assets: PlayerAssets(money: 800000, ships: [], warehouses: [], reputation: 60.0), learningRate: 0.15, singularityContribution: 0.12),
            AICompetitor(name: "QuantumLogistics", assets: PlayerAssets(money: 1200000, ships: [], warehouses: [], reputation: 75.0), learningRate: 0.20, singularityContribution: 0.18),
            AICompetitor(name: "NeuralShip", assets: PlayerAssets(money: 950000, ships: [], warehouses: [], reputation: 65.0), learningRate: 0.18, singularityContribution: 0.15)
        ]
        
        // Set initial singularity progress
        singularityProgress = 0.23
    }
    
    // MARK: - Game Actions
    func executeGameAction(_ actionType: String, parameters: [String: Any]) async throws {
        let playerId = getCurrentPlayerId()
        let action = GameAction(
            playerId: playerId,
            actionType: actionType,
            parameters: parameters.mapValues { AnyCodable($0) }
        )
        
        // Apply action locally first for responsiveness
        applyGameAction(action)
        
        // Send to multiplayer if in multiplayer mode
        if isMultiplayer {
            try await multiplayerManager.sendGameAction(action)
        }
    }
    
    func completeTurn() async throws {
        gameState.turn += 1
        
        if isMultiplayer {
            try await multiplayerManager.completeTurn(gameState: gameState)
        } else {
            // Save state for offline play
            offlineManager.saveGameStateSnapshot(gameState, sessionId: "offline")
        }
        
        // Update singularity progress
        updateSingularityProgress()
    }
    
    // MARK: - Private Methods
    private func handleGameStateChange(_ newState: GameState) {
        // Auto-save game state
        if !isMultiplayer {
            offlineManager.saveGameStateSnapshot(newState, sessionId: "offline")
        }
        
        // Update derived values
        updateSingularityProgress()
    }
    
    private func handleRemoteGameAction(_ action: GameAction) {
        // Apply remote player's action
        applyGameAction(action)
    }
    
    private func handleRemoteStateUpdate(_ update: GameStateUpdate) {
        // Sync turn number
        gameState.turn = update.turn
        
        // Update markets with remote data
        updateMarketsFromSnapshot(update.marketState)
    }
    
    private func applyGameAction(_ action: GameAction) {
        // Apply action to game state based on action type
        switch action.actionType {
        case "buyShip":
            handleBuyShipAction(action.parameters)
        case "sellShip":
            handleSellShipAction(action.parameters)
        case "buyWarehouse":
            handleBuyWarehouseAction(action.parameters)
        case "tradeCommodity":
            handleTradeCommodityAction(action.parameters)
        default:
            print("Unknown action type: \(action.actionType)")
        }
    }
    
    private func handleBuyShipAction(_ parameters: [String: AnyCodable]) {
        // Implementation for buying ships
        guard let shipName = parameters["shipName"]?.value as? String,
              let price = parameters["price"]?.value as? Double else { return }
        
        if gameState.playerAssets.money >= price {
            let ship = Ship(
                name: shipName,
                capacity: 1000,
                speed: 1.0,
                efficiency: 0.8,
                maintenanceCost: price * 0.01
            )
            gameState.playerAssets.ships.append(ship)
            gameState.playerAssets.money -= price
        }
    }
    
    private func handleSellShipAction(_ parameters: [String: AnyCodable]) {
        // Implementation for selling ships
        guard let shipId = parameters["shipId"]?.value as? String,
              let shipUUID = UUID(uuidString: shipId),
              let price = parameters["price"]?.value as? Double else { return }
        
        if let index = gameState.playerAssets.ships.firstIndex(where: { $0.id == shipUUID }) {
            gameState.playerAssets.ships.remove(at: index)
            gameState.playerAssets.money += price
        }
    }
    
    private func handleBuyWarehouseAction(_ parameters: [String: AnyCodable]) {
        // Implementation for buying warehouses
        guard let locationName = parameters["locationName"]?.value as? String,
              let price = parameters["price"]?.value as? Double else { return }
        
        if gameState.playerAssets.money >= price {
            let location = Location(
                name: locationName,
                coordinates: Coordinates(latitude: 0, longitude: 0),
                portType: .multimodal
            )
            let warehouse = Warehouse(
                location: location,
                capacity: 5000,
                storageCost: price * 0.005
            )
            gameState.playerAssets.warehouses.append(warehouse)
            gameState.playerAssets.money -= price
        }
    }
    
    private func handleTradeCommodityAction(_ parameters: [String: AnyCodable]) {
        // Implementation for commodity trading
        guard let commodityName = parameters["commodityName"]?.value as? String,
              let quantity = parameters["quantity"]?.value as? Double,
              let price = parameters["price"]?.value as? Double,
              let isBuying = parameters["isBuying"]?.value as? Bool else { return }
        
        let totalCost = quantity * price
        
        if isBuying && gameState.playerAssets.money >= totalCost {
            gameState.playerAssets.money -= totalCost
            // Add commodity to inventory (would need inventory system)
        } else if !isBuying {
            gameState.playerAssets.money += totalCost
            // Remove commodity from inventory
        }
    }
    
    private func updateMarketsFromSnapshot(_ snapshot: MarketStateSnapshot) {
        // Update commodity prices
        for (name, price) in snapshot.commodityPrices {
            if let index = gameState.markets.goodsMarket.commodities.firstIndex(where: { $0.name == name }) {
                gameState.markets.goodsMarket.commodities[index].basePrice = price
            }
        }
        
        // Update interest rate
        gameState.markets.capitalMarket.interestRate = snapshot.interestRate
    }
    
    private func updateSingularityProgress() {
        // Calculate singularity progress based on game state
        let wealthFactor = min(gameState.playerAssets.money / 100_000_000, 1.0) * 0.3
        let assetFactor = min(Double(gameState.playerAssets.ships.count + gameState.playerAssets.warehouses.count) / 50, 1.0) * 0.3
        let reputationFactor = min(gameState.playerAssets.reputation / 100, 1.0) * 0.2
        let turnFactor = min(Double(gameState.turn) / 100, 1.0) * 0.2
        
        singularityProgress = (wealthFactor + assetFactor + reputationFactor + turnFactor) * 100
    }
    
    private func updateMultiplayerStatus(_ state: ConnectionState) {
        switch state {
        case .disconnected:
            multiplayerStatus = "Disconnected"
        case .connecting:
            multiplayerStatus = "Connecting..."
        case .connected:
            multiplayerStatus = "Connected"
        case .reconnecting:
            multiplayerStatus = "Reconnecting..."
        }
    }
    
    private func getCurrentPlayerId() -> String {
        return UserDefaults.standard.string(forKey: "playerId") ?? "player_\(UUID().uuidString)"
    }
}

// MARK: - Game Screen Enum
enum GameScreen {
    case mainMenu
    case game
    case leaderboard
    case settings
    case multiplayer
}

struct GameState: Codable {
    var playerAssets: PlayerAssets = PlayerAssets()
    var markets: Markets = Markets()
    var aiCompetitors: [AICompetitor] = []
    var turn: Int = 0
    var isGameActive: Bool = true
}

struct PlayerAssets: Codable {
    var money: Double = 1_000_000
    var ships: [Ship] = []
    var warehouses: [Warehouse] = []
    var reputation: Double = 50.0
}

struct Markets: Codable {
    var goodsMarket: GoodsMarket = GoodsMarket()
    var capitalMarket: CapitalMarket = CapitalMarket()
    var assetMarket: AssetMarket = AssetMarket()
    var laborMarket: LaborMarket = LaborMarket()
}

struct GoodsMarket: Codable {
    var commodities: [Commodity] = []
}

struct CapitalMarket: Codable {
    var interestRate: Double = 0.05
    var availableCapital: Double = 10_000_000
}

struct AssetMarket: Codable {
    var availableShips: [Ship] = []
    var availableWarehouses: [Warehouse] = []
}

struct LaborMarket: Codable {
    var availableWorkers: [Worker] = []
    var averageWage: Double = 50_000
}

struct Ship: Codable {
    let id: UUID
    var name: String
    var capacity: Int
    var speed: Double
    var efficiency: Double
    var maintenanceCost: Double
    
    init(name: String, capacity: Int, speed: Double, efficiency: Double, maintenanceCost: Double) {
        self.id = UUID()
        self.name = name
        self.capacity = capacity
        self.speed = speed
        self.efficiency = efficiency
        self.maintenanceCost = maintenanceCost
    }
}

struct Warehouse: Codable {
    let id: UUID
    var location: Location
    var capacity: Int
    var storageCost: Double
    
    init(location: Location, capacity: Int, storageCost: Double) {
        self.id = UUID()
        self.location = location
        self.capacity = capacity
        self.storageCost = storageCost
    }
}

struct Location: Codable {
    var name: String
    var coordinates: Coordinates
    var portType: PortType
}

struct Coordinates: Codable {
    var latitude: Double
    var longitude: Double
}

enum PortType: String, Codable {
    case sea
    case air
    case rail
    case multimodal
}

struct Commodity: Codable {
    var name: String
    var basePrice: Double
    var volatility: Double
    var supply: Double
    var demand: Double
}

struct Worker: Codable {
    var specialization: WorkerSpecialization
    var skill: Double
    var wage: Double
}

enum WorkerSpecialization: String, Codable {
    case operations
    case sales
    case engineering
    case management
}

struct AICompetitor: Codable {
    let id: UUID
    var name: String
    var assets: PlayerAssets
    var learningRate: Double
    var singularityContribution: Double
    
    init(name: String, assets: PlayerAssets, learningRate: Double, singularityContribution: Double) {
        self.id = UUID()
        self.name = name
        self.assets = assets
        self.learningRate = learningRate
        self.singularityContribution = singularityContribution
    }
}