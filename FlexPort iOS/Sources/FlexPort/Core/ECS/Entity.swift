import Foundation

/// Entity represents a unique identifier in the ECS system
public struct Entity: Hashable, Identifiable {
    public let id: UUID
    
    public init() {
        self.id = UUID()
    }
}

/// High-performance EntityManager with advanced memory pooling and batch operations
public class EntityManager {
    private var entities: Set<Entity> = []
    private var entityComponentMask: [Entity: ComponentMask] = [:]
    
    // Advanced memory pooling
    private var entityPool = EntityPool()
    private var activeEntities: [Entity] = []
    private var entityToIndex: [Entity: Int] = [:]
    private var freeIndices: [Int] = []
    
    // Spatial partitioning for map view entities (containers, ships, etc.)
    private var spatialGrid = SpatialGrid(cellSize: 100.0)
    
    // Entity archetype system for batch processing
    private var archetypes: [ComponentMask: Archetype] = [:]
    
    public init() {}
    
    /// Creates a new entity with optimized pooling
    public func createEntity() -> Entity {
        let entity = entityPool.acquire()
        
        let index: Int
        if let freeIndex = freeIndices.popLast() {
            index = freeIndex
            activeEntities[index] = entity
        } else {
            index = activeEntities.count
            activeEntities.append(entity)
        }
        
        entities.insert(entity)
        entityToIndex[entity] = index
        entityComponentMask[entity] = ComponentMask()
        
        return entity
    }
    
    /// Destroys an entity and returns it to the pool
    public func destroyEntity(_ entity: Entity) {
        guard let index = entityToIndex[entity] else { return }
        
        entities.remove(entity)
        entityComponentMask.removeValue(forKey: entity)
        entityToIndex.removeValue(forKey: entity)
        freeIndices.append(index)
        
        // Remove from spatial grid if it was spatially tracked
        spatialGrid.remove(entity)
        
        // Return to pool
        entityPool.release(entity)
    }
    
    /// Batch create entities for map initialization (containers, ships, etc.)
    public func createEntitiesBatch(count: Int) -> [Entity] {
        var newEntities: [Entity] = []
        newEntities.reserveCapacity(count)
        
        for _ in 0..<count {
            newEntities.append(createEntity())
        }
        
        return newEntities
    }
    
    /// Update entity position for spatial queries (important for map view)
    public func updateEntityPosition(_ entity: Entity, position: SIMD3<Float>) {
        spatialGrid.update(entity, position: position)
    }
    
    /// Get entities within a spatial region (for map view culling)
    public func getEntitiesInRegion(center: SIMD3<Float>, radius: Float) -> [Entity] {
        return spatialGrid.query(center: center, radius: radius)
    }
    
    /// Get entities within view frustum for rendering optimization
    public func getEntitiesInFrustum(frustum: ViewFrustum) -> [Entity] {
        return spatialGrid.queryFrustum(frustum)
    }
    
    /// Checks if an entity exists
    public func exists(_ entity: Entity) -> Bool {
        entities.contains(entity)
    }
    
    /// Updates the component mask for an entity and manages archetypes
    public func updateComponentMask(_ entity: Entity, componentType: ComponentType) {
        guard let currentMask = entityComponentMask[entity] else { return }
        
        // Remove from current archetype
        if let archetype = archetypes[currentMask] {
            archetype.removeEntity(entity)
        }
        
        // Update mask
        var newMask = currentMask
        newMask.set(componentType)
        entityComponentMask[entity] = newMask
        
        // Add to new archetype
        if archetypes[newMask] == nil {
            archetypes[newMask] = Archetype(mask: newMask)
        }
        archetypes[newMask]?.addEntity(entity)
    }
    
    /// Removes a component type from an entity's mask
    public func removeComponentFromMask(_ entity: Entity, componentType: ComponentType) {
        guard let currentMask = entityComponentMask[entity] else { return }
        
        // Remove from current archetype
        if let archetype = archetypes[currentMask] {
            archetype.removeEntity(entity)
        }
        
        // Update mask
        var newMask = currentMask
        newMask.unset(componentType)
        entityComponentMask[entity] = newMask
        
        // Add to new archetype
        if archetypes[newMask] == nil {
            archetypes[newMask] = Archetype(mask: newMask)
        }
        archetypes[newMask]?.addEntity(entity)
    }
    
    /// Gets all entities with a specific component mask (optimized with archetypes)
    public func getEntitiesWithComponents(_ components: [ComponentType]) -> [Entity] {
        let queryMask = ComponentMask(components: components)
        
        return archetypes.compactMap { (mask, archetype) in
            mask.contains(queryMask) ? archetype.entities : nil
        }.flatMap { $0 }
    }
    
    /// Get entities in batches for parallel processing
    public func getEntitiesBatch(startIndex: Int, batchSize: Int) -> ArraySlice<Entity> {
        let endIndex = min(startIndex + batchSize, activeEntities.count)
        return activeEntities[startIndex..<endIndex]
    }
    
    /// Compact entity arrays to remove gaps
    public func compact() {
        guard !freeIndices.isEmpty else { return }
        
        var newActiveEntities: [Entity] = []
        var newEntityToIndex: [Entity: Int] = [:]
        
        for (oldIndex, entity) in activeEntities.enumerated() {
            if !freeIndices.contains(oldIndex) {
                let newIndex = newActiveEntities.count
                newActiveEntities.append(entity)
                newEntityToIndex[entity] = newIndex
            }
        }
        
        activeEntities = newActiveEntities
        entityToIndex = newEntityToIndex
        freeIndices.removeAll()
    }
    
    /// Get performance statistics
    public func getStats() -> EntityManagerStats {
        return EntityManagerStats(
            activeEntities: entities.count,
            pooledEntities: entityPool.availableCount,
            archetypeCount: archetypes.count,
            spatialCells: spatialGrid.cellCount
        )
    }
}

/// Entity pool for memory optimization
private class EntityPool {
    private var pool: [Entity] = []
    private let maxPoolSize = 10000
    
    var availableCount: Int { pool.count }
    
    func acquire() -> Entity {
        if !pool.isEmpty {
            return pool.removeLast()
        } else {
            return Entity()
        }
    }
    
    func release(_ entity: Entity) {
        if pool.count < maxPoolSize {
            pool.append(entity)
        }
    }
}

/// Archetype system for grouping entities with same component combinations
private class Archetype {
    let mask: ComponentMask
    private(set) var entities: [Entity] = []
    
    init(mask: ComponentMask) {
        self.mask = mask
    }
    
    func addEntity(_ entity: Entity) {
        entities.append(entity)
    }
    
    func removeEntity(_ entity: Entity) {
        entities.removeAll { $0.id == entity.id }
    }
}

/// Spatial grid for efficient spatial queries (crucial for map view performance)
private class SpatialGrid {
    private let cellSize: Float
    private var grid: [SIMD2<Int>: Set<Entity>] = [:]
    private var entityPositions: [Entity: SIMD3<Float>] = [:]
    
    var cellCount: Int { grid.count }
    
    init(cellSize: Float) {
        self.cellSize = cellSize
    }
    
    private func getCellCoordinate(_ position: SIMD3<Float>) -> SIMD2<Int> {
        return SIMD2<Int>(Int(position.x / cellSize), Int(position.z / cellSize))
    }
    
    func update(_ entity: Entity, position: SIMD3<Float>) {
        // Remove from old cell if exists
        if let oldPosition = entityPositions[entity] {
            let oldCell = getCellCoordinate(oldPosition)
            grid[oldCell]?.remove(entity)
            if grid[oldCell]?.isEmpty == true {
                grid.removeValue(forKey: oldCell)
            }
        }
        
        // Add to new cell
        let newCell = getCellCoordinate(position)
        if grid[newCell] == nil {
            grid[newCell] = Set<Entity>()
        }
        grid[newCell]?.insert(entity)
        entityPositions[entity] = position
    }
    
    func remove(_ entity: Entity) {
        guard let position = entityPositions[entity] else { return }
        let cell = getCellCoordinate(position)
        grid[cell]?.remove(entity)
        if grid[cell]?.isEmpty == true {
            grid.removeValue(forKey: cell)
        }
        entityPositions.removeValue(forKey: entity)
    }
    
    func query(center: SIMD3<Float>, radius: Float) -> [Entity] {
        let cellRadius = Int(ceil(radius / cellSize))
        let centerCell = getCellCoordinate(center)
        
        var result: [Entity] = []
        
        for x in (centerCell.x - cellRadius)...(centerCell.x + cellRadius) {
            for z in (centerCell.y - cellRadius)...(centerCell.y + cellRadius) {
                let cell = SIMD2<Int>(x, z)
                if let entities = grid[cell] {
                    for entity in entities {
                        if let entityPos = entityPositions[entity] {
                            let distance = length(entityPos - center)
                            if distance <= radius {
                                result.append(entity)
                            }
                        }
                    }
                }
            }
        }
        
        return result
    }
    
    func queryFrustum(_ frustum: ViewFrustum) -> [Entity] {
        // Simplified frustum culling - in production would use proper frustum intersection
        let center = frustum.center
        let radius = frustum.farDistance
        return query(center: center, radius: radius)
    }
}

/// View frustum for culling
public struct ViewFrustum {
    let center: SIMD3<Float>
    let farDistance: Float
    let nearDistance: Float
    let fov: Float
    
    public init(center: SIMD3<Float>, farDistance: Float, nearDistance: Float, fov: Float) {
        self.center = center
        self.farDistance = farDistance
        self.nearDistance = nearDistance
        self.fov = fov
    }
}

/// Performance statistics
public struct EntityManagerStats {
    let activeEntities: Int
    let pooledEntities: Int
    let archetypeCount: Int
    let spatialCells: Int
}