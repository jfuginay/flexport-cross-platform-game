import Foundation
import simd

// MARK: - Economic Event Components

/// Component for economic events that affect market conditions
public struct EconomicEventComponent: Component {
    public static let componentType = ComponentType.economicEvent
    
    public var eventId: UUID
    public var name: String
    public var description: String
    public var eventType: EconomicEventType
    public var severity: EventSeverity
    public var duration: TimeInterval
    public var remainingDuration: TimeInterval
    public var priceMultiplier: Double
    public var affectedCommodities: Set<String>
    public var affectedRegions: Set<GeographicRegion>
    public var sourceEntity: Entity?
    public var isActive: Bool
    public var startTime: Date
    public var triggerHapticFeedback: Bool
    
    public enum EconomicEventType: String, Codable, CaseIterable {
        case portStrike = "Port Strike"
        case hurricaneWarning = "Hurricane Warning"
        case oilPriceSurge = "Oil Price Surge"
        case tradeWar = "Trade War"
        case pandemic = "Global Pandemic"
        case cyberAttack = "Cyber Attack"
        case earthquake = "Earthquake"
        case tsunami = "Tsunami Warning"
        case piracy = "Piracy Activity"
        case sanctions = "Economic Sanctions"
        case recession = "Economic Recession"
        case boom = "Economic Boom"
        case techBreakthrough = "Technology Breakthrough"
        case environmentalDisaster = "Environmental Disaster"
        case regulatoryChange = "Regulatory Changes"
    }
    
    public enum EventSeverity: String, Codable {
        case minor = "Minor"
        case moderate = "Moderate"
        case major = "Major"
        case catastrophic = "Catastrophic"
        
        public var impactMultiplier: Double {
            switch self {
            case .minor: return 0.1
            case .moderate: return 0.3
            case .major: return 0.6
            case .catastrophic: return 1.0
            }
        }
        
        public var hapticIntensity: Float {
            switch self {
            case .minor: return 0.3
            case .moderate: return 0.5
            case .major: return 0.8
            case .catastrophic: return 1.0
            }
        }
    }
    
    public init(
        eventType: EconomicEventType,
        severity: EventSeverity,
        duration: TimeInterval,
        affectedCommodities: Set<String> = [],
        affectedRegions: Set<GeographicRegion> = []
    ) {
        self.eventId = UUID()
        self.name = eventType.rawValue
        self.description = EconomicEventComponent.generateDescription(for: eventType, severity: severity)
        self.eventType = eventType
        self.severity = severity
        self.duration = duration
        self.remainingDuration = duration
        self.priceMultiplier = EconomicEventComponent.calculatePriceMultiplier(for: eventType, severity: severity)
        self.affectedCommodities = affectedCommodities.isEmpty ? EconomicEventComponent.getDefaultCommodities(for: eventType) : affectedCommodities
        self.affectedRegions = affectedRegions
        self.sourceEntity = nil
        self.isActive = true
        self.startTime = Date()
        self.triggerHapticFeedback = EconomicEventComponent.shouldTriggerHaptic(for: eventType)
    }
    
    private static func generateDescription(for eventType: EconomicEventType, severity: EventSeverity) -> String {
        switch eventType {
        case .portStrike:
            return "\(severity.rawValue) work stoppage affecting port operations and cargo handling"
        case .hurricaneWarning:
            return "\(severity.rawValue) hurricane system threatening shipping lanes and coastal ports"
        case .oilPriceSurge:
            return "\(severity.rawValue) increase in fuel costs affecting shipping operations"
        case .tradeWar:
            return "\(severity.rawValue) trade dispute creating tariffs and shipping restrictions"
        case .pandemic:
            return "\(severity.rawValue) global health crisis disrupting supply chains"
        case .cyberAttack:
            return "\(severity.rawValue) digital attack on port systems and logistics networks"
        case .earthquake:
            return "\(severity.rawValue) seismic activity threatening port infrastructure"
        case .tsunami:
            return "\(severity.rawValue) tsunami warning for coastal shipping areas"
        case .piracy:
            return "\(severity.rawValue) piracy activity in shipping corridors"
        case .sanctions:
            return "\(severity.rawValue) economic sanctions affecting international trade"
        case .recession:
            return "\(severity.rawValue) economic downturn reducing shipping demand"
        case .boom:
            return "\(severity.rawValue) economic growth increasing shipping demand"
        case .techBreakthrough:
            return "\(severity.rawValue) technological advancement affecting logistics efficiency"
        case .environmentalDisaster:
            return "\(severity.rawValue) environmental catastrophe disrupting trade routes"
        case .regulatoryChange:
            return "\(severity.rawValue) new regulations affecting shipping operations"
        }
    }
    
    private static func calculatePriceMultiplier(for eventType: EconomicEventType, severity: EventSeverity) -> Double {
        let baseMultiplier: Double
        
        switch eventType {
        case .portStrike, .hurricaneWarning, .earthquake, .tsunami, .cyberAttack:
            baseMultiplier = 1.5 // Supply disruption increases prices
        case .oilPriceSurge:
            baseMultiplier = 1.8 // Direct fuel cost impact
        case .tradeWar, .sanctions:
            baseMultiplier = 1.3 // Trade friction
        case .pandemic, .environmentalDisaster:
            baseMultiplier = 1.6 // Major disruption
        case .piracy:
            baseMultiplier = 1.2 // Regional risk premium
        case .recession:
            baseMultiplier = 0.8 // Reduced demand
        case .boom, .techBreakthrough:
            baseMultiplier = 0.9 // Increased efficiency or demand
        case .regulatoryChange:
            baseMultiplier = 1.1 // Compliance costs
        }
        
        return 1.0 + (baseMultiplier - 1.0) * severity.impactMultiplier
    }
    
    private static func getDefaultCommodities(for eventType: EconomicEventType) -> Set<String> {
        switch eventType {
        case .portStrike, .hurricaneWarning, .earthquake, .tsunami, .cyberAttack:
            return ["Container", "Oil", "Electronics", "Automobiles"] // All major goods
        case .oilPriceSurge:
            return ["Oil", "LNG", "Chemicals"] // Energy-related
        case .tradeWar, .sanctions:
            return ["Electronics", "Steel", "Automobiles", "Machinery"] // Manufactured goods
        case .pandemic:
            return ["Container", "Electronics", "Grain", "Machinery"] // Essential and tech goods
        case .piracy:
            return ["Oil", "Container", "Electronics"] // High-value cargo
        case .recession:
            return ["Automobiles", "Electronics", "Machinery"] // Luxury/durable goods
        case .boom:
            return ["Steel", "Machinery", "Electronics", "Container"] // Industrial growth
        case .techBreakthrough:
            return ["Electronics", "Machinery"] // Tech-related
        case .environmentalDisaster:
            return ["Grain", "Oil", "Chemicals"] // Agricultural and industrial
        case .regulatoryChange:
            return ["Oil", "Chemicals", "LNG"] // Regulated industries
        }
    }
    
    private static func shouldTriggerHaptic(for eventType: EconomicEventType) -> Bool {
        switch eventType {
        case .hurricaneWarning, .earthquake, .tsunami, .cyberAttack, .piracy, .environmentalDisaster:
            return true // Physical or immediate threats
        case .portStrike, .oilPriceSurge, .tradeWar, .pandemic, .sanctions:
            return true // Major economic impacts
        default:
            return false // Gradual economic changes
        }
    }
}

/// Component for tracking disaster effects on routes and ships
public struct DisasterEffectComponent: Component {
    public static let componentType = ComponentType.disasterEffect
    
    public var disasterId: UUID
    public var affectedEntity: Entity
    public var disasterType: DisasterType
    public var intensityLevel: Float // 0.0 to 1.0
    public var position: SIMD3<Float>
    public var radius: Float
    public var speedMultiplier: Float
    public var fuelConsumptionMultiplier: Float
    public var damageRate: Float // Per second
    public var visualEffectIntensity: Float
    public var audioEffectType: AudioEffectType
    public var hapticPattern: HapticPattern
    public var duration: TimeInterval
    public var remainingDuration: TimeInterval
    
    public enum DisasterType: String, Codable {
        case hurricane
        case tsunami
        case earthquake
        case storm
        case fog
        case piracy
        case cyberAttack
        case fire
        case flooding
    }
    
    public enum AudioEffectType: String, Codable {
        case hurricane
        case earthquakeRumble
        case tsunamiWave
        case stormWind
        case emergencyAlarm
        case cyberStatic
        case fireAlarm
        case none
    }
    
    public enum HapticPattern: String, Codable {
        case earthquake // Rumbling pattern
        case hurricane // Circular wind pattern
        case tsunami // Wave pattern
        case storm // Irregular gusts
        case cyberAttack // Sharp pulses
        case collision // Single strong impact
        case warning // Rhythmic alerts
        case none
    }
    
    public init(
        disasterType: DisasterType,
        position: SIMD3<Float>,
        radius: Float,
        intensityLevel: Float,
        duration: TimeInterval
    ) {
        self.disasterId = UUID()
        self.affectedEntity = Entity() // Will be set when applied
        self.disasterType = disasterType
        self.intensityLevel = max(0.0, min(1.0, intensityLevel))
        self.position = position
        self.radius = radius
        self.speedMultiplier = DisasterEffectComponent.calculateSpeedMultiplier(for: disasterType, intensity: intensityLevel)
        self.fuelConsumptionMultiplier = DisasterEffectComponent.calculateFuelMultiplier(for: disasterType, intensity: intensityLevel)
        self.damageRate = DisasterEffectComponent.calculateDamageRate(for: disasterType, intensity: intensityLevel)
        self.visualEffectIntensity = intensityLevel
        self.audioEffectType = DisasterEffectComponent.getAudioEffect(for: disasterType)
        self.hapticPattern = DisasterEffectComponent.getHapticPattern(for: disasterType)
        self.duration = duration
        self.remainingDuration = duration
    }
    
    private static func calculateSpeedMultiplier(for disasterType: DisasterType, intensity: Float) -> Float {
        let baseEffect: Float
        
        switch disasterType {
        case .hurricane, .storm:
            baseEffect = 0.3 // Strong headwinds
        case .tsunami:
            baseEffect = 0.1 // Massive water displacement
        case .earthquake:
            baseEffect = 0.8 // Minimal direct speed impact
        case .fog:
            baseEffect = 0.5 // Reduced visibility forces slower speeds
        case .piracy:
            baseEffect = 0.2 // Forced to stop or reroute
        case .cyberAttack:
            baseEffect = 0.7 // Navigation systems affected
        case .fire:
            baseEffect = 0.4 // Emergency protocols
        case .flooding:
            baseEffect = 0.6 // Waterlogged areas
        }
        
        return 1.0 - (1.0 - baseEffect) * intensity
    }
    
    private static func calculateFuelMultiplier(for disasterType: DisasterType, intensity: Float) -> Float {
        let baseIncrease: Float
        
        switch disasterType {
        case .hurricane, .storm:
            baseIncrease = 0.8 // Fighting winds
        case .tsunami:
            baseIncrease = 1.2 // Emergency power needed
        case .earthquake:
            baseIncrease = 0.1 // Minimal impact
        case .fog:
            baseIncrease = 0.3 // Slower speeds, longer routes
        case .piracy:
            baseIncrease = 0.5 // Evasive maneuvers
        case .cyberAttack:
            baseIncrease = 0.2 // Manual operation less efficient
        case .fire:
            baseIncrease = 0.4 // Emergency systems
        case .flooding:
            baseIncrease = 0.4 // Difficult navigation
        }
        
        return 1.0 + baseIncrease * intensity
    }
    
    private static func calculateDamageRate(for disasterType: DisasterType, intensity: Float) -> Float {
        let baseDamage: Float
        
        switch disasterType {
        case .hurricane, .storm:
            baseDamage = 0.05 // Structural stress
        case .tsunami:
            baseDamage = 0.15 // Massive water force
        case .earthquake:
            baseDamage = 0.08 // Shaking damage
        case .fog:
            baseDamage = 0.01 // Minor collision risk
        case .piracy:
            baseDamage = 0.12 // Direct attacks
        case .cyberAttack:
            baseDamage = 0.02 // System damage
        case .fire:
            baseDamage = 0.20 // Direct fire damage
        case .flooding:
            baseDamage = 0.06 // Water damage
        }
        
        return baseDamage * intensity
    }
    
    private static func getAudioEffect(for disasterType: DisasterType) -> AudioEffectType {
        switch disasterType {
        case .hurricane, .storm: return .hurricane
        case .tsunami: return .tsunamiWave
        case .earthquake: return .earthquakeRumble
        case .fog: return .none
        case .piracy: return .emergencyAlarm
        case .cyberAttack: return .cyberStatic
        case .fire: return .fireAlarm
        case .flooding: return .stormWind
        }
    }
    
    private static func getHapticPattern(for disasterType: DisasterType) -> HapticPattern {
        switch disasterType {
        case .hurricane, .storm: return .hurricane
        case .tsunami: return .tsunami
        case .earthquake: return .earthquake
        case .fog: return .none
        case .piracy: return .warning
        case .cyberAttack: return .cyberAttack
        case .fire: return .warning
        case .flooding: return .storm
        }
    }
}

/// Component for asset management integration
public struct AssetManagementComponent: Component {
    public static let componentType = ComponentType.assetManagement
    
    public var assetId: UUID
    public var assetType: AssetType
    public var condition: Float // 0.0 to 1.0
    public var value: Double
    public var purchasePrice: Double
    public var purchaseDate: Date
    public var maintenanceCost: Double
    public var insurancePremium: Double
    public var insuranceProvider: String?
    public var lastMaintenanceDate: Date?
    public var scheduledMaintenanceDate: Date?
    public var crewCount: Int
    public var crewEfficiency: Float
    public var crewMorale: Float
    public var operationalStatus: OperationalStatus
    public var revenueHistory: [RevenueRecord]
    public var costHistory: [CostRecord]
    
    public enum AssetType: String, Codable {
        case containerShip = "Container Ship"
        case tankerShip = "Tanker Ship"
        case bulkCarrier = "Bulk Carrier"
        case cargoShip = "Cargo Ship"
        case port = "Port"
        case warehouse = "Warehouse"
        case crane = "Crane"
        case truck = "Truck"
    }
    
    public enum OperationalStatus: String, Codable {
        case active = "Active"
        case maintenance = "Under Maintenance"
        case damaged = "Damaged"
        case idle = "Idle"
        case emergency = "Emergency"
        case decommissioned = "Decommissioned"
    }
    
    public struct RevenueRecord: Codable {
        public let date: Date
        public let amount: Double
        public let source: String
        public let tradeRoute: UUID?
        
        public init(amount: Double, source: String, tradeRoute: UUID? = nil) {
            self.date = Date()
            self.amount = amount
            self.source = source
            self.tradeRoute = tradeRoute
        }
    }
    
    public struct CostRecord: Codable {
        public let date: Date
        public let amount: Double
        public let category: CostCategory
        public let description: String
        
        public enum CostCategory: String, Codable {
            case fuel = "Fuel"
            case maintenance = "Maintenance"
            case crew = "Crew"
            case insurance = "Insurance"
            case docking = "Docking Fees"
            case repairs = "Repairs"
            case upgrades = "Upgrades"
            case emergency = "Emergency"
        }
        
        public init(amount: Double, category: CostCategory, description: String) {
            self.date = Date()
            self.amount = amount
            self.category = category
            self.description = description
        }
    }
    
    public init(assetType: AssetType, value: Double) {
        self.assetId = UUID()
        self.assetType = assetType
        self.condition = 1.0
        self.value = value
        self.purchasePrice = value
        self.purchaseDate = Date()
        self.maintenanceCost = value * 0.05 // 5% of value annually
        self.insurancePremium = value * 0.02 // 2% of value annually
        self.insuranceProvider = nil
        self.lastMaintenanceDate = nil
        self.scheduledMaintenanceDate = Calendar.current.date(byAdding: .month, value: 6, to: Date())
        self.crewCount = AssetManagementComponent.getDefaultCrewCount(for: assetType)
        self.crewEfficiency = 0.8
        self.crewMorale = 0.7
        self.operationalStatus = .active
        self.revenueHistory = []
        self.costHistory = []
    }
    
    private static func getDefaultCrewCount(for assetType: AssetType) -> Int {
        switch assetType {
        case .containerShip: return 25
        case .tankerShip: return 30
        case .bulkCarrier: return 22
        case .cargoShip: return 20
        case .port: return 200
        case .warehouse: return 15
        case .crane: return 2
        case .truck: return 1
        }
    }
    
    public mutating func addRevenue(_ amount: Double, source: String, tradeRoute: UUID? = nil) {
        revenueHistory.append(RevenueRecord(amount: amount, source: source, tradeRoute: tradeRoute))
        
        // Keep only last 100 records
        if revenueHistory.count > 100 {
            revenueHistory.removeFirst()
        }
    }
    
    public mutating func addCost(_ amount: Double, category: CostRecord.CostCategory, description: String) {
        costHistory.append(CostRecord(amount: amount, category: category, description: description))
        
        // Keep only last 100 records
        if costHistory.count > 100 {
            costHistory.removeFirst()
        }
    }
    
    public func getTotalRevenue(period: TimeInterval = 30 * 24 * 3600) -> Double {
        let cutoffDate = Date().addingTimeInterval(-period)
        return revenueHistory
            .filter { $0.date >= cutoffDate }
            .reduce(0) { $0 + $1.amount }
    }
    
    public func getTotalCosts(period: TimeInterval = 30 * 24 * 3600) -> Double {
        let cutoffDate = Date().addingTimeInterval(-period)
        return costHistory
            .filter { $0.date >= cutoffDate }
            .reduce(0) { $0 + $1.amount }
    }
    
    public func getProfitability(period: TimeInterval = 30 * 24 * 3600) -> Double {
        return getTotalRevenue(period: period) - getTotalCosts(period: period)
    }
}

// MARK: - Extended Component Types

extension ComponentType {
    public static let economicEvent = ComponentType(rawValue: "economicEvent")
    public static let disasterEffect = ComponentType(rawValue: "disasterEffect")
    public static let assetManagement = ComponentType(rawValue: "assetManagement")
}