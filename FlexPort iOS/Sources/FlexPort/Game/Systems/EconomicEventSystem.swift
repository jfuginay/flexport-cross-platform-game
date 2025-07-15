import Foundation
import Combine

// MARK: - Economic Event System
class EconomicEventSystem: ObservableObject {
    @Published var activeEvents: [EconomicEvent] = []
    @Published var marketIndicators: MarketIndicators
    @Published var priceHistory: [CargoType: [PricePoint]] = [:]
    @Published var volatilityIndex: Double = 0.5
    
    private var cancellables = Set<AnyCancellable>()
    private let marketSimulator = MarketSimulator()
    private var eventTimer: Timer?
    
    init() {
        self.marketIndicators = MarketIndicators()
        setupMarketSimulation()
        initializePriceHistory()
    }
    
    private func setupMarketSimulation() {
        // Run market simulation every game hour
        eventTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.simulateMarketTick()
        }
    }
    
    private func initializePriceHistory() {
        for cargoType in CargoType.allCases {
            priceHistory[cargoType] = [PricePoint(date: Date(), price: getBasePrice(for: cargoType))]
        }
    }
    
    // MARK: - Market Simulation
    private func simulateMarketTick() {
        // Update market indicators
        updateMarketIndicators()
        
        // Check for new economic events
        if shouldTriggerEvent() {
            if let event = generateEconomicEvent() {
                triggerEvent(event)
            }
        }
        
        // Update prices based on supply and demand
        updateMarketPrices()
        
        // Process ongoing events
        processActiveEvents()
    }
    
    private func updateMarketIndicators() {
        // GDP Growth simulation
        let gdpChange = Double.random(in: -0.02...0.03)
        marketIndicators.gdpGrowth += gdpChange
        marketIndicators.gdpGrowth = max(-0.1, min(0.1, marketIndicators.gdpGrowth))
        
        // Inflation simulation
        let inflationChange = Double.random(in: -0.001...0.002)
        marketIndicators.inflationRate += inflationChange
        marketIndicators.inflationRate = max(0, min(0.1, marketIndicators.inflationRate))
        
        // Consumer confidence
        marketIndicators.consumerConfidence += Double.random(in: -5...5)
        marketIndicators.consumerConfidence = max(0, min(100, marketIndicators.consumerConfidence))
        
        // Trade volume
        let volumeMultiplier = 1.0 + (marketIndicators.consumerConfidence - 50) / 100
        marketIndicators.tradeVolume = marketIndicators.baseTradeVolume * volumeMultiplier
        
        // Update volatility based on market conditions
        updateVolatilityIndex()
    }
    
    private func updateVolatilityIndex() {
        var factors: [Double] = []
        
        // Economic uncertainty
        factors.append(abs(marketIndicators.gdpGrowth) * 10)
        
        // Active events impact
        let eventImpact = Double(activeEvents.count) * 0.1
        factors.append(eventImpact)
        
        // Market confidence inverse
        factors.append((100 - marketIndicators.consumerConfidence) / 100)
        
        volatilityIndex = factors.reduce(0, +) / Double(factors.count)
        volatilityIndex = max(0.1, min(1.0, volatilityIndex))
    }
    
    // MARK: - Event Generation
    private func shouldTriggerEvent() -> Bool {
        // Higher volatility increases event probability
        let eventProbability = 0.1 + (volatilityIndex * 0.2)
        return Double.random(in: 0...1) < eventProbability
    }
    
    private func generateEconomicEvent() -> EconomicEvent? {
        let eventType = selectEventType()
        
        switch eventType {
        case .marketCrash:
            return createMarketCrashEvent()
        case .commodityShortage:
            return createCommodityShortageEvent()
        case .tradeWarStart:
            return createTradeWarEvent()
        case .technologicalBreakthrough:
            return createTechBreakthroughEvent()
        case .naturalDisaster:
            return createNaturalDisasterEvent()
        case .economicBoom:
            return createEconomicBoomEvent()
        case .currencyFluctuation:
            return createCurrencyEvent()
        case .regulatoryChange:
            return createRegulatoryEvent()
        case .pandemicOutbreak:
            return createPandemicEvent()
        case .energyCrisis:
            return createEnergyCrisisEvent()
        }
    }
    
    private func selectEventType() -> EconomicEventType {
        // Weight event types based on current conditions
        var weights: [EconomicEventType: Double] = [:]
        
        // Market crash more likely with low confidence
        weights[.marketCrash] = max(0, 100 - marketIndicators.consumerConfidence) / 100
        
        // Commodity shortage based on trade volume
        weights[.commodityShortage] = marketIndicators.tradeVolume < marketIndicators.baseTradeVolume ? 0.3 : 0.1
        
        // Trade war based on international tensions
        weights[.tradeWarStart] = 0.15
        
        // Tech breakthrough constant probability
        weights[.technologicalBreakthrough] = 0.1
        
        // Natural disasters
        weights[.naturalDisaster] = 0.1
        
        // Economic boom with high confidence
        weights[.economicBoom] = marketIndicators.consumerConfidence / 100
        
        // Currency fluctuation with high volatility
        weights[.currencyFluctuation] = volatilityIndex
        
        // Regulatory changes
        weights[.regulatoryChange] = 0.1
        
        // Pandemic (rare)
        weights[.pandemicOutbreak] = 0.02
        
        // Energy crisis
        weights[.energyCrisis] = 0.08
        
        // Weighted random selection
        let totalWeight = weights.values.reduce(0, +)
        let random = Double.random(in: 0...totalWeight)
        
        var cumulative = 0.0
        for (type, weight) in weights {
            cumulative += weight
            if random <= cumulative {
                return type
            }
        }
        
        return .commodityShortage // fallback
    }
    
    // MARK: - Event Creation
    private func createMarketCrashEvent() -> EconomicEvent {
        let severity = Double.random(in: 0.3...0.7)
        
        return EconomicEvent(
            id: UUID(),
            type: .marketCrash,
            name: "Global Market Crash",
            description: "Financial markets experience severe downturn, affecting global trade",
            startDate: Date(),
            duration: TimeInterval.random(in: 7...30) * 24 * 60 * 60,
            severity: severity,
            affectedRegions: [.global],
            priceImpacts: createUniversalPriceImpact(multiplier: 1 - severity * 0.5),
            demandImpacts: createUniversalDemandImpact(multiplier: 1 - severity * 0.7),
            additionalEffects: [
                .reducedCreditAvailability(severity * 0.8),
                .increasedInsuranceCosts(severity * 0.5),
                .reducedConsumerSpending(severity * 0.6)
            ]
        )
    }
    
    private func createCommodityShortageEvent() -> EconomicEvent {
        let commodity = CargoType.allCases.randomElement()!
        let severity = Double.random(in: 0.4...0.8)
        
        return EconomicEvent(
            id: UUID(),
            type: .commodityShortage,
            name: "\(commodity.rawValue.capitalized) Shortage",
            description: "Global shortage of \(commodity.rawValue) drives prices up",
            startDate: Date(),
            duration: TimeInterval.random(in: 14...45) * 24 * 60 * 60,
            severity: severity,
            affectedRegions: [.global],
            priceImpacts: [commodity: PriceImpact(multiplier: 1 + severity * 2, volatility: severity)],
            demandImpacts: [commodity: DemandImpact(multiplier: 1 + severity * 1.5, elasticity: 0.3)],
            additionalEffects: [
                .supplyChainDisruption(severity * 0.6),
                .substitutionEffect(commodity, severity * 0.4)
            ]
        )
    }
    
    private func createTradeWarEvent() -> EconomicEvent {
        let regions = [Region.northAmerica, Region.asia, Region.europe]
        let affectedRegions = Array(regions.shuffled().prefix(2))
        
        return EconomicEvent(
            id: UUID(),
            type: .tradeWarStart,
            name: "Trade War: \(affectedRegions.map { $0.name }.joined(separator: " vs "))",
            description: "Trade tensions escalate into tariff war",
            startDate: Date(),
            duration: TimeInterval.random(in: 30...180) * 24 * 60 * 60,
            severity: Double.random(in: 0.4...0.7),
            affectedRegions: affectedRegions,
            priceImpacts: createRegionalPriceImpact(regions: affectedRegions, multiplier: 1.2),
            demandImpacts: createRegionalDemandImpact(regions: affectedRegions, multiplier: 0.8),
            additionalEffects: [
                .tariffIncrease(0.25),
                .tradeRouteDisruption(affectedRegions, 0.5),
                .diplomaticTensions(0.7)
            ]
        )
    }
    
    private func createTechBreakthroughEvent() -> EconomicEvent {
        let techType = ["Automation", "AI Logistics", "Quantum Computing", "Green Energy"].randomElement()!
        
        return EconomicEvent(
            id: UUID(),
            type: .technologicalBreakthrough,
            name: "\(techType) Breakthrough",
            description: "Major advancement in \(techType) transforms logistics industry",
            startDate: Date(),
            duration: TimeInterval.random(in: 90...365) * 24 * 60 * 60,
            severity: Double.random(in: 0.6...0.9),
            affectedRegions: [.global],
            priceImpacts: [:], // No direct price impact
            demandImpacts: [:], // No direct demand impact
            additionalEffects: [
                .efficiencyGain(0.2),
                .costReduction(0.15),
                .newMarketOpportunity(techType, 0.3),
                .skillRequirementChange(0.5)
            ]
        )
    }
    
    private func createNaturalDisasterEvent() -> EconomicEvent {
        let disasterType = ["Hurricane", "Earthquake", "Tsunami", "Wildfire", "Flood"].randomElement()!
        let region = Region.allCases.randomElement()!
        
        return EconomicEvent(
            id: UUID(),
            type: .naturalDisaster,
            name: "\(disasterType) in \(region.name)",
            description: "Major \(disasterType.lowercased()) disrupts supply chains",
            startDate: Date(),
            duration: TimeInterval.random(in: 7...30) * 24 * 60 * 60,
            severity: Double.random(in: 0.5...0.9),
            affectedRegions: [region],
            priceImpacts: createRegionalPriceImpact(regions: [region], multiplier: 1.5),
            demandImpacts: createEmergencyDemandImpact(),
            additionalEffects: [
                .infrastructureDamage(region, 0.7),
                .humanitarianCrisis(0.6),
                .insuranceClaimSurge(0.8)
            ]
        )
    }
    
    private func createEconomicBoomEvent() -> EconomicEvent {
        return EconomicEvent(
            id: UUID(),
            type: .economicBoom,
            name: "Global Economic Expansion",
            description: "Strong economic growth drives increased trade",
            startDate: Date(),
            duration: TimeInterval.random(in: 60...180) * 24 * 60 * 60,
            severity: Double.random(in: 0.4...0.7),
            affectedRegions: [.global],
            priceImpacts: createUniversalPriceImpact(multiplier: 1.1),
            demandImpacts: createUniversalDemandImpact(multiplier: 1.3),
            additionalEffects: [
                .increasedInvestment(0.5),
                .employmentGrowth(0.3),
                .consumerConfidenceBoost(0.4)
            ]
        )
    }
    
    private func createCurrencyEvent() -> EconomicEvent {
        let currency = ["USD", "EUR", "CNY", "JPY"].randomElement()!
        let direction = Bool.random() ? "Strengthens" : "Weakens"
        
        return EconomicEvent(
            id: UUID(),
            type: .currencyFluctuation,
            name: "\(currency) \(direction)",
            description: "Major currency movement affects international trade",
            startDate: Date(),
            duration: TimeInterval.random(in: 30...90) * 24 * 60 * 60,
            severity: Double.random(in: 0.3...0.6),
            affectedRegions: [.global],
            priceImpacts: createCurrencyPriceImpact(strengthening: direction == "Strengthens"),
            demandImpacts: [:],
            additionalEffects: [
                .exchangeRateVolatility(0.4),
                .importExportBalance(direction == "Strengthens" ? -0.3 : 0.3)
            ]
        )
    }
    
    private func createRegulatoryEvent() -> EconomicEvent {
        let regulationType = ["Environmental", "Safety", "Trade", "Labor"].randomElement()!
        
        return EconomicEvent(
            id: UUID(),
            type: .regulatoryChange,
            name: "New \(regulationType) Regulations",
            description: "Government implements stricter \(regulationType.lowercased()) requirements",
            startDate: Date(),
            duration: TimeInterval.random(in: 180...365) * 24 * 60 * 60,
            severity: Double.random(in: 0.3...0.6),
            affectedRegions: Array(Region.allCases.shuffled().prefix(Int.random(in: 1...3))),
            priceImpacts: createRegulatoryPriceImpact(),
            demandImpacts: [:],
            additionalEffects: [
                .complianceCosts(0.2),
                .operationalChanges(regulationType, 0.4)
            ]
        )
    }
    
    private func createPandemicEvent() -> EconomicEvent {
        return EconomicEvent(
            id: UUID(),
            type: .pandemicOutbreak,
            name: "Global Health Crisis",
            description: "Pandemic disrupts global supply chains and trade",
            startDate: Date(),
            duration: TimeInterval.random(in: 90...365) * 24 * 60 * 60,
            severity: Double.random(in: 0.7...0.9),
            affectedRegions: [.global],
            priceImpacts: createPandemicPriceImpact(),
            demandImpacts: createPandemicDemandImpact(),
            additionalEffects: [
                .borderClosures(0.8),
                .workforceReduction(0.5),
                .digitalTransformation(0.6),
                .healthcareDemandSurge(0.9)
            ]
        )
    }
    
    private func createEnergyCrisisEvent() -> EconomicEvent {
        return EconomicEvent(
            id: UUID(),
            type: .energyCrisis,
            name: "Global Energy Crisis",
            description: "Energy shortages drive up transportation costs",
            startDate: Date(),
            duration: TimeInterval.random(in: 30...120) * 24 * 60 * 60,
            severity: Double.random(in: 0.5...0.8),
            affectedRegions: [.global],
            priceImpacts: createEnergyPriceImpact(),
            demandImpacts: [:],
            additionalEffects: [
                .fuelCostIncrease(0.8),
                .transportationCapacityReduction(0.3),
                .renewableEnergyInvestment(0.5)
            ]
        )
    }
    
    // MARK: - Impact Calculations
    private func createUniversalPriceImpact(multiplier: Double) -> [CargoType: PriceImpact] {
        var impacts: [CargoType: PriceImpact] = [:]
        for cargo in CargoType.allCases {
            impacts[cargo] = PriceImpact(multiplier: multiplier, volatility: volatilityIndex * 0.5)
        }
        return impacts
    }
    
    private func createUniversalDemandImpact(multiplier: Double) -> [CargoType: DemandImpact] {
        var impacts: [CargoType: DemandImpact] = [:]
        for cargo in CargoType.allCases {
            impacts[cargo] = DemandImpact(multiplier: multiplier, elasticity: getElasticity(for: cargo))
        }
        return impacts
    }
    
    private func createRegionalPriceImpact(regions: [Region], multiplier: Double) -> [CargoType: PriceImpact] {
        var impacts: [CargoType: PriceImpact] = [:]
        for cargo in CargoType.allCases {
            // Only affect certain cargo types more in regional events
            let regionalMultiplier = regions.count == 1 ? multiplier * 0.7 : multiplier
            impacts[cargo] = PriceImpact(multiplier: regionalMultiplier, volatility: volatilityIndex * 0.3)
        }
        return impacts
    }
    
    private func createRegionalDemandImpact(regions: [Region], multiplier: Double) -> [CargoType: DemandImpact] {
        var impacts: [CargoType: DemandImpact] = [:]
        for cargo in CargoType.allCases {
            impacts[cargo] = DemandImpact(multiplier: multiplier, elasticity: getElasticity(for: cargo))
        }
        return impacts
    }
    
    private func createEmergencyDemandImpact() -> [CargoType: DemandImpact] {
        return [
            .food: DemandImpact(multiplier: 2.0, elasticity: 0.1),
            .rawMaterials: DemandImpact(multiplier: 1.5, elasticity: 0.3),
            .machinery: DemandImpact(multiplier: 1.3, elasticity: 0.5)
        ]
    }
    
    private func createCurrencyPriceImpact(strengthening: Bool) -> [CargoType: PriceImpact] {
        let multiplier = strengthening ? 0.9 : 1.1
        return createUniversalPriceImpact(multiplier: multiplier)
    }
    
    private func createRegulatoryPriceImpact() -> [CargoType: PriceImpact] {
        var impacts: [CargoType: PriceImpact] = [:]
        // Regulations typically increase costs
        for cargo in CargoType.allCases {
            impacts[cargo] = PriceImpact(multiplier: 1.05 + Double.random(in: 0...0.1), volatility: 0.1)
        }
        return impacts
    }
    
    private func createPandemicPriceImpact() -> [CargoType: PriceImpact] {
        return [
            .food: PriceImpact(multiplier: 1.3, volatility: 0.4),
            .electronics: PriceImpact(multiplier: 1.5, volatility: 0.5),
            .textiles: PriceImpact(multiplier: 0.7, volatility: 0.3),
            .chemicals: PriceImpact(multiplier: 1.2, volatility: 0.3),
            .rawMaterials: PriceImpact(multiplier: 0.9, volatility: 0.2),
            .machinery: PriceImpact(multiplier: 1.1, volatility: 0.3),
            .vehicles: PriceImpact(multiplier: 0.8, volatility: 0.4)
        ]
    }
    
    private func createPandemicDemandImpact() -> [CargoType: DemandImpact] {
        return [
            .food: DemandImpact(multiplier: 1.4, elasticity: 0.1),
            .electronics: DemandImpact(multiplier: 1.8, elasticity: 0.4),
            .textiles: DemandImpact(multiplier: 0.5, elasticity: 0.6),
            .chemicals: DemandImpact(multiplier: 1.3, elasticity: 0.3),
            .rawMaterials: DemandImpact(multiplier: 0.7, elasticity: 0.4),
            .machinery: DemandImpact(multiplier: 0.8, elasticity: 0.5),
            .vehicles: DemandImpact(multiplier: 0.4, elasticity: 0.7)
        ]
    }
    
    private func createEnergyPriceImpact() -> [CargoType: PriceImpact] {
        // Energy crisis affects all prices but especially heavy goods
        return [
            .food: PriceImpact(multiplier: 1.2, volatility: 0.3),
            .electronics: PriceImpact(multiplier: 1.15, volatility: 0.2),
            .textiles: PriceImpact(multiplier: 1.1, volatility: 0.2),
            .chemicals: PriceImpact(multiplier: 1.25, volatility: 0.4),
            .rawMaterials: PriceImpact(multiplier: 1.3, volatility: 0.4),
            .machinery: PriceImpact(multiplier: 1.35, volatility: 0.4),
            .vehicles: PriceImpact(multiplier: 1.4, volatility: 0.5)
        ]
    }
    
    // MARK: - Event Management
    func triggerEvent(_ event: EconomicEvent) {
        activeEvents.append(event)
        
        // Send notification
        NotificationCenter.default.post(
            name: .economicEventTriggered,
            object: nil,
            userInfo: ["event": event]
        )
        
        // Apply immediate effects
        applyEventEffects(event)
    }
    
    private func applyEventEffects(_ event: EconomicEvent) {
        // Apply price impacts
        for (cargo, impact) in event.priceImpacts {
            adjustPrice(for: cargo, impact: impact)
        }
        
        // Apply demand impacts
        for (cargo, impact) in event.demandImpacts {
            adjustDemand(for: cargo, impact: impact)
        }
        
        // Apply additional effects
        for effect in event.additionalEffects {
            applyAdditionalEffect(effect)
        }
    }
    
    private func processActiveEvents() {
        activeEvents = activeEvents.filter { event in
            let elapsed = Date().timeIntervalSince(event.startDate)
            if elapsed > event.duration {
                // Event has ended
                removeEventEffects(event)
                return false
            }
            return true
        }
    }
    
    private func removeEventEffects(_ event: EconomicEvent) {
        // Gradually restore normal market conditions
        // This would be more sophisticated in a full implementation
        NotificationCenter.default.post(
            name: .economicEventEnded,
            object: nil,
            userInfo: ["event": event]
        )
    }
    
    // MARK: - Price Management
    private func updateMarketPrices() {
        for cargoType in CargoType.allCases {
            let currentPrice = getCurrentPrice(for: cargoType)
            let basePrice = getBasePrice(for: cargoType)
            
            // Calculate new price based on supply/demand and volatility
            let supplyDemandFactor = calculateSupplyDemandFactor(for: cargoType)
            let volatilityFactor = (Double.random(in: -1...1) * volatilityIndex * 0.1)
            
            var newPrice = currentPrice * (1 + supplyDemandFactor + volatilityFactor)
            
            // Apply inflation
            newPrice *= (1 + marketIndicators.inflationRate / 365)
            
            // Prevent extreme price movements
            newPrice = max(basePrice * 0.1, min(basePrice * 10, newPrice))
            
            // Record price point
            if priceHistory[cargoType] == nil {
                priceHistory[cargoType] = []
            }
            priceHistory[cargoType]?.append(PricePoint(date: Date(), price: newPrice))
            
            // Keep history size manageable
            if let history = priceHistory[cargoType], history.count > 1000 {
                priceHistory[cargoType] = Array(history.suffix(500))
            }
        }
    }
    
    private func adjustPrice(for cargo: CargoType, impact: PriceImpact) {
        guard let currentPrice = priceHistory[cargo]?.last?.price else { return }
        
        let adjustedPrice = currentPrice * impact.multiplier
        let volatilityAdjustment = (Double.random(in: -1...1) * impact.volatility * 0.1) * adjustedPrice
        
        let finalPrice = adjustedPrice + volatilityAdjustment
        
        priceHistory[cargo]?.append(PricePoint(date: Date(), price: finalPrice))
    }
    
    private func adjustDemand(for cargo: CargoType, impact: DemandImpact) {
        // This would integrate with the supply/demand tracking system
        // For now, we'll adjust the market indicators
        marketIndicators.tradeVolume *= impact.multiplier
    }
    
    private func applyAdditionalEffect(_ effect: AdditionalEffect) {
        switch effect {
        case .reducedCreditAvailability(let severity):
            marketIndicators.creditAvailability *= (1 - severity)
        case .increasedInsuranceCosts(let increase):
            marketIndicators.insuranceCostMultiplier *= (1 + increase)
        case .supplyChainDisruption(let severity):
            marketIndicators.supplyChainEfficiency *= (1 - severity)
        case .efficiencyGain(let gain):
            marketIndicators.logisticsEfficiency *= (1 + gain)
        default:
            break // Handle other cases as needed
        }
    }
    
    // MARK: - Helper Methods
    private func getBasePrice(for cargo: CargoType) -> Double {
        switch cargo {
        case .electronics: return 1000
        case .textiles: return 100
        case .food: return 50
        case .rawMaterials: return 200
        case .machinery: return 5000
        case .chemicals: return 300
        case .vehicles: return 20000
        }
    }
    
    private func getElasticity(for cargo: CargoType) -> Double {
        switch cargo {
        case .food: return 0.2 // Inelastic
        case .electronics: return 0.8 // Elastic
        case .textiles: return 0.6
        case .rawMaterials: return 0.4
        case .machinery: return 0.5
        case .chemicals: return 0.3
        case .vehicles: return 0.9 // Very elastic
        }
    }
    
    private func calculateSupplyDemandFactor(for cargo: CargoType) -> Double {
        // Simplified supply/demand calculation
        // In a full implementation, this would track actual market activity
        return Double.random(in: -0.02...0.02)
    }
    
    func getCurrentPrice(for cargo: CargoType) -> Double {
        return priceHistory[cargo]?.last?.price ?? getBasePrice(for: cargo)
    }
    
    func getPriceHistory(for cargo: CargoType, days: Int = 30) -> [PricePoint] {
        guard let history = priceHistory[cargo] else { return [] }
        
        let cutoffDate = Date().addingTimeInterval(-Double(days) * 24 * 60 * 60)
        return history.filter { $0.date > cutoffDate }
    }
    
    func getMarketTrend(for cargo: CargoType) -> MarketTrend {
        let history = getPriceHistory(for: cargo, days: 7)
        guard history.count >= 2 else { return .stable }
        
        let oldPrice = history.first!.price
        let currentPrice = history.last!.price
        let change = (currentPrice - oldPrice) / oldPrice
        
        if change > 0.1 { return .bullish }
        else if change < -0.1 { return .bearish }
        else { return .stable }
    }
}

// MARK: - Market Models
struct MarketIndicators {
    var gdpGrowth: Double = 0.02
    var inflationRate: Double = 0.02
    var unemploymentRate: Double = 0.05
    var consumerConfidence: Double = 50.0
    var tradeVolume: Double = 1_000_000
    var baseTradeVolume: Double = 1_000_000
    var creditAvailability: Double = 1.0
    var insuranceCostMultiplier: Double = 1.0
    var supplyChainEfficiency: Double = 1.0
    var logisticsEfficiency: Double = 1.0
}

struct MarketSimulator {
    // Simulation logic would go here
}

// MARK: - Event Models
struct EconomicEvent: Identifiable {
    let id: UUID
    let type: EconomicEventType
    let name: String
    let description: String
    let startDate: Date
    let duration: TimeInterval
    let severity: Double // 0-1
    let affectedRegions: [Region]
    let priceImpacts: [CargoType: PriceImpact]
    let demandImpacts: [CargoType: DemandImpact]
    let additionalEffects: [AdditionalEffect]
}

enum EconomicEventType {
    case marketCrash
    case commodityShortage
    case tradeWarStart
    case tradeWarEnd
    case technologicalBreakthrough
    case naturalDisaster
    case economicBoom
    case currencyFluctuation
    case regulatoryChange
    case pandemicOutbreak
    case energyCrisis
}

struct PriceImpact {
    let multiplier: Double
    let volatility: Double
}

struct DemandImpact {
    let multiplier: Double
    let elasticity: Double
}

enum AdditionalEffect {
    case reducedCreditAvailability(Double)
    case increasedInsuranceCosts(Double)
    case reducedConsumerSpending(Double)
    case supplyChainDisruption(Double)
    case substitutionEffect(CargoType, Double)
    case tariffIncrease(Double)
    case tradeRouteDisruption([Region], Double)
    case diplomaticTensions(Double)
    case efficiencyGain(Double)
    case costReduction(Double)
    case newMarketOpportunity(String, Double)
    case skillRequirementChange(Double)
    case infrastructureDamage(Region, Double)
    case humanitarianCrisis(Double)
    case insuranceClaimSurge(Double)
    case increasedInvestment(Double)
    case employmentGrowth(Double)
    case consumerConfidenceBoost(Double)
    case exchangeRateVolatility(Double)
    case importExportBalance(Double)
    case complianceCosts(Double)
    case operationalChanges(String, Double)
    case borderClosures(Double)
    case workforceReduction(Double)
    case digitalTransformation(Double)
    case healthcareDemandSurge(Double)
    case fuelCostIncrease(Double)
    case transportationCapacityReduction(Double)
    case renewableEnergyInvestment(Double)
}

enum Region: CaseIterable {
    case northAmerica
    case southAmerica
    case europe
    case africa
    case asia
    case oceania
    case global
    
    var name: String {
        switch self {
        case .northAmerica: return "North America"
        case .southAmerica: return "South America"
        case .europe: return "Europe"
        case .africa: return "Africa"
        case .asia: return "Asia"
        case .oceania: return "Oceania"
        case .global: return "Global"
        }
    }
}

struct PricePoint {
    let date: Date
    let price: Double
}

enum MarketTrend {
    case bullish
    case bearish
    case stable
}

// MARK: - Notifications
extension Notification.Name {
    static let economicEventTriggered = Notification.Name("economicEventTriggered")
    static let economicEventEnded = Notification.Name("economicEventEnded")
    static let marketPricesUpdated = Notification.Name("marketPricesUpdated")
}