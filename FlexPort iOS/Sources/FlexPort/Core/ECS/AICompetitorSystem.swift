import Foundation
import simd

// MARK: - AI Competitor Components

/// Component for AI competitors in the market
public struct AICompetitorComponent: Component {
    public static let componentType = ComponentType.aiCompetitor
    
    public var competitorId: UUID
    public var name: String
    public var competitorType: CompetitorType
    public var aggressiveness: Float // 0.0 to 1.0
    public var intelligence: Float // 0.0 to 1.0
    public var resources: Double // Available capital
    public var marketShare: Float // 0.0 to 1.0
    public var reputation: Float // 0.0 to 1.0
    public var fleetSize: Int
    public var specialization: Specialization
    public var strategicFocus: StrategicFocus
    public var competitiveAdvantages: Set<CompetitiveAdvantage>
    public var weaknesses: Set<Weakness>
    public var marketPenetration: [GeographicRegion: Float]
    public var performanceMetrics: PerformanceMetrics
    public var aiLevel: AILevel
    public var learningRate: Float
    public var adaptationSpeed: Float
    
    public enum CompetitorType: String, Codable {
        case corporateGiant = "Corporate Giant"
        case nimbleStartup = "Nimble Startup"
        case governmentOwned = "Government-Owned"
        case regionalPlayer = "Regional Player"
        case aiEnhanced = "AI-Enhanced"
        case traditionalist = "Traditionalist"
        case disruptor = "Market Disruptor"
    }
    
    public enum Specialization: String, Codable {
        case containerShipping = "Container Shipping"
        case bulkCargo = "Bulk Cargo"
        case tankerOperations = "Tanker Operations"
        case luxuryGoods = "Luxury Goods"
        case perishables = "Perishables"
        case hazardousMaterials = "Hazardous Materials"
        case emergencyLogistics = "Emergency Logistics"
        case shortHaul = "Short Haul"
        case longHaul = "Long Haul"
        case multiModal = "Multi-Modal Transport"
    }
    
    public enum StrategicFocus: String, Codable {
        case costLeadership = "Cost Leadership"
        case premiumService = "Premium Service"
        case speedOptimization = "Speed Optimization"
        case reliabilityFirst = "Reliability First"
        case technologyInnovation = "Technology Innovation"
        case sustainabilityLeader = "Sustainability Leader"
        case marketExpansion = "Market Expansion"
        case verticalIntegration = "Vertical Integration"
    }
    
    public enum CompetitiveAdvantage: String, Codable {
        case advancedAI = "Advanced AI"
        case fuelEfficiency = "Fuel Efficiency"
        case speedSuperiority = "Speed Superiority"
        case costEffectiveness = "Cost Effectiveness"
        case reliabilityRecord = "Reliability Record"
        case globalNetwork = "Global Network"
        case specializedFleet = "Specialized Fleet"
        case governmentContracts = "Government Contracts"
        case technologyIntegration = "Technology Integration"
        case environmentalCompliance = "Environmental Compliance"
    }
    
    public enum Weakness: String, Codable {
        case highOperatingCosts = "High Operating Costs"
        case limitedFleet = "Limited Fleet"
        case poorReputation = "Poor Reputation"
        case technologicalLag = "Technological Lag"
        case geographicLimitations = "Geographic Limitations"
        case inflexibleOperations = "Inflexible Operations"
        case capitalConstraints = "Capital Constraints"
        case regulatoryIssues = "Regulatory Issues"
    }
    
    public enum AILevel: String, Codable {
        case basic = "Basic"
        case intermediate = "Intermediate"
        case advanced = "Advanced"
        case expert = "Expert"
        case superhuman = "Superhuman"
        case singularity = "Post-Singularity"
    }
    
    public struct PerformanceMetrics: Codable {
        public var totalRevenue: Double
        public var profitMargin: Float
        public var onTimeDeliveryRate: Float
        public var customerSatisfaction: Float
        public var fuelEfficiency: Float
        public var accidentRate: Float
        public var marketGrowthRate: Float
        public var contractWinRate: Float
        
        public init() {
            self.totalRevenue = 0.0
            self.profitMargin = 0.15
            self.onTimeDeliveryRate = 0.85
            self.customerSatisfaction = 0.7
            self.fuelEfficiency = 0.6
            self.accidentRate = 0.02
            self.marketGrowthRate = 0.0
            self.contractWinRate = 0.3
        }
    }
    
    public init(name: String, competitorType: CompetitorType, specialization: Specialization) {
        self.competitorId = UUID()
        self.name = name
        self.competitorType = competitorType
        self.specialization = specialization
        
        // Generate base attributes based on competitor type
        let (aggressiveness, intelligence, resources, reputation) = AICompetitorComponent.generateBaseAttributes(for: competitorType)
        
        self.aggressiveness = aggressiveness
        self.intelligence = intelligence
        self.resources = resources
        self.reputation = reputation
        self.marketShare = Float.random(in: 0.05...0.15)
        self.fleetSize = Int.random(in: 5...50)
        self.strategicFocus = AICompetitorComponent.generateStrategicFocus(for: competitorType)
        self.competitiveAdvantages = AICompetitorComponent.generateAdvantages(for: competitorType, specialization: specialization)
        self.weaknesses = AICompetitorComponent.generateWeaknesses(for: competitorType)
        self.marketPenetration = AICompetitorComponent.generateMarketPenetration()
        self.performanceMetrics = PerformanceMetrics()
        self.aiLevel = AICompetitorComponent.generateAILevel(for: competitorType)
        self.learningRate = Float.random(in: 0.01...0.1)
        self.adaptationSpeed = Float.random(in: 0.05...0.3)
    }
    
    private static func generateBaseAttributes(for type: CompetitorType) -> (Float, Float, Double, Float) {
        switch type {
        case .corporateGiant:
            return (0.7, 0.6, 10_000_000, 0.8)
        case .nimbleStartup:
            return (0.9, 0.8, 500_000, 0.4)
        case .governmentOwned:
            return (0.4, 0.5, 20_000_000, 0.6)
        case .regionalPlayer:
            return (0.6, 0.6, 2_000_000, 0.7)
        case .aiEnhanced:
            return (0.8, 0.95, 5_000_000, 0.5)
        case .traditionalist:
            return (0.3, 0.4, 8_000_000, 0.9)
        case .disruptor:
            return (1.0, 0.9, 1_000_000, 0.3)
        }
    }
    
    private static func generateStrategicFocus(for type: CompetitorType) -> StrategicFocus {
        switch type {
        case .corporateGiant: return .marketExpansion
        case .nimbleStartup: return .technologyInnovation
        case .governmentOwned: return .reliabilityFirst
        case .regionalPlayer: return .costLeadership
        case .aiEnhanced: return .speedOptimization
        case .traditionalist: return .premiumService
        case .disruptor: return .technologyInnovation
        }
    }
    
    private static func generateAdvantages(for type: CompetitorType, specialization: Specialization) -> Set<CompetitiveAdvantage> {
        var advantages: Set<CompetitiveAdvantage> = []
        
        switch type {
        case .corporateGiant:
            advantages.insert(.globalNetwork)
            advantages.insert(.reliabilityRecord)
        case .nimbleStartup:
            advantages.insert(.technologyIntegration)
            advantages.insert(.speedSuperiority)
        case .governmentOwned:
            advantages.insert(.governmentContracts)
            advantages.insert(.costEffectiveness)
        case .regionalPlayer:
            advantages.insert(.costEffectiveness)
        case .aiEnhanced:
            advantages.insert(.advancedAI)
            advantages.insert(.fuelEfficiency)
        case .traditionalist:
            advantages.insert(.reliabilityRecord)
        case .disruptor:
            advantages.insert(.technologyIntegration)
        }
        
        // Add specialization-based advantages
        switch specialization {
        case .containerShipping, .bulkCargo, .tankerOperations:
            advantages.insert(.specializedFleet)
        case .perishables, .emergencyLogistics:
            advantages.insert(.speedSuperiority)
        case .hazardousMaterials:
            advantages.insert(.environmentalCompliance)
        default:
            break
        }
        
        return advantages
    }
    
    private static func generateWeaknesses(for type: CompetitorType) -> Set<Weakness> {
        var weaknesses: Set<Weakness> = []
        
        switch type {
        case .corporateGiant:
            weaknesses.insert(.highOperatingCosts)
            weaknesses.insert(.inflexibleOperations)
        case .nimbleStartup:
            weaknesses.insert(.limitedFleet)
            weaknesses.insert(.capitalConstraints)
        case .governmentOwned:
            weaknesses.insert(.inflexibleOperations)
            weaknesses.insert(.technologicalLag)
        case .regionalPlayer:
            weaknesses.insert(.geographicLimitations)
        case .aiEnhanced:
            weaknesses.insert(.poorReputation)
        case .traditionalist:
            weaknesses.insert(.technologicalLag)
        case .disruptor:
            weaknesses.insert(.poorReputation)
            weaknesses.insert(.regulatoryIssues)
        }
        
        return weaknesses
    }
    
    private static func generateMarketPenetration() -> [GeographicRegion: Float] {
        var penetration: [GeographicRegion: Float] = [:]
        
        for region in GeographicRegion.allCases {
            penetration[region] = Float.random(in: 0.0...0.3)
        }
        
        return penetration
    }
    
    private static func generateAILevel(for type: CompetitorType) -> AILevel {
        switch type {
        case .aiEnhanced: return .advanced
        case .nimbleStartup, .disruptor: return .intermediate
        case .corporateGiant, .regionalPlayer: return .intermediate
        case .governmentOwned, .traditionalist: return .basic
        }
    }
}

/// Component for AI decision making state
public struct AIDecisionStateComponent: Component {
    public static let componentType = ComponentType.aiDecisionState
    
    public var currentStrategy: Strategy
    public var nextDecisionTime: Date
    public var decisionHistory: [Decision]
    public var confidenceLevel: Float
    public var riskTolerance: Float
    public var marketAnalysis: MarketAnalysis
    public var targetPlayer: Entity? // Player they're competing against
    public var strategicPlans: [StrategicPlan]
    public var reactiveMode: Bool // Reacting to player actions
    
    public enum Strategy: String, Codable {
        case aggressive = "Aggressive Expansion"
        case defensive = "Defensive Positioning"
        case opportunistic = "Opportunistic"
        case cooperative = "Cooperative"
        case disruptive = "Market Disruption"
        case innovative = "Innovation Focus"
        case efficient = "Efficiency Optimization"
    }
    
    public struct Decision: Codable {
        public let timestamp: Date
        public let strategy: Strategy
        public let action: ActionType
        public let target: String?
        public let outcome: Outcome?
        
        public enum ActionType: String, Codable {
            case contractBid = "Contract Bid"
            case fleetExpansion = "Fleet Expansion"
            case routeOptimization = "Route Optimization"
            case priceAdjustment = "Price Adjustment"
            case technologyUpgrade = "Technology Upgrade"
            case marketEntry = "Market Entry"
            case partnershipFormation = "Partnership Formation"
            case capacityIncrease = "Capacity Increase"
        }
        
        public enum Outcome: String, Codable {
            case success = "Success"
            case failure = "Failure"
            case partial = "Partial Success"
            case pending = "Pending"
        }
        
        public init(strategy: Strategy, action: ActionType, target: String? = nil) {
            self.timestamp = Date()
            self.strategy = strategy
            self.action = action
            self.target = target
            self.outcome = .pending
        }
    }
    
    public struct MarketAnalysis: Codable {
        public var playerStrength: Float // Analysis of human player
        public var marketOpportunities: [String]
        public var threats: [String]
        public var priceVolatility: Float
        public var demandForecast: Float
        public var competitorRanking: Int
        
        public init() {
            self.playerStrength = 0.5
            self.marketOpportunities = []
            self.threats = []
            self.priceVolatility = 0.2
            self.demandForecast = 0.0
            self.competitorRanking = 5
        }
    }
    
    public struct StrategicPlan: Codable {
        public let id = UUID()
        public var name: String
        public var objectives: [String]
        public var timeline: TimeInterval
        public var requiredResources: Double
        public var expectedROI: Double
        public var priority: Priority
        public var progress: Float
        
        public enum Priority: String, Codable {
            case low = "Low"
            case medium = "Medium"
            case high = "High"
            case critical = "Critical"
        }
        
        public init(name: String, objectives: [String], timeline: TimeInterval, requiredResources: Double) {
            self.name = name
            self.objectives = objectives
            self.timeline = timeline
            self.requiredResources = requiredResources
            self.expectedROI = 0.2 // 20% default ROI expectation
            self.priority = .medium
            self.progress = 0.0
        }
    }
    
    public init() {
        self.currentStrategy = .opportunistic
        self.nextDecisionTime = Date().addingTimeInterval(Double.random(in: 30...120))
        self.decisionHistory = []
        self.confidenceLevel = 0.5
        self.riskTolerance = Float.random(in: 0.2...0.8)
        self.marketAnalysis = MarketAnalysis()
        self.targetPlayer = nil
        self.strategicPlans = []
        self.reactiveMode = false
    }
}

// MARK: - AI Competitor Management System

/// System for managing AI competitors and their behaviors
public class AICompetitorManagementSystem: System {
    public let priority = 120
    public let canRunInParallel = false
    public let requiredComponents: [ComponentType] = [.aiCompetitor]
    
    private var cargoTradingSystem: CargoTradingSystem?
    private var economicSystem: EconomicSystem?
    private var gameWorld: World?
    private let competitorNames = [
        "Maritime Dynamics Corp", "Pacific Logistics Alliance", "Global Trade Syndicate",
        "Ocean Connect International", "Continental Freight Solutions", "Quantum Shipping AI",
        "Neptune's Fleet Management", "TransGlobal Maritime", "Apex Logistics Network",
        "Stellar Shipping Solutions", "Azure Ocean Transport", "Prime Maritime Group"
    ]
    
    public init() {}
    
    public func setCargoTradingSystem(_ system: CargoTradingSystem) {
        self.cargoTradingSystem = system
    }
    
    public func setEconomicSystem(_ system: EconomicSystem) {
        self.economicSystem = system
    }
    
    public func update(deltaTime: TimeInterval, world: World) {
        self.gameWorld = world
        let aiEntities = world.getEntitiesWithComponents(requiredComponents)
        
        for aiEntity in aiEntities {
            guard var aiCompetitor = world.getComponent(AICompetitorComponent.self, for: aiEntity) else {
                continue
            }
            
            // Update AI decision state
            updateAIDecisionState(for: aiEntity, competitor: &aiCompetitor, world: world)
            
            // Execute AI strategies
            executeAIStrategies(for: aiEntity, competitor: aiCompetitor, world: world)
            
            // Update performance metrics
            updatePerformanceMetrics(for: &aiCompetitor, world: world)
            
            // Learn from outcomes
            processLearning(for: &aiCompetitor, world: world)
            
            world.addComponent(aiCompetitor, to: aiEntity)
        }
    }
    
    private func updateAIDecisionState(for entity: Entity, competitor: inout AICompetitorComponent, world: World) {
        var decisionState: AIDecisionStateComponent
        
        if let existingState = world.getComponent(AIDecisionStateComponent.self, for: entity) {
            decisionState = existingState
        } else {
            decisionState = AIDecisionStateComponent()
            decisionState.riskTolerance = competitor.aggressiveness * 0.7 + 0.1
        }
        
        // Check if it's time for a new decision
        if Date() >= decisionState.nextDecisionTime {
            makeStrategicDecision(&decisionState, competitor: competitor, world: world)
            
            // Schedule next decision based on AI level
            let baseInterval: TimeInterval = 60.0 // 1 minute base
            let aiMultiplier = getAISpeedMultiplier(for: competitor.aiLevel)
            decisionState.nextDecisionTime = Date().addingTimeInterval(baseInterval / aiMultiplier)
        }
        
        // Analyze market conditions
        updateMarketAnalysis(&decisionState, competitor: competitor, world: world)
        
        world.addComponent(decisionState, to: entity)
    }
    
    private func makeStrategicDecision(_ decisionState: inout AIDecisionStateComponent, competitor: AICompetitorComponent, world: World) {
        // Analyze current situation
        let marketOpportunities = analyzeMarketOpportunities(competitor: competitor, world: world)
        let threats = analyzeThreats(competitor: competitor, world: world)
        
        // Select strategy based on AI intelligence and market conditions
        let newStrategy = selectOptimalStrategy(
            competitor: competitor,
            opportunities: marketOpportunities,
            threats: threats
        )
        
        if newStrategy != decisionState.currentStrategy {
            decisionState.currentStrategy = newStrategy
            decisionState.confidenceLevel = competitor.intelligence * 0.8 + 0.1
        }
        
        // Decide on specific action
        let action = selectAction(strategy: newStrategy, competitor: competitor, world: world)
        
        let decision = AIDecisionStateComponent.Decision(
            strategy: newStrategy,
            action: action,
            target: getActionTarget(action: action, competitor: competitor, world: world)
        )
        
        decisionState.decisionHistory.append(decision)
        
        // Limit decision history size
        if decisionState.decisionHistory.count > 50 {
            decisionState.decisionHistory.removeFirst()
        }
        
        // Execute the decision
        executeDecision(decision, competitor: competitor, world: world)
    }
    
    private func analyzeMarketOpportunities(competitor: AICompetitorComponent, world: World) -> [String] {
        var opportunities: [String] = []
        
        // Check for available contracts
        if let tradingSystem = cargoTradingSystem {
            let availableContracts = tradingSystem.getAvailableContracts()
            
            if !availableContracts.isEmpty {
                opportunities.append("High-value contracts available")
            }
            
            // Look for underserved routes
            let highPriorityContracts = availableContracts.filter { 
                $0.priority == .urgent || $0.priority == .critical 
            }
            if !highPriorityContracts.isEmpty {
                opportunities.append("Urgent delivery opportunities")
            }
        }
        
        // Check for market gaps in specialization
        if competitor.specialization == .perishables || competitor.specialization == .emergencyLogistics {
            opportunities.append("Time-sensitive cargo demand")
        }
        
        // Check economic conditions
        if let economicSystem = economicSystem {
            // Simplified: assume opportunities exist if certain commodities are volatile
            opportunities.append("Market price volatility")
        }
        
        return opportunities
    }
    
    private func analyzeThreats(competitor: AICompetitorComponent, world: World) -> [String] {
        var threats: [String] = []
        
        // Player competition
        threats.append("Human player competition")
        
        // Economic events
        let eventSystem = world.getSystem(EconomicEventGenerationSystem.self)
        if let events = eventSystem?.getActiveEvents(), !events.isEmpty {
            threats.append("Active economic disruptions")
        }
        
        // Fleet condition (simplified)
        if competitor.fleetSize < 10 {
            threats.append("Limited fleet capacity")
        }
        
        return threats
    }
    
    private func selectOptimalStrategy(competitor: AICompetitorComponent, opportunities: [String], threats: [String]) -> AIDecisionStateComponent.Strategy {
        let opportunityCount = opportunities.count
        let threatCount = threats.count
        
        // Decision based on competitor type and situation
        switch competitor.competitorType {
        case .corporateGiant:
            return threatCount > opportunityCount ? .defensive : .aggressive
        case .nimbleStartup:
            return .innovative
        case .governmentOwned:
            return .defensive
        case .regionalPlayer:
            return opportunityCount > 2 ? .opportunistic : .efficient
        case .aiEnhanced:
            return competitor.intelligence > 0.8 ? .disruptive : .aggressive
        case .traditionalist:
            return .defensive
        case .disruptor:
            return .disruptive
        }
    }
    
    private func selectAction(strategy: AIDecisionStateComponent.Strategy, competitor: AICompetitorComponent, world: World) -> AIDecisionStateComponent.Decision.ActionType {
        switch strategy {
        case .aggressive:
            return Bool.random() ? .contractBid : .fleetExpansion
        case .defensive:
            return .routeOptimization
        case .opportunistic:
            return .contractBid
        case .cooperative:
            return .partnershipFormation
        case .disruptive:
            return .priceAdjustment
        case .innovative:
            return .technologyUpgrade
        case .efficient:
            return .routeOptimization
        }
    }
    
    private func getActionTarget(action: AIDecisionStateComponent.Decision.ActionType, competitor: AICompetitorComponent, world: World) -> String? {
        switch action {
        case .contractBid:
            if let tradingSystem = cargoTradingSystem {
                let contracts = tradingSystem.getAvailableContracts()
                return contracts.randomElement()?.clientName
            }
            return nil
        case .marketEntry:
            let regions = GeographicRegion.allCases.filter { region in
                competitor.marketPenetration[region] ?? 0 < 0.1
            }
            return regions.randomElement()?.rawValue
        default:
            return nil
        }
    }
    
    private func executeDecision(_ decision: AIDecisionStateComponent.Decision, competitor: AICompetitorComponent, world: World) {
        switch decision.action {
        case .contractBid:
            executeContractBidding(competitor: competitor, world: world)
        case .fleetExpansion:
            executeFleetExpansion(competitor: competitor, world: world)
        case .priceAdjustment:
            executePriceAdjustment(competitor: competitor, world: world)
        case .technologyUpgrade:
            executeTechnologyUpgrade(competitor: competitor, world: world)
        case .routeOptimization:
            executeRouteOptimization(competitor: competitor, world: world)
        default:
            // Other actions would be implemented similarly
            break
        }
    }
    
    private func executeContractBidding(competitor: AICompetitorComponent, world: World) {
        guard let tradingSystem = cargoTradingSystem else { return }
        
        let availableContracts = tradingSystem.getAvailableContracts()
        
        // AI selects contracts based on its specialization and strategy
        let suitableContracts = availableContracts.filter { contract in
            // Check if contract matches specialization
            switch competitor.specialization {
            case .containerShipping:
                return contract.cargoType == .container
            case .bulkCargo:
                return [.grain, .coal, .steel].contains(contract.cargoType)
            case .tankerOperations:
                return [.oil, .lng, .chemicals].contains(contract.cargoType)
            case .perishables:
                return contract.cargoType == .perishables
            case .hazardousMaterials:
                return contract.cargoType == .hazardous
            default:
                return true // General competitors can bid on anything
            }
        }
        
        // Bid on most profitable suitable contract
        if let targetContract = suitableContracts.max(by: { $0.totalValue < $1.totalValue }) {
            // Simulate contract competition (simplified)
            let bidSuccessRate = calculateBidSuccessRate(competitor: competitor, contract: targetContract)
            
            if Float.random(in: 0...1) < bidSuccessRate {
                // AI wins contract - reduce available contracts for player
                NotificationCenter.default.post(
                    name: Notification.Name("AICompetitorWonContract"),
                    object: competitor,
                    userInfo: ["contract": targetContract]
                )
            }
        }
    }
    
    private func calculateBidSuccessRate(competitor: AICompetitorComponent, contract: TradingContractComponent) -> Float {
        var successRate: Float = 0.3 // Base 30% chance
        
        // Adjust based on competitor attributes
        successRate += competitor.intelligence * 0.2
        successRate += competitor.reputation * 0.3
        successRate += (competitor.marketShare * 2.0) // Market share helps
        
        // Competitive advantages
        if competitor.competitiveAdvantages.contains(.costEffectiveness) {
            successRate += 0.15
        }
        if competitor.competitiveAdvantages.contains(.reliabilityRecord) {
            successRate += 0.1
        }
        if competitor.competitiveAdvantages.contains(.speedSuperiority) && contract.priority == .urgent {
            successRate += 0.2
        }
        
        // Weaknesses
        if competitor.weaknesses.contains(.highOperatingCosts) {
            successRate -= 0.1
        }
        if competitor.weaknesses.contains(.poorReputation) {
            successRate -= 0.15
        }
        
        return min(0.8, max(0.1, successRate)) // Clamp between 10% and 80%
    }
    
    private func executeFleetExpansion(competitor: AICompetitorComponent, world: World) {
        // Simulate fleet expansion - this would interact with the asset market
        NotificationCenter.default.post(
            name: Notification.Name("AICompetitorFleetExpansion"),
            object: competitor,
            userInfo: ["newShips": Int.random(in: 1...3)]
        )
    }
    
    private func executePriceAdjustment(competitor: AICompetitorComponent, world: World) {
        // Simulate price pressure on the market
        let priceAdjustment = competitor.aggressiveness > 0.7 ? -0.05 : 0.02 // Aggressive pricing vs premium
        
        NotificationCenter.default.post(
            name: Notification.Name("AICompetitorPriceAdjustment"),
            object: competitor,
            userInfo: ["adjustment": priceAdjustment]
        )
    }
    
    private func executeTechnologyUpgrade(competitor: AICompetitorComponent, world: World) {
        // Simulate technology investment
        NotificationCenter.default.post(
            name: Notification.Name("AICompetitorTechUpgrade"),
            object: competitor,
            userInfo: ["upgradeType": "AI Systems"]
        )
    }
    
    private func executeRouteOptimization(competitor: AICompetitorComponent, world: World) {
        // Simulate route efficiency improvements
        NotificationCenter.default.post(
            name: Notification.Name("AICompetitorRouteOptimization"),
            object: competitor,
            userInfo: ["efficiencyGain": Float.random(in: 0.02...0.08)]
        )
    }
    
    private func updateMarketAnalysis(_ decisionState: inout AIDecisionStateComponent, competitor: AICompetitorComponent, world: World) {
        // Analyze player strength (simplified)
        let playerEntities = world.getEntitiesWithComponents([.economy, .ship])
        var playerStrength: Float = 0.5
        
        if !playerEntities.isEmpty {
            let totalPlayerAssets = playerEntities.compactMap { entity in
                world.getComponent(EconomyComponent.self, for: entity)?.money
            }.reduce(0, +)
            
            playerStrength = min(1.0, Float(totalPlayerAssets / 10_000_000)) // Normalized strength
        }
        
        decisionState.marketAnalysis.playerStrength = playerStrength
        
        // Update other market metrics
        decisionState.marketAnalysis.priceVolatility = Float.random(in: 0.1...0.4)
        decisionState.marketAnalysis.demandForecast = Float.random(in: -0.2...0.3)
    }
    
    private func updatePerformanceMetrics(for competitor: inout AICompetitorComponent, world: World) {
        // Update metrics based on recent decisions and market performance
        let performance = &competitor.performanceMetrics
        
        // Simulate performance changes
        performance.totalRevenue += Double.random(in: -10000...50000)
        performance.onTimeDeliveryRate = min(1.0, max(0.0, performance.onTimeDeliveryRate + Float.random(in: -0.02...0.02)))
        performance.customerSatisfaction = min(1.0, max(0.0, performance.customerSatisfaction + Float.random(in: -0.01...0.01)))
        
        // Update market share based on performance
        let performanceScore = (performance.onTimeDeliveryRate + performance.customerSatisfaction) / 2.0
        let marketShareChange = (performanceScore - 0.75) * 0.001 // Small changes
        competitor.marketShare = min(1.0, max(0.0, competitor.marketShare + marketShareChange))
    }
    
    private func processLearning(for competitor: inout AICompetitorComponent, world: World) {
        // AI learning based on recent decision outcomes
        if let decisionState = world.getComponent(AIDecisionStateComponent.self, for: Entity()) {
            // Simplified learning: adjust intelligence and aggressiveness based on success
            let recentDecisions = Array(decisionState.decisionHistory.suffix(5))
            let successRate = Float(recentDecisions.filter { $0.outcome == .success }.count) / Float(max(1, recentDecisions.count))
            
            if successRate > 0.7 {
                // Successful decisions - increase confidence
                competitor.intelligence = min(1.0, competitor.intelligence + competitor.learningRate * 0.1)
            } else if successRate < 0.3 {
                // Poor decisions - adjust strategy
                competitor.aggressiveness = max(0.1, competitor.aggressiveness - competitor.learningRate * 0.1)
            }
        }
        
        // AI level progression
        if competitor.intelligence > 0.9 && competitor.aiLevel == .advanced {
            competitor.aiLevel = .expert
        } else if competitor.intelligence > 0.95 && competitor.aiLevel == .expert {
            competitor.aiLevel = .superhuman
        }
    }
    
    private func getAISpeedMultiplier(for aiLevel: AICompetitorComponent.AILevel) -> Double {
        switch aiLevel {
        case .basic: return 0.5
        case .intermediate: return 1.0
        case .advanced: return 1.5
        case .expert: return 2.0
        case .superhuman: return 3.0
        case .singularity: return 5.0
        }
    }
    
    // MARK: - Public Interface
    
    public func createAICompetitor(type: AICompetitorComponent.CompetitorType, specialization: AICompetitorComponent.Specialization, world: World) -> Entity {
        let name = competitorNames.randomElement() ?? "AI Competitor"
        let competitor = AICompetitorComponent(name: name, competitorType: type, specialization: specialization)
        
        let entity = world.createEntity()
        world.addComponent(competitor, to: entity)
        
        // Add supporting components
        let economy = EconomyComponent(money: competitor.resources)
        world.addComponent(economy, to: entity)
        
        // Create AI ships
        for i in 0..<competitor.fleetSize {
            let ship = createAIShip(for: competitor, index: i, world: world)
            // Ships are separate entities linked to the competitor
        }
        
        NotificationCenter.default.post(
            name: Notification.Name("AICompetitorCreated"),
            object: competitor,
            userInfo: ["entity": entity]
        )
        
        return entity
    }
    
    private func createAIShip(for competitor: AICompetitorComponent, index: Int, world: World) -> Entity {
        let shipEntity = world.createEntity()
        
        let shipType = getShipTypeForSpecialization(competitor.specialization)
        let ship = ShipComponent(
            name: "\(competitor.name) \(index + 1)",
            type: shipType,
            capacity: getCapacityForSpecialization(competitor.specialization),
            speed: 25.0
        )
        
        world.addComponent(ship, to: shipEntity)
        
        // Add AI component
        let ai = AIComponent(behaviorType: .balanced, decisionCooldown: 10.0)
        world.addComponent(ai, to: shipEntity)
        
        // Add cargo component
        let cargo = CargoComponent(
            capacity: ship.capacity,
            temperatureControlled: competitor.specialization == .perishables,
            hazardousLicense: competitor.specialization == .hazardousMaterials
        )
        world.addComponent(cargo, to: shipEntity)
        
        return shipEntity
    }
    
    private func getShipTypeForSpecialization(_ specialization: AICompetitorComponent.Specialization) -> ShipComponent.ShipType {
        switch specialization {
        case .containerShipping: return .container
        case .bulkCargo: return .bulk
        case .tankerOperations: return .tanker
        default: return .cargo
        }
    }
    
    private func getCapacityForSpecialization(_ specialization: AICompetitorComponent.Specialization) -> Int {
        switch specialization {
        case .containerShipping: return Int.random(in: 500...2000)
        case .bulkCargo: return Int.random(in: 1000...5000)
        case .tankerOperations: return Int.random(in: 800...3000)
        case .emergencyLogistics: return Int.random(in: 100...500)
        default: return Int.random(in: 300...1000)
        }
    }
}

// MARK: - Extended Component Types

extension ComponentType {
    public static let aiCompetitor = ComponentType(rawValue: "aiCompetitor")
    public static let aiDecisionState = ComponentType(rawValue: "aiDecisionState")
}