import XCTest
import Combine
import Foundation
@testable import FlexPort

/// Base test case class providing common testing utilities and setup
class FlexPortTestCase: XCTestCase {
    
    // MARK: - Properties
    
    var cancellables: Set<AnyCancellable> = []
    var testBundle: Bundle { Bundle(for: type(of: self)) }
    
    // Common test objects
    var mockGameManager: MockGameManager!
    var mockWorld: MockWorld!
    var mockAnalyticsEngine: MockAnalyticsEngine!
    var mockNetworkManager: MockNetworkManager!
    
    // Test timeouts
    static let defaultTimeout: TimeInterval = 5.0
    static let longTimeout: TimeInterval = 30.0
    static let shortTimeout: TimeInterval = 1.0
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Clear UserDefaults for clean test state
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        
        // Initialize mock objects
        mockGameManager = MockGameManager()
        mockWorld = MockWorld()
        mockAnalyticsEngine = MockAnalyticsEngine()
        mockNetworkManager = MockNetworkManager()
        
        // Clear cancellables
        cancellables.removeAll()
    }
    
    override func tearDownWithError() throws {
        // Cancel all publishers
        cancellables.removeAll()
        
        // Clean up mock objects
        mockGameManager = nil
        mockWorld = nil
        mockAnalyticsEngine = nil
        mockNetworkManager = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - Testing Utilities
    
    /// Wait for a publisher to emit a value or complete
    func waitForPublisher<T: Publisher>(
        _ publisher: T,
        timeout: TimeInterval = defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> T.Output where T.Failure == Never {
        let expectation = XCTestExpectation(description: "Publisher completion")
        var result: T.Output?
        
        publisher
            .sink { value in
                result = value
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: timeout)
        
        guard let output = result else {
            XCTFail("Publisher did not emit a value within timeout", file: file, line: line)
            throw TestError.publisherTimeout
        }
        
        return output
    }
    
    /// Wait for an async operation to complete
    func waitForAsync<T>(
        timeout: TimeInterval = defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw TestError.asyncTimeout
            }
            
            guard let result = try await group.next() else {
                throw TestError.asyncTimeout
            }
            
            group.cancelAll()
            return result
        }
    }
    
    /// Create a test entity with components for ECS testing
    func createTestEntity(in world: World = World()) -> Entity {
        let entity = world.entityManager.createEntity()
        
        // Add basic test components
        world.addComponent(TestPositionComponent(x: 0, y: 0), to: entity)
        world.addComponent(TestVelocityComponent(dx: 1, dy: 1), to: entity)
        
        return entity
    }
    
    /// Create mock game state for testing
    func createMockGameState() -> GameState {
        var gameState = GameState()
        gameState.playerAssets.money = 1_000_000
        gameState.turn = 1
        gameState.isGameActive = true
        return gameState
    }
    
    /// Measure performance of a block of code
    func measurePerformance<T>(
        name: String = #function,
        iterations: Int = 10,
        operation: () throws -> T
    ) throws -> PerformanceMeasurement {
        var times: [TimeInterval] = []
        
        for _ in 0..<iterations {
            let startTime = CFAbsoluteTimeGetCurrent()
            _ = try operation()
            let endTime = CFAbsoluteTimeGetCurrent()
            times.append(endTime - startTime)
        }
        
        let measurement = PerformanceMeasurement(
            name: name,
            times: times,
            iterations: iterations
        )
        
        print("Performance measurement for \(name):")
        print("  Average: \(measurement.averageTime * 1000)ms")
        print("  Min: \(measurement.minTime * 1000)ms")
        print("  Max: \(measurement.maxTime * 1000)ms")
        print("  Standard deviation: \(measurement.standardDeviation * 1000)ms")
        
        return measurement
    }
    
    /// Assert that two values are approximately equal (for floating point comparisons)
    func XCTAssertApproximatelyEqual<T: FloatingPoint>(
        _ expression1: T,
        _ expression2: T,
        accuracy: T,
        _ message: String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertEqual(expression1, expression2, accuracy: accuracy, message, file: file, line: line)
    }
    
    /// Assert that a code block throws a specific error
    func XCTAssertThrowsSpecificError<T, E: Error & Equatable>(
        _ expression: @autoclosure () throws -> T,
        expectedError: E,
        _ message: String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try expression(), message, file: file, line: line) { error in
            if let specificError = error as? E {
                XCTAssertEqual(specificError, expectedError, file: file, line: line)
            } else {
                XCTFail("Expected error of type \(E.self), but got \(type(of: error))", file: file, line: line)
            }
        }
    }
}

// MARK: - Test Error Types

enum TestError: Error, Equatable {
    case publisherTimeout
    case asyncTimeout
    case mockFailure(String)
    case performanceThresholdExceeded(expected: TimeInterval, actual: TimeInterval)
}

// MARK: - Performance Measurement

struct PerformanceMeasurement {
    let name: String
    let times: [TimeInterval]
    let iterations: Int
    
    var averageTime: TimeInterval {
        times.reduce(0, +) / Double(times.count)
    }
    
    var minTime: TimeInterval {
        times.min() ?? 0
    }
    
    var maxTime: TimeInterval {
        times.max() ?? 0
    }
    
    var standardDeviation: TimeInterval {
        let avg = averageTime
        let variance = times.map { pow($0 - avg, 2) }.reduce(0, +) / Double(times.count)
        return sqrt(variance)
    }
}

// MARK: - Test Components

struct TestPositionComponent: Component {
    let id = UUID()
    var x: Double
    var y: Double
}

struct TestVelocityComponent: Component {
    let id = UUID()
    var dx: Double
    var dy: Double
}

struct TestHealthComponent: Component {
    let id = UUID()
    var health: Int
    var maxHealth: Int
    
    init(health: Int = 100, maxHealth: Int = 100) {
        self.health = health
        self.maxHealth = maxHealth
    }
}