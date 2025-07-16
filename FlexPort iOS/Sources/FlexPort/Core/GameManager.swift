import Foundation
import Combine

public class GameManager: ObservableObject {
    @Published public var currentScreen: GameScreen = .mainMenu
    @Published public var gameState: GameState = GameState()
    @Published public var singularityProgress: Double = 0.0
    
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        setupBindings()
    }
    
    private func setupBindings() {
        // Monitor game state changes
    }
    
    public func startNewGame() {
        gameState = GameState()
        currentScreen = .game
    }
    
    public func navigateTo(_ screen: GameScreen) {
        currentScreen = screen
    }
}

public struct GameState: Codable {
    public var playerAssets: PlayerAssets = PlayerAssets()
    public var markets: Markets = Markets()
    public var aiCompetitors: [AICompetitor] = []
    public var tradeRoutes: [TradeRoute] = []
    public var turn: Int = 0
    public var isGameActive: Bool = true
    
    public init() {}
}

public struct PlayerAssets: Codable {
    public var money: Double = 1_000_000
    public var ships: [Ship] = []
    public var warehouses: [Warehouse] = []
    public var reputation: Double = 50.0
    
    public init() {}
}

public struct Markets: Codable {
    public var goodsMarket: GoodsMarket = GoodsMarket()
    public var capitalMarket: CapitalMarket = CapitalMarket()
    public var assetMarket: AssetMarket = AssetMarket()
    public var laborMarket: LaborMarket = LaborMarket()
    
    public init() {}
}

public struct GoodsMarket: Codable {
    public var commodities: [Commodity] = []
    
    public init() {}
}

public struct CapitalMarket: Codable {
    public var interestRate: Double = 0.05
    public var availableCapital: Double = 10_000_000
    
    public init() {}
}

public struct AssetMarket: Codable {
    public var availableShips: [Ship] = []
    public var availableWarehouses: [Warehouse] = []
    
    public init() {}
}

public struct LaborMarket: Codable {
    public var availableWorkers: [Worker] = []
    public var averageWage: Double = 50_000
    
    public init() {}
}

public struct Ship: Codable {
    public let id: UUID = UUID()
    public var name: String
    public var capacity: Int
    public var speed: Double
    public var efficiency: Double
    public var maintenanceCost: Double
    
    public init(name: String, capacity: Int, speed: Double, efficiency: Double, maintenanceCost: Double) {
        self.name = name
        self.capacity = capacity
        self.speed = speed
        self.efficiency = efficiency
        self.maintenanceCost = maintenanceCost
    }
}

public struct Warehouse: Codable {
    public let id: UUID = UUID()
    public var location: Location
    public var capacity: Int
    public var storageCost: Double
    
    public init(location: Location, capacity: Int, storageCost: Double) {
        self.location = location
        self.capacity = capacity
        self.storageCost = storageCost
    }
}

public struct Location: Codable {
    public var name: String
    public var coordinates: Coordinates
    public var portType: PortType
    
    public init(name: String, coordinates: Coordinates, portType: PortType) {
        self.name = name
        self.coordinates = coordinates
        self.portType = portType
    }
}

public struct Coordinates: Codable {
    public var latitude: Double
    public var longitude: Double
    
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public enum PortType: Codable {
    case sea
    case air
    case rail
    case multimodal
}

public struct Commodity: Codable {
    public var name: String
    public var basePrice: Double
    public var volatility: Double
    public var supply: Double
    public var demand: Double
    
    public init(name: String, basePrice: Double, volatility: Double, supply: Double, demand: Double) {
        self.name = name
        self.basePrice = basePrice
        self.volatility = volatility
        self.supply = supply
        self.demand = demand
    }
}

public struct Worker: Codable {
    public var specialization: WorkerSpecialization
    public var skill: Double
    public var wage: Double
    
    public init(specialization: WorkerSpecialization, skill: Double, wage: Double) {
        self.specialization = specialization
        self.skill = skill
        self.wage = wage
    }
}

public enum WorkerSpecialization: Codable {
    case operations
    case sales
    case engineering
    case management
}

public struct AICompetitor: Codable {
    public let id: UUID = UUID()
    public var name: String
    public var assets: PlayerAssets
    public var learningRate: Double
    public var singularityContribution: Double
    
    public init(name: String, assets: PlayerAssets, learningRate: Double, singularityContribution: Double) {
        self.name = name
        self.assets = assets
        self.learningRate = learningRate
        self.singularityContribution = singularityContribution
    }
}

public struct TradeRoute: Codable {
    public let id: UUID
    public var name: String
    public var startPort: String
    public var endPort: String
    public var assignedShips: [UUID]
    public var goodsType: String
    public var profitMargin: Double
    public var status: TradeRouteStatus
    public var createdAt: Date
    
    public init(id: UUID, name: String, startPort: String, endPort: String, assignedShips: [UUID], goodsType: String, profitMargin: Double) {
        self.id = id
        self.name = name
        self.startPort = startPort
        self.endPort = endPort
        self.assignedShips = assignedShips
        self.goodsType = goodsType
        self.profitMargin = profitMargin
        self.status = .active
        self.createdAt = Date()
    }
}

public enum TradeRouteStatus: Codable {
    case active
    case suspended
    case completed
}