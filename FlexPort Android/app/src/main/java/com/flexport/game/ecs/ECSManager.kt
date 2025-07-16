package com.flexport.game.ecs

import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Central manager for the Entity-Component-System architecture.
 * Coordinates entities, components, and systems.
 */
class ECSManager {
    private val componentManager = ComponentManager()
    private val entities = mutableMapOf<String, Entity>()
    private val systems = mutableListOf<System>()
    
    // Game loop control
    private var gameLoopJob: Job? = null
    private var isRunning = false
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())
    
    // Performance metrics
    private val _frameTime = MutableStateFlow(0f)
    val frameTime: StateFlow<Float> = _frameTime.asStateFlow()
    
    private val _entityCount = MutableStateFlow(0)
    val entityCount: StateFlow<Int> = _entityCount.asStateFlow()
    
    private val _systemCount = MutableStateFlow(0)
    val systemCount: StateFlow<Int> = _systemCount.asStateFlow()
    
    init {
        // Initialize core systems
        addSystem(MovementSystem(componentManager))
        addSystem(EconomicSystem(componentManager))
        addSystem(DockingSystem(componentManager))
    }
    
    // Entity management
    fun createEntity(): Entity {
        val entity = Entity.create()
        entities[entity.id] = entity
        updateEntityCount()
        return entity
    }
    
    fun createEntity(id: String): Entity {
        val entity = Entity.create(id)
        entities[entity.id] = entity
        updateEntityCount()
        return entity
    }
    
    fun getEntity(id: String): Entity? {
        return entities[id]
    }
    
    fun destroyEntity(entity: Entity) {
        componentManager.removeAllComponents(entity)
        entities.remove(entity.id)
        updateEntityCount()
    }
    
    fun getAllEntities(): Collection<Entity> {
        return entities.values
    }
    
    // Component management (delegated to ComponentManager)
    fun <T : Component> addComponent(entity: Entity, component: T) {
        componentManager.addComponent(entity, component)
    }
    
    fun <T : Component> removeComponent(entity: Entity, componentType: kotlin.reflect.KClass<T>): T? {
        return componentManager.removeComponent(entity, componentType)
    }
    
    fun <T : Component> getComponent(entity: Entity, componentType: kotlin.reflect.KClass<T>): T? {
        return componentManager.getComponent(entity, componentType)
    }
    
    fun <T : Component> hasComponent(entity: Entity, componentType: kotlin.reflect.KClass<T>): Boolean {
        return componentManager.hasComponent(entity, componentType)
    }
    
    // System management
    fun addSystem(system: System) {
        systems.add(system)
        systems.sortBy { it.getPriority() }
        system.initialize()
        updateSystemCount()
    }
    
    fun removeSystem(system: System) {
        system.dispose()
        systems.remove(system)
        updateSystemCount()
    }
    
    fun getSystem(systemClass: kotlin.reflect.KClass<out System>): System? {
        return systems.find { it::class == systemClass }
    }
    
    // Game loop
    fun start() {
        if (isRunning) return
        
        isRunning = true
        gameLoopJob = scope.launch {
            var lastTime = java.lang.System.nanoTime()
            
            while (isActive && isRunning) {
                val currentTime = java.lang.System.nanoTime()
                val deltaTime = (currentTime - lastTime) / 1_000_000_000f // Convert to seconds
                lastTime = currentTime
                
                // Update all systems
                val frameStart = java.lang.System.nanoTime()
                updateSystems(deltaTime)
                val frameEnd = java.lang.System.nanoTime()
                
                _frameTime.value = (frameEnd - frameStart) / 1_000_000f // Convert to milliseconds
                
                // Target 60 FPS (16.67ms per frame)
                val targetFrameTime = 16_666_667L // nanoseconds
                val actualFrameTime = frameEnd - frameStart
                val sleepTime = targetFrameTime - actualFrameTime
                
                if (sleepTime > 0) {
                    delay(sleepTime / 1_000_000) // Convert to milliseconds for delay
                }
            }
        }
    }
    
    fun stop() {
        isRunning = false
        gameLoopJob?.cancel()
    }
    
    fun pause() {
        isRunning = false
    }
    
    fun resume() {
        if (!isRunning && gameLoopJob?.isActive != true) {
            start()
        } else {
            isRunning = true
        }
    }
    
    private fun updateSystems(deltaTime: Float) {
        for (system in systems) {
            try {
                system.update(deltaTime)
            } catch (e: Exception) {
                // Log error but continue with other systems
                println("Error in system ${system::class.simpleName}: ${e.message}")
            }
        }
    }
    
    // Helper methods for creating common game entities
    fun createShipEntity(
        position: com.flexport.game.models.GeographicalPosition,
        ship: com.flexport.game.models.Ship,
        playerId: String
    ): Entity {
        val entity = createEntity(ship.id)
        
        addComponent(entity, PositionComponent(position))
        addComponent(entity, MovementComponent(ship.speed, ship.speed))
        addComponent(entity, CargoComponent(ship.capacity, ship.currentCargo))
        addComponent(entity, OwnershipComponent(playerId, purchasePrice = ship.purchasePrice))
        addComponent(entity, EconomicComponent(ship.purchasePrice, ship.maintenanceCost))
        addComponent(entity, DockingComponent())
        addComponent(entity, ShipComponent(ship.type, ship.fuelLevel, ship.condition, ship.fuelEfficiency))
        
        return entity
    }
    
    fun createPortEntity(port: com.flexport.game.models.Port): Entity {
        val entity = createEntity(port.id)
        
        addComponent(entity, PositionComponent(port.position))
        addComponent(entity, PortComponent(port.type, port.capacity, port.dockingFee, port.isOperational))
        
        return entity
    }
    
    // Utility methods
    private fun updateEntityCount() {
        _entityCount.value = entities.size
    }
    
    private fun updateSystemCount() {
        _systemCount.value = systems.size
    }
    
    fun getStats(): ECSStats {
        return ECSStats(
            entityCount = entities.size,
            componentCount = componentManager.getComponentCount(),
            systemCount = systems.size,
            frameTimeMs = _frameTime.value,
            isRunning = isRunning
        )
    }
    
    fun cleanup() {
        stop()
        
        // Dispose all systems
        systems.forEach { it.dispose() }
        systems.clear()
        
        // Clear all data
        componentManager.clear()
        entities.clear()
        
        scope.cancel()
    }
}

// Extension functions for easier component access
inline fun <reified T : Component> ECSManager.addComponent(entity: Entity, component: T) {
    addComponent(entity, component)
}

inline fun <reified T : Component> ECSManager.removeComponent(entity: Entity): T? {
    return removeComponent(entity, T::class)
}

inline fun <reified T : Component> ECSManager.getComponent(entity: Entity): T? {
    return getComponent(entity, T::class)
}

inline fun <reified T : Component> ECSManager.hasComponent(entity: Entity): Boolean {
    return hasComponent(entity, T::class)
}

inline fun <reified T : System> ECSManager.getSystem(): T? {
    @Suppress("UNCHECKED_CAST")
    return getSystem(T::class) as? T
}

/**
 * Statistics about the ECS system
 */
data class ECSStats(
    val entityCount: Int,
    val componentCount: Int,
    val systemCount: Int,
    val frameTimeMs: Float,
    val isRunning: Boolean
)