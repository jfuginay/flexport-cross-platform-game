package com.flexport.input.interactions

import com.flexport.game.ecs.EntityManager
import com.flexport.game.ecs.components.PositionComponent
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
    private var routeStartEntity: String? = null
    private var routeStartPosition = Vector2()
    private var currentRoutePosition = Vector2()
    
    // Route creation settings
    var isRouteCreationEnabled = true
    var minimumDragDistance = 50f // Minimum distance to start route creation
    var snapDistance = 100f // Distance to snap to nearby entities
    var allowSelfRoutes = false // Allow routes from entity to itself
    
    sealed class RouteEvent {
        data class RouteCreationStarted(
            val startEntityId: String?,
            val startPosition: Vector2
        ) : RouteEvent()
        
        data class RouteCreationUpdated(
            val currentPosition: Vector2,
            val snapTarget: String? = null,
            val isValidTarget: Boolean = true
        ) : RouteEvent()
        
        data class RouteCreationCompleted(
            val startEntityId: String?,
            val endEntityId: String?,
            val startPosition: Vector2,
            val endPosition: Vector2,
            val isValid: Boolean
        ) : RouteEvent()
        
        data class RouteCreationCancelled(
            val startEntityId: String?,
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
            
            // TODO: Fix RouteEvent type mismatches 
            // _routeEvents.tryEmit(
            //     RouteEvent.RouteCreationStarted(
            //         startEntityId = startEntityId,
            //         startPosition = routeStartPosition.cpy()
            //     )
            // )
        }
        
        if (isCreatingRoute) {
            // Check for snap targets
            // TODO: Fix type mismatches and re-enable route functionality
            // val snapTarget = findNearestSnapTarget(event.currentWorldPosition)
            // val isValidTarget = isValidRouteTarget(startEntityId, snapTarget?.id)
            
            // TODO: Fix RouteEvent type mismatches
            // _routeEvents.tryEmit(
            //     RouteEvent.RouteCreationUpdated(
            //         currentPosition = event.currentWorldPosition.cpy(),
            //         snapTarget = snapTarget?.id,
            //         isValidTarget = isValidTarget
            //     )
            // )
        }
    }
    
    private fun handleDragEnd(event: GestureEvent.DragEnd) {
        val startEntityId = routeStartEntity ?: return
        
        if (isCreatingRoute) {
            // Find end entity
            val endEntity = findRouteableEntityAtPosition(event.endWorldPosition.x, event.endWorldPosition.y)
                ?: findNearestSnapTarget(event.endWorldPosition)
            
            val isValid = isValidRouteTarget(startEntityId, endEntity?.id?.toString())
            
            // TODO: Re-enable once entity ID system is fully consistent
            // _routeEvents.tryEmit(
            //     RouteEvent.RouteCreationCompleted(
            //         startEntityId = startEntityId,
            //         endEntityId = endEntity?.id?.toString(),
            //         startPosition = routeStartPosition.cpy(),
            //         endPosition = event.endWorldPosition.cpy(),
            //         isValid = isValid
            //     )
            // )
        } else {
            // Drag wasn't long enough - cancel
            // TODO: Re-enable once entity ID system is fully consistent
            // _routeEvents.tryEmit(
            //     RouteEvent.RouteCreationCancelled(
            //         startEntityId = startEntityId,
            //         startPosition = routeStartPosition.cpy()
            //     )
            // )
        }
        
        // Reset state
        resetRouteCreation()
    }
    
    private fun findRouteableEntityAtPosition(x: Float, y: Float): com.flexport.game.ecs.Entity? {
        // This would be customized based on your game's entity types
        // For now, find any entity with a position component
        val entities = entityManager.getEntitiesWithComponent<PositionComponent>()
        
        for (entityId in entities) {
            val entity = entityManager.getEntity(entityId) ?: continue
            val position = entityManager.getComponent(entity, PositionComponent::class) ?: continue
            
            // Simple distance check - in a real game you'd use proper bounds  
            val posVec = Vector2(position.x, position.y)
            val distance = Vector2(x, y).dst(posVec)
            if (distance <= 50f) { // 50 unit radius for selection
                // Check if this entity type can have routes (you'd add your own logic here)
                if (isRouteableEntity(entity)) {
                    return entity
                }
            }
        }
        
        return null
    }
    
    private fun findNearestSnapTarget(position: Vector2): com.flexport.game.ecs.Entity? {
        val entities = entityManager.getEntitiesWithComponent<PositionComponent>()
        var nearestEntity: com.flexport.game.ecs.Entity? = null
        var nearestDistance = Float.MAX_VALUE
        
        for (entityId in entities) {
            val entity = entityManager.getEntity(entityId) ?: continue
            val entityPosition = entityManager.getComponent(entity, PositionComponent::class) ?: continue
            
            if (!isRouteableEntity(entity)) continue
            
            val entityVec = Vector2(entityPosition.x, entityPosition.y)
            val distance = position.dst(entityVec)
            if (distance <= snapDistance && distance < nearestDistance) {
                nearestDistance = distance
                nearestEntity = entity
            }
        }
        
        return nearestEntity
    }
    
    private fun isRouteableEntity(entity: com.flexport.game.ecs.Entity): Boolean {
        // Add your logic here to determine if an entity can be part of a route
        // For example, check for specific components like PortComponent, ShipComponent, etc.
        
        // For now, just check if it has a position component
        return entityManager.hasComponent(entity, PositionComponent::class)
    }
    
    private fun isValidRouteTarget(startEntityId: String?, endEntityId: String?): Boolean {
        if (endEntityId == null || startEntityId == null) return false
        
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
    fun getRouteStartEntity(): String? = routeStartEntity
    
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
            // TODO: Re-enable once entity ID system is fully consistent
            // _routeEvents.tryEmit(
            //     RouteEvent.RouteCreationCancelled(
            //         startEntityId = routeStartEntity,
            //         startPosition = routeStartPosition.cpy()
            //     )
            // )
            
            resetRouteCreation()
        }
    }
    
    // Note: setRouteCreationEnabled, setMinimumDragDistance, and setSnapDistance
    // are auto-generated by Kotlin for var properties
    
    /**
     * Dispose resources
     */
    fun dispose() {
        resetRouteCreation()
    }
}