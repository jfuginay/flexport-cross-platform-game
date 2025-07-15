package com.flexport.game.ecs.core

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Base class for all systems in the ECS architecture.
 * Systems contain the game logic and operate on entities with specific components.
 */
abstract class System(
    protected val entityManager: EntityManager
) {
    protected val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())
    
    /**
     * Called once when the system is initialized
     */
    open suspend fun initialize() {}
    
    /**
     * Called every frame to update the system
     * @param deltaTime Time since last update in seconds
     */
    abstract suspend fun update(deltaTime: Float)
    
    /**
     * Called when the system is being destroyed
     */
    open suspend fun dispose() {}
    
    /**
     * Get the component types this system requires
     */
    abstract fun getRequiredComponents(): Array<ComponentType>
    
    /**
     * Process entities in parallel for better performance
     */
    protected suspend fun processEntitiesParallel(
        entities: List<Entity>,
        process: suspend (Entity) -> Unit
    ) {
        entities.forEach { entity ->
            scope.launch {
                process(entity)
            }
        }
    }
}