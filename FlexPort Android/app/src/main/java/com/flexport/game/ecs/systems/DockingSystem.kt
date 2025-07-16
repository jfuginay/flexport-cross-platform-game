package com.flexport.game.ecs.systems

import com.flexport.game.ecs.System
import com.flexport.game.ecs.ComponentManager
import com.flexport.game.ecs.Entity
import com.flexport.game.ecs.*

/**
 * System responsible for handling ship docking at ports
 */
class DockingSystem(private val componentManager: ComponentManager) : System {
    
    private val dockingRange = 0.5 // degrees, roughly 50km
    
    override fun getPriority(): Int = 15
    
    override fun update(deltaTime: Float) {
        // Get all ships (entities with docking components)
        val ships = componentManager.getEntitiesWithComponents(
            DockingComponent::class,
            PositionComponent::class
        )
        
        // Get all ports
        val ports = componentManager.getEntitiesWithComponents(
            PortComponent::class,
            PositionComponent::class
        )
        
        ships.forEach { shipId ->
            val ship = Entity.create(shipId)
            val shipPos = componentManager.getComponent(ship, PositionComponent::class) ?: return@forEach
            val docking = componentManager.getComponent(ship, DockingComponent::class) ?: return@forEach
            
            // Check if ship is near any port
            var nearestPortId: String? = null
            var nearestDistance = Double.MAX_VALUE
            
            ports.forEach { portId ->
                val port = Entity.create(portId)
                val portPos = componentManager.getComponent(port, PositionComponent::class) ?: return@forEach
                val portComp = componentManager.getComponent(port, PortComponent::class) ?: return@forEach
                
                if (portComp.isOperational) {
                    val distance = calculateDistance(shipPos.position, portPos.position)
                    if (distance < dockingRange && distance < nearestDistance) {
                        nearestPortId = portId
                        nearestDistance = distance
                    }
                }
            }
            
            // Update docking status
            if (nearestPortId != null && docking.currentPortId == null) {
                // Dock at port
                val nearestPort = Entity.create(nearestPortId!!)
                val portComp = componentManager.getComponent(nearestPort, PortComponent::class)!!
                
                val updatedDocking = docking.copy(
                    currentPortId = nearestPortId,
                    dockingTime = java.lang.System.currentTimeMillis()
                )
                componentManager.removeComponent(ship, DockingComponent::class)
                componentManager.addComponent(ship, updatedDocking)
                
                // Apply docking fee to ship's economic value
                componentManager.getComponent(ship, EconomicComponent::class)?.let { economic ->
                    val updatedEconomic = economic.copy(
                        dailyOperatingCost = economic.dailyOperatingCost + portComp.dockingFee
                    )
                    componentManager.removeComponent(ship, EconomicComponent::class)
                    componentManager.addComponent(ship, updatedEconomic)
                }
                
                // Stop ship movement
                componentManager.getComponent(ship, MovementComponent::class)?.let { movement ->
                    val updatedMovement = movement.copy(
                        speed = 0.0,
                        isMoving = false
                    )
                    componentManager.removeComponent(ship, MovementComponent::class)
                    componentManager.addComponent(ship, updatedMovement)
                }
            } else if (nearestPortId == null && docking.currentPortId != null) {
                // Undock from port
                val updatedDocking = docking.copy(
                    currentPortId = null,
                    dockingTime = null
                )
                componentManager.removeComponent(ship, DockingComponent::class)
                componentManager.addComponent(ship, updatedDocking)
            }
        }
    }
    
    private fun calculateDistance(pos1: com.flexport.game.models.GeographicalPosition, 
                                 pos2: com.flexport.game.models.GeographicalPosition): Double {
        val deltaLat = pos2.latitude - pos1.latitude
        val deltaLon = pos2.longitude - pos1.longitude
        return kotlin.math.sqrt(deltaLat * deltaLat + deltaLon * deltaLon)
    }
}

