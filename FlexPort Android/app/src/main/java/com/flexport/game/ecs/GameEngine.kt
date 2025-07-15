package com.flexport.game.ecs

import com.flexport.game.ecs.components.*
import com.flexport.game.ecs.core.World
import com.flexport.game.ecs.systems.EconomicUpdateSystem
import com.flexport.game.ecs.systems.MovementSystem
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Main game engine that manages the ECS world and provides a simplified interface
 * for the game to interact with the entity system.
 */
class GameEngine {
    private val world = World()
    private var isInitialized = false
    
    // Game state tracking
    private val _gameState = MutableStateFlow(GameState())
    val gameState: StateFlow<GameState> = _gameState.asStateFlow()
    
    // Systems
    private lateinit var movementSystem: MovementSystem
    private lateinit var economicUpdateSystem: EconomicUpdateSystem
    
    /**
     * Initialize the game engine and all systems
     */
    suspend fun initialize() {
        if (isInitialized) return
        
        // Register systems
        movementSystem = world.registerSystem(MovementSystem(world.entityManager))
        economicUpdateSystem = world.registerSystem(EconomicUpdateSystem(world.entityManager))
        
        // Create initial test entities
        createTestEntities()
        
        isInitialized = true
    }
    
    /**
     * Start the game engine
     */
    fun start() {
        if (!isInitialized) {
            throw IllegalStateException("GameEngine must be initialized before starting")
        }
        world.start()
    }
    
    /**
     * Stop the game engine
     */
    fun stop() {
        world.stop()
    }
    
    /**
     * Clean up resources
     */
    suspend fun dispose() {
        world.dispose()
        isInitialized = false
    }
    
    /**
     * Create test entities to demonstrate the ECS working
     */
    private suspend fun createTestEntities() {
        // Create a test ship
        val ship = world.entityManager.createEntity()
        world.entityManager.addComponent(ship, PositionComponent(x = 100f, y = 100f))
        world.entityManager.addComponent(ship, VelocityComponent(dx = 10f, dy = 5f))
        world.entityManager.addComponent(ship, AssetComponent(
            assetType = AssetType.SHIP,
            assetId = "ship_001",
            name = "Test Cargo Ship",
            owner = "player",
            capacity = 1000,
            maintenanceCost = 50f
        ))
        world.entityManager.addComponent(ship, EconomicComponent(
            balance = 10000f,
            creditLimit = 5000f
        ))
        world.entityManager.addComponent(ship, RenderComponent(
            textureId = "ship_sprite",
            width = 64f,
            height = 32f
        ))
        
        // Create a test port
        val port = world.entityManager.createEntity()
        world.entityManager.addComponent(port, PositionComponent(x = 200f, y = 200f))
        world.entityManager.addComponent(port, AssetComponent(
            assetType = AssetType.PORT,
            assetId = "port_001",
            name = "Test Port",
            owner = "player",
            capacity = 5000,
            maintenanceCost = 100f
        ))
        world.entityManager.addComponent(port, EconomicComponent(
            balance = 50000f,
            creditLimit = 20000f
        ))
        world.entityManager.addComponent(port, RenderComponent(
            textureId = "port_sprite",
            width = 96f,
            height = 96f
        ))
        
        // Create a moving test entity
        val movingEntity = world.entityManager.createEntity()
        world.entityManager.addComponent(movingEntity, PositionComponent(x = 0f, y = 0f))
        world.entityManager.addComponent(movingEntity, VelocityComponent(dx = 20f, dy = 15f, angularVelocity = 1f))
        world.entityManager.addComponent(movingEntity, RenderComponent(
            textureId = "test_sprite",
            width = 32f,
            height = 32f
        ))
        
        updateGameState()
    }
    
    /**
     * Update the game state for UI consumption
     */
    private fun updateGameState() {
        val entities = world.entityManager.getAllEntities()
        var totalBalance = 0f
        var shipCount = 0
        var portCount = 0
        
        entities.forEach { entity ->
            val economic = world.entityManager.getComponent(entity, EconomicComponent::class)
            val asset = world.entityManager.getComponent(entity, AssetComponent::class)
            
            economic?.let { totalBalance += it.balance }
            asset?.let { 
                when (it.assetType) {
                    AssetType.SHIP -> shipCount++
                    AssetType.PORT -> portCount++
                    else -> {}
                }
            }
        }
        
        _gameState.value = GameState(
            entityCount = entities.size,
            totalBalance = totalBalance,
            shipCount = shipCount,
            portCount = portCount,
            isRunning = world.entityManager.getAllEntities().isNotEmpty()
        )
    }
    
    /**
     * Get current game statistics for display
     */
    fun getGameStats(): GameStats {
        val entities = world.entityManager.getAllEntities()
        var totalEntities = entities.size
        var movingEntities = 0
        var economicEntities = 0
        
        entities.forEach { entity ->
            if (world.entityManager.hasComponent(entity, VelocityComponent::class)) {
                movingEntities++
            }
            if (world.entityManager.hasComponent(entity, EconomicComponent::class)) {
                economicEntities++
            }
        }
        
        return GameStats(
            totalEntities = totalEntities,
            movingEntities = movingEntities,
            economicEntities = economicEntities,
            systemsActive = isInitialized && totalEntities > 0
        )
    }
}

/**
 * Data class representing the current state of the game
 */
data class GameState(
    val entityCount: Int = 0,
    val totalBalance: Float = 0f,
    val shipCount: Int = 0,
    val portCount: Int = 0,
    val isRunning: Boolean = false
)

/**
 * Data class for game statistics
 */
data class GameStats(
    val totalEntities: Int = 0,
    val movingEntities: Int = 0,
    val economicEntities: Int = 0,
    val systemsActive: Boolean = false
)