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
        
        // Container 2: Ship AI & Movement System - Auto Movement
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            self.updateShipMovement()
        }
        
        // Container 3: Advanced Economic Engine - Market Updates
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            self.updateMarketPrices()
        }
        
        // Container 5: Game Progression - Achievement & Research Updates
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            self.updateProgression()
        }
    }
    
    // Container 2: Ship AI & Movement System - Movement Logic
    private func updateShipMovement() {
        for i in 0..<gameState.playerAssets.ships.count {
            var ship = gameState.playerAssets.ships[i]
            
            // Find assigned trade route
            if let routeId = ship.assignedRoute,
               let route = gameState.tradeRoutes.first(where: { $0.id == routeId }) {
                
                switch ship.movementState {
                case .docked:
                    // Start journey to destination
                    ship.targetPort = (ship.currentPort == route.startPort) ? route.endPort : route.startPort
                    ship.targetPosition = Ship.getPortCoordinates(port: ship.targetPort!)
                    ship.movementState = .departing
                    
                case .departing:
                    ship.movementState = .traveling
                    
                case .traveling:
                    // Move towards target
                    let distance = calculateDistance(from: ship.currentPosition, to: ship.targetPosition)
                    if distance < 0.5 { // Close enough to port
                        ship.movementState = .arriving
                    } else {
                        // Move ship towards target
                        ship.currentPosition = moveTowards(from: ship.currentPosition, to: ship.targetPosition, speed: ship.speed)
                    }
                    
                case .arriving:
                    ship.currentPort = ship.targetPort
                    ship.currentPosition = ship.targetPosition
                    ship.movementState = .loading
                    
                case .loading:
                    ship.cargoLoad = min(ship.cargoLoad + 10, 100)
                    if ship.cargoLoad >= 80 {
                        ship.movementState = .docked
                    }
                    
                case .unloading:
                    ship.cargoLoad = max(ship.cargoLoad - 10, 0)
                    if ship.cargoLoad <= 20 {
                        ship.movementState = .docked
                    }
                }
            } else {
                // No route assigned, assign to random route
                if let randomRoute = gameState.tradeRoutes.randomElement() {
                    ship.assignedRoute = randomRoute.id
                }
            }
            
            gameState.playerAssets.ships[i] = ship
        }
    }
    
    private func calculateDistance(from: Coordinates, to: Coordinates) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lon1 = from.longitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let lon2 = to.longitude * .pi / 180
        
        let dLat = lat2 - lat1
        let dLon = lon2 - lon1
        
        let a = sin(dLat/2) * sin(dLat/2) + cos(lat1) * cos(lat2) * sin(dLon/2) * sin(dLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        
        return c * 6371 // Earth's radius in km
    }
    
    private func moveTowards(from: Coordinates, to: Coordinates, speed: Double) -> Coordinates {
        let factor = 0.01 * speed / 100 // Movement factor
        let newLat = from.latitude + (to.latitude - from.latitude) * factor
        let newLon = from.longitude + (to.longitude - from.longitude) * factor
        return Coordinates(latitude: newLat, longitude: newLon)
    }
    
    // Container 3: Advanced Economic Engine - Market Update Logic
    private func updateMarketPrices() {
        // Update commodity prices
        for i in 0..<gameState.markets.goodsMarket.commodities.count {
            gameState.markets.goodsMarket.commodities[i].updatePrice()
        }
        
        // Generate random economic events
        if Double.random(in: 0...1) < 0.1 { // 10% chance per update
            generateEconomicEvent()
        }
        
        // Update trade route profitability based on current prices
        updateTradeRouteProfitability()
    }
    
    private func generateEconomicEvent() {
        let events = [
            EconomicEvent(name: "Port Strike", description: "Workers strike affects port operations", priceMultiplier: 1.2, duration: 10, affectedCategories: [.manufacturing]),
            EconomicEvent(name: "Oil Price Surge", description: "Energy costs increase", priceMultiplier: 1.5, duration: 15, affectedCategories: [.energy]),
            EconomicEvent(name: "Good Harvest", description: "Agricultural yields exceed expectations", priceMultiplier: 0.8, duration: 20, affectedCategories: [.agriculture]),
            EconomicEvent(name: "Tech Boom", description: "Innovation drives demand", priceMultiplier: 1.3, duration: 25, affectedCategories: [.technology]),
            EconomicEvent(name: "Trade War", description: "International tensions affect trade", priceMultiplier: 1.1, duration: 30, affectedCategories: [.manufacturing, .technology])
        ]
        
        if let event = events.randomElement() {
            // Apply event to relevant commodities
            for i in 0..<gameState.markets.goodsMarket.commodities.count {
                let commodity = gameState.markets.goodsMarket.commodities[i]
                if event.affectedCategories.contains(commodity.category) {
                    gameState.markets.goodsMarket.commodities[i].globalEvents.append(event)
                }
            }
        }
    }
    
    private func updateTradeRouteProfitability() {
        for i in 0..<gameState.tradeRoutes.count {
            // Calculate new profit margin based on current market conditions
            let baseProfit = gameState.tradeRoutes[i].profitMargin
            let marketFactor = Double.random(in: 0.8...1.2) // Market volatility
            gameState.tradeRoutes[i].profitMargin = baseProfit * marketFactor
        }
    }
    
    // Container 5: Game Progression - Achievement & Research Logic
    private func updateProgression() {
        // Update research progress
        if let currentResearch = gameState.researchTree.currentResearch {
            gameState.researchTree.researchPoints += 1
            
            // Complete research if enough points
            if gameState.researchTree.researchPoints >= currentResearch.cost {
                completeResearch(currentResearch)
            }
        }
        
        // Update achievements
        updateAchievements()
        
        // Update game statistics
        gameState.gameStats.playTime += 3.0 // 3 second intervals
        gameState.gameStats.totalEarnings = gameState.playerAssets.money
        
        // Update singularity progress based on research
        let aiResearch = gameState.researchTree.completedResearch.filter { $0.category == .artificial_intelligence }
        singularityProgress = min(Double(aiResearch.count) * 0.2, 1.0)
    }
    
    private func completeResearch(_ research: ResearchProject) {
        // Move to completed research
        gameState.researchTree.completedResearch.append(research)
        gameState.researchTree.currentResearch = nil
        gameState.researchTree.researchPoints = 0
        
        // Apply research benefits
        applyResearchBenefits(research)
    }
    
    private func applyResearchBenefits(_ research: ResearchProject) {
        switch research.category {
        case .navigation:
            // Increase ship speed
            for i in 0..<gameState.playerAssets.ships.count {
                gameState.playerAssets.ships[i].speed *= 1.25
            }
        case .efficiency:
            // Reduce fuel consumption (increase efficiency)
            for i in 0..<gameState.playerAssets.ships.count {
                gameState.playerAssets.ships[i].efficiency *= 1.2
            }
        case .automation:
            // Faster loading times (handled in ship movement logic)
            break
        case .intelligence:
            // Better market predictions (handled in economic system)
            break
        case .artificial_intelligence:
            // Automated optimization (handled in AI system)
            break
        }
    }
    
    private func updateAchievements() {
        for i in 0..<gameState.achievements.count {
            let achievement = gameState.achievements[i]
            
            switch achievement.name {
            case "First Trade":
                gameState.achievements[i].progress = gameState.tradeRoutes.count
            case "Fleet Captain":
                gameState.achievements[i].progress = gameState.playerAssets.ships.count
            case "Millionaire":
                gameState.achievements[i].progress = Int(gameState.playerAssets.money)
            case "Global Trader":
                let uniquePorts = Set(gameState.tradeRoutes.flatMap { [$0.startPort, $0.endPort] })
                gameState.achievements[i].progress = uniquePorts.count
            case "Speed Demon":
                gameState.achievements[i].progress = gameState.gameStats.totalTrades
            case "AI Overlord":
                gameState.achievements[i].progress = Int(singularityProgress * 100)
            default:
                break
            }
            
            // Unlock achievement if target reached
            if gameState.achievements[i].progress >= achievement.target && !achievement.isUnlocked {
                gameState.achievements[i].isUnlocked = true
            }
        }
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
    
    // Container 5: Game Progression & Content - Research System
    public var researchTree: ResearchTree = ResearchTree()
    public var achievements: [Achievement] = []
    public var gameStats: GameStatistics = GameStatistics()
    
    public init() {
        // Initialize achievements
        achievements = [
            Achievement(name: "First Trade", description: "Complete your first trade route", target: 1),
            Achievement(name: "Fleet Captain", description: "Own 5 ships", target: 5),
            Achievement(name: "Millionaire", description: "Earn $1,000,000", target: 1000000),
            Achievement(name: "Global Trader", description: "Trade with all 7 major ports", target: 7),
            Achievement(name: "Speed Demon", description: "Complete 50 trades", target: 50),
            Achievement(name: "AI Overlord", description: "Reach 100% AI singularity", target: 100)
        ]
    }
}

// Container 5: Game Progression & Content - Research System
public struct ResearchTree: Codable {
    public var availableResearch: [ResearchProject] = []
    public var completedResearch: [ResearchProject] = []
    public var currentResearch: ResearchProject?
    public var researchPoints: Int = 0
    
    public init() {
        availableResearch = [
            ResearchProject(name: "Advanced Navigation", description: "Increases ship speed by 25%", cost: 100, category: .navigation),
            ResearchProject(name: "Fuel Efficiency", description: "Reduces fuel consumption by 20%", cost: 150, category: .efficiency),
            ResearchProject(name: "Port Automation", description: "Faster loading/unloading times", cost: 200, category: .automation),
            ResearchProject(name: "Market Analysis", description: "Better commodity price predictions", cost: 250, category: .intelligence),
            ResearchProject(name: "AI Assistant", description: "Automated trade route optimization", cost: 500, category: .artificial_intelligence)
        ]
    }
}

public struct ResearchProject: Codable, Identifiable {
    public let id = UUID()
    public var name: String
    public var description: String
    public var cost: Int
    public var category: ResearchCategory
    public var progress: Int = 0
    
    public init(name: String, description: String, cost: Int, category: ResearchCategory) {
        self.name = name
        self.description = description
        self.cost = cost
        self.category = category
    }
}

public enum ResearchCategory: Codable {
    case navigation, efficiency, automation, intelligence, artificial_intelligence
}

public struct Achievement: Codable, Identifiable {
    public let id = UUID()
    public var name: String
    public var description: String
    public var isUnlocked: Bool = false
    public var progress: Int = 0
    public var target: Int
    
    public init(name: String, description: String, target: Int) {
        self.name = name
        self.description = description
        self.target = target
    }
}

public struct GameStatistics: Codable {
    public var totalEarnings: Double = 0
    public var totalDistanceTraveled: Double = 0
    public var totalCargoDelivered: Int = 0
    public var totalTrades: Int = 0
    public var playTime: TimeInterval = 0
    public var bestProfit: Double = 0
    
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
    
    public init() {
        // Container 3: Initialize with default commodities
        commodities = [
            Commodity(name: "Crude Oil", basePrice: 70.0, volatility: 15.0, supply: 100.0, demand: 95.0, category: .energy),
            Commodity(name: "Steel", basePrice: 800.0, volatility: 10.0, supply: 80.0, demand: 85.0, category: .metals),
            Commodity(name: "Wheat", basePrice: 250.0, volatility: 20.0, supply: 120.0, demand: 100.0, category: .agriculture),
            Commodity(name: "Electronics", basePrice: 1200.0, volatility: 25.0, supply: 60.0, demand: 90.0, category: .technology),
            Commodity(name: "Textiles", basePrice: 15.0, volatility: 12.0, supply: 110.0, demand: 105.0, category: .manufacturing),
            Commodity(name: "Coffee", basePrice: 4.5, volatility: 30.0, supply: 90.0, demand: 100.0, category: .agriculture),
            Commodity(name: "Gold", basePrice: 2000.0, volatility: 8.0, supply: 40.0, demand: 45.0, category: .luxury),
            Commodity(name: "Automobiles", basePrice: 25000.0, volatility: 15.0, supply: 70.0, demand: 80.0, category: .manufacturing)
        ]
    }
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
    
    // Container 2: Ship AI & Movement System - Enhanced Properties
    public var currentPosition: Coordinates = Coordinates(latitude: 0, longitude: 0)
    public var targetPosition: Coordinates = Coordinates(latitude: 0, longitude: 0)
    public var currentPort: String?
    public var targetPort: String?
    public var movementState: ShipMovementState = .docked
    public var cargoLoad: Double = 0.0
    public var fuel: Double = 100.0
    public var assignedRoute: UUID?
    
    public init(name: String, capacity: Int, speed: Double, efficiency: Double, maintenanceCost: Double) {
        self.name = name
        self.capacity = capacity
        self.speed = speed
        self.efficiency = efficiency
        self.maintenanceCost = maintenanceCost
        
        // Initialize at random port
        let ports = ["Singapore", "Hong Kong", "Shanghai", "Los Angeles", "New York", "London", "Dubai"]
        let randomPort = ports.randomElement() ?? "Singapore"
        self.currentPort = randomPort
        self.currentPosition = Self.getPortCoordinates(port: randomPort)
    }
    
    static func getPortCoordinates(port: String) -> Coordinates {
        let portCoordinates: [String: Coordinates] = [
            "Singapore": Coordinates(latitude: 1.3521, longitude: 103.8198),
            "Hong Kong": Coordinates(latitude: 22.3193, longitude: 114.1694),
            "Shanghai": Coordinates(latitude: 31.2304, longitude: 121.4737),
            "Los Angeles": Coordinates(latitude: 34.0522, longitude: -118.2437),
            "New York": Coordinates(latitude: 40.7128, longitude: -74.0060),
            "London": Coordinates(latitude: 51.5074, longitude: -0.1278),
            "Dubai": Coordinates(latitude: 25.2048, longitude: 55.2708)
        ]
        return portCoordinates[port] ?? Coordinates(latitude: 0, longitude: 0)
    }
}

public enum ShipMovementState: Codable {
    case docked
    case departing
    case traveling
    case arriving
    case loading
    case unloading
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
    
    // Container 3: Advanced Economic Engine - Enhanced Properties
    public var currentPrice: Double
    public var priceHistory: [Double] = []
    public var category: CommodityCategory
    public var seasonalFactor: Double = 1.0
    public var globalEvents: [EconomicEvent] = []
    
    public init(name: String, basePrice: Double, volatility: Double, supply: Double, demand: Double, category: CommodityCategory) {
        self.name = name
        self.basePrice = basePrice
        self.volatility = volatility
        self.supply = supply
        self.demand = demand
        self.category = category
        self.currentPrice = basePrice
        self.priceHistory = [basePrice]
    }
    
    public mutating func updatePrice() {
        // Supply/demand dynamics
        let supplyDemandRatio = supply / demand
        let supplyDemandEffect = 1.0 / supplyDemandRatio
        
        // Volatility factor
        let volatilityEffect = 1.0 + (Double.random(in: -volatility...volatility) / 100)
        
        // Global events impact
        let eventEffect = globalEvents.reduce(1.0) { result, event in
            result * event.priceMultiplier
        }
        
        // Calculate new price
        currentPrice = basePrice * supplyDemandEffect * volatilityEffect * eventEffect * seasonalFactor
        
        // Update history
        priceHistory.append(currentPrice)
        if priceHistory.count > 100 { // Keep last 100 prices
            priceHistory.removeFirst()
        }
    }
}

public enum CommodityCategory: Codable {
    case energy, metals, agriculture, manufacturing, technology, luxury
}

public struct EconomicEvent: Codable {
    public var name: String
    public var description: String
    public var priceMultiplier: Double
    public var duration: Int
    public var affectedCategories: [CommodityCategory]
    
    public init(name: String, description: String, priceMultiplier: Double, duration: Int, affectedCategories: [CommodityCategory]) {
        self.name = name
        self.description = description
        self.priceMultiplier = priceMultiplier
        self.duration = duration
        self.affectedCategories = affectedCategories
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