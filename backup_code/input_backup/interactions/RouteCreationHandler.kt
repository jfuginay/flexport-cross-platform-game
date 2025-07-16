package com.flexport.input.interactions

import com.flexport.ecs.core.EntityManager
import com.flexport.ecs.components.PositionComponent
import com.flexport.input.TouchInputManager
import com.flexport.input.GestureEvent
import com.flexport.rendering.math.Vector2
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch

/**
 * Handles trade route creation through drag gestures
 */
class RouteCreationHandler(
    private val entityManager: EntityManager,
    private val touchInputManager: TouchInputManager
) {
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())
    
    // Route creation events
    private val _routeEvents = MutableSharedFlow<RouteEvent>(extraBufferCapacity = 16)
    val routeEvents: SharedFlow<RouteEvent> = _routeEvents.asSharedFlow()
    
    // Route creation state
    private var isCreatingRoute = false
    private var routeStartEntity: Int? = null
    private var routeStartPosition = Vector2()
    private var currentRoutePosition = Vector2()
    
    // Route creation settings
    var isRouteCreationEnabled = true
    var minimumDragDistance = 50f // Minimum distance to start route creation
    var snapDistance = 100f // Distance to snap to nearby entities
    var allowSelfRoutes = false // Allow routes from entity to itself
    
    sealed class RouteEvent {
        data class RouteCreationStarted(
            val startEntityId: Int?,
            val startPosition: Vector2
        ) : RouteEvent()
        
        data class RouteCreationUpdated(
            val currentPosition: Vector2,
            val snapTarget: Int? = null,
            val isValidTarget: Boolean = true
        ) : RouteEvent()
        
        data class RouteCreationCompleted(
            val startEntityId: Int?,
            val endEntityId: Int?,
            val startPosition: Vector2,
            val endPosition: Vector2,
            val isValid: Boolean
        ) : RouteEvent()
        
        data class RouteCreationCancelled(
            val startEntityId: Int?,
            val startPosition: Vector2
        ) : RouteEvent()
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
        if (!isRouteCreationEnabled) return
        
        when (event) {
            is GestureEvent.DragStart -> handleDragStart(event)
            is GestureEvent.Drag -> handleDrag(event)
            is GestureEvent.DragEnd -> handleDragEnd(event)
            else -> { /* Other gestures not relevant for route creation */ }
        }
    }
    
    private fun handleDragStart(event: GestureEvent.DragStart) {
        // Find if we're starting from a valid entity (port or ship)
        val startEntity = findRouteableEntityAtPosition(event.worldPosition.x, event.worldPosition.y)
        
        if (startEntity != null) {
            routeStartEntity = startEntity.id
            routeStartPosition.set(event.worldPosition)
            currentRoutePosition.set(event.worldPosition)
            isCreatingRoute = false // Will become true if drag distance exceeds threshold
        }
    }
    
    private fun handleDrag(event: GestureEvent.Drag) {
        val startEntityId = routeStartEntity ?: return
        
        currentRoutePosition.set(event.currentWorldPosition)
        
        // Check if we've dragged far enough to start route creation
        if (!isCreatingRoute && event.totalWorldDelta.len() >= minimumDragDistance) {
            isCreatingRoute = true
            
            _routeEvents.tryEmit(
                RouteEvent.RouteCreationStarted(
                    startEntityId = startEntityId,
                    startPosition = routeStartPosition.cpy()
                )
            )
        }
        
        if (isCreatingRoute) {
            // Check for snap targets
            val snapTarget = findNearestSnapTarget(event.currentWorldPosition)
            val isValidTarget = isValidRouteTarget(startEntityId, snapTarget?.id)
            
            _routeEvents.tryEmit(
                RouteEvent.RouteCreationUpdated(
                    currentPosition = event.currentWorldPosition.cpy(),
                    snapTarget = snapTarget?.id,
                    isValidTarget = isValidTarget
                )
            )
        }
    }
    
    private fun handleDragEnd(event: GestureEvent.DragEnd) {
        val startEntityId = routeStartEntity ?: return
        
        if (isCreatingRoute) {
            // Find end entity
            val endEntity = findRouteableEntityAtPosition(event.endWorldPosition.x, event.endWorldPosition.y)
                ?: findNearestSnapTarget(event.endWorldPosition)
            
            val isValid = isValidRouteTarget(startEntityId, endEntity?.id)
            
            _routeEvents.tryEmit(
                RouteEvent.RouteCreationCompleted(
                    startEntityId = startEntityId,
                    endEntityId = endEntity?.id,
                    startPosition = routeStartPosition.cpy(),
                    endPosition = event.endWorldPosition.cpy(),
                    isValid = isValid
                )
            )
        } else {
            // Drag wasn't long enough - cancel
            _routeEvents.tryEmit(
                RouteEvent.RouteCreationCancelled(
                    startEntityId = startEntityId,
                    startPosition = routeStartPosition.cpy()
                )
            )
        }
        
        // Reset state
        resetRouteCreation()
    }
    
    private fun findRouteableEntityAtPosition(x: Float, y: Float): com.flexport.ecs.core.Entity? {
        // This would be customized based on your game's entity types
        // For now, find any entity with a position component
        val entities = entityManager.getEntitiesWithComponent<PositionComponent>()
        
        for (entity in entities) {
            val position = entity.getComponent<PositionComponent>() ?: continue
            
            // Simple distance check - in a real game you'd use proper bounds
            val distance = Vector2(x, y).dst(position.x, position.y)
            if (distance <= 50f) { // 50 unit radius for selection
                // Check if this entity type can have routes (you'd add your own logic here)
                if (isRouteableEntity(entity)) {
                    return entity
                }
            }
        }
        
        return null
    }
    
    private fun findNearestSnapTarget(position: Vector2): com.flexport.ecs.core.Entity? {
        val entities = entityManager.getEntitiesWithComponent<PositionComponent>()
        var nearestEntity: com.flexport.ecs.core.Entity? = null
        var nearestDistance = Float.MAX_VALUE
        
        for (entity in entities) {
            val entityPosition = entity.getComponent<PositionComponent>() ?: continue
            
            if (!isRouteableEntity(entity)) continue
            
            val distance = position.dst(entityPosition.x, entityPosition.y)
            if (distance <= snapDistance && distance < nearestDistance) {
                nearestDistance = distance
                nearestEntity = entity
            }
        }
        
        return nearestEntity
    }
    
    private fun isRouteableEntity(entity: com.flexport.ecs.core.Entity): Boolean {
        // Add your logic here to determine if an entity can be part of a route
        // For example, check for specific components like PortComponent, ShipComponent, etc.
        
        // For now, just check if it has a position component
        return entity.hasComponent<PositionComponent>()
    }
    
    private fun isValidRouteTarget(startEntityId: Int, endEntityId: Int?): Boolean {
        if (endEntityId == null) return false
        
        // Can't create route to self unless allowed
        if (startEntityId == endEntityId) {
            return allowSelfRoutes
        }
        
        // Add your game-specific route validation logic here
        // For example:
        // - Check if route already exists
        // - Check if entities are compatible (port-to-port, ship-to-port, etc.)
        // - Check distance constraints
        // - Check resource/economic constraints
        
        return true
    }
    
    private fun resetRouteCreation() {
        isCreatingRoute = false
        routeStartEntity = null
        routeStartPosition.set(0f, 0f)
        currentRoutePosition.set(0f, 0f)
    }
    
    /**
     * Check if currently creating a route
     */
    fun isCreatingRoute(): Boolean = isCreatingRoute
    
    /**
     * Get the current route start entity
     */
    fun getRouteStartEntity(): Int? = routeStartEntity
    
    /**
     * Get the current route start position
     */
    fun getRouteStartPosition(): Vector2 = routeStartPosition.cpy()
    
    /**
     * Get the current route end position
     */
    fun getCurrentRoutePosition(): Vector2 = currentRoutePosition.cpy()
    
    /**
     * Cancel current route creation
     */
    fun cancelRouteCreation() {
        if (isCreatingRoute || routeStartEntity != null) {
            _routeEvents.tryEmit(
                RouteEvent.RouteCreationCancelled(
                    startEntityId = routeStartEntity,
                    startPosition = routeStartPosition.cpy()
                )
            )
            
            resetRouteCreation()
        }
    }
    
    /**
     * Enable or disable route creation
     */
    fun setRouteCreationEnabled(enabled: Boolean) {
        isRouteCreationEnabled = enabled
        
        if (!enabled) {
            cancelRouteCreation()
        }
    }
    
    /**
     * Set minimum drag distance to start route creation
     */
    fun setMinimumDragDistance(distance: Float) {
        minimumDragDistance = distance.coerceAtLeast(0f)
    }
    
    /**
     * Set snap distance for automatic targeting
     */
    fun setSnapDistance(distance: Float) {
        snapDistance = distance.coerceAtLeast(0f)
    }
    
    /**
     * Dispose resources
     */
    fun dispose() {
        resetRouteCreation()
    }
}