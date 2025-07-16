import Foundation
import Combine
import os.log

/// Advanced ECS scheduler with dependency resolution and parallel execution
public class ECSScheduler {
    private var systems: [System] = []
    private var systemDependencies: [ObjectIdentifier: Set<ObjectIdentifier>] = [:]
    private var executionGroups: [[System]] = []
    private var systemMetrics: [ObjectIdentifier: SystemMetrics] = [:]
    
    private let executionQueue = DispatchQueue(label: "com.flexport.ecs.scheduler", attributes: .concurrent)
    private let metricsQueue = DispatchQueue(label: "com.flexport.ecs.metrics")
    
    private let logger = Logger(subsystem: "com.flexport", category: "ECSScheduler")
    
    public init() {}
    
    // MARK: - System Registration
    
    /// Register a system with optional dependencies
    public func registerSystem(_ system: System, dependsOn dependencies: [System] = []) {
        systems.append(system)
        
        let systemId = ObjectIdentifier(system)
        systemDependencies[systemId] = Set(dependencies.map { ObjectIdentifier($0) })
        systemMetrics[systemId] = SystemMetrics()
        
        // Rebuild execution groups when systems change
        rebuildExecutionGroups()
    }
    
    /// Remove a system from the scheduler
    public func unregisterSystem(_ system: System) {
        let systemId = ObjectIdentifier(system)
        systems.removeAll { ObjectIdentifier($0) == systemId }
        systemDependencies.removeValue(forKey: systemId)
        systemMetrics.removeValue(forKey: systemId)
        
        // Remove references to this system from other dependencies
        for (id, deps) in systemDependencies {
            var updatedDeps = deps
            updatedDeps.remove(systemId)
            systemDependencies[id] = updatedDeps
        }
        
        rebuildExecutionGroups()
    }
    
    // MARK: - Execution
    
    /// Execute all systems with optimal parallelization
    public func execute(deltaTime: TimeInterval, world: World) {
        let startTime = CACurrentMediaTime()
        
        for group in executionGroups {
            if group.count == 1 {
                // Single system in group, execute directly
                executeSystem(group[0], deltaTime: deltaTime, world: world)
            } else {
                // Multiple systems can run in parallel
                executeSystemsInParallel(group, deltaTime: deltaTime, world: world)
            }
        }
        
        let totalTime = CACurrentMediaTime() - startTime
        logger.debug("Frame execution completed in \(totalTime * 1000, format: .fixed(precision: 2))ms")
    }
    
    private func executeSystem(_ system: System, deltaTime: TimeInterval, world: World) {
        let systemId = ObjectIdentifier(system)
        let startTime = CACurrentMediaTime()
        
        system.update(deltaTime: deltaTime, world: world)
        
        let executionTime = CACurrentMediaTime() - startTime
        
        metricsQueue.async {
            self.systemMetrics[systemId]?.recordExecution(time: executionTime)
        }
    }
    
    private func executeSystemsInParallel(_ systems: [System], deltaTime: TimeInterval, world: World) {
        let group = DispatchGroup()
        
        for system in systems {
            if system.canRunInParallel {
                group.enter()
                executionQueue.async {
                    self.executeSystem(system, deltaTime: deltaTime, world: world)
                    group.leave()
                }
            } else {
                // System cannot run in parallel, execute on main thread
                executeSystem(system, deltaTime: deltaTime, world: world)
            }
        }
        
        group.wait()
    }
    
    // MARK: - Dependency Resolution
    
    private func rebuildExecutionGroups() {
        executionGroups.removeAll()
        
        // Topological sort to determine execution order
        let sortedSystems = topologicalSort()
        
        // Group systems that can run in parallel
        var currentGroup: [System] = []
        var processedSystems = Set<ObjectIdentifier>()
        
        for system in sortedSystems {
            let systemId = ObjectIdentifier(system)
            let dependencies = systemDependencies[systemId] ?? []
            
            // Check if all dependencies have been processed
            let canExecute = dependencies.isSubset(of: processedSystems)
            
            if canExecute {
                // Check if system has conflicts with current group
                let hasConflicts = currentGroup.contains { otherSystem in
                    !system.canRunInParallel || !otherSystem.canRunInParallel ||
                    hasComponentConflict(system, otherSystem)
                }
                
                if hasConflicts && !currentGroup.isEmpty {
                    // Start new group
                    executionGroups.append(currentGroup)
                    currentGroup = [system]
                } else {
                    currentGroup.append(system)
                }
                
                processedSystems.insert(systemId)
            }
        }
        
        if !currentGroup.isEmpty {
            executionGroups.append(currentGroup)
        }
        
        logger.info("Rebuilt execution groups: \(executionGroups.count) groups total")
    }
    
    private func topologicalSort() -> [System] {
        var sorted: [System] = []
        var visited = Set<ObjectIdentifier>()
        var visiting = Set<ObjectIdentifier>()
        
        func visit(_ system: System) {
            let systemId = ObjectIdentifier(system)
            
            if visiting.contains(systemId) {
                logger.error("Circular dependency detected for system: \(String(describing: type(of: system)))")
                return
            }
            
            if visited.contains(systemId) {
                return
            }
            
            visiting.insert(systemId)
            
            // Visit dependencies first
            let dependencies = systemDependencies[systemId] ?? []
            for depId in dependencies {
                if let depSystem = systems.first(where: { ObjectIdentifier($0) == depId }) {
                    visit(depSystem)
                }
            }
            
            visiting.remove(systemId)
            visited.insert(systemId)
            sorted.append(system)
        }
        
        // Sort by priority first
        let prioritySorted = systems.sorted { $0.priority < $1.priority }
        
        // Then apply topological sort
        for system in prioritySorted {
            visit(system)
        }
        
        return sorted
    }
    
    private func hasComponentConflict(_ system1: System, _ system2: System) -> Bool {
        // Check if systems write to the same components
        let components1 = Set(system1.requiredComponents)
        let components2 = Set(system2.requiredComponents)
        
        return !components1.isDisjoint(with: components2)
    }
    
    // MARK: - Performance Monitoring
    
    /// Get performance metrics for all systems
    public func getPerformanceReport() -> SchedulerPerformanceReport {
        var systemReports: [SystemPerformanceReport] = []
        
        for system in systems {
            let systemId = ObjectIdentifier(system)
            if let metrics = systemMetrics[systemId] {
                systemReports.append(SystemPerformanceReport(
                    systemName: String(describing: type(of: system)),
                    averageExecutionTime: metrics.averageExecutionTime,
                    maxExecutionTime: metrics.maxExecutionTime,
                    totalExecutions: metrics.executionCount,
                    canRunInParallel: system.canRunInParallel
                ))
            }
        }
        
        return SchedulerPerformanceReport(
            totalGroups: executionGroups.count,
            parallelizationRatio: calculateParallelizationRatio(),
            systemReports: systemReports
        )
    }
    
    private func calculateParallelizationRatio() -> Double {
        let totalSystems = systems.count
        let parallelSystems = systems.filter { $0.canRunInParallel }.count
        
        return totalSystems > 0 ? Double(parallelSystems) / Double(totalSystems) : 0.0
    }
    
    /// Clear all performance metrics
    public func resetMetrics() {
        metricsQueue.sync {
            for (_, metrics) in systemMetrics {
                metrics.reset()
            }
        }
    }
}

// MARK: - Supporting Types

/// Metrics for individual system performance
private class SystemMetrics {
    private var executionTimes: [TimeInterval] = []
    private let maxSamples = 60 // Keep last 60 frame times
    
    var executionCount: Int {
        executionTimes.count
    }
    
    var averageExecutionTime: TimeInterval {
        guard !executionTimes.isEmpty else { return 0 }
        return executionTimes.reduce(0, +) / Double(executionTimes.count)
    }
    
    var maxExecutionTime: TimeInterval {
        executionTimes.max() ?? 0
    }
    
    func recordExecution(time: TimeInterval) {
        executionTimes.append(time)
        if executionTimes.count > maxSamples {
            executionTimes.removeFirst()
        }
    }
    
    func reset() {
        executionTimes.removeAll()
    }
}

/// Performance report for the scheduler
public struct SchedulerPerformanceReport {
    public let totalGroups: Int
    public let parallelizationRatio: Double
    public let systemReports: [SystemPerformanceReport]
    
    public var totalExecutionTime: TimeInterval {
        systemReports.reduce(0) { $0 + $1.averageExecutionTime }
    }
    
    public var bottleneckSystem: SystemPerformanceReport? {
        systemReports.max { $0.averageExecutionTime < $1.averageExecutionTime }
    }
}

/// Performance report for individual systems
public struct SystemPerformanceReport {
    public let systemName: String
    public let averageExecutionTime: TimeInterval
    public let maxExecutionTime: TimeInterval
    public let totalExecutions: Int
    public let canRunInParallel: Bool
    
    public var executionTimeMs: Double {
        averageExecutionTime * 1000
    }
}

// MARK: - ECS Scheduler Extension for World

public extension World {
    /// Create a scheduler with all standard game systems
    func createStandardScheduler() -> ECSScheduler {
        let scheduler = ECSScheduler()
        let metalAccelerator = MetalECSAccelerator()
        
        // Create systems
        let collisionSystem = CollisionDetectionSystem()
        let physicsSystem = PhysicsSystem(metalAccelerator: metalAccelerator)
        let movementSystem = MovementSystem()
        let routeSystem = RouteFollowingSystem()
        let economicSystem = EconomicSystem()
        let aiSystem = AIDecisionSystem(metalAccelerator: metalAccelerator)
        let singularitySystem = SingularityEvolutionSystem()
        
        // Set up cross-system references
        aiSystem.setEconomicSystem(economicSystem)
        
        // Register systems with dependencies
        scheduler.registerSystem(collisionSystem)
        scheduler.registerSystem(physicsSystem, dependsOn: [collisionSystem])
        scheduler.registerSystem(movementSystem, dependsOn: [physicsSystem])
        scheduler.registerSystem(routeSystem, dependsOn: [movementSystem])
        scheduler.registerSystem(economicSystem)
        scheduler.registerSystem(aiSystem, dependsOn: [economicSystem])
        scheduler.registerSystem(singularitySystem, dependsOn: [aiSystem])
        
        return scheduler
    }
}