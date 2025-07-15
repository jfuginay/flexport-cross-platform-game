package com.flexport.game.ecs.systems

import com.flexport.game.ecs.components.PositionComponent
import com.flexport.game.ecs.components.VelocityComponent
import com.flexport.game.ecs.core.ComponentType
import com.flexport.game.ecs.core.EntityManager
import com.flexport.game.ecs.core.System
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch

/**
 * System responsible for updating entity positions based on their velocity
 */
class MovementSystem(
    entityManager: EntityManager
) : System(entityManager) {
    
    override fun getRequiredComponents(): Array<ComponentType> {
        return arrayOf(PositionComponent::class, VelocityComponent::class)
    }
    
    override suspend fun update(deltaTime: Float) {
        val entities = entityManager.getEntitiesWithComponents(
            PositionComponent::class,
            VelocityComponent::class
        )
        
        // Process entities in parallel for better performance
        coroutineScope {
            entities.chunked(100).forEach { chunk ->
                launch {
                    chunk.forEach { entity ->
                        val position = entityManager.getComponent(entity, PositionComponent::class)
                        val velocity = entityManager.getComponent(entity, VelocityComponent::class)
                        
                        if (position != null && velocity != null) {
                            // Update position based on velocity
                            position.x += velocity.dx * deltaTime
                            position.y += velocity.dy * deltaTime
                            position.rotation += velocity.angularVelocity * deltaTime
                            
                            // Keep rotation in range [0, 2π]
                            while (position.rotation < 0) {
                                position.rotation += 2 * Math.PI.toFloat()
                            }
                            while (position.rotation > 2 * Math.PI) {
                                position.rotation -= 2 * Math.PI.toFloat()
                            }
                        }
                    }
                }
            }
        }
    }
}