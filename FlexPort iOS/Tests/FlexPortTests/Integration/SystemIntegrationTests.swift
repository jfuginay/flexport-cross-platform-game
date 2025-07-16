import XCTest
import Combine
@testable import FlexPort

/// Comprehensive integration tests for system interactions
class SystemIntegrationTests: FlexPortTestCase {
    
    var gameManager: GameManager!
    var world: World!
    var analyticsEngine: MockAnalyticsEngine!
    var networkManager: MockNetworkManager!
    var economicSystem: MockEconomicSystem!
    var performanceProfiler: PerformanceProfiler!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Initialize all systems
        gameManager = GameManager()
        world = World()
        analyticsEngine = MockAnalyticsEngine()
        networkManager = MockNetworkManager()
        economicSystem = MockEconomicSystem()
        performanceProfiler = PerformanceProfiler()
        
        // Start analytics session
        analyticsEngine.startSession()
    }
    
    override func tearDownWithError() throws {
        performanceProfiler.setProfilingEnabled(false)
        analyticsEngine.endSession()
        
        gameManager = nil
        world = nil
        analyticsEngine = nil
        networkManager = nil
        economicSystem = nil
        performanceProfiler = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - Game Manager + Analytics Integration
    
    func testGameManagerAnalyticsIntegration() throws {
        // Given
        let expectation = XCTestExpectation(description: "Analytics tracks game events")
        var trackedEvents: [AnalyticsEvent] = []
        
        analyticsEngine.$trackEventCalled
            .sink { events in
                trackedEvents = events
                if events.count >= 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        gameManager.startNewGame()
        analyticsEngine.trackEvent(AnalyticsEvent(
            type: .gameplay,
            action: "game_started",
            properties: ["initial_money": gameManager.gameState.playerAssets.money],
            timestamp: Date()
        ))
        
        gameManager.navigateTo(.settings)
        analyticsEngine.trackEvent(AnalyticsEvent(
            type: .userAction,
            action: "settings_opened",
            properties: [:],
            timestamp: Date()
        ))
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(trackedEvents.count, 2)
        XCTAssertEqual(trackedEvents[0].action, "game_started")
        XCTAssertEqual(trackedEvents[1].action, "settings_opened")
    }
    
    // MARK: - ECS + Performance Integration
    
    func testECSPerformanceIntegration() throws {
        // Given
        performanceProfiler.setProfilingEnabled(true)
        
        // Create entities with components
        let entities = (0..<1000).map { _ in
            let entity = world.entityManager.createEntity()
            world.addComponent(TestPositionComponent(x: 0, y: 0), to: entity)
            world.addComponent(TestVelocityComponent(dx: 1, dy: 1), to: entity)
            return entity
        }
        
        // Add movement system
        let movementSystem = TestMovementSystem()
        world.addSystem(movementSystem)
        
        // When
        let (_, duration) = performanceProfiler.measure(
            identifier: "ecs_update_1000_entities",
            category: .ecs
        ) {
            world.update(deltaTime: 0.016) // 60 FPS
        }
        
        // Then
        XCTAssertLessThan(duration, 0.016, "ECS update should complete within frame time")
        XCTAssertEqual(world.entityManager.entities.count, 1000)
        
        // Verify performance metrics were recorded
        let summary = performanceProfiler.getPerformanceSummary(for: .ecs)
        XCTAssertNotNil(summary.averageDuration)
        XCTAssertGreaterThan(summary.sampleCount, 0)
    }
    
    // MARK: - Economic System + Analytics Integration
    
    func testEconomicSystemAnalyticsIntegration() throws {
        // Given
        let tradeTransaction = Transaction(
            commodity: .oil,
            quantity: 100,
            price: 50000
        )
        
        // When
        let result = economicSystem.processTransaction(tradeTransaction)
        
        // Track the transaction in analytics
        analyticsEngine.trackEvent(AnalyticsEvent(
            type: .gameplay,
            action: "trade_completed",
            properties: [
                "commodity": tradeTransaction.commodity.rawValue,
                "quantity": tradeTransaction.quantity,
                "price": tradeTransaction.price,
                "success": result.success
            ],
            timestamp: Date()
        ))
        
        // Update player state
        var gameState = gameManager.gameState
        if result.success {
            gameState.playerAssets.money -= result.finalPrice
        }
        
        let stateSnapshot = GameStateSnapshot(
            turn: gameState.turn,
            playerMoney: gameState.playerAssets.money,
            playerReputation: gameState.playerAssets.reputation,
            shipsCount: gameState.playerAssets.ships.count,
            warehousesCount: gameState.playerAssets.warehouses.count,
            activeTrades: 1
        )
        analyticsEngine.updatePlayerState(stateSnapshot)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertEqual(economicSystem.processTransactionCalled.count, 1)
        XCTAssertEqual(analyticsEngine.trackEventCalled.count, 1)
        XCTAssertEqual(analyticsEngine.updatePlayerStateCalled.count, 1)
        
        let trackedEvent = analyticsEngine.trackEventCalled.first!
        XCTAssertEqual(trackedEvent.action, "trade_completed")
        XCTAssertEqual(trackedEvent.properties["commodity"] as? String, "oil")
    }
    
    // MARK: - Multiplayer + Network Integration
    
    func testMultiplayerNetworkIntegration() async throws {
        // Given
        try await networkManager.connect()
        
        let playerJoinMessage = NetworkMessage(
            type: "player_join",
            payload: try JSONEncoder().encode(["playerId": "test-player"])
        )
        
        let tradeMessage = NetworkMessage(
            type: "trade_request",
            payload: try JSONEncoder().encode([
                "commodity": "oil",
                "quantity": 50,
                "price": 25000
            ])
        )
        
        // When
        try await networkManager.sendMessage(playerJoinMessage)
        try await networkManager.sendMessage(tradeMessage)
        
        // Simulate receiving messages
        networkManager.simulateReceivedMessage(NetworkMessage(
            type: "trade_response",
            payload: try JSONEncoder().encode(["accepted": true])
        ))
        
        // Then
        XCTAssertTrue(networkManager.isConnected)
        XCTAssertEqual(networkManager.sendMessageCalled.count, 2)
        XCTAssertEqual(networkManager.receivedMessages.count, 1)
        
        // Verify messages were sent correctly
        XCTAssertEqual(networkManager.sendMessageCalled[0].type, "player_join")
        XCTAssertEqual(networkManager.sendMessageCalled[1].type, "trade_request")
        XCTAssertEqual(networkManager.receivedMessages[0].type, "trade_response")
    }
    
    // MARK: - AI + Performance + Analytics Integration
    
    func testAISystemFullIntegration() async throws {
        // Given
        let aiSystem = MockAISystem()
        world.addSystem(aiSystem)
        
        // Create AI entities
        let aiEntities = (0..<10).map { i in
            let entity = world.entityManager.createEntity()
            world.addComponent(TestPositionComponent(x: Double(i), y: Double(i)), to: entity)
            world.addComponent(TestHealthComponent(health: 100), to: entity)
            return entity
        }
        
        // When - Measure AI processing performance
        let (_, aiDuration) = performanceProfiler.measure(
            identifier: "ai_system_update",
            category: .ai
        ) {
            aiSystem.update(deltaTime: 0.016, world: world)
        }
        
        // Track AI performance in analytics
        if aiDuration > 0.01 { // 10ms threshold
            analyticsEngine.trackEvent(AnalyticsEvent(
                type: .performance,
                action: "ai_slow_update",
                properties: [
                    "duration_ms": aiDuration * 1000,
                    "entity_count": aiEntities.count
                ],
                timestamp: Date()
            ))
        }
        
        // Then
        XCTAssertTrue(aiSystem.updateCalled)
        XCTAssertEqual(aiSystem.lastUpdateDeltaTime, 0.016)
        XCTAssertLessThan(aiDuration, 0.016, "AI update should complete within frame time")
        
        // Verify performance tracking
        let aiSummary = performanceProfiler.getPerformanceSummary(for: .ai)
        XCTAssertNotNil(aiSummary.averageDuration)
    }
    
    // MARK: - Full System Integration Test
    
    func testCompleteSystemIntegration() async throws {
        // Given - Set up complete game environment
        performanceProfiler.setProfilingEnabled(true)
        try await networkManager.connect()
        
        // Create game world with entities
        let playerEntity = world.entityManager.createEntity()
        world.addComponent(TestPositionComponent(x: 0, y: 0), to: playerEntity)
        world.addComponent(TestHealthComponent(health: 100), to: playerEntity)
        
        let aiEntities = (0..<5).map { i in
            let entity = world.entityManager.createEntity()
            world.addComponent(TestPositionComponent(x: Double(i * 10), y: Double(i * 10)), to: entity)
            world.addComponent(TestHealthComponent(health: 80), to: entity)
            return entity
        }
        
        // Add systems
        let aiSystem = MockAISystem()
        world.addSystem(aiSystem)
        
        // When - Simulate game turn
        let turnStartTime = Date()
        
        // 1. Update ECS
        let (_, ecsTime) = performanceProfiler.measure(
            identifier: "complete_ecs_update",
            category: .ecs
        ) {
            world.update(deltaTime: 0.016)
        }
        
        // 2. Process economic updates
        let (_, economicTime) = performanceProfiler.measure(
            identifier: "economic_update",
            category: .general
        ) {
            economicSystem.updateMarket(deltaTime: 0.016)
        }
        
        // 3. Handle network messages
        let networkMessage = NetworkMessage(
            type: "turn_update",
            payload: try JSONEncoder().encode(["turn": gameManager.gameState.turn + 1])
        )
        try await networkManager.sendMessage(networkMessage)
        
        // 4. Update game state
        gameManager.gameState.turn += 1
        
        // 5. Track analytics
        let gameStateSnapshot = GameStateSnapshot(
            turn: gameManager.gameState.turn,
            playerMoney: gameManager.gameState.playerAssets.money,
            playerReputation: gameManager.gameState.playerAssets.reputation,
            shipsCount: gameManager.gameState.playerAssets.ships.count,
            warehousesCount: gameManager.gameState.playerAssets.warehouses.count,
            activeTrades: 0
        )
        analyticsEngine.updatePlayerState(gameStateSnapshot)
        
        analyticsEngine.trackEvent(AnalyticsEvent(
            type: .gameplay,
            action: "turn_completed",
            properties: [
                "turn": gameManager.gameState.turn,
                "ecs_time_ms": ecsTime * 1000,
                "economic_time_ms": economicTime * 1000,
                "total_entities": world.entityManager.entities.count
            ],
            timestamp: Date()
        ))
        
        let totalTurnTime = Date().timeIntervalSince(turnStartTime)
        
        // Then - Verify all systems worked together
        XCTAssertEqual(gameManager.gameState.turn, 1)
        XCTAssertTrue(aiSystem.updateCalled)
        XCTAssertTrue(economicSystem.updateMarketCalled)
        XCTAssertEqual(networkManager.sendMessageCalled.count, 1)
        XCTAssertEqual(analyticsEngine.updatePlayerStateCalled.count, 1)
        XCTAssertEqual(analyticsEngine.trackEventCalled.count, 1)
        
        // Verify performance
        XCTAssertLessThan(ecsTime, 0.010, "ECS should complete in under 10ms")
        XCTAssertLessThan(economicTime, 0.005, "Economic update should complete in under 5ms")
        XCTAssertLessThan(totalTurnTime, 0.100, "Complete turn should complete in under 100ms")
        
        // Verify analytics data
        let trackedEvent = analyticsEngine.trackEventCalled.first!
        XCTAssertEqual(trackedEvent.action, "turn_completed")
        XCTAssertEqual(trackedEvent.properties["turn"] as? Int, 1)
        
        let stateSnapshot = analyticsEngine.updatePlayerStateCalled.first!
        XCTAssertEqual(stateSnapshot.turn, 1)
    }
    
    // MARK: - Error Handling Integration
    
    func testErrorHandlingIntegration() async throws {
        // Given
        let crashReporter = CrashReporter()
        crashReporter.setEnabled(true)
        
        // When - Simulate various error conditions
        
        // 1. Network error
        networkManager.isConnected = false
        do {
            try await networkManager.sendMessage(NetworkMessage(type: "test", payload: Data()))
            XCTFail("Should have thrown network error")
        } catch {
            crashReporter.reportError(
                error,
                context: "Network integration test",
                severity: .medium,
                additionalInfo: ["operation": "send_message"]
            )
        }
        
        // 2. Performance error
        let slowOperation = {
            Thread.sleep(forTimeInterval: 0.1) // Simulate slow operation
        }
        
        let (_, duration) = performanceProfiler.measure(
            identifier: "slow_operation_test",
            category: .general,
            operation: slowOperation
        )
        
        if duration > 0.05 { // 50ms threshold
            crashReporter.reportPerformanceIssue(
                operation: "slow_operation_test",
                duration: duration,
                threshold: 0.05
            )
        }
        
        // 3. Game state error
        let invalidGameState = GameState()
        // This would trigger validation errors in a real implementation
        
        // Then
        let errorReports = crashReporter.getErrorReports()
        XCTAssertGreaterThanOrEqual(errorReports.count, 2)
        
        // Verify error reporting
        let networkError = errorReports.first { $0.context.contains("Network") }
        XCTAssertNotNil(networkError)
        XCTAssertEqual(networkError?.severity, .medium)
        
        let performanceError = errorReports.first { $0.context.contains("Performance") }
        XCTAssertNotNil(performanceError)
    }
    
    // MARK: - Memory Management Integration
    
    func testMemoryManagementIntegration() throws {
        // Given
        let initialMemory = getMemoryUsage()
        var entities: [Entity] = []
        
        // When - Create and destroy many entities
        for _ in 0..<1000 {
            let entity = world.entityManager.createEntity()
            world.addComponent(TestPositionComponent(x: 0, y: 0), to: entity)
            world.addComponent(TestVelocityComponent(dx: 1, dy: 1), to: entity)
            world.addComponent(TestHealthComponent(health: 100), to: entity)
            entities.append(entity)
        }
        
        let peakMemory = getMemoryUsage()
        
        // Clean up entities
        for entity in entities {
            world.entityManager.destroyEntity(entity)
        }
        
        // Force garbage collection
        autoreleasepool { }
        
        let finalMemory = getMemoryUsage()
        
        // Then
        XCTAssertGreaterThan(peakMemory, initialMemory, "Memory should increase with entities")
        XCTAssertLessThan(finalMemory - initialMemory, 50.0, "Memory should be mostly cleaned up (within 50MB)")
        XCTAssertEqual(world.entityManager.entities.count, 0, "All entities should be destroyed")
        
        // Track memory usage in analytics
        analyticsEngine.trackEvent(AnalyticsEvent(
            type: .performance,
            action: "memory_test_completed",
            properties: [
                "initial_memory_mb": initialMemory,
                "peak_memory_mb": peakMemory,
                "final_memory_mb": finalMemory,
                "entities_created": 1000
            ],
            timestamp: Date()
        ))
    }
    
    // MARK: - Concurrent Operations Integration
    
    func testConcurrentOperationsIntegration() async throws {
        // Given
        let operationCount = 100
        let expectation = XCTestExpectation(description: "Concurrent operations completed")
        expectation.expectedFulfillmentCount = operationCount
        
        // When - Run concurrent operations across different systems
        await withTaskGroup(of: Void.self) { group in
            
            // ECS operations
            for i in 0..<operationCount/4 {
                group.addTask {
                    let entity = self.world.entityManager.createEntity()
                    self.world.addComponent(TestPositionComponent(x: Double(i), y: Double(i)), to: entity)
                    expectation.fulfill()
                }
            }
            
            // Analytics operations
            for i in 0..<operationCount/4 {
                group.addTask {
                    self.analyticsEngine.trackEvent(AnalyticsEvent(
                        type: .userAction,
                        action: "concurrent_test_\(i)",
                        properties: ["index": i],
                        timestamp: Date()
                    ))
                    expectation.fulfill()
                }
            }
            
            // Economic operations
            for i in 0..<operationCount/4 {
                group.addTask {
                    _ = self.economicSystem.calculatePrice(for: .oil)
                    expectation.fulfill()
                }
            }
            
            // Performance measurements
            for i in 0..<operationCount/4 {
                group.addTask {
                    let (_, _) = self.performanceProfiler.measure(
                        identifier: "concurrent_op_\(i)",
                        category: .general
                    ) {
                        Thread.sleep(forTimeInterval: 0.001) // 1ms operation
                    }
                    expectation.fulfill()
                }
            }
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 10.0)
        
        XCTAssertEqual(world.entityManager.entities.count, operationCount/4)
        XCTAssertEqual(analyticsEngine.trackEventCalled.count, operationCount/4)
        XCTAssertEqual(economicSystem.calculatePriceCalled.count, operationCount/4)
    }
    
    // MARK: - Helper Methods
    
    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024 / 1024 // Convert to MB
        }
        
        return 0
    }
}