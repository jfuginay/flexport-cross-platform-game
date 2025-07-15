import Foundation
import Combine

class GameManager: ObservableObject {
    @Published var currentScreen: GameScreen = .mainMenu
    @Published var gameState: GameState = GameState()
    @Published var singularityProgress: Double = 0.0
    
    init() {
        initializeGameData()
    }
    
    func startNewGame() {
        gameState = GameState()
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
}

enum GameScreen {
    case mainMenu
    case game
    case settings
}

struct GameState {
    var playerAssets: PlayerAssets = PlayerAssets()
    var markets: Markets = Markets()
    var aiCompetitors: [AICompetitor] = []
    var turn: Int = 0
    var isGameActive: Bool = true
}

struct PlayerAssets {
    var money: Double = 1_000_000
    var ships: [Ship] = []
    var warehouses: [Warehouse] = []
    var reputation: Double = 50.0
}

struct Markets {
    var goodsMarket: GoodsMarket = GoodsMarket()
    var capitalMarket: CapitalMarket = CapitalMarket()
    var assetMarket: AssetMarket = AssetMarket()
    var laborMarket: LaborMarket = LaborMarket()
}

struct GoodsMarket {
    var commodities: [Commodity] = []
}

struct CapitalMarket {
    var interestRate: Double = 0.05
    var availableCapital: Double = 10_000_000
}

struct AssetMarket {
    var availableShips: [Ship] = []
    var availableWarehouses: [Warehouse] = []
}

struct LaborMarket {
    var availableWorkers: [Worker] = []
    var averageWage: Double = 50_000
}

struct Ship {
    let id: UUID = UUID()
    var name: String
    var capacity: Int
    var speed: Double
    var efficiency: Double
    var maintenanceCost: Double
}

struct Warehouse {
    let id: UUID = UUID()
    var location: Location
    var capacity: Int
    var storageCost: Double
}

struct Location {
    var name: String
    var coordinates: Coordinates
    var portType: PortType
}

struct Coordinates {
    var latitude: Double
    var longitude: Double
}

enum PortType {
    case sea
    case air
    case rail
    case multimodal
}

struct Commodity {
    var name: String
    var basePrice: Double
    var volatility: Double
    var supply: Double
    var demand: Double
}

struct Worker {
    var specialization: WorkerSpecialization
    var skill: Double
    var wage: Double
}

enum WorkerSpecialization {
    case operations
    case sales
    case engineering
    case management
}

struct AICompetitor {
    let id: UUID = UUID()
    var name: String
    var assets: PlayerAssets
    var learningRate: Double
    var singularityContribution: Double
}