import Foundation
import simd

// MARK: - Core Simulation Models

public struct GlobalMarketState {
    public var timestamp: Date
    public var totalGlobalTrade: Double
    public var averageShippingCost: Double
    public var globalInventoryLevels: Double
    public var supplyChainStress: Double
    public var demandPressure: Double
    public var marketLiquidity: Double
    public var volatilityIndex: Double
    public var commodityPrices: [String: Double] = [:]
    public var exchangeRates: [String: Double] = [:]
    public var interestRates: [String: Double] = [:]
    
    public init(timestamp: Date = Date(), totalGlobalTrade: Double = 0, averageShippingCost: Double = 0,
                globalInventoryLevels: Double = 0, supplyChainStress: Double = 0, demandPressure: Double = 0,
                marketLiquidity: Double = 0, volatilityIndex: Double = 0) {
        self.timestamp = timestamp
        self.totalGlobalTrade = totalGlobalTrade
        self.averageShippingCost = averageShippingCost
        self.globalInventoryLevels = globalInventoryLevels
        self.supplyChainStress = supplyChainStress
        self.demandPressure = demandPressure
        self.marketLiquidity = marketLiquidity
        self.volatilityIndex = volatilityIndex
    }
}

// MARK: - Supply Chain Models

public struct SupplyChain {
    public let name: String
    public let commodityTypes: [String]
    public var productionNodes: [ProductionNode]
    public var transportationNetwork: TransportationNetwork
    public var storageCapacity: Double
    public var currentUtilization: Double
    public var efficiency: Double
    public var inventoryLevel: Double
    
    // Calculated properties
    public var totalCapacity: Double {
        productionNodes.map { $0.capacity }.reduce(0, +)
    }
    
    public var averageCost: Double {
        let costs = productionNodes.map { $0.operatingCost }
        return costs.reduce(0, +) / Double(costs.count)
    }
    
    public var congestionLevel: Double {
        currentUtilization > 0.8 ? (currentUtilization - 0.8) / 0.2 : 0.0
    }
    
    public var riskLevel: Double {
        let geopoliticalRisk = calculateGeopoliticalRisk()
        let operationalRisk = 1.0 - efficiency
        let concentrationRisk = calculateConcentrationRisk()
        return (geopoliticalRisk + operationalRisk + concentrationRisk) / 3.0
    }
    
    // Dynamic properties updated by simulation
    public var commodityOutputs: [String: Double] = [:]
    public var operatingCosts: Double = 0.0
    public var transportationCosts: Double = 0.0
    public var energyCosts: Double = 1.0
    public var laborCosts: Double = 1.0
    public var regulatoryCompliance: Double = 0.8
    
    public init(name: String, commodityTypes: [String], productionNodes: [ProductionNode],
                transportationNetwork: TransportationNetwork, storageCapacity: Double,
                currentUtilization: Double, efficiency: Double, inventoryLevel: Double) {
        self.name = name
        self.commodityTypes = commodityTypes
        self.productionNodes = productionNodes
        self.transportationNetwork = transportationNetwork
        self.storageCapacity = storageCapacity
        self.currentUtilization = currentUtilization
        self.efficiency = efficiency
        self.inventoryLevel = inventoryLevel
        
        // Initialize commodity outputs
        for commodity in commodityTypes {
            commodityOutputs[commodity] = totalCapacity * currentUtilization / Double(commodityTypes.count)
        }
    }
    
    private func calculateGeopoliticalRisk() -> Double {
        let risks = productionNodes.map { node in
            getGeopoliticalRisk(for: node.location)
        }
        return risks.reduce(0, +) / Double(risks.count)
    }
    
    private func calculateConcentrationRisk() -> Double {
        let totalCapacity = self.totalCapacity
        let concentrations = productionNodes.map { $0.capacity / totalCapacity }
        let herfindahlIndex = concentrations.map { $0 * $0 }.reduce(0, +)
        return herfindahlIndex // Higher values indicate more concentration
    }
    
    private func getGeopoliticalRisk(for location: String) -> Double {
        let riskMap: [String: Double] = [
            "USA": 0.1, "Canada": 0.1, "Australia": 0.15, "Norway": 0.1,
            "Saudi Arabia": 0.4, "UAE": 0.3, "Qatar": 0.3,
            "Russia": 0.6, "Iran": 0.8, "Venezuela": 0.7,
            "China": 0.3, "India": 0.35, "Brazil": 0.25,
            "Nigeria": 0.6, "Angola": 0.6, "Iraq": 0.8,
            "Libya": 0.9, "Yemen": 0.95, "Afghanistan": 0.98
        ]
        return riskMap[location] ?? 0.5
    }
}

public struct ProductionNode {
    public let name: String
    public var capacity: Double
    public var efficiency: Double
    public let location: String
    public var operatingCost: Double
    public var maintenanceSchedule: MaintenanceSchedule
    public var technologyLevel: Double
    public var environmentalCompliance: Double
    public var skillLevel: Double
    
    public init(name: String, capacity: Double, efficiency: Double, location: String,
                operatingCost: Double = 0.0, technologyLevel: Double = 0.8,
                environmentalCompliance: Double = 0.8, skillLevel: Double = 0.7) {
        self.name = name
        self.capacity = capacity
        self.efficiency = efficiency
        self.location = location
        self.operatingCost = operatingCost
        self.technologyLevel = technologyLevel
        self.environmentalCompliance = environmentalCompliance
        self.skillLevel = skillLevel
        self.maintenanceSchedule = MaintenanceSchedule()
    }
}

public struct MaintenanceSchedule {
    public var lastMaintenance: Date = Date().addingTimeInterval(-86400 * 30) // 30 days ago
    public var nextMaintenance: Date = Date().addingTimeInterval(86400 * 60) // 60 days from now
    public var maintenanceInterval: TimeInterval = 86400 * 90 // 90 days
    public var maintenanceDuration: TimeInterval = 86400 * 7 // 7 days
    public var criticalityLevel: Double = 0.3
    
    public var isMaintenanceDue: Bool {
        Date() >= nextMaintenance
    }
    
    public var maintenanceUrgency: Double {
        let timeUntilMaintenance = nextMaintenance.timeIntervalSinceNow
        let urgency = max(0, 1.0 - timeUntilMaintenance / maintenanceInterval)
        return urgency * criticalityLevel
    }
}

public struct TransportationNetwork {
    public var routes: [TransportRoute]
    public var hubCapacities: [String: Double] = [:]
    public var congestionLevels: [String: Double] = [:]
    public var averageTransitTime: TimeInterval = 0
    public var reliabilityScore: Double = 0.85
    
    public init(routes: [TransportRoute]) {
        self.routes = routes
        calculateAverageTransitTime()
    }
    
    private mutating func calculateAverageTransitTime() {
        let transitTimes = routes.map { $0.estimatedTransitTime }
        averageTransitTime = transitTimes.reduce(0, +) / Double(transitTimes.count)
    }
    
    public var totalCapacity: Double {
        routes.map { $0.capacity }.reduce(0, +)
    }
    
    public var averageCost: Double {
        let costs = routes.map { $0.costPerUnit }
        return costs.reduce(0, +) / Double(costs.count)
    }
}

public struct TransportRoute {
    public let origin: String
    public let destination: String
    public let mode: TransportMode
    public var capacity: Double
    public var costPerUnit: Double
    public var estimatedTransitTime: TimeInterval
    public var reliabilityScore: Double
    public var currentUtilization: Double
    public var weatherSensitivity: Double
    public var seasonalFactors: [Int: Double] // Month -> multiplier
    
    public init(origin: String, destination: String, mode: TransportMode, capacity: Double,
                cost: Double, estimatedTransitTime: TimeInterval = 0, reliabilityScore: Double = 0.85,
                currentUtilization: Double = 0.7, weatherSensitivity: Double = 0.2) {
        self.origin = origin
        self.destination = destination
        self.mode = mode
        self.capacity = capacity
        self.costPerUnit = cost
        self.estimatedTransitTime = estimatedTransitTime > 0 ? estimatedTransitTime : mode.defaultTransitTime
        self.reliabilityScore = reliabilityScore
        self.currentUtilization = currentUtilization
        self.weatherSensitivity = weatherSensitivity
        self.seasonalFactors = mode.defaultSeasonalFactors
    }
    
    public var availableCapacity: Double {
        capacity * (1.0 - currentUtilization)
    }
    
    public var congestionLevel: Double {
        max(0, currentUtilization - 0.8) / 0.2
    }
}

public enum TransportMode: String, CaseIterable {
    case pipeline = "Pipeline"
    case tanker = "Tanker"
    case bulkCarrier = "Bulk Carrier"
    case container = "Container Ship"
    case lng = "LNG Carrier"
    case rail = "Rail"
    case truck = "Truck"
    case air = "Air Freight"
    case barge = "Barge"
    
    public var defaultTransitTime: TimeInterval {
        switch self {
        case .pipeline: return 86400 * 7 // 7 days
        case .tanker: return 86400 * 21 // 21 days
        case .bulkCarrier: return 86400 * 18 // 18 days
        case .container: return 86400 * 16 // 16 days
        case .lng: return 86400 * 14 // 14 days
        case .rail: return 86400 * 10 // 10 days
        case .truck: return 86400 * 3 // 3 days
        case .air: return 86400 * 1 // 1 day
        case .barge: return 86400 * 12 // 12 days
        }
    }
    
    public var defaultSeasonalFactors: [Int: Double] {
        switch self {
        case .tanker, .bulkCarrier, .container, .lng:
            return [1: 1.1, 2: 1.1, 3: 1.0, 4: 0.95, 5: 0.9, 6: 0.9, 7: 0.95, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.05, 12: 1.1]
        case .rail, .truck:
            return [1: 1.05, 2: 1.05, 3: 1.0, 4: 0.98, 5: 0.95, 6: 0.95, 7: 0.98, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.02, 12: 1.05]
        case .air:
            return [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0]
        case .pipeline, .barge:
            return [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0]
        }
    }
}

// MARK: - Demand Center Models

public struct DemandCenter {
    public let name: String
    public var population: Int
    public var gdpPerCapita: Double
    public var economicGrowthRate: Double
    public var inflationRate: Double
    public var interestRate: Double = 0.05
    public var unemploymentRate: Double = 0.04
    public var consumerConfidence: Double = 0.7
    
    // Consumption patterns
    public var consumptionPatterns: [String: Double] // Commodity -> Annual consumption
    public var industrialDemand: [String: Double] // Commodity -> Industrial demand
    public var seasonalFactors: [String: [Int: Double]] // Commodity -> Month -> multiplier
    
    // Economic elasticity
    public var priceElasticity: Double
    public var incomeElasticity: Double
    public var substitutionElasticities: [String: [String: Double]] = [:] // Commodity -> Substitute -> elasticity
    
    // Dynamic properties
    public var commodityDemands: [String: Double] = [:]
    public var commodityElasticities: [String: Double] = [:]
    public var demandGrowthRate: Double = 0.03
    public var purchasingPower: Double = 1.0
    public var inventoryLevels: Double = 0.7
    public var totalDemand: Double = 0.0
    
    public init(name: String, population: Int, gdpPerCapita: Double, economicGrowthRate: Double,
                inflationRate: Double, consumptionPatterns: [String: Double], industrialDemand: [String: Double],
                seasonalFactors: [String: [Int: Double]], priceElasticity: Double, incomeElasticity: Double) {
        self.name = name
        self.population = population
        self.gdpPerCapita = gdpPerCapita
        self.economicGrowthRate = economicGrowthRate
        self.inflationRate = inflationRate
        self.consumptionPatterns = consumptionPatterns
        self.industrialDemand = industrialDemand
        self.seasonalFactors = seasonalFactors
        self.priceElasticity = priceElasticity
        self.incomeElasticity = incomeElasticity
        
        initializeDemands()
        calculateTotalDemand()
    }
    
    private mutating func initializeDemands() {
        // Combine consumption and industrial demand
        for (commodity, consumption) in consumptionPatterns {
            let industrial = industrialDemand[commodity] ?? 0.0
            commodityDemands[commodity] = consumption + industrial
            commodityElasticities[commodity] = priceElasticity
        }
        
        for (commodity, industrial) in industrialDemand {
            if commodityDemands[commodity] == nil {
                commodityDemands[commodity] = industrial
                commodityElasticities[commodity] = priceElasticity * 0.5 // Industrial demand less elastic
            }
        }
    }
    
    private mutating func calculateTotalDemand() {
        totalDemand = commodityDemands.values.reduce(0, +)
    }
    
    public var gdpTotal: Double {
        Double(population) * gdpPerCapita
    }
    
    public var consumptionCapacity: Double {
        gdpTotal * 0.7 // 70% of GDP for consumption
    }
}

// MARK: - Market Interconnection Models

public struct MarketInterconnectionMatrix {
    private var connections: [InterconnectionEdge] = []
    private var nodeStrengths: [String: Double] = [:]
    private var networkMetrics: NetworkMetrics = NetworkMetrics()
    
    public mutating func addConnection(_ from: String, _ to: String, strength: Double, type: InterconnectionType) {
        let edge = InterconnectionEdge(from: from, to: to, strength: strength, type: type)
        connections.append(edge)
        updateNodeStrengths(from, to, strength)
    }
    
    private mutating func updateNodeStrengths(_ from: String, _ to: String, _ strength: Double) {
        nodeStrengths[from, default: 0.0] += strength * 0.5
        nodeStrengths[to, default: 0.0] += strength * 0.5
    }
    
    public mutating func calculateNetworkEffects() {
        networkMetrics.density = calculateNetworkDensity()
        networkMetrics.clustering = calculateClustering()
        networkMetrics.centralityMeasures = calculateCentralityMeasures()
        networkMetrics.communityStructure = detectCommunities()
    }
    
    public func calculateNetworkDensity() -> Double {
        let nodes = Set(connections.flatMap { [$0.from, $0.to] })
        let maxPossibleEdges = nodes.count * (nodes.count - 1)
        return maxPossibleEdges > 0 ? Double(connections.count) / Double(maxPossibleEdges) : 0.0
    }
    
    public func calculatePropagationEffects(currentState: GlobalMarketState, 
                                           supplyChains: [String: SupplyChain],
                                           demandCenters: [String: DemandCenter]) -> PropagationEffects {
        var supplyEffects: [String: SupplyEffect] = [:]
        var demandEffects: [String: DemandEffect] = [:]
        
        // Calculate supply chain effects
        for (chainName, chain) in supplyChains {
            let effect = calculateSupplyChainEffect(chain: chain, marketState: currentState)
            supplyEffects[chainName] = effect
        }
        
        // Calculate demand center effects
        for (centerName, center) in demandCenters {
            let effect = calculateDemandCenterEffect(center: center, marketState: currentState)
            demandEffects[centerName] = effect
        }
        
        return PropagationEffects(supplyEffects: supplyEffects, demandEffects: demandEffects)
    }
    
    private func calculateSupplyChainEffect(chain: SupplyChain, marketState: GlobalMarketState) -> SupplyEffect {
        let relevantConnections = connections.filter { $0.from == chain.name || $0.to == chain.name }
        
        var capacityMultiplier = 1.0
        var costMultiplier = 1.0
        var efficiencyMultiplier = 1.0
        
        for connection in relevantConnections {
            let strength = connection.strength
            let impact = calculateConnectionImpact(connection, marketState)
            
            switch connection.type {
            case .input:
                costMultiplier *= (1.0 + impact * strength)
            case .substitute:
                capacityMultiplier *= (1.0 - impact * strength * 0.5)
            case .complement:
                capacityMultiplier *= (1.0 + impact * strength * 0.3)
            case .demand, .supply:
                efficiencyMultiplier *= (1.0 + impact * strength * 0.2)
            }
        }
        
        return SupplyEffect(
            capacityMultiplier: capacityMultiplier,
            costMultiplier: costMultiplier,
            efficiencyMultiplier: efficiencyMultiplier
        )
    }
    
    private func calculateDemandCenterEffect(center: DemandCenter, marketState: GlobalMarketState) -> DemandEffect {
        let relevantConnections = connections.filter { $0.from == center.name || $0.to == center.name }
        
        var demandMultiplier = 1.0
        var elasticityMultiplier = 1.0
        
        for connection in relevantConnections {
            let strength = connection.strength
            let impact = calculateConnectionImpact(connection, marketState)
            
            switch connection.type {
            case .demand:
                demandMultiplier *= (1.0 + impact * strength * 0.5)
            case .substitute:
                elasticityMultiplier *= (1.0 + impact * strength * 0.3)
            default:
                demandMultiplier *= (1.0 + impact * strength * 0.1)
            }
        }
        
        return DemandEffect(
            demandMultiplier: demandMultiplier,
            elasticityMultiplier: elasticityMultiplier
        )
    }
    
    private func calculateConnectionImpact(_ connection: InterconnectionEdge, _ marketState: GlobalMarketState) -> Double {
        // Calculate the impact of market conditions on this connection
        let volatility = marketState.volatilityIndex
        let stress = marketState.supplyChainStress
        let pressure = marketState.demandPressure
        
        return (volatility + stress + pressure) / 3.0 - 0.5 // Normalize around 0
    }
    
    private func calculateClustering() -> Double {
        // Simplified clustering coefficient calculation
        return 0.3 // Placeholder
    }
    
    private func calculateCentralityMeasures() -> [String: Double] {
        var centrality: [String: Double] = [:]
        
        for (node, strength) in nodeStrengths {
            centrality[node] = strength
        }
        
        return centrality
    }
    
    private func detectCommunities() -> [String: Int] {
        // Simplified community detection
        var communities: [String: Int] = [:]
        var communityId = 0
        
        let nodes = Set(connections.flatMap { [$0.from, $0.to] })
        for node in nodes {
            communities[node] = communityId % 3 // Simple grouping
            communityId += 1
        }
        
        return communities
    }
}

public struct InterconnectionEdge {
    public let from: String
    public let to: String
    public var strength: Double
    public let type: InterconnectionType
    public var lastUpdated: Date = Date()
    
    public init(from: String, to: String, strength: Double, type: InterconnectionType) {
        self.from = from
        self.to = to
        self.strength = strength
        self.type = type
    }
}

public enum InterconnectionType: String, CaseIterable {
    case input = "Input"           // One is input to another
    case substitute = "Substitute" // Can be substituted for each other
    case complement = "Complement" // Used together
    case demand = "Demand"         // Demand relationship
    case supply = "Supply"         // Supply relationship
}

public struct NetworkMetrics {
    public var density: Double = 0.0
    public var clustering: Double = 0.0
    public var centralityMeasures: [String: Double] = [:]
    public var communityStructure: [String: Int] = [:]
    public var averagePathLength: Double = 0.0
    public var diameter: Int = 0
}

public struct PropagationEffects {
    public let supplyEffects: [String: SupplyEffect]
    public let demandEffects: [String: DemandEffect]
}

public struct SupplyEffect {
    public let capacityMultiplier: Double
    public let costMultiplier: Double
    public let efficiencyMultiplier: Double
}

public struct DemandEffect {
    public let demandMultiplier: Double
    public let elasticityMultiplier: Double
}

// MARK: - Market Shock Models

public struct MarketShock {
    public let id: UUID
    public let type: ShockType
    public let commodity: String
    public let region: String
    public let magnitude: Double
    public let duration: TimeInterval
    public let startTime: Date
    public let description: String
    public let probability: Double
    public var propagationPaths: [String] = []
    public var decayRate: Double = 0.1
    
    public var currentIntensity: Double {
        let elapsed = Date().timeIntervalSince(startTime)
        let normalizedTime = elapsed / duration
        
        if normalizedTime >= 1.0 {
            return 0.0
        }
        
        // Exponential decay
        return magnitude * exp(-decayRate * normalizedTime)
    }
    
    public var isActive: Bool {
        Date().timeIntervalSince(startTime) < duration
    }
}

public enum ShockType: String, CaseIterable {
    case supply = "Supply Shock"
    case demand = "Demand Shock"
    case transportation = "Transportation Disruption"
    case regulatory = "Regulatory Change"
    case technology = "Technology Disruption"
    case natural = "Natural Disaster"
    case geopolitical = "Geopolitical Event"
    case financial = "Financial Crisis"
    case pandemic = "Pandemic"
    case cyber = "Cyber Attack"
}

// MARK: - Simulation Engines

public class SupplyDynamicsEngine {
    public func updateProductionCapacity(_ chain: SupplyChain, timeStep: TimeInterval, 
                                       externalFactors: SupplyFactors) -> SupplyChain {
        var updatedChain = chain
        
        // Update production nodes
        for i in 0..<updatedChain.productionNodes.count {
            var node = updatedChain.productionNodes[i]
            
            // Apply capacity growth/decline
            let capacityChange = calculateCapacityChange(node: node, factors: externalFactors, timeStep: timeStep)
            node.capacity *= (1.0 + capacityChange)
            
            // Update efficiency
            let efficiencyChange = calculateEfficiencyChange(node: node, factors: externalFactors)
            node.efficiency = max(0.1, min(1.0, node.efficiency + efficiencyChange))
            
            updatedChain.productionNodes[i] = node
        }
        
        return updatedChain
    }
    
    public func updateInventoryLevels(_ chain: SupplyChain, demand: Double, timeStep: TimeInterval) -> SupplyChain {
        var updatedChain = chain
        
        let production = updatedChain.totalCapacity * updatedChain.currentUtilization
        let inventoryChange = (production - demand) * timeStep / 86400 // Normalize to daily
        
        let maxInventory = updatedChain.storageCapacity
        let newInventoryLevel = updatedChain.inventoryLevel + inventoryChange / maxInventory
        
        updatedChain.inventoryLevel = max(0.0, min(1.0, newInventoryLevel))
        
        return updatedChain
    }
    
    public func updateTransportationNetworks(_ chain: SupplyChain, shippingCosts: Double, 
                                           congestionLevels: [String: Double]) -> SupplyChain {
        var updatedChain = chain
        
        // Update route utilization and costs
        for i in 0..<updatedChain.transportationNetwork.routes.count {
            var route = updatedChain.transportationNetwork.routes[i]
            
            // Update congestion
            let congestion = congestionLevels["\(route.origin)-\(route.destination)"] ?? 0.3
            route.currentUtilization = congestion
            
            // Update costs based on congestion and fuel prices
            let congestionMultiplier = 1.0 + congestion * 0.5
            route.costPerUnit *= congestionMultiplier * shippingCosts
            
            updatedChain.transportationNetwork.routes[i] = route
        }
        
        return updatedChain
    }
    
    public func updateSupplierBehavior(_ chain: SupplyChain, marketConditions: MarketConditions, 
                                     timeStep: TimeInterval) -> SupplyChain {
        var updatedChain = chain
        
        // Adjust utilization based on market conditions
        let targetUtilization = calculateTargetUtilization(conditions: marketConditions)
        let utilizationAdjustment = (targetUtilization - updatedChain.currentUtilization) * 0.1
        
        updatedChain.currentUtilization = max(0.1, min(1.0, updatedChain.currentUtilization + utilizationAdjustment))
        
        return updatedChain
    }
    
    private func calculateCapacityChange(node: ProductionNode, factors: SupplyFactors, timeStep: TimeInterval) -> Double {
        let investmentRate = factors.investmentLevel * 0.05 // 5% annual growth max
        let depreciationRate = -0.02 // 2% annual depreciation
        let technologyEffect = (node.technologyLevel - 0.5) * 0.01
        
        let annualChange = investmentRate + depreciationRate + technologyEffect
        return annualChange * timeStep / (365.25 * 86400) // Convert to timeStep
    }
    
    private func calculateEfficiencyChange(node: ProductionNode, factors: SupplyFactors) -> Double {
        let skillEffect = (node.skillLevel - 0.5) * 0.01
        let maintenanceEffect = node.maintenanceSchedule.isMaintenanceDue ? -0.05 : 0.01
        let environmentalEffect = (node.environmentalCompliance - 0.5) * 0.005
        
        return skillEffect + maintenanceEffect + environmentalEffect
    }
    
    private func calculateTargetUtilization(conditions: MarketConditions) -> Double {
        let demandFactor = conditions.demandLevel
        let priceFactor = (conditions.priceLevel - 1.0) * 0.5
        let costFactor = -(conditions.costLevel - 1.0) * 0.3
        
        let baseUtilization = 0.75
        return max(0.1, min(1.0, baseUtilization + demandFactor + priceFactor + costFactor))
    }
}

public class DemandDynamicsEngine {
    public func updateConsumptionPatterns(_ center: DemandCenter, economicConditions: EconomicConditions, 
                                        timeStep: TimeInterval) -> DemandCenter {
        var updatedCenter = center
        
        // Update based on economic growth
        let growthEffect = economicConditions.gdpGrowthRate * updatedCenter.incomeElasticity
        
        // Update purchasing power
        let inflationEffect = -economicConditions.inflationRate
        updatedCenter.purchasingPower *= (1.0 + (growthEffect + inflationEffect) * timeStep / (365.25 * 86400))
        
        // Update commodity demands
        for (commodity, baseDemand) in updatedCenter.commodityDemands {
            let elasticity = updatedCenter.commodityElasticities[commodity] ?? updatedCenter.priceElasticity
            let priceEffect = economicConditions.commodityPrices[commodity] ?? 1.0
            let demandChange = elasticity * log(priceEffect) + growthEffect
            
            updatedCenter.commodityDemands[commodity] = baseDemand * (1.0 + demandChange)
        }
        
        return updatedCenter
    }
    
    public func updateIndustrialDemand(_ center: DemandCenter, productionLevels: ProductionLevels, 
                                     timeStep: TimeInterval) -> DemandCenter {
        var updatedCenter = center
        
        // Update industrial demands based on production levels
        for (commodity, baseDemand) in updatedCenter.industrialDemand {
            let productionLevel = productionLevels.levels[commodity] ?? 1.0
            let newDemand = baseDemand * productionLevel
            
            if updatedCenter.commodityDemands[commodity] != nil {
                updatedCenter.commodityDemands[commodity]! += (newDemand - baseDemand)
            }
        }
        
        return updatedCenter
    }
    
    public func updateConsumerDemand(_ center: DemandCenter, demographics: Demographics, 
                                   seasonality: SeasonalFactors, timeStep: TimeInterval) -> DemandCenter {
        var updatedCenter = center
        
        // Apply demographic changes
        let populationGrowth = demographics.populationGrowthRate
        let ageDistributionEffect = calculateAgeDistributionEffect(demographics.ageDistribution)
        
        // Apply seasonal adjustments
        let currentMonth = Calendar.current.component(.month, from: Date())
        
        for (commodity, baseDemand) in updatedCenter.consumptionPatterns {
            let seasonalMultiplier = updatedCenter.seasonalFactors[commodity]?[currentMonth] ?? 1.0
            let demographicMultiplier = 1.0 + populationGrowth + ageDistributionEffect
            
            let adjustedDemand = baseDemand * seasonalMultiplier * demographicMultiplier
            updatedCenter.commodityDemands[commodity] = adjustedDemand
        }
        
        return updatedCenter
    }
    
    public func updateStrategicStockpiling(_ center: DemandCenter, geopoliticalFactors: GeopoliticalFactors, 
                                         timeStep: TimeInterval) -> DemandCenter {
        var updatedCenter = center
        
        // Increase demand for strategic commodities during times of uncertainty
        let riskLevel = geopoliticalFactors.politicalRisk
        let strategicCommodities = ["CRUDE_OIL", "NATURAL_GAS", "WHEAT", "SEMICONDUCTORS", "REE"]
        
        for commodity in strategicCommodities {
            if let currentDemand = updatedCenter.commodityDemands[commodity] {
                let stockpilingMultiplier = 1.0 + riskLevel * 0.2
                updatedCenter.commodityDemands[commodity] = currentDemand * stockpilingMultiplier
            }
        }
        
        return updatedCenter
    }
    
    private func calculateAgeDistributionEffect(_ ageDistribution: AgeDistribution) -> Double {
        // Younger populations consume more, older populations consume differently
        let youthFactor = ageDistribution.under30Percentage * 0.05
        let elderlyFactor = ageDistribution.over65Percentage * (-0.02)
        return youthFactor + elderlyFactor
    }
}

public class PriceDiscoveryEngine {
    public func calculateEquilibriumPrice(commodity: String, supply: Double, demand: Double, 
                                        currentPrice: Double, elasticity: Double, 
                                        marketLiquidity: Double, timeStep: TimeInterval) -> Double {
        // Basic supply-demand equilibrium
        let supplyDemandRatio = demand / max(supply, 0.001)
        let priceChange = (supplyDemandRatio - 1.0) * abs(elasticity)
        
        // Adjust for market liquidity
        let liquidityAdjustment = (1.0 - marketLiquidity) * 0.1
        let adjustedPriceChange = priceChange * (1.0 + liquidityAdjustment)
        
        // Apply time-based smoothing
        let smoothingFactor = timeStep / 86400 // Daily smoothing
        let newPrice = currentPrice * (1.0 + adjustedPriceChange * smoothingFactor)
        
        return max(currentPrice * 0.5, min(currentPrice * 2.0, newPrice)) // Limit extreme changes
    }
}

public class ShockPropagationEngine {
    public func calculateShockIntensity(shock: MarketShock, currentTime: Date) -> Double {
        return shock.currentIntensity
    }
}

public class ElasticityCalculator {
    public func calculatePriceElasticity(commodity: String, region: String, timeHorizon: TimeInterval) -> Double {
        // Elasticity varies by commodity type and time horizon
        let baseElasticities: [String: Double] = [
            "CRUDE_OIL": -0.1,
            "NATURAL_GAS": -0.2,
            "WHEAT": -0.3,
            "CORN": -0.4,
            "STEEL": -0.2,
            "COPPER": -0.3,
            "GOLD": -0.05,
            "SEMICONDUCTORS": -0.1
        ]
        
        let baseElasticity = baseElasticities[commodity] ?? -0.25
        
        // Adjust for time horizon (more elastic in long term)
        let timeAdjustment = min(1.0, timeHorizon / (86400 * 365)) * 0.5
        
        return baseElasticity * (1.0 + timeAdjustment)
    }
}

// MARK: - Supporting Data Structures

public struct SupplyFactors {
    public let investmentLevel: Double
    public let regulatoryEnvironment: Double
    public let technologyProgress: Double
    public let laborAvailability: Double
    public let energyCosts: Double
    public let rawMaterialCosts: Double
    
    public init(investmentLevel: Double = 1.0, regulatoryEnvironment: Double = 0.8,
                technologyProgress: Double = 0.05, laborAvailability: Double = 0.9,
                energyCosts: Double = 1.0, rawMaterialCosts: Double = 1.0) {
        self.investmentLevel = investmentLevel
        self.regulatoryEnvironment = regulatoryEnvironment
        self.technologyProgress = technologyProgress
        self.laborAvailability = laborAvailability
        self.energyCosts = energyCosts
        self.rawMaterialCosts = rawMaterialCosts
    }
}

public struct MarketConditions {
    public let demandLevel: Double
    public let priceLevel: Double
    public let costLevel: Double
    public let competitionLevel: Double
    public let regulatoryStability: Double
    
    public init(demandLevel: Double = 1.0, priceLevel: Double = 1.0, costLevel: Double = 1.0,
                competitionLevel: Double = 0.5, regulatoryStability: Double = 0.8) {
        self.demandLevel = demandLevel
        self.priceLevel = priceLevel
        self.costLevel = costLevel
        self.competitionLevel = competitionLevel
        self.regulatoryStability = regulatoryStability
    }
}

public struct EconomicConditions {
    public let gdpGrowthRate: Double
    public let inflationRate: Double
    public let interestRate: Double
    public let unemploymentRate: Double
    public let consumerConfidence: Double
    public let commodityPrices: [String: Double]
    
    public init(gdpGrowthRate: Double = 0.03, inflationRate: Double = 0.025, interestRate: Double = 0.05,
                unemploymentRate: Double = 0.04, consumerConfidence: Double = 0.7, commodityPrices: [String: Double] = [:]) {
        self.gdpGrowthRate = gdpGrowthRate
        self.inflationRate = inflationRate
        self.interestRate = interestRate
        self.unemploymentRate = unemploymentRate
        self.consumerConfidence = consumerConfidence
        self.commodityPrices = commodityPrices
    }
}

public struct ProductionLevels {
    public let levels: [String: Double]
    
    public init(levels: [String: Double] = [:]) {
        self.levels = levels
    }
}

public struct Demographics {
    public let populationGrowthRate: Double
    public let ageDistribution: AgeDistribution
    public let urbanizationRate: Double
    public let educationLevel: Double
    
    public init(populationGrowthRate: Double = 0.01, ageDistribution: AgeDistribution = AgeDistribution(),
                urbanizationRate: Double = 0.55, educationLevel: Double = 0.7) {
        self.populationGrowthRate = populationGrowthRate
        self.ageDistribution = ageDistribution
        self.urbanizationRate = urbanizationRate
        self.educationLevel = educationLevel
    }
}

public struct AgeDistribution {
    public let under30Percentage: Double
    public let between30And65Percentage: Double
    public let over65Percentage: Double
    
    public init(under30: Double = 0.4, between30And65: Double = 0.5, over65: Double = 0.1) {
        self.under30Percentage = under30
        self.between30And65Percentage = between30And65
        self.over65Percentage = over65
    }
}

// MARK: - External Data Integration

public class RealTimeDataAdapter: ObservableObject {
    @Published public var marketUpdates: [MarketUpdate] = []
    
    public func processUpdate(_ update: MarketUpdate) {
        marketUpdates.append(update)
    }
}

public class EconomicIndicatorService: ObservableObject {
    @Published public var latestIndicators: EconomicIndicators = EconomicIndicators()
    
    public func updateIndicators(_ indicators: EconomicIndicators) {
        latestIndicators = indicators
    }
}

public struct MarketUpdate {
    public let type: MarketUpdateType
    public let commodity: String
    public let region: String
    public let value: Double
    public let timestamp: Date
    public let source: String
    
    public init(type: MarketUpdateType, commodity: String, region: String, value: Double, source: String) {
        self.type = type
        self.commodity = commodity
        self.region = region
        self.value = value
        self.timestamp = Date()
        self.source = source
    }
}

public enum MarketUpdateType: String, CaseIterable {
    case priceUpdate = "Price Update"
    case supplyShock = "Supply Shock"
    case demandSurge = "Demand Surge"
    case transportationDisruption = "Transportation Disruption"
    case regulatoryChange = "Regulatory Change"
}

public struct EconomicIndicators {
    public let gdpGrowthRates: [String: Double]
    public let inflationRates: [String: Double]
    public let interestRates: [String: Double]
    public let unemploymentRates: [String: Double]
    public let consumerConfidence: [String: Double]
    public let energyPrices: [String: Double]
    public let laborCosts: [String: Double]
    public let regulatoryIndex: [String: Double]
    
    public init(gdpGrowthRates: [String: Double] = [:], inflationRates: [String: Double] = [:],
                interestRates: [String: Double] = [:], unemploymentRates: [String: Double] = [:],
                consumerConfidence: [String: Double] = [:], energyPrices: [String: Double] = [:],
                laborCosts: [String: Double] = [:], regulatoryIndex: [String: Double] = [:]) {
        self.gdpGrowthRates = gdpGrowthRates
        self.inflationRates = inflationRates
        self.interestRates = interestRates
        self.unemploymentRates = unemploymentRates
        self.consumerConfidence = consumerConfidence
        self.energyPrices = energyPrices
        self.laborCosts = laborCosts
        self.regulatoryIndex = regulatoryIndex
    }
}

// MARK: - Analysis and Forecasting Models

public struct SupplyChainStatus {
    public let name: String
    public let healthScore: Double
    public let bottlenecks: [String]
    public let efficiency: Double
    public let capacity: Double
    public let utilization: Double
    public let averageCost: Double
    public let riskLevel: Double
}

public struct DemandCenterAnalysis {
    public let name: String
    public let totalDemand: Double
    public let growthRate: Double
    public let elasticity: Double
    public let seasonality: [String: [Int: Double]]
    public let economicHealth: Double
    public let purchasingPower: Double
    public let forecast: [String: Double]
}

public struct InterconnectionAnalysis {
    public let networkDensity: Double
    public let systemicRisk: Double
    public let propagationSpeed: Double
    public let criticalNodes: [String]
    public let clusterAnalysis: [String: [String]]
    public let resilience: Double
}

public struct MarketForecast {
    public let timeHorizon: TimeInterval
    public let priceForecasts: [String: Double]
    public let supplyForecasts: [String: Double]
    public let demandForecasts: [String: Double]
    public let riskAssessment: RiskAssessment
    public let confidence: Double
    public let scenarios: [MarketScenario]
}

public struct RiskAssessment {
    public let overallRisk: Double
    public let supplyRisk: Double
    public let demandRisk: Double
    public let priceRisk: Double
    public let geopoliticalRisk: Double
    public let operationalRisk: Double
}

public struct MarketScenario {
    public let name: String
    public let description: String
    public let probability: Double
    public let duration: TimeInterval
    public let changes: [ScenarioChange]
}

public struct ScenarioChange {
    public let type: ScenarioChangeType
    public let target: String
    public let magnitude: Double
    public let description: String
}

public enum ScenarioChangeType: String, CaseIterable {
    case supplyCapacityChange = "Supply Capacity Change"
    case demandShift = "Demand Shift"
    case regulatoryChange = "Regulatory Change"
    case technologyAdoption = "Technology Adoption"
}

public struct ScenarioResult {
    public let scenario: MarketScenario
    public let results: SimulationResults
    public let impactAnalysis: ImpactAnalysis
    public let riskMetrics: RiskMetrics
    public let mitigationStrategies: [MitigationStrategy]
}

public struct SimulationResults {
    public var priceEvolution: [String: [TimeSeriesPoint]] = [:]
    public var supplyEvolution: [String: [TimeSeriesPoint]] = [:]
    public var demandEvolution: [String: [TimeSeriesPoint]] = [:]
    public var marketMetrics: [TimeSeriesPoint] = []
    
    public mutating func recordStep(_ marketState: GlobalMarketState, 
                                   _ supplyChains: [String: SupplyChain],
                                   _ demandCenters: [String: DemandCenter]) {
        let timestamp = marketState.timestamp
        
        // Record prices
        for (commodity, price) in marketState.commodityPrices {
            if priceEvolution[commodity] == nil {
                priceEvolution[commodity] = []
            }
            priceEvolution[commodity]?.append(TimeSeriesPoint(timestamp: timestamp, value: price))
        }
        
        // Record supply
        for (chainName, chain) in supplyChains {
            if supplyEvolution[chainName] == nil {
                supplyEvolution[chainName] = []
            }
            supplyEvolution[chainName]?.append(TimeSeriesPoint(timestamp: timestamp, value: chain.totalCapacity))
        }
        
        // Record demand
        for (centerName, center) in demandCenters {
            if demandEvolution[centerName] == nil {
                demandEvolution[centerName] = []
            }
            demandEvolution[centerName]?.append(TimeSeriesPoint(timestamp: timestamp, value: center.totalDemand))
        }
        
        // Record market metrics
        marketMetrics.append(TimeSeriesPoint(timestamp: timestamp, value: marketState.volatilityIndex))
    }
}

public struct TimeSeriesPoint {
    public let timestamp: Date
    public let value: Double
    
    public init(timestamp: Date, value: Double) {
        self.timestamp = timestamp
        self.value = value
    }
}

public struct ImpactAnalysis {
    public let priceImpacts: [String: Double]
    public let supplyImpacts: [String: Double]
    public let demandImpacts: [String: Double]
    public let overallImpact: Double
}

public struct RiskMetrics {
    public let volatility: Double
    public let maxDrawdown: Double
    public let valueAtRisk: Double
    public let expectedShortfall: Double
}

public struct MitigationStrategy {
    public let name: String
    public let description: String
    public let effectiveness: Double
    public let cost: Double
    public let timeToImplement: TimeInterval
}

public struct SimulationState {
    public let marketState: GlobalMarketState
    public let supplyChains: [String: SupplyChain]
    public let demandCenters: [String: DemandCenter]
    public let marketShocks: [MarketShock]
    public let simulationTime: Date
}