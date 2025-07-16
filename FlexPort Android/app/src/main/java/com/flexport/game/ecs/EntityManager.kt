package com.flexport.game.ecs

import kotlin.reflect.KClass

/**
 * EntityManager provides a clean interface for managing entities and components.
 * This wraps the ECSManager to provide a more focused API for entity operations.
 */
class EntityManager(private val ecsManager: ECSManager) {
    
    /**
     * Create a new entity
     */
    fun createEntity(): Entity {
        return ecsManager.createEntity()
    }
    
    /**
     * Create a new entity with a specific ID
     */
    fun createEntity(id: String): Entity {
        return ecsManager.createEntity(id)
    }
    
    /**
     * Get an entity by ID
     */
    fun getEntity(id: String): Entity? {
        return ecsManager.getEntity(id)
    }
    
    /**
     * Get an entity by numeric ID (for compatibility)
     */
    fun getEntity(id: Int): Entity? {
        return getEntity(id.toString())
    }
    
    /**
     * Destroy an entity and all its components
     */
    fun destroyEntity(entity: Entity) {
        ecsManager.destroyEntity(entity)
    }
    
    /**
     * Destroy an entity by ID
     */
    fun destroyEntity(entityId: String) {
        getEntity(entityId)?.let { destroyEntity(it) }
    }
    
    /**
     * Get all entities
     */
    fun getAllEntities(): Collection<Entity> {
        return ecsManager.getAllEntities()
    }
    
    /**
     * Add a component to an entity
     */
    fun <T : Component> addComponent(entity: Entity, component: T) {
        ecsManager.addComponent(entity, component)
    }
    
    /**
     * Remove a component from an entity
     */
    fun <T : Component> removeComponent(entity: Entity, componentType: KClass<T>): T? {
        return ecsManager.removeComponent(entity, componentType)
    }
    
    /**
     * Get a component from an entity
     */
    fun <T : Component> getComponent(entity: Entity, componentType: KClass<T>): T? {
        return ecsManager.getComponent(entity, componentType)
    }
    
    /**
     * Check if an entity has a component
     */
    fun <T : Component> hasComponent(entity: Entity, componentType: KClass<T>): Boolean {
        return ecsManager.hasComponent(entity, componentType)
    }
    
    /**
     * Get all entities that have a specific component type
     */
    inline fun <reified T : Component> getEntitiesWithComponent(): List<String> {
        return getAllEntities().map { it.id }.filter { entityId ->
            val entity = getEntity(entityId)!!
            hasComponent(entity, T::class)
        }
    }
    
    /**
     * Get all entities that have all of the specified component types
     */
    fun getEntitiesWithComponents(vararg componentTypes: KClass<out Component>): List<String> {
        return getAllEntities().map { it.id }.filter { entityId ->
            val entity = getEntity(entityId)!!
            componentTypes.all { componentType ->
                hasComponent(entity, componentType)
            }
        }
    }
    
    /**
     * Create a query builder for complex entity queries
     */
    fun query(): EntityQuery {
        return EntityQuery(this)
    }
    
    /**
     * Get the number of entities
     */
    fun getEntityCount(): Int {
        return getAllEntities().size
    }
    
    /**
     * Check if an entity exists
     */
    fun exists(entityId: String): Boolean {
        return getEntity(entityId) != null
    }
    
    /**
     * Check if an entity exists
     */
    fun exists(entity: Entity): Boolean {
        return exists(entity.id)
    }
}

/**
 * Extension functions for easier component access
 */
inline fun <reified T : Component> EntityManager.addComponent(entity: Entity, component: T) {
    addComponent(entity, component)
}

inline fun <reified T : Component> EntityManager.removeComponent(entity: Entity): T? {
    return removeComponent(entity, T::class)
}

inline fun <reified T : Component> EntityManager.getComponent(entity: Entity): T? {
    return getComponent(entity, T::class)
}

inline fun <reified T : Component> EntityManager.hasComponent(entity: Entity): Boolean {
    return hasComponent(entity, T::class)
}

/**
 * Extension functions for Entity to work with components
 */
inline fun <reified T : Component> Entity.getComponent(): T? {
    val world = GameWorld.instance
    return world.entityManager.getComponent(this, T::class)
}

inline fun <reified T : Component> Entity.hasComponent(): Boolean {
    val world = GameWorld.instance
    return world.entityManager.hasComponent(this, T::class)
}

inline fun <reified T : Component> Entity.addComponent(component: T) {
    val world = GameWorld.instance
    world.entityManager.addComponent(this, component)
}

inline fun <reified T : Component> Entity.removeComponent(): T? {
    val world = GameWorld.instance
    return world.entityManager.removeComponent(this, T::class)
}

/**
 * Query builder for complex entity queries
 */
class EntityQuery(private val entityManager: EntityManager) {
    val requiredComponents = mutableListOf<KClass<out Component>>()
    val excludedComponents = mutableListOf<KClass<out Component>>()
    private var filter: ((Entity) -> Boolean)? = null
    
    /**
     * Require entities to have this component
     */
    inline fun <reified T : Component> withComponent(): EntityQuery {
        requiredComponents.add(T::class)
        return this
    }
    
    /**
     * Require entities to have this component type
     */
    fun withComponent(componentType: KClass<out Component>): EntityQuery {
        requiredComponents.add(componentType)
        return this
    }
    
    /**
     * Exclude entities that have this component
     */
    inline fun <reified T : Component> withoutComponent(): EntityQuery {
        excludedComponents.add(T::class)
        return this
    }
    
    /**
     * Exclude entities that have this component type
     */
    fun withoutComponent(componentType: KClass<out Component>): EntityQuery {
        excludedComponents.add(componentType)
        return this
    }
    
    /**
     * Add a custom filter predicate
     */
    fun where(predicate: (Entity) -> Boolean): EntityQuery {
        val previousFilter = filter
        filter = if (previousFilter != null) {
            { entity -> previousFilter(entity) && predicate(entity) }
        } else {
            predicate
        }
        return this
    }
    
    /**
     * Execute the query and return matching entities
     */
    fun get(): List<Entity> {
        return entityManager.getAllEntities().filter { entity ->
            // Check required components
            requiredComponents.all { componentType ->
                entityManager.hasComponent(entity, componentType)
            } &&
            // Check excluded components
            excludedComponents.none { componentType ->
                entityManager.hasComponent(entity, componentType)
            } &&
            // Apply custom filter
            (filter?.invoke(entity) ?: true)
        }
    }
    
    /**
     * Execute the query and return the first matching entity
     */
    fun first(): Entity? {
        return get().firstOrNull()
    }
    
    /**
     * Execute the query and return the count of matching entities
     */
    fun count(): Int {
        return get().size
    }
    
    /**
     * Check if any entities match the query
     */
    fun any(): Boolean {
        return first() != null
    }
}