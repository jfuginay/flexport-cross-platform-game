package com.flexport.ecs.systems

import com.flexport.game.ecs.EntityManager
import com.flexport.game.ecs.Entity
import com.flexport.game.ecs.components.TouchableComponent
import com.flexport.game.ecs.System
import com.flexport.input.TouchInputManager
import com.flexport.input.GestureEvent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch

/**
 * ECS System that processes touch input and updates touchable entities
 */
class TouchInputSystem(
    private val entityManager: EntityManager,
    private val touchInputManager: TouchInputManager
) : System {
    
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())
    
    override fun getPriority(): Int = 100 // High priority for input processing
    
    override fun initialize() {
        // Set up gesture event handling
        scope.launch {
            touchInputManager.gestureEvents.collect { gestureEvent ->
                handleGestureEvent(gestureEvent)
            }
        }
    }
    
    override fun update(deltaTime: Float) {
        // Touch input is handled via events, so update is not needed
        // This could be used for continuous touch state updates if needed
    }
    
    private fun handleGestureEvent(event: GestureEvent) {
        when (event) {
            is GestureEvent.Tap -> handleTap(event)
            is GestureEvent.LongPress -> handleLongPress(event)
            is GestureEvent.Pan -> handlePan(event)
            is GestureEvent.DragStart -> handleDragStart(event)
            is GestureEvent.Drag -> handleDrag(event)
            is GestureEvent.DragEnd -> handleDragEnd(event)
            is GestureEvent.Pinch -> handlePinch(event)
            is GestureEvent.Pinch -> handlePinch(event) // Pinch end is also handled in Pinch event
        }
    }
    
    private fun handleTap(event: GestureEvent.Tap) {
        // Find touchable entities at tap position
        val touchedEntities = findTouchableEntitiesAt(event.worldPosition.x, event.worldPosition.y)
        
        // Process in priority order
        for (entity in touchedEntities) {
            val touchable = entityManager.getComponent(entity, TouchableComponent::class)
            if (touchable != null && touchable.enabled) {
                // Entity was touched - could emit an event or trigger a callback
                // For now, just mark that it was touched
                println("Entity ${entity.id} was tapped at ${event.worldPosition}")
                break // Only process the highest priority entity
            }
        }
    }
    
    private fun handleDoubleTap(event: GestureEvent.Tap) {
        // Similar to tap but for double tap gestures
        val touchedEntities = findTouchableEntitiesAt(event.worldPosition.x, event.worldPosition.y)
        
        for (entity in touchedEntities) {
            val touchable = entityManager.getComponent(entity, TouchableComponent::class)
            if (touchable != null && touchable.enabled) {
                println("Entity ${entity.id} was double-tapped at ${event.worldPosition}")
                break
            }
        }
    }
    
    private fun handleLongPress(event: GestureEvent.LongPress) {
        val touchedEntities = findTouchableEntitiesAt(event.worldPosition.x, event.worldPosition.y)
        
        for (entity in touchedEntities) {
            val touchable = entityManager.getComponent(entity, TouchableComponent::class)
            if (touchable != null && touchable.enabled) {
                println("Entity ${entity.id} was long-pressed at ${event.worldPosition}")
                break
            }
        }
    }
    
    private fun handleDragStart(event: GestureEvent.DragStart) {
        // Handle drag start on touchable entities
        val touchedEntities = findTouchableEntitiesAt(event.worldPosition.x, event.worldPosition.y)
        
        for (entity in touchedEntities) {
            val touchable = entityManager.getComponent(entity, TouchableComponent::class)
            if (touchable != null && touchable.enabled) {
                println("Started dragging entity ${entity.id} from ${event.worldPosition}")
                break
            }
        }
    }
    
    private fun handleDrag(event: GestureEvent.Drag) {
        // Handle ongoing drag
        // This could update entity positions or show drag feedback
    }
    
    private fun handleDragEnd(event: GestureEvent.DragEnd) {
        // Handle drag end
        println("Drag ended at ${event.endWorldPosition}")
    }
    
    private fun handlePan(event: GestureEvent.Pan) {
        // Handle pan gestures (usually for camera movement)
        // This is typically handled by camera controller
        println("Pan gesture at ${event.currentWorldPosition}")
    }
    
    private fun handlePinch(event: GestureEvent.Pinch) {
        // Handle pinch gestures (usually for camera zoom)
        // This is typically handled by camera controller
    }
    
    
    /**
     * Find all touchable entities at the given world position
     * Returns entities sorted by priority (highest first)
     */
    private fun findTouchableEntitiesAt(x: Float, y: Float): List<Entity> {
        val touchableEntityIds = entityManager.getEntitiesWithComponent<TouchableComponent>()
        
        return touchableEntityIds
            .mapNotNull { entityId -> entityManager.getEntity(entityId) }
            .filter { entity ->
                val touchable = entityManager.getComponent(entity, TouchableComponent::class)
                touchable != null && touchable.contains(x, y)
            }
            .sortedByDescending { entity ->
                entityManager.getComponent(entity, TouchableComponent::class)?.priority ?: 0
            }
    }
    
    override fun dispose() {
        // Clean up coroutine scope
        scope.launch { /* Cancel scope */ }
    }
}