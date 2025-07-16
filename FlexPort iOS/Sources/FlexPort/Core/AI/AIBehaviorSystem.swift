import Foundation
import Combine

/// AI Behavior System for managing computer-controlled competitors
public class AIBehaviorSystem: ObservableObject {
    @Published public var competitors: [AICompetitor] = []
    @Published public var globalAIActivity: Double = 0.0
    
    private var cancellables = Set<AnyCancellable>()
    private let decisionInterval: TimeInterval = 5.0 // AI makes decisions every 5 seconds
    private var lastDecisionTime = Date()
    
    public init() {
        generateInitialCompetitors()
        setupBehaviorMonitoring()
    }
    
    private func setupBehaviorMonitoring() {
        // Monitor competitor performance
        Timer.publish(every: decisionInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateCompetitorBehaviors()
            }
            .store(in: &cancellables)
    }
    
    private func generateInitialCompetitors() {
        let competitorNames = [
            "Titan Logistics", "Global Marine Corp", "Neptune Trading",
            "Ocean Master Inc", "Blue Wave Shipping", "Pacific Giants",
            "Atlantic Express", "Meridian Transport", "Aegis Maritime"
        ]
        
        for name in competitorNames.prefix(5) { // Start with 5 competitors
            let competitor = createCompetitor(name: name)
            competitors.append(competitor)
        }
    }
    
    private func createCompetitor(name: String) -> AICompetitor {
        let behaviorType = AIBehaviorType.allCases.randomElement()!
        let learningRate = Double.random(in: 0.005...0.025)
        let singularityContribution = Double.random(in: 0.1...0.8)
        
        let assets = PlayerAssets(
            money: Double.random(in: 500_000...2_000_000),
            ships: generateCompetitorShips(),
            warehouses: generateCompetitorWarehouses(),
            reputation: Double.random(in: 30...70)
        )
        
        var competitor = AICompetitor(
            name: name,
            assets: assets,
            learningRate: learningRate,
            singularityContribution: singularityContribution
        )
        
        competitor.behaviorProfile = generateBehaviorProfile(for: behaviorType)
        competitor.decisionEngine = AIDecisionEngine(behaviorType: behaviorType)
        competitor.performanceMetrics = AIPerformanceMetrics()
        
        return competitor
    }
    
    private func generateBehaviorProfile(for behaviorType: AIBehaviorType) -> AIBehaviorProfile {
        switch behaviorType {
        case .aggressive:
            return AIBehaviorProfile(
                aggressiveness: Double.random(in: 0.7...0.9),
                riskTolerance: Double.random(in: 0.6...0.8),
                innovationFocus: Double.random(in: 0.4...0.7),
                collaborationTendency: Double.random(in: 0.2...0.4),
                resourceAllocation: ResourceAllocation(
                    research: 0.05,
                    expansion: 0.5,
                    operations: 0.3,
                    defense: 0.15
                )
            )
        case .conservative:
            return AIBehaviorProfile(
                aggressiveness: Double.random(in: 0.2...0.4),
                riskTolerance: Double.random(in: 0.2...0.4),
                innovationFocus: Double.random(in: 0.3...0.5),
                collaborationTendency: Double.random(in: 0.6...0.8),
                resourceAllocation: ResourceAllocation(
                    research: 0.15,
                    expansion: 0.2,
                    operations: 0.5,
                    defense: 0.15
                )
            )
        case .balanced:
            return AIBehaviorProfile(
                aggressiveness: Double.random(in: 0.4...0.6),
                riskTolerance: Double.random(in: 0.4...0.6),
                innovationFocus: Double.random(in: 0.5...0.7),
                collaborationTendency: Double.random(in: 0.4...0.6),
                resourceAllocation: ResourceAllocation(
                    research: 0.1,
                    expansion: 0.3,
                    operations: 0.4,
                    defense: 0.2
                )
            )
        case .experimental:
            return AIBehaviorProfile(
                aggressiveness: Double.random(in: 0.3...0.7),
                riskTolerance: Double.random(in: 0.7...0.9),
                innovationFocus: Double.random(in: 0.8...0.95),
                collaborationTendency: Double.random(in: 0.3...0.5),
                resourceAllocation: ResourceAllocation(
                    research: 0.25,
                    expansion: 0.25,
                    operations: 0.35,
                    defense: 0.15
                )
            )
        }
    }
    
    private func generateCompetitorShips() -> [Ship] {
        let shipCount = Int.random(in: 2...8)
        var ships: [Ship] = []
        
        for i in 0..<shipCount {
            let ship = Ship(
                name: "AI-Ship-\(i)",
                capacity: Int.random(in: 500...5000),
                speed: Double.random(in: 15...28),
                efficiency: Double.random(in: 0.6...0.9),
                maintenanceCost: Double.random(in: 5000...25000),
                price: Double.random(in: 800000...5000000)
            )
            ships.append(ship)
        }
        
        return ships
    }
    
    private func generateCompetitorWarehouses() -> [Warehouse] {
        let warehouseCount = Int.random(in: 1...4)
        var warehouses: [Warehouse] = []
        
        let locations = ["Singapore", "Rotterdam", "Los Angeles", "Shanghai", "Dubai"]
        
        for i in 0..<warehouseCount {
            let location = locations.randomElement()!
            let warehouse = Warehouse(
                location: Location(
                    name: location,
                    coordinates: Coordinates(
                        latitude: Double.random(in: -60...60),
                        longitude: Double.random(in: -180...180)
                    ),
                    portType: .multimodal
                ),
                capacity: Int.random(in: 5000...50000),
                storageCost: Double.random(in: 500...5000),
                price: Double.random(in: 300000...3000000)
            )
            warehouses.append(warehouse)
        }
        
        return warehouses
    }
    
    /// Update AI competitor behaviors and decisions
    public func updateCompetitorBehaviors() {
        let currentTime = Date()
        
        for i in 0..<competitors.count {
            updateCompetitorDecisions(&competitors[i], currentTime: currentTime)
            updateCompetitorPerformance(&competitors[i])
            adaptBehaviorBasedOnPerformance(&competitors[i])
        }
        
        updateGlobalActivity()
        lastDecisionTime = currentTime
    }
    
    private func updateCompetitorDecisions(_ competitor: inout AICompetitor, currentTime: Date) {
        guard let decisionEngine = competitor.decisionEngine else { return }
        
        // Check if it's time for a new decision
        let timeSinceLastDecision = currentTime.timeIntervalSince(competitor.lastDecisionTime)
        if timeSinceLastDecision < competitor.decisionCooldown {
            return
        }
        
        // Generate and execute decision
        let context = AIDecisionContext(
            availableFunds: competitor.assets.money,
            marketConditions: getCurrentMarketConditions(),
            competitorState: competitor,
            singularityProgress: 0.0 // This would come from the singularity system
        )
        
        let decision = decisionEngine.makeDecision(context: context)
        executeDecision(decision, for: &competitor)
        
        competitor.lastDecisionTime = currentTime
    }
    
    private func executeDecision(_ decision: AIDecision, for competitor: inout AICompetitor) {
        switch decision.type {
        case .buyShip(let shipType, let budget):
            executeBuyShip(shipType: shipType, budget: budget, for: &competitor)
        case .sellShip(let shipId):
            executeSellShip(shipId: shipId, for: &competitor)
        case .buyWarehouse(let location, let budget):
            executeBuyWarehouse(location: location, budget: budget, for: &competitor)
        case .investInResearch(let amount):
            executeResearchInvestment(amount: amount, for: &competitor)
        case .createTradeRoute(let route):
            executeCreateTradeRoute(route: route, for: &competitor)
        case .adjustPricing(let modifier):
            executeAdjustPricing(modifier: modifier, for: &competitor)
        case .expandOperations(let region):
            executeExpandOperations(region: region, for: &competitor)
        case .wait:
            // No action taken
            break
        }
        
        // Record decision for learning
        competitor.performanceMetrics?.recordDecision(decision)
    }
    
    private func executeBuyShip(shipType: ShipType, budget: Double, for competitor: inout AICompetitor) {
        if competitor.assets.money >= budget {
            let ship = generateShipForAI(type: shipType, budget: budget)
            competitor.assets.ships.append(ship)
            competitor.assets.money -= ship.price
            
            // Update performance metrics
            competitor.performanceMetrics?.totalInvestment += ship.price
        }
    }
    
    private func executeSellShip(shipId: UUID, for competitor: inout AICompetitor) {
        if let shipIndex = competitor.assets.ships.firstIndex(where: { $0.id == shipId }) {
            let ship = competitor.assets.ships.remove(at: shipIndex)
            let salePrice = ship.price * ship.condition * 0.8 // Depreciation
            competitor.assets.money += salePrice
        }
    }
    
    private func executeBuyWarehouse(location: String, budget: Double, for competitor: inout AICompetitor) {
        if competitor.assets.money >= budget {
            let warehouse = generateWarehouseForAI(location: location, budget: budget)
            competitor.assets.warehouses.append(warehouse)
            competitor.assets.money -= warehouse.price
            
            competitor.performanceMetrics?.totalInvestment += warehouse.price
        }
    }
    
    private func executeResearchInvestment(amount: Double, for competitor: inout AICompetitor) {
        if competitor.assets.money >= amount {
            competitor.assets.money -= amount
            competitor.researchInvestment += amount
            competitor.technologicalAdvantage += amount / 1_000_000 * 0.01 // Small incremental gains
            
            competitor.performanceMetrics?.researchSpending += amount
        }
    }
    
    private func executeCreateTradeRoute(route: TradeRouteDescription, for competitor: inout AICompetitor) {
        // This would integrate with the trade route physics system
        competitor.performanceMetrics?.activeRoutes += 1
    }
    
    private func executeAdjustPricing(modifier: Double, for competitor: inout AICompetitor) {
        competitor.pricingStrategy.baseMultiplier = modifier
    }
    
    private func executeExpandOperations(region: String, for competitor: inout AICompetitor) {
        competitor.operationalRegions.insert(region)
        competitor.assets.money -= 100_000 // Expansion cost
    }
    
    private func updateCompetitorPerformance(_ competitor: inout AICompetitor) {
        guard var metrics = competitor.performanceMetrics else { return }
        
        // Calculate revenue from assets
        let shipRevenue = competitor.assets.ships.reduce(0) { sum, ship in
            sum + calculateShipRevenue(ship)
        }
        
        let warehouseRevenue = competitor.assets.warehouses.reduce(0) { sum, warehouse in
            sum + calculateWarehouseRevenue(warehouse)
        }
        
        let totalRevenue = shipRevenue + warehouseRevenue
        metrics.totalRevenue += totalRevenue
        competitor.assets.money += totalRevenue
        
        // Calculate costs
        let maintenanceCosts = competitor.assets.ships.reduce(0) { sum, ship in
            sum + ship.maintenanceCost
        }
        
        let storageCosts = competitor.assets.warehouses.reduce(0) { sum, warehouse in
            sum + warehouse.storageCost
        }
        
        let totalCosts = maintenanceCosts + storageCosts
        metrics.totalCosts += totalCosts
        competitor.assets.money -= totalCosts
        
        // Update reputation based on performance
        let profitability = (totalRevenue - totalCosts) / max(totalRevenue, 1.0)
        competitor.assets.reputation += profitability * 0.1
        competitor.assets.reputation = max(0, min(100, competitor.assets.reputation))
        
        competitor.performanceMetrics = metrics
    }
    
    private func adaptBehaviorBasedOnPerformance(_ competitor: inout AICompetitor) {
        guard let metrics = competitor.performanceMetrics else { return }
        
        let profitability = (metrics.totalRevenue - metrics.totalCosts) / max(metrics.totalRevenue, 1.0)
        
        // Adjust behavior based on performance
        if profitability < 0.1 { // Poor performance
            // Become more conservative
            competitor.behaviorProfile.riskTolerance *= 0.95
            competitor.behaviorProfile.aggressiveness *= 0.95
        } else if profitability > 0.3 { // Good performance
            // Become more aggressive
            competitor.behaviorProfile.riskTolerance *= 1.05
            competitor.behaviorProfile.aggressiveness *= 1.05
        }
        
        // Clamp values
        competitor.behaviorProfile.riskTolerance = max(0.1, min(0.9, competitor.behaviorProfile.riskTolerance))
        competitor.behaviorProfile.aggressiveness = max(0.1, min(0.9, competitor.behaviorProfile.aggressiveness))
        
        // Learn from decisions
        competitor.learningRate *= 1.001 // Gradual learning improvement
    }
    
    private func updateGlobalActivity() {
        globalAIActivity = competitors.reduce(0) { sum, competitor in
            sum + competitor.behaviorProfile.aggressiveness
        } / Double(competitors.count)
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentMarketConditions() -> MarketConditions {
        // This would integrate with the economic system
        return MarketConditions(
            volatility: 0.5,
            growthRate: 0.02,
            competitiveness: 0.7
        )
    }
    
    private func calculateShipRevenue(_ ship: Ship) -> Double {
        // Simplified revenue calculation
        return Double(ship.capacity) * ship.efficiency * 0.1
    }
    
    private func calculateWarehouseRevenue(_ warehouse: Warehouse) -> Double {
        // Simplified revenue calculation
        return warehouse.utilization * warehouse.storageCost * 0.1
    }
    
    private func generateShipForAI(type: ShipType, budget: Double) -> Ship {
        return Ship(
            name: "AI-\(type.rawValue)-\(UUID().uuidString.prefix(8))",
            capacity: type.capacity,
            speed: type.speed,
            efficiency: Double.random(in: 0.7...0.9),
            maintenanceCost: budget * 0.1,
            price: budget
        )
    }
    
    private func generateWarehouseForAI(location: String, budget: Double) -> Warehouse {
        return Warehouse(
            location: Location(
                name: location,
                coordinates: Coordinates(
                    latitude: Double.random(in: -60...60),
                    longitude: Double.random(in: -180...180)
                ),
                portType: .multimodal
            ),
            capacity: Int(budget / 100),
            storageCost: budget * 0.05,
            price: budget
        )
    }
    
    /// Add a new competitor to the game
    public func addCompetitor(name: String, behaviorType: AIBehaviorType) {
        let competitor = createCompetitor(name: name)
        competitors.append(competitor)
    }
    
    /// Remove a competitor from the game
    public func removeCompetitor(id: UUID) {
        competitors.removeAll { $0.id == id }
    }
    
    /// Get competitor by ID
    public func getCompetitor(id: UUID) -> AICompetitor? {
        return competitors.first { $0.id == id }
    }
}

// MARK: - Supporting Types

public struct AIDecisionContext {
    public let availableFunds: Double
    public let marketConditions: MarketConditions
    public let competitorState: AICompetitor
    public let singularityProgress: Double
}

public struct MarketConditions {
    public let volatility: Double
    public let growthRate: Double
    public let competitiveness: Double
}

public struct AIDecision {
    public let type: AIDecisionType
    public let confidence: Double
    public let expectedReturn: Double
    public let riskLevel: Double
}

public enum AIDecisionType {
    case buyShip(ShipType, budget: Double)
    case sellShip(UUID)
    case buyWarehouse(location: String, budget: Double)
    case investInResearch(amount: Double)
    case createTradeRoute(TradeRouteDescription)
    case adjustPricing(modifier: Double)
    case expandOperations(region: String)
    case wait
}

public struct TradeRouteDescription {
    public let origin: String
    public let destination: String
    public let commodity: String
    public let expectedProfit: Double
}

public enum ShipType: String, CaseIterable {
    case container = "Container"
    case bulkCarrier = "Bulk Carrier"
    case tanker = "Tanker"
    case generalCargo = "General Cargo"
    
    var capacity: Int {
        switch self {
        case .container: return 8000
        case .bulkCarrier: return 12000
        case .tanker: return 10000
        case .generalCargo: return 5000
        }
    }
    
    var speed: Double {
        switch self {
        case .container: return 24.0
        case .bulkCarrier: return 18.0
        case .tanker: return 20.0
        case .generalCargo: return 22.0
        }
    }
}

public class AIPerformanceMetrics {
    public var totalRevenue: Double = 0
    public var totalCosts: Double = 0
    public var totalInvestment: Double = 0
    public var researchSpending: Double = 0
    public var activeRoutes: Int = 0
    public var decisionHistory: [AIDecision] = []
    
    public func recordDecision(_ decision: AIDecision) {
        decisionHistory.append(decision)
        
        // Keep only recent decisions (last 100)
        if decisionHistory.count > 100 {
            decisionHistory.removeFirst()
        }
    }
    
    public var profitability: Double {
        return (totalRevenue - totalCosts) / max(totalRevenue, 1.0)
    }
    
    public var roi: Double {
        return (totalRevenue - totalCosts - totalInvestment) / max(totalInvestment, 1.0)
    }
}

// MARK: - AI Decision Engine

public class AIDecisionEngine {
    private let behaviorType: AIBehaviorType
    private var decisionWeights: [AIDecisionType: Double] = [:]
    
    public init(behaviorType: AIBehaviorType) {
        self.behaviorType = behaviorType
        setupDecisionWeights()
    }
    
    private func setupDecisionWeights() {
        switch behaviorType {
        case .aggressive:
            decisionWeights = [
                .buyShip(.container, budget: 0): 0.3,
                .expandOperations(region: ""): 0.25,
                .adjustPricing(modifier: 0): 0.2,
                .investInResearch(amount: 0): 0.1,
                .wait: 0.15
            ]
        case .conservative:
            decisionWeights = [
                .buyShip(.container, budget: 0): 0.15,
                .investInResearch(amount: 0): 0.25,
                .buyWarehouse(location: "", budget: 0): 0.2,
                .adjustPricing(modifier: 0): 0.15,
                .wait: 0.25
            ]
        case .balanced:
            decisionWeights = [
                .buyShip(.container, budget: 0): 0.2,
                .buyWarehouse(location: "", budget: 0): 0.2,
                .investInResearch(amount: 0): 0.15,
                .expandOperations(region: ""): 0.15,
                .adjustPricing(modifier: 0): 0.15,
                .wait: 0.15
            ]
        case .experimental:
            decisionWeights = [
                .investInResearch(amount: 0): 0.4,
                .buyShip(.container, budget: 0): 0.15,
                .createTradeRoute(TradeRouteDescription(origin: "", destination: "", commodity: "", expectedProfit: 0)): 0.2,
                .expandOperations(region: ""): 0.15,
                .wait: 0.1
            ]
        }
    }
    
    public func makeDecision(context: AIDecisionContext) -> AIDecision {
        // Evaluate each possible decision type
        var scoredDecisions: [(AIDecisionType, Double)] = []
        
        for (decisionType, weight) in decisionWeights {
            let score = evaluateDecision(decisionType, context: context) * weight
            scoredDecisions.append((decisionType, score))
        }
        
        // Sort by score and add randomness
        scoredDecisions.sort { $0.1 > $1.1 }
        
        // Select decision with some randomness (not always the best)
        let randomnessFactor = context.competitorState.behaviorProfile.riskTolerance
        let selectedIndex = Int(Double.random(in: 0...1) * randomnessFactor * Double(min(3, scoredDecisions.count)))
        
        let selectedDecision = scoredDecisions[selectedIndex].0
        let confidence = scoredDecisions[selectedIndex].1
        
        return AIDecision(
            type: selectedDecision,
            confidence: confidence,
            expectedReturn: calculateExpectedReturn(selectedDecision, context: context),
            riskLevel: calculateRiskLevel(selectedDecision, context: context)
        )
    }
    
    private func evaluateDecision(_ decisionType: AIDecisionType, context: AIDecisionContext) -> Double {
        // Simplified decision evaluation
        switch decisionType {
        case .buyShip:
            return evaluateBuyShip(context: context)
        case .sellShip:
            return evaluateSellShip(context: context)
        case .buyWarehouse:
            return evaluateBuyWarehouse(context: context)
        case .investInResearch:
            return evaluateResearchInvestment(context: context)
        case .createTradeRoute:
            return evaluateCreateTradeRoute(context: context)
        case .adjustPricing:
            return evaluateAdjustPricing(context: context)
        case .expandOperations:
            return evaluateExpandOperations(context: context)
        case .wait:
            return 0.3 // Baseline score for waiting
        }
    }
    
    private func evaluateBuyShip(context: AIDecisionContext) -> Double {
        let hasCapital = context.availableFunds > 1_000_000
        let marketGrowth = context.marketConditions.growthRate > 0.01
        let lowCompetition = context.marketConditions.competitiveness < 0.7
        
        var score = 0.0
        if hasCapital { score += 0.4 }
        if marketGrowth { score += 0.3 }
        if lowCompetition { score += 0.3 }
        
        return score
    }
    
    private func evaluateSellShip(context: AIDecisionContext) -> Double {
        let hasExcessShips = context.competitorState.assets.ships.count > 5
        let needsCash = context.availableFunds < 500_000
        let highMaintenance = context.competitorState.assets.ships.contains { $0.maintenanceCost > 20_000 }
        
        var score = 0.0
        if hasExcessShips { score += 0.3 }
        if needsCash { score += 0.4 }
        if highMaintenance { score += 0.3 }
        
        return score
    }
    
    private func evaluateBuyWarehouse(context: AIDecisionContext) -> Double {
        let hasCapital = context.availableFunds > 500_000
        let needsStorage = context.competitorState.assets.warehouses.count < 3
        let stableMarket = context.marketConditions.volatility < 0.5
        
        var score = 0.0
        if hasCapital { score += 0.3 }
        if needsStorage { score += 0.4 }
        if stableMarket { score += 0.3 }
        
        return score
    }
    
    private func evaluateResearchInvestment(context: AIDecisionContext) -> Double {
        let hasCapital = context.availableFunds > 200_000
        let lowTechAdvantage = context.competitorState.technologicalAdvantage < 0.5
        let approachingSingularity = context.singularityProgress > 0.5
        
        var score = 0.0
        if hasCapital { score += 0.3 }
        if lowTechAdvantage { score += 0.4 }
        if approachingSingularity { score += 0.5 }
        
        return score
    }
    
    private func evaluateCreateTradeRoute(context: AIDecisionContext) -> Double {
        let hasShips = !context.competitorState.assets.ships.isEmpty
        let goodMarketConditions = context.marketConditions.growthRate > 0.02
        let lowVolatility = context.marketConditions.volatility < 0.4
        
        var score = 0.0
        if hasShips { score += 0.4 }
        if goodMarketConditions { score += 0.3 }
        if lowVolatility { score += 0.3 }
        
        return score
    }
    
    private func evaluateAdjustPricing(context: AIDecisionContext) -> Double {
        let highCompetition = context.marketConditions.competitiveness > 0.7
        let volatileMarket = context.marketConditions.volatility > 0.5
        
        var score = 0.0
        if highCompetition { score += 0.4 }
        if volatileMarket { score += 0.6 }
        
        return score
    }
    
    private func evaluateExpandOperations(context: AIDecisionContext) -> Double {
        let hasCapital = context.availableFunds > 300_000
        let strongReputation = context.competitorState.assets.reputation > 60
        let growingMarket = context.marketConditions.growthRate > 0.015
        
        var score = 0.0
        if hasCapital { score += 0.3 }
        if strongReputation { score += 0.4 }
        if growingMarket { score += 0.3 }
        
        return score
    }
    
    private func calculateExpectedReturn(_ decisionType: AIDecisionType, context: AIDecisionContext) -> Double {
        // Simplified expected return calculation
        switch decisionType {
        case .buyShip: return 0.15
        case .sellShip: return 0.1
        case .buyWarehouse: return 0.12
        case .investInResearch: return 0.25
        case .createTradeRoute: return 0.2
        case .adjustPricing: return 0.08
        case .expandOperations: return 0.18
        case .wait: return 0.0
        }
    }
    
    private func calculateRiskLevel(_ decisionType: AIDecisionType, context: AIDecisionContext) -> Double {
        // Simplified risk calculation
        switch decisionType {
        case .buyShip: return 0.6
        case .sellShip: return 0.3
        case .buyWarehouse: return 0.4
        case .investInResearch: return 0.7
        case .createTradeRoute: return 0.5
        case .adjustPricing: return 0.2
        case .expandOperations: return 0.8
        case .wait: return 0.1
        }
    }
}

// MARK: - Extensions

extension AICompetitor {
    public var decisionEngine: AIDecisionEngine? {
        get { return nil } // Would be stored separately
        set { /* Would be stored separately */ }
    }
    
    public var performanceMetrics: AIPerformanceMetrics? {
        get { return nil } // Would be stored separately
        set { /* Would be stored separately */ }
    }
    
    public var lastDecisionTime: Date {
        get { return Date().addingTimeInterval(-10) } // Default to allow immediate decisions
        set { /* Would be stored separately */ }
    }
    
    public var decisionCooldown: TimeInterval {
        return 5.0 + Double.random(in: -2...2) // 3-7 seconds with randomness
    }
    
    public var pricingStrategy: PricingStrategy {
        get { return PricingStrategy() }
        set { /* Would be stored separately */ }
    }
    
    public var operationalRegions: Set<String> {
        get { return Set(["Global"]) }
        set { /* Would be stored separately */ }
    }
}

public struct PricingStrategy {
    public var baseMultiplier: Double = 1.0
    public var dynamicAdjustment: Bool = true
    public var competitivenessWeight: Double = 0.5
}

public enum AIBehaviorType: String, Codable, CaseIterable {
    case aggressive = "Aggressive"
    case conservative = "Conservative"
    case balanced = "Balanced"
    case experimental = "Experimental"
}