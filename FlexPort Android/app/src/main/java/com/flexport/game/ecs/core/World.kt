package com.flexport.game.ecs.core

import kotlinx.coroutines.*
import java.util.concurrent.ConcurrentHashMap
import kotlin.reflect.KClass

/**
 * The World class is the main engine that manages entities, components, and systems.
 * It coordinates the update cycle and provides a unified interface for the ECS.
 */
class World {
    val entityManager = EntityManager()
    private val systems = ConcurrentHashMap<KClass<out System>, System>()
    private val systemUpdateOrder = mutableListOf<System>()
    private val worldScope = CoroutineScope(Dispatchers.Default + SupervisorJob())
    
    private var isRunning = false
    private var lastUpdateTime = java.lang.System.currentTimeMillis()
    
    /**
     * Register a system in the world
     */
    suspend fun <T : System> registerSystem(system: T): T {
        systems[system::class] = system
        systemUpdateOrder.add(system)
        system.initialize()
        return system
    }
    
    /**
     * Get a registered system
     */
    @Suppress("UNCHECKED_CAST")
    fun <T : System> getSystem(systemClass: KClass<T>): T? {
        return systems[systemClass] as? T
    }
    
    /**
     * Update all systems
     */
    suspend fun update() {
        val currentTime = java.lang.System.currentTimeMillis()
        val deltaTime = (currentTime - lastUpdateTime) / 1000f
        lastUpdateTime = currentTime
        
        // Update all systems in parallel
        coroutineScope {
            systemUpdateOrder.map { system ->
                launch {
                    system.update(deltaTime)
                }
            }.joinAll()
        }
    }
    
    /**
     * Start the world update loop
     */
    fun start() {
        if (isRunning) return
        
        isRunning = true
        worldScope.launch {
            while (isRunning) {
                update()
                delay(16) // ~60 FPS
            }
        }
    }
    
    /**
     * Stop the world update loop
     */
    fun stop() {
        isRunning = false
    }
    
    /**
     * Dispose of all systems and clear entities
     */
    suspend fun dispose() {
        stop()
        
        // Dispose all systems
        systemUpdateOrder.forEach { system ->
            system.dispose()
        }
        
        systems.clear()
        systemUpdateOrder.clear()
        entityManager.clear()
        
        worldScope.cancel()
    }
}