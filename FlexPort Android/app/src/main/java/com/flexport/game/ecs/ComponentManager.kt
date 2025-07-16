package com.flexport.game.ecs

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlin.reflect.KClass

/**
 * Manages all components in the ECS system.
 * Provides efficient storage and retrieval of components by entity and type.
 */
class ComponentManager {
    // Map of component type to (entity ID -> component)
    private val components = mutableMapOf<KClass<out Component>, MutableMap<String, Component>>()
    
    // Map of entity ID to list of component types for that entity
    private val entityComponents = mutableMapOf<String, MutableSet<KClass<out Component>>>()
    
    // Flow for component change notifications
    private val _componentChanges = MutableStateFlow(0)
    val componentChanges: StateFlow<Int> = _componentChanges.asStateFlow()
    
    /**
     * Add a component to an entity
     */
    fun <T : Component> addComponent(entity: Entity, component: T) {
        val componentType = component::class
        
        // Initialize maps if needed
        if (!components.containsKey(componentType)) {
            components[componentType] = mutableMapOf()
        }
        if (!entityComponents.containsKey(entity.id)) {
            entityComponents[entity.id] = mutableSetOf()
        }
        
        // Store component
        components[componentType]!![entity.id] = component
        entityComponents[entity.id]!!.add(componentType)
        
        // Notify of change
        _componentChanges.value++
    }
    
    /**
     * Remove a component from an entity
     */
    fun <T : Component> removeComponent(entity: Entity, componentType: KClass<T>): T? {
        val component = components[componentType]?.remove(entity.id)
        entityComponents[entity.id]?.remove(componentType)
        
        if (component != null) {
            _componentChanges.value++
        }
        
        @Suppress("UNCHECKED_CAST")
        return component as? T
    }
    
    /**
     * Get a component from an entity
     */
    fun <T : Component> getComponent(entity: Entity, componentType: KClass<T>): T? {
        @Suppress("UNCHECKED_CAST")
        return components[componentType]?.get(entity.id) as? T
    }
    
    /**
     * Check if an entity has a specific component
     */
    fun <T : Component> hasComponent(entity: Entity, componentType: KClass<T>): Boolean {
        return components[componentType]?.containsKey(entity.id) == true
    }
    
    /**
     * Get all entities that have a specific component
     */
    fun <T : Component> getEntitiesWithComponent(componentType: KClass<T>): Set<String> {
        return components[componentType]?.keys ?: emptySet()
    }
    
    /**
     * Get all entities that have all of the specified components
     */
    fun getEntitiesWithComponents(vararg componentTypes: KClass<out Component>): Set<String> {
        if (componentTypes.isEmpty()) return emptySet()
        
        var result = getEntitiesWithComponent(componentTypes[0])
        
        for (i in 1 until componentTypes.size) {
            result = result.intersect(getEntitiesWithComponent(componentTypes[i]))
        }
        
        return result
    }
    
    /**
     * Get all components of a specific type
     */
    fun <T : Component> getAllComponents(componentType: KClass<T>): Map<String, T> {
        @Suppress("UNCHECKED_CAST")
        return (components[componentType] ?: emptyMap()) as Map<String, T>
    }
    
    /**
     * Get all component types for an entity
     */
    fun getComponentTypes(entity: Entity): Set<KClass<out Component>> {
        return entityComponents[entity.id]?.toSet() ?: emptySet()
    }
    
    /**
     * Remove all components for an entity
     */
    fun removeAllComponents(entity: Entity) {
        val componentTypes = entityComponents[entity.id]?.toList() ?: return
        
        for (componentType in componentTypes) {
            components[componentType]?.remove(entity.id)
        }
        
        entityComponents.remove(entity.id)
        _componentChanges.value++
    }
    
    /**
     * Get total number of entities with components
     */
    fun getEntityCount(): Int {
        return entityComponents.size
    }
    
    /**
     * Get total number of component instances
     */
    fun getComponentCount(): Int {
        return components.values.sumOf { it.size }
    }
    
    /**
     * Clear all components
     */
    fun clear() {
        components.clear()
        entityComponents.clear()
        _componentChanges.value++
    }
}

// Extension functions for easier component access
inline fun <reified T : Component> ComponentManager.addComponent(entity: Entity, component: T) {
    addComponent(entity, component)
}

inline fun <reified T : Component> ComponentManager.removeComponent(entity: Entity): T? {
    return removeComponent(entity, T::class)
}

inline fun <reified T : Component> ComponentManager.getComponent(entity: Entity): T? {
    return getComponent(entity, T::class)
}

inline fun <reified T : Component> ComponentManager.hasComponent(entity: Entity): Boolean {
    return hasComponent(entity, T::class)
}

inline fun <reified T : Component> ComponentManager.getEntitiesWithComponent(): Set<String> {
    return getEntitiesWithComponent(T::class)
}

inline fun <reified T : Component> ComponentManager.getAllComponents(): Map<String, T> {
    return getAllComponents(T::class)
}