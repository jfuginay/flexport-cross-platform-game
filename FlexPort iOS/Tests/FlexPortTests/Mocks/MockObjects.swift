import Foundation
import Combine
import CoreData
@testable import FlexPort

// MARK: - Mock Game Manager

class MockGameManager: ObservableObject {
    @Published var currentScreen: GameScreen = .mainMenu
    @Published var gameState: GameState = GameState()
    @Published var singularityProgress: Double = 0.0
    
    var startNewGameCalled = false
    var navigateToCalled: [GameScreen] = []
    
    func startNewGame() {
        startNewGameCalled = true
        gameState = GameState()
        currentScreen = .game
    }
    
    func navigateTo(_ screen: GameScreen) {
        navigateToCalled.append(screen)
        currentScreen = screen
    }
    
    func reset() {
        startNewGameCalled = false
        navigateToCalled.removeAll()
        currentScreen = .mainMenu
        gameState = GameState()
        singularityProgress = 0.0
    }
}

// MARK: - Mock World

class MockWorld {
    var entities: [Entity] = []
    var components: [Entity: [ComponentType: Component]] = [:]
    var systems: [System] = []
    
    var updateCalled = false
    var lastUpdateDeltaTime: TimeInterval = 0
    var createEntityCalled = false
    var addComponentCalled: [(Entity, Component)] = []
    var removeComponentCalled: [(Entity, ComponentType)] = []
    
    func createEntity() -> Entity {
        createEntityCalled = true
        let entity = Entity(id: UUID())
        entities.append(entity)
        components[entity] = [:]
        return entity
    }
    
    func addComponent<T: Component>(_ component: T, to entity: Entity) {
        addComponentCalled.append((entity, component))
        components[entity]?[T.componentType] = component
    }
    
    func removeComponent<T: Component>(_ componentType: T.Type, from entity: Entity) {
        removeComponentCalled.append((entity, T.componentType))
        components[entity]?.removeValue(forKey: T.componentType)
    }
    
    func getComponent<T: Component>(_ componentType: T.Type, for entity: Entity) -> T? {
        return components[entity]?[T.componentType] as? T
    }
    
    func update(deltaTime: TimeInterval) {
        updateCalled = true
        lastUpdateDeltaTime = deltaTime
        
        for system in systems {
            system.update(deltaTime: deltaTime, world: self as! World)
        }
    }
    
    func reset() {
        entities.removeAll()
        components.removeAll()
        systems.removeAll()
        updateCalled = false
        lastUpdateDeltaTime = 0
        createEntityCalled = false
        addComponentCalled.removeAll()
        removeComponentCalled.removeAll()
    }
}

// MARK: - Mock Analytics Engine

class MockAnalyticsEngine: ObservableObject {
    @Published var currentSession: PlayerSession?
    @Published var isTrackingEnabled: Bool = true
    @Published var isOnline: Bool = true
    
    var startSessionCalled = false
    var endSessionCalled = false
    var trackEventCalled: [AnalyticsEvent] = []
    var updatePlayerStateCalled: [GameStateSnapshot] = []
    
    func startSession(userId: UUID? = nil, gameState: GameStateSnapshot? = nil) {
        startSessionCalled = true
        currentSession = PlayerSession(
            id: UUID(),
            userId: userId ?? UUID(),
            startTime: Date(),
            gameVersion: "1.0.0",
            platform: "iOS"
        )
    }
    
    func endSession() {
        endSessionCalled = true
        currentSession = nil
    }
    
    func trackEvent(_ event: AnalyticsEvent) {
        trackEventCalled.append(event)
    }
    
    func updatePlayerState(_ gameState: GameStateSnapshot) {
        updatePlayerStateCalled.append(gameState)
    }
    
    func reset() {
        currentSession = nil
        startSessionCalled = false
        endSessionCalled = false
        trackEventCalled.removeAll()
        updatePlayerStateCalled.removeAll()
    }
}

// MARK: - Mock Network Manager

class MockNetworkManager {
    var isConnected = true
    var latency: TimeInterval = 0.05 // 50ms
    
    var connectCalled = false
    var disconnectCalled = false
    var sendMessageCalled: [NetworkMessage] = []
    var receivedMessages: [NetworkMessage] = []
    
    private let messageSubject = PassthroughSubject<NetworkMessage, Never>()
    var messagePublisher: AnyPublisher<NetworkMessage, Never> {
        messageSubject.eraseToAnyPublisher()
    }
    
    func connect() async throws {
        connectCalled = true
        await Task.sleep(nanoseconds: UInt64(latency * 1_000_000_000))
        isConnected = true
    }
    
    func disconnect() {
        disconnectCalled = true
        isConnected = false
    }
    
    func sendMessage(_ message: NetworkMessage) async throws {
        sendMessageCalled.append(message)
        guard isConnected else {
            throw NetworkError.notConnected
        }
        
        // Simulate network latency
        await Task.sleep(nanoseconds: UInt64(latency * 1_000_000_000))
    }
    
    func simulateReceivedMessage(_ message: NetworkMessage) {
        receivedMessages.append(message)
        messageSubject.send(message)
    }
    
    func reset() {
        isConnected = true
        latency = 0.05
        connectCalled = false
        disconnectCalled = false
        sendMessageCalled.removeAll()
        receivedMessages.removeAll()
    }
}

// MARK: - Mock AI System

class MockAISystem: System {
    let priority = 100
    let canRunInParallel = false
    let requiredComponents: [ComponentType] = []
    
    var updateCalled = false
    var lastUpdateDeltaTime: TimeInterval = 0
    var updateBatchCalled = false
    var lastBatchSize = 0
    
    func update(deltaTime: TimeInterval, world: World) {
        updateCalled = true
        lastUpdateDeltaTime = deltaTime
    }
    
    func updateBatch(entities: ArraySlice<Entity>, deltaTime: TimeInterval, world: World) {
        updateBatchCalled = true
        lastBatchSize = entities.count
        lastUpdateDeltaTime = deltaTime
    }
    
    func reset() {
        updateCalled = false
        lastUpdateDeltaTime = 0
        updateBatchCalled = false
        lastBatchSize = 0
    }
}

// MARK: - Mock Economic System

class MockEconomicSystem {
    var currentMarketData: MarketData = MarketData()
    var updateMarketCalled = false
    var calculatePriceCalled: [CommodityType] = []
    var processTransactionCalled: [Transaction] = []
    
    func updateMarket(deltaTime: TimeInterval) {
        updateMarketCalled = true
        // Simulate market fluctuations
        currentMarketData.timestamp = Date()
    }
    
    func calculatePrice(for commodity: CommodityType) -> Double {
        calculatePriceCalled.append(commodity)
        return Double.random(in: 10...1000)
    }
    
    func processTransaction(_ transaction: Transaction) -> TransactionResult {
        processTransactionCalled.append(transaction)
        return TransactionResult(
            success: true,
            finalPrice: transaction.price,
            timestamp: Date()
        )
    }
    
    func reset() {
        currentMarketData = MarketData()
        updateMarketCalled = false
        calculatePriceCalled.removeAll()
        processTransactionCalled.removeAll()
    }
}

// MARK: - Mock Performance Profiler

class MockPerformanceProfiler {
    var measurements: [String: PerformanceMeasurement] = [:]
    var isProfilingEnabled = true
    
    var startProfilingCalled: [String] = []
    var endProfilingCalled: [String] = []
    
    func startProfiling(for identifier: String) {
        guard isProfilingEnabled else { return }
        startProfilingCalled.append(identifier)
    }
    
    func endProfiling(for identifier: String) -> TimeInterval {
        guard isProfilingEnabled else { return 0 }
        endProfilingCalled.append(identifier)
        
        let duration = TimeInterval.random(in: 0.001...0.1) // 1-100ms
        let measurement = PerformanceMeasurement(
            name: identifier,
            times: [duration],
            iterations: 1
        )
        measurements[identifier] = measurement
        
        return duration
    }
    
    func getAverageTime(for identifier: String) -> TimeInterval? {
        return measurements[identifier]?.averageTime
    }
    
    func reset() {
        measurements.removeAll()
        startProfilingCalled.removeAll()
        endProfilingCalled.removeAll()
    }
}

// MARK: - Supporting Types

struct NetworkMessage: Codable, Equatable {
    let id: UUID
    let type: String
    let payload: Data
    let timestamp: Date
    
    init(id: UUID = UUID(), type: String, payload: Data = Data(), timestamp: Date = Date()) {
        self.id = id
        self.type = type
        self.payload = payload
        self.timestamp = timestamp
    }
}

enum NetworkError: Error {
    case notConnected
    case timeout
    case invalidMessage
}

struct MarketData {
    var timestamp = Date()
    var prices: [CommodityType: Double] = [:]
    var volumes: [CommodityType: Int] = [:]
}

enum CommodityType: String, CaseIterable {
    case oil, grain, electronics, textiles, lumber
}

struct Transaction {
    let id: UUID
    let commodity: CommodityType
    let quantity: Int
    let price: Double
    let timestamp: Date
    
    init(commodity: CommodityType, quantity: Int, price: Double) {
        self.id = UUID()
        self.commodity = commodity
        self.quantity = quantity
        self.price = price
        self.timestamp = Date()
    }
}

struct TransactionResult {
    let success: Bool
    let finalPrice: Double
    let timestamp: Date
}

// MARK: - Mock Core Data Stack

class MockCoreDataManager: CoreDataManager {
    var saveContextCalled = false
    var fetchCalled: [String] = []
    var deleteCalled: [NSManagedObject] = []
    
    override func saveContext() {
        saveContextCalled = true
        // Don't actually save in tests
    }
    
    override func fetch<T: NSManagedObject>(_ request: NSFetchRequest<T>) -> [T] {
        fetchCalled.append(String(describing: T.self))
        return [] // Return empty results in tests
    }
    
    override func delete(_ object: NSManagedObject) {
        deleteCalled.append(object)
        // Don't actually delete in tests
    }
    
    func reset() {
        saveContextCalled = false
        fetchCalled.removeAll()
        deleteCalled.removeAll()
    }
}