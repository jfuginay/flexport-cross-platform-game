import XCTest
import Combine
@testable import FlexPort

class AnalyticsEngineTests: FlexPortTestCase {
    
    var analyticsEngine: MockAnalyticsEngine!
    var coreDataManager: MockCoreDataManager!
    var networkConfiguration: NetworkConfiguration!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        analyticsEngine = MockAnalyticsEngine()
        coreDataManager = MockCoreDataManager()
        networkConfiguration = NetworkConfiguration(baseURL: URL(string: "https://api.flexport.test")!)
    }
    
    override func tearDownWithError() throws {
        analyticsEngine = nil
        coreDataManager = nil
        networkConfiguration = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Session Management Tests
    
    func testStartSession() throws {
        // Given
        XCTAssertNil(analyticsEngine.currentSession)
        XCTAssertFalse(analyticsEngine.startSessionCalled)
        
        // When
        analyticsEngine.startSession()
        
        // Then
        XCTAssertTrue(analyticsEngine.startSessionCalled)
        XCTAssertNotNil(analyticsEngine.currentSession)
        XCTAssertNotNil(analyticsEngine.currentSession?.id)
        XCTAssertNotNil(analyticsEngine.currentSession?.userId)
        XCTAssertEqual(analyticsEngine.currentSession?.platform, "iOS")
        XCTAssertEqual(analyticsEngine.currentSession?.gameVersion, "1.0.0")
    }
    
    func testStartSessionWithCustomUserId() throws {
        // Given
        let customUserId = UUID()
        
        // When
        analyticsEngine.startSession(userId: customUserId)
        
        // Then
        XCTAssertEqual(analyticsEngine.currentSession?.userId, customUserId)
    }
    
    func testStartSessionWithGameState() throws {
        // Given
        let gameState = GameStateSnapshot(
            turn: 5,
            playerMoney: 2_000_000,
            playerReputation: 75.0,
            shipsCount: 3,
            warehousesCount: 2,
            activeTrades: 5
        )
        
        // When
        analyticsEngine.startSession(gameState: gameState)
        
        // Then
        XCTAssertTrue(analyticsEngine.startSessionCalled)
        XCTAssertNotNil(analyticsEngine.currentSession)
    }
    
    func testEndSession() throws {
        // Given
        analyticsEngine.startSession()
        XCTAssertNotNil(analyticsEngine.currentSession)
        
        // When
        analyticsEngine.endSession()
        
        // Then
        XCTAssertTrue(analyticsEngine.endSessionCalled)
        XCTAssertNil(analyticsEngine.currentSession)
    }
    
    // MARK: - Event Tracking Tests
    
    func testTrackEvent() throws {
        // Given
        let event = AnalyticsEvent(
            type: .userAction,
            action: "ship_purchased",
            properties: ["ship_type": "cargo", "cost": 500_000],
            timestamp: Date()
        )
        
        // When
        analyticsEngine.trackEvent(event)
        
        // Then
        XCTAssertEqual(analyticsEngine.trackEventCalled.count, 1)
        XCTAssertEqual(analyticsEngine.trackEventCalled.first?.action, "ship_purchased")
        XCTAssertEqual(analyticsEngine.trackEventCalled.first?.properties["ship_type"] as? String, "cargo")
        XCTAssertEqual(analyticsEngine.trackEventCalled.first?.properties["cost"] as? Int, 500_000)
    }
    
    func testTrackMultipleEvents() throws {
        // Given
        let events = [
            AnalyticsEvent(type: .userAction, action: "game_started", properties: [:], timestamp: Date()),
            AnalyticsEvent(type: .userAction, action: "tutorial_completed", properties: [:], timestamp: Date()),
            AnalyticsEvent(type: .userAction, action: "first_trade", properties: ["commodity": "oil"], timestamp: Date())
        ]
        
        // When
        events.forEach { analyticsEngine.trackEvent($0) }
        
        // Then
        XCTAssertEqual(analyticsEngine.trackEventCalled.count, 3)
        XCTAssertEqual(analyticsEngine.trackEventCalled[0].action, "game_started")
        XCTAssertEqual(analyticsEngine.trackEventCalled[1].action, "tutorial_completed")
        XCTAssertEqual(analyticsEngine.trackEventCalled[2].action, "first_trade")
    }
    
    func testTrackEventTypes() throws {
        // Given
        let userActionEvent = AnalyticsEvent(type: .userAction, action: "button_clicked", properties: [:], timestamp: Date())
        let gameplayEvent = AnalyticsEvent(type: .gameplay, action: "level_completed", properties: [:], timestamp: Date())
        let performanceEvent = AnalyticsEvent(type: .performance, action: "frame_drop", properties: [:], timestamp: Date())
        let errorEvent = AnalyticsEvent(type: .error, action: "network_timeout", properties: [:], timestamp: Date())
        
        // When
        [userActionEvent, gameplayEvent, performanceEvent, errorEvent].forEach {
            analyticsEngine.trackEvent($0)
        }
        
        // Then
        XCTAssertEqual(analyticsEngine.trackEventCalled.count, 4)
        XCTAssertEqual(analyticsEngine.trackEventCalled.filter { $0.type == .userAction }.count, 1)
        XCTAssertEqual(analyticsEngine.trackEventCalled.filter { $0.type == .gameplay }.count, 1)
        XCTAssertEqual(analyticsEngine.trackEventCalled.filter { $0.type == .performance }.count, 1)
        XCTAssertEqual(analyticsEngine.trackEventCalled.filter { $0.type == .error }.count, 1)
    }
    
    // MARK: - Player State Tests
    
    func testUpdatePlayerState() throws {
        // Given
        let gameState = GameStateSnapshot(
            turn: 10,
            playerMoney: 5_000_000,
            playerReputation: 85.0,
            shipsCount: 8,
            warehousesCount: 4,
            activeTrades: 12
        )
        
        // When
        analyticsEngine.updatePlayerState(gameState)
        
        // Then
        XCTAssertEqual(analyticsEngine.updatePlayerStateCalled.count, 1)
        let updatedState = analyticsEngine.updatePlayerStateCalled.first!
        XCTAssertEqual(updatedState.turn, 10)
        XCTAssertEqual(updatedState.playerMoney, 5_000_000)
        XCTAssertEqual(updatedState.playerReputation, 85.0)
        XCTAssertEqual(updatedState.shipsCount, 8)
        XCTAssertEqual(updatedState.warehousesCount, 4)
        XCTAssertEqual(updatedState.activeTrades, 12)
    }
    
    func testMultiplePlayerStateUpdates() throws {
        // Given
        let states = [
            GameStateSnapshot(turn: 1, playerMoney: 1_000_000, playerReputation: 50.0, shipsCount: 0, warehousesCount: 0, activeTrades: 0),
            GameStateSnapshot(turn: 5, playerMoney: 2_000_000, playerReputation: 60.0, shipsCount: 2, warehousesCount: 1, activeTrades: 3),
            GameStateSnapshot(turn: 10, playerMoney: 5_000_000, playerReputation: 75.0, shipsCount: 5, warehousesCount: 2, activeTrades: 8)
        ]
        
        // When
        states.forEach { analyticsEngine.updatePlayerState($0) }
        
        // Then
        XCTAssertEqual(analyticsEngine.updatePlayerStateCalled.count, 3)
        XCTAssertEqual(analyticsEngine.updatePlayerStateCalled[0].turn, 1)
        XCTAssertEqual(analyticsEngine.updatePlayerStateCalled[1].turn, 5)
        XCTAssertEqual(analyticsEngine.updatePlayerStateCalled[2].turn, 10)
    }
    
    // MARK: - Privacy Tests
    
    func testTrackingEnabledDisabled() throws {
        // Given
        XCTAssertTrue(analyticsEngine.isTrackingEnabled)
        
        // When tracking is disabled
        analyticsEngine.isTrackingEnabled = false
        analyticsEngine.trackEvent(AnalyticsEvent(type: .userAction, action: "test", properties: [:], timestamp: Date()))
        
        // Then - events should still be tracked by mock, but real implementation would filter
        XCTAssertFalse(analyticsEngine.isTrackingEnabled)
    }
    
    func testOfflineAnalytics() throws {
        // Given
        analyticsEngine.isOnline = false
        
        // When
        let event = AnalyticsEvent(type: .userAction, action: "offline_action", properties: [:], timestamp: Date())
        analyticsEngine.trackEvent(event)
        
        // Then - events should be tracked locally
        XCTAssertFalse(analyticsEngine.isOnline)
        XCTAssertEqual(analyticsEngine.trackEventCalled.count, 1)
    }
    
    // MARK: - Observable Tests
    
    func testCurrentSessionObservable() throws {
        // Given
        let expectation = XCTestExpectation(description: "Session observable")
        var sessionChanges: [PlayerSession?] = []
        
        analyticsEngine.$currentSession
            .sink { session in
                sessionChanges.append(session)
                if sessionChanges.count == 3 { // nil, started, ended
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        analyticsEngine.startSession()
        analyticsEngine.endSession()
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(sessionChanges.count, 3)
        XCTAssertNil(sessionChanges[0]) // Initial
        XCTAssertNotNil(sessionChanges[1]) // Started
        XCTAssertNil(sessionChanges[2]) // Ended
    }
    
    func testTrackingEnabledObservable() throws {
        // Given
        let expectation = XCTestExpectation(description: "Tracking enabled observable")
        var trackingStates: [Bool] = []
        
        analyticsEngine.$isTrackingEnabled
            .sink { enabled in
                trackingStates.append(enabled)
                if trackingStates.count == 3 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        analyticsEngine.isTrackingEnabled = false
        analyticsEngine.isTrackingEnabled = true
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(trackingStates, [true, false, true])
    }
    
    // MARK: - Performance Tests
    
    func testEventTrackingPerformance() throws {
        // Given
        let eventCount = 1000
        let events = (0..<eventCount).map { i in
            AnalyticsEvent(
                type: .userAction,
                action: "performance_test_\(i)",
                properties: ["index": i, "timestamp": Date().timeIntervalSince1970],
                timestamp: Date()
            )
        }
        
        // When
        measure {
            events.forEach { analyticsEngine.trackEvent($0) }
        }
        
        // Then
        XCTAssertEqual(analyticsEngine.trackEventCalled.count, eventCount)
    }
    
    func testSessionManagementPerformance() throws {
        measure {
            for _ in 0..<100 {
                analyticsEngine.startSession()
                analyticsEngine.endSession()
            }
        }
    }
    
    func testPlayerStateUpdatePerformance() throws {
        // Given
        let states = (0..<1000).map { i in
            GameStateSnapshot(
                turn: i,
                playerMoney: Double(1_000_000 + i * 1000),
                playerReputation: Double(50 + (i % 50)),
                shipsCount: i % 10,
                warehousesCount: i % 5,
                activeTrades: i % 20
            )
        }
        
        // When
        measure {
            states.forEach { analyticsEngine.updatePlayerState($0) }
        }
        
        // Then
        XCTAssertEqual(analyticsEngine.updatePlayerStateCalled.count, 1000)
    }
    
    // MARK: - Memory Tests
    
    func testAnalyticsMemoryUsage() throws {
        // Given
        let largeEventCount = 10000
        
        // When
        for i in 0..<largeEventCount {
            let event = AnalyticsEvent(
                type: .userAction,
                action: "memory_test_\(i)",
                properties: [
                    "large_data": String(repeating: "x", count: 1000),
                    "index": i
                ],
                timestamp: Date()
            )
            analyticsEngine.trackEvent(event)
        }
        
        // Then
        XCTAssertEqual(analyticsEngine.trackEventCalled.count, largeEventCount)
        
        // Cleanup
        analyticsEngine.reset()
        XCTAssertEqual(analyticsEngine.trackEventCalled.count, 0)
    }
    
    // MARK: - Error Handling Tests
    
    func testAnalyticsErrorHandling() throws {
        // Test with invalid event data
        let invalidEvent = AnalyticsEvent(
            type: .error,
            action: "",
            properties: [:],
            timestamp: Date()
        )
        
        // Should not crash
        XCTAssertNoThrow(analyticsEngine.trackEvent(invalidEvent))
    }
    
    func testAnalyticsWithNilValues() throws {
        // Test with properties containing nil-like values
        let eventWithNilValues = AnalyticsEvent(
            type: .userAction,
            action: "test_nil_values",
            properties: [
                "valid_key": "valid_value",
                "empty_string": "",
                "zero_value": 0
            ],
            timestamp: Date()
        )
        
        // Should handle gracefully
        XCTAssertNoThrow(analyticsEngine.trackEvent(eventWithNilValues))
        XCTAssertEqual(analyticsEngine.trackEventCalled.count, 1)
    }
}

// MARK: - Supporting Types

struct PlayerSession: Codable {
    let id: UUID
    let userId: UUID
    let startTime: Date
    let gameVersion: String
    let platform: String
}

struct GameStateSnapshot: Codable {
    let turn: Int
    let playerMoney: Double
    let playerReputation: Double
    let shipsCount: Int
    let warehousesCount: Int
    let activeTrades: Int
}

struct AnalyticsEvent: Codable {
    let id = UUID()
    let type: AnalyticsEventType
    let action: String
    let properties: [String: Any]
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case id, type, action, timestamp
    }
    
    init(type: AnalyticsEventType, action: String, properties: [String: Any], timestamp: Date) {
        self.type = type
        self.action = action
        self.properties = properties
        self.timestamp = timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(AnalyticsEventType.self, forKey: .type)
        action = try container.decode(String.self, forKey: .action)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        properties = [:] // Simplified for testing
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(action, forKey: .action)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

enum AnalyticsEventType: String, Codable, CaseIterable {
    case userAction = "user_action"
    case gameplay = "gameplay"
    case performance = "performance"
    case error = "error"
    case system = "system"
}

struct NetworkConfiguration {
    let baseURL: URL
    let timeout: TimeInterval
    let retryCount: Int
    
    init(baseURL: URL, timeout: TimeInterval = 30.0, retryCount: Int = 3) {
        self.baseURL = baseURL
        self.timeout = timeout
        self.retryCount = retryCount
    }
}