import Foundation

/// Protocol that all components must conform to
public protocol Component: Codable {
    static var componentType: ComponentType { get }
}

/// Enum representing all component types in the game
public enum ComponentType: Int, CaseIterable {
    case transform
    case ship
    case warehouse
    case port
    case cargo
    case economy
    case ai
    case route
    case physics
    case trader
    case singularity
    case touchInput
    
    var bitMask: UInt64 {
        1 << rawValue
    }
}

/// ComponentMask for efficient component queries
public struct ComponentMask: Hashable {
    private var mask: UInt64 = 0
    
    public init() {}
    
    public init(components: [ComponentType]) {
        for component in components {
            set(component)
        }
    }
    
    mutating func set(_ componentType: ComponentType) {
        mask |= componentType.bitMask
    }
    
    mutating func unset(_ componentType: ComponentType) {
        mask &= ~componentType.bitMask
    }
    
    func has(_ componentType: ComponentType) -> Bool {
        (mask & componentType.bitMask) != 0
    }
    
    /// Check if this mask contains all components in another mask
    func contains(_ other: ComponentMask) -> Bool {
        (mask & other.mask) == other.mask
    }
    
    /// Check if this mask intersects with another mask
    func intersects(_ other: ComponentMask) -> Bool {
        (mask & other.mask) != 0
    }
    
    /// Get the raw mask value for debugging
    var rawValue: UInt64 { mask }
}

/// Component storage protocol
public protocol ComponentStorage {
    associatedtype ComponentType: Component
    
    func add(_ component: ComponentType, to entity: Entity)
    func remove(from entity: Entity)
    func get(for entity: Entity) -> ComponentType?
    func getAll() -> [(Entity, ComponentType)]
}

/// High-performance component storage with batching and cache optimization
public class GenericComponentStorage<T: Component>: ComponentStorage {
    private var components: [Entity: T] = [:]
    private var componentArray: [T] = []
    private var entityArray: [Entity] = []
    private var indices: [Entity: Int] = [:]
    private var freeIndices: [Int] = []
    
    // Batch processing support
    private var isDirty = false
    private let batchSize = 32
    
    public init() {}
    
    public func add(_ component: T, to entity: Entity) {
        if let existingIndex = indices[entity] {
            // Update existing component
            componentArray[existingIndex] = component
            components[entity] = component
        } else {
            // Add new component
            let index: Int
            if let freeIndex = freeIndices.popLast() {
                index = freeIndex
                componentArray[index] = component
                entityArray[index] = entity
            } else {
                index = componentArray.count
                componentArray.append(component)
                entityArray.append(entity)
            }
            
            indices[entity] = index
            components[entity] = component
        }
        isDirty = true
    }
    
    public func remove(from entity: Entity) {
        guard let index = indices[entity] else { return }
        
        indices.removeValue(forKey: entity)
        components.removeValue(forKey: entity)
        freeIndices.append(index)
        isDirty = true
    }
    
    public func get(for entity: Entity) -> T? {
        components[entity]
    }
    
    public func getAll() -> [(Entity, T)] {
        components.map { ($0.key, $0.value) }
    }
    
    /// Get components in batches for cache-friendly processing
    public func getBatch(startIndex: Int, batchSize: Int) -> ArraySlice<T> {
        let endIndex = min(startIndex + batchSize, componentArray.count)
        return componentArray[startIndex..<endIndex]
    }
    
    /// Get corresponding entities for batch processing
    public func getEntityBatch(startIndex: Int, batchSize: Int) -> ArraySlice<Entity> {
        let endIndex = min(startIndex + batchSize, entityArray.count)
        return entityArray[startIndex..<endIndex]
    }
    
    /// Get total number of active components
    public var count: Int {
        return componentArray.count - freeIndices.count
    }
    
    /// Compact the arrays to remove gaps from deleted components
    public func compact() {
        guard isDirty && !freeIndices.isEmpty else { return }
        
        var newComponentArray: [T] = []
        var newEntityArray: [Entity] = []
        var newIndices: [Entity: Int] = [:]
        
        for (oldIndex, entity) in entityArray.enumerated() {
            if !freeIndices.contains(oldIndex) {
                let newIndex = newComponentArray.count
                newComponentArray.append(componentArray[oldIndex])
                newEntityArray.append(entity)
                newIndices[entity] = newIndex
            }
        }
        
        componentArray = newComponentArray
        entityArray = newEntityArray
        indices = newIndices
        freeIndices.removeAll()
        isDirty = false
    }
    
    /// Process components in batches with a closure
    public func processBatches<R>(batchSize: Int = 32, processor: (ArraySlice<T>, ArraySlice<Entity>) -> [R]) -> [R] {
        var results: [R] = []
        let totalComponents = count
        
        for startIndex in stride(from: 0, to: totalComponents, by: batchSize) {
            let componentBatch = getBatch(startIndex: startIndex, batchSize: batchSize)
            let entityBatch = getEntityBatch(startIndex: startIndex, batchSize: batchSize)
            let batchResults = processor(componentBatch, entityBatch)
            results.append(contentsOf: batchResults)
        }
        
        return results
    }
}

/// Transform component for position and rotation
public struct TransformComponent: Component {
    public static let componentType = ComponentType.transform
    
    public var position: SIMD3<Float>
    public var rotation: SIMD4<Float> // Quaternion
    public var scale: SIMD3<Float>
    
    public init(position: SIMD3<Float> = .zero, 
                rotation: SIMD4<Float> = SIMD4<Float>(0, 0, 0, 1), 
                scale: SIMD3<Float> = SIMD3<Float>(1, 1, 1)) {
        self.position = position
        self.rotation = rotation
        self.scale = scale
    }
}

/// Ship component for vessel properties
public struct ShipComponent: Component {
    public static let componentType = ComponentType.ship
    
    public var name: String
    public var capacity: Int
    public var speed: Float
    public var efficiency: Float
    public var maintenanceCost: Double
    public var currentPort: Entity?
    public var destination: Entity?
    public var fuelCapacity: Float
    public var currentFuel: Float
    
    public init(name: String, capacity: Int, speed: Float, efficiency: Float, 
                maintenanceCost: Double, fuelCapacity: Float) {
        self.name = name
        self.capacity = capacity
        self.speed = speed
        self.efficiency = efficiency
        self.maintenanceCost = maintenanceCost
        self.fuelCapacity = fuelCapacity
        self.currentFuel = fuelCapacity
    }
}

/// Warehouse component for storage facilities
public struct WarehouseComponent: Component {
    public static let componentType = ComponentType.warehouse
    
    public var capacity: Int
    public var usedCapacity: Int
    public var storageCost: Double
    public var securityLevel: Float
    public var temperatureControl: Bool
    
    public init(capacity: Int, storageCost: Double, securityLevel: Float = 1.0, 
                temperatureControl: Bool = false) {
        self.capacity = capacity
        self.usedCapacity = 0
        self.storageCost = storageCost
        self.securityLevel = securityLevel
        self.temperatureControl = temperatureControl
    }
}

/// Port component for trade hubs
public struct PortComponent: Component {
    public static let componentType = ComponentType.port
    
    public var name: String
    public var portType: PortType
    public var maxBerths: Int
    public var availableBerths: Int
    public var portFees: Double
    public var handlingEfficiency: Float
    
    public init(name: String, portType: PortType, maxBerths: Int, portFees: Double, 
                handlingEfficiency: Float = 1.0) {
        self.name = name
        self.portType = portType
        self.maxBerths = maxBerths
        self.availableBerths = maxBerths
        self.portFees = portFees
        self.handlingEfficiency = handlingEfficiency
    }
}

/// Cargo component for tradeable goods
public struct CargoComponent: Component {
    public static let componentType = ComponentType.cargo
    
    public var commodityType: String
    public var quantity: Int
    public var weight: Float
    public var value: Double
    public var perishable: Bool
    public var expiryDate: Date?
    
    public init(commodityType: String, quantity: Int, weight: Float, value: Double, 
                perishable: Bool = false, expiryDate: Date? = nil) {
        self.commodityType = commodityType
        self.quantity = quantity
        self.weight = weight
        self.value = value
        self.perishable = perishable
        self.expiryDate = expiryDate
    }
}

/// AI component for computer-controlled entities
public struct AIComponent: Component {
    public static let componentType = ComponentType.ai
    
    public var behaviorType: AIBehaviorType
    public var learningRate: Double
    public var riskTolerance: Float
    public var decisionCooldown: TimeInterval
    public var lastDecisionTime: Date
    
    public enum AIBehaviorType: String, Codable {
        case aggressive
        case conservative
        case balanced
        case experimental
    }
    
    public init(behaviorType: AIBehaviorType, learningRate: Double = 0.01, 
                riskTolerance: Float = 0.5) {
        self.behaviorType = behaviorType
        self.learningRate = learningRate
        self.riskTolerance = riskTolerance
        self.decisionCooldown = 5.0
        self.lastDecisionTime = Date()
    }
}

/// Touch input component for entities that can be interacted with via touch
public struct TouchInputComponent: Component {
    public static let componentType = ComponentType.touchInput
    
    public var isSelected: Bool
    public var isHovered: Bool
    public var isDragTarget: Bool
    public var selectionTime: Date?
    public var lastInteractionTime: Date
    public var interactionCount: Int
    public var isSelectable: Bool
    public var isDraggable: Bool
    public var selectionRadius: Float
    public var highlightIntensity: Float
    
    public init(isSelected: Bool = false,
                isHovered: Bool = false,
                isDragTarget: Bool = false,
                selectionTime: Date? = nil,
                isSelectable: Bool = true,
                isDraggable: Bool = true,
                selectionRadius: Float = 50.0,
                highlightIntensity: Float = 1.0) {
        self.isSelected = isSelected
        self.isHovered = isHovered
        self.isDragTarget = isDragTarget
        self.selectionTime = selectionTime
        self.lastInteractionTime = Date()
        self.interactionCount = 0
        self.isSelectable = isSelectable
        self.isDraggable = isDraggable
        self.selectionRadius = selectionRadius
        self.highlightIntensity = highlightIntensity
    }
    
    public mutating func recordInteraction() {
        lastInteractionTime = Date()
        interactionCount += 1
    }
    
    public mutating func select() {
        guard isSelectable else { return }
        isSelected = true
        selectionTime = Date()
        recordInteraction()
    }
    
    public mutating func deselect() {
        isSelected = false
        selectionTime = nil
    }
    
    public mutating func setHovered(_ hovered: Bool) {
        isHovered = hovered
        if hovered {
            recordInteraction()
        }
    }
    
    public mutating func setDragTarget(_ isDrag: Bool) {
        guard isDraggable else { return }
        isDragTarget = isDrag
        if isDrag {
            recordInteraction()
        }
    }
}