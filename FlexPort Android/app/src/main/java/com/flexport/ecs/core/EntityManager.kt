package com.flexport.ecs.core

import com.flexport.game.ecs.Component
import com.flexport.game.ecs.ECSManager
import kotlin.reflect.KClass

/**
 * Entity Manager wrapper that provides Entity objects with component management
 * This wraps the game's EntityManager to provide the expected API
 */
class EntityManager(private val ecsManager: ECSManager) {
    private val gameEntityManager = com.flexport.game.ecs.EntityManager(ecsManager)
    
    /**
     * Create a new entity
     */
    fun createEntity(): Entity {
        val gameEntity = gameEntityManager.createEntity()
        val id = gameEntity.id.toIntOrNull() ?: gameEntity.id.hashCode()
        return Entity(id, gameEntityManager)
    }
    
    /**
     * Get an entity by ID
     */
    fun getEntity(id: Int): Entity? {
        val gameEntity = gameEntityManager.getEntity(id.toString()) ?: return null
        return Entity(id, gameEntityManager)
    }
    
    /**
     * Get all entities
     */
    fun getAllEntities(): List<Entity> {
        return gameEntityManager.getAllEntities().map { gameEntity ->
            val id = gameEntity.id.toIntOrNull() ?: gameEntity.id.hashCode()
            Entity(id, gameEntityManager)
        }
    }
    
    /**
     * Get entities with a specific component type
     */
    fun <T : Component> getEntitiesWithComponent(componentClass: KClass<T>): List<Entity> {
        return gameEntityManager.getEntitiesWithComponents(componentClass).map { entityId ->
            val id = entityId.toIntOrNull() ?: entityId.hashCode()
            Entity(id, gameEntityManager)
        }
    }
    
    /**
     * Get entities with a specific component type (reified version)
     */
    inline fun <reified T : Component> getEntitiesWithComponent(): List<Entity> {
        return getEntitiesWithComponent(T::class)
    }
    
    /**
     * Destroy an entity
     */
    fun destroyEntity(entity: Entity) {
        entity.gameEntity?.let { gameEntityManager.destroyEntity(it) }
    }
    
    /**
     * Destroy an entity by ID
     */
    fun destroyEntity(entityId: Int) {
        gameEntityManager.destroyEntity(entityId.toString())
    }
}