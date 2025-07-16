package com.flexport.ecs.core

import com.flexport.game.ecs.Component
import kotlin.reflect.KClass

/**
 * Entity wrapper that provides component management functionality
 * This wraps the basic Entity from the game.ecs package
 */
class Entity(
    val id: Int,
    val entityManager: com.flexport.game.ecs.EntityManager
) {
    // Convert Int ID to String for underlying entity system
    private val stringId: String = id.toString()
    
    /**
     * Get the underlying game entity
     */
    val gameEntity: com.flexport.game.ecs.Entity? 
        get() = entityManager.getEntity(stringId)
    
    /**
     * Get a component from this entity
     */
    inline fun <reified T : Component> getComponent(): T? {
        val entity = gameEntity ?: return null
        return entityManager.getComponent(entity, T::class)
    }
    
    /**
     * Get a component by class
     */
    fun <T : Component> getComponent(componentClass: KClass<T>): T? {
        return entityManager.getComponent(gameEntity ?: return null, componentClass)
    }
    
    /**
     * Check if entity has a specific component
     */
    inline fun <reified T : Component> hasComponent(): Boolean {
        return getComponent<T>() != null
    }
    
    /**
     * Check if entity has a component by class
     */
    fun <T : Component> hasComponent(componentClass: KClass<T>): Boolean {
        return getComponent(componentClass) != null
    }
    
    /**
     * Check if entity has a component by Java class (for compatibility)
     */
    fun hasComponent(componentClass: Class<out Component>): Boolean {
        return hasComponent(componentClass.kotlin)
    }
    
    /**
     * Add a component to this entity
     */
    fun <T : Component> addComponent(component: T) {
        gameEntity?.let { entityManager.addComponent(it, component) }
    }
    
    /**
     * Remove a component from this entity
     */
    inline fun <reified T : Component> removeComponent(): T? {
        val entity = gameEntity ?: return null
        return entityManager.removeComponent(entity, T::class)
    }
    
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is Entity) return false
        return id == other.id
    }
    
    override fun hashCode(): Int = id
    
    override fun toString(): String = "Entity($id)"
}

/**
 * Extension to get entities with a specific component type
 */
inline fun <reified T : Component> com.flexport.game.ecs.EntityManager.getEntitiesWithComponent(): List<Entity> {
    return this.getEntitiesWithComponents(T::class).map { entityId ->
        // Convert entity ID to Int for Entity wrapper
        val id = entityId.toIntOrNull() ?: entityId.hashCode()
        Entity(id, this)
    }
}