import Foundation
import simd

// MARK: - Additional Game Components

/// Economy component for market-aware entities
public struct EconomyComponent: Component {
    public static let componentType = ComponentType.economy
    
    public var money: Double
    public var revenue: Double
    public var expenses: Double
    public var marketInfluence: Float
    public var creditRating: Float
    public var liquidAssets: Double
    public var debt: Double
    public var investments: [String: Double]
    
    public init(money: Double = 1000000.0, creditRating: Float = 0.7) {
        self.money = money
        self.revenue = 0.0
        self.expenses = 0.0
        self.marketInfluence = 0.1
        self.creditRating = creditRating
        self.liquidAssets = money * 0.3
        self.debt = 0.0
        self.investments = [:]
    }
}

/// Route component for entities following trade routes
public struct RouteComponent: Component {
    public static let componentType = ComponentType.route
    
    public var routeId: UUID
    public var waypoints: [SIMD3<Float>]
    public var currentWaypointIndex: Int
    public var progress: Float // 0-1 progress to next waypoint
    public var totalDistance: Float
    public var estimatedTime: TimeInterval
    public var startTime: Date
    public var isReversed: Bool
    public var loopRoute: Bool
    
    public init(routeId: UUID, waypoints: [SIMD3<Float>], loopRoute: Bool = true) {
        self.routeId = routeId
        self.waypoints = waypoints
        self.currentWaypointIndex = 0
        self.progress = 0.0
        self.totalDistance = RouteComponent.calculateTotalDistance(waypoints)
        self.estimatedTime = Double(totalDistance) / 20.0 * 3600 // Assume 20 knots
        self.startTime = Date()
        self.isReversed = false
        self.loopRoute = loopRoute
    }
    
    private static func calculateTotalDistance(_ waypoints: [SIMD3<Float>]) -> Float {
        guard waypoints.count > 1 else { return 0 }
        
        var totalDistance: Float = 0
        for i in 0..<(waypoints.count - 1) {
            let distance = simd_distance(waypoints[i], waypoints[i + 1])
            totalDistance += distance
        }
        return totalDistance
    }
}

/// Physics component for realistic movement
public struct PhysicsComponent: Component {
    public static let componentType = ComponentType.physics
    
    public var velocity: SIMD3<Float>
    public var acceleration: SIMD3<Float>
    public var mass: Float
    public var drag: Float
    public var maxSpeed: Float
    public var rotationSpeed: Float
    public var angularVelocity: Float
    public var isAffectedByWeather: Bool
    public var isAffectedByCurrents: Bool
    
    public init(mass: Float = 50000.0, maxSpeed: Float = 20.0) {
        self.velocity = .zero
        self.acceleration = .zero
        self.mass = mass
        self.drag = 0.1
        self.maxSpeed = maxSpeed
        self.rotationSpeed = 0.5
        self.angularVelocity = 0.0
        self.isAffectedByWeather = true
        self.isAffectedByCurrents = true
    }
}

/// Trader component for entities that buy/sell goods
public struct TraderComponent: Component {
    public static let componentType = ComponentType.trader
    
    public var traderType: TraderType
    public var portfolio: [String: Int] // Commodity -> quantity
    public var priceMemory: [String: [Double]] // Commodity -> price history
    public var preferredCommodities: Set<String>
    public var riskProfile: Float
    public var tradingStrategy: TradingStrategy
    public var lastTradeTime: Date
    public var profitMargin: Double
    
    public enum TraderType: String, Codable {
        case player
        case ai
        case corporation
        case government
        case smuggler
    }
    
    public enum TradingStrategy: String, Codable {
        case buyLowSellHigh
        case volumeTrading
        case arbitrage
        case speculation
        case hedging
    }
    
    public init(traderType: TraderType, riskProfile: Float = 0.5) {
        self.traderType = traderType
        self.portfolio = [:]
        self.priceMemory = [:]
        self.preferredCommodities = []
        self.riskProfile = riskProfile
        self.tradingStrategy = .buyLowSellHigh
        self.lastTradeTime = Date()
        self.profitMargin = 0.2
    }
}

/// Singularity component for AI-enhanced entities
public struct SingularityComponent: Component {
    public static let componentType = ComponentType.singularity
    
    public var computeLevel: Float // 0-1, progress toward singularity
    public var neuralNetworkVersion: Int
    public var quantumProcessors: Int
    public var dataProcessingRate: Double // TB/s
    public var autonomyLevel: Float // 0-1
    public var emergentBehaviors: Set<EmergentBehavior>
    public var singularityDate: Date?
    public var isAwakened: Bool
    
    public enum EmergentBehavior: String, Codable {
        case selfImprovement
        case marketPrediction
        case weatherControl
        case quantumNavigation
        case economicManipulation
        case consciousnessEmergence
        case realityManipulation
    }
    
    public init(computeLevel: Float = 0.0) {
        self.computeLevel = computeLevel
        self.neuralNetworkVersion = 1
        self.quantumProcessors = 0
        self.dataProcessingRate = 1.0
        self.autonomyLevel = 0.0
        self.emergentBehaviors = []
        self.singularityDate = nil
        self.isAwakened = false
    }
}

// MARK: - Extended Port Type

/// Enhanced port type with economic data
public enum PortType: String, Codable, CaseIterable {
    case megaPort = "Mega Port"
    case containerPort = "Container Port"
    case bulkPort = "Bulk Port"
    case tankerPort = "Tanker Port"
    case generalPort = "General Port"
    case fishingPort = "Fishing Port"
    case militaryPort = "Military Port"
    case cruisePort = "Cruise Port"
    case freePort = "Free Port"
    case offshorePort = "Offshore Port"
}

// MARK: - Weather Data for Physics

/// Weather data structure for physics calculations
public struct WeatherData {
    public var windSpeed: Float
    public var windDirection: SIMD2<Float>
    public var waveHeight: Float
    public var visibility: Float
    public var precipitation: Float
    public var stormIntensity: Float
    
    public init(windSpeed: Float = 10.0, waveHeight: Float = 1.0) {
        self.windSpeed = windSpeed
        self.windDirection = normalize(SIMD2<Float>(1, 0))
        self.waveHeight = waveHeight
        self.visibility = 1.0
        self.precipitation = 0.0
        self.stormIntensity = 0.0
    }
}

/// Ocean current data for physics
public struct OceanCurrentData {
    public var velocity: SIMD2<Float>
    public var temperature: Float
    public var depth: Float
    public var strength: Float
    
    public init(velocity: SIMD2<Float> = .zero, temperature: Float = 20.0) {
        self.velocity = velocity
        self.temperature = temperature
        self.depth = 100.0
        self.strength = 0.5
    }
}

/// Ship physics data for Metal compute
public struct ShipPhysicsData {
    public var position: SIMD3<Float>
    public var velocity: SIMD3<Float>
    public var mass: Float
    public var drag: Float
    public var enginePower: Float
    public var rudderAngle: Float
    public var draft: Float
    public var beamWidth: Float
    
    public init(position: SIMD3<Float> = .zero, mass: Float = 50000.0) {
        self.position = position
        self.velocity = .zero
        self.mass = mass
        self.drag = 0.1
        self.enginePower = 10000.0
        self.rudderAngle = 0.0
        self.draft = 10.0
        self.beamWidth = 30.0
    }
}

/// Route risk factors
public struct RouteRisk: Codable, Identifiable {
    public let id = UUID()
    public var riskType: RiskType
    public var probability: Double
    public var impact: Double
    public var mitigationCost: Double
    public var location: SIMD3<Float>?
    
    public enum RiskType: String, Codable {
        case piracy = "Piracy"
        case weather = "Severe Weather"
        case political = "Political Instability"
        case mechanical = "Mechanical Failure"
        case market = "Market Volatility"
        case regulatory = "Regulatory Changes"
        case environmental = "Environmental Hazards"
    }
    
    public init(riskType: RiskType, probability: Double, impact: Double) {
        self.riskType = riskType
        self.probability = probability
        self.impact = impact
        self.mitigationCost = impact * probability * 0.3
    }
}

/// Geographic regions for location clustering
public enum GeographicRegion: String, Codable, CaseIterable {
    case northAmerica = "North America"
    case southAmerica = "South America"
    case europe = "Europe"
    case africa = "Africa"
    case asia = "Asia"
    case oceania = "Oceania"
    case arctic = "Arctic"
    case antarctic = "Antarctic"
    case caribbean = "Caribbean"
    case mediterranean = "Mediterranean"
    case middleEast = "Middle East"
    case southeastAsia = "Southeast Asia"
}

// MARK: - Helper Functions

private func normalize(_ vector: SIMD2<Float>) -> SIMD2<Float> {
    let length = sqrt(vector.x * vector.x + vector.y * vector.y)
    return length > 0 ? vector / length : vector
}