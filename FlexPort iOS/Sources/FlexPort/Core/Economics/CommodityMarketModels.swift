import Foundation

// MARK: - Core Market Models

public struct CommodityMarket {
    public let name: String
    public let symbol: String
    public let category: CommodityCategory
    public let basePrice: Double
    public var currentPrice: Double
    public let unit: String
    
    // Supply and demand
    public var supply: Double
    public var demand: Double
    public var volatility: Double
    public var tradingVolume: Double
    public var priceElasticity: Double
    
    // Production
    public var productionCost: Double
    public let productionRegions: [String]
    public let regionWeights: [String: Double]
    public let primaryRegion: String
    
    // Risk management
    public let maxDailyChange: Double
    
    // Economic sensitivities
    public let gdpSensitivity: Double
    public let inflationSensitivity: Double
    public let interestRateSensitivity: Double
    public let currencySensitivity: Double
    public let sanctionsSensitivity: Double
    
    // Calculated metrics
    public var momentum: Double = 0.0
    public var trend: PriceTrend = .sideways
    public var lastUpdate: Date = Date()
    
    public init(name: String, symbol: String, category: CommodityCategory, basePrice: Double, 
                currentPrice: Double, unit: String, supply: Double, demand: Double, 
                volatility: Double, tradingVolume: Double, priceElasticity: Double, 
                productionCost: Double, productionRegions: [String], regionWeights: [String: Double], 
                primaryRegion: String, maxDailyChange: Double, gdpSensitivity: Double, 
                inflationSensitivity: Double, interestRateSensitivity: Double, 
                currencySensitivity: Double, sanctionsSensitivity: Double) {
        self.name = name
        self.symbol = symbol
        self.category = category
        self.basePrice = basePrice
        self.currentPrice = currentPrice
        self.unit = unit
        self.supply = supply
        self.demand = demand
        self.volatility = volatility
        self.tradingVolume = tradingVolume
        self.priceElasticity = priceElasticity
        self.productionCost = productionCost
        self.productionRegions = productionRegions
        self.regionWeights = regionWeights
        self.primaryRegion = primaryRegion
        self.maxDailyChange = maxDailyChange
        self.gdpSensitivity = gdpSensitivity
        self.inflationSensitivity = inflationSensitivity
        self.interestRateSensitivity = interestRateSensitivity
        self.currencySensitivity = currencySensitivity
        self.sanctionsSensitivity = sanctionsSensitivity
    }
}

public enum CommodityCategory: String, CaseIterable {
    case energy = "Energy"
    case metals = "Metals"
    case preciousMetals = "Precious Metals"
    case agriculture = "Agriculture"
    case shipping = "Shipping"
    case livestock = "Livestock"
    case softs = "Softs"
}

public enum PriceTrend: String, CaseIterable {
    case strongBullish = "Strong Bullish"
    case bullish = "Bullish"
    case sideways = "Sideways"
    case bearish = "Bearish"
    case strongBearish = "Strong Bearish"
}

public struct PricePoint: Codable {
    public let date: Date
    public let price: Double
    public let volume: Double
    
    public init(date: Date, price: Double, volume: Double) {
        self.date = date
        self.price = price
        self.volume = volume
    }
}

// MARK: - Market Indicators

public struct MarketIndicators {
    public var overallTrend: MarketTrend = .neutral
    public var overallSentiment: Double = 0.0
    public var averageVolatility: Double = 0.2
    public var marketStress: Double = 0.3
    public var confidenceIndex: Double = 0.7
    public var liquidityIndex: Double = 0.8
    public var lastUpdate: Date = Date()
}

public enum MarketTrend: String, CaseIterable {
    case bullish = "Bullish"
    case neutral = "Neutral"
    case bearish = "Bearish"
}

// MARK: - Economic Factors

public struct GlobalEconomicFactors {
    public var globalGDPGrowth: Double = 0.03
    public var globalInflation: Double = 0.025
    public var globalInterestRates: Double = 0.05
    public var dollarIndex: Double = 103.0
    public var globalTradeVolume: Double = 1.0
    public var economicUncertainty: Double = 0.3
}

public struct SeasonalFactors {
    public var currentSeason: Season = .spring
    public var seasonalMultipliers: [String: [Season: Double]] = [:]
    public var weatherPatterns: [String: WeatherImpact] = [:]
    public var harvestSchedules: [String: HarvestPeriod] = [:]
}

public enum Season: String, CaseIterable {
    case spring = "Spring"
    case summer = "Summer"
    case autumn = "Autumn"
    case winter = "Winter"
}

public struct WeatherImpact {
    public let temperature: Double
    public let precipitation: Double
    public let extremeWeatherRisk: Double
    public let seasonality: Double
}

public struct HarvestPeriod {
    public let startMonth: Int
    public let endMonth: Int
    public let peakMonth: Int
    public let yieldExpectation: Double
}

public struct GeopoliticalFactors {
    public var regionalStability: [String: Double] = [
        "North America": 0.9,
        "Europe": 0.85,
        "Asia": 0.8,
        "Middle East": 0.6,
        "Africa": 0.7,
        "South America": 0.75
    ]
    public var tradeRestrictions: [CommodityCategory: Double] = [:]
    public var sanctionsImpact: Double = 0.1
    public var politicalRisk: Double = 0.2
}

// MARK: - Price Forecasting

public struct PriceForecast {
    public let commodity: String
    public let predictions: [PricePrediction]
    public let methodology: String
    public let confidence: Double
    public let lastUpdated: Date
    
    public init(commodity: String, predictions: [PricePrediction], methodology: String, lastUpdated: Date) {
        self.commodity = commodity
        self.predictions = predictions
        self.methodology = methodology
        self.lastUpdated = lastUpdated
        
        // Calculate overall confidence as average of prediction confidences
        self.confidence = predictions.isEmpty ? 0.0 : predictions.map { $0.confidence }.reduce(0, +) / Double(predictions.count)
    }
}

public struct PricePrediction {
    public let timeHorizon: Int // days
    public let predictedPrice: Double
    public let confidence: Double
    public let upperBound: Double
    public let lowerBound: Double
    public let methodology: String
    
    public init(timeHorizon: Int, predictedPrice: Double, confidence: Double, upperBound: Double, lowerBound: Double, methodology: String = "Advanced Statistical Model") {
        self.timeHorizon = timeHorizon
        self.predictedPrice = predictedPrice
        self.confidence = confidence
        self.upperBound = upperBound
        self.lowerBound = lowerBound
        self.methodology = methodology
    }
}

// MARK: - Market Events

public struct MarketEvent {
    public let type: MarketEventType
    public let commodity: String
    public let impact: MarketImpact
    public let magnitude: Double
    public let description: String
    public let timestamp: Date
    public let duration: TimeInterval
    public let id = UUID()
}

public enum MarketEventType: String, CaseIterable {
    case supplyShock = "Supply Shock"
    case demandSurge = "Demand Surge"
    case weatherEvent = "Weather Event"
    case politicalEvent = "Political Event"
    case tradeDispute = "Trade Dispute"
    case technologicalAdvancement = "Technological Advancement"
    case arbitrageOpportunity = "Arbitrage Opportunity"
    case marketCrash = "Market Crash"
    case regulatoryChange = "Regulatory Change"
    case economicData = "Economic Data Release"
}

public enum MarketImpact: String, CaseIterable {
    case positive = "Positive"
    case negative = "Negative"
    case neutral = "Neutral"
}

// MARK: - Trading and Analysis

public struct MarketSentiment {
    public let trend: PriceTrend
    public let momentum: Double
    public let volatility: Double
    public let sentiment: Double
    public let confidence: Double
    public let technicalIndicators: TechnicalIndicators
    
    public init(trend: PriceTrend, momentum: Double, volatility: Double, sentiment: Double, confidence: Double) {
        self.trend = trend
        self.momentum = momentum
        self.volatility = volatility
        self.sentiment = sentiment
        self.confidence = confidence
        self.technicalIndicators = TechnicalIndicators()
    }
}

public struct TechnicalIndicators {
    public var rsi: Double = 50.0
    public var macd: Double = 0.0
    public var bollingerBands: BollingerBands = BollingerBands()
    public var movingAverages: MovingAverages = MovingAverages()
    public var supportResistance: SupportResistance = SupportResistance()
}

public struct BollingerBands {
    public var upperBand: Double = 0.0
    public var middleBand: Double = 0.0
    public var lowerBand: Double = 0.0
    public var position: BandPosition = .middle
}

public enum BandPosition {
    case upper, upperMiddle, middle, lowerMiddle, lower
}

public struct MovingAverages {
    public var ma5: Double = 0.0
    public var ma10: Double = 0.0
    public var ma20: Double = 0.0
    public var ma50: Double = 0.0
    public var ma200: Double = 0.0
}

public struct SupportResistance {
    public var supportLevels: [Double] = []
    public var resistanceLevels: [Double] = []
    public var currentLevel: PriceLevel = .neutral
}

public enum PriceLevel {
    case strongSupport, support, neutral, resistance, strongResistance
}

public struct TradingStrategy {
    public let action: TradingAction
    public let confidence: Double
    public let reasoning: String
    public let riskLevel: RiskLevel
    public let timeHorizon: TimeHorizon
    public let targetPrice: Double?
    public let stopLoss: Double?
    
    public init(action: TradingAction, confidence: Double, reasoning: String, 
                riskLevel: RiskLevel = .medium, timeHorizon: TimeHorizon = .shortTerm,
                targetPrice: Double? = nil, stopLoss: Double? = nil) {
        self.action = action
        self.confidence = confidence
        self.reasoning = reasoning
        self.riskLevel = riskLevel
        self.timeHorizon = timeHorizon
        self.targetPrice = targetPrice
        self.stopLoss = stopLoss
    }
}

public enum TradingAction: String, CaseIterable {
    case buy = "Buy"
    case sell = "Sell"
    case hold = "Hold"
    case buyStrong = "Strong Buy"
    case sellStrong = "Strong Sell"
}

public enum RiskLevel: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case extreme = "Extreme"
}

public enum TimeHorizon: String, CaseIterable {
    case intraday = "Intraday"
    case shortTerm = "Short Term"
    case mediumTerm = "Medium Term"
    case longTerm = "Long Term"
}

// MARK: - Arbitrage

public struct ArbitrageOpportunity {
    public let commodity: String
    public let buyMarket: String
    public let sellMarket: String
    public let buyPrice: Double
    public let sellPrice: Double
    public let profitPotential: Double
    public let riskLevel: RiskLevel
    public let timeWindow: TimeInterval
    public let description: String
    public let confidence: Double
    
    public var profitMargin: Double {
        (sellPrice - buyPrice) / buyPrice
    }
}

// MARK: - Market Models

public class SupplyDemandModel {
    public func calculateFactor(supply: Double, demand: Double, elasticity: Double) -> Double {
        let ratio = demand / supply
        let factor = pow(ratio, abs(elasticity))
        return factor
    }
    
    public func calculateEquilibriumPrice(basePrice: Double, supply: Double, demand: Double, elasticity: Double) -> Double {
        let supplyDemandRatio = demand / supply
        let priceAdjustment = pow(supplyDemandRatio, abs(elasticity))
        return basePrice * priceAdjustment
    }
}

public class VolatilityModel {
    public func calculateHistoricalVolatility(prices: [Double], period: Int = 30) -> Double {
        guard prices.count >= period else { return 0.2 }
        
        let recentPrices = Array(prices.suffix(period))
        let returns = zip(recentPrices.dropFirst(), recentPrices.dropLast()).map { log($1 / $0) }
        
        let mean = returns.reduce(0, +) / Double(returns.count)
        let variance = returns.map { pow($0 - mean, 2) }.reduce(0, +) / Double(returns.count)
        
        return sqrt(variance * 252) // Annualized
    }
    
    public func calculateImpliedVolatility(currentPrice: Double, strikePrice: Double, timeToExpiry: Double, riskFreeRate: Double, optionPrice: Double) -> Double {
        // Simplified Black-Scholes implied volatility calculation
        // This is a placeholder - full implementation would use Newton-Raphson method
        return 0.25
    }
}

public class SeasonalityModel {
    private let seasonalPatterns: [String: [Season: Double]] = [
        "WHEAT": [.spring: 1.1, .summer: 0.9, .autumn: 1.2, .winter: 1.0],
        "CORN": [.spring: 1.0, .summer: 0.85, .autumn: 1.3, .winter: 1.05],
        "SOYBEANS": [.spring: 1.05, .summer: 0.9, .autumn: 1.25, .winter: 1.0],
        "RICE": [.spring: 1.0, .summer: 0.95, .autumn: 1.15, .winter: 1.0],
        "COFFEE": [.spring: 1.1, .summer: 1.0, .autumn: 0.95, .winter: 1.05],
        "COTTON": [.spring: 1.0, .summer: 0.9, .autumn: 1.2, .winter: 1.0],
        "NATURAL_GAS": [.spring: 0.8, .summer: 1.3, .autumn: 1.1, .winter: 1.4],
        "HEATING_OIL": [.spring: 0.85, .summer: 0.7, .autumn: 1.2, .winter: 1.5]
    ]
    
    public func getSeasonalFactor(commodity: String, date: Date, hemisphere: String) -> Double {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        
        let season = getSeason(month: month, hemisphere: hemisphere)
        
        return seasonalPatterns[commodity]?[season] ?? 1.0
    }
    
    private func getSeason(month: Int, hemisphere: String) -> Season {
        if hemisphere.lowercased().contains("south") {
            // Southern hemisphere seasons are opposite
            switch month {
            case 12, 1, 2: return .summer
            case 3, 4, 5: return .autumn
            case 6, 7, 8: return .winter
            case 9, 10, 11: return .spring
            default: return .spring
            }
        } else {
            // Northern hemisphere
            switch month {
            case 12, 1, 2: return .winter
            case 3, 4, 5: return .spring
            case 6, 7, 8: return .summer
            case 9, 10, 11: return .autumn
            default: return .spring
            }
        }
    }
}

public class ArbitrageModel {
    public func findOpportunities(commodities: [String: CommodityMarket]) -> [ArbitrageOpportunity] {
        var opportunities: [ArbitrageOpportunity] = []
        
        // Look for price discrepancies between related commodities
        opportunities.append(contentsOf: findCommoditySpreadOpportunities(commodities))
        
        // Look for calendar spread opportunities
        opportunities.append(contentsOf: findCalendarSpreadOpportunities(commodities))
        
        // Look for cross-market opportunities
        opportunities.append(contentsOf: findCrossMarketOpportunities(commodities))
        
        return opportunities.sorted { $0.profitPotential > $1.profitPotential }
    }
    
    private func findCommoditySpreadOpportunities(_ commodities: [String: CommodityMarket]) -> [ArbitrageOpportunity] {
        var opportunities: [ArbitrageOpportunity] = []
        
        // Example: WTI vs Brent crude spread
        if let wti = commodities["WTI_CRUDE"], let brent = commodities["BRENT_CRUDE"] {
            let normalSpread = 3.0 // Normal $3 spread
            let currentSpread = brent.currentPrice - wti.currentPrice
            
            if abs(currentSpread - normalSpread) > 2.0 {
                let opportunity = ArbitrageOpportunity(
                    commodity: "WTI-BRENT_SPREAD",
                    buyMarket: currentSpread > normalSpread ? "WTI" : "BRENT",
                    sellMarket: currentSpread > normalSpread ? "BRENT" : "WTI",
                    buyPrice: currentSpread > normalSpread ? wti.currentPrice : brent.currentPrice,
                    sellPrice: currentSpread > normalSpread ? brent.currentPrice : wti.currentPrice,
                    profitPotential: abs(currentSpread - normalSpread),
                    riskLevel: .medium,
                    timeWindow: 86400 * 7, // 1 week
                    description: "Oil spread arbitrage opportunity",
                    confidence: 0.7
                )
                opportunities.append(opportunity)
            }
        }
        
        return opportunities
    }
    
    private func findCalendarSpreadOpportunities(_ commodities: [String: CommodityMarket]) -> [ArbitrageOpportunity] {
        // Placeholder for calendar spread opportunities
        // Would implement seasonal price differences
        return []
    }
    
    private func findCrossMarketOpportunities(_ commodities: [String: CommodityMarket]) -> [ArbitrageOpportunity] {
        // Placeholder for cross-market arbitrage
        // Would implement geographical price differences
        return []
    }
}

// MARK: - Data Services

public class LiveCommodityDataService: ObservableObject {
    @Published public var latestPrices: [String: Double] = [:]
    @Published public var marketDepth: [String: MarketDepth] = [:]
    @Published public var tradingVolumes: [String: Double] = [:]
    @Published public var connectionStatus: APIConnectionStatus = .disconnected
    @Published public var lastUpdate: Date?
    
    // API Configuration
    private let quandlAPIKey = "your_quandl_api_key"
    private let alphaVantageAPIKey = "your_alpha_vantage_api_key"
    private let yahooCommodityEndpoints: [String: String] = [
        "WTI_CRUDE": "CL=F",
        "BRENT_CRUDE": "BZ=F",
        "NATURAL_GAS": "NG=F",
        "GOLD": "GC=F",
        "SILVER": "SI=F",
        "COPPER": "HG=F",
        "PLATINUM": "PL=F",
        "PALLADIUM": "PA=F",
        "WHEAT": "ZW=F",
        "CORN": "ZC=F",
        "SOYBEANS": "ZS=F",
        "COFFEE": "KC=F",
        "SUGAR": "SB=F",
        "COTTON": "CT=F",
        "IRON_ORE": "IRONO.L"
    ]
    
    // Market data providers
    private let commodityExchangeAPIs = [
        "CME": "https://www.cmegroup.com/api/",
        "ICE": "https://www.theice.com/api/",
        "LME": "https://www.lme.com/api/",
        "COMEX": "https://www.comex.com/api/"
    ]
    
    // Rate limiting and caching
    private let rateLimiter = CommodityAPIRateLimiter(requestsPerMinute: 100)
    private let dataCache = CommodityDataCache()
    private var cancellables = Set<AnyCancellable>()
    private let updateInterval: TimeInterval = 60 // 1 minute for commodity data
    
    public init() {
        startPeriodicUpdates()
    }
    
    private func startPeriodicUpdates() {
        Timer.publish(every: updateInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.updateAllCommodityData()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Update all commodity data sources
    public func updateAllCommodityData() async {
        connectionStatus = .updating
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.updateCommodityPrices()
            }
            
            group.addTask {
                await self.updateMarketDepth()
            }
            
            group.addTask {
                await self.updateTradingVolumes()
            }
        }
        
        await MainActor.run {
            self.lastUpdate = Date()
            self.connectionStatus = .connected
        }
    }
    
    private func updateCommodityPrices() async {
        do {
            let prices = try await fetchRealTimePrices()
            
            await MainActor.run {
                self.latestPrices = prices
            }
            
            dataCache.cachePrices(prices, expiry: Date().addingTimeInterval(120))
            
        } catch {
            print("Failed to update commodity prices: \(error)")
            if let cachedPrices = dataCache.getCachedPrices() {
                await MainActor.run {
                    self.latestPrices = cachedPrices
                }
            }
        }
    }
    
    private func updateMarketDepth() async {
        do {
            let depth = try await fetchMarketDepth()
            
            await MainActor.run {
                self.marketDepth = depth
            }
            
        } catch {
            print("Failed to update market depth: \(error)")
        }
    }
    
    private func updateTradingVolumes() async {
        do {
            let volumes = try await fetchTradingVolumes()
            
            await MainActor.run {
                self.tradingVolumes = volumes
            }
            
        } catch {
            print("Failed to update trading volumes: \(error)")
        }
    }
    
    /// Fetch real-time commodity prices from multiple sources
    private func fetchRealTimePrices() async throws -> [String: Double] {
        guard await rateLimiter.canMakeRequest() else {
            throw CommodityDataError.rateLimitExceeded
        }
        
        var prices: [String: Double] = [:]
        
        // Yahoo Finance for real-time prices
        for (commodity, symbol) in yahooCommodityEndpoints {
            if let price = try? await fetchYahooPrice(symbol: symbol) {
                prices[commodity] = price
            }
        }
        
        // Alpha Vantage for additional data
        let alphaVantagePrices = try await fetchAlphaVantagePrices()
        for (commodity, price) in alphaVantagePrices {
            prices[commodity] = price
        }
        
        // Quandl for specialized commodities
        let quandlPrices = try await fetchQuandlPrices()
        for (commodity, price) in quandlPrices {
            prices[commodity] = price
        }
        
        return prices
    }
    
    private func fetchYahooPrice(symbol: String) async throws -> Double {
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw CommodityDataError.invalidResponse
        }
        
        let yahooResponse = try JSONDecoder().decode(YahooFinanceResponse.self, from: data)
        
        guard let chart = yahooResponse.chart.result.first,
              let meta = chart.meta,
              let price = meta.regularMarketPrice else {
            throw CommodityDataError.dataParsingError
        }
        
        return price
    }
    
    private func fetchAlphaVantagePrices() async throws -> [String: Double] {
        var prices: [String: Double] = [:]
        
        // Fetch major commodity indices
        let commoditySymbols = ["DJP", "GSG", "PDBC"] // Commodity ETFs as proxies
        
        for symbol in commoditySymbols {
            let url = URL(string: "https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol=\(symbol)&apikey=\(alphaVantageAPIKey)")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(AlphaVantageGlobalQuote.self, from: data)
            
            if let priceString = response.globalQuote.price,
               let price = Double(priceString) {
                prices[symbol] = price
            }
        }
        
        return prices
    }
    
    private func fetchQuandlPrices() async throws -> [String: Double] {
        var prices: [String: Double] = [:]
        
        // Quandl commodity datasets
        let quandlDatasets = [
            "CHRIS/CME_CL1": "WTI_CRUDE",
            "CHRIS/ICE_B1": "BRENT_CRUDE", 
            "CHRIS/CME_NG1": "NATURAL_GAS",
            "CHRIS/CME_GC1": "GOLD",
            "CHRIS/CME_SI1": "SILVER"
        ]
        
        for (dataset, commodity) in quandlDatasets {
            let url = URL(string: "https://www.quandl.com/api/v3/datasets/\(dataset)/data.json?api_key=\(quandlAPIKey)&rows=1")!
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let response = try JSONDecoder().decode(QuandlDatasetResponse.self, from: data)
                
                if let latestData = response.dataset_data.data.first,
                   latestData.count > 1,
                   let price = latestData[1] as? Double {
                    prices[commodity] = price
                }
            } catch {
                print("Failed to fetch Quandl data for \(commodity): \(error)")
            }
        }
        
        return prices
    }
    
    private func fetchMarketDepth() async throws -> [String: MarketDepth] {
        var marketDepth: [String: MarketDepth] = [:]
        
        // For demonstration, create realistic market depth data
        // In production, this would fetch from commodity exchange APIs
        for commodity in yahooCommodityEndpoints.keys {
            if let price = latestPrices[commodity] {
                let depth = generateRealisticMarketDepth(basePrice: price)
                marketDepth[commodity] = depth
            }
        }
        
        return marketDepth
    }
    
    private func fetchTradingVolumes() async throws -> [String: Double] {
        var volumes: [String: Double] = [:]
        
        // Fetch volumes from Yahoo Finance
        for (commodity, symbol) in yahooCommodityEndpoints {
            if let volume = try? await fetchYahooVolume(symbol: symbol) {
                volumes[commodity] = volume
            }
        }
        
        return volumes
    }
    
    private func fetchYahooVolume(symbol: String) async throws -> Double {
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(YahooFinanceResponse.self, from: data)
        
        guard let chart = response.chart.result.first,
              let meta = chart.meta,
              let volume = meta.regularMarketVolume else {
            return 0
        }
        
        return Double(volume)
    }
    
    private func generateRealisticMarketDepth(basePrice: Double) -> MarketDepth {
        let spread = basePrice * 0.001 // 0.1% spread
        let bidPrice = basePrice - spread / 2
        let askPrice = basePrice + spread / 2
        
        var bids: [OrderBookEntry] = []
        var asks: [OrderBookEntry] = []
        
        // Generate 5 levels of market depth
        for i in 0..<5 {
            let bidPriceLevel = bidPrice - (Double(i) * spread * 0.1)
            let askPriceLevel = askPrice + (Double(i) * spread * 0.1)
            let quantity = Double.random(in: 100...1000)
            
            bids.append(OrderBookEntry(
                price: bidPriceLevel,
                quantity: quantity,
                timestamp: Date()
            ))
            
            asks.append(OrderBookEntry(
                price: askPriceLevel,
                quantity: quantity,
                timestamp: Date()
            ))
        }
        
        return MarketDepth(
            bids: bids,
            asks: asks,
            spread: spread,
            lastUpdate: Date()
        )
    }
    
    /// Get latest price for a specific commodity
    public func getLatestPrice(commodity: String) -> Double? {
        return latestPrices[commodity]
    }
    
    /// Get market depth for a specific commodity
    public func getMarketDepth(commodity: String) -> MarketDepth? {
        return marketDepth[commodity]
    }
    
    /// Force refresh all data
    public func forceRefresh() async {
        await updateAllCommodityData()
    }
}

public class EconomicDataService: ObservableObject {
    @Published public var economicIndicators: EconomicIndicators = EconomicIndicators()
    @Published public var connectionStatus: APIConnectionStatus = .disconnected
    @Published public var lastUpdate: Date?
    
    // API Configuration
    private let fredAPIKey = "your_fred_api_key" // Federal Reserve Economic Data
    private let worldBankAPIKey = "your_worldbank_api_key"
    private let oecdAPIKey = "your_oecd_api_key"
    
    // Economic data endpoints
    private let fredEndpoints = [
        "GDP": "GDP",
        "INFLATION": "CPIAUCSL",
        "UNEMPLOYMENT": "UNRATE",
        "INTEREST_RATE": "FEDFUNDS",
        "DOLLAR_INDEX": "DTWEXBGS",
        "CONSUMER_CONFIDENCE": "UMCSENT",
        "MANUFACTURING_PMI": "MANEMP",
        "SERVICES_PMI": "SRVPRD"
    ]
    
    private let rateLimiter = EconomicAPIRateLimiter(requestsPerMinute: 60)
    private let dataCache = EconomicDataCache()
    private var cancellables = Set<AnyCancellable>()
    private let updateInterval: TimeInterval = 3600 // 1 hour for economic data
    
    public init() {
        startPeriodicUpdates()
    }
    
    private func startPeriodicUpdates() {
        Timer.publish(every: updateInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.updateEconomicData()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Update all economic indicators
    public func updateEconomicData() async {
        connectionStatus = .updating
        
        do {
            let indicators = try await fetchEconomicData()
            
            await MainActor.run {
                self.economicIndicators = indicators
                self.lastUpdate = Date()
                self.connectionStatus = .connected
            }
            
            dataCache.cacheIndicators(indicators, expiry: Date().addingTimeInterval(7200))
            
        } catch {
            print("Failed to update economic data: \(error)")
            if let cachedIndicators = dataCache.getCachedIndicators() {
                await MainActor.run {
                    self.economicIndicators = cachedIndicators
                    self.connectionStatus = .connected
                }
            } else {
                await MainActor.run {
                    self.connectionStatus = .error("Failed to fetch economic data")
                }
            }
        }
    }
    
    /// Fetch comprehensive economic data from multiple sources
    public func fetchEconomicData() async throws -> EconomicIndicators {
        guard await rateLimiter.canMakeRequest() else {
            throw EconomicDataError.rateLimitExceeded
        }
        
        var indicators = EconomicIndicators()
        
        // Fetch from FRED (Federal Reserve Economic Data)
        let fredData = try await fetchFREDData()
        indicators.merge(with: fredData)
        
        // Fetch from World Bank
        let worldBankData = try await fetchWorldBankData()
        indicators.merge(with: worldBankData)
        
        // Fetch from OECD
        let oecdData = try await fetchOECDData()
        indicators.merge(with: oecdData)
        
        return indicators
    }
    
    private func fetchFREDData() async throws -> EconomicIndicators {
        var indicators = EconomicIndicators()
        
        for (indicator, seriesId) in fredEndpoints {
            do {
                let url = URL(string: "https://api.stlouisfed.org/fred/series/observations?series_id=\(seriesId)&api_key=\(fredAPIKey)&file_type=json&limit=1&sort_order=desc")!
                let (data, _) = try await URLSession.shared.data(from: url)
                let response = try JSONDecoder().decode(FREDResponse.self, from: data)
                
                if let observation = response.observations.first,
                   let value = Double(observation.value) {
                    
                    switch indicator {
                    case "GDP":
                        // Convert to growth rate (simplified)
                        indicators.globalGDPGrowth = value / 100.0
                    case "INFLATION":
                        // Convert CPI to inflation rate
                        indicators.globalInflation = value / 100.0
                    case "UNEMPLOYMENT":
                        indicators.unemploymentRate = value / 100.0
                    case "INTEREST_RATE":
                        indicators.globalInterestRates = value / 100.0
                    case "DOLLAR_INDEX":
                        indicators.dollarIndex = value
                    case "CONSUMER_CONFIDENCE":
                        indicators.consumerConfidence = value / 100.0
                    case "MANUFACTURING_PMI":
                        indicators.manufacturingPMI = value
                    case "SERVICES_PMI":
                        indicators.servicesPMI = value
                    default:
                        break
                    }
                }
            } catch {
                print("Failed to fetch FRED data for \(indicator): \(error)")
            }
        }
        
        return indicators
    }
    
    private func fetchWorldBankData() async throws -> EconomicIndicators {
        var indicators = EconomicIndicators()
        
        // World Bank Global Economic Indicators
        let worldBankIndicators = [
            "NY.GDP.MKTP.KD.ZG": "gdpGrowth", // GDP growth
            "FP.CPI.TOTL.ZG": "inflation"     // Inflation
        ]
        
        for (indicatorCode, field) in worldBankIndicators {
            let url = URL(string: "https://api.worldbank.org/v2/country/WLD/indicator/\(indicatorCode)?format=json&date=2023")!
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let response = try JSONDecoder().decode([WorldBankResponse].self, from: data)
                
                if response.count > 1,
                   let dataArray = response[1] as? [WorldBankDataPoint],
                   let dataPoint = dataArray.first,
                   let value = dataPoint.value {
                    
                    switch field {
                    case "gdpGrowth":
                        indicators.globalGDPGrowth = value / 100.0
                    case "inflation":
                        indicators.globalInflation = value / 100.0
                    default:
                        break
                    }
                }
            } catch {
                print("Failed to fetch World Bank data for \(indicatorCode): \(error)")
            }
        }
        
        return indicators
    }
    
    private func fetchOECDData() async throws -> EconomicIndicators {
        var indicators = EconomicIndicators()
        
        // OECD Composite Leading Indicators
        let url = URL(string: "https://stats.oecd.org/restsdmx/sdmx.ashx/GetData/MEI_CLI/CLI.OECD.GP.M/all?startTime=2023&endTime=2023")!
        
        do {
            // OECD API returns SDMX format, simplified implementation
            let (data, _) = try await URLSession.shared.data(from: url)
            // Parse SDMX data (complex format, simplified here)
            // indicators.compositeCLI = parsedValue
        } catch {
            print("Failed to fetch OECD data: \(error)")
        }
        
        return indicators
    }
    
    /// Get specific economic indicator
    public func getIndicator(_ indicator: String) -> Double? {
        switch indicator.lowercased() {
        case "gdp", "gdp_growth":
            return economicIndicators.globalGDPGrowth
        case "inflation", "cpi":
            return economicIndicators.globalInflation
        case "unemployment":
            return economicIndicators.unemploymentRate
        case "interest_rate", "fed_funds":
            return economicIndicators.globalInterestRates
        case "dollar_index", "dxy":
            return economicIndicators.dollarIndex
        case "consumer_confidence":
            return economicIndicators.consumerConfidence
        case "manufacturing_pmi", "pmi":
            return economicIndicators.manufacturingPMI
        case "services_pmi":
            return economicIndicators.servicesPMI
        default:
            return nil
        }
    }
    
    /// Force refresh economic data
    public func forceRefresh() async {
        await updateEconomicData()
    }
}

public struct EconomicIndicators {
    public var globalGDPGrowth: Double = 0.03
    public var globalInflation: Double = 0.025
    public var globalInterestRates: Double = 0.05
    public var dollarIndex: Double = 103.0
    public var unemploymentRate: Double = 0.04
    public var consumerConfidence: Double = 0.7
    public var manufacturingPMI: Double = 52.0
    public var servicesPMI: Double = 54.0
    
    public init() {}
    
    /// Merge with another set of economic indicators, preferring non-default values
    public mutating func merge(with other: EconomicIndicators) {
        if other.globalGDPGrowth != 0.03 {
            self.globalGDPGrowth = other.globalGDPGrowth
        }
        if other.globalInflation != 0.025 {
            self.globalInflation = other.globalInflation
        }
        if other.globalInterestRates != 0.05 {
            self.globalInterestRates = other.globalInterestRates
        }
        if other.dollarIndex != 103.0 {
            self.dollarIndex = other.dollarIndex
        }
        if other.unemploymentRate != 0.04 {
            self.unemploymentRate = other.unemploymentRate
        }
        if other.consumerConfidence != 0.7 {
            self.consumerConfidence = other.consumerConfidence
        }
        if other.manufacturingPMI != 52.0 {
            self.manufacturingPMI = other.manufacturingPMI
        }
        if other.servicesPMI != 54.0 {
            self.servicesPMI = other.servicesPMI
        }
    }
}

public struct MarketDepth {
    public let bids: [OrderBookEntry]
    public let asks: [OrderBookEntry]
    public let spread: Double
    public let lastUpdate: Date
}

public struct OrderBookEntry {
    public let price: Double
    public let quantity: Double
    public let timestamp: Date
}

// MARK: - Risk Management

public struct RiskMetrics {
    public let valueAtRisk: Double
    public let expectedShortfall: Double
    public let maxDrawdown: Double
    public let volatility: Double
    public let beta: Double
    public let sharpeRatio: Double
    public let correlations: [String: Double]
}

public struct PortfolioRisk {
    public let totalRisk: Double
    public let diversificationBenefit: Double
    public let concentrationRisk: Double
    public let liquidityRisk: Double
    public let marketRisk: Double
    public let creditRisk: Double
}

// MARK: - Performance Analytics

public struct PerformanceMetrics {
    public let totalReturn: Double
    public let annualizedReturn: Double
    public let volatility: Double
    public let sharpeRatio: Double
    public let maxDrawdown: Double
    public let winRate: Double
    public let profitFactor: Double
    public let averageWin: Double
    public let averageLoss: Double
}

// MARK: - API Response Models and Supporting Infrastructure

public enum APIConnectionStatus {
    case connected, disconnected, updating, error(String)
}

public enum CommodityDataError: Error {
    case rateLimitExceeded
    case invalidResponse
    case dataParsingError
    case networkError
}

public enum EconomicDataError: Error {
    case rateLimitExceeded
    case invalidResponse
    case dataParsingError
    case networkError
}

// MARK: - Yahoo Finance API Models

public struct YahooFinanceResponse: Codable {
    public let chart: YahooChart
}

public struct YahooChart: Codable {
    public let result: [YahooChartResult]
}

public struct YahooChartResult: Codable {
    public let meta: YahooMeta?
}

public struct YahooMeta: Codable {
    public let regularMarketPrice: Double?
    public let regularMarketVolume: Int?
}

// MARK: - Alpha Vantage API Models

public struct AlphaVantageGlobalQuote: Codable {
    public let globalQuote: AlphaVantageQuote
    
    private enum CodingKeys: String, CodingKey {
        case globalQuote = "Global Quote"
    }
}

public struct AlphaVantageQuote: Codable {
    public let price: String?
    
    private enum CodingKeys: String, CodingKey {
        case price = "05. price"
    }
}

// MARK: - Quandl API Models

public struct QuandlDatasetResponse: Codable {
    public let dataset_data: QuandlDatasetData
}

public struct QuandlDatasetData: Codable {
    public let data: [[Any]]
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dataArray = try container.decode([[AnyCodable]].self, forKey: .data)
        self.data = dataArray.map { $0.map { $0.value } }
    }
    
    private enum CodingKeys: String, CodingKey {
        case data
    }
}

struct AnyCodable: Codable {
    let value: Any
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else {
            throw DecodingError.typeMismatch(AnyCodable.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let intValue = value as? Int {
            try container.encode(intValue)
        } else if let doubleValue = value as? Double {
            try container.encode(doubleValue)
        } else if let stringValue = value as? String {
            try container.encode(stringValue)
        } else if let boolValue = value as? Bool {
            try container.encode(boolValue)
        } else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
}

// MARK: - Federal Reserve Economic Data (FRED) API Models

public struct FREDResponse: Codable {
    public let observations: [FREDObservation]
}

public struct FREDObservation: Codable {
    public let date: String
    public let value: String
}

// MARK: - World Bank API Models

public struct WorldBankResponse: Codable {
    // World Bank returns array with metadata and data
}

public struct WorldBankDataPoint: Codable {
    public let value: Double?
    public let date: String?
}

// MARK: - Rate Limiters and Caches

public class CommodityAPIRateLimiter {
    private let requestsPerMinute: Int
    private var requestTimes: [Date] = []
    private let queue = DispatchQueue(label: "commodity_rate_limiter")
    
    public init(requestsPerMinute: Int) {
        self.requestsPerMinute = requestsPerMinute
    }
    
    public func canMakeRequest() async -> Bool {
        return await withCheckedContinuation { continuation in
            queue.async {
                let now = Date()
                let oneMinuteAgo = now.addingTimeInterval(-60)
                
                self.requestTimes = self.requestTimes.filter { $0 > oneMinuteAgo }
                
                if self.requestTimes.count < self.requestsPerMinute {
                    self.requestTimes.append(now)
                    continuation.resume(returning: true)
                } else {
                    continuation.resume(returning: false)
                }
            }
        }
    }
}

public class EconomicAPIRateLimiter {
    private let requestsPerMinute: Int
    private var requestTimes: [Date] = []
    private let queue = DispatchQueue(label: "economic_rate_limiter")
    
    public init(requestsPerMinute: Int) {
        self.requestsPerMinute = requestsPerMinute
    }
    
    public func canMakeRequest() async -> Bool {
        return await withCheckedContinuation { continuation in
            queue.async {
                let now = Date()
                let oneMinuteAgo = now.addingTimeInterval(-60)
                
                self.requestTimes = self.requestTimes.filter { $0 > oneMinuteAgo }
                
                if self.requestTimes.count < self.requestsPerMinute {
                    self.requestTimes.append(now)
                    continuation.resume(returning: true)
                } else {
                    continuation.resume(returning: false)
                }
            }
        }
    }
}

public class CommodityDataCache {
    private var priceCache: (data: [String: Double], expiry: Date)?
    private var hitCount = 0
    private var missCount = 0
    
    public func cachePrices(_ data: [String: Double], expiry: Date) {
        priceCache = (data, expiry)
    }
    
    public func getCachedPrices() -> [String: Double]? {
        guard let cache = priceCache, cache.expiry > Date() else {
            missCount += 1
            return nil
        }
        hitCount += 1
        return cache.data
    }
    
    public func getHitRate() -> Double {
        let total = hitCount + missCount
        return total > 0 ? Double(hitCount) / Double(total) : 0.0
    }
}

public class EconomicDataCache {
    private var indicatorCache: (data: EconomicIndicators, expiry: Date)?
    private var hitCount = 0
    private var missCount = 0
    
    public func cacheIndicators(_ data: EconomicIndicators, expiry: Date) {
        indicatorCache = (data, expiry)
    }
    
    public func getCachedIndicators() -> EconomicIndicators? {
        guard let cache = indicatorCache, cache.expiry > Date() else {
            missCount += 1
            return nil
        }
        hitCount += 1
        return cache.data
    }
    
    public func getHitRate() -> Double {
        let total = hitCount + missCount
        return total > 0 ? Double(hitCount) / Double(total) : 0.0
    }
}