import Foundation
import CoreData
import Combine

/// Advanced ECS persistence manager optimized for component serialization
public class ECSPersistenceManager: ObservableObject {
    private let coreDataManager: CoreDataManager
    private let componentSerializer = ComponentSerializer()
    private let compressionManager = CompressionManager()
    
    // Performance optimization
    private var batchSaveTimer: Timer?
    private var pendingComponents: [Entity: [Component]] = [:]
    private let batchSaveInterval: TimeInterval = 0.1 // 100ms batching
    
    // Component change tracking
    private var componentChangeSet = Set<Entity>()
    private var lastSaveTimestamp: Date = Date()
    
    public init(coreDataManager: CoreDataManager = CoreDataManager.shared) {
        self.coreDataManager = coreDataManager
        setupBatchSaving()
    }
    
    private func setupBatchSaving() {
        batchSaveTimer = Timer.scheduledTimer(withTimeInterval: batchSaveInterval, repeats: true) { _ in
            self.flushPendingChanges()
        }
    }
    
    // MARK: - Component Persistence
    
    /// Save components for an entity with batching optimization
    public func saveComponents(_ components: [Component], for entity: Entity) {
        pendingComponents[entity] = components
        componentChangeSet.insert(entity)
        
        // If we have a lot of pending changes, flush immediately
        if componentChangeSet.count > 100 {
            flushPendingChanges()
        }
    }
    
    /// Load components for an entity
    public func loadComponents(for entity: Entity, completion: @escaping (Result<[Component], Error>) -> Void) {
        let backgroundContext = coreDataManager.persistentContainer.newBackgroundContext()
        
        backgroundContext.perform {
            do {
                let request: NSFetchRequest<ComponentData> = ComponentData.fetchRequest()
                request.predicate = NSPredicate(format: "entityId == %@", entity.id as CVarArg)
                
                let componentDataObjects = try backgroundContext.fetch(request)
                var components: [Component] = []
                
                for componentData in componentDataObjects {
                    if let data = componentData.data,
                       let componentType = ComponentType(rawValue: Int(componentData.componentType)) {
                        
                        // Decompress if needed
                        let decompressedData = componentData.isCompressed ? 
                            self.compressionManager.decompress(data) : data
                        
                        if let component = try? self.componentSerializer.deserialize(
                            data: decompressedData, 
                            type: componentType
                        ) {
                            components.append(component)
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    completion(.success(components))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Save world state with advanced compression
    public func saveWorldState(_ world: World, completion: @escaping (Result<Void, Error>) -> Void) {
        let backgroundContext = coreDataManager.persistentContainer.newBackgroundContext()
        
        backgroundContext.perform {
            do {
                // Create world state snapshot
                let worldSnapshot = WorldSnapshot(context: backgroundContext)
                worldSnapshot.id = UUID()
                worldSnapshot.timestamp = Date()
                worldSnapshot.version = "1.0.0"
                
                // Serialize entity manager state
                let entityManagerData = try self.serializeEntityManager(world.entityManager)
                worldSnapshot.entityManagerData = self.compressionManager.compress(entityManagerData)
                
                // Serialize performance stats
                let performanceData = try self.serializePerformanceStats(world.getPerformanceStats())
                worldSnapshot.performanceData = self.compressionManager.compress(performanceData)
                
                // Save component storages
                worldSnapshot.componentStorageData = try self.serializeComponentStorages(world)
                
                try backgroundContext.save()
                
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Load world state with decompression
    public func loadWorldState(snapshotId: UUID, completion: @escaping (Result<WorldStateData, Error>) -> Void) {
        let backgroundContext = coreDataManager.persistentContainer.newBackgroundContext()
        
        backgroundContext.perform {
            do {
                let request: NSFetchRequest<WorldSnapshot> = WorldSnapshot.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", snapshotId as CVarArg)
                
                guard let snapshot = try backgroundContext.fetch(request).first else {
                    throw ECSPersistenceError.snapshotNotFound
                }
                
                // Deserialize entity manager
                let entityManagerData = self.compressionManager.decompress(snapshot.entityManagerData!)
                let entityManagerState = try self.deserializeEntityManager(entityManagerData)
                
                // Deserialize performance stats
                var performanceStats: PerformanceStats?
                if let perfData = snapshot.performanceData {
                    let decompressedPerfData = self.compressionManager.decompress(perfData)
                    performanceStats = try self.deserializePerformanceStats(decompressedPerfData)
                }
                
                // Deserialize component storages
                let componentStorageData = try self.deserializeComponentStorages(snapshot.componentStorageData!)
                
                let worldStateData = WorldStateData(
                    entityManagerState: entityManagerState,
                    componentStorageData: componentStorageData,
                    performanceStats: performanceStats,
                    timestamp: snapshot.timestamp!
                )
                
                DispatchQueue.main.async {
                    completion(.success(worldStateData))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Batch Operations
    
    private func flushPendingChanges() {
        guard !pendingComponents.isEmpty else { return }
        
        let componentsToSave = pendingComponents
        let entitiesToUpdate = componentChangeSet
        
        pendingComponents.removeAll()
        componentChangeSet.removeAll()
        
        let backgroundContext = coreDataManager.persistentContainer.newBackgroundContext()
        
        backgroundContext.perform {
            do {
                for (entity, components) in componentsToSave {
                    try self.saveComponentsBatch(components, for: entity, context: backgroundContext)
                }
                
                try backgroundContext.save()
                self.lastSaveTimestamp = Date()
            } catch {
                print("Failed to save component batch: \(error)")
            }
        }
    }
    
    private func saveComponentsBatch(_ components: [Component], for entity: Entity, context: NSManagedObjectContext) throws {
        // Delete existing components for this entity
        let deleteRequest: NSFetchRequest<ComponentData> = ComponentData.fetchRequest()
        deleteRequest.predicate = NSPredicate(format: "entityId == %@", entity.id as CVarArg)
        
        let existingComponents = try context.fetch(deleteRequest)
        for component in existingComponents {
            context.delete(component)
        }
        
        // Save new components
        for component in components {
            let componentData = ComponentData(context: context)
            componentData.entityId = entity.id
            componentData.componentType = Int32(type(of: component).componentType.rawValue)
            componentData.timestamp = Date()
            
            let serializedData = try componentSerializer.serialize(component)
            
            // Compress if data is large enough
            if serializedData.count > 512 {
                componentData.data = compressionManager.compress(serializedData)
                componentData.isCompressed = true
            } else {
                componentData.data = serializedData
                componentData.isCompressed = false
            }
        }
    }
    
    // MARK: - Serialization Helpers
    
    private func serializeEntityManager(_ entityManager: EntityManager) throws -> Data {
        let stats = entityManager.getStats()
        let encoder = JSONEncoder()
        return try encoder.encode(stats)
    }
    
    private func deserializeEntityManager(_ data: Data) throws -> EntityManagerStats {
        let decoder = JSONDecoder()
        return try decoder.decode(EntityManagerStats.self, from: data)
    }
    
    private func serializePerformanceStats(_ stats: PerformanceStats) throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(stats)
    }
    
    private func deserializePerformanceStats(_ data: Data) throws -> PerformanceStats {
        let decoder = JSONDecoder()
        return try decoder.decode(PerformanceStats.self, from: data)
    }
    
    private func serializeComponentStorages(_ world: World) throws -> Data {
        // This would serialize all component storage states
        // For now, return empty data as a placeholder
        return Data()
    }
    
    private func deserializeComponentStorages(_ data: Data) throws -> [String: Any] {
        // This would deserialize component storage states
        // For now, return empty dictionary as a placeholder
        return [:]
    }
    
    // MARK: - Cleanup
    
    deinit {
        batchSaveTimer?.invalidate()
        flushPendingChanges()
    }
}

// MARK: - Component Serialization

/// High-performance component serializer with type safety
public class ComponentSerializer {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    public init() {
        encoder.outputFormatting = .sortedKeys // For consistent serialization
    }
    
    public func serialize(_ component: Component) throws -> Data {
        switch component {
        case let transform as TransformComponent:
            return try encoder.encode(transform)
        case let ship as ShipComponent:
            return try encoder.encode(ship)
        case let warehouse as WarehouseComponent:
            return try encoder.encode(warehouse)
        case let port as PortComponent:
            return try encoder.encode(port)
        case let cargo as CargoComponent:
            return try encoder.encode(cargo)
        case let ai as AIComponent:
            return try encoder.encode(ai)
        case let touchInput as TouchInputComponent:
            return try encoder.encode(touchInput)
        default:
            throw ECSPersistenceError.unsupportedComponentType
        }
    }
    
    public func deserialize(data: Data, type: ComponentType) throws -> Component {
        switch type {
        case .transform:
            return try decoder.decode(TransformComponent.self, from: data)
        case .ship:
            return try decoder.decode(ShipComponent.self, from: data)
        case .warehouse:
            return try decoder.decode(WarehouseComponent.self, from: data)
        case .port:
            return try decoder.decode(PortComponent.self, from: data)
        case .cargo:
            return try decoder.decode(CargoComponent.self, from: data)
        case .ai:
            return try decoder.decode(AIComponent.self, from: data)
        case .touchInput:
            return try decoder.decode(TouchInputComponent.self, from: data)
        default:
            throw ECSPersistenceError.unsupportedComponentType
        }
    }
}

// MARK: - Compression Manager

/// Data compression manager for optimizing storage
public class CompressionManager {
    public func compress(_ data: Data) -> Data {
        // Use iOS built-in compression
        do {
            return try (data as NSData).compressed(using: .lzfse) as Data
        } catch {
            print("Compression failed: \(error)")
            return data
        }
    }
    
    public func decompress(_ data: Data) -> Data {
        do {
            return try (data as NSData).decompressed(using: .lzfse) as Data
        } catch {
            print("Decompression failed: \(error)")
            return data
        }
    }
}

// MARK: - Supporting Types

public struct WorldStateData {
    let entityManagerState: EntityManagerStats
    let componentStorageData: [String: Any]
    let performanceStats: PerformanceStats?
    let timestamp: Date
}

public enum ECSPersistenceError: LocalizedError {
    case snapshotNotFound
    case unsupportedComponentType
    case serializationFailed
    case deserializationFailed
    
    public var errorDescription: String? {
        switch self {
        case .snapshotNotFound:
            return "World snapshot not found"
        case .unsupportedComponentType:
            return "Unsupported component type for serialization"
        case .serializationFailed:
            return "Failed to serialize component data"
        case .deserializationFailed:
            return "Failed to deserialize component data"
        }
    }
}

// MARK: - PerformanceStats Codable Extension

extension PerformanceStats: Codable {
    enum CodingKeys: String, CodingKey {
        case averageFrameTime
        case currentFPS
        case targetFPS
        case droppedFrames
        case frameCount
    }
}

// MARK: - EntityManagerStats Codable Extension

extension EntityManagerStats: Codable {
    enum CodingKeys: String, CodingKey {
        case activeEntities
        case pooledEntities
        case archetypeCount
        case spatialCells
    }
}