package com.flexport.game.ecs.systems

import com.flexport.game.ecs.System
import com.flexport.game.ecs.ComponentManager
import com.flexport.game.ecs.Entity
import com.flexport.game.ecs.*

/**
 * System responsible for handling entity movement and position updates
 */
class MovementSystem(private val componentManager: ComponentManager) : System {
    
    override fun getPriority(): Int = 10
    
    override fun update(deltaTime: Float) {
        // Get all entities with both position and movement components
        val entities = componentManager.getEntitiesWithComponents(
            PositionComponent::class,
            MovementComponent::class
        )
        
        entities.forEach { entityId ->
            val entity = Entity.create(entityId)
            val position = componentManager.getComponent(entity, PositionComponent::class) ?: return@forEach
            val movement = componentManager.getComponent(entity, MovementComponent::class) ?: return@forEach
            
            if (movement.isMoving && movement.destination != null) {
                // Calculate direction to target
                val targetPos = movement.destination!!
                val deltaLat = targetPos.latitude - position.position.latitude
                val deltaLon = targetPos.longitude - position.position.longitude
                
                // Simple distance check (for demo purposes)
                val distance = kotlin.math.sqrt(deltaLat * deltaLat + deltaLon * deltaLon)
                
                if (distance < 0.1) { // Arrived at destination
                    // Update position to exact target
                    val updatedPosition = position.copy(
                        position = targetPos,
                        heading = position.heading
                    )
                    componentManager.removeComponent(entity, PositionComponent::class)
                    componentManager.addComponent(entity, updatedPosition)
                    
                    // Stop movement
                    val updatedMovement = movement.copy(
                        isMoving = false,
                        destination = null
                    )
                    componentManager.removeComponent(entity, MovementComponent::class)
                    componentManager.addComponent(entity, updatedMovement)
                } else {
                    // Move towards target
                    val moveDistance = movement.speed * deltaTime / 3600.0 // Convert to degrees
                    val ratio = moveDistance / distance
                    
                    val newLat = position.position.latitude + (deltaLat * ratio)
                    val newLon = position.position.longitude + (deltaLon * ratio)
                    
                    // Calculate heading
                    val heading = kotlin.math.atan2(deltaLon, deltaLat) * 180 / kotlin.math.PI
                    
                    // Update position
                    val updatedPosition = position.copy(
                        position = com.flexport.game.models.GeographicalPosition(newLat, newLon),
                        heading = heading
                    )
                    componentManager.removeComponent(entity, PositionComponent::class)
                    componentManager.addComponent(entity, updatedPosition)
                }
            }
        }
    }
}

