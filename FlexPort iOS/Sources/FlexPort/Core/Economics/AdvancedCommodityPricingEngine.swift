import Foundation
import Combine
import simd

/// Advanced commodity pricing engine with sophisticated supply/demand dynamics and real-world market simulation
public class AdvancedCommodityPricingEngine: ObservableObject {
    @Published public var commodities: [String: CommodityMarket] = [:]
    @Published public var marketIndicators: MarketIndicators = MarketIndicators()
    @Published public var priceForecasts: [String: PriceForecast] = [:]
    @Published public var marketEvents: [MarketEvent] = []
    
    // Economic factors
    private var globalEconomicFactors = GlobalEconomicFactors()
    private var seasonalFactors = SeasonalFactors()
    private var geopoliticalFactors = GeopoliticalFactors()
    
    // Price calculation models
    private let supplyDemandModel = SupplyDemandModel()
    private let volatilityModel = VolatilityModel()
    private let seasonalityModel = SeasonalityModel()
    private let arbitrageModel = ArbitrageModel()
    
    // Real-world data integration
    private let commodityDataService = LiveCommodityDataService()
    private let economicDataService = EconomicDataService()
    
    // Price history and analytics
    private var priceHistory: [String: [PricePoint]] = [:]
    private let maxHistoryLength = 1000
    
    private var cancellables = Set<AnyCancellable>()
    private let updateInterval: TimeInterval = 60 // Update every minute
    
    public init() {
        initializeCommodityMarkets()
        setupDataSubscriptions()
        startPriceUpdates()
    }
    
    private func initializeCommodityMarkets() {
        // Initialize major commodity markets with realistic parameters
        commodities = [
            "WTI_CRUDE": createOilMarket(),
            "BRENT_CRUDE": createBrentMarket(),
            "NATURAL_GAS": createNaturalGasMarket(),
            "IRON_ORE": createIronOreMarket(),
            "COPPER": createCopperMarket(),
            "ALUMINUM": createAluminumMarket(),
            "STEEL": createSteelMarket(),
            "COAL": createCoalMarket(),
            "GOLD": createGoldMarket(),
            "SILVER": createSilverMarket(),
            "WHEAT": createWheatMarket(),
            "CORN": createCornMarket(),
            "SOYBEANS": createSoybeansMarket(),
            "RICE": createRiceMarket(),
            "COFFEE": createCoffeeMarket(),
            "COTTON": createCottonMarket(),
            "RUBBER": createRubberMarket(),
            "PALM_OIL": createPalmOilMarket(),
            "CONTAINER_RATES": createContainerRatesMarket(),
            "BUNKER_FUEL": createBunkerFuelMarket()
        ]
        
        // Initialize price history
        for (commodity, market) in commodities {
            priceHistory[commodity] = generateHistoricalPrices(for: market)
        }
    }
    
    private func setupDataSubscriptions() {
        // Subscribe to real-world data updates
        commodityDataService.$latestPrices
            .sink { [weak self] prices in
                self?.updatePricesFromRealData(prices)
            }
            .store(in: &cancellables)
        
        economicDataService.$economicIndicators
            .sink { [weak self] indicators in
                self?.updateEconomicFactors(indicators)
            }
            .store(in: &cancellables)
    }
    
    private func startPriceUpdates() {
        Timer.publish(every: updateInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateAllPrices()
            }
            .store(in: &cancellables)
    }
    
    /// Update all commodity prices based on supply/demand dynamics and external factors
    public func updateAllPrices() {
        let currentTime = Date()
        
        for (commodityName, var market) in commodities {
            // Calculate new price based on multiple factors
            let newPrice = calculatePrice(for: market, commodity: commodityName, time: currentTime)
            
            // Update market data
            market.currentPrice = newPrice
            market.lastUpdate = currentTime
            
            // Update price history
            let pricePoint = PricePoint(date: currentTime, price: newPrice, volume: market.tradingVolume)
            addPricePoint(commodity: commodityName, point: pricePoint)
            
            // Calculate volatility and other metrics
            market.volatility = calculateVolatility(for: commodityName)
            market.momentum = calculateMomentum(for: commodityName)
            market.trend = calculateTrend(for: commodityName)
            
            commodities[commodityName] = market
        }
        
        // Update market indicators
        updateMarketIndicators()
        
        // Generate price forecasts
        updatePriceForecasts()
        
        // Check for arbitrage opportunities
        checkArbitrageOpportunities()
        
        // Generate market events
        generateMarketEvents()
    }
    
    /// Calculate price for a specific commodity using advanced modeling
    private func calculatePrice(for market: CommodityMarket, commodity: String, time: Date) -> Double {
        var basePrice = market.basePrice
        
        // 1. Supply and Demand Factor
        let supplyDemandFactor = supplyDemandModel.calculateFactor(
            supply: market.supply,
            demand: market.demand,
            elasticity: market.priceElasticity
        )
        
        // 2. Seasonal Factor
        let seasonalFactor = seasonalityModel.getSeasonalFactor(
            commodity: commodity,
            date: time,
            hemisphere: market.primaryRegion
        )
        
        // 3. Economic Factor
        let economicFactor = calculateEconomicFactor(for: market)
        
        // 4. Geopolitical Factor
        let geopoliticalFactor = calculateGeopoliticalFactor(for: market)
        
        // 5. Market Sentiment Factor
        let sentimentFactor = calculateSentimentFactor(for: commodity)
        
        // 6. Volatility and Momentum
        let technicalFactor = calculateTechnicalFactor(for: commodity)
        
        // 7. Random market noise
        let noiseFactor = generateMarketNoise(volatility: market.volatility)
        
        // Combine all factors
        let totalFactor = supplyDemandFactor * seasonalFactor * economicFactor * 
                         geopoliticalFactor * sentimentFactor * technicalFactor * noiseFactor
        
        let newPrice = basePrice * totalFactor
        
        // Apply price bounds to prevent unrealistic movements
        let maxChange = market.maxDailyChange
        let currentPrice = market.currentPrice
        let maxPrice = currentPrice * (1.0 + maxChange)
        let minPrice = currentPrice * (1.0 - maxChange)
        
        return max(minPrice, min(maxPrice, newPrice))
    }
    
    private func calculateEconomicFactor(for market: CommodityMarket) -> Double {
        var factor = 1.0
        
        // GDP growth impact
        let gdpGrowth = globalEconomicFactors.globalGDPGrowth
        factor *= (1.0 + gdpGrowth * market.gdpSensitivity)
        
        // Inflation impact
        let inflation = globalEconomicFactors.globalInflation
        factor *= (1.0 + inflation * market.inflationSensitivity)
        
        // Interest rates impact
        let interestRates = globalEconomicFactors.globalInterestRates
        factor *= (1.0 - interestRates * market.interestRateSensitivity)
        
        // Currency strength impact
        let currencyStrength = globalEconomicFactors.dollarIndex
        factor *= (1.0 + (currencyStrength - 100) / 100 * market.currencySensitivity)
        
        return factor
    }
    
    private func calculateGeopoliticalFactor(for market: CommodityMarket) -> Double {
        var factor = 1.0
        
        // Regional stability
        for region in market.productionRegions {
            let stability = geopoliticalFactors.regionalStability[region] ?? 0.8
            let weight = market.regionWeights[region] ?? 0.0
            factor *= (1.0 + (1.0 - stability) * weight * 0.2)
        }
        
        // Trade restrictions
        let restrictions = geopoliticalFactors.tradeRestrictions[market.category] ?? 0.0
        factor *= (1.0 + restrictions * 0.1)
        
        // Sanctions impact
        let sanctions = geopoliticalFactors.sanctionsImpact
        factor *= (1.0 + sanctions * market.sanctionsSensitivity)
        
        return factor
    }
    
    private func calculateSentimentFactor(for commodity: String) -> Double {
        let sentiment = marketIndicators.overallSentiment
        let commoditySpecificSentiment = getCommoditySpecificSentiment(commodity)
        
        let combinedSentiment = (sentiment + commoditySpecificSentiment) / 2.0
        
        // Convert sentiment (-1 to 1) to price factor (0.9 to 1.1)
        return 1.0 + combinedSentiment * 0.1
    }
    
    private func calculateTechnicalFactor(for commodity: String) -> Double {
        guard let history = priceHistory[commodity], history.count >= 20 else {
            return 1.0
        }
        
        let recentPrices = Array(history.suffix(20)).map { $0.price }
        
        // Moving average crossover
        let shortMA = recentPrices.suffix(5).reduce(0, +) / 5
        let longMA = recentPrices.reduce(0, +) / Double(recentPrices.count)
        let maCrossover = (shortMA / longMA - 1.0) * 0.5
        
        // RSI-like momentum
        let priceChanges = zip(recentPrices.dropFirst(), recentPrices.dropLast()).map { $1 - $0 }
        let gains = priceChanges.filter { $0 > 0 }.reduce(0, +)
        let losses = abs(priceChanges.filter { $0 < 0 }.reduce(0, +))
        let rsi = gains / (gains + losses + 0.0001) // Avoid division by zero
        let rsiEffect = (rsi - 0.5) * 0.1
        
        return 1.0 + maCrossover + rsiEffect
    }
    
    private func generateMarketNoise(volatility: Double) -> Double {
        // Generate random noise based on volatility using Box-Muller transform
        let u1 = Double.random(in: 0.001...0.999)
        let u2 = Double.random(in: 0.001...0.999)
        let z = sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)
        
        return 1.0 + z * volatility * 0.01 // Scale noise to reasonable level
    }
    
    private func calculateVolatility(for commodity: String) -> Double {
        guard let history = priceHistory[commodity], history.count >= 30 else {
            return 0.2 // Default volatility
        }
        
        let prices = Array(history.suffix(30)).map { $0.price }
        let returns = zip(prices.dropFirst(), prices.dropLast()).map { log($1 / $0) }
        
        let mean = returns.reduce(0, +) / Double(returns.count)
        let variance = returns.map { pow($0 - mean, 2) }.reduce(0, +) / Double(returns.count)
        
        return sqrt(variance * 252) // Annualized volatility
    }
    
    private func calculateMomentum(for commodity: String) -> Double {
        guard let history = priceHistory[commodity], history.count >= 20 else {
            return 0.0
        }
        
        let prices = Array(history.suffix(20)).map { $0.price }
        let currentPrice = prices.last!
        let pastPrice = prices.first!
        
        return (currentPrice - pastPrice) / pastPrice
    }
    
    private func calculateTrend(for commodity: String) -> PriceTrend {
        let momentum = calculateMomentum(for: commodity)
        
        switch momentum {
        case let x where x > 0.05: return .strongBullish
        case let x where x > 0.02: return .bullish
        case let x where x > -0.02: return .sideways
        case let x where x > -0.05: return .bearish
        default: return .strongBearish
        }
    }
    
    private func updateMarketIndicators() {
        let allPrices = commodities.values.map { $0.currentPrice / $0.basePrice - 1.0 }
        let avgChange = allPrices.reduce(0, +) / Double(allPrices.count)
        
        marketIndicators.overallTrend = avgChange > 0.02 ? .bullish : (avgChange < -0.02 ? .bearish : .neutral)
        marketIndicators.averageVolatility = commodities.values.map { $0.volatility }.reduce(0, +) / Double(commodities.count)
        marketIndicators.marketStress = calculateMarketStress()
        marketIndicators.lastUpdate = Date()
    }
    
    private func calculateMarketStress() -> Double {
        let volatilities = commodities.values.map { $0.volatility }
        let avgVolatility = volatilities.reduce(0, +) / Double(volatilities.count)
        let volatilityStd = sqrt(volatilities.map { pow($0 - avgVolatility, 2) }.reduce(0, +) / Double(volatilities.count))
        
        // Normalized stress index (0-1)
        return min(1.0, (avgVolatility + volatilityStd) / 0.5)
    }
    
    private func updatePriceForecasts() {
        for (commodity, market) in commodities {
            let forecast = generatePriceForecast(for: commodity, market: market)
            priceForecasts[commodity] = forecast
        }
    }
    
    private func generatePriceForecast(for commodity: String, market: CommodityMarket) -> PriceForecast {
        let currentPrice = market.currentPrice
        let volatility = market.volatility
        let trend = market.momentum
        
        // Simple geometric Brownian motion forecast
        var predictions: [PricePrediction] = []
        
        for days in [1, 7, 30, 90, 365] {
            let dt = Double(days) / 365.0
            let drift = trend - 0.5 * volatility * volatility
            let diffusion = volatility * sqrt(dt) * generateRandomNormal()
            
            let predictedPrice = currentPrice * exp(drift * dt + diffusion)
            let confidence = calculateForecastConfidence(days: days, volatility: volatility)
            
            predictions.append(PricePrediction(
                timeHorizon: days,
                predictedPrice: predictedPrice,
                confidence: confidence,
                upperBound: predictedPrice * (1.0 + volatility * sqrt(dt) * 2),
                lowerBound: predictedPrice * (1.0 - volatility * sqrt(dt) * 2)
            ))
        }
        
        return PriceForecast(
            commodity: commodity,
            predictions: predictions,
            methodology: "Geometric Brownian Motion with Market Factors",
            lastUpdated: Date()
        )
    }
    
    private func calculateForecastConfidence(days: Int, volatility: Double) -> Double {
        // Confidence decreases with time horizon and volatility
        let timeDecay = exp(-Double(days) / 365.0)
        let volatilityPenalty = exp(-volatility * 5.0)
        return timeDecay * volatilityPenalty
    }
    
    private func generateRandomNormal() -> Double {
        let u1 = Double.random(in: 0.001...0.999)
        let u2 = Double.random(in: 0.001...0.999)
        return sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)
    }
    
    private func checkArbitrageOpportunities() {
        let opportunities = arbitrageModel.findOpportunities(commodities: commodities)
        
        for opportunity in opportunities {
            let event = MarketEvent(
                type: .arbitrageOpportunity,
                commodity: opportunity.commodity,
                impact: .neutral,
                magnitude: opportunity.profitPotential,
                description: opportunity.description,
                timestamp: Date(),
                duration: 3600 // 1 hour
            )
            
            marketEvents.append(event)
        }
    }
    
    private func generateMarketEvents() {
        // Remove expired events
        marketEvents.removeAll { Date().timeIntervalSince($0.timestamp) > $0.duration }
        
        // Generate random market events
        if Double.random(in: 0...1) < 0.05 { // 5% chance per update
            let event = generateRandomMarketEvent()
            marketEvents.append(event)
            applyMarketEvent(event)
        }
    }
    
    private func generateRandomMarketEvent() -> MarketEvent {
        let eventTypes: [MarketEventType] = [.supplyShock, .demandSurge, .weatherEvent, .politicalEvent, .tradeDispute, .technologicalAdvancement]
        let commodityNames = Array(commodities.keys)
        let impacts: [MarketImpact] = [.positive, .negative, .neutral]
        
        let type = eventTypes.randomElement()!
        let commodity = commodityNames.randomElement()!
        let impact = impacts.randomElement()!
        let magnitude = Double.random(in: 0.05...0.3)
        
        return MarketEvent(
            type: type,
            commodity: commodity,
            impact: impact,
            magnitude: magnitude,
            description: generateEventDescription(type: type, commodity: commodity, impact: impact),
            timestamp: Date(),
            duration: TimeInterval.random(in: 3600...86400) // 1-24 hours
        )
    }
    
    private func generateEventDescription(type: MarketEventType, commodity: String, impact: MarketImpact) -> String {
        switch (type, impact) {
        case (.supplyShock, .negative):
            return "Supply disruption in \(commodity) market due to production facility shutdown"
        case (.demandSurge, .positive):
            return "Unexpected demand surge for \(commodity) from emerging markets"
        case (.weatherEvent, .negative):
            return "Adverse weather conditions affecting \(commodity) production regions"
        case (.politicalEvent, .negative):
            return "Political instability in key \(commodity) producing region"
        case (.tradeDispute, .negative):
            return "Trade restrictions imposed on \(commodity) imports"
        case (.technologicalAdvancement, .positive):
            return "New technology reduces \(commodity) production costs"
        default:
            return "Market event affecting \(commodity) prices"
        }
    }
    
    private func applyMarketEvent(_ event: MarketEvent) {
        guard var market = commodities[event.commodity] else { return }
        
        let multiplier = event.impact == .positive ? (1.0 + event.magnitude) : (1.0 - event.magnitude)
        
        switch event.type {
        case .supplyShock:
            market.supply *= event.impact == .negative ? (1.0 - event.magnitude) : (1.0 + event.magnitude)
        case .demandSurge:
            market.demand *= multiplier
        case .weatherEvent, .politicalEvent, .tradeDispute:
            market.currentPrice *= multiplier
        case .technologicalAdvancement:
            market.productionCost *= (1.0 - event.magnitude)
        case .arbitrageOpportunity:
            break // Already handled in arbitrage check
        }
        
        commodities[event.commodity] = market
    }
    
    // MARK: - Real-world Data Integration
    
    private func updatePricesFromRealData(_ prices: [String: Double]) {
        for (commodity, realPrice) in prices {
            guard var market = commodities[commodity] else { continue }
            
            // Blend real price with simulated price for smooth transitions
            let blendFactor = 0.3 // 30% real data, 70% simulation
            market.currentPrice = market.currentPrice * (1.0 - blendFactor) + realPrice * blendFactor
            
            commodities[commodity] = market
        }
    }
    
    private func updateEconomicFactors(_ indicators: EconomicIndicators) {
        globalEconomicFactors.globalGDPGrowth = indicators.globalGDPGrowth
        globalEconomicFactors.globalInflation = indicators.globalInflation
        globalEconomicFactors.globalInterestRates = indicators.globalInterestRates
        globalEconomicFactors.dollarIndex = indicators.dollarIndex
    }
    
    // MARK: - Public Interface
    
    /// Get current price for a commodity
    public func getCurrentPrice(commodity: String) -> Double? {
        return commodities[commodity]?.currentPrice
    }
    
    /// Get price forecast for a commodity
    public func getPriceForecast(commodity: String) -> PriceForecast? {
        return priceForecasts[commodity]
    }
    
    /// Get arbitrage opportunities
    public func getArbitrageOpportunities() -> [ArbitrageOpportunity] {
        return arbitrageModel.findOpportunities(commodities: commodities)
    }
    
    /// Get market sentiment for a commodity
    public func getMarketSentiment(commodity: String) -> MarketSentiment {
        let trend = commodities[commodity]?.trend ?? .sideways
        let momentum = commodities[commodity]?.momentum ?? 0.0
        let volatility = commodities[commodity]?.volatility ?? 0.2
        
        return MarketSentiment(
            trend: trend,
            momentum: momentum,
            volatility: volatility,
            sentiment: getCommoditySpecificSentiment(commodity),
            confidence: calculateSentimentConfidence(commodity)
        )
    }
    
    /// Get optimal trading strategy for a commodity
    public func getTradingStrategy(commodity: String) -> TradingStrategy {
        guard let market = commodities[commodity],
              let forecast = priceForecasts[commodity] else {
            return TradingStrategy(action: .hold, confidence: 0.0, reasoning: "Insufficient data")
        }
        
        let currentPrice = market.currentPrice
        let shortTermForecast = forecast.predictions.first { $0.timeHorizon == 7 }?.predictedPrice ?? currentPrice
        let longTermForecast = forecast.predictions.first { $0.timeHorizon == 30 }?.predictedPrice ?? currentPrice
        
        let shortTermGain = (shortTermForecast - currentPrice) / currentPrice
        let longTermGain = (longTermForecast - currentPrice) / currentPrice
        
        var action: TradingAction
        var confidence: Double
        var reasoning: String
        
        if shortTermGain > 0.05 && longTermGain > 0.1 {
            action = .buy
            confidence = min(0.9, (shortTermGain + longTermGain) * 2)
            reasoning = "Strong upward trend expected in both short and long term"
        } else if shortTermGain < -0.05 && longTermGain < -0.1 {
            action = .sell
            confidence = min(0.9, abs(shortTermGain + longTermGain) * 2)
            reasoning = "Strong downward trend expected in both short and long term"
        } else if market.volatility > 0.4 {
            action = .hold
            confidence = 0.6
            reasoning = "High volatility suggests waiting for clearer signals"
        } else {
            action = .hold
            confidence = 0.7
            reasoning = "Mixed signals suggest maintaining current position"
        }
        
        return TradingStrategy(action: action, confidence: confidence, reasoning: reasoning)
    }
    
    // MARK: - Helper Methods
    
    private func getCommoditySpecificSentiment(_ commodity: String) -> Double {
        // Simplified sentiment calculation based on recent price movements
        guard let history = priceHistory[commodity], history.count >= 10 else {
            return 0.0
        }
        
        let recentPrices = Array(history.suffix(10)).map { $0.price }
        let priceChanges = zip(recentPrices.dropFirst(), recentPrices.dropLast()).map { ($1 - $0) / $0 }
        let avgChange = priceChanges.reduce(0, +) / Double(priceChanges.count)
        
        return max(-1.0, min(1.0, avgChange * 10)) // Scale to -1 to 1
    }
    
    private func calculateSentimentConfidence(_ commodity: String) -> Double {
        guard let market = commodities[commodity] else { return 0.0 }
        
        let volatility = market.volatility
        let momentum = abs(market.momentum)
        
        // Higher momentum and lower volatility = higher confidence
        return min(0.95, momentum * 2 + (1.0 - volatility))
    }
    
    private func addPricePoint(commodity: String, point: PricePoint) {
        if priceHistory[commodity] == nil {
            priceHistory[commodity] = []
        }
        
        priceHistory[commodity]?.append(point)
        
        // Limit history length
        if let count = priceHistory[commodity]?.count, count > maxHistoryLength {
            priceHistory[commodity]?.removeFirst(count - maxHistoryLength)
        }
    }
    
    private func generateHistoricalPrices(for market: CommodityMarket) -> [PricePoint] {
        var history: [PricePoint] = []
        var currentPrice = market.basePrice
        let volatility = market.volatility
        
        // Generate 100 days of historical data
        for i in 0..<100 {
            let date = Date().addingTimeInterval(-TimeInterval(100 - i) * 86400)
            let change = generateRandomNormal() * volatility * 0.01
            currentPrice *= (1.0 + change)
            
            let volume = Double.random(in: 0.5...2.0) * market.tradingVolume
            history.append(PricePoint(date: date, price: currentPrice, volume: volume))
        }
        
        return history
    }
}

// MARK: - Market Creation Methods

extension AdvancedCommodityPricingEngine {
    private func createOilMarket() -> CommodityMarket {
        CommodityMarket(
            name: "WTI Crude Oil",
            symbol: "WTI",
            category: .energy,
            basePrice: 75.0,
            currentPrice: 75.0,
            unit: "USD/barrel",
            supply: 100_000_000,
            demand: 99_500_000,
            volatility: 0.25,
            tradingVolume: 1_000_000,
            priceElasticity: -0.1,
            productionCost: 45.0,
            productionRegions: ["North America", "Middle East", "Russia"],
            regionWeights: ["North America": 0.4, "Middle East": 0.3, "Russia": 0.2],
            primaryRegion: "Global",
            maxDailyChange: 0.1,
            gdpSensitivity: 1.5,
            inflationSensitivity: 0.8,
            interestRateSensitivity: -0.3,
            currencySensitivity: -0.5,
            sanctionsSensitivity: 0.4
        )
    }
    
    private func createBrentMarket() -> CommodityMarket {
        CommodityMarket(
            name: "Brent Crude Oil",
            symbol: "BRENT",
            category: .energy,
            basePrice: 78.0,
            currentPrice: 78.0,
            unit: "USD/barrel",
            supply: 95_000_000,
            demand: 94_800_000,
            volatility: 0.24,
            tradingVolume: 800_000,
            priceElasticity: -0.1,
            productionCost: 50.0,
            productionRegions: ["North Sea", "Middle East", "Africa"],
            regionWeights: ["North Sea": 0.3, "Middle East": 0.4, "Africa": 0.2],
            primaryRegion: "Europe",
            maxDailyChange: 0.1,
            gdpSensitivity: 1.4,
            inflationSensitivity: 0.8,
            interestRateSensitivity: -0.3,
            currencySensitivity: -0.6,
            sanctionsSensitivity: 0.5
        )
    }
    
    private func createNaturalGasMarket() -> CommodityMarket {
        CommodityMarket(
            name: "Natural Gas",
            symbol: "NG",
            category: .energy,
            basePrice: 4.5,
            currentPrice: 4.5,
            unit: "USD/MMBtu",
            supply: 50_000_000,
            demand: 49_800_000,
            volatility: 0.35,
            tradingVolume: 500_000,
            priceElasticity: -0.15,
            productionCost: 2.5,
            productionRegions: ["North America", "Russia", "Middle East"],
            regionWeights: ["North America": 0.5, "Russia": 0.2, "Middle East": 0.2],
            primaryRegion: "North America",
            maxDailyChange: 0.15,
            gdpSensitivity: 1.2,
            inflationSensitivity: 0.6,
            interestRateSensitivity: -0.2,
            currencySensitivity: -0.4,
            sanctionsSensitivity: 0.6
        )
    }
    
    private func createIronOreMarket() -> CommodityMarket {
        CommodityMarket(
            name: "Iron Ore",
            symbol: "IO",
            category: .metals,
            basePrice: 120.0,
            currentPrice: 120.0,
            unit: "USD/metric ton",
            supply: 2_500_000_000,
            demand: 2_480_000_000,
            volatility: 0.3,
            tradingVolume: 100_000,
            priceElasticity: -0.2,
            productionCost: 60.0,
            productionRegions: ["Australia", "Brazil", "China"],
            regionWeights: ["Australia": 0.4, "Brazil": 0.3, "China": 0.2],
            primaryRegion: "Asia-Pacific",
            maxDailyChange: 0.08,
            gdpSensitivity: 2.0,
            inflationSensitivity: 0.5,
            interestRateSensitivity: -0.4,
            currencySensitivity: -0.3,
            sanctionsSensitivity: 0.2
        )
    }
    
    private func createCopperMarket() -> CommodityMarket {
        CommodityMarket(
            name: "Copper",
            symbol: "CU",
            category: .metals,
            basePrice: 8500.0,
            currentPrice: 8500.0,
            unit: "USD/metric ton",
            supply: 21_000_000,
            demand: 20_800_000,
            volatility: 0.28,
            tradingVolume: 50_000,
            priceElasticity: -0.3,
            productionCost: 5000.0,
            productionRegions: ["Chile", "Peru", "China", "DRC"],
            regionWeights: ["Chile": 0.3, "Peru": 0.12, "China": 0.08, "DRC": 0.08],
            primaryRegion: "South America",
            maxDailyChange: 0.06,
            gdpSensitivity: 1.8,
            inflationSensitivity: 0.4,
            interestRateSensitivity: -0.5,
            currencySensitivity: -0.4,
            sanctionsSensitivity: 0.3
        )
    }
    
    private func createAluminumMarket() -> CommodityMarket {
        CommodityMarket(
            name: "Aluminum",
            symbol: "AL",
            category: .metals,
            basePrice: 2200.0,
            currentPrice: 2200.0,
            unit: "USD/metric ton",
            supply: 65_000_000,
            demand: 64_500_000,
            volatility: 0.22,
            tradingVolume: 75_000,
            priceElasticity: -0.25,
            productionCost: 1600.0,
            productionRegions: ["China", "Russia", "Canada", "UAE"],
            regionWeights: ["China": 0.57, "Russia": 0.06, "Canada": 0.05, "UAE": 0.04],
            primaryRegion: "Asia",
            maxDailyChange: 0.05,
            gdpSensitivity: 1.5,
            inflationSensitivity: 0.3,
            interestRateSensitivity: -0.4,
            currencySensitivity: -0.3,
            sanctionsSensitivity: 0.4
        )
    }
    
    private func createSteelMarket() -> CommodityMarket {
        CommodityMarket(
            name: "Steel",
            symbol: "ST",
            category: .metals,
            basePrice: 600.0,
            currentPrice: 600.0,
            unit: "USD/metric ton",
            supply: 1_950_000_000,
            demand: 1_930_000_000,
            volatility: 0.2,
            tradingVolume: 200_000,
            priceElasticity: -0.15,
            productionCost: 400.0,
            productionRegions: ["China", "India", "Japan", "USA"],
            regionWeights: ["China": 0.53, "India": 0.06, "Japan": 0.05, "USA": 0.04],
            primaryRegion: "Asia",
            maxDailyChange: 0.04,
            gdpSensitivity: 2.2,
            inflationSensitivity: 0.6,
            interestRateSensitivity: -0.3,
            currencySensitivity: -0.2,
            sanctionsSensitivity: 0.3
        )
    }
    
    private func createCoalMarket() -> CommodityMarket {
        CommodityMarket(
            name: "Coal",
            symbol: "COAL",
            category: .energy,
            basePrice: 150.0,
            currentPrice: 150.0,
            unit: "USD/metric ton",
            supply: 8_000_000_000,
            demand: 7_900_000_000,
            volatility: 0.4,
            tradingVolume: 300_000,
            priceElasticity: -0.2,
            productionCost: 80.0,
            productionRegions: ["China", "India", "Indonesia", "Australia"],
            regionWeights: ["China": 0.46, "India": 0.11, "Indonesia": 0.08, "Australia": 0.07],
            primaryRegion: "Asia",
            maxDailyChange: 0.12,
            gdpSensitivity: 1.3,
            inflationSensitivity: 0.5,
            interestRateSensitivity: -0.2,
            currencySensitivity: -0.3,
            sanctionsSensitivity: 0.4
        )
    }
    
    private func createGoldMarket() -> CommodityMarket {
        CommodityMarket(
            name: "Gold",
            symbol: "XAU",
            category: .preciousMetals,
            basePrice: 2000.0,
            currentPrice: 2000.0,
            unit: "USD/troy oz",
            supply: 200_000_000,
            demand: 195_000_000,
            volatility: 0.18,
            tradingVolume: 50_000,
            priceElasticity: -0.05,
            productionCost: 1200.0,
            productionRegions: ["China", "Australia", "Russia", "USA"],
            regionWeights: ["China": 0.11, "Australia": 0.09, "Russia": 0.08, "USA": 0.06],
            primaryRegion: "Global",
            maxDailyChange: 0.03,
            gdpSensitivity: -0.5,
            inflationSensitivity: 1.2,
            interestRateSensitivity: -0.8,
            currencySensitivity: -1.0,
            sanctionsSensitivity: 0.3
        )
    }
    
    private func createSilverMarket() -> CommodityMarket {
        CommodityMarket(
            name: "Silver",
            symbol: "XAG",
            category: .preciousMetals,
            basePrice: 25.0,
            currentPrice: 25.0,
            unit: "USD/troy oz",
            supply: 1_000_000_000,
            demand: 980_000_000,
            volatility: 0.25,
            tradingVolume: 30_000,
            priceElasticity: -0.1,
            productionCost: 15.0,
            productionRegions: ["Mexico", "Peru", "China", "Poland"],
            regionWeights: ["Mexico": 0.23, "Peru": 0.13, "China": 0.11, "Poland": 0.05],
            primaryRegion: "Americas",
            maxDailyChange: 0.05,
            gdpSensitivity: 0.8,
            inflationSensitivity: 1.0,
            interestRateSensitivity: -0.6,
            currencySensitivity: -0.8,
            sanctionsSensitivity: 0.2
        )
    }
    
    private func createWheatMarket() -> CommodityMarket {
        CommodityMarket(
            name: "Wheat",
            symbol: "W",
            category: .agriculture,
            basePrice: 550.0,
            currentPrice: 550.0,
            unit: "USD/metric ton",
            supply: 780_000_000,
            demand: 760_000_000,
            volatility: 0.3,
            tradingVolume: 80_000,
            priceElasticity: -0.2,
            productionCost: 200.0,
            productionRegions: ["China", "India", "Russia", "USA"],
            regionWeights: ["China": 0.17, "India": 0.13, "Russia": 0.11, "USA": 0.07],
            primaryRegion: "Global",
            maxDailyChange: 0.08,
            gdpSensitivity: 0.8,
            inflationSensitivity: 0.6,
            interestRateSensitivity: -0.2,
            currencySensitivity: -0.4,
            sanctionsSensitivity: 0.5
        )
    }
    
    private func createCornMarket() -> CommodityMarket {
        CommodityMarket(
            name: "Corn",
            symbol: "C",
            category: .agriculture,
            basePrice: 420.0,
            currentPrice: 420.0,
            unit: "USD/metric ton",
            supply: 1_150_000_000,
            demand: 1_130_000_000,
            volatility: 0.28,
            tradingVolume: 100_000,
            priceElasticity: -0.25,
            productionCost: 150.0,
            productionRegions: ["USA", "China", "Brazil", "Argentina"],
            regionWeights: ["USA": 0.32, "China": 0.22, "Brazil": 0.11, "Argentina": 0.06],
            primaryRegion: "Americas",
            maxDailyChange: 0.07,
            gdpSensitivity: 0.9,
            inflationSensitivity: 0.5,
            interestRateSensitivity: -0.3,
            currencySensitivity: -0.3,
            sanctionsSensitivity: 0.3
        )
    }
    
    private func createSoybeansMarket() -> CommodityMarket {
        CommodityMarket(
            name: "Soybeans",
            symbol: "S",
            category: .agriculture,
            basePrice: 480.0,
            currentPrice: 480.0,
            unit: "USD/metric ton",
            supply: 370_000_000,
            demand: 360_000_000,
            volatility: 0.26,
            tradingVolume: 60_000,
            priceElasticity: -0.2,
            productionCost: 200.0,
            productionRegions: ["USA", "Brazil", "Argentina", "China"],
            regionWeights: ["USA": 0.34, "Brazil": 0.33, "Argentina": 0.12, "China": 0.06],
            primaryRegion: "Americas",
            maxDailyChange: 0.06,
            gdpSensitivity: 1.0,
            inflationSensitivity: 0.4,
            interestRateSensitivity: -0.2,
            currencySensitivity: -0.4,
            sanctionsSensitivity: 0.4
        )
    }
    
    private func createRiceMarket() -> CommodityMarket {
        CommodityMarket(
            name: "Rice",
            symbol: "RR",
            category: .agriculture,
            basePrice: 350.0,
            currentPrice: 350.0,
            unit: "USD/metric ton",
            supply: 520_000_000,
            demand: 510_000_000,
            volatility: 0.2,
            tradingVolume: 40_000,
            priceElasticity: -0.15,
            productionCost: 180.0,
            productionRegions: ["China", "India", "Indonesia", "Bangladesh"],
            regionWeights: ["China": 0.28, "India": 0.23, "Indonesia": 0.08, "Bangladesh": 0.07],
            primaryRegion: "Asia",
            maxDailyChange: 0.04,
            gdpSensitivity: 0.6,
            inflationSensitivity: 0.3,
            interestRateSensitivity: -0.1,
            currencySensitivity: -0.2,
            sanctionsSensitivity: 0.2
        )
    }
    
    private func createCoffeeMarket() -> CommodityMarket {
        CommodityMarket(
            name: "Coffee",
            symbol: "KC",
            category: .agriculture,
            basePrice: 1800.0,
            currentPrice: 1800.0,
            unit: "USD/metric ton",
            supply: 10_000_000,
            demand: 9_800_000,
            volatility: 0.35,
            tradingVolume: 20_000,
            priceElasticity: -0.3,
            productionCost: 1000.0,
            productionRegions: ["Brazil", "Vietnam", "Colombia", "Indonesia"],
            regionWeights: ["Brazil": 0.39, "Vietnam": 0.16, "Colombia": 0.08, "Indonesia": 0.07],
            primaryRegion: "South America",
            maxDailyChange: 0.1,
            gdpSensitivity: 1.2,
            inflationSensitivity: 0.4,
            interestRateSensitivity: -0.3,
            currencySensitivity: -0.5,
            sanctionsSensitivity: 0.2
        )
    }
    
    private func createCottonMarket() -> CommodityMarket {
        CommodityMarket(
            name: "Cotton",
            symbol: "CT",
            category: .agriculture,
            basePrice: 1600.0,
            currentPrice: 1600.0,
            unit: "USD/metric ton",
            supply: 26_000_000,
            demand: 25_500_000,
            volatility: 0.24,
            tradingVolume: 15_000,
            priceElasticity: -0.4,
            productionCost: 900.0,
            productionRegions: ["China", "India", "USA", "Brazil"],
            regionWeights: ["China": 0.23, "India": 0.18, "USA": 0.14, "Brazil": 0.09],
            primaryRegion: "Global",
            maxDailyChange: 0.05,
            gdpSensitivity: 1.5,
            inflationSensitivity: 0.3,
            interestRateSensitivity: -0.4,
            currencySensitivity: -0.3,
            sanctionsSensitivity: 0.3
        )
    }
    
    private func createRubberMarket() -> CommodityMarket {
        CommodityMarket(
            name: "Natural Rubber",
            symbol: "RU",
            category: .agriculture,
            basePrice: 1400.0,
            currentPrice: 1400.0,
            unit: "USD/metric ton",
            supply: 14_000_000,
            demand: 13_800_000,
            volatility: 0.3,
            tradingVolume: 25_000,
            priceElasticity: -0.3,
            productionCost: 800.0,
            productionRegions: ["Thailand", "Indonesia", "Malaysia", "Vietnam"],
            regionWeights: ["Thailand": 0.32, "Indonesia": 0.28, "Malaysia": 0.07, "Vietnam": 0.07],
            primaryRegion: "Southeast Asia",
            maxDailyChange: 0.08,
            gdpSensitivity: 1.8,
            inflationSensitivity: 0.4,
            interestRateSensitivity: -0.3,
            currencySensitivity: -0.4,
            sanctionsSensitivity: 0.2
        )
    }
    
    private func createPalmOilMarket() -> CommodityMarket {
        CommodityMarket(
            name: "Palm Oil",
            symbol: "PO",
            category: .agriculture,
            basePrice: 900.0,
            currentPrice: 900.0,
            unit: "USD/metric ton",
            supply: 75_000_000,
            demand: 74_000_000,
            volatility: 0.28,
            tradingVolume: 35_000,
            priceElasticity: -0.2,
            productionCost: 500.0,
            productionRegions: ["Indonesia", "Malaysia", "Thailand", "Colombia"],
            regionWeights: ["Indonesia": 0.58, "Malaysia": 0.26, "Thailand": 0.03, "Colombia": 0.02],
            primaryRegion: "Southeast Asia",
            maxDailyChange: 0.06,
            gdpSensitivity: 1.1,
            inflationSensitivity: 0.5,
            interestRateSensitivity: -0.2,
            currencySensitivity: -0.3,
            sanctionsSensitivity: 0.3
        )
    }
    
    private func createContainerRatesMarket() -> CommodityMarket {
        CommodityMarket(
            name: "Container Shipping Rates",
            symbol: "CSR",
            category: .shipping,
            basePrice: 2500.0,
            currentPrice: 2500.0,
            unit: "USD/TEU",
            supply: 25_000_000,
            demand: 24_500_000,
            volatility: 0.45,
            tradingVolume: 10_000,
            priceElasticity: -0.8,
            productionCost: 1200.0,
            productionRegions: ["Asia", "Europe", "Americas"],
            regionWeights: ["Asia": 0.6, "Europe": 0.2, "Americas": 0.2],
            primaryRegion: "Global",
            maxDailyChange: 0.15,
            gdpSensitivity: 2.5,
            inflationSensitivity: 0.8,
            interestRateSensitivity: -0.5,
            currencySensitivity: -0.4,
            sanctionsSensitivity: 0.6
        )
    }
    
    private func createBunkerFuelMarket() -> CommodityMarket {
        CommodityMarket(
            name: "Bunker Fuel",
            symbol: "BF",
            category: .energy,
            basePrice: 650.0,
            currentPrice: 650.0,
            unit: "USD/metric ton",
            supply: 300_000_000,
            demand: 295_000_000,
            volatility: 0.3,
            tradingVolume: 50_000,
            priceElasticity: -0.15,
            productionCost: 400.0,
            productionRegions: ["Singapore", "Rotterdam", "Fujairah", "Houston"],
            regionWeights: ["Singapore": 0.25, "Rotterdam": 0.2, "Fujairah": 0.15, "Houston": 0.15],
            primaryRegion: "Global",
            maxDailyChange: 0.08,
            gdpSensitivity: 1.8,
            inflationSensitivity: 0.7,
            interestRateSensitivity: -0.3,
            currencySensitivity: -0.5,
            sanctionsSensitivity: 0.4
        )
    }
}