import XCTest
import Combine
@testable import FlexPort

class GameManagerTests: FlexPortTestCase {
    
    var gameManager: GameManager!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        gameManager = GameManager()
    }
    
    override func tearDownWithError() throws {
        gameManager = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Initialization Tests
    
    func testGameManagerInitialization() throws {
        // Then
        XCTAssertEqual(gameManager.currentScreen, .mainMenu)
        XCTAssertNotNil(gameManager.gameState)
        XCTAssertEqual(gameManager.singularityProgress, 0.0)
    }
    
    func testInitialGameState() throws {
        // Given
        let gameState = gameManager.gameState
        
        // Then
        XCTAssertEqual(gameState.playerAssets.money, 1_000_000)
        XCTAssertTrue(gameState.playerAssets.ships.isEmpty)
        XCTAssertTrue(gameState.playerAssets.warehouses.isEmpty)
        XCTAssertEqual(gameState.playerAssets.reputation, 50.0)
        XCTAssertEqual(gameState.turn, 0)
        XCTAssertTrue(gameState.isGameActive)
        XCTAssertTrue(gameState.aiCompetitors.isEmpty)
    }
    
    // MARK: - Game Flow Tests
    
    func testStartNewGame() throws {
        // Given
        gameManager.currentScreen = .settings
        gameManager.singularityProgress = 0.5
        
        // When
        gameManager.startNewGame()
        
        // Then
        XCTAssertEqual(gameManager.currentScreen, .game)
        XCTAssertEqual(gameManager.gameState.turn, 0)
        XCTAssertTrue(gameManager.gameState.isGameActive)
        XCTAssertEqual(gameManager.gameState.playerAssets.money, 1_000_000)
    }
    
    func testNavigateTo() throws {
        // Given
        XCTAssertEqual(gameManager.currentScreen, .mainMenu)
        
        // When
        gameManager.navigateTo(.settings)
        
        // Then
        XCTAssertEqual(gameManager.currentScreen, .settings)
        
        // When
        gameManager.navigateTo(.game)
        
        // Then
        XCTAssertEqual(gameManager.currentScreen, .game)
    }
    
    // MARK: - Observable Tests
    
    func testCurrentScreenObservable() throws {
        // Given
        let expectation = XCTestExpectation(description: "Current screen changed")
        var receivedScreens: [GameScreen] = []
        
        gameManager.$currentScreen
            .dropFirst() // Skip initial value
            .sink { screen in
                receivedScreens.append(screen)
                if receivedScreens.count == 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        gameManager.navigateTo(.settings)
        gameManager.navigateTo(.game)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedScreens, [.settings, .game])
    }
    
    func testGameStateObservable() throws {
        // Given
        let expectation = XCTestExpectation(description: "Game state changed")
        var stateChangeCount = 0
        
        gameManager.$gameState
            .dropFirst() // Skip initial value
            .sink { _ in
                stateChangeCount += 1
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        gameManager.startNewGame()
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(stateChangeCount, 1)
    }
    
    func testSingularityProgressObservable() throws {
        // Given
        let expectation = XCTestExpectation(description: "Singularity progress changed")
        var progressValues: [Double] = []
        
        gameManager.$singularityProgress
            .dropFirst() // Skip initial value
            .sink { progress in
                progressValues.append(progress)
                if progressValues.count == 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        gameManager.singularityProgress = 0.3
        gameManager.singularityProgress = 0.7
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(progressValues, [0.3, 0.7])
    }
    
    // MARK: - Game State Manipulation Tests
    
    func testPlayerAssetModification() throws {
        // When
        gameManager.gameState.playerAssets.money = 2_000_000
        gameManager.gameState.playerAssets.reputation = 75.0
        
        // Then
        XCTAssertEqual(gameManager.gameState.playerAssets.money, 2_000_000)
        XCTAssertEqual(gameManager.gameState.playerAssets.reputation, 75.0)
    }
    
    func testTurnProgression() throws {
        // Given
        XCTAssertEqual(gameManager.gameState.turn, 0)
        
        // When
        gameManager.gameState.turn += 1
        
        // Then
        XCTAssertEqual(gameManager.gameState.turn, 1)
    }
    
    func testGameActiveState() throws {
        // Given
        XCTAssertTrue(gameManager.gameState.isGameActive)
        
        // When
        gameManager.gameState.isGameActive = false
        
        // Then
        XCTAssertFalse(gameManager.gameState.isGameActive)
    }
    
    // MARK: - AI Competitor Tests
    
    func testAICompetitorAddition() throws {
        // Given
        let competitor = AICompetitor(
            id: UUID(),
            name: "Test AI",
            difficulty: .medium,
            assets: PlayerAssets(),
            strategy: .aggressive
        )
        
        // When
        gameManager.gameState.aiCompetitors.append(competitor)
        
        // Then
        XCTAssertEqual(gameManager.gameState.aiCompetitors.count, 1)
        XCTAssertEqual(gameManager.gameState.aiCompetitors.first?.name, "Test AI")
        XCTAssertEqual(gameManager.gameState.aiCompetitors.first?.difficulty, .medium)
    }
    
    // MARK: - Market Tests
    
    func testMarketInitialization() throws {
        // Given
        let markets = gameManager.gameState.markets
        
        // Then
        XCTAssertNotNil(markets.goodsMarket)
        XCTAssertNotNil(markets.capitalMarket)
    }
    
    // MARK: - Performance Tests
    
    func testGameStateCreationPerformance() throws {
        measure {
            for _ in 0..<1000 {
                _ = GameState()
            }
        }
    }
    
    func testGameManagerCreationPerformance() throws {
        measure {
            for _ in 0..<100 {
                _ = GameManager()
            }
        }
    }
    
    func testNavigationPerformance() throws {
        measure {
            for _ in 0..<1000 {
                gameManager.navigateTo(.game)
                gameManager.navigateTo(.settings)
                gameManager.navigateTo(.mainMenu)
            }
        }
    }
    
    // MARK: - Memory Tests
    
    func testMemoryUsageWithLargeGameState() throws {
        // Given
        let initialMemory = mach_task_basic_info()
        
        // When
        for i in 0..<1000 {
            let ship = Ship(
                id: UUID(),
                name: "Ship \(i)",
                type: .cargo,
                capacity: 1000,
                speed: 10.0,
                location: Port(id: UUID(), name: "Port \(i)", location: (0, 0))
            )
            gameManager.gameState.playerAssets.ships.append(ship)
        }
        
        // Then
        XCTAssertEqual(gameManager.gameState.playerAssets.ships.count, 1000)
        
        // Cleanup
        gameManager.gameState.playerAssets.ships.removeAll()
        XCTAssertTrue(gameManager.gameState.playerAssets.ships.isEmpty)
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentGameStateAccess() throws {
        let expectation = XCTestExpectation(description: "Concurrent access completed")
        let iterations = 100
        var completedTasks = 0
        
        for i in 0..<iterations {
            DispatchQueue.global().async {
                // Simulate concurrent reads and writes
                let currentMoney = self.gameManager.gameState.playerAssets.money
                self.gameManager.gameState.playerAssets.money = currentMoney + Double(i)
                
                DispatchQueue.main.async {
                    completedTasks += 1
                    if completedTasks == iterations {
                        expectation.fulfill()
                    }
                }
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        XCTAssertGreaterThan(gameManager.gameState.playerAssets.money, 1_000_000)
    }
    
    // MARK: - Game State Validation Tests
    
    func testGameStateValidation() throws {
        // Given
        var gameState = gameManager.gameState
        
        // Test valid state
        XCTAssertTrue(gameState.isValid())
        
        // Test invalid money
        gameState.playerAssets.money = -1000
        XCTAssertFalse(gameState.isValid())
        
        // Reset and test invalid reputation
        gameState = GameState()
        gameState.playerAssets.reputation = -10
        XCTAssertFalse(gameState.isValid())
        
        // Reset and test invalid turn
        gameState = GameState()
        gameState.turn = -1
        XCTAssertFalse(gameState.isValid())
    }
}

// MARK: - Extensions for Testing

extension GameState {
    func isValid() -> Bool {
        guard playerAssets.money >= 0,
              playerAssets.reputation >= 0 && playerAssets.reputation <= 100,
              turn >= 0 else {
            return false
        }
        return true
    }
}

// MARK: - Supporting Test Types

struct AICompetitor: Codable {
    let id: UUID
    let name: String
    let difficulty: AIDifficulty
    var assets: PlayerAssets
    let strategy: AIStrategy
}

enum AIDifficulty: String, Codable, CaseIterable {
    case easy, medium, hard, expert
}

enum AIStrategy: String, Codable, CaseIterable {
    case aggressive, defensive, balanced, economic
}

struct Ship: Codable {
    let id: UUID
    let name: String
    let type: ShipType
    let capacity: Int
    let speed: Double
    var location: Port
}

enum ShipType: String, Codable, CaseIterable {
    case cargo, tanker, container, bulk
}

struct Port: Codable {
    let id: UUID
    let name: String
    let location: (Double, Double)
    
    init(id: UUID, name: String, location: (Double, Double)) {
        self.id = id
        self.name = name
        self.location = location
    }
    
    // Codable conformance for tuple
    enum CodingKeys: String, CodingKey {
        case id, name, latitude, longitude
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        location = (latitude, longitude)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(location.0, forKey: .latitude)
        try container.encode(location.1, forKey: .longitude)
    }
}

struct Warehouse: Codable {
    let id: UUID
    let name: String
    let capacity: Int
    var currentStock: [CommodityType: Int]
    let location: Port
}