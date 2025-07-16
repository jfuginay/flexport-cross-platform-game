import Foundation
import simd
import os.log

/// Performance testing suite for ECS architecture
public class ECSPerformanceTests {
    private let logger = Logger(subsystem: "com.flexport", category: "ECSPerformance")
    private var world: World
    private var scheduler: ECSScheduler
    private var testResults: [PerformanceTestResult] = []
    
    public init() {
        self.world = World()
        self.scheduler = world.createStandardScheduler()
    }
    
    // MARK: - Test Suites
    
    /// Run all performance tests
    public func runAllTests(completion: @escaping ([PerformanceTestResult]) -> Void) {
        testResults.removeAll()
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.logger.info("Starting ECS performance tests...")
            
            // Entity creation tests
            self.testEntityCreation()
            self.testBatchEntityCreation()
            
            // Component tests
            self.testComponentAddition()
            self.testComponentRetrieval()
            self.testComponentRemoval()
            
            // System execution tests
            self.testSystemExecution(entityCount: 1000)
            self.testSystemExecution(entityCount: 5000)
            self.testSystemExecution(entityCount: 10000)
            
            // Spatial query tests
            self.testSpatialQueries()
            
            // Memory tests
            self.testMemoryUsage()
            
            // Stress tests
            self.testMaxEntityCount()
            
            DispatchQueue.main.async {
                self.logger.info("ECS performance tests completed")
                completion(self.testResults)
            }
        }
    }
    
    // MARK: - Entity Tests
    
    private func testEntityCreation() {
        let testName = "Entity Creation (10k entities)"
        logger.info("Running test: \(testName)")
        
        let startTime = CACurrentMediaTime()
        let startMemory = getMemoryUsage()
        
        var entities: [Entity] = []
        for _ in 0..<10000 {
            entities.append(world.entityManager.createEntity())
        }
        
        let endTime = CACurrentMediaTime()
        let endMemory = getMemoryUsage()
        
        let result = PerformanceTestResult(
            testName: testName,
            executionTime: endTime - startTime,
            memoryUsed: endMemory - startMemory,
            entitiesProcessed: 10000,
            passed: (endTime - startTime) < 1.0 // Should complete in under 1 second
        )
        
        testResults.append(result)
        logger.info("Test completed: \(testName) - Time: \(result.executionTimeMs)ms")
        
        // Cleanup
        for entity in entities {
            world.entityManager.destroyEntity(entity)
        }
    }
    
    private func testBatchEntityCreation() {
        let testName = "Batch Entity Creation (10k entities)"
        logger.info("Running test: \(testName)")
        
        let startTime = CACurrentMediaTime()
        let startMemory = getMemoryUsage()
        
        let entities = world.entityManager.createEntitiesBatch(count: 10000)
        
        let endTime = CACurrentMediaTime()
        let endMemory = getMemoryUsage()
        
        let result = PerformanceTestResult(
            testName: testName,
            executionTime: endTime - startTime,
            memoryUsed: endMemory - startMemory,
            entitiesProcessed: 10000,
            passed: (endTime - startTime) < 0.5 // Batch should be faster
        )
        
        testResults.append(result)
        logger.info("Test completed: \(testName) - Time: \(result.executionTimeMs)ms")
        
        // Cleanup
        for entity in entities {
            world.entityManager.destroyEntity(entity)
        }
    }
    
    // MARK: - Component Tests
    
    private func testComponentAddition() {
        let testName = "Component Addition (10k entities, 3 components each)"
        logger.info("Running test: \(testName)")
        
        // Create entities first
        let entities = world.entityManager.createEntitiesBatch(count: 10000)
        
        let startTime = CACurrentMediaTime()
        
        for entity in entities {
            world.addComponent(TransformComponent(), to: entity)
            world.addComponent(PhysicsComponent(), to: entity)
            world.addComponent(ShipComponent(
                name: "Test Ship",
                capacity: 1000,
                speed: 20.0,
                efficiency: 0.8,
                maintenanceCost: 1000.0,
                fuelCapacity: 500.0
            ), to: entity)
        }
        
        let endTime = CACurrentMediaTime()
        
        let result = PerformanceTestResult(
            testName: testName,
            executionTime: endTime - startTime,
            memoryUsed: 0,
            entitiesProcessed: 10000,
            passed: (endTime - startTime) < 2.0
        )
        
        testResults.append(result)
        logger.info("Test completed: \(testName) - Time: \(result.executionTimeMs)ms")
        
        // Keep entities for next test
    }
    
    private func testComponentRetrieval() {
        let testName = "Component Retrieval (10k queries)"
        logger.info("Running test: \(testName)")
        
        let entities = world.getEntitiesWithComponents([.transform, .physics, .ship])
        guard entities.count >= 10000 else {
            logger.warning("Not enough entities for retrieval test")
            return
        }
        
        let startTime = CACurrentMediaTime()
        
        for entity in entities.prefix(10000) {
            _ = world.getComponent(TransformComponent.self, for: entity)
            _ = world.getComponent(PhysicsComponent.self, for: entity)
            _ = world.getComponent(ShipComponent.self, for: entity)
        }
        
        let endTime = CACurrentMediaTime()
        
        let result = PerformanceTestResult(
            testName: testName,
            executionTime: endTime - startTime,
            memoryUsed: 0,
            entitiesProcessed: 10000,
            passed: (endTime - startTime) < 0.5
        )
        
        testResults.append(result)
        logger.info("Test completed: \(testName) - Time: \(result.executionTimeMs)ms")
    }
    
    private func testComponentRemoval() {
        let testName = "Component Removal (5k removals)"
        logger.info("Running test: \(testName)")
        
        let entities = world.getEntitiesWithComponents([.transform, .physics, .ship])
        let entitiesToModify = Array(entities.prefix(5000))
        
        let startTime = CACurrentMediaTime()
        
        for entity in entitiesToModify {
            world.removeComponent(.physics, from: entity)
        }
        
        let endTime = CACurrentMediaTime()
        
        let result = PerformanceTestResult(
            testName: testName,
            executionTime: endTime - startTime,
            memoryUsed: 0,
            entitiesProcessed: 5000,
            passed: (endTime - startTime) < 1.0
        )
        
        testResults.append(result)
        logger.info("Test completed: \(testName) - Time: \(result.executionTimeMs)ms")
        
        // Cleanup all test entities
        for entity in entities {
            world.destroyEntity(entity)
        }
    }
    
    // MARK: - System Execution Tests
    
    private func testSystemExecution(entityCount: Int) {
        let testName = "System Execution (\(entityCount) entities)"
        logger.info("Running test: \(testName)")
        
        // Create test entities
        let factory = WorldFactory(world: world)
        let ships = factory.createShipFleet(
            baseName: "Test Ship",
            count: entityCount,
            startPosition: .zero,
            spacing: 50.0
        )
        
        // Warm up
        for _ in 0..<5 {
            scheduler.execute(deltaTime: 1.0/60.0, world: world)
        }
        
        // Reset metrics
        scheduler.resetMetrics()
        
        // Measure execution
        let startTime = CACurrentMediaTime()
        let frames = 60
        
        for _ in 0..<frames {
            scheduler.execute(deltaTime: 1.0/60.0, world: world)
        }
        
        let endTime = CACurrentMediaTime()
        let averageFrameTime = (endTime - startTime) / Double(frames)
        let fps = 1.0 / averageFrameTime
        
        let result = PerformanceTestResult(
            testName: testName,
            executionTime: averageFrameTime,
            memoryUsed: 0,
            entitiesProcessed: entityCount,
            passed: fps >= 60.0,
            additionalInfo: "FPS: \(String(format: "%.1f", fps))"
        )
        
        testResults.append(result)
        logger.info("Test completed: \(testName) - FPS: \(fps)")
        
        // Cleanup
        for ship in ships {
            world.destroyEntity(ship)
        }
    }
    
    // MARK: - Spatial Query Tests
    
    private func testSpatialQueries() {
        let testName = "Spatial Queries (10k entities, 1k queries)"
        logger.info("Running test: \(testName)")
        
        // Create entities spread across the world
        let entities = world.entityManager.createEntitiesBatch(count: 10000)
        for entity in entities {
            let position = SIMD3<Float>(
                Float.random(in: -5000...5000),
                0,
                Float.random(in: -5000...5000)
            )
            world.addComponent(TransformComponent(position: position), to: entity)
            world.entityManager.updateEntityPosition(entity, position: position)
        }
        
        let startTime = CACurrentMediaTime()
        
        // Perform spatial queries
        for _ in 0..<1000 {
            let queryPos = SIMD3<Float>(
                Float.random(in: -5000...5000),
                0,
                Float.random(in: -5000...5000)
            )
            _ = world.entityManager.getEntitiesInRegion(center: queryPos, radius: 200.0)
        }
        
        let endTime = CACurrentMediaTime()
        
        let result = PerformanceTestResult(
            testName: testName,
            executionTime: endTime - startTime,
            memoryUsed: 0,
            entitiesProcessed: 1000,
            passed: (endTime - startTime) < 0.5
        )
        
        testResults.append(result)
        logger.info("Test completed: \(testName) - Time: \(result.executionTimeMs)ms")
        
        // Cleanup
        for entity in entities {
            world.destroyEntity(entity)
        }
    }
    
    // MARK: - Memory Tests
    
    private func testMemoryUsage() {
        let testName = "Memory Usage (10k full entities)"
        logger.info("Running test: \(testName)")
        
        let startMemory = getMemoryUsage()
        
        // Create fully featured entities
        let factory = WorldFactory(world: world)
        let ships = factory.createShipFleet(
            baseName: "Memory Test Ship",
            count: 10000,
            startPosition: .zero
        )
        
        // Add additional components
        for ship in ships {
            world.addComponent(
                EconomyComponent(money: 1_000_000),
                to: ship
            )
            world.addComponent(
                RouteComponent(
                    routeId: UUID(),
                    waypoints: [.zero, SIMD3<Float>(1000, 0, 1000)]
                ),
                to: ship
            )
        }
        
        let endMemory = getMemoryUsage()
        let memoryPerEntity = (endMemory - startMemory) / 10000
        
        let result = PerformanceTestResult(
            testName: testName,
            executionTime: 0,
            memoryUsed: endMemory - startMemory,
            entitiesProcessed: 10000,
            passed: memoryPerEntity < 10240, // Less than 10KB per entity
            additionalInfo: "Memory per entity: \(memoryPerEntity) bytes"
        )
        
        testResults.append(result)
        logger.info("Test completed: \(testName) - Memory per entity: \(memoryPerEntity) bytes")
        
        // Cleanup
        for ship in ships {
            world.destroyEntity(ship)
        }
    }
    
    // MARK: - Stress Tests
    
    private func testMaxEntityCount() {
        let testName = "Maximum Entity Count"
        logger.info("Running test: \(testName)")
        
        var entities: [Entity] = []
        let batchSize = 1000
        var totalCreated = 0
        
        let startTime = CACurrentMediaTime()
        
        // Keep creating until we hit a limit or performance degrades
        while CACurrentMediaTime() - startTime < 10.0 { // 10 second timeout
            let batchStart = CACurrentMediaTime()
            let batch = world.entityManager.createEntitiesBatch(count: batchSize)
            let batchTime = CACurrentMediaTime() - batchStart
            
            // Add basic components
            for entity in batch {
                world.addComponent(TransformComponent(), to: entity)
            }
            
            entities.append(contentsOf: batch)
            totalCreated += batchSize
            
            // Check if performance is degrading
            if batchTime > 0.5 { // If batch takes more than 500ms, stop
                break
            }
            
            if totalCreated >= 50000 { // Safety limit
                break
            }
        }
        
        let result = PerformanceTestResult(
            testName: testName,
            executionTime: CACurrentMediaTime() - startTime,
            memoryUsed: 0,
            entitiesProcessed: totalCreated,
            passed: totalCreated >= 10000,
            additionalInfo: "Max entities created: \(totalCreated)"
        )
        
        testResults.append(result)
        logger.info("Test completed: \(testName) - Max entities: \(totalCreated)")
        
        // Cleanup
        for entity in entities {
            world.destroyEntity(entity)
        }
    }
    
    // MARK: - Helper Functions
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}

// MARK: - Test Result Structure

public struct PerformanceTestResult {
    public let testName: String
    public let executionTime: TimeInterval
    public let memoryUsed: Int64
    public let entitiesProcessed: Int
    public let passed: Bool
    public let additionalInfo: String?
    
    public init(testName: String, executionTime: TimeInterval, memoryUsed: Int64,
                entitiesProcessed: Int, passed: Bool, additionalInfo: String? = nil) {
        self.testName = testName
        self.executionTime = executionTime
        self.memoryUsed = memoryUsed
        self.entitiesProcessed = entitiesProcessed
        self.passed = passed
        self.additionalInfo = additionalInfo
    }
    
    public var executionTimeMs: Double {
        executionTime * 1000
    }
    
    public var memoryUsedMB: Double {
        Double(memoryUsed) / 1024 / 1024
    }
    
    public var summary: String {
        var result = "\(testName): \(passed ? "PASSED" : "FAILED")\n"
        result += "  Time: \(String(format: "%.2f", executionTimeMs))ms\n"
        if memoryUsed > 0 {
            result += "  Memory: \(String(format: "%.2f", memoryUsedMB))MB\n"
        }
        result += "  Entities: \(entitiesProcessed)\n"
        if let info = additionalInfo {
            result += "  \(info)\n"
        }
        return result
    }
}