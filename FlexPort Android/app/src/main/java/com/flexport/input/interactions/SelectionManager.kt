package com.flexport.input.interactions

import com.flexport.game.ecs.EntityManager
import com.flexport.game.ecs.components.SelectableComponent
import com.flexport.game.ecs.components.TouchableComponent
import com.flexport.input.TouchInputManager
import com.flexport.input.GestureEvent
import com.flexport.rendering.math.Vector2
import com.flexport.rendering.math.Rectangle
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch

/**
 * Manages entity selection through various input methods
 */
class SelectionManager(
    private val entityManager: EntityManager,
    private val touchInputManager: TouchInputManager
) {
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())
    
    // Selection events
    private val _selectionEvents = MutableSharedFlow<SelectionEvent>(extraBufferCapacity = 16)
    val selectionEvents: SharedFlow<SelectionEvent> = _selectionEvents.asSharedFlow()
    
    // Selection state
    private val selectedEntities = mutableSetOf<String>()
    private var selectionMode = SelectionMode.SINGLE
    
    // Box selection state
    private var isBoxSelecting = false
    private var boxSelectionStart = Vector2()
    private var boxSelectionEnd = Vector2()
    private var boxSelectionBounds = Rectangle()
    
    // Selection settings
    var allowBoxSelection = true
    var boxSelectionMinDistance = 20f // Minimum drag distance to start box selection
    
    enum class SelectionMode {
        SINGLE,    // Only one entity can be selected at a time
        MULTIPLE,  // Multiple entities can be selected
        ADDITIVE   // Ctrl/Shift-click to add to selection
    }
    
    sealed class SelectionEvent {
        data class EntitySelected(val entityId: String) : SelectionEvent()
        data class EntityDeselected(val entityId: String) : SelectionEvent()
        data class SelectionCleared(val previousSelection: Set<String>) : SelectionEvent()
        data class BoxSelectionStarted(val startPosition: Vector2) : SelectionEvent()
        data class BoxSelectionUpdated(val bounds: Rectangle) : SelectionEvent()
        data class BoxSelectionCompleted(val selectedEntities: Set<String>, val bounds: Rectangle) : SelectionEvent()
    }
    
    init {
        setupGestureHandling()
    }
    
    private fun setupGestureHandling() {
        scope.launch {
            touchInputManager.gestureEvents.collect { gestureEvent ->
                handleGestureEvent(gestureEvent)
            }
        }
    }
    
    private fun handleGestureEvent(event: GestureEvent) {
        when (event) {
            is GestureEvent.Tap -> handleTap(event)
            is GestureEvent.DragStart -> handleDragStart(event)
            is GestureEvent.Drag -> handleDrag(event)
            is GestureEvent.DragEnd -> handleDragEnd(event)
            else -> { /* Other gestures not relevant for selection */ }
        }
    }
    
    private fun handleTap(event: GestureEvent.Tap) {
        val entity = findSelectableEntityAtPosition(event.worldPosition.x, event.worldPosition.y)
        
        if (entity != null) {
            when (selectionMode) {
                SelectionMode.SINGLE -> {
                    selectSingleEntity(entity.id)
                }
                SelectionMode.MULTIPLE -> {
                    toggleEntitySelection(entity.id)
                }
                SelectionMode.ADDITIVE -> {
                    if (isAdditiveModeActive()) {
                        toggleEntitySelection(entity.id)
                    } else {
                        selectSingleEntity(entity.id)
                    }
                }
            }
        } else {
            // Tap on empty space - clear selection unless in additive mode
            if (!isAdditiveModeActive()) {
                clearSelection()
            }
        }
    }
    
    private fun handleDragStart(event: GestureEvent.DragStart) {
        if (!allowBoxSelection) return
        
        val entity = findSelectableEntityAtPosition(event.worldPosition.x, event.worldPosition.y)
        
        // Only start box selection if not starting on an entity
        if (entity == null) {
            isBoxSelecting = true
            boxSelectionStart.set(event.worldPosition)
            boxSelectionEnd.set(event.worldPosition)
            updateBoxSelectionBounds()
            
            _selectionEvents.tryEmit(SelectionEvent.BoxSelectionStarted(event.worldPosition.cpy()))
        }
    }
    
    private fun handleDrag(event: GestureEvent.Drag) {
        if (!isBoxSelecting) return
        
        boxSelectionEnd.set(event.currentWorldPosition)
        updateBoxSelectionBounds()
        
        // Check if we've dragged far enough to actually be box selecting
        val dragDistance = event.totalWorldDelta.len()
        if (dragDistance >= boxSelectionMinDistance) {
            _selectionEvents.tryEmit(SelectionEvent.BoxSelectionUpdated(boxSelectionBounds))
        }
    }
    
    private fun handleDragEnd(event: GestureEvent.DragEnd) {
        if (!isBoxSelecting) return
        
        val dragDistance = event.totalWorldDelta.len()
        
        if (dragDistance >= boxSelectionMinDistance) {
            // Complete box selection
            val entitiesInBox = findSelectableEntitiesInBounds(boxSelectionBounds)
            
            when (selectionMode) {
                SelectionMode.SINGLE -> {
                    if (entitiesInBox.isNotEmpty()) {
                        selectSingleEntity(entitiesInBox.first().id)
                    }
                }
                SelectionMode.MULTIPLE, SelectionMode.ADDITIVE -> {
                    if (!isAdditiveModeActive()) {
                        clearSelection()
                    }
                    
                    entitiesInBox.forEach { entity ->
                        selectEntity(entity.id, emitEvent = false)
                    }
                }
            }
            
            _selectionEvents.tryEmit(
                SelectionEvent.BoxSelectionCompleted(
                    selectedEntities.toSet(),
                    boxSelectionBounds
                )
            )
        }
        
        isBoxSelecting = false
    }
    
    private fun updateBoxSelectionBounds() {
        val minX = minOf(boxSelectionStart.x, boxSelectionEnd.x)
        val minY = minOf(boxSelectionStart.y, boxSelectionEnd.y)
        val maxX = maxOf(boxSelectionStart.x, boxSelectionEnd.x)
        val maxY = maxOf(boxSelectionStart.y, boxSelectionEnd.y)
        
        boxSelectionBounds.set(minX, minY, maxX - minX, maxY - minY)
    }
    
    private fun findSelectableEntityAtPosition(x: Float, y: Float): com.flexport.game.ecs.Entity? {
        val entityIds = entityManager.getEntitiesWithComponent<SelectableComponent>()
        
        for (entityId in entityIds) {
            val entity = entityManager.getEntity(entityId) ?: continue
            val touchable = entityManager.getComponent(entity, TouchableComponent::class)
            if (touchable != null && touchable.contains(x, y)) {
                return entity
            }
        }
        
        return null
    }
    
    private fun findSelectableEntitiesInBounds(bounds: Rectangle): List<com.flexport.game.ecs.Entity> {
        val entityIds = entityManager.getEntitiesWithComponent<SelectableComponent>()
        val entitiesInBounds = mutableListOf<com.flexport.game.ecs.Entity>()
        
        for (entityId in entityIds) {
            val entity = entityManager.getEntity(entityId) ?: continue
            val touchable = entityManager.getComponent(entity, TouchableComponent::class)
            if (touchable != null && bounds.overlaps(touchable.bounds)) {
                entitiesInBounds.add(entity)
            }
        }
        
        return entitiesInBounds
    }
    
    private fun selectSingleEntity(entityId: String) {
        val previousSelection = selectedEntities.toSet()
        clearSelection(emitEvent = false)
        selectEntity(entityId)
        
        // Emit clear event if there was a previous selection
        if (previousSelection.isNotEmpty()) {
            _selectionEvents.tryEmit(SelectionEvent.SelectionCleared(previousSelection))
        }
    }
    
    private fun toggleEntitySelection(entityId: String) {
        if (entityId in selectedEntities) {
            deselectEntity(entityId)
        } else {
            selectEntity(entityId)
        }
    }
    
    private fun selectEntity(entityId: String, emitEvent: Boolean = true) {
        if (entityId in selectedEntities) return
        
        val entity = entityManager.getEntity(entityId)
        if (entity != null) {
            val selectable = entityManager.getComponent(entity, SelectableComponent::class)
            selectable?.setSelected(true)
            selectedEntities.add(entityId)
            
            if (emitEvent) {
                _selectionEvents.tryEmit(SelectionEvent.EntitySelected(entityId))
            }
        }
    }
    
    private fun deselectEntity(entityId: String, emitEvent: Boolean = true) {
        if (entityId !in selectedEntities) return
        
        val entity = entityManager.getEntity(entityId)
        if (entity != null) {
            val selectable = entityManager.getComponent(entity, SelectableComponent::class)
            selectable?.setSelected(false)
            selectedEntities.remove(entityId)
            
            if (emitEvent) {
                _selectionEvents.tryEmit(SelectionEvent.EntityDeselected(entityId))
            }
        }
    }
    
    private fun clearSelection(emitEvent: Boolean = true) {
        if (selectedEntities.isEmpty()) return
        
        val previousSelection = selectedEntities.toSet()
        
        selectedEntities.forEach { entityId ->
            val entity = entityManager.getEntity(entityId)
            if (entity != null) {
                val selectable = entityManager.getComponent(entity, SelectableComponent::class)
                selectable?.setSelected(false)
            }
        }
        selectedEntities.clear()
        
        if (emitEvent) {
            _selectionEvents.tryEmit(SelectionEvent.SelectionCleared(previousSelection))
        }
    }
    
    private fun isAdditiveModeActive(): Boolean {
        // This would check for modifier keys (Ctrl/Shift) in a real implementation
        // For now, just return false
        return false
    }
    
    /**
     * Get currently selected entities
     */
    fun getSelectedEntities(): Set<String> = selectedEntities.toSet()
    
    /**
     * Check if an entity is selected
     */
    fun isEntitySelected(entityId: String): Boolean = entityId in selectedEntities
    
    /**
     * Get the number of selected entities
     */
    fun getSelectionCount(): Int = selectedEntities.size
    
    /**
     * Set selection mode
     */
    fun setSelectionMode(mode: SelectionMode) {
        selectionMode = mode
    }
    
    /**
     * Get current selection mode
     */
    fun getSelectionMode(): SelectionMode = selectionMode
    
    /**
     * Check if box selection is currently active
     */
    fun isBoxSelectionActive(): Boolean = isBoxSelecting
    
    /**
     * Get current box selection bounds
     */
    fun getBoxSelectionBounds(): Rectangle = boxSelectionBounds
    
    /**
     * Programmatically select entities
     */
    fun selectEntities(entityIds: Collection<String>, clearPrevious: Boolean = true) {
        if (clearPrevious) {
            clearSelection(emitEvent = false)
        }
        
        entityIds.forEach { entityId ->
            selectEntity(entityId, emitEvent = false)
        }
        
        // Emit a single selection event for all entities
        entityIds.forEach { entityId ->
            _selectionEvents.tryEmit(SelectionEvent.EntitySelected(entityId))
        }
    }
    
    /**
     * Programmatically clear selection
     */
    fun clearSelectionProgrammatically() {
        clearSelection()
    }
    
    /**
     * Dispose resources
     */
    fun dispose() {
        selectedEntities.clear()
    }
}