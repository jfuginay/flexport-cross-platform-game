import Foundation
import Combine
import simd

/// Dynamic market simulation engine with sophisticated supply/demand modeling and interconnected market effects
public class DynamicMarketSimulator: ObservableObject {
    @Published public var marketState: GlobalMarketState = GlobalMarketState()
    @Published public var supplyChains: [String: SupplyChain] = [:]
    @Published public var demandCenters: [String: DemandCenter] = [:]
    @Published public var marketShocks: [MarketShock] = []
    @Published public var interconnectionMatrix: MarketInterconnectionMatrix = MarketInterconnectionMatrix()
    
    // Simulation parameters
    private let simulationTimeStep: TimeInterval = 3600 // 1 hour steps
    private let maxHistoryLength = 8760 // 1 year of hourly data
    
    // Market dynamics engines
    private let supplyDynamicsEngine = SupplyDynamicsEngine()
    private let demandDynamicsEngine = DemandDynamicsEngine()
    private let priceDiscoveryEngine = PriceDiscoveryEngine()
    private let shockPropagationEngine = ShockPropagationEngine()
    private let elasticityCalculator = ElasticityCalculator()
    
    // External data integration
    private let realTimeDataAdapter = RealTimeDataAdapter()
    private let economicIndicatorService = EconomicIndicatorService()
    
    // Simulation state
    private var simulationTime: Date = Date()
    private var simulationSpeed: Double = 1.0 // Real-time multiplier
    private var isRunning = false
    
    private var cancellables = Set<AnyCancellable>()
    private var simulationTimer: Timer?
    
    public init() {
        initializeMarketStructure()
        setupDataSubscriptions()
        calculateInterconnections()
    }
    
    // MARK: - Initialization
    
    private func initializeMarketStructure() {
        // Initialize global supply chains
        supplyChains = [
            "CRUDE_OIL": createCrudeOilSupplyChain(),
            "NATURAL_GAS": createNaturalGasSupplyChain(),
            "IRON_ORE": createIronOreSupplyChain(),
            "AGRICULTURAL": createAgriculturalSupplyChain(),
            "CONTAINER_SHIPPING": createContainerShippingSupplyChain(),
            "SEMICONDUCTOR": createSemiconductorSupplyChain(),
            "RARE_EARTH": createRareEarthSupplyChain()
        ]
        
        // Initialize demand centers
        demandCenters = [
            "CHINA": createChinaDemandCenter(),
            "USA": createUSADemandCenter(),
            "EUROPE": createEuropeDemandCenter(),
            "JAPAN": createJapanDemandCenter(),
            "INDIA": createIndiaDemandCenter(),
            "EMERGING_ASIA": createEmergingAsiaDemandCenter(),
            "MIDDLE_EAST": createMiddleEastDemandCenter()
        ]
        
        // Initialize market state
        marketState = GlobalMarketState(
            timestamp: Date(),
            totalGlobalTrade: 25_000_000_000_000, // $25 trillion
            averageShippingCost: 0.05, // 5% of value
            globalInventoryLevels: 0.75, // 75% of capacity
            supplyChainStress: 0.3,
            demandPressure: 0.6,
            marketLiquidity: 0.8,
            volatilityIndex: 0.25
        )
    }
    
    private func setupDataSubscriptions() {
        // Subscribe to real-time economic data
        economicIndicatorService.$latestIndicators
            .sink { [weak self] indicators in
                self?.updateFromEconomicData(indicators)
            }
            .store(in: &cancellables)
        
        // Subscribe to real-time market data
        realTimeDataAdapter.$marketUpdates
            .sink { [weak self] updates in
                self?.applyRealTimeUpdates(updates)
            }
            .store(in: &cancellables)
    }
    
    private func calculateInterconnections() {
        // Calculate complex market interconnections using network theory
        interconnectionMatrix = MarketInterconnectionMatrix()
        
        // Energy interconnections
        interconnectionMatrix.addConnection("CRUDE_OIL", "NATURAL_GAS", strength: 0.7, type: .substitute)
        interconnectionMatrix.addConnection("CRUDE_OIL", "CONTAINER_SHIPPING", strength: 0.9, type: .input)
        interconnectionMatrix.addConnection("NATURAL_GAS", "AGRICULTURAL", strength: 0.6, type: .input)
        
        // Metal interconnections
        interconnectionMatrix.addConnection("IRON_ORE", "CONTAINER_SHIPPING", strength: 0.8, type: .complement)
        interconnectionMatrix.addConnection("RARE_EARTH", "SEMICONDUCTOR", strength: 0.95, type: .input)
        
        // Regional demand interconnections
        interconnectionMatrix.addConnection("CHINA", "IRON_ORE", strength: 0.9, type: .demand)
        interconnectionMatrix.addConnection("USA", "CRUDE_OIL", strength: 0.8, type: .demand)
        interconnectionMatrix.addConnection("EUROPE", "NATURAL_GAS", strength: 0.85, type: .demand)
        
        // Calculate network effects
        interconnectionMatrix.calculateNetworkEffects()
    }
    
    // MARK: - Simulation Control
    
    public func startSimulation(speed: Double = 1.0) {
        guard !isRunning else { return }
        
        simulationSpeed = speed
        isRunning = true
        simulationTime = Date()
        
        let interval = simulationTimeStep / simulationSpeed
        simulationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.simulationStep()
        }
    }
    
    public func stopSimulation() {
        isRunning = false
        simulationTimer?.invalidate()
        simulationTimer = nil
    }
    
    public func pauseSimulation() {
        simulationTimer?.invalidate()
        simulationTimer = nil
    }
    
    public func setSimulationSpeed(_ speed: Double) {
        simulationSpeed = max(0.1, min(10.0, speed))
        
        if isRunning {
            stopSimulation()
            startSimulation(speed: simulationSpeed)
        }
    }
    
    // MARK: - Core Simulation Step
    
    private func simulationStep() {
        simulationTime = simulationTime.addingTimeInterval(simulationTimeStep)
        
        // 1. Update external conditions
        updateExternalConditions()
        
        // 2. Process supply dynamics
        updateSupplyDynamics()
        
        // 3. Process demand dynamics
        updateDemandDynamics()
        
        // 4. Process market shocks
        processMarketShocks()
        
        // 5. Calculate price discovery
        performPriceDiscovery()
        
        // 6. Propagate interconnection effects
        propagateInterconnectionEffects()
        
        // 7. Update market state
        updateGlobalMarketState()
        
        // 8. Record historical data
        recordHistoricalData()
        
        // 9. Generate new market events
        generateMarketEvents()
        
        // 10. Publish updates
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    // MARK: - Supply Dynamics
    
    private func updateSupplyDynamics() {
        for (chainName, var supplyChain) in supplyChains {
            // Update production capacity
            supplyChain = supplyDynamicsEngine.updateProductionCapacity(
                supplyChain,
                timeStep: simulationTimeStep,
                externalFactors: getSupplyFactors(for: chainName)
            )
            
            // Update inventory levels
            supplyChain = supplyDynamicsEngine.updateInventoryLevels(
                supplyChain,
                demand: getDemandForSupplyChain(chainName),
                timeStep: simulationTimeStep
            )
            
            // Update transportation networks
            supplyChain = supplyDynamicsEngine.updateTransportationNetworks(
                supplyChain,
                shippingCosts: marketState.averageShippingCost,
                congestionLevels: getTransportationCongestion(for: chainName)
            )
            
            // Update supplier dynamics
            supplyChain = supplyDynamicsEngine.updateSupplierBehavior(
                supplyChain,
                marketConditions: getMarketConditions(for: chainName),
                timeStep: simulationTimeStep
            )
            
            supplyChains[chainName] = supplyChain
        }
    }
    
    // MARK: - Demand Dynamics
    
    private func updateDemandDynamics() {
        for (centerName, var demandCenter) in demandCenters {
            // Update consumption patterns
            demandCenter = demandDynamicsEngine.updateConsumptionPatterns(
                demandCenter,
                economicConditions: getEconomicConditions(for: centerName),
                timeStep: simulationTimeStep
            )
            
            // Update industrial demand
            demandCenter = demandDynamicsEngine.updateIndustrialDemand(
                demandCenter,
                productionLevels: getProductionLevels(for: centerName),
                timeStep: simulationTimeStep
            )
            
            // Update consumer demand
            demandCenter = demandDynamicsEngine.updateConsumerDemand(
                demandCenter,
                demographics: getDemographics(for: centerName),
                seasonality: getSeasonalFactors(for: centerName),
                timeStep: simulationTimeStep
            )
            
            // Update strategic stockpiling
            demandCenter = demandDynamicsEngine.updateStrategicStockpiling(
                demandCenter,
                geopoliticalFactors: getGeopoliticalFactors(for: centerName),
                timeStep: simulationTimeStep
            )
            
            demandCenters[centerName] = demandCenter
        }
    }
    
    // MARK: - Price Discovery
    
    private func performPriceDiscovery() {
        let allCommodities = getAllCommodities()
        
        for commodity in allCommodities {
            let totalSupply = calculateTotalSupply(for: commodity)
            let totalDemand = calculateTotalDemand(for: commodity)
            let currentPrice = getCurrentPrice(for: commodity)
            
            let newPrice = priceDiscoveryEngine.calculateEquilibriumPrice(
                commodity: commodity,
                supply: totalSupply,
                demand: totalDemand,
                currentPrice: currentPrice,
                elasticity: getElasticity(for: commodity),
                marketLiquidity: getMarketLiquidity(for: commodity),
                timeStep: simulationTimeStep
            )
            
            updatePrice(for: commodity, price: newPrice)
        }
    }
    
    // MARK: - Shock Propagation
    
    private func processMarketShocks() {
        // Remove expired shocks
        marketShocks.removeAll { shock in
            simulationTime.timeIntervalSince(shock.startTime) > shock.duration
        }
        
        // Apply active shocks
        for shock in marketShocks {
            let intensity = shockPropagationEngine.calculateShockIntensity(
                shock: shock,
                currentTime: simulationTime
            )
            
            applyShockToMarkets(shock: shock, intensity: intensity)
        }
    }
    
    private func propagateInterconnectionEffects() {
        // Calculate network effects using graph algorithms
        let networkEffects = interconnectionMatrix.calculatePropagationEffects(
            currentState: marketState,
            supplyChains: supplyChains,
            demandCenters: demandCenters
        )
        
        // Apply effects to supply chains
        for (chainName, effect) in networkEffects.supplyEffects {
            if var supplyChain = supplyChains[chainName] {
                supplyChain.productionCapacity *= effect.capacityMultiplier
                supplyChain.operatingCosts *= effect.costMultiplier
                supplyChain.efficiency *= effect.efficiencyMultiplier
                supplyChains[chainName] = supplyChain
            }
        }
        
        // Apply effects to demand centers
        for (centerName, effect) in networkEffects.demandEffects {
            if var demandCenter = demandCenters[centerName] {
                demandCenter.consumptionRate *= effect.demandMultiplier
                demandCenter.priceElasticity *= effect.elasticityMultiplier
                demandCenters[centerName] = demandCenter
            }
        }
    }
    
    // MARK: - Market State Updates
    
    private func updateGlobalMarketState() {
        // Calculate aggregate metrics
        let totalSupply = supplyChains.values.map { $0.totalCapacity }.reduce(0, +)
        let totalDemand = demandCenters.values.map { $0.totalDemand }.reduce(0, +)
        
        marketState.supplyChainStress = calculateSupplyChainStress()
        marketState.demandPressure = calculateDemandPressure()
        marketState.marketLiquidity = calculateMarketLiquidity()
        marketState.volatilityIndex = calculateVolatilityIndex()
        marketState.globalInventoryLevels = calculateGlobalInventoryLevels()
        marketState.averageShippingCost = calculateAverageShippingCost()
        marketState.timestamp = simulationTime
        
        // Update interconnection strengths based on market conditions
        updateInterconnectionStrengths()
    }
    
    // MARK: - External Data Integration
    
    private func updateFromEconomicData(_ indicators: EconomicIndicators) {
        // Update demand centers based on economic indicators
        for (centerName, var center) in demandCenters {
            center.economicGrowthRate = indicators.gdpGrowthRates[centerName] ?? 0.03
            center.inflationRate = indicators.inflationRates[centerName] ?? 0.025
            center.interestRate = indicators.interestRates[centerName] ?? 0.05
            center.unemploymentRate = indicators.unemploymentRates[centerName] ?? 0.04
            center.consumerConfidence = indicators.consumerConfidence[centerName] ?? 0.7
            
            demandCenters[centerName] = center
        }
        
        // Update supply chains based on input costs and regulations
        for (chainName, var chain) in supplyChains {
            chain.energyCosts = indicators.energyPrices[chainName] ?? 1.0
            chain.laborCosts = indicators.laborCosts[chainName] ?? 1.0
            chain.regulatoryCompliance = indicators.regulatoryIndex[chainName] ?? 0.8
            
            supplyChains[chainName] = chain
        }
    }
    
    private func applyRealTimeUpdates(_ updates: [MarketUpdate]) {
        for update in updates {
            switch update.type {
            case .priceUpdate:
                applyPriceUpdate(update)
            case .supplyShock:
                applySupplyShock(update)
            case .demandSurge:
                applyDemandSurge(update)
            case .transportationDisruption:
                applyTransportationDisruption(update)
            case .regulatoryChange:
                applyRegulatoryChange(update)
            }
        }
    }
    
    // MARK: - Market Event Generation
    
    private func generateMarketEvents() {
        // Generate random market events based on current conditions
        let eventProbability = calculateEventProbability()
        
        if Double.random(in: 0...1) < eventProbability {
            let event = generateRandomMarketEvent()
            injectMarketShock(event)
        }
        
        // Generate seasonal events
        generateSeasonalEvents()
        
        // Generate technology advancement events
        generateTechnologyEvents()
        
        // Generate geopolitical events
        generateGeopoliticalEvents()
    }
    
    private func generateRandomMarketEvent() -> MarketShock {
        let shockTypes: [ShockType] = [.supply, .demand, .transportation, .regulatory, .technology, .natural, .geopolitical]
        let commodities = getAllCommodities()
        let regions = Array(demandCenters.keys)
        
        let shockType = shockTypes.randomElement()!
        let commodity = commodities.randomElement()!
        let region = regions.randomElement()!
        let magnitude = Double.random(in: 0.05...0.5)
        let duration = TimeInterval.random(in: 3600...86400*30) // 1 hour to 30 days
        
        return MarketShock(
            id: UUID(),
            type: shockType,
            commodity: commodity,
            region: region,
            magnitude: magnitude,
            duration: duration,
            startTime: simulationTime,
            description: generateShockDescription(type: shockType, commodity: commodity, region: region),
            probability: calculateShockProbability(type: shockType)
        )
    }
    
    // MARK: - Public Interface
    
    /// Inject a custom market shock
    public func injectMarketShock(_ shock: MarketShock) {
        marketShocks.append(shock)
    }
    
    /// Get current supply chain status
    public func getSupplyChainStatus(_ chainName: String) -> SupplyChainStatus? {
        guard let chain = supplyChains[chainName] else { return nil }
        
        return SupplyChainStatus(
            name: chainName,
            healthScore: calculateSupplyChainHealth(chain),
            bottlenecks: identifyBottlenecks(chain),
            efficiency: chain.efficiency,
            capacity: chain.totalCapacity,
            utilization: chain.currentUtilization,
            averageCost: chain.averageCost,
            riskLevel: calculateRiskLevel(chain)
        )
    }
    
    /// Get current demand center analysis
    public func getDemandCenterAnalysis(_ centerName: String) -> DemandCenterAnalysis? {
        guard let center = demandCenters[centerName] else { return nil }
        
        return DemandCenterAnalysis(
            name: centerName,
            totalDemand: center.totalDemand,
            growthRate: center.demandGrowthRate,
            elasticity: center.priceElasticity,
            seasonality: center.seasonalFactors,
            economicHealth: calculateEconomicHealth(center),
            purchasingPower: center.purchasingPower,
            forecast: forecastDemand(center)
        )
    }
    
    /// Get market interconnection analysis
    public func getMarketInterconnectionAnalysis() -> InterconnectionAnalysis {
        return InterconnectionAnalysis(
            networkDensity: interconnectionMatrix.calculateNetworkDensity(),
            systemicRisk: calculateSystemicRisk(),
            propagationSpeed: calculatePropagationSpeed(),
            criticalNodes: identifyCriticalNodes(),
            clusterAnalysis: performClusterAnalysis(),
            resilience: calculateSystemResilience()
        )
    }
    
    /// Forecast market conditions
    public func forecastMarketConditions(timeHorizon: TimeInterval) -> MarketForecast {
        let steps = Int(timeHorizon / simulationTimeStep)
        
        return MarketForecast(
            timeHorizon: timeHorizon,
            priceForecasts: forecastPrices(steps: steps),
            supplyForecasts: forecastSupply(steps: steps),
            demandForecasts: forecastDemand(steps: steps),
            riskAssessment: assessForecastRisk(steps: steps),
            confidence: calculateForecastConfidence(steps: steps),
            scenarios: generateScenarios(steps: steps)
        )
    }
    
    /// Run scenario analysis
    public func runScenarioAnalysis(_ scenario: MarketScenario) -> ScenarioResult {
        // Save current state
        let savedState = saveCurrentState()
        
        // Apply scenario conditions
        applyScenario(scenario)
        
        // Run simulation for scenario duration
        let results = runSimulationForDuration(scenario.duration)
        
        // Restore original state
        restoreState(savedState)
        
        return ScenarioResult(
            scenario: scenario,
            results: results,
            impactAnalysis: analyzeScenarioImpact(results),
            riskMetrics: calculateScenarioRisk(results),
            mitigationStrategies: generateMitigationStrategies(results)
        )
    }
    
    // MARK: - Helper Methods
    
    private func getAllCommodities() -> [String] {
        var commodities = Set<String>()
        
        for chain in supplyChains.values {
            commodities.formUnion(chain.commodityTypes)
        }
        
        for center in demandCenters.values {
            commodities.formUnion(center.commodityDemands.keys)
        }
        
        return Array(commodities)
    }
    
    private func calculateTotalSupply(for commodity: String) -> Double {
        return supplyChains.values
            .compactMap { $0.commodityOutputs[commodity] }
            .reduce(0, +)
    }
    
    private func calculateTotalDemand(for commodity: String) -> Double {
        return demandCenters.values
            .compactMap { $0.commodityDemands[commodity] }
            .reduce(0, +)
    }
    
    private func getCurrentPrice(for commodity: String) -> Double {
        // Implement price lookup from market state
        return marketState.commodityPrices[commodity] ?? 100.0
    }
    
    private func updatePrice(for commodity: String, price: Double) {
        marketState.commodityPrices[commodity] = price
    }
    
    private func getElasticity(for commodity: String) -> Double {
        // Calculate weighted average elasticity across demand centers
        let elasticities = demandCenters.values.compactMap { center in
            center.commodityElasticities[commodity]
        }
        
        return elasticities.isEmpty ? -0.2 : elasticities.reduce(0, +) / Double(elasticities.count)
    }
    
    private func getMarketLiquidity(for commodity: String) -> Double {
        // Calculate market liquidity based on trading volume and market makers
        return 0.8 // Placeholder
    }
    
    private func calculateSupplyChainStress() -> Double {
        let stressLevels = supplyChains.values.map { chain in
            1.0 - chain.efficiency + chain.congestionLevel + chain.riskLevel
        }
        
        return stressLevels.reduce(0, +) / Double(stressLevels.count)
    }
    
    private func calculateDemandPressure() -> Double {
        let pressureLevels = demandCenters.values.map { center in
            center.demandGrowthRate + (1.0 - center.inventoryLevels)
        }
        
        return pressureLevels.reduce(0, +) / Double(pressureLevels.count)
    }
    
    private func calculateMarketLiquidity() -> Double {
        // Aggregate liquidity across all markets
        return 0.8 // Placeholder
    }
    
    private func calculateVolatilityIndex() -> Double {
        let priceChanges = marketState.commodityPrices.values.map { price in
            // Calculate recent price volatility
            return 0.1 // Placeholder
        }
        
        return priceChanges.reduce(0, +) / Double(priceChanges.count)
    }
    
    private func calculateGlobalInventoryLevels() -> Double {
        let inventoryLevels = supplyChains.values.map { $0.inventoryLevel }
        return inventoryLevels.reduce(0, +) / Double(inventoryLevels.count)
    }
    
    private func calculateAverageShippingCost() -> Double {
        let shippingCosts = supplyChains.values.map { $0.transportationCosts }
        return shippingCosts.reduce(0, +) / Double(shippingCosts.count)
    }
    
    private func recordHistoricalData() {
        // Record current state in historical database
        // Implementation would store data for analysis and replay
    }
    
    // MARK: - State Management
    
    private func saveCurrentState() -> SimulationState {
        return SimulationState(
            marketState: marketState,
            supplyChains: supplyChains,
            demandCenters: demandCenters,
            marketShocks: marketShocks,
            simulationTime: simulationTime
        )
    }
    
    private func restoreState(_ state: SimulationState) {
        marketState = state.marketState
        supplyChains = state.supplyChains
        demandCenters = state.demandCenters
        marketShocks = state.marketShocks
        simulationTime = state.simulationTime
    }
    
    private func applyScenario(_ scenario: MarketScenario) {
        // Apply scenario-specific changes to market conditions
        for change in scenario.changes {
            switch change.type {
            case .supplyCapacityChange:
                applySupplyCapacityChange(change)
            case .demandShift:
                applyDemandShift(change)
            case .regulatoryChange:
                applyRegulatoryChange(change)
            case .technologyAdoption:
                applyTechnologyAdoption(change)
            }
        }
    }
    
    private func runSimulationForDuration(_ duration: TimeInterval) -> SimulationResults {
        let endTime = simulationTime.addingTimeInterval(duration)
        var results = SimulationResults()
        
        while simulationTime < endTime {
            simulationStep()
            results.recordStep(marketState, supplyChains, demandCenters)
        }
        
        return results
    }
}

// MARK: - Supply Chain Creation Methods

extension DynamicMarketSimulator {
    private func createCrudeOilSupplyChain() -> SupplyChain {
        SupplyChain(
            name: "Crude Oil",
            commodityTypes: ["WTI_CRUDE", "BRENT_CRUDE", "HEAVY_CRUDE"],
            productionNodes: [
                ProductionNode(name: "Permian Basin", capacity: 5_000_000, efficiency: 0.85, location: "USA"),
                ProductionNode(name: "Ghawar Field", capacity: 3_500_000, efficiency: 0.90, location: "Saudi Arabia"),
                ProductionNode(name: "Yamburg Field", capacity: 2_000_000, efficiency: 0.80, location: "Russia")
            ],
            transportationNetwork: TransportationNetwork(
                routes: [
                    TransportRoute(origin: "USA", destination: "Global", mode: .pipeline, capacity: 10_000_000, cost: 5.0),
                    TransportRoute(origin: "Saudi Arabia", destination: "Global", mode: .tanker, capacity: 15_000_000, cost: 8.0),
                    TransportRoute(origin: "Russia", destination: "Europe", mode: .pipeline, capacity: 8_000_000, cost: 6.0)
                ]
            ),
            storageCapacity: 1_000_000_000,
            currentUtilization: 0.75,
            efficiency: 0.85,
            inventoryLevel: 0.7
        )
    }
    
    private func createNaturalGasSupplyChain() -> SupplyChain {
        SupplyChain(
            name: "Natural Gas",
            commodityTypes: ["HENRY_HUB", "TTF", "JKM"],
            productionNodes: [
                ProductionNode(name: "Marcellus Shale", capacity: 30_000_000_000, efficiency: 0.88, location: "USA"),
                ProductionNode(name: "North Field", capacity: 25_000_000_000, efficiency: 0.92, location: "Qatar"),
                ProductionNode(name: "Yamal Peninsula", capacity: 20_000_000_000, efficiency: 0.85, location: "Russia")
            ],
            transportationNetwork: TransportationNetwork(
                routes: [
                    TransportRoute(origin: "USA", destination: "Global", mode: .lng, capacity: 100_000_000, cost: 12.0),
                    TransportRoute(origin: "Qatar", destination: "Asia", mode: .lng, capacity: 80_000_000, cost: 10.0),
                    TransportRoute(origin: "Russia", destination: "Europe", mode: .pipeline, capacity: 150_000_000, cost: 8.0)
                ]
            ),
            storageCapacity: 500_000_000_000,
            currentUtilization: 0.80,
            efficiency: 0.88,
            inventoryLevel: 0.65
        )
    }
    
    private func createIronOreSupplyChain() -> SupplyChain {
        SupplyChain(
            name: "Iron Ore",
            commodityTypes: ["IRON_ORE_62", "IRON_ORE_65"],
            productionNodes: [
                ProductionNode(name: "Pilbara Region", capacity: 800_000_000, efficiency: 0.92, location: "Australia"),
                ProductionNode(name: "Carajás Mine", capacity: 400_000_000, efficiency: 0.88, location: "Brazil"),
                ProductionNode(name: "Labrador Trough", capacity: 200_000_000, efficiency: 0.85, location: "Canada")
            ],
            transportationNetwork: TransportationNetwork(
                routes: [
                    TransportRoute(origin: "Australia", destination: "China", mode: .bulkCarrier, capacity: 600_000_000, cost: 15.0),
                    TransportRoute(origin: "Brazil", destination: "Global", mode: .bulkCarrier, capacity: 300_000_000, cost: 18.0),
                    TransportRoute(origin: "Canada", destination: "Global", mode: .bulkCarrier, capacity: 150_000_000, cost: 20.0)
                ]
            ),
            storageCapacity: 100_000_000,
            currentUtilization: 0.85,
            efficiency: 0.90,
            inventoryLevel: 0.75
        )
    }
    
    private func createAgriculturalSupplyChain() -> SupplyChain {
        SupplyChain(
            name: "Agricultural Products",
            commodityTypes: ["WHEAT", "CORN", "SOYBEANS", "RICE"],
            productionNodes: [
                ProductionNode(name: "US Midwest", capacity: 400_000_000, efficiency: 0.85, location: "USA"),
                ProductionNode(name: "Pampas", capacity: 150_000_000, efficiency: 0.82, location: "Argentina"),
                ProductionNode(name: "Black Sea", capacity: 120_000_000, efficiency: 0.80, location: "Ukraine")
            ],
            transportationNetwork: TransportationNetwork(
                routes: [
                    TransportRoute(origin: "USA", destination: "Global", mode: .bulkCarrier, capacity: 300_000_000, cost: 25.0),
                    TransportRoute(origin: "Argentina", destination: "Global", mode: .bulkCarrier, capacity: 100_000_000, cost: 30.0),
                    TransportRoute(origin: "Ukraine", destination: "Global", mode: .bulkCarrier, capacity: 80_000_000, cost: 28.0)
                ]
            ),
            storageCapacity: 200_000_000,
            currentUtilization: 0.70,
            efficiency: 0.82,
            inventoryLevel: 0.60
        )
    }
    
    private func createContainerShippingSupplyChain() -> SupplyChain {
        SupplyChain(
            name: "Container Shipping",
            commodityTypes: ["CONTAINER_RATES"],
            productionNodes: [
                ProductionNode(name: "Global Fleet", capacity: 25_000_000, efficiency: 0.75, location: "Global")
            ],
            transportationNetwork: TransportationNetwork(
                routes: [
                    TransportRoute(origin: "Asia", destination: "Europe", mode: .container, capacity: 8_000_000, cost: 2500.0),
                    TransportRoute(origin: "Asia", destination: "USA", mode: .container, capacity: 12_000_000, cost: 2800.0),
                    TransportRoute(origin: "Europe", destination: "USA", mode: .container, capacity: 3_000_000, cost: 1800.0)
                ]
            ),
            storageCapacity: 0, // No storage for shipping services
            currentUtilization: 0.85,
            efficiency: 0.75,
            inventoryLevel: 0.0
        )
    }
    
    private func createSemiconductorSupplyChain() -> SupplyChain {
        SupplyChain(
            name: "Semiconductors",
            commodityTypes: ["SILICON_WAFERS", "CHIPS", "PROCESSORS"],
            productionNodes: [
                ProductionNode(name: "Taiwan Foundries", capacity: 50_000_000, efficiency: 0.95, location: "Taiwan"),
                ProductionNode(name: "South Korea Fabs", capacity: 30_000_000, efficiency: 0.93, location: "South Korea"),
                ProductionNode(name: "US Facilities", capacity: 20_000_000, efficiency: 0.90, location: "USA")
            ],
            transportationNetwork: TransportationNetwork(
                routes: [
                    TransportRoute(origin: "Taiwan", destination: "Global", mode: .air, capacity: 40_000_000, cost: 50.0),
                    TransportRoute(origin: "South Korea", destination: "Global", mode: .air, capacity: 25_000_000, cost: 45.0),
                    TransportRoute(origin: "USA", destination: "Global", mode: .air, capacity: 15_000_000, cost: 40.0)
                ]
            ),
            storageCapacity: 10_000_000,
            currentUtilization: 0.90,
            efficiency: 0.93,
            inventoryLevel: 0.40
        )
    }
    
    private func createRareEarthSupplyChain() -> SupplyChain {
        SupplyChain(
            name: "Rare Earth Elements",
            commodityTypes: ["NEODYMIUM", "LITHIUM", "COBALT", "REE"],
            productionNodes: [
                ProductionNode(name: "Bayan Obo", capacity: 100_000, efficiency: 0.85, location: "China"),
                ProductionNode(name: "Mountain Pass", capacity: 25_000, efficiency: 0.80, location: "USA"),
                ProductionNode(name: "Mount Weld", capacity: 15_000, efficiency: 0.82, location: "Australia")
            ],
            transportationNetwork: TransportationNetwork(
                routes: [
                    TransportRoute(origin: "China", destination: "Global", mode: .container, capacity: 80_000, cost: 200.0),
                    TransportRoute(origin: "USA", destination: "Global", mode: .container, capacity: 20_000, cost: 150.0),
                    TransportRoute(origin: "Australia", destination: "Global", mode: .container, capacity: 12_000, cost: 180.0)
                ]
            ),
            storageCapacity: 50_000,
            currentUtilization: 0.95,
            efficiency: 0.84,
            inventoryLevel: 0.30
        )
    }
}

// MARK: - Demand Center Creation Methods

extension DynamicMarketSimulator {
    private func createChinaDemandCenter() -> DemandCenter {
        DemandCenter(
            name: "China",
            population: 1_400_000_000,
            gdpPerCapita: 12_000,
            economicGrowthRate: 0.055,
            inflationRate: 0.02,
            consumptionPatterns: [
                "IRON_ORE": 1_500_000_000,
                "CRUDE_OIL": 500_000_000,
                "NATURAL_GAS": 350_000_000_000,
                "WHEAT": 120_000_000,
                "SOYBEANS": 95_000_000
            ],
            industrialDemand: [
                "STEEL": 1_000_000_000,
                "ALUMINUM": 35_000_000,
                "COPPER": 12_000_000,
                "SEMICONDUCTORS": 300_000_000_000
            ],
            seasonalFactors: [
                "NATURAL_GAS": [1: 1.4, 2: 1.3, 3: 1.1, 4: 0.9, 5: 0.8, 6: 0.7, 7: 0.7, 8: 0.8, 9: 0.9, 10: 1.1, 11: 1.3, 12: 1.4],
                "AGRICULTURAL": [1: 0.8, 2: 0.9, 3: 1.1, 4: 1.2, 5: 1.1, 6: 1.0, 7: 0.9, 8: 0.8, 9: 1.0, 10: 1.2, 11: 1.1, 12: 0.9]
            ],
            priceElasticity: -0.3,
            incomeElasticity: 1.2
        )
    }
    
    private func createUSADemandCenter() -> DemandCenter {
        DemandCenter(
            name: "USA",
            population: 330_000_000,
            gdpPerCapita: 65_000,
            economicGrowthRate: 0.025,
            inflationRate: 0.03,
            consumptionPatterns: [
                "CRUDE_OIL": 750_000_000,
                "NATURAL_GAS": 800_000_000_000,
                "WHEAT": 30_000_000,
                "CORN": 300_000_000,
                "SOYBEANS": 60_000_000
            ],
            industrialDemand: [
                "STEEL": 80_000_000,
                "ALUMINUM": 5_000_000,
                "COPPER": 2_000_000,
                "SEMICONDUCTORS": 200_000_000_000
            ],
            seasonalFactors: [
                "NATURAL_GAS": [1: 1.5, 2: 1.4, 3: 1.2, 4: 1.0, 5: 0.8, 6: 0.9, 7: 1.1, 8: 1.2, 9: 0.9, 10: 1.0, 11: 1.2, 12: 1.4],
                "GASOLINE": [1: 0.9, 2: 0.9, 3: 1.0, 4: 1.1, 5: 1.2, 6: 1.3, 7: 1.3, 8: 1.2, 9: 1.1, 10: 1.0, 11: 0.9, 12: 0.9]
            ],
            priceElasticity: -0.4,
            incomeElasticity: 0.8
        )
    }
    
    private func createEuropeDemandCenter() -> DemandCenter {
        DemandCenter(
            name: "Europe",
            population: 450_000_000,
            gdpPerCapita: 45_000,
            economicGrowthRate: 0.02,
            inflationRate: 0.025,
            consumptionPatterns: [
                "CRUDE_OIL": 550_000_000,
                "NATURAL_GAS": 400_000_000_000,
                "WHEAT": 140_000_000,
                "CORN": 65_000_000
            ],
            industrialDemand: [
                "STEEL": 150_000_000,
                "ALUMINUM": 8_000_000,
                "COPPER": 3_500_000,
                "SEMICONDUCTORS": 150_000_000_000
            ],
            seasonalFactors: [
                "NATURAL_GAS": [1: 1.6, 2: 1.5, 3: 1.3, 4: 1.0, 5: 0.7, 6: 0.6, 7: 0.6, 8: 0.7, 9: 0.9, 10: 1.2, 11: 1.4, 12: 1.5],
                "HEATING_OIL": [1: 1.8, 2: 1.7, 3: 1.4, 4: 1.0, 5: 0.5, 6: 0.3, 7: 0.3, 8: 0.4, 9: 0.8, 10: 1.3, 11: 1.6, 12: 1.7]
            ],
            priceElasticity: -0.35,
            incomeElasticity: 0.9
        )
    }
    
    private func createJapanDemandCenter() -> DemandCenter {
        DemandCenter(
            name: "Japan",
            population: 125_000_000,
            gdpPerCapita: 40_000,
            economicGrowthRate: 0.01,
            inflationRate: 0.01,
            consumptionPatterns: [
                "CRUDE_OIL": 150_000_000,
                "NATURAL_GAS": 100_000_000_000,
                "WHEAT": 6_000_000,
                "RICE": 8_000_000
            ],
            industrialDemand: [
                "STEEL": 60_000_000,
                "ALUMINUM": 2_000_000,
                "COPPER": 1_000_000,
                "SEMICONDUCTORS": 80_000_000_000
            ],
            seasonalFactors: [
                "NATURAL_GAS": [1: 1.4, 2: 1.3, 3: 1.1, 4: 0.9, 5: 0.8, 6: 0.8, 7: 0.9, 8: 1.0, 9: 0.9, 10: 1.0, 11: 1.2, 12: 1.3],
                "RICE": [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.2, 10: 1.3, 11: 1.2, 12: 1.0]
            ],
            priceElasticity: -0.25,
            incomeElasticity: 0.7
        )
    }
    
    private func createIndiaDemandCenter() -> DemandCenter {
        DemandCenter(
            name: "India",
            population: 1_380_000_000,
            gdpPerCapita: 2_500,
            economicGrowthRate: 0.065,
            inflationRate: 0.045,
            consumptionPatterns: [
                "CRUDE_OIL": 220_000_000,
                "NATURAL_GAS": 60_000_000_000,
                "WHEAT": 100_000_000,
                "RICE": 110_000_000
            ],
            industrialDemand: [
                "STEEL": 120_000_000,
                "ALUMINUM": 4_000_000,
                "COPPER": 800_000,
                "SEMICONDUCTORS": 50_000_000_000
            ],
            seasonalFactors: [
                "NATURAL_GAS": [1: 1.2, 2: 1.1, 3: 1.0, 4: 0.9, 5: 0.8, 6: 0.8, 7: 0.8, 8: 0.8, 9: 0.9, 10: 1.0, 11: 1.1, 12: 1.2],
                "RICE": [1: 0.8, 2: 0.9, 3: 1.0, 4: 1.2, 5: 1.1, 6: 1.0, 7: 0.9, 8: 0.8, 9: 0.9, 10: 1.3, 11: 1.2, 12: 0.9]
            ],
            priceElasticity: -0.5,
            incomeElasticity: 1.5
        )
    }
    
    private func createEmergingAsiaDemandCenter() -> DemandCenter {
        DemandCenter(
            name: "Emerging Asia",
            population: 600_000_000,
            gdpPerCapita: 8_000,
            economicGrowthRate: 0.05,
            inflationRate: 0.035,
            consumptionPatterns: [
                "CRUDE_OIL": 200_000_000,
                "NATURAL_GAS": 150_000_000_000,
                "WHEAT": 50_000_000,
                "RICE": 180_000_000
            ],
            industrialDemand: [
                "STEEL": 200_000_000,
                "ALUMINUM": 8_000_000,
                "COPPER": 3_000_000,
                "SEMICONDUCTORS": 100_000_000_000
            ],
            seasonalFactors: [
                "NATURAL_GAS": [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0],
                "RICE": [1: 0.9, 2: 0.9, 3: 1.0, 4: 1.1, 5: 1.2, 6: 1.1, 7: 1.0, 8: 0.9, 9: 1.0, 10: 1.3, 11: 1.2, 12: 1.0]
            ],
            priceElasticity: -0.4,
            incomeElasticity: 1.3
        )
    }
    
    private func createMiddleEastDemandCenter() -> DemandCenter {
        DemandCenter(
            name: "Middle East",
            population: 400_000_000,
            gdpPerCapita: 25_000,
            economicGrowthRate: 0.03,
            inflationRate: 0.04,
            consumptionPatterns: [
                "CRUDE_OIL": 300_000_000,
                "NATURAL_GAS": 200_000_000_000,
                "WHEAT": 45_000_000,
                "RICE": 15_000_000
            ],
            industrialDemand: [
                "STEEL": 50_000_000,
                "ALUMINUM": 3_000_000,
                "COPPER": 500_000,
                "SEMICONDUCTORS": 30_000_000_000
            ],
            seasonalFactors: [
                "NATURAL_GAS": [1: 1.3, 2: 1.2, 3: 1.0, 4: 0.8, 5: 0.6, 6: 0.5, 7: 0.6, 8: 0.7, 9: 0.8, 10: 1.0, 11: 1.2, 12: 1.3],
                "COOLING": [1: 0.5, 2: 0.6, 3: 0.8, 4: 1.0, 5: 1.3, 6: 1.5, 7: 1.6, 8: 1.5, 9: 1.3, 10: 1.0, 11: 0.7, 12: 0.5]
            ],
            priceElasticity: -0.2,
            incomeElasticity: 1.0
        )
    }
}