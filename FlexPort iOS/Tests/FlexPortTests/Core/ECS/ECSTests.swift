import XCTest
import Foundation
@testable import FlexPort

class ECSTests: FlexPortTestCase {
    
    var world: World!
    var testSystem: MockAISystem!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        world = World()
        testSystem = MockAISystem()
    }
    
    override func tearDownWithError() throws {
        world = nil
        testSystem = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Entity Tests
    
    func testEntityCreation() throws {
        // Given
        let initialEntityCount = world.entityManager.entities.count
        
        // When
        let entity = world.entityManager.createEntity()
        
        // Then
        XCTAssertNotNil(entity.id)
        XCTAssertEqual(world.entityManager.entities.count, initialEntityCount + 1)
        XCTAssertTrue(world.entityManager.entities.contains(entity))
    }
    
    func testEntityDestruction() throws {
        // Given
        let entity = world.entityManager.createEntity()
        XCTAssertTrue(world.entityManager.entities.contains(entity))
        
        // When
        world.entityManager.destroyEntity(entity)
        
        // Then
        XCTAssertFalse(world.entityManager.entities.contains(entity))
    }
    
    func testEntityUniqueIDs() throws {
        // Given & When
        let entity1 = world.entityManager.createEntity()
        let entity2 = world.entityManager.createEntity()
        let entity3 = world.entityManager.createEntity()
        
        // Then
        XCTAssertNotEqual(entity1.id, entity2.id)
        XCTAssertNotEqual(entity2.id, entity3.id)
        XCTAssertNotEqual(entity1.id, entity3.id)
    }
    
    // MARK: - Component Tests
    
    func testComponentAddition() throws {
        // Given
        let entity = world.entityManager.createEntity()
        let position = TestPositionComponent(x: 10, y: 20)
        
        // When
        world.addComponent(position, to: entity)
        
        // Then
        let retrievedPosition: TestPositionComponent? = world.getComponent(TestPositionComponent.self, for: entity)
        XCTAssertNotNil(retrievedPosition)
        XCTAssertEqual(retrievedPosition?.x, 10)
        XCTAssertEqual(retrievedPosition?.y, 20)
    }
    
    func testComponentRemoval() throws {
        // Given
        let entity = world.entityManager.createEntity()
        let position = TestPositionComponent(x: 10, y: 20)
        world.addComponent(position, to: entity)
        
        // When
        world.removeComponent(TestPositionComponent.self, from: entity)
        
        // Then
        let retrievedPosition: TestPositionComponent? = world.getComponent(TestPositionComponent.self, for: entity)
        XCTAssertNil(retrievedPosition)
    }
    
    func testComponentUpdate() throws {
        // Given
        let entity = world.entityManager.createEntity()
        var position = TestPositionComponent(x: 10, y: 20)
        world.addComponent(position, to: entity)
        
        // When
        position.x = 30
        position.y = 40
        world.addComponent(position, to: entity) // Should update existing component
        
        // Then
        let retrievedPosition: TestPositionComponent? = world.getComponent(TestPositionComponent.self, for: entity)
        XCTAssertNotNil(retrievedPosition)
        XCTAssertEqual(retrievedPosition?.x, 30)
        XCTAssertEqual(retrievedPosition?.y, 40)
    }
    
    func testMultipleComponentTypes() throws {
        // Given
        let entity = world.entityManager.createEntity()
        let position = TestPositionComponent(x: 10, y: 20)
        let velocity = TestVelocityComponent(dx: 1, dy: 2)
        let health = TestHealthComponent(health: 80, maxHealth: 100)
        
        // When
        world.addComponent(position, to: entity)
        world.addComponent(velocity, to: entity)
        world.addComponent(health, to: entity)
        
        // Then
        XCTAssertNotNil(world.getComponent(TestPositionComponent.self, for: entity))
        XCTAssertNotNil(world.getComponent(TestVelocityComponent.self, for: entity))
        XCTAssertNotNil(world.getComponent(TestHealthComponent.self, for: entity))
    }
    
    func testComponentQuery() throws {
        // Given
        let entity1 = world.entityManager.createEntity()
        let entity2 = world.entityManager.createEntity()
        let entity3 = world.entityManager.createEntity()
        
        world.addComponent(TestPositionComponent(x: 1, y: 1), to: entity1)
        world.addComponent(TestVelocityComponent(dx: 1, dy: 1), to: entity1)
        
        world.addComponent(TestPositionComponent(x: 2, y: 2), to: entity2)
        
        world.addComponent(TestVelocityComponent(dx: 3, dy: 3), to: entity3)
        
        // When
        let entitiesWithPosition = world.entitiesWithComponent(TestPositionComponent.self)
        let entitiesWithVelocity = world.entitiesWithComponent(TestVelocityComponent.self)
        let entitiesWithBoth = world.entitiesWithComponents([TestPositionComponent.self, TestVelocityComponent.self])
        
        // Then
        XCTAssertEqual(entitiesWithPosition.count, 2)
        XCTAssertTrue(entitiesWithPosition.contains(entity1))
        XCTAssertTrue(entitiesWithPosition.contains(entity2))
        
        XCTAssertEqual(entitiesWithVelocity.count, 2)
        XCTAssertTrue(entitiesWithVelocity.contains(entity1))
        XCTAssertTrue(entitiesWithVelocity.contains(entity3))
        
        XCTAssertEqual(entitiesWithBoth.count, 1)
        XCTAssertTrue(entitiesWithBoth.contains(entity1))
    }
    
    // MARK: - System Tests
    
    func testSystemRegistration() throws {
        // Given
        let initialSystemCount = world.systems.count
        
        // When
        world.addSystem(testSystem)
        
        // Then
        XCTAssertEqual(world.systems.count, initialSystemCount + 1)
        XCTAssertTrue(world.systems.contains { $0 === testSystem })
    }
    
    func testSystemUpdate() throws {
        // Given
        world.addSystem(testSystem)
        let deltaTime: TimeInterval = 0.016 // 60 FPS
        
        // When
        world.update(deltaTime: deltaTime)
        
        // Then
        XCTAssertTrue(testSystem.updateCalled)
        XCTAssertEqual(testSystem.lastUpdateDeltaTime, deltaTime)
    }
    
    func testSystemPriority() throws {
        // Given
        let highPrioritySystem = MockAISystem()
        highPrioritySystem.priority = 1
        
        let lowPrioritySystem = MockAISystem()
        lowPrioritySystem.priority = 100
        
        // When
        world.addSystem(lowPrioritySystem)
        world.addSystem(highPrioritySystem)
        
        // Then
        // Systems should be sorted by priority
        let sortedSystems = world.systems.sorted { $0.priority < $1.priority }
        XCTAssertEqual(sortedSystems.first?.priority, 1)
        XCTAssertEqual(sortedSystems.last?.priority, 100)
    }
    
    // MARK: - Performance Tests
    
    func testEntityCreationPerformance() throws {
        measure {
            for _ in 0..<1000 {
                _ = world.entityManager.createEntity()
            }
        }
    }
    
    func testComponentAdditionPerformance() throws {
        // Given
        let entities = (0..<1000).map { _ in world.entityManager.createEntity() }
        
        // When
        measure {
            for entity in entities {
                world.addComponent(TestPositionComponent(x: 0, y: 0), to: entity)
                world.addComponent(TestVelocityComponent(dx: 1, dy: 1), to: entity)
            }
        }
    }
    
    func testComponentQueryPerformance() throws {
        // Given
        for _ in 0..<1000 {
            let entity = world.entityManager.createEntity()
            world.addComponent(TestPositionComponent(x: 0, y: 0), to: entity)
            if Bool.random() {
                world.addComponent(TestVelocityComponent(dx: 1, dy: 1), to: entity)
            }
        }
        
        // When
        measure {
            _ = world.entitiesWithComponent(TestPositionComponent.self)
            _ = world.entitiesWithComponent(TestVelocityComponent.self)
            _ = world.entitiesWithComponents([TestPositionComponent.self, TestVelocityComponent.self])
        }
    }
    
    func testSystemUpdatePerformance() throws {
        // Given
        let systems = (0..<10).map { _ in MockAISystem() }
        systems.forEach { world.addSystem($0) }
        
        for _ in 0..<100 {
            let entity = world.entityManager.createEntity()
            world.addComponent(TestPositionComponent(x: 0, y: 0), to: entity)
            world.addComponent(TestVelocityComponent(dx: 1, dy: 1), to: entity)
        }
        
        // When
        measure {
            world.update(deltaTime: 0.016)
        }
    }
    
    // MARK: - Memory Tests
    
    func testEntityDestructionCleansUpComponents() throws {
        // Given
        let entity = world.entityManager.createEntity()
        world.addComponent(TestPositionComponent(x: 10, y: 20), to: entity)
        world.addComponent(TestVelocityComponent(dx: 1, dy: 2), to: entity)
        
        // When
        world.entityManager.destroyEntity(entity)
        
        // Then
        XCTAssertNil(world.getComponent(TestPositionComponent.self, for: entity))
        XCTAssertNil(world.getComponent(TestVelocityComponent.self, for: entity))
    }
    
    func testLargeNumberOfEntitiesMemoryUsage() throws {
        // Given & When
        let entities = (0..<10000).map { _ in world.entityManager.createEntity() }
        
        entities.forEach { entity in
            world.addComponent(TestPositionComponent(x: 0, y: 0), to: entity)
        }
        
        // Then
        XCTAssertEqual(world.entityManager.entities.count, 10000)
        XCTAssertEqual(world.entitiesWithComponent(TestPositionComponent.self).count, 10000)
        
        // Cleanup
        entities.forEach { world.entityManager.destroyEntity($0) }
        XCTAssertEqual(world.entityManager.entities.count, 0)
    }
    
    // MARK: - Threading Tests
    
    func testConcurrentEntityCreation() throws {
        let expectation = XCTestExpectation(description: "Concurrent entity creation")
        let entityCount = 1000
        let concurrentQueues = 4
        
        DispatchQueue.concurrentPerform(iterations: concurrentQueues) { _ in
            for _ in 0..<(entityCount / concurrentQueues) {
                _ = world.entityManager.createEntity()
            }
        }
        
        expectation.fulfill()
        wait(for: [expectation], timeout: 5.0)
        
        XCTAssertEqual(world.entityManager.entities.count, entityCount)
    }
}

// MARK: - Test Systems

class TestMovementSystem: System {
    let priority = 50
    let canRunInParallel = true
    let requiredComponents: [ComponentType] = [TestPositionComponent.componentType, TestVelocityComponent.componentType]
    
    func update(deltaTime: TimeInterval, world: World) {
        let entities = world.entitiesWithComponents([TestPositionComponent.self, TestVelocityComponent.self])
        
        for entity in entities {
            guard var position: TestPositionComponent = world.getComponent(TestPositionComponent.self, for: entity),
                  let velocity: TestVelocityComponent = world.getComponent(TestVelocityComponent.self, for: entity) else {
                continue
            }
            
            position.x += velocity.dx * deltaTime
            position.y += velocity.dy * deltaTime
            
            world.addComponent(position, to: entity)
        }
    }
}