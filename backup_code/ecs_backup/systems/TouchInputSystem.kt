package com.flexport.ecs.systems

import com.flexport.ecs.core.System
import com.flexport.ecs.core.EntityManager
import com.flexport.ecs.core.ComponentType
import com.flexport.ecs.components.TouchableComponent
import com.flexport.ecs.components.SelectableComponent
import com.flexport.ecs.components.InteractableComponent
import com.flexport.ecs.components.TransformComponent
import com.flexport.ecs.components.PositionComponent
import com.flexport.input.TouchInputManager
import com.flexport.input.TouchEvent
import com.flexport.input.GestureEvent
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch

/**
 * System that handles touch input and interactions with ECS entities
 */
class TouchInputSystem(
    entityManager: EntityManager,
    private val touchInputManager: TouchInputManager
) : System(entityManager) {
    
    // Touch interaction state
    private val touchedEntities = mutableSetOf<Int>() // Entity IDs currently being touched
    private val selectedEntities = mutableSetOf<Int>() // Entity IDs currently selected
    private var draggedEntity: Int? = null
    
    override suspend fun initialize() {
        // Subscribe to touch events
        scope.launch {
            touchInputManager.touchEvents.collect { touchEvent ->
                handleTouchEvent(touchEvent)
            }
        }
        
        // Subscribe to gesture events
        scope.launch {
            touchInputManager.gestureEvents.collect { gestureEvent ->
                handleGestureEvent(gestureEvent)
            }
        }
    }
    
    override suspend fun update(deltaTime: Float) {
        // Update entity bounds based on current transforms
        updateTouchableBounds()
        
        // Update interaction states
        updateInteractionStates(deltaTime)
    }
    
    override fun getRequiredComponents(): Array<ComponentType> = arrayOf()
    
    private suspend fun handleTouchEvent(event: TouchEvent) {
        when (event.action) {
            TouchEvent.TouchAction.DOWN -> handleTouchDown(event)
            TouchEvent.TouchAction.MOVE -> handleTouchMove(event)
            TouchEvent.TouchAction.UP -> handleTouchUp(event)
            TouchEvent.TouchAction.CANCEL -> handleTouchCancel(event)
        }
    }
    
    private suspend fun handleGestureEvent(event: GestureEvent) {
        when (event) {
            is GestureEvent.Tap -> handleTap(event)
            is GestureEvent.LongPress -> handleLongPress(event)
            is GestureEvent.DragStart -> handleDragStart(event)
            is GestureEvent.Drag -> handleDrag(event)
            is GestureEvent.DragEnd -> handleDragEnd(event)
            is GestureEvent.Pan -> handlePan(event)
            is GestureEvent.Pinch -> handlePinch(event)
        }
    }
    
    private fun handleTouchDown(event: TouchEvent) {
        val entity = findEntityAtPosition(event.worldPosition.x, event.worldPosition.y)
        if (entity != null) {
            touchedEntities.add(entity.id)
            
            // Update interactable component
            entity.getComponent<InteractableComponent>()?.let { interactable ->
                interactable.lastTouchTime = event.timestamp
            }
        }
    }
    
    private fun handleTouchMove(event: TouchEvent) {
        // Update any dragged entities
        draggedEntity?.let { entityId ->
            entityManager.getEntity(entityId)?.let { entity ->
                val interactable = entity.getComponent<InteractableComponent>()
                if (interactable != null && interactable.isDragging) {
                    val deltaX = event.worldPosition.x - interactable.dragStartX
                    val deltaY = event.worldPosition.y - interactable.dragStartY
                    
                    interactable.totalDragX = deltaX
                    interactable.totalDragY = deltaY
                    
                    // Update entity position if it has a transform or position component
                    entity.getComponent<TransformComponent>()?.translate(
                        event.worldPosition.x - interactable.dragStartX,
                        event.worldPosition.y - interactable.dragStartY
                    )
                    
                    entity.getComponent<PositionComponent>()?.set(
                        event.worldPosition.x,
                        event.worldPosition.y
                    )
                    
                    // Invoke drag callback
                    val currentDeltaX = event.worldPosition.x - interactable.dragStartX - interactable.totalDragX
                    val currentDeltaY = event.worldPosition.y - interactable.dragStartY - interactable.totalDragY
                    interactable.onDragCallback?.invoke(currentDeltaX, currentDeltaY, deltaX, deltaY)
                }
            }
        }
    }
    
    private fun handleTouchUp(event: TouchEvent) {
        val entity = findEntityAtPosition(event.worldPosition.x, event.worldPosition.y)
        entity?.let { touchedEntities.remove(it.id) }
    }
    
    private fun handleTouchCancel(event: TouchEvent) {
        touchedEntities.clear()
        draggedEntity?.let { entityId ->
            entityManager.getEntity(entityId)?.getComponent<InteractableComponent>()?.resetDragState()
        }
        draggedEntity = null
    }
    
    private fun handleTap(event: GestureEvent.Tap) {
        val entity = findEntityAtPosition(event.worldPosition.x, event.worldPosition.y)
        if (entity != null) {
            // Handle selection
            entity.getComponent<SelectableComponent>()?.let { selectable ->
                if (selectable.isMultiSelectEnabled) {
                    selectable.toggleSelection()
                } else {
                    // Clear other selections unless multi-select is enabled
                    clearAllSelections()
                    selectable.setSelected(true)
                }
                
                if (selectable.isSelected) {
                    selectedEntities.add(entity.id)
                } else {
                    selectedEntities.remove(entity.id)
                }
            }
            
            // Handle tap interaction
            entity.getComponent<InteractableComponent>()?.let { interactable ->
                if (interactable.isEnabled && interactable.supportsTap) {
                    interactable.onTapCallback?.invoke()
                }
            }
        } else {
            // Tap on empty space - clear selections
            clearAllSelections()
        }
    }
    
    private fun handleLongPress(event: GestureEvent.LongPress) {
        val entity = findEntityAtPosition(event.worldPosition.x, event.worldPosition.y)
        if (entity != null) {
            entity.getComponent<InteractableComponent>()?.let { interactable ->
                if (interactable.isEnabled && interactable.supportsLongPress) {
                    interactable.onLongPressCallback?.invoke()
                }
                
                if (interactable.supportsContextMenu) {
                    interactable.onContextMenuCallback?.invoke()
                }
            }
        }
    }
    
    private fun handleDragStart(event: GestureEvent.DragStart) {
        val entity = findEntityAtPosition(event.worldPosition.x, event.worldPosition.y)
        if (entity != null) {
            entity.getComponent<InteractableComponent>()?.let { interactable ->
                if (interactable.isEnabled && interactable.supportsDrag) {
                    interactable.isDragging = true
                    interactable.dragStartX = event.worldPosition.x
                    interactable.dragStartY = event.worldPosition.y
                    interactable.totalDragX = 0f
                    interactable.totalDragY = 0f
                    
                    draggedEntity = entity.id
                    interactable.onDragStartCallback?.invoke(event.worldPosition.x, event.worldPosition.y)
                }
            }
        }
    }
    
    private fun handleDrag(event: GestureEvent.Drag) {
        draggedEntity?.let { entityId ->
            entityManager.getEntity(entityId)?.getComponent<InteractableComponent>()?.let { interactable ->
                val deltaX = event.deltaWorldPosition.x
                val deltaY = event.deltaWorldPosition.y
                val totalX = event.totalWorldDelta.x
                val totalY = event.totalWorldDelta.y
                
                interactable.onDragCallback?.invoke(deltaX, deltaY, totalX, totalY)
            }
        }
    }
    
    private fun handleDragEnd(event: GestureEvent.DragEnd) {
        draggedEntity?.let { entityId ->
            entityManager.getEntity(entityId)?.getComponent<InteractableComponent>()?.let { interactable ->
                interactable.onDragEndCallback?.invoke(event.endWorldPosition.x, event.endWorldPosition.y)
                interactable.resetDragState()
            }
        }
        draggedEntity = null
    }
    
    private fun handlePan(event: GestureEvent.Pan) {
        // Pan events are typically handled by camera controller
        // This could be forwarded to a camera system or handled directly
    }
    
    private fun handlePinch(event: GestureEvent.Pinch) {
        // Pinch events are typically handled by camera controller for zoom
        // This could be forwarded to a camera system or handled directly
    }
    
    private fun findEntityAtPosition(worldX: Float, worldY: Float): com.flexport.ecs.core.Entity? {
        // Get all entities with touchable components
        val touchableEntities = entityManager.getEntitiesWithComponent<TouchableComponent>()
        
        // Sort by priority (higher priority first)
        val sortedEntities = touchableEntities.sortedByDescending { entity ->
            entity.getComponent<TouchableComponent>()?.priority ?: 0
        }
        
        // Find the first entity that contains the touch point
        for (entity in sortedEntities) {
            val touchable = entity.getComponent<TouchableComponent>()
            if (touchable != null && touchable.contains(worldX, worldY)) {
                return entity
            }
        }
        
        return null
    }
    
    private fun updateTouchableBounds() {
        // Update touchable bounds based on current entity transforms
        val entities = entityManager.getEntitiesWithComponent<TouchableComponent>()
        
        for (entity in entities) {
            val touchable = entity.getComponent<TouchableComponent>() ?: continue
            
            // Update bounds from transform component if available
            entity.getComponent<TransformComponent>()?.let { transform ->
                // Assuming some default size - this could be improved with a BoundsComponent
                val size = 64f // Default size
                touchable.setBoundsFromCenter(transform.x, transform.y, size, size)
            }
            
            // Or update from position component
            entity.getComponent<PositionComponent>()?.let { position ->
                val size = 64f // Default size
                touchable.setBoundsFromCenter(position.x, position.y, size, size)
            }
        }
    }
    
    private fun updateInteractionStates(deltaTime: Float) {
        val entities = entityManager.getEntitiesWithComponent<InteractableComponent>()
        val currentTime = System.currentTimeMillis()
        
        for (entity in entities) {
            val interactable = entity.getComponent<InteractableComponent>() ?: continue
            
            // Check for long press if entity is being touched
            if (entity.id in touchedEntities && 
                !interactable.isDragging && 
                interactable.supportsLongPress &&
                currentTime - interactable.lastTouchTime >= interactable.longPressThreshold) {
                
                // Trigger long press
                interactable.onLongPressCallback?.invoke()
            }
        }
    }
    
    private fun clearAllSelections() {
        selectedEntities.forEach { entityId ->
            entityManager.getEntity(entityId)?.getComponent<SelectableComponent>()?.setSelected(false)
        }
        selectedEntities.clear()
    }
    
    /**
     * Get currently selected entities
     */
    fun getSelectedEntities(): Set<Int> = selectedEntities.toSet()
    
    /**
     * Get currently touched entities
     */
    fun getTouchedEntities(): Set<Int> = touchedEntities.toSet()
    
    /**
     * Get the currently dragged entity
     */
    fun getDraggedEntity(): Int? = draggedEntity
    
    /**
     * Programmatically select an entity
     */
    fun selectEntity(entityId: Int, clearOthers: Boolean = true) {
        if (clearOthers) {
            clearAllSelections()
        }
        
        entityManager.getEntity(entityId)?.getComponent<SelectableComponent>()?.let { selectable ->
            selectable.setSelected(true)
            selectedEntities.add(entityId)
        }
    }
    
    /**
     * Programmatically deselect an entity
     */
    fun deselectEntity(entityId: Int) {
        entityManager.getEntity(entityId)?.getComponent<SelectableComponent>()?.setSelected(false)
        selectedEntities.remove(entityId)
    }
}