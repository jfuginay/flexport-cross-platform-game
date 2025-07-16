package com.flexport.game.ecs

import kotlinx.coroutines.flow.StateFlow

/**
 * The World represents the entire ECS game world.
 * It manages all entities, components, and systems.
 * This is the main entry point for the ECS architecture.
 */
class World {
    val ecsManager = ECSManager()
    
    /**
     * Get the entity manager for this world
     */
    val entityManager: EntityManager = EntityManager(ecsManager)
    
    /**
     * Performance metrics
     */
    val frameTime: StateFlow<Float> = ecsManager.frameTime
    val entityCount: StateFlow<Int> = ecsManager.entityCount
    val systemCount: StateFlow<Int> = ecsManager.systemCount
    
    /**
     * Start the world simulation
     */
    fun start() {
        ecsManager.start()
    }
    
    /**
     * Stop the world simulation
     */
    fun stop() {
        ecsManager.stop()
    }
    
    /**
     * Pause the world simulation
     */
    fun pause() {
        ecsManager.pause()
    }
    
    /**
     * Resume the world simulation
     */
    fun resume() {
        ecsManager.resume()
    }
    
    /**
     * Add a system to the world
     */
    fun addSystem(system: System) {
        ecsManager.addSystem(system)
    }
    
    /**
     * Remove a system from the world
     */
    fun removeSystem(system: System) {
        ecsManager.removeSystem(system)
    }
    
    /**
     * Get a system by its class
     */
    inline fun <reified T : System> getSystem(): T? {
        @Suppress("UNCHECKED_CAST")
        return ecsManager.getSystem(T::class) as? T
    }
    
    /**
     * Create a new entity in the world
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
     * Destroy an entity and all its components
     */
    fun destroyEntity(entity: Entity) {
        ecsManager.destroyEntity(entity)
    }
    
    /**
     * Get all entities in the world
     */
    fun getAllEntities(): Collection<Entity> {
        return ecsManager.getAllEntities()
    }
    
    /**
     * Add a component to an entity
     */
    inline fun <reified T : Component> addComponent(entity: Entity, component: T) {
        ecsManager.addComponent(entity, component)
    }
    
    /**
     * Remove a component from an entity
     */
    inline fun <reified T : Component> removeComponent(entity: Entity): T? {
        return ecsManager.removeComponent<T>(entity)
    }
    
    /**
     * Get a component from an entity
     */
    inline fun <reified T : Component> getComponent(entity: Entity): T? {
        return ecsManager.getComponent<T>(entity)
    }
    
    /**
     * Check if an entity has a component
     */
    inline fun <reified T : Component> hasComponent(entity: Entity): Boolean {
        return ecsManager.hasComponent<T>(entity)
    }
    
    /**
     * Get world statistics
     */
    fun getStats(): WorldStats {
        val ecsStats = ecsManager.getStats()
        return WorldStats(
            entityCount = ecsStats.entityCount,
            componentCount = ecsStats.componentCount,
            systemCount = ecsStats.systemCount,
            frameTimeMs = ecsStats.frameTimeMs,
            isRunning = ecsStats.isRunning
        )
    }
    
    /**
     * Clean up all resources
     */
    fun dispose() {
        ecsManager.cleanup()
    }
}

/**
 * Statistics about the world
 */
data class WorldStats(
    val entityCount: Int,
    val componentCount: Int,
    val systemCount: Int,
    val frameTimeMs: Float,
    val isRunning: Boolean
)

/**
 * Singleton instance of the game world
 */
object GameWorld {
    private var _instance: World? = null
    
    /**
     * Get or create the world instance
     */
    val instance: World
        get() {
            if (_instance == null) {
                _instance = World()
            }
            return _instance!!
        }
    
    /**
     * Reset the world (useful for testing or restarting the game)
     */
    fun reset() {
        _instance?.dispose()
        _instance = null
    }
    
    /**
     * Check if the world has been initialized
     */
    fun isInitialized(): Boolean = _instance != null
}