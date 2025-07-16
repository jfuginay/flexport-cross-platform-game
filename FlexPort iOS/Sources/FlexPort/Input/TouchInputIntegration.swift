import Foundation
import Combine
import UIKit
import simd

/// Integrates touch input system with the ECS architecture for game interaction
public class TouchInputIntegration: System {
    
    // MARK: - System Protocol
    public let priority = 50 // Higher priority than movement system
    
    // MARK: - Dependencies
    private let touchInputManager: TouchInputManager
    private let hapticManager: HapticManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Touch Event Processing
    @Published public private(set) var selectedEntities: Set<Entity> = []
    @Published public private(set) var hoveredEntity: Entity?
    @Published public private(set) var isDragging: Bool = false
    @Published public private(set) var currentDragTarget: Entity?
    
    // MARK: - Input State
    private var lastTapTime: Date = Date()
    private var doubleTapThreshold: TimeInterval = 0.3
    private var dragStartPosition: SIMD2<Float>?
    private var dragThreshold: Float = 10.0
    
    // MARK: - World Interaction
    private var worldBounds: (min: SIMD2<Float>, max: SIMD2<Float>) = (
        min: SIMD2<Float>(-1000, -1000),
        max: SIMD2<Float>(1000, 1000)
    )
    
    // MARK: - Publishers for game events
    public let entitySelected = PassthroughSubject<EntitySelectionEvent, Never>()
    public let entityDeselected = PassthroughSubject<Entity, Never>()
    public let entityDragStarted = PassthroughSubject<EntityDragEvent, Never>()
    public let entityDragMoved = PassthroughSubject<EntityDragEvent, Never>()
    public let entityDragEnded = PassthroughSubject<EntityDragEvent, Never>()
    public let worldTapped = PassthroughSubject<WorldTapEvent, Never>()
    public let cameraControlRequested = PassthroughSubject<CameraControlEvent, Never>()
    
    // MARK: - Initialization
    public init(touchInputManager: TouchInputManager, hapticManager: HapticManager = HapticManager.shared) {
        self.touchInputManager = touchInputManager
        self.hapticManager = hapticManager
        
        setupTouchEventBindings()
        setupGestureEventBindings()
    }
    
    // MARK: - System Update
    public func update(deltaTime: TimeInterval, world: World) {
        // Process hover detection
        updateHoverDetection(world: world)
        
        // Update drag operations
        updateDragOperations(world: world)
        
        // Update selection states
        updateSelectionStates(world: world)
    }
    
    // MARK: - Public Interface
    
    /// Set the world bounds for touch interaction
    public func setWorldBounds(min: SIMD2<Float>, max: SIMD2<Float>) {
        worldBounds = (min: min, max: max)
    }
    
    /// Select entity programmatically
    public func selectEntity(_ entity: Entity, in world: World, addToSelection: Bool = false) {
        guard world.getComponent(TransformComponent.self, for: entity) != nil else { return }
        
        if !addToSelection {
            clearSelection()
        }
        
        selectedEntities.insert(entity)
        
        // Add selection component if needed
        addSelectionComponent(to: entity, in: world)
        
        let event = EntitySelectionEvent(
            entity: entity,
            selectionType: addToSelection ? .additive : .exclusive,
            worldPosition: world.getComponent(TransformComponent.self, for: entity)?.position.xz ?? SIMD2<Float>(0, 0)
        )
        
        entitySelected.send(event)
        hapticManager.playShipSelectionFeedback()
    }
    
    /// Deselect entity
    public func deselectEntity(_ entity: Entity, in world: World) {
        selectedEntities.remove(entity)
        removeSelectionComponent(from: entity, in: world)
        entityDeselected.send(entity)
    }
    
    /// Clear all selections
    public func clearSelection() {
        selectedEntities.removeAll()
    }
    
    /// Check if entity is selectable
    public func isEntitySelectable(_ entity: Entity, in world: World) -> Bool {
        // Check if entity has required components for selection
        let hasTransform = world.getComponent(TransformComponent.self, for: entity) != nil
        let hasShip = world.getComponent(ShipComponent.self, for: entity) != nil
        let hasPort = world.getComponent(PortComponent.self, for: entity) != nil
        let hasWarehouse = world.getComponent(WarehouseComponent.self, for: entity) != nil
        
        return hasTransform && (hasShip || hasPort || hasWarehouse)
    }
    
    // MARK: - Private Implementation
    
    private func setupTouchEventBindings() {
        // Single tap handling
        touchInputManager.touchBegan
            .sink { [weak self] touchEvent in
                self?.handleTouchBegan(touchEvent)
            }
            .store(in: &cancellables)
        
        touchInputManager.touchMoved
            .sink { [weak self] touchEvent in
                self?.handleTouchMoved(touchEvent)
            }
            .store(in: &cancellables)
        
        touchInputManager.touchEnded
            .sink { [weak self] touchEvent in
                self?.handleTouchEnded(touchEvent)
            }
            .store(in: &cancellables)
    }
    
    private func setupGestureEventBindings() {
        // Gesture handling
        touchInputManager.gestureBegan
            .sink { [weak self] gestureEvent in
                self?.handleGestureBegan(gestureEvent)
            }
            .store(in: &cancellables)
        
        touchInputManager.gestureChanged
            .sink { [weak self] gestureEvent in
                self?.handleGestureChanged(gestureEvent)
            }
            .store(in: &cancellables)
        
        touchInputManager.gestureEnded
            .sink { [weak self] gestureEvent in
                self?.handleGestureEnded(gestureEvent)
            }
            .store(in: &cancellables)
    }
    
    private func handleTouchBegan(_ touchEvent: TouchEvent) {
        dragStartPosition = touchEvent.touchData.worldPosition
    }
    
    private func handleTouchMoved(_ touchEvent: TouchEvent) {
        guard let startPos = dragStartPosition else { return }
        
        let currentPos = touchEvent.touchData.worldPosition
        let dragDistance = length(currentPos - startPos)
        
        if !isDragging && dragDistance > dragThreshold {
            startDragOperation(from: startPos, to: currentPos)
        } else if isDragging {
            updateDragOperation(to: currentPos)
        }
    }
    
    private func handleTouchEnded(_ touchEvent: TouchEvent) {
        if isDragging {
            endDragOperation(at: touchEvent.touchData.worldPosition)
        } else {
            // Handle tap
            handleTap(at: touchEvent.touchData.worldPosition)
        }
        
        dragStartPosition = nil
    }
    
    private func handleGestureBegan(_ gestureEvent: GestureEvent) {
        switch gestureEvent.type {
        case .pan:
            handlePanGestureBegan(gestureEvent)
        case .pinch:
            handlePinchGestureBegan(gestureEvent)
        case .longPress:
            handleLongPressGestureBegan(gestureEvent)
        default:
            break
        }
    }
    
    private func handleGestureChanged(_ gestureEvent: GestureEvent) {
        switch gestureEvent.type {
        case .pan:
            handlePanGestureChanged(gestureEvent)
        case .pinch:
            handlePinchGestureChanged(gestureEvent)
        default:
            break
        }
    }
    
    private func handleGestureEnded(_ gestureEvent: GestureEvent) {
        switch gestureEvent.type {
        case .pan:
            handlePanGestureEnded(gestureEvent)
        case .pinch:
            handlePinchGestureEnded(gestureEvent)
        case .longPress:
            handleLongPressGestureEnded(gestureEvent)
        default:
            break
        }
    }
    
    private func handleTap(at worldPosition: SIMD2<Float>) {
        let now = Date()
        let isDoubleTap = now.timeIntervalSince(lastTapTime) < doubleTapThreshold
        lastTapTime = now
        
        // Find entity at position
        if let entity = findEntityAt(worldPosition) {
            if isDoubleTap {
                handleEntityDoubleTap(entity, at: worldPosition)
            } else {
                handleEntityTap(entity, at: worldPosition)
            }
        } else {
            // Empty space tap
            handleWorldTap(at: worldPosition, isDoubleTap: isDoubleTap)
        }
    }
    
    private func handleEntityTap(_ entity: Entity, at worldPosition: SIMD2<Float>) {
        // Toggle selection or add to selection
        if selectedEntities.contains(entity) {
            // Entity already selected, could deselect or keep selected
            if selectedEntities.count == 1 {
                // Keep single selection
            } else {
                // Deselect from multi-selection
                deselectEntity(entity, in: getCurrentWorld())
            }
        } else {
            // Select entity (replace current selection)
            selectEntity(entity, in: getCurrentWorld(), addToSelection: false)
        }
    }
    
    private func handleEntityDoubleTap(_ entity: Entity, at worldPosition: SIMD2<Float>) {
        // Double tap actions (e.g., focus camera, open details)
        selectEntity(entity, in: getCurrentWorld(), addToSelection: false)
        
        let event = CameraControlEvent(
            type: .focusOn,
            targetPosition: worldPosition,
            targetEntity: entity
        )
        cameraControlRequested.send(event)
        hapticManager.playNavigationFeedback()
    }
    
    private func handleWorldTap(at worldPosition: SIMD2<Float>, isDoubleTap: Bool) {
        if !isDoubleTap {
            // Clear selection on single tap in empty space
            clearSelection()
        }
        
        let event = WorldTapEvent(
            worldPosition: worldPosition,
            isDoubleTap: isDoubleTap,
            selectedEntities: Array(selectedEntities)
        )
        worldTapped.send(event)
    }
    
    private func handlePanGestureBegan(_ gestureEvent: GestureEvent) {
        // Check if panning selected entity or camera
        if let entity = findEntityAt(gestureEvent.location), selectedEntities.contains(entity) {
            startEntityDrag(entity, at: gestureEvent.location)
        } else {
            startCameraPan(at: gestureEvent.location)
        }
    }
    
    private func handlePanGestureChanged(_ gestureEvent: GestureEvent) {
        if isDragging {
            updateDragOperation(to: gestureEvent.location)
        } else {
            updateCameraPan(gestureEvent)
        }
    }
    
    private func handlePanGestureEnded(_ gestureEvent: GestureEvent) {
        if isDragging {
            endDragOperation(at: gestureEvent.location)
        } else {
            endCameraPan(gestureEvent)
        }
    }
    
    private func handlePinchGestureBegan(_ gestureEvent: GestureEvent) {
        let event = CameraControlEvent(
            type: .zoomBegan,
            targetPosition: gestureEvent.location
        )
        cameraControlRequested.send(event)
    }
    
    private func handlePinchGestureChanged(_ gestureEvent: GestureEvent) {
        guard let scale = gestureEvent.properties["scale"] as? Float else { return }
        
        let event = CameraControlEvent(
            type: .zoom,
            targetPosition: gestureEvent.location,
            scale: scale
        )
        cameraControlRequested.send(event)
    }
    
    private func handleLongPressGestureBegan(_ gestureEvent: GestureEvent) {
        // Long press for context menu or special actions
        if let entity = findEntityAt(gestureEvent.location) {
            handleEntityLongPress(entity, at: gestureEvent.location)
        } else {
            handleWorldLongPress(at: gestureEvent.location)
        }
    }
    
    private func handleLongPressGestureEnded(_ gestureEvent: GestureEvent) {
        // End long press action
    }
    
    private func startEntityDrag(_ entity: Entity, at position: SIMD2<Float>) {
        isDragging = true
        currentDragTarget = entity
        
        let event = EntityDragEvent(
            entity: entity,
            startPosition: position,
            currentPosition: position,
            phase: .began
        )
        entityDragStarted.send(event)
        hapticManager.playDragDropFeedback(.began)
    }
    
    private func startDragOperation(from startPos: SIMD2<Float>, to currentPos: SIMD2<Float>) {
        if let entity = findEntityAt(startPos), selectedEntities.contains(entity) {
            startEntityDrag(entity, at: startPos)
        }
    }
    
    private func updateDragOperation(to position: SIMD2<Float>) {
        guard isDragging, let entity = currentDragTarget else { return }
        
        let event = EntityDragEvent(
            entity: entity,
            startPosition: dragStartPosition ?? position,
            currentPosition: position,
            phase: .moved
        )
        entityDragMoved.send(event)
    }
    
    private func endDragOperation(at position: SIMD2<Float>) {
        guard isDragging, let entity = currentDragTarget else { return }
        
        let event = EntityDragEvent(
            entity: entity,
            startPosition: dragStartPosition ?? position,
            currentPosition: position,
            phase: .ended
        )
        entityDragEnded.send(event)
        hapticManager.playDragDropFeedback(.dropped)
        
        isDragging = false
        currentDragTarget = nil
    }
    
    private func startCameraPan(at position: SIMD2<Float>) {
        let event = CameraControlEvent(
            type: .panBegan,
            targetPosition: position
        )
        cameraControlRequested.send(event)
    }
    
    private func updateCameraPan(_ gestureEvent: GestureEvent) {
        guard let translation = gestureEvent.properties["translation"] as? CGPoint else { return }
        
        let event = CameraControlEvent(
            type: .pan,
            targetPosition: gestureEvent.location,
            translation: SIMD2<Float>(Float(translation.x), Float(translation.y))
        )
        cameraControlRequested.send(event)
    }
    
    private func endCameraPan(_ gestureEvent: GestureEvent) {
        let event = CameraControlEvent(
            type: .panEnded,
            targetPosition: gestureEvent.location
        )
        cameraControlRequested.send(event)
    }
    
    private func handleEntityLongPress(_ entity: Entity, at position: SIMD2<Float>) {
        // Show context menu or special actions
        selectEntity(entity, in: getCurrentWorld(), addToSelection: false)
        hapticManager.playNotificationFeedback(.warning)
    }
    
    private func handleWorldLongPress(at position: SIMD2<Float>) {
        // Show world context menu
        let event = WorldTapEvent(
            worldPosition: position,
            isDoubleTap: false,
            selectedEntities: Array(selectedEntities),
            isLongPress: true
        )
        worldTapped.send(event)
        hapticManager.playNotificationFeedback(.warning)
    }
    
    private func updateHoverDetection(world: World) {
        // Update hover state based on current touch position
        // This would be used for highlighting entities under touch
    }
    
    private func updateDragOperations(world: World) {
        // Update any ongoing drag operations
        guard isDragging, let entity = currentDragTarget else { return }
        
        // Update entity position based on drag
        if var transform = world.getComponent(TransformComponent.self, for: entity) {
            // Apply drag movement (this is a simplified example)
            world.addComponent(transform, to: entity)
        }
    }
    
    private func updateSelectionStates(world: World) {
        // Ensure selection components are in sync
        for entity in selectedEntities {
            if world.getComponent(TouchInputComponent.self, for: entity) == nil {
                addSelectionComponent(to: entity, in: world)
            }
        }
    }
    
    private func findEntityAt(_ worldPosition: SIMD2<Float>) -> Entity? {
        // This would use spatial partitioning or similar to efficiently find entities
        // For now, this is a placeholder implementation
        return getCurrentWorld().getEntitiesWithComponents([.transform]).first { entity in
            guard let transform = getCurrentWorld().getComponent(TransformComponent.self, for: entity) else {
                return false
            }
            
            let entityPos = SIMD2<Float>(transform.position.x, transform.position.z)
            let distance = length(entityPos - worldPosition)
            return distance < 50.0 // 50 unit selection radius
        }
    }
    
    private func addSelectionComponent(to entity: Entity, in world: World) {
        let component = TouchInputComponent(
            isSelected: true,
            isHovered: false,
            isDragTarget: false,
            selectionTime: Date()
        )
        world.addComponent(component, to: entity)
    }
    
    private func removeSelectionComponent(from entity: Entity, in world: World) {
        world.removeComponent(.touchInput, from: entity)
    }
    
    // World reference - should be injected properly in production
    private weak var world: World?
    
    /// Set the world reference for ECS integration
    public func setWorld(_ world: World) {
        self.world = world
    }
    
    private func getCurrentWorld() -> World {
        guard let world = world else {
            // Return a temporary world for demo purposes
            return World()
        }
        return world
    }
}

// MARK: - Supporting Types

public struct EntitySelectionEvent {
    public let entity: Entity
    public let selectionType: SelectionType
    public let worldPosition: SIMD2<Float>
    public let timestamp: Date
    
    public init(entity: Entity, selectionType: SelectionType, worldPosition: SIMD2<Float>) {
        self.entity = entity
        self.selectionType = selectionType
        self.worldPosition = worldPosition
        self.timestamp = Date()
    }
}

public enum SelectionType {
    case exclusive  // Replace current selection
    case additive   // Add to current selection
    case toggle     // Toggle selection state
}

public struct EntityDragEvent {
    public let entity: Entity
    public let startPosition: SIMD2<Float>
    public let currentPosition: SIMD2<Float>
    public let phase: DragPhase
    public let timestamp: Date
    
    public init(entity: Entity, startPosition: SIMD2<Float>, currentPosition: SIMD2<Float>, phase: DragPhase) {
        self.entity = entity
        self.startPosition = startPosition
        self.currentPosition = currentPosition
        self.phase = phase
        self.timestamp = Date()
    }
    
    public var dragDelta: SIMD2<Float> {
        return currentPosition - startPosition
    }
}

public enum DragPhase {
    case began
    case moved
    case ended
    case cancelled
}

public struct WorldTapEvent {
    public let worldPosition: SIMD2<Float>
    public let isDoubleTap: Bool
    public let selectedEntities: [Entity]
    public let isLongPress: Bool
    public let timestamp: Date
    
    public init(worldPosition: SIMD2<Float>, isDoubleTap: Bool, selectedEntities: [Entity], isLongPress: Bool = false) {
        self.worldPosition = worldPosition
        self.isDoubleTap = isDoubleTap
        self.selectedEntities = selectedEntities
        self.isLongPress = isLongPress
        self.timestamp = Date()
    }
}

public struct CameraControlEvent {
    public let type: CameraControlType
    public let targetPosition: SIMD2<Float>
    public let targetEntity: Entity?
    public let scale: Float?
    public let translation: SIMD2<Float>?
    public let timestamp: Date
    
    public init(type: CameraControlType, 
                targetPosition: SIMD2<Float>, 
                targetEntity: Entity? = nil,
                scale: Float? = nil,
                translation: SIMD2<Float>? = nil) {
        self.type = type
        self.targetPosition = targetPosition
        self.targetEntity = targetEntity
        self.scale = scale
        self.translation = translation
        self.timestamp = Date()
    }
}

public enum CameraControlType {
    case pan
    case panBegan
    case panEnded
    case zoom
    case zoomBegan
    case zoomEnded
    case focusOn
    case reset
}

// MARK: - SIMD Extensions

private func length(_ vector: SIMD2<Float>) -> Float {
    return sqrt(vector.x * vector.x + vector.y * vector.y)
}

private extension SIMD3<Float> {
    var xz: SIMD2<Float> {
        return SIMD2<Float>(x, z)
    }
}