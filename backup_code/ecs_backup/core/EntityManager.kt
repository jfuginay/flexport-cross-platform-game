package com.flexport.ecs.core

import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.util.concurrent.ConcurrentHashMap
import kotlin.reflect.KClass

/**
 * EntityManager handles creation, deletion, and component management for entities.
 * Thread-safe implementation for concurrent access.
 */
class EntityManager {
    private val entities = ConcurrentHashMap<String, Entity>()
    private val componentStorage = ConcurrentHashMap<ComponentType, ConcurrentHashMap<String, Component>>()
    private val entityComponents = ConcurrentHashMap<String, MutableSet<ComponentType>>()
    private val mutex = Mutex()

    /**
     * Create a new entity
     */
    suspend fun createEntity(): Entity = mutex.withLock {
        val entity = Entity()
        entities[entity.id] = entity
        entityComponents[entity.id] = ConcurrentHashMap.newKeySet()
        return entity
    }

    /**
     * Delete an entity and all its components
     */
    suspend fun deleteEntity(entity: Entity) = mutex.withLock {
        entities.remove(entity.id)
        entityComponents[entity.id]?.forEach { componentType ->
            componentStorage[componentType]?.remove(entity.id)
        }
        entityComponents.remove(entity.id)
    }

    /**
     * Add a component to an entity
     */
    suspend fun <T : Component> addComponent(entity: Entity, component: T) = mutex.withLock {
        val componentType = component::class
        
        // Initialize storage for this component type if needed
        componentStorage.computeIfAbsent(componentType) { ConcurrentHashMap() }
        
        // Store the component
        componentStorage[componentType]!![entity.id] = component
        
        // Track component type for this entity
        entityComponents[entity.id]?.add(componentType)
    }

    /**
     * Remove a component from an entity
     */
    suspend fun <T : Component> removeComponent(entity: Entity, componentType: KClass<T>) = mutex.withLock {
        componentStorage[componentType]?.remove(entity.id)
        entityComponents[entity.id]?.remove(componentType)
    }

    /**
     * Get a component from an entity
     */
    @Suppress("UNCHECKED_CAST")
    fun <T : Component> getComponent(entity: Entity, componentType: KClass<T>): T? {
        return componentStorage[componentType]?.get(entity.id) as? T
    }

    /**
     * Check if an entity has a component
     */
    fun <T : Component> hasComponent(entity: Entity, componentType: KClass<T>): Boolean {
        return entityComponents[entity.id]?.contains(componentType) == true
    }

    /**
     * Get all entities with specific components
     */
    fun getEntitiesWithComponents(vararg componentTypes: ComponentType): List<Entity> {
        return entities.values.filter { entity ->
            componentTypes.all { componentType ->
                hasComponent(entity, componentType)
            }
        }
    }

    /**
     * Get all entities
     */
    fun getAllEntities(): List<Entity> {
        return entities.values.toList()
    }

    /**
     * Clear all entities and components
     */
    suspend fun clear() = mutex.withLock {
        entities.clear()
        componentStorage.clear()
        entityComponents.clear()
    }

    /**
     * Get entity count
     */
    fun getEntityCount(): Int = entities.size
}