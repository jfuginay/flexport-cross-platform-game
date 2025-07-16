import Foundation
import Combine

/// Ryan's Multi-Market Economic System
/// Based on Dr. Paul Ryan's economic theory integrating goods, capital, assets, and labor markets
public class RyanEconomicSystem: ObservableObject {
    @Published public var goodsMarket: GoodsMarket
    @Published public var capitalMarket: CapitalMarket
    @Published public var assetMarket: AssetMarket
    @Published public var laborMarket: LaborMarket
    @Published public var marketInterconnections: MarketInterconnections
    
    private var cancellables = Set<AnyCancellable>()
    private let updateInterval: TimeInterval = 1.0 // Update markets every second
    private var lastUpdateTime = Date()
    
    public init() {
        self.goodsMarket = GoodsMarket()
        self.capitalMarket = CapitalMarket()
        self.assetMarket = AssetMarket()
        self.laborMarket = LaborMarket()
        self.marketInterconnections = MarketInterconnections()
        
        setupMarketInterconnections()
        initializeMarkets()
    }
    
    private func setupMarketInterconnections() {
        // Capital market affects all other markets
        capitalMarket.$interestRate
            .sink { [weak self] rate in
                self?.updateMarketsFromInterestRate(rate)
            }
            .store(in: &cancellables)
        
        // Labor market affects production costs
        laborMarket.$averageWage
            .sink { [weak self] wage in
                self?.updateProductionCosts(wage)
            }
            .store(in: &cancellables)
    }
    
    private func initializeMarkets() {
        // Initialize goods market with commodities
        goodsMarket.commodities = [
            Commodity(name: "Electronics", category: .manufactured, basePrice: 1000, volatility: 0.15),
            Commodity(name: "Raw Materials", category: .raw, basePrice: 100, volatility: 0.25),
            Commodity(name: "Energy", category: .energy, basePrice: 50, volatility: 0.35),
            Commodity(name: "Food", category: .perishable, basePrice: 20, volatility: 0.20),
            Commodity(name: "Machinery", category: .manufactured, basePrice: 5000, volatility: 0.10),
            Commodity(name: "Textiles", category: .manufactured, basePrice: 200, volatility: 0.18),
            Commodity(name: "Chemicals", category: .hazardous, basePrice: 300, volatility: 0.22)
        ]
        
        // Initialize asset market with base assets
        generateInitialAssets()
        
        // Initialize labor market
        generateInitialLabor()
    }
    
    /// Update all markets based on time and interactions
    public func update(deltaTime: TimeInterval) {
        // Update supply and demand dynamics
        updateSupplyDemandDynamics(deltaTime)
        
        // Apply market interconnections
        applyMarketInterconnections()
        
        // Update prices based on market conditions
        updatePrices()
        
        // Generate market events
        generateMarketEvents()
        
        lastUpdateTime = Date()
    }
    
    private func updateSupplyDemandDynamics(_ deltaTime: TimeInterval) {
        // Update goods market
        for i in 0..<goodsMarket.commodities.count {
            var commodity = goodsMarket.commodities[i]
            
            // Supply changes based on production capacity and labor
            let laborEffect = laborMarket.employmentRate
            let productionCapacity = assetMarket.totalProductionCapacity * laborEffect
            commodity.supply += productionCapacity * deltaTime * commodity.productionRate
            
            // Demand changes based on economic activity and interest rates
            let economicActivity = 1.0 - (capitalMarket.interestRate / 0.2) // Higher rates reduce activity
            commodity.demand = commodity.baseDemand * economicActivity * marketInterconnections.globalDemandMultiplier
            
            // Natural decay for perishable goods
            if commodity.category == .perishable {
                commodity.supply *= pow(0.99, deltaTime) // 1% decay per time unit
            }
            
            goodsMarket.commodities[i] = commodity
        }
    }
    
    private func applyMarketInterconnections() {
        // Capital availability affects asset prices
        assetMarket.priceMultiplier = 1.0 + (capitalMarket.availableCapital / capitalMarket.totalCapital - 0.5) * 0.2
        
        // Labor costs affect production costs
        let laborCostFactor = laborMarket.averageWage / laborMarket.baseWage
        goodsMarket.productionCostMultiplier = 0.7 + 0.3 * laborCostFactor
        
        // Asset utilization affects labor demand
        laborMarket.demandMultiplier = assetMarket.utilizationRate
    }
    
    private func updatePrices() {
        // Update commodity prices based on supply and demand
        for i in 0..<goodsMarket.commodities.count {
            var commodity = goodsMarket.commodities[i]
            
            let supplyDemandRatio = commodity.supply / max(commodity.demand, 0.01)
            let priceChange = (1.0 / supplyDemandRatio - 1.0) * commodity.volatility
            
            // Apply price change with dampening
            commodity.currentPrice = commodity.basePrice * (1.0 + priceChange * 0.1)
            
            // Add random market noise
            let noise = Double.random(in: -commodity.volatility...commodity.volatility) * 0.05
            commodity.currentPrice *= (1.0 + noise)
            
            // Store price history
            commodity.priceHistory.append(PricePoint(date: Date(), price: commodity.currentPrice))
            if commodity.priceHistory.count > 100 {
                commodity.priceHistory.removeFirst()
            }
            
            goodsMarket.commodities[i] = commodity
        }
        
        // Update interest rates based on capital supply and demand
        let capitalUtilization = 1.0 - (capitalMarket.availableCapital / capitalMarket.totalCapital)
        capitalMarket.interestRate = capitalMarket.baseRate * (0.5 + capitalUtilization * 1.5)
        
        // Update wages based on labor supply and demand
        let laborSupplyDemandRatio = Double(laborMarket.availableWorkers.count) / max(laborMarket.totalDemand, 1.0)
        laborMarket.averageWage = laborMarket.baseWage * (2.0 - laborSupplyDemandRatio)
    }
    
    private func generateMarketEvents() {
        // Random events that affect markets
        if Double.random(in: 0...1) < 0.01 { // 1% chance per update
            let eventType = MarketEvent.EventType.allCases.randomElement()!
            let event = MarketEvent(type: eventType, magnitude: Double.random(in: 0.1...0.5))
            applyMarketEvent(event)
        }
    }
    
    private func applyMarketEvent(_ event: MarketEvent) {
        switch event.type {
        case .boom:
            marketInterconnections.globalDemandMultiplier *= (1.0 + event.magnitude)
            capitalMarket.availableCapital *= (1.0 + event.magnitude * 0.5)
        case .recession:
            marketInterconnections.globalDemandMultiplier *= (1.0 - event.magnitude)
            capitalMarket.availableCapital *= (1.0 - event.magnitude * 0.3)
        case .supply:
            if let commodity = goodsMarket.commodities.randomElement() {
                let index = goodsMarket.commodities.firstIndex(where: { $0.name == commodity.name })!
                goodsMarket.commodities[index].supply *= (1.0 + event.magnitude)
            }
        case .demand:
            if let commodity = goodsMarket.commodities.randomElement() {
                let index = goodsMarket.commodities.firstIndex(where: { $0.name == commodity.name })!
                goodsMarket.commodities[index].demand *= (1.0 + event.magnitude)
            }
        case .technology:
            assetMarket.totalProductionCapacity *= (1.0 + event.magnitude * 0.2)
            laborMarket.productivityMultiplier *= (1.0 + event.magnitude * 0.1)
        }
    }
    
    private func updateMarketsFromInterestRate(_ rate: Double) {
        // Higher interest rates reduce investment in assets
        assetMarket.investmentDemand = assetMarket.baseInvestmentDemand * (0.2 / max(rate, 0.01))
        
        // Higher rates reduce consumer spending
        goodsMarket.consumerDemandMultiplier = 1.2 - rate * 2.0
    }
    
    private func updateProductionCosts(_ wage: Double) {
        // Labor costs directly affect production
        let laborCostRatio = wage / laborMarket.baseWage
        goodsMarket.productionCostMultiplier = 0.5 + 0.5 * laborCostRatio
    }
    
    private func generateInitialAssets() {
        // Generate ships
        for i in 1...20 {
            let ship = Ship(
                name: "Vessel-\(i)",
                capacity: Int.random(in: 1000...10000),
                speed: Double.random(in: 15...30),
                efficiency: Double.random(in: 0.7...0.95),
                maintenanceCost: Double.random(in: 10000...50000),
                price: Double.random(in: 1000000...10000000)
            )
            assetMarket.availableShips.append(ship)
        }
        
        // Generate warehouses
        let locations = ["New York", "London", "Singapore", "Dubai", "Shanghai", "Rotterdam", "Los Angeles", "Hamburg"]
        for location in locations {
            let warehouse = Warehouse(
                location: Location(
                    name: location,
                    coordinates: Coordinates(
                        latitude: Double.random(in: -90...90),
                        longitude: Double.random(in: -180...180)
                    ),
                    portType: .multimodal
                ),
                capacity: Int.random(in: 10000...100000),
                storageCost: Double.random(in: 1000...10000),
                price: Double.random(in: 500000...5000000)
            )
            assetMarket.availableWarehouses.append(warehouse)
        }
    }
    
    private func generateInitialLabor() {
        // Generate workers
        for _ in 1...100 {
            let specialization = WorkerSpecialization.allCases.randomElement()!
            let worker = Worker(
                specialization: specialization,
                skill: Double.random(in: 0.5...1.0),
                wage: laborMarket.baseWage * Double.random(in: 0.8...1.2),
                productivity: Double.random(in: 0.7...1.3)
            )
            laborMarket.availableWorkers.append(worker)
        }
    }
}

/// Enhanced market models
public struct MarketInterconnections {
    public var globalDemandMultiplier: Double = 1.0
    public var globalSupplyMultiplier: Double = 1.0
    public var confidenceIndex: Double = 0.5
    public var volatilityIndex: Double = 0.2
}

public struct MarketEvent {
    public enum EventType: CaseIterable {
        case boom
        case recession
        case supply
        case demand
        case technology
    }
    
    public let type: EventType
    public let magnitude: Double
    public let timestamp = Date()
}

/// Enhanced Commodity model
public struct Commodity: Identifiable, Codable {
    public let id = UUID()
    public var name: String
    public var category: CommodityCategory
    public var basePrice: Double
    public var currentPrice: Double
    public var volatility: Double
    public var supply: Double = 1000
    public var demand: Double = 1000
    public var baseDemand: Double = 1000
    public var productionRate: Double = 0.1
    public var priceHistory: [PricePoint] = []
    
    public enum CommodityCategory: String, Codable, CaseIterable {
        case raw
        case manufactured
        case perishable
        case energy
        case hazardous
    }
    
    public init(name: String, category: CommodityCategory, basePrice: Double, volatility: Double) {
        self.name = name
        self.category = category
        self.basePrice = basePrice
        self.currentPrice = basePrice
        self.volatility = volatility
        self.baseDemand = 1000
    }
}

public struct PricePoint: Codable {
    public let date: Date
    public let price: Double
}

/// Enhanced market structures
public class GoodsMarket: ObservableObject {
    @Published public var commodities: [Commodity] = []
    @Published public var productionCostMultiplier: Double = 1.0
    @Published public var consumerDemandMultiplier: Double = 1.0
}

public class CapitalMarket: ObservableObject {
    @Published public var interestRate: Double = 0.05
    @Published public var baseRate: Double = 0.05
    @Published public var availableCapital: Double = 10_000_000
    @Published public var totalCapital: Double = 50_000_000
    @Published public var creditRating: Double = 0.8
}

public class AssetMarket: ObservableObject {
    @Published public var availableShips: [Ship] = []
    @Published public var availableWarehouses: [Warehouse] = []
    @Published public var priceMultiplier: Double = 1.0
    @Published public var investmentDemand: Double = 1.0
    @Published public var baseInvestmentDemand: Double = 1.0
    @Published public var totalProductionCapacity: Double = 1.0
    @Published public var utilizationRate: Double = 0.8
}

public class LaborMarket: ObservableObject {
    @Published public var availableWorkers: [Worker] = []
    @Published public var averageWage: Double = 50_000
    @Published public var baseWage: Double = 50_000
    @Published public var employmentRate: Double = 0.95
    @Published public var demandMultiplier: Double = 1.0
    @Published public var totalDemand: Double = 80
    @Published public var productivityMultiplier: Double = 1.0
}

/// Enhanced models
public struct Ship: Identifiable, Codable {
    public let id = UUID()
    public var name: String
    public var capacity: Int
    public var speed: Double
    public var efficiency: Double
    public var maintenanceCost: Double
    public var price: Double
    public var age: Double = 0
    public var condition: Double = 1.0
}

public struct Warehouse: Identifiable, Codable {
    public let id = UUID()
    public var location: Location
    public var capacity: Int
    public var storageCost: Double
    public var price: Double
    public var utilization: Double = 0
}

public struct Worker: Identifiable, Codable {
    public let id = UUID()
    public var specialization: WorkerSpecialization
    public var skill: Double
    public var wage: Double
    public var productivity: Double
    public var experience: Double = 0
}

public enum WorkerSpecialization: String, Codable, CaseIterable {
    case operations
    case sales
    case engineering
    case management
    case logistics
    case finance
}