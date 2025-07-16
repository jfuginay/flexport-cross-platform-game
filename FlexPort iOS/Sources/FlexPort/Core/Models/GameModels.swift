import Foundation
import simd

// MARK: - Enhanced Game Models

/// Game Screen enumeration
public enum GameScreen {
    case mainMenu
    case game
    case settings
    case saveLoad
    case statistics
}

/// Enhanced Ship model with detailed properties
public struct Ship: Identifiable, Codable, Hashable {
    public let id = UUID()
    public var name: String
    public var capacity: Int
    public var speed: Double
    public var efficiency: Double
    public var maintenanceCost: Double
    public var price: Double
    public var age: Double = 0
    public var condition: Double = 1.0
    public var fuelCapacity: Double = 1000.0
    public var currentFuel: Double = 1000.0
    public var shipClass: ShipClass
    public var specializations: Set<ShipSpecialization> = []
    public var currentRoute: UUID?
    public var currentPort: UUID?
    public var cargoManifest: [CargoItem] = []
    public var crew: ShipCrew
    public var insuranceValue: Double
    public var nextMaintenanceDate: Date
    
    public init(name: String, capacity: Int, speed: Double, efficiency: Double, 
                maintenanceCost: Double, price: Double, shipClass: ShipClass = .generalCargo) {
        self.name = name
        self.capacity = capacity
        self.speed = speed
        self.efficiency = efficiency
        self.maintenanceCost = maintenanceCost
        self.price = price
        self.shipClass = shipClass
        self.crew = ShipCrew(size: shipClass.requiredCrew)
        self.insuranceValue = price * 0.8
        self.nextMaintenanceDate = Date().addingTimeInterval(TimeInterval.random(in: 86400*30...86400*90))
    }
    
    public var totalCapacityUsed: Int {
        cargoManifest.reduce(0) { $0 + $1.quantity }
    }
    
    public var availableCapacity: Int {
        capacity - totalCapacityUsed
    }
    
    public var isFullyLoaded: Bool {
        totalCapacityUsed >= capacity
    }
    
    public var needsMaintenance: Bool {
        Date() >= nextMaintenanceDate || condition < 0.7
    }
}

public enum ShipClass: String, Codable, CaseIterable {
    case bulkCarrier = "Bulk Carrier"
    case containerShip = "Container Ship"
    case tanker = "Tanker"
    case generalCargo = "General Cargo"
    case roro = "Roll-on/Roll-off"
    case refrigeratedCargo = "Refrigerated Cargo"
    case heavyLift = "Heavy Lift"
    
    public var requiredCrew: Int {
        switch self {
        case .bulkCarrier: return 25
        case .containerShip: return 22
        case .tanker: return 30
        case .generalCargo: return 20
        case .roro: return 18
        case .refrigeratedCargo: return 24
        case .heavyLift: return 35
        }
    }
    
    public var baseEfficiency: Double {
        switch self {
        case .bulkCarrier: return 0.85
        case .containerShip: return 0.95
        case .tanker: return 0.80
        case .generalCargo: return 0.75
        case .roro: return 0.70
        case .refrigeratedCargo: return 0.88
        case .heavyLift: return 0.65
        }
    }
}

public enum ShipSpecialization: String, Codable, CaseIterable {
    case hazardousMaterials = "Hazardous Materials"
    case perishableGoods = "Perishable Goods"
    case oversizedCargo = "Oversized Cargo"
    case liquidCargo = "Liquid Cargo"
    case automobiles = "Automobiles"
    case livestockTransport = "Livestock Transport"
    case breakBulk = "Break Bulk"
}

public struct ShipCrew: Codable {
    public var size: Int
    public var skill: Double = 0.5
    public var morale: Double = 0.8
    public var experience: Double = 0.0
    public var wageMultiplier: Double = 1.0
    
    public init(size: Int) {
        self.size = size
    }
}

public struct CargoItem: Identifiable, Codable {
    public let id = UUID()
    public var commodityType: String
    public var quantity: Int
    public var weight: Double
    public var value: Double
    public var origin: String
    public var destination: String
    public var loadDate: Date
    public var expectedDeliveryDate: Date
    public var specialHandling: Set<HandlingRequirement> = []
    public var insuranceValue: Double
    public var owner: String // Client company name
    
    public init(commodityType: String, quantity: Int, weight: Double, value: Double,
                origin: String, destination: String, expectedDeliveryDate: Date, owner: String) {
        self.commodityType = commodityType
        self.quantity = quantity
        self.weight = weight
        self.value = value
        self.origin = origin
        self.destination = destination
        self.loadDate = Date()
        self.expectedDeliveryDate = expectedDeliveryDate
        self.insuranceValue = value * 0.9
        self.owner = owner
    }
}

public enum HandlingRequirement: String, Codable, CaseIterable {
    case temperatureControlled = "Temperature Controlled"
    case fragile = "Fragile"
    case hazardous = "Hazardous"
    case oversized = "Oversized"
    case highValue = "High Value"
    case quickDelivery = "Quick Delivery"
}

/// Enhanced Warehouse model
public struct Warehouse: Identifiable, Codable, Hashable {
    public let id = UUID()
    public var location: Location
    public var capacity: Int
    public var storageCost: Double
    public var price: Double
    public var utilization: Double = 0.0
    public var warehouseType: WarehouseType
    public var facilities: Set<WarehouseFacility> = []
    public var securityLevel: SecurityLevel = .standard
    public var automationLevel: Double = 0.0
    public var staff: WarehouseStaff
    public var inventory: [StoredItem] = []
    public var monthlyRevenue: Double = 0.0
    public var operatingCosts: Double = 0.0
    
    public init(location: Location, capacity: Int, storageCost: Double, price: Double,
                warehouseType: WarehouseType = .general) {
        self.location = location
        self.capacity = capacity
        self.storageCost = storageCost
        self.price = price
        self.warehouseType = warehouseType
        self.staff = WarehouseStaff(size: max(5, capacity / 1000))
    }
    
    public var availableCapacity: Int {
        let usedCapacity = inventory.reduce(0) { $0 + $1.quantity }
        return capacity - usedCapacity
    }
    
    public var occupancyRate: Double {
        let usedCapacity = inventory.reduce(0) { $0 + $1.quantity }
        return Double(usedCapacity) / Double(capacity)
    }
}

public enum WarehouseType: String, Codable, CaseIterable {
    case general = "General Storage"
    case refrigerated = "Refrigerated"
    case hazmat = "Hazardous Materials"
    case automotive = "Automotive"
    case bulk = "Bulk Storage"
    case container = "Container Storage"
    case highValue = "High Value Goods"
}

public enum WarehouseFacility: String, Codable, CaseIterable {
    case loadingDocks = "Loading Docks"
    case railAccess = "Rail Access"
    case cranes = "Cranes"
    case refrigeration = "Refrigeration"
    case security = "Security Systems"
    case automation = "Automation Systems"
    case qualityControl = "Quality Control"
    case customsClearance = "Customs Clearance"
}

public enum SecurityLevel: String, Codable, CaseIterable {
    case basic = "Basic"
    case standard = "Standard"
    case enhanced = "Enhanced"
    case maximum = "Maximum"
    
    public var costMultiplier: Double {
        switch self {
        case .basic: return 1.0
        case .standard: return 1.2
        case .enhanced: return 1.5
        case .maximum: return 2.0
        }
    }
}

public struct WarehouseStaff: Codable {
    public var size: Int
    public var skill: Double = 0.5
    public var productivity: Double = 1.0
    public var wageRate: Double = 25.0 // per hour
    
    public init(size: Int) {
        self.size = size
    }
}

public struct StoredItem: Identifiable, Codable {
    public let id = UUID()
    public var commodityType: String
    public var quantity: Int
    public var owner: String
    public var storageDate: Date
    public var storageRate: Double
    public var specialRequirements: Set<StorageRequirement> = []
    
    public init(commodityType: String, quantity: Int, owner: String, storageRate: Double) {
        self.commodityType = commodityType
        self.quantity = quantity
        self.owner = owner
        self.storageDate = Date()
        self.storageRate = storageRate
    }
}

public enum StorageRequirement: String, Codable, CaseIterable {
    case climateControlled = "Climate Controlled"
    case ventilation = "Ventilation"
    case fireProtection = "Fire Protection"
    case pestControl = "Pest Control"
    case segregation = "Segregation Required"
}

/// Enhanced Location model
public struct Location: Codable, Hashable {
    public var name: String
    public var coordinates: Coordinates
    public var portType: PortType
    public var region: GeographicRegion?
    public var timeZone: String
    public var weatherPattern: WeatherPattern
    public var economicIndicators: EconomicIndicators
    public var infrastructure: InfrastructureRating
    public var regulations: RegulatoryEnvironment
    
    public init(name: String, coordinates: Coordinates, portType: PortType) {
        self.name = name
        self.coordinates = coordinates
        self.portType = portType
        self.timeZone = "UTC"
        self.weatherPattern = WeatherPattern()
        self.economicIndicators = EconomicIndicators()
        self.infrastructure = InfrastructureRating()
        self.regulations = RegulatoryEnvironment()
    }
}

public struct WeatherPattern: Codable, Hashable {
    public var averageTemperature: Double = 20.0
    public var seasonalVariation: Double = 10.0
    public var precipitationLevel: Double = 0.5
    public var stormFrequency: Double = 0.1
    public var windStrength: Double = 0.3
    
    public init() {}
}

public struct EconomicIndicators: Codable, Hashable {
    public var gdpPerCapita: Double = 25000
    public var unemploymentRate: Double = 0.05
    public var inflationRate: Double = 0.02
    public var tradeVolume: Double = 1.0
    public var developmentIndex: Double = 0.7
    
    public init() {}
}

public struct InfrastructureRating: Codable, Hashable {
    public var portFacilities: Double = 0.7
    public var roadNetwork: Double = 0.7
    public var railNetwork: Double = 0.6
    public var digitalInfrastructure: Double = 0.8
    public var utilities: Double = 0.8
    
    public init() {}
    
    public var overallRating: Double {
        (portFacilities + roadNetwork + railNetwork + digitalInfrastructure + utilities) / 5.0
    }
}

public struct RegulatoryEnvironment: Codable, Hashable {
    public var customsEfficiency: Double = 0.7
    public var bureaucracyLevel: Double = 0.5
    public var corruptionIndex: Double = 0.3
    public var tradeBarriers: Double = 0.2
    public var laborRegulations: Double = 0.6
    
    public init() {}
}

/// Port model
public struct Port: Identifiable, Codable {
    public let id = UUID()
    public var name: String
    public var location: Location
    public var facilities: Set<PortFacility> = []
    public var capacity: PortCapacity
    public var fees: PortFees
    public var operatingHours: OperatingSchedule
    public var services: Set<PortService> = []
    public var performance: PortPerformance
    public var connections: Set<TransportConnection> = []
    
    public init(name: String, location: Location) {
        self.name = name
        self.location = location
        self.capacity = PortCapacity()
        self.fees = PortFees()
        self.operatingHours = OperatingSchedule()
        self.performance = PortPerformance()
    }
}

public enum PortFacility: String, Codable, CaseIterable {
    case containerTerminal = "Container Terminal"
    case bulkTerminal = "Bulk Terminal"
    case liquidBulkTerminal = "Liquid Bulk Terminal"
    case roroTerminal = "RoRo Terminal"
    case cruiseTerminal = "Cruise Terminal"
    case drydock = "Dry Dock"
    case pilotage = "Pilotage"
    case tugboats = "Tugboats"
    case bunkerFueling = "Bunker Fueling"
    case wasteDisposal = "Waste Disposal"
}

public struct PortCapacity: Codable {
    public var maxBerths: Int = 10
    public var maxTEU: Int = 100000 // Twenty-foot Equivalent Units
    public var maxBulkTonnage: Int = 500000
    public var maxVesselLength: Double = 400.0 // meters
    public var maxVesselDraft: Double = 15.0 // meters
    
    public init() {}
}

public struct PortFees: Codable {
    public var berthingFee: Double = 100.0 // per day
    public var cargoHandlingFee: Double = 50.0 // per TEU or ton
    public var pilotage: Double = 500.0
    public var tugboatService: Double = 300.0
    public var stevedoring: Double = 25.0 // per hour
    
    public init() {}
}

public struct OperatingSchedule: Codable {
    public var hoursPerDay: Int = 24
    public var daysPerWeek: Int = 7
    public var holidayClosures: [String] = []
    public var nightShiftCapacity: Double = 0.8
    
    public init() {}
}

public enum PortService: String, Codable, CaseIterable {
    case customsClearance = "Customs Clearance"
    case cargoInspection = "Cargo Inspection"
    case shipRepair = "Ship Repair"
    case provisioning = "Provisioning"
    case crewChange = "Crew Change"
    case medicalServices = "Medical Services"
    case banking = "Banking Services"
    case telecommunications = "Telecommunications"
}

public struct PortPerformance: Codable {
    public var averageTurnaroundTime: Double = 24.0 // hours
    public var berthUtilization: Double = 0.75
    public var cargoThroughput: Double = 0.0 // TEU or tons per year
    public var onTimePerformance: Double = 0.85
    public var customerSatisfaction: Double = 0.8
    
    public init() {}
}

public enum TransportConnection: String, Codable, CaseIterable {
    case highway = "Highway"
    case railway = "Railway"
    case airport = "Airport"
    case inlandWaterway = "Inland Waterway"
    case pipeline = "Pipeline"
}

/// Trade Route model
public struct TradeRoute: Identifiable, Codable {
    public let id = UUID()
    public var name: String
    public var origin: Port
    public var destination: Port
    public var intermediateStops: [Port] = []
    public var distance: Double
    public var estimatedTransitTime: TimeInterval
    public var commodity: String
    public var frequency: RouteFrequency
    public var seasonality: SeasonalPattern
    public var profitability: RouteProfitability
    public var risks: [RouteRisk] = []
    public var competitionLevel: Double = 0.5
    public var marketDemand: Double = 1.0
    
    public init(name: String, origin: Port, destination: Port, distance: Double, commodity: String) {
        self.name = name
        self.origin = origin
        self.destination = destination
        self.distance = distance
        self.estimatedTransitTime = distance / 20.0 * 3600 // Assume 20 knots average speed
        self.commodity = commodity
        self.frequency = RouteFrequency.weekly
        self.seasonality = SeasonalPattern()
        self.profitability = RouteProfitability()
    }
}

public enum RouteFrequency: String, Codable, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case biweekly = "Bi-weekly"
    case monthly = "Monthly"
    case seasonal = "Seasonal"
    case onDemand = "On Demand"
    
    public var daysInterval: Int {
        switch self {
        case .daily: return 1
        case .weekly: return 7
        case .biweekly: return 14
        case .monthly: return 30
        case .seasonal: return 90
        case .onDemand: return 0
        }
    }
}

public struct SeasonalPattern: Codable {
    public var peakSeason: (start: Int, end: Int) = (6, 8) // June to August
    public var lowSeason: (start: Int, end: Int) = (12, 2) // December to February
    public var seasonalVariation: Double = 0.3 // 30% variation
    
    public init() {}
}

public struct RouteProfitability: Codable {
    public var averageRevenue: Double = 0.0
    public var operatingCosts: Double = 0.0
    public var fuelCosts: Double = 0.0
    public var portFees: Double = 0.0
    public var crewCosts: Double = 0.0
    public var insuranceCosts: Double = 0.0
    
    public init() {}
    
    public var netProfit: Double {
        averageRevenue - (operatingCosts + fuelCosts + portFees + crewCosts + insuranceCosts)
    }
    
    public var profitMargin: Double {
        guard averageRevenue > 0 else { return 0 }
        return netProfit / averageRevenue
    }
}

/// Enhanced Coordinates
public struct Coordinates: Codable, Hashable {
    public var latitude: Double
    public var longitude: Double
    public var elevation: Double = 0.0
    
    public init(latitude: Double, longitude: Double, elevation: Double = 0.0) {
        self.latitude = latitude
        self.longitude = longitude
        self.elevation = elevation
    }
    
    /// Calculate distance to another coordinate using Haversine formula
    public func distance(to other: Coordinates) -> Double {
        let earthRadius = 6371.0 // kilometers
        
        let lat1Rad = latitude * .pi / 180
        let lat2Rad = other.latitude * .pi / 180
        let deltaLat = (other.latitude - latitude) * .pi / 180
        let deltaLon = (other.longitude - longitude) * .pi / 180
        
        let a = sin(deltaLat/2) * sin(deltaLat/2) +
                cos(lat1Rad) * cos(lat2Rad) *
                sin(deltaLon/2) * sin(deltaLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        
        return earthRadius * c
    }
}

/// Enhanced PortType
public enum PortType: String, Codable, CaseIterable {
    case sea = "Seaport"
    case air = "Airport"
    case rail = "Rail Terminal"
    case multimodal = "Multimodal Hub"
    case inland = "Inland Port"
    case dry = "Dry Port"
    case fishing = "Fishing Port"
    case military = "Military Port"
    case cruise = "Cruise Port"
    case industrial = "Industrial Port"
    
    public var capabilities: Set<TransportMode> {
        switch self {
        case .sea: return [.maritime]
        case .air: return [.air]
        case .rail: return [.rail]
        case .multimodal: return [.maritime, .rail, .road]
        case .inland: return [.rail, .road, .barge]
        case .dry: return [.rail, .road]
        case .fishing: return [.maritime]
        case .military: return [.maritime, .air]
        case .cruise: return [.maritime]
        case .industrial: return [.maritime, .rail, .road, .pipeline]
        }
    }
}

public enum TransportMode: String, Codable, CaseIterable {
    case maritime = "Maritime"
    case air = "Air"
    case rail = "Rail"
    case road = "Road"
    case barge = "Barge"
    case pipeline = "Pipeline"
}

/// Game Statistics
public struct GameStatistics: Codable {
    public var totalRevenue: Double = 0.0
    public var totalExpenses: Double = 0.0
    public var shipmentsCompleted: Int = 0
    public var shipmentsInProgress: Int = 0
    public var averageDeliveryTime: Double = 0.0
    public var customerSatisfactionRating: Double = 0.8
    public var marketShare: Double = 0.0
    public var sustainabilityScore: Double = 0.5
    public var reputationScore: Double = 50.0
    public var gameStartDate: Date = Date()
    public var totalPlayTime: TimeInterval = 0.0
    
    public init() {}
    
    public var netProfit: Double {
        totalRevenue - totalExpenses
    }
    
    public var profitMargin: Double {
        guard totalRevenue > 0 else { return 0 }
        return netProfit / totalRevenue
    }
    
    public var onTimeDeliveryRate: Double {
        // This would be calculated based on actual delivery performance
        return 0.85 // Placeholder
    }
}