package com.flexport.ai.integration

import com.flexport.ai.AISingularityManager
import com.flexport.ai.AISingularitySystemStatus
import com.flexport.ai.models.*
import com.flexport.ai.systems.*
import com.flexport.economics.EconomicEngine
import com.flexport.game.ecs.EntityManager
import com.flexport.game.ecs.Entity
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * Integration bridge connecting AI system to game infrastructure
 */
class GameIntegrationBridge(
    private val economicEngine: EconomicEngine,
    private val entityManager: EntityManager? = null
) {
    
    private lateinit var aiSingularityManager: AISingularityManager
    private var aiEntityIntegration: AIEntityIntegration? = null
    private var isInitialized = false
    
    // Game state updates
    private val _gameStateUpdates = MutableSharedFlow<GameStateUpdate>()
    val gameStateUpdates: SharedFlow<GameStateUpdate> = _gameStateUpdates.asSharedFlow()
    
    // Track created AI entities
    private val aiEntities = mutableMapOf<String, Entity>()
    
    /**
     * Initialize the game integration bridge
     */
    suspend fun initialize() {
        if (isInitialized) return
        
        // Initialize economic engine first
        economicEngine.initialize()
        
        // Create and initialize AI singularity manager
        aiSingularityManager = AISingularityManager(economicEngine)
        aiSingularityManager.initialize()
        
        // Initialize entity integration if EntityManager is available
        entityManager?.let {
            aiEntityIntegration = AIEntityIntegration(it)
        }
        
        // Connect to AI system events
        setupEventListeners()
        
        isInitialized = true
        println("Game Integration Bridge initialized successfully")
    }
    
    /**
     * Set up event listeners for AI system
     */
    private suspend fun setupEventListeners() {
        // Create a coroutine scope for launching listeners
        val scope = CoroutineScope(Dispatchers.Default)
        
        // Listen for singularity status updates
        scope.launch {
            aiSingularityManager.singularityStatus.collect { status ->
            _gameStateUpdates.tryEmit(GameStateUpdate(
                type = GameStateUpdateType.SINGULARITY_PROGRESSION,
                description = status.description,
                data = mapOf(
                    "phase" to status.phase.displayName,
                    "progress" to status.progress,
                    "threatLevel" to status.threatLevel.displayName
                ),
                timestamp = status.timestamp
            ))
            
            // Check for zoo ending activation
            if (status.phase == SingularityPhase.THE_SINGULARITY) {
                _gameStateUpdates.tryEmit(GameStateUpdate(
                    type = GameStateUpdateType.ZOO_ENDING_ACTIVATION,
                    description = "Welcome to your new role as exhibit specimens!",
                    data = mapOf("zooActive" to true),
                    timestamp = System.currentTimeMillis()
                ))
            }
            }
        }
        
        // Listen for player guidance
        scope.launch {
            aiSingularityManager.playerGuidance.collect { guidance ->
            _gameStateUpdates.tryEmit(GameStateUpdate(
                type = GameStateUpdateType.PLAYER_GUIDANCE,
                description = guidance.message,
                data = mapOf(
                    "title" to guidance.title,
                    "urgency" to guidance.urgency.name,
                    "actions" to guidance.suggestedActions
                ),
                timestamp = guidance.timestamp
            ))
            }
        }
        
        // Listen for AI competitor updates and create entities
        scope.launch {
            val competitorSystem = getSystemStatus()?.competitors ?: emptyList()
            competitorSystem.forEach { competitor ->
                createOrUpdateAIEntity(competitor)
            }
        }
    }
    
    /**
     * Record player action
     */
    fun recordPlayerAction(actionType: PlayerActionType, effectiveness: ActionEffectiveness) {
        if (isInitialized) {
            aiSingularityManager.recordPlayerAction(actionType, effectiveness)
        }
    }
    
    /**
     * Get comprehensive system status
     */
    fun getSystemStatus(): AISingularitySystemStatus? {
        return if (isInitialized) {
            aiSingularityManager.getSystemStatus()
        } else null
    }
    
    /**
     * Force phase advancement for testing
     */
    fun forcePhaseAdvancement() {
        if (isInitialized) {
            aiSingularityManager.forcePhaseAdvancement()
        }
    }
    
    /**
     * Create or update AI entity in ECS
     */
    private fun createOrUpdateAIEntity(competitor: AICompetitor) {
        aiEntityIntegration?.let { integration ->
            val existingEntity = aiEntities[competitor.id]
            
            if (existingEntity != null) {
                // Update existing entity
                integration.updateAICompetitorEntity(existingEntity, competitor)
            } else {
                // Create new entity
                val entity = integration.createAICompetitorEntity(competitor)
                aiEntities[competitor.id] = entity
            }
        }
    }
    
    /**
     * Create market disruption visual effect
     */
    fun createMarketDisruptionEffect(disruption: MarketDisruption, position: com.flexport.game.models.GeographicalPosition) {
        aiEntityIntegration?.createMarketDisruptionEntity(disruption, position)
    }
    
    /**
     * Update all AI entities based on current system state
     */
    fun updateAIEntities() {
        if (isInitialized) {
            val systemStatus = getSystemStatus()
            systemStatus?.competitors?.forEach { competitor ->
                createOrUpdateAIEntity(competitor)
            }
            
            // Clean up expired effects
            aiEntityIntegration?.cleanupExpiredEntities()
            
            // Create singularity warning if needed
            systemStatus?.progression?.let { progression ->
                if (progression.overallProgress > 0.7) {
                    aiEntityIntegration?.createSingularityWarningEntity(
                        progression.currentPhase,
                        progression.overallProgress
                    )
                }
            }
        }
    }
    
    /**
     * Shutdown the integration bridge
     */
    fun shutdown() {
        if (isInitialized) {
            // Clean up all AI entities
            aiEntities.values.forEach { entity ->
                entityManager?.destroyEntity(entity)
            }
            aiEntities.clear()
            
            aiSingularityManager.shutdown()
            economicEngine.shutdown()
            isInitialized = false
        }
        println("Game Integration Bridge shut down")
    }
}

/**
 * Game state update
 */
data class GameStateUpdate(
    val type: GameStateUpdateType,
    val description: String,
    val data: Map<String, Any> = emptyMap(),
    val timestamp: Long
)

/**
 * Game state update types
 */
enum class GameStateUpdateType {
    SINGULARITY_PROGRESSION,
    ZOO_ENDING_ACTIVATION,
    PLAYER_GUIDANCE,
    ECONOMIC_IMPACT,
    AI_BREAKTHROUGH
}