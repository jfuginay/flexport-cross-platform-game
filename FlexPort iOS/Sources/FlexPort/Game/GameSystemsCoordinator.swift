import Foundation
import Combine

// MARK: - Game Systems Coordinator
class GameSystemsCoordinator: ObservableObject {
    // Core game systems
    @Published var tradeRouteSystem = TradeRouteSystem()
    @Published var assetManagementSystem = AssetManagementSystem()
    @Published var economicEventSystem = EconomicEventSystem()
    @Published var randomEventSystem = RandomEventSystem()
    @Published var tutorialSystem = TutorialSystem()
    
    // Game state
    @Published var gameState: GameState
    @Published var singularityProgress: Double = 0.0
    @Published var gameTime: Date = Date()
    @Published var gameSpeed: GameSpeed = .normal
    @Published var isPaused: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private var gameTimer: Timer?
    private let gameStartTime = Date()
    
    init(gameState: GameState = GameState()) {
        self.gameState = gameState
        setupSystemIntegrations()
        startGameLoop()
    }
    
    // MARK: - System Integration
    private func setupSystemIntegrations() {
        // Trade routes affect economic events
        tradeRouteSystem.$activeRoutes
            .sink { [weak self] routes in
                self?.handleRouteChanges(routes)
            }
            .store(in: &cancellables)
        
        // Economic events affect trade routes
        economicEventSystem.$activeEvents
            .sink { [weak self] events in
                self?.handleEconomicEvents(events)
            }
            .store(in: &cancellables)
        
        // Asset performance affects economic indicators
        assetManagementSystem.$totalAssetValue
            .sink { [weak self] value in
                self?.updateEconomicIndicators(assetValue: value)
            }
            .store(in: &cancellables)
        
        // Random events can trigger economic events
        randomEventSystem.$activeEvents
            .sink { [weak self] events in
                self?.handleRandomEvents(events)
            }
            .store(in: &cancellables)
        
        // Tutorial progress unlocks features
        tutorialSystem.$progress
            .sink { [weak self] progress in
                self?.handleTutorialProgress(progress)
            }
            .store(in: &cancellables)
        
        // Singularity progress affects all systems
        $singularityProgress
            .sink { [weak self] progress in
                self?.handleSingularityProgress(progress)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Game Loop
    private func startGameLoop() {
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, !self.isPaused else { return }
            self.updateGameLoop()
        }
    }
    
    private func updateGameLoop() {
        // Update game time based on speed
        let timeIncrement = gameSpeed.timeMultiplier
        gameTime = gameTime.addingTimeInterval(timeIncrement)
        
        // Update systems
        updateTradeRoutes()
        updateAssets()
        updateMarkets()
        updateEvents()
        updateTutorials()
        updateSingularity()
        
        // Process cross-system interactions
        processSystemInteractions()
        
        // Update game state
        syncGameState()
    }
    
    private func updateTradeRoutes() {
        // Optimize routes based on current conditions
        tradeRouteSystem.optimizeAllRoutes()
        
        // Update route performance based on economic conditions
        for route in tradeRouteSystem.activeRoutes {
            updateRoutePerformance(route)
        }
    }
    
    private func updateAssets() {
        // Process maintenance schedules
        processAssetMaintenance()
        
        // Update asset conditions
        degradeAssetConditions()
        
        // Calculate utilization and revenue
        calculateAssetPerformance()
    }
    
    private func updateMarkets() {
        // Let economic system handle its own updates
        // We just monitor for external integration needs
    }
    
    private func updateEvents() {
        // Process active events
        randomEventSystem.processActiveEvents()
        
        // Check for new event triggers based on game state
        checkEventTriggers()
    }
    
    private func updateTutorials() {
        // Check for tutorial completion conditions
        checkTutorialConditions()
        
        // Update tutorial availability based on game progress
        updateTutorialAvailability()
    }
    
    private func updateSingularity() {
        // Calculate singularity progression rate
        var progressRate = calculateBaseProgressRate()
        
        // Factors that accelerate singularity
        progressRate += calculateEconomicFactor()
        progressRate += calculateTechnologyFactor()
        progressRate += calculateEfficiencyFactor()
        
        // Update progress
        singularityProgress = min(1.0, singularityProgress + progressRate)
        
        // Trigger endgame if reached
        if singularityProgress >= 1.0 && gameState.isGameActive {
            triggerEndgame()
        }
    }
    
    // MARK: - System Interaction Handlers
    private func handleRouteChanges(_ routes: [TradeRoute]) {
        // Update market demand based on active routes
        var demandChanges: [CargoType: Double] = [:]
        
        for route in routes {
            let demandIncrease = Double(route.cargo.quantity) / 1000.0
            demandChanges[route.cargo.type, default: 0] += demandIncrease
        }
        
        // Apply demand changes to economic system
        for (cargo, change) in demandChanges {
            economicEventSystem.adjustDemand(for: cargo, change: change)
        }
    }
    
    private func handleEconomicEvents(_ events: [EconomicEvent]) {
        for event in events {
            // Disrupt trade routes based on event type
            if event.type == .naturalDisaster || event.type == .tradeWarStart {
                disruptTradeRoutes(affectedBy: event)
            }
            
            // Affect asset values
            if event.type == .marketCrash {
                depreciateAssets(by: event.severity * 0.2)
            }
            
            // Trigger random events
            if event.severity > 0.7 {
                triggerRelatedRandomEvents(from: event)
            }
        }
    }
    
    private func handleRandomEvents(_ events: [RandomEvent]) {
        for event in events {
            switch event.category {
            case .operational:
                handleOperationalEvent(event)
            case .financial:
                handleFinancialEvent(event)
            case .crisis:
                handleCrisisEvent(event)
            case .opportunity:
                handleOpportunityEvent(event)
            default:
                break
            }
        }
    }
    
    private func handleTutorialProgress(_ progress: TutorialProgress) {
        // Unlock features based on completed tutorials
        for tutorialId in progress.completedTutorials {
            unlockFeaturesForTutorial(tutorialId)
        }
        
        // Adjust difficulty based on player performance
        adjustGameDifficulty(based: progress)
    }
    
    private func handleSingularityProgress(_ progress: Double) {
        // Increase AI competition as singularity approaches
        increaseAICompetition(factor: progress)
        
        // Introduce new technologies
        if progress > 0.5 {
            enableAdvancedTechnologies()
        }
        
        // Change market dynamics
        if progress > 0.7 {
            introduceAIMarketEffects()
        }
        
        // Trigger warning events
        if progress > 0.9 {
            triggerSingularityWarnings()
        }
    }
    
    // MARK: - Helper Methods
    private func updateRoutePerformance(_ route: TradeRoute) {
        // Adjust route profitability based on current market prices
        let currentBuyPrice = economicEventSystem.getCurrentPrice(for: route.cargo.type)
        let marketConditions = economicEventSystem.marketIndicators
        
        // Routes become less profitable in volatile markets
        let volatilityImpact = economicEventSystem.volatilityIndex
        let adjustedProfit = route.estimatedProfit * (1 - volatilityImpact * 0.2)
        
        // Update route if significantly different
        if abs(adjustedProfit - route.estimatedProfit) > route.estimatedProfit * 0.1 {
            tradeRouteSystem.recalculateRoute(route)
        }
    }
    
    private func processAssetMaintenance() {
        let dueMaintenance = assetManagementSystem.maintenanceBacklog.filter {
            $0.scheduledDate <= gameTime
        }
        
        for task in dueMaintenance {
            // Auto-perform critical maintenance
            if task.priority == .critical {
                _ = assetManagementSystem.performMaintenance(task)
            }
        }
    }
    
    private func degradeAssetConditions() {
        // Natural degradation over time
        let degradationRate = gameSpeed.timeMultiplier / 86400 * 0.001 // 0.1% per day
        
        for ship in assetManagementSystem.ships {
            ship.currentCondition = max(0, ship.currentCondition - degradationRate)
        }
        
        for plane in assetManagementSystem.planes {
            plane.currentCondition = max(0, plane.currentCondition - degradationRate)
        }
    }
    
    private func calculateAssetPerformance() {
        // Calculate revenue for all assets
        var totalRevenue = 0.0
        
        // Ship revenue
        for ship in assetManagementSystem.ships {
            if let route = ship.currentRoute {
                let dailyRevenue = route.estimatedProfit / route.estimatedDuration * 86400
                totalRevenue += dailyRevenue * gameSpeed.timeMultiplier / 86400
            }
        }
        
        // Plane revenue
        for plane in assetManagementSystem.planes {
            if let route = plane.currentRoute {
                let dailyRevenue = route.estimatedProfit / route.estimatedDuration * 86400
                totalRevenue += dailyRevenue * gameSpeed.timeMultiplier / 86400
            }
        }
        
        // Warehouse revenue (storage fees)
        for warehouse in assetManagementSystem.warehouses {
            let dailyRevenue = warehouse.currentOccupancy * 1000 // $1000 per unit stored
            totalRevenue += dailyRevenue * gameSpeed.timeMultiplier / 86400
        }
        
        // Update player money
        gameState.playerAssets.money += totalRevenue
    }
    
    private func processSystemInteractions() {
        // Cross-system interactions happen here
        
        // Economic events affect asset values
        syncAssetValuesWithMarket()
        
        // Asset performance affects economic indicators
        updateMarketLiquidity()
        
        // Random events can trigger tutorials
        checkEventTriggeredTutorials()
    }
    
    private func syncGameState() {
        // Update game state with current system states
        gameState.playerAssets.money = max(0, gameState.playerAssets.money)
        gameState.turn = Int(gameTime.timeIntervalSince(gameStartTime) / 86400) // Days elapsed
        
        // Update AI competitors
        updateAICompetitors()
    }
    
    private func calculateBaseProgressRate() -> Double {
        return 0.0001 * gameSpeed.timeMultiplier // Base rate per second
    }
    
    private func calculateEconomicFactor() -> Double {
        let gdp = economicEventSystem.marketIndicators.gdpGrowth
        let tradeVolume = economicEventSystem.marketIndicators.tradeVolume
        return (gdp + tradeVolume / 1_000_000) * 0.00001
    }
    
    private func calculateTechnologyFactor() -> Double {
        let techEvents = economicEventSystem.activeEvents.filter { $0.type == .technologicalBreakthrough }
        return Double(techEvents.count) * 0.0005
    }
    
    private func calculateEfficiencyFactor() -> Double {
        let totalAssets = assetManagementSystem.ships.count + assetManagementSystem.planes.count
        let efficiency = totalAssets > 0 ? assetManagementSystem.totalAssetValue / Double(totalAssets) / 1_000_000 : 0
        return efficiency * 0.00001
    }
    
    // MARK: - Event Handlers
    private func disruptTradeRoutes(affectedBy event: EconomicEvent) {
        for route in tradeRouteSystem.activeRoutes {
            if event.affectedRegions.contains(.global) || isRouteInRegion(route, regions: event.affectedRegions) {
                // Add delays and increase costs
                let disruption = event.severity * 0.5
                // Implementation would modify route parameters
            }
        }
    }
    
    private func depreciateAssets(by factor: Double) {
        for ship in assetManagementSystem.ships {
            ship.currentCondition = max(0.1, ship.currentCondition * (1 - factor))
        }
        
        for plane in assetManagementSystem.planes {
            plane.currentCondition = max(0.1, plane.currentCondition * (1 - factor))
        }
    }
    
    private func triggerRelatedRandomEvents(from economicEvent: EconomicEvent) {
        // Major economic events can trigger operational random events
        if economicEvent.type == .marketCrash {
            randomEventSystem.triggerEvent(createFinancialCrisisEvent())
        } else if economicEvent.type == .naturalDisaster {
            randomEventSystem.triggerEvent(createSupplyChainDisruptionEvent())
        }
    }
    
    private func handleOperationalEvent(_ event: RandomEvent) {
        // Operational events often affect assets directly
        for effect in event.immediateEffects {
            if case .assetDamage(let assetId, let damage) = effect {
                applyAssetDamage(assetId: assetId, damage: damage)
            }
        }
    }
    
    private func handleFinancialEvent(_ event: RandomEvent) {
        // Financial events affect market conditions
        if event.severity == .major || event.severity == .critical {
            economicEventSystem.adjustVolatility(by: 0.1)
        }
    }
    
    private func handleCrisisEvent(_ event: RandomEvent) {
        // Crisis events often have wide-reaching effects
        increaseSingularityProgress(by: 0.01) // Crises accelerate AI adoption
    }
    
    private func handleOpportunityEvent(_ event: RandomEvent) {
        // Opportunities can unlock new features or provide benefits
        for effect in event.immediateEffects {
            if case .technologyUnlock(let tech) = effect {
                unlockTechnology(tech)
            }
        }
    }
    
    // MARK: - Game Management
    func pauseGame() {
        isPaused = true
    }
    
    func resumeGame() {
        isPaused = false
    }
    
    func setGameSpeed(_ speed: GameSpeed) {
        gameSpeed = speed
    }
    
    func resetGame() {
        gameState = GameState()
        singularityProgress = 0.0
        gameTime = Date()
        
        // Reset all systems
        tradeRouteSystem = TradeRouteSystem()
        assetManagementSystem = AssetManagementSystem()
        economicEventSystem = EconomicEventSystem()
        randomEventSystem = RandomEventSystem()
        tutorialSystem = TutorialSystem()
        
        setupSystemIntegrations()
    }
    
    private func triggerEndgame() {
        gameState.isGameActive = false
        
        // Calculate final score
        let finalScore = calculateFinalScore()
        gameState.finalScore = finalScore
        
        // Trigger endgame event
        NotificationCenter.default.post(
            name: .gameEnded,
            object: nil,
            userInfo: ["finalScore": finalScore, "singularityProgress": singularityProgress]
        )
    }
    
    private func calculateFinalScore() -> Double {
        let assetScore = assetManagementSystem.totalAssetValue / 100_000_000 * 1000
        let efficiencyScore = calculateEfficiencyScore() * 500
        let educationScore = tutorialSystem.getTutorialAnalytics().completionRate * 300
        let adaptabilityScore = randomEventSystem.getPlayerPerformanceMetrics().successRate * 200
        let timeBonus = max(0, 1000 - singularityProgress * 1000) // Bonus for delaying singularity
        
        return assetScore + efficiencyScore + educationScore + adaptabilityScore + timeBonus
    }
    
    private func calculateEfficiencyScore() -> Double {
        guard !tradeRouteSystem.activeRoutes.isEmpty else { return 0 }
        
        let profitableRoutes = tradeRouteSystem.activeRoutes.filter { $0.estimatedProfit > 0 }
        return Double(profitableRoutes.count) / Double(tradeRouteSystem.activeRoutes.count)
    }
    
    // MARK: - Helper Functions
    private func isRouteInRegion(_ route: TradeRoute, regions: [Region]) -> Bool {
        // Implementation would check if route passes through affected regions
        return regions.contains(.global) // Simplified
    }
    
    private func createFinancialCrisisEvent() -> RandomEvent {
        // Implementation would create appropriate random event
        return RandomEvent(
            id: UUID(),
            title: "Market Panic",
            description: "The economic crisis has caused panic in the markets",
            category: .financial,
            severity: .major,
            triggerDate: Date(),
            responseTimeLimit: 3600,
            expirationDate: Date().addingTimeInterval(86400),
            choices: [],
            immediateEffects: [.moneyChange(-gameState.playerAssets.money * 0.1)],
            ignoreConsequences: [.moneyChange(-gameState.playerAssets.money * 0.2)],
            expirationEffects: [],
            status: .active,
            outcome: nil
        )
    }
    
    private func createSupplyChainDisruptionEvent() -> RandomEvent {
        return RandomEvent(
            id: UUID(),
            title: "Supply Chain Breakdown",
            description: "The disaster has severely disrupted supply chains",
            category: .operational,
            severity: .critical,
            triggerDate: Date(),
            responseTimeLimit: 1800,
            expirationDate: Date().addingTimeInterval(172800),
            choices: [],
            immediateEffects: [.routeDisruption(UUID(), 86400)],
            ignoreConsequences: [.routeDisruption(UUID(), 172800)],
            expirationEffects: [],
            status: .active,
            outcome: nil
        )
    }
    
    // Additional helper methods would be implemented here...
    private func checkEventTriggers() {}
    private func checkTutorialConditions() {}
    private func updateTutorialAvailability() {}
    private func unlockFeaturesForTutorial(_ id: UUID) {}
    private func adjustGameDifficulty(based progress: TutorialProgress) {}
    private func increaseAICompetition(factor: Double) {}
    private func enableAdvancedTechnologies() {}
    private func introduceAIMarketEffects() {}
    private func triggerSingularityWarnings() {}
    private func syncAssetValuesWithMarket() {}
    private func updateMarketLiquidity() {}
    private func checkEventTriggeredTutorials() {}
    private func updateAICompetitors() {}
    private func applyAssetDamage(assetId: UUID, damage: Double) {}
    private func unlockTechnology(_ tech: Technology) {}
    private func increaseSingularityProgress(by amount: Double) {
        singularityProgress = min(1.0, singularityProgress + amount)
    }
    
    deinit {
        gameTimer?.invalidate()
    }
}

// MARK: - Supporting Types
enum GameSpeed: Double, CaseIterable {
    case paused = 0
    case slow = 0.5
    case normal = 1.0
    case fast = 2.0
    case turbo = 5.0
    
    var timeMultiplier: Double {
        return rawValue
    }
    
    var displayName: String {
        switch self {
        case .paused: return "Paused"
        case .slow: return "Slow"
        case .normal: return "Normal"
        case .fast: return "Fast"
        case .turbo: return "Turbo"
        }
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let gameEnded = Notification.Name("gameEnded")
    static let singularityReached = Notification.Name("singularityReached")
    static let systemsIntegrated = Notification.Name("systemsIntegrated")
}

// MARK: - Extensions
extension EconomicEventSystem {
    func adjustDemand(for cargo: CargoType, change: Double) {
        // Implementation would adjust market demand
    }
    
    func adjustVolatility(by amount: Double) {
        volatilityIndex = max(0, min(1.0, volatilityIndex + amount))
    }
}

extension TradeRouteSystem {
    func recalculateRoute(_ route: TradeRoute) {
        // Implementation would recalculate route with current conditions
    }
}