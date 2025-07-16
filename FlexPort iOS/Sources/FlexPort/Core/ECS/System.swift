import Foundation
import Combine

/// Enhanced system protocol with threading and batching support
public protocol System: AnyObject {
    var priority: Int { get }
    var canRunInParallel: Bool { get }
    var requiredComponents: [ComponentType] { get }
    func update(deltaTime: TimeInterval, world: World)
    func updateBatch(entities: ArraySlice<Entity>, deltaTime: TimeInterval, world: World)
}

/// Default implementations for System protocol
public extension System {
    var canRunInParallel: Bool { false }
    var requiredComponents: [ComponentType] { [] }
    
    func updateBatch(entities: ArraySlice<Entity>, deltaTime: TimeInterval, world: World) {
        // Default implementation processes entities sequentially
        for entity in entities {
            // Systems can override this for true batch processing
        }
    }
}

/// High-performance World manager with threaded system execution
public class World {
    public let entityManager = EntityManager()
    private var componentStorages: [ComponentType: Any] = [:]
    
    // Advanced system scheduling
    private var systems: [System] = []
    private var parallelSystems: [System] = []
    private var sequentialSystems: [System] = []
    private let systemScheduler = SystemScheduler()
    
    // Performance monitoring
    private var performanceProfiler = PerformanceProfiler()
    private var frameTime: TimeInterval = 0
    private var targetFrameTime: TimeInterval = 1.0 / 60.0 // 60 FPS target
    
    // Publishers for game events
    public let entityCreated = PassthroughSubject<Entity, Never>()
    public let entityDestroyed = PassthroughSubject<Entity, Never>()
    public let componentAdded = PassthroughSubject<(Entity, ComponentType), Never>()
    public let componentRemoved = PassthroughSubject<(Entity, ComponentType), Never>()
    
    // Threading queues
    private let mainQueue = DispatchQueue.main
    private let systemQueue = DispatchQueue(label: "com.flexport.systems", qos: .userInteractive, attributes: .concurrent)
    private let physicsQueue = DispatchQueue(label: "com.flexport.physics", qos: .userInteractive)
    
    public init() {
        setupComponentStorages()
        setupPerformanceMonitoring()
    }
    
    private func setupComponentStorages() {
        componentStorages[.transform] = GenericComponentStorage<TransformComponent>()
        componentStorages[.ship] = GenericComponentStorage<ShipComponent>()
        componentStorages[.warehouse] = GenericComponentStorage<WarehouseComponent>()
        componentStorages[.port] = GenericComponentStorage<PortComponent>()
        componentStorages[.cargo] = GenericComponentStorage<CargoComponent>()
        componentStorages[.ai] = GenericComponentStorage<AIComponent>()
        componentStorages[.touchInput] = GenericComponentStorage<TouchInputComponent>()
    }
    
    private func setupPerformanceMonitoring() {
        performanceProfiler.targetFrameTime = targetFrameTime
    }
    
    /// Register a system with automatic parallel/sequential classification
    public func registerSystem(_ system: System) {
        systems.append(system)
        
        if system.canRunInParallel {
            parallelSystems.append(system)
        } else {
            sequentialSystems.append(system)
        }
        
        // Sort systems by priority
        systems.sort { $0.priority < $1.priority }
        parallelSystems.sort { $0.priority < $1.priority }
        sequentialSystems.sort { $0.priority < $1.priority }
    }
    
    /// High-performance update with threading and batching
    public func update(deltaTime: TimeInterval) {
        let frameStart = CACurrentMediaTime()
        
        // Update frame timing
        frameTime = deltaTime
        performanceProfiler.startFrame()
        
        // Execute systems based on their capabilities
        executeSystemsOptimized(deltaTime: deltaTime)
        
        // Compact storage if needed for performance
        if frameTime > targetFrameTime * 1.2 {
            compactStorages()
        }
        
        let frameEnd = CACurrentMediaTime()
        performanceProfiler.endFrame(actualTime: frameEnd - frameStart)
    }
    
    private func executeSystemsOptimized(deltaTime: TimeInterval) {
        let dispatchGroup = DispatchGroup()
        
        // Run parallel systems concurrently
        for system in parallelSystems {
            dispatchGroup.enter()
            systemQueue.async {
                self.executeSystemInBatches(system, deltaTime: deltaTime)
                dispatchGroup.leave()
            }
        }
        
        // Run sequential systems on main thread
        for system in sequentialSystems {
            system.update(deltaTime: deltaTime, world: self)
        }
        
        // Wait for parallel systems to complete
        dispatchGroup.wait()
    }
    
    private func executeSystemInBatches(_ system: System, deltaTime: TimeInterval) {
        let entities = entityManager.getEntitiesWithComponents(system.requiredComponents)
        let batchSize = 64 // Optimize based on cache line size
        
        let batches = stride(from: 0, to: entities.count, by: batchSize).map {
            Array(entities[$0..<min($0 + batchSize, entities.count)])
        }
        
        let batchGroup = DispatchGroup()
        
        for batch in batches {
            batchGroup.enter()
            systemQueue.async {
                system.updateBatch(entities: ArraySlice(batch), deltaTime: deltaTime, world: self)
                batchGroup.leave()
            }
        }
        
        batchGroup.wait()
    }
    
    private func compactStorages() {
        // Compact entity manager
        entityManager.compact()
        
        // Compact component storages
        for (_, storage) in componentStorages {
            if let genericStorage = storage as? AnyComponentStorage {
                genericStorage.compact()
            }
        }
    }
    
    /// Get performance statistics
    public func getPerformanceStats() -> PerformanceStats {
        return performanceProfiler.getStats()
    }
    
    /// Create entity with components
    public func createEntity(with components: [Component]) -> Entity {
        let entity = entityManager.createEntity()
        
        for component in components {
            addComponent(component, to: entity)
        }
        
        entityCreated.send(entity)
        return entity
    }
    
    /// Destroy entity and all its components
    public func destroyEntity(_ entity: Entity) {
        // Remove all components
        for componentType in ComponentType.allCases {
            removeComponent(componentType, from: entity)
        }
        
        entityManager.destroyEntity(entity)
        entityDestroyed.send(entity)
    }
    
    /// Add component to entity
    public func addComponent<T: Component>(_ component: T, to entity: Entity) {
        guard let storage = componentStorages[T.componentType] as? GenericComponentStorage<T> else {
            return
        }
        
        storage.add(component, to: entity)
        entityManager.updateComponentMask(entity, componentType: T.componentType)
        componentAdded.send((entity, T.componentType))
    }
    
    /// Remove component from entity
    public func removeComponent(_ componentType: ComponentType, from entity: Entity) {
        switch componentType {
        case .transform:
            (componentStorages[componentType] as? GenericComponentStorage<TransformComponent>)?.remove(from: entity)
        case .ship:
            (componentStorages[componentType] as? GenericComponentStorage<ShipComponent>)?.remove(from: entity)
        case .warehouse:
            (componentStorages[componentType] as? GenericComponentStorage<WarehouseComponent>)?.remove(from: entity)
        case .port:
            (componentStorages[componentType] as? GenericComponentStorage<PortComponent>)?.remove(from: entity)
        case .cargo:
            (componentStorages[componentType] as? GenericComponentStorage<CargoComponent>)?.remove(from: entity)
        case .ai:
            (componentStorages[componentType] as? GenericComponentStorage<AIComponent>)?.remove(from: entity)
        case .touchInput:
            (componentStorages[componentType] as? GenericComponentStorage<TouchInputComponent>)?.remove(from: entity)
        default:
            break
        }
        
        entityManager.removeComponentFromMask(entity, componentType: componentType)
        componentRemoved.send((entity, componentType))
    }
    
    /// Get component for entity
    public func getComponent<T: Component>(_ componentType: T.Type, for entity: Entity) -> T? {
        guard let storage = componentStorages[T.componentType] as? GenericComponentStorage<T> else {
            return nil
        }
        return storage.get(for: entity)
    }
    
    /// Get all entities with specific components
    public func getEntitiesWithComponents(_ componentTypes: [ComponentType]) -> [Entity] {
        entityManager.getEntitiesWithComponents(componentTypes)
    }
    
    /// Get all components of a specific type
    public func getAllComponents<T: Component>(_ componentType: T.Type) -> [(Entity, T)] {
        guard let storage = componentStorages[T.componentType] as? GenericComponentStorage<T> else {
            return []
        }
        return storage.getAll()
    }
}

/// Movement system for ships
public class MovementSystem: System {
    public let priority = 100
    
    public init() {}
    
    public func update(deltaTime: TimeInterval, world: World) {
        let movingEntities = world.getEntitiesWithComponents([.transform, .ship])
        
        for entity in movingEntities {
            guard let transform = world.getComponent(TransformComponent.self, for: entity),
                  let ship = world.getComponent(ShipComponent.self, for: entity) else {
                continue
            }
            
            // Update position based on destination and speed
            if let destination = ship.destination,
               let destTransform = world.getComponent(TransformComponent.self, for: destination) {
                
                let direction = destTransform.position - transform.position
                let distance = length(direction)
                
                if distance > 0.1 {
                    let normalizedDirection = normalize(direction)
                    let moveDistance = Float(deltaTime) * ship.speed * ship.efficiency
                    let newPosition = transform.position + normalizedDirection * min(moveDistance, distance)
                    
                    var updatedTransform = transform
                    updatedTransform.position = newPosition
                    world.addComponent(updatedTransform, to: entity)
                    
                    // Update fuel consumption
                    var updatedShip = ship
                    updatedShip.currentFuel -= Float(deltaTime) * 0.1
                    world.addComponent(updatedShip, to: entity)
                }
            }
        }
    }
}

// SIMD helper functions
private func length(_ vector: SIMD3<Float>) -> Float {
    sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
}

private func normalize(_ vector: SIMD3<Float>) -> SIMD3<Float> {
    let len = length(vector)
    return len > 0 ? vector / len : vector
}

// MARK: - Supporting Infrastructure

/// System scheduler for managing execution order and dependencies
public class SystemScheduler {
    private var executionGraph: [System: [System]] = [:]
    
    public init() {}
    
    public func addDependency(system: System, dependsOn: System) {
        if executionGraph[dependsOn] == nil {
            executionGraph[dependsOn] = []
        }
        executionGraph[dependsOn]?.append(system)
    }
    
    public func getExecutionOrder(systems: [System]) -> [System] {
        // Topological sort for dependency resolution
        return systems.sorted { $0.priority < $1.priority }
    }
}

/// Performance profiler for frame timing and system performance
public class PerformanceProfiler {
    public var targetFrameTime: TimeInterval = 1.0 / 60.0
    private var frameStartTime: TimeInterval = 0
    private var frameCount: Int = 0
    private var totalFrameTime: TimeInterval = 0
    private var frameTimeSamples: [TimeInterval] = []
    private let maxSamples = 120 // 2 seconds at 60fps
    
    public func startFrame() {
        frameStartTime = CACurrentMediaTime()
    }
    
    public func endFrame(actualTime: TimeInterval) {
        frameCount += 1
        totalFrameTime += actualTime
        
        frameTimeSamples.append(actualTime)
        if frameTimeSamples.count > maxSamples {
            frameTimeSamples.removeFirst()
        }
    }
    
    public func getStats() -> PerformanceStats {
        let averageFrameTime = frameTimeSamples.isEmpty ? 0 : frameTimeSamples.reduce(0, +) / Double(frameTimeSamples.count)
        let fps = averageFrameTime > 0 ? 1.0 / averageFrameTime : 0
        let droppedFrames = frameTimeSamples.filter { $0 > targetFrameTime * 1.1 }.count
        
        return PerformanceStats(
            averageFrameTime: averageFrameTime,
            currentFPS: fps,
            targetFPS: 1.0 / targetFrameTime,
            droppedFrames: droppedFrames,
            frameCount: frameCount
        )
    }
}

/// Performance statistics
public struct PerformanceStats {
    public let averageFrameTime: TimeInterval
    public let currentFPS: Double
    public let targetFPS: Double
    public let droppedFrames: Int
    public let frameCount: Int
    
    public var isPerformanceGood: Bool {
        currentFPS >= targetFPS * 0.95 // Within 5% of target
    }
}

/// Protocol for type-erased component storage
protocol AnyComponentStorage {
    func compact()
}

/// Extension to make GenericComponentStorage conform to AnyComponentStorage
extension GenericComponentStorage: AnyComponentStorage {}