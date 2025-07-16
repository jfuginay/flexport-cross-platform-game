package com.flexport.game.ecs

import kotlin.system.measureTimeMillis

/**
 * Base interface for all systems in the ECS architecture.
 * Systems contain logic and operate on entities with specific components.
 */
interface System {
    /**
     * Update the system with the given delta time
     */
    fun update(deltaTime: Float)
    
    /**
     * Initialize the system
     */
    fun initialize() {}
    
    /**
     * Clean up the system
     */
    fun dispose() {}
    
    /**
     * Get the priority of this system (lower numbers = higher priority)
     */
    fun getPriority(): Int = 0
}

/**
 * Base class for systems that operate on entities with specific components
 */
abstract class EntitySystem(
    protected val componentManager: ComponentManager
) : System {
    
    /**
     * Process a specific entity
     */
    abstract fun processEntity(entityId: String, deltaTime: Float)
    
    /**
     * Get the entities this system should process
     */
    abstract fun getRelevantEntities(): Set<String>
    
    override fun update(deltaTime: Float) {
        val entities = getRelevantEntities()
        for (entityId in entities) {
            processEntity(entityId, deltaTime)
        }
    }
}

/**
 * System for updating ship movement
 */
class MovementSystem(componentManager: ComponentManager) : EntitySystem(componentManager) {
    
    override fun processEntity(entityId: String, deltaTime: Float) {
        val positionComp = componentManager.getComponent<PositionComponent>(Entity(entityId))
        val movementComp = componentManager.getComponent<MovementComponent>(Entity(entityId))
        
        if (positionComp != null && movementComp != null && movementComp.isMoving) {
            val destination = movementComp.destination
            if (destination != null) {
                val distance = positionComp.position.distanceTo(destination)
                val maxDistanceThisFrame = movementComp.speed * (deltaTime.toDouble() / 3600.0) // Convert speed to distance per frame
                
                if (distance <= maxDistanceThisFrame) {
                    // Reached destination
                    val newPosition = PositionComponent(destination, positionComp.heading)
                    val newMovement = movementComp.copy(isMoving = false, destination = null)
                    
                    componentManager.addComponent(Entity(entityId), newPosition)
                    componentManager.addComponent(Entity(entityId), newMovement)
                } else {
                    // Move towards destination
                    val bearing = positionComp.position.bearingTo(destination)
                    val ratio = maxDistanceThisFrame / distance
                    
                    val newLat = positionComp.position.latitude + (destination.latitude - positionComp.position.latitude) * ratio
                    val newLon = positionComp.position.longitude + (destination.longitude - positionComp.position.longitude) * ratio
                    
                    val newPosition = PositionComponent(
                        com.flexport.game.models.GeographicalPosition(newLat, newLon),
                        bearing
                    )
                    
                    componentManager.addComponent(Entity(entityId), newPosition)
                }
            }
        }
    }
    
    override fun getRelevantEntities(): Set<String> {
        return componentManager.getEntitiesWithComponents(
            PositionComponent::class,
            MovementComponent::class
        )
    }
    
    override fun getPriority(): Int = 1
}

/**
 * System for updating economic aspects (costs, revenues, etc.)
 */
class EconomicSystem(componentManager: ComponentManager) : EntitySystem(componentManager) {
    
    private var lastUpdateTime = java.lang.System.currentTimeMillis()
    
    override fun processEntity(entityId: String, deltaTime: Float) {
        val economicComp = componentManager.getComponent<EconomicComponent>(Entity(entityId))
        val shipComp = componentManager.getComponent<ShipComponent>(Entity(entityId))
        
        if (economicComp != null) {
            // Calculate daily costs - this is simplified to run every update
            val currentTime = java.lang.System.currentTimeMillis()
            val timeDelta = (currentTime - lastUpdateTime) / (1000.0 * 60.0 * 60.0 * 24.0) // Days
            
            if (timeDelta > 0.001) { // Only update if significant time has passed
                val totalDailyCost = economicComp.dailyOperatingCost + 
                                   economicComp.maintenanceCost + 
                                   economicComp.insuranceCost
                
                val costThisUpdate = totalDailyCost * timeDelta.toDouble()
                val newValue = economicComp.currentValue - costThisUpdate
                
                // Update economic component
                val updatedEconomic = economicComp.copy(currentValue = newValue)
                componentManager.addComponent(Entity(entityId), updatedEconomic)
            }
        }
    }
    
    override fun update(deltaTime: Float) {
        super.update(deltaTime)
        lastUpdateTime = java.lang.System.currentTimeMillis()
    }
    
    override fun getRelevantEntities(): Set<String> {
        return componentManager.getEntitiesWithComponent<EconomicComponent>()
    }
    
    override fun getPriority(): Int = 2
}

/**
 * System for managing docking operations
 */
class DockingSystem(componentManager: ComponentManager) : EntitySystem(componentManager) {
    
    override fun processEntity(entityId: String, deltaTime: Float) {
        val positionComp = componentManager.getComponent<PositionComponent>(Entity(entityId))
        val dockingComp = componentManager.getComponent<DockingComponent>(Entity(entityId))
        val shipComp = componentManager.getComponent<ShipComponent>(Entity(entityId))
        
        if (positionComp != null && dockingComp != null && shipComp != null) {
            // Check if ship is near any ports
            val nearbyPorts = findNearbyPorts(positionComp.position)
            
            for (portId in nearbyPorts) {
                val portEntity = Entity(portId)
                val portPosition = componentManager.getComponent<PositionComponent>(portEntity)
                val portComp = componentManager.getComponent<PortComponent>(portEntity)
                
                if (portPosition != null && portComp != null) {
                    val distance = positionComp.position.distanceTo(portPosition.position)
                    
                    // Auto-dock if within docking range (0.1 nautical miles)
                    if (distance <= 0.1 && dockingComp.currentPortId == null && portComp.isOperational) {
                        val updatedDocking = dockingComp.copy(
                            currentPortId = portId,
                            dockingTime = java.lang.System.currentTimeMillis()
                        )
                        
                        componentManager.addComponent(Entity(entityId), updatedDocking)
                        
                        // Update port to include this ship
                        val updatedPort = portComp.copy(
                            dockedShips = portComp.dockedShips + entityId
                        )
                        componentManager.addComponent(portEntity, updatedPort)
                    }
                }
            }
        }
    }
    
    private fun findNearbyPorts(position: com.flexport.game.models.GeographicalPosition): List<String> {
        // Find all port entities within reasonable distance
        val portEntities = componentManager.getEntitiesWithComponents(
            PositionComponent::class,
            PortComponent::class
        )
        
        return portEntities.filter { portId ->
            val portPosition = componentManager.getComponent<PositionComponent>(Entity(portId))
            portPosition?.let { 
                position.distanceTo(it.position) <= 1.0 // Within 1 nautical mile
            } ?: false
        }
    }
    
    override fun getRelevantEntities(): Set<String> {
        return componentManager.getEntitiesWithComponents(
            PositionComponent::class,
            DockingComponent::class,
            ShipComponent::class
        )
    }
    
    override fun getPriority(): Int = 3
}