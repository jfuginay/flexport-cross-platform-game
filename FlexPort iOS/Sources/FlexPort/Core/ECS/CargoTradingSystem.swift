import Foundation
import simd

// MARK: - Cargo Trading Components

/// Component for cargo holds and cargo management
public struct CargoComponent: Component {
    public static let componentType = ComponentType.cargo
    
    public var capacity: Int // Total cargo capacity in containers/units
    public var currentLoad: Int // Current cargo amount
    public var cargoTypes: [CargoType] // Types of cargo currently loaded
    public var cargoManifest: [CargoItem] // Detailed cargo manifest
    public var loadingProgress: Float // 0.0 to 1.0 for loading/unloading animation
    public var isLoading: Bool
    public var isUnloading: Bool
    public var temperatureControlled: Bool
    public var hazardousCargoLicense: Bool
    public var maxWeight: Float // Maximum weight capacity
    public var currentWeight: Float // Current weight
    
    public enum CargoType: String, Codable, CaseIterable {
        case container = "Container"
        case oil = "Oil"
        case grain = "Grain"
        case electronics = "Electronics"
        case automobiles = "Automobiles"
        case steel = "Steel"
        case coal = "Coal"
        case lng = "LNG"
        case chemicals = "Chemicals"
        case machinery = "Machinery"
        case timber = "Timber"
        case livestock = "Livestock"
        case perishables = "Perishables"
        case hazardous = "Hazardous Materials"
    }
    
    public struct CargoItem: Codable, Identifiable {
        public let id = UUID()
        public var cargoType: CargoType
        public var quantity: Int
        public var weight: Float
        public var value: Double
        public var origin: String
        public var destination: String
        public var loadDate: Date
        public var expiryDate: Date?
        public var specialRequirements: Set<SpecialRequirement>
        public var insuranceValue: Double
        public var contractId: UUID?
        
        public enum SpecialRequirement: String, Codable {
            case refrigerated = "Refrigerated"
            case hazardous = "Hazardous"
            case fragile = "Fragile"
            case oversize = "Oversize"
            case highValue = "High Value"
            case timeSpecific = "Time Specific"
            case securityEscort = "Security Escort"
        }
        
        public init(
            cargoType: CargoType,
            quantity: Int,
            weight: Float,
            value: Double,
            origin: String,
            destination: String,
            specialRequirements: Set<SpecialRequirement> = []
        ) {
            self.cargoType = cargoType
            self.quantity = quantity
            self.weight = weight
            self.value = value
            self.origin = origin
            self.destination = destination
            self.loadDate = Date()
            self.expiryDate = CargoItem.calculateExpiryDate(for: cargoType)
            self.specialRequirements = specialRequirements
            self.insuranceValue = value * 0.1 // 10% insurance
            self.contractId = nil
        }
        
        private static func calculateExpiryDate(for cargoType: CargoType) -> Date? {
            let daysToExpiry: Int?
            
            switch cargoType {
            case .perishables: daysToExpiry = 7
            case .livestock: daysToExpiry = 3
            case .grain: daysToExpiry = 30
            case .chemicals: daysToExpiry = 180
            default: daysToExpiry = nil
            }
            
            if let days = daysToExpiry {
                return Calendar.current.date(byAdding: .day, value: days, to: Date())
            }
            return nil
        }
    }
    
    public init(capacity: Int, temperatureControlled: Bool = false, hazardousLicense: Bool = false) {
        self.capacity = capacity
        self.currentLoad = 0
        self.cargoTypes = []
        self.cargoManifest = []
        self.loadingProgress = 0.0
        self.isLoading = false
        self.isUnloading = false
        self.temperatureControlled = temperatureControlled
        self.hazardousCargoLicense = hazardousLicense
        self.maxWeight = Float(capacity) * 20.0 // Assume 20 tons per container
        self.currentWeight = 0.0
    }
    
    public var utilizationPercentage: Float {
        guard capacity > 0 else { return 0 }
        return Float(currentLoad) / Float(capacity)
    }
    
    public var weightUtilizationPercentage: Float {
        guard maxWeight > 0 else { return 0 }
        return currentWeight / maxWeight
    }
    
    public mutating func addCargo(_ item: CargoItem) -> Bool {
        // Check capacity constraints
        guard currentLoad + item.quantity <= capacity else { return false }
        guard currentWeight + item.weight <= maxWeight else { return false }
        
        // Check special requirements
        if item.specialRequirements.contains(.refrigerated) && !temperatureControlled {
            return false
        }
        if item.specialRequirements.contains(.hazardous) && !hazardousCargoLicense {
            return false
        }
        
        // Add cargo
        cargoManifest.append(item)
        currentLoad += item.quantity
        currentWeight += item.weight
        
        if !cargoTypes.contains(item.cargoType) {
            cargoTypes.append(item.cargoType)
        }
        
        return true
    }
    
    public mutating func removeCargo(itemId: UUID) -> CargoItem? {
        guard let index = cargoManifest.firstIndex(where: { $0.id == itemId }) else {
            return nil
        }
        
        let item = cargoManifest.remove(at: index)
        currentLoad -= item.quantity
        currentWeight -= item.weight
        
        // Update cargo types
        updateCargoTypes()
        
        return item
    }
    
    private mutating func updateCargoTypes() {
        cargoTypes = Array(Set(cargoManifest.map { $0.cargoType }))
    }
}

/// Component for trade contracts and cargo trading
public struct TradingContractComponent: Component {
    public static let componentType = ComponentType.tradingContract
    
    public var contractId: UUID
    public var contractType: ContractType
    public var cargoType: CargoComponent.CargoType
    public var quantity: Int
    public var pricePerUnit: Double
    public var totalValue: Double
    public var originPort: String
    public var destinationPort: String
    public var deadline: Date
    public var priority: ContractPriority
    public var status: ContractStatus
    public var penalties: [Penalty]
    public var bonuses: [Bonus]
    public var requiredShipType: ShipComponent.ShipType?
    public var assignedShip: Entity?
    public var clientId: UUID
    public var clientName: String
    public var contractSignDate: Date
    public var estimatedProfit: Double
    public var riskAssessment: RiskAssessment
    
    public enum ContractType: String, Codable {
        case spot = "Spot Market"
        case charter = "Charter"
        case longTerm = "Long-term Contract"
        case emergency = "Emergency Delivery"
        case government = "Government Contract"
        case humanitarian = "Humanitarian Aid"
    }
    
    public enum ContractPriority: String, Codable {
        case low = "Low"
        case normal = "Normal"
        case high = "High"
        case urgent = "Urgent"
        case critical = "Critical"
    }
    
    public enum ContractStatus: String, Codable {
        case available = "Available"
        case negotiating = "Negotiating"
        case accepted = "Accepted"
        case inProgress = "In Progress"
        case completed = "Completed"
        case cancelled = "Cancelled"
        case failed = "Failed"
        case expired = "Expired"
    }
    
    public struct Penalty: Codable {
        public let type: PenaltyType
        public let amount: Double
        public let description: String
        
        public enum PenaltyType: String, Codable {
            case lateFee = "Late Delivery"
            case damageFee = "Cargo Damage"
            case cancellationFee = "Contract Cancellation"
            case qualityIssue = "Quality Issue"
        }
        
        public init(type: PenaltyType, amount: Double, description: String) {
            self.type = type
            self.amount = amount
            self.description = description
        }
    }
    
    public struct Bonus: Codable {
        public let type: BonusType
        public let amount: Double
        public let description: String
        public let condition: String
        
        public enum BonusType: String, Codable {
            case earlyDelivery = "Early Delivery"
            case perfectCondition = "Perfect Condition"
            case efficiency = "Fuel Efficiency"
            case volume = "Volume Bonus"
        }
        
        public init(type: BonusType, amount: Double, description: String, condition: String) {
            self.type = type
            self.amount = amount
            self.description = description
            self.condition = condition
        }
    }
    
    public struct RiskAssessment: Codable {
        public var weatherRisk: Float // 0.0 to 1.0
        public var piracyRisk: Float
        public var politicalRisk: Float
        public var marketRisk: Float
        public var overallRisk: Float
        public var riskFactors: [String]
        
        public init() {
            self.weatherRisk = 0.0
            self.piracyRisk = 0.0
            self.politicalRisk = 0.0
            self.marketRisk = 0.0
            self.overallRisk = 0.0
            self.riskFactors = []
        }
        
        public mutating func calculateOverallRisk() {
            overallRisk = (weatherRisk + piracyRisk + politicalRisk + marketRisk) / 4.0
        }
    }
    
    public init(
        cargoType: CargoComponent.CargoType,
        quantity: Int,
        pricePerUnit: Double,
        originPort: String,
        destinationPort: String,
        deadline: Date,
        priority: ContractPriority,
        clientName: String
    ) {
        self.contractId = UUID()
        self.contractType = .spot // Default to spot market
        self.cargoType = cargoType
        self.quantity = quantity
        self.pricePerUnit = pricePerUnit
        self.totalValue = Double(quantity) * pricePerUnit
        self.originPort = originPort
        self.destinationPort = destinationPort
        self.deadline = deadline
        self.priority = priority
        self.status = .available
        self.penalties = []
        self.bonuses = []
        self.requiredShipType = nil
        self.assignedShip = nil
        self.clientId = UUID()
        self.clientName = clientName
        self.contractSignDate = Date()
        self.estimatedProfit = self.totalValue * 0.2 // 20% estimated margin
        self.riskAssessment = RiskAssessment()
        
        // Add default penalties and bonuses
        setupDefaultPenaltiesAndBonuses()
    }
    
    private mutating func setupDefaultPenaltiesAndBonuses() {
        // Add late delivery penalty
        penalties.append(Penalty(
            type: .lateFee,
            amount: totalValue * 0.1,
            description: "10% penalty for late delivery"
        ))
        
        // Add early delivery bonus
        bonuses.append(Bonus(
            type: .earlyDelivery,
            amount: totalValue * 0.05,
            description: "5% bonus for early delivery",
            condition: "Deliver 24+ hours early"
        ))
        
        // Add condition bonus
        bonuses.append(Bonus(
            type: .perfectCondition,
            amount: totalValue * 0.03,
            description: "3% bonus for perfect cargo condition",
            condition: "No damage to cargo"
        ))
    }
}

// MARK: - Cargo Trading System

/// System for managing cargo trading, contracts, and port operations
public class CargoTradingSystem: System {
    public let priority = 75
    public let canRunInParallel = false // Contracts need synchronization
    public let requiredComponents: [ComponentType] = []
    
    private var availableContracts: [TradingContractComponent] = []
    private var activeContracts: [UUID: TradingContractComponent] = [:]
    private var contractGenerationInterval: TimeInterval = 45.0 // Generate contracts every 45 seconds
    private var lastContractGeneration = Date()
    private var economicSystem: EconomicSystem?
    
    // Port data for contract generation
    private let majorPorts = [
        "Singapore", "Hong Kong", "Shanghai", "Los Angeles", 
        "New York", "London", "Dubai", "Rotterdam", "Hamburg", "Mumbai"
    ]
    
    private let clientNames = [
        "Global Logistics Inc.", "Pacific Trading Co.", "European Freight Ltd.",
        "Asian Commerce Corp.", "TransOceanic Shipping", "Continental Cargo",
        "Maritime Solutions", "Worldwide Transport", "International Trade Co.",
        "Ocean Connect Ltd.", "Global Supply Chain", "Premier Logistics"
    ]
    
    public init() {}
    
    public func setEconomicSystem(_ system: EconomicSystem) {
        self.economicSystem = system
    }
    
    public func update(deltaTime: TimeInterval, world: World) {
        // Generate new contracts periodically
        if Date().timeIntervalSince(lastContractGeneration) >= contractGenerationInterval {
            generateRandomContract()
            lastContractGeneration = Date()
        }
        
        // Update active contracts
        updateActiveContracts(deltaTime: deltaTime, world: world)
        
        // Process ship cargo operations
        processCargoOperations(deltaTime: deltaTime, world: world)
        
        // Expire old available contracts
        expireOldContracts()
    }
    
    private func generateRandomContract() {
        guard availableContracts.count < 20 else { return } // Limit available contracts
        
        let cargoType = CargoComponent.CargoType.allCases.randomElement()!
        let originPort = majorPorts.randomElement()!
        var destinationPort = majorPorts.randomElement()!
        
        // Ensure different ports
        while destinationPort == originPort {
            destinationPort = majorPorts.randomElement()!
        }
        
        let quantity = generateQuantity(for: cargoType)
        let pricePerUnit = generatePrice(for: cargoType)
        let priority = generatePriority()
        let deadline = generateDeadline(for: priority)
        let clientName = clientNames.randomElement()!
        
        var contract = TradingContractComponent(
            cargoType: cargoType,
            quantity: quantity,
            pricePerUnit: pricePerUnit,
            originPort: originPort,
            destinationPort: destinationPort,
            deadline: deadline,
            priority: priority,
            clientName: clientName
        )
        
        // Set contract type based on characteristics
        contract.contractType = generateContractType(for: priority, quantity: quantity)
        
        // Calculate risk assessment
        contract.riskAssessment = calculateRiskAssessment(
            originPort: originPort,
            destinationPort: destinationPort,
            cargoType: cargoType
        )
        
        // Adjust price based on risk
        let riskMultiplier = 1.0 + Double(contract.riskAssessment.overallRisk) * 0.5
        contract.pricePerUnit *= riskMultiplier
        contract.totalValue = Double(contract.quantity) * contract.pricePerUnit
        
        availableContracts.append(contract)
        
        NotificationCenter.default.post(
            name: Notification.Name("NewContractAvailable"),
            object: contract
        )
    }
    
    private func generateQuantity(for cargoType: CargoComponent.CargoType) -> Int {
        switch cargoType {
        case .container: return Int.random(in: 50...500)
        case .oil: return Int.random(in: 1000...10000) // Barrels
        case .grain: return Int.random(in: 500...5000) // Tons
        case .electronics: return Int.random(in: 10...100)
        case .automobiles: return Int.random(in: 20...200)
        case .steel: return Int.random(in: 100...1000)
        case .coal: return Int.random(in: 1000...20000)
        case .lng: return Int.random(in: 500...5000)
        case .chemicals: return Int.random(in: 100...1000)
        case .machinery: return Int.random(in: 5...50)
        case .timber: return Int.random(in: 200...2000)
        case .livestock: return Int.random(in: 50...500)
        case .perishables: return Int.random(in: 100...1000)
        case .hazardous: return Int.random(in: 10...100)
        }
    }
    
    private func generatePrice(for cargoType: CargoComponent.CargoType) -> Double {
        let basePrice: Double
        
        switch cargoType {
        case .container: basePrice = 2000.0
        case .oil: basePrice = 80.0
        case .grain: basePrice = 250.0
        case .electronics: basePrice = 5000.0
        case .automobiles: basePrice = 30000.0
        case .steel: basePrice = 800.0
        case .coal: basePrice = 100.0
        case .lng: basePrice = 400.0
        case .chemicals: basePrice = 1500.0
        case .machinery: basePrice = 10000.0
        case .timber: basePrice = 150.0
        case .livestock: basePrice = 1200.0
        case .perishables: basePrice = 800.0
        case .hazardous: basePrice = 2500.0
        }
        
        // Apply market volatility
        let volatility = 0.2 // ±20%
        let marketMultiplier = 1.0 + Double.random(in: -volatility...volatility)
        
        // Get current market price if economic system is available
        if let economicSystem = economicSystem,
           let marketPrice = economicSystem.getMarketPrice(for: cargoType.rawValue) {
            return marketPrice * marketMultiplier
        }
        
        return basePrice * marketMultiplier
    }
    
    private func generatePriority() -> TradingContractComponent.ContractPriority {
        let random = Double.random(in: 0...1)
        
        switch random {
        case 0.0..<0.4: return .normal
        case 0.4..<0.7: return .high
        case 0.7..<0.9: return .low
        case 0.9..<0.98: return .urgent
        default: return .critical
        }
    }
    
    private func generateDeadline(for priority: TradingContractComponent.ContractPriority) -> Date {
        let daysFromNow: Int
        
        switch priority {
        case .critical: daysFromNow = Int.random(in: 1...2)
        case .urgent: daysFromNow = Int.random(in: 2...5)
        case .high: daysFromNow = Int.random(in: 5...10)
        case .normal: daysFromNow = Int.random(in: 7...21)
        case .low: daysFromNow = Int.random(in: 14...30)
        }
        
        return Calendar.current.date(byAdding: .day, value: daysFromNow, to: Date()) ?? Date()
    }
    
    private func generateContractType(
        for priority: TradingContractComponent.ContractPriority,
        quantity: Int
    ) -> TradingContractComponent.ContractType {
        if priority == .critical || priority == .urgent {
            return .emergency
        } else if quantity > 1000 {
            return .charter
        } else {
            return .spot
        }
    }
    
    private func calculateRiskAssessment(
        originPort: String,
        destinationPort: String,
        cargoType: CargoComponent.CargoType
    ) -> TradingContractComponent.RiskAssessment {
        var assessment = TradingContractComponent.RiskAssessment()
        
        // Weather risk based on regions
        let highWeatherRiskPorts = ["Singapore", "Hong Kong", "Mumbai"]
        if highWeatherRiskPorts.contains(originPort) || highWeatherRiskPorts.contains(destinationPort) {
            assessment.weatherRisk = Float.random(in: 0.3...0.7)
            assessment.riskFactors.append("Seasonal weather patterns")
        } else {
            assessment.weatherRisk = Float.random(in: 0.1...0.3)
        }
        
        // Piracy risk based on routes
        let highPiracyRiskPorts = ["Mumbai", "Dubai"]
        if highPiracyRiskPorts.contains(originPort) || highPiracyRiskPorts.contains(destinationPort) {
            assessment.piracyRisk = Float.random(in: 0.2...0.5)
            assessment.riskFactors.append("Piracy activity in region")
        } else {
            assessment.piracyRisk = Float.random(in: 0.0...0.2)
        }
        
        // Political risk
        assessment.politicalRisk = Float.random(in: 0.0...0.3)
        
        // Market risk based on cargo type
        switch cargoType {
        case .oil, .lng, .chemicals:
            assessment.marketRisk = Float.random(in: 0.3...0.6)
            assessment.riskFactors.append("Volatile commodity prices")
        case .electronics, .automobiles:
            assessment.marketRisk = Float.random(in: 0.2...0.4)
            assessment.riskFactors.append("Technology market fluctuations")
        default:
            assessment.marketRisk = Float.random(in: 0.1...0.3)
        }
        
        assessment.calculateOverallRisk()
        return assessment
    }
    
    private func updateActiveContracts(deltaTime: TimeInterval, world: World) {
        var contractsToComplete: [UUID] = []
        var contractsToFail: [UUID] = []
        
        for (contractId, var contract) in activeContracts {
            // Check if contract deadline has passed
            if Date() > contract.deadline && contract.status != .completed {
                contract.status = .failed
                contractsToFail.append(contractId)
                continue
            }
            
            // Update contract based on assigned ship progress
            if let shipEntity = contract.assignedShip,
               let ship = world.getComponent(ShipComponent.self, for: shipEntity),
               let cargo = world.getComponent(CargoComponent.self, for: shipEntity) {
                
                // Check if ship has reached destination
                if ship.currentPort == contract.destinationPort && cargo.currentLoad > 0 {
                    // Contract completed
                    contract.status = .completed
                    contractsToComplete.append(contractId)
                    
                    // Calculate final payment with bonuses/penalties
                    let finalPayment = calculateFinalPayment(for: contract)
                    
                    // Apply payment to ship's economy
                    if var economy = world.getComponent(EconomyComponent.self, for: shipEntity) {
                        economy.money += finalPayment
                        world.addComponent(economy, to: shipEntity)
                    }
                    
                    // Update asset management with revenue
                    if var assetManagement = world.getComponent(AssetManagementComponent.self, for: shipEntity) {
                        assetManagement.addRevenue(
                            finalPayment,
                            source: "Contract: \(contract.clientName)",
                            tradeRoute: nil
                        )
                        world.addComponent(assetManagement, to: shipEntity)
                    }
                }
            }
            
            activeContracts[contractId] = contract
        }
        
        // Remove completed/failed contracts
        for contractId in contractsToComplete + contractsToFail {
            if let contract = activeContracts.removeValue(forKey: contractId) {
                NotificationCenter.default.post(
                    name: Notification.Name("ContractStatusChanged"),
                    object: contract,
                    userInfo: ["status": contract.status]
                )
            }
        }
    }
    
    private func calculateFinalPayment(for contract: TradingContractComponent) -> Double {
        var payment = contract.totalValue
        
        // Apply early delivery bonus
        let deliveryTime = Date()
        if deliveryTime < contract.deadline.addingTimeInterval(-24 * 3600) { // 24 hours early
            for bonus in contract.bonuses {
                if bonus.type == .earlyDelivery {
                    payment += bonus.amount
                    break
                }
            }
        }
        
        // Apply perfect condition bonus (simplified - assume perfect if delivered)
        for bonus in contract.bonuses {
            if bonus.type == .perfectCondition {
                payment += bonus.amount
                break
            }
        }
        
        return payment
    }
    
    private func processCargoOperations(deltaTime: TimeInterval, world: World) {
        let cargoEntities = world.getEntitiesWithComponents([.cargo, .ship])
        
        for entity in cargoEntities {
            guard var cargo = world.getComponent(CargoComponent.self, for: entity),
                  let ship = world.getComponent(ShipComponent.self, for: entity) else {
                continue
            }
            
            // Update loading/unloading progress
            if cargo.isLoading || cargo.isUnloading {
                let loadingSpeed: Float = 0.1 // 10% per second
                cargo.loadingProgress += loadingSpeed * Float(deltaTime)
                
                if cargo.loadingProgress >= 1.0 {
                    cargo.loadingProgress = 0.0
                    cargo.isLoading = false
                    cargo.isUnloading = false
                }
                
                world.addComponent(cargo, to: entity)
            }
            
            // Check for expired perishable cargo
            var expiredItems: [UUID] = []
            for item in cargo.cargoManifest {
                if let expiryDate = item.expiryDate, Date() > expiryDate {
                    expiredItems.append(item.id)
                }
            }
            
            // Remove expired cargo
            for itemId in expiredItems {
                if let expiredItem = cargo.removeCargo(itemId: itemId) {
                    // Apply penalty for spoiled cargo
                    if var assetManagement = world.getComponent(AssetManagementComponent.self, for: entity) {
                        assetManagement.addCost(
                            expiredItem.value * 0.8, // 80% loss
                            category: .emergency,
                            description: "Spoiled cargo: \(expiredItem.cargoType.rawValue)"
                        )
                        world.addComponent(assetManagement, to: entity)
                    }
                }
            }
            
            if !expiredItems.isEmpty {
                world.addComponent(cargo, to: entity)
            }
        }
    }
    
    private func expireOldContracts() {
        let twoDaysAgo = Date().addingTimeInterval(-2 * 24 * 3600)
        availableContracts.removeAll { contract in
            contract.contractSignDate < twoDaysAgo && contract.status == .available
        }
    }
    
    // MARK: - Public Interface
    
    public func acceptContract(_ contract: TradingContractComponent, withShip shipEntity: Entity, world: World) -> Bool {
        guard contract.status == .available else { return false }
        guard let ship = world.getComponent(ShipComponent.self, for: shipEntity),
              var cargo = world.getComponent(CargoComponent.self, for: shipEntity) else {
            return false
        }
        
        // Check if ship can handle the cargo
        guard cargo.capacity >= contract.quantity else { return false }
        
        // Create cargo item for contract
        let cargoItem = CargoComponent.CargoItem(
            cargoType: contract.cargoType,
            quantity: contract.quantity,
            weight: Float(contract.quantity) * getCargoWeight(for: contract.cargoType),
            value: contract.totalValue,
            origin: contract.originPort,
            destination: contract.destinationPort
        )
        
        // Add cargo to ship
        guard cargo.addCargo(cargoItem) else { return false }
        
        // Update contract
        var updatedContract = contract
        updatedContract.status = .accepted
        updatedContract.assignedShip = shipEntity
        
        // Move from available to active contracts
        availableContracts.removeAll { $0.contractId == contract.contractId }
        activeContracts[updatedContract.contractId] = updatedContract
        
        // Update ship components
        world.addComponent(cargo, to: shipEntity)
        
        NotificationCenter.default.post(
            name: Notification.Name("ContractAccepted"),
            object: updatedContract,
            userInfo: ["shipEntity": shipEntity]
        )
        
        return true
    }
    
    private func getCargoWeight(for cargoType: CargoComponent.CargoType) -> Float {
        switch cargoType {
        case .container: return 20.0
        case .oil: return 0.8
        case .grain: return 1.0
        case .electronics: return 5.0
        case .automobiles: return 1500.0
        case .steel: return 1.0
        case .coal: return 1.0
        case .lng: return 0.5
        case .chemicals: return 1.2
        case .machinery: return 500.0
        case .timber: return 0.8
        case .livestock: return 300.0
        case .perishables: return 0.5
        case .hazardous: return 2.0
        }
    }
    
    public func getAvailableContracts() -> [TradingContractComponent] {
        return availableContracts.filter { $0.status == .available }
    }
    
    public func getActiveContracts() -> [TradingContractComponent] {
        return Array(activeContracts.values)
    }
}

// MARK: - Extended Component Types

extension ComponentType {
    public static let cargo = ComponentType(rawValue: "cargo")
    public static let tradingContract = ComponentType(rawValue: "tradingContract")
}