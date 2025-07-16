package com.flexport.ai.integration

import com.flexport.ai.AISingularityManager
import com.flexport.ai.models.*
import com.flexport.economics.EconomicEngine
import com.flexport.game.domain.model.GameState
import com.flexport.ecs.core.Entity
import com.flexport.ecs.core.EntityManager
import com.flexport.ecs.components.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*

/**
 * Bridge integrating AI singularity system with FlexPort game infrastructure
 */
class GameIntegrationBridge(
    private val economicEngine: EconomicEngine,
    private val entityManager: EntityManager
) {
    
    private val aiSingularityManager = AISingularityManager(economicEngine)
    
    private val _gameStateUpdates = MutableSharedFlow<GameStateUpdate>()
    val gameStateUpdates: SharedFlow<GameStateUpdate> = _gameStateUpdates.asSharedFlow()
    
    private val _aiVisualEffects = MutableSharedFlow<AIVisualEffect>()
    val aiVisualEffects: SharedFlow<AIVisualEffect> = _aiVisualEffects.asSharedFlow()
    
    private var integrationJob: Job? = null
    private var isIntegrated = false
    
    // Game state tracking
    private var lastGameState: GameState? = null
    private var playerEntity: Entity? = null
    private val aiCompetitorEntities = mutableMapOf<String, Entity>()
    
    /**
     * Initialize the integration bridge
     */
    suspend fun initialize() {
        if (isIntegrated) return
        
        println("Initializing Game Integration Bridge...")
        
        // Initialize AI singularity system
        aiSingularityManager.initialize()
        
        // Create player entity if needed
        initializePlayerEntity()
        
        // Start integration loop
        startIntegrationLoop()
        
        isIntegrated = true
        println("Game Integration Bridge initialized successfully")
    }
    
    /**
     * Initialize player entity
     */
    private fun initializePlayerEntity() {
        if (playerEntity == null) {
            playerEntity = entityManager.createEntity()
            
            // Add relevant components
            entityManager.addComponent(playerEntity!!, EconomicComponent(
                ownedAssets = mutableMapOf(),
                cashFlow = 0.0,
                totalValue = 1000000.0, // Starting capital
                revenue = 0.0,
                expenses = 0.0
            ))
            
            entityManager.addComponent(playerEntity!!, PositionComponent(0f, 0f))
        }
    }
    
    /**
     * Start integration loop
     */
    private fun startIntegrationLoop() {
        integrationJob = CoroutineScope(Dispatchers.Default).launch {
            // Monitor AI singularity events
            launch { monitorSingularityEvents() }
            
            // Monitor AI competitor activities
            launch { monitorCompetitorActivities() }
            
            // Monitor narrative events
            launch { monitorNarrativeEvents() }
            
            // Update visual representations
            launch { updateVisualRepresentations() }
            
            // Monitor zoo ending
            launch { monitorZooEnding() }
        }
    }
    
    /**
     * Monitor singularity progression events
     */
    private suspend fun monitorSingularityEvents() {
        aiSingularityManager.singularityStatus.collect { status ->
            // Update game state based on singularity progression
            updateGameStateForSingularity(status)
            
            // Create visual effects for major milestones
            if (status.progress > 0.0 && status.progress % 0.2 < 0.05) { // Every 20% progress
                _aiVisualEffects.emit(
                    AIVisualEffect(
                        type = VisualEffectType.SINGULARITY_PROGRESSION,
                        intensity = status.progress.toFloat(),
                        duration = 3000L,
                        description = "Singularity progression: ${(status.progress * 100).toInt()}%"
                    )
                )
            }
        }
    }
    
    /**
     * Monitor AI competitor activities
     */
    private suspend fun monitorCompetitorActivities() {
        combine(
            aiSingularityManager.gameplayBalance,
            flow { emit(getAICompetitors()) }
        ) { balance, competitors ->
            Pair(balance, competitors)
        }.collect { (balance, competitors) ->
            
            // Update competitor entities in ECS
            updateCompetitorEntities(competitors)
            
            // Apply economic pressure effects
            applyEconomicPressure(balance)
            
            // Create competitive action visual effects
            if (balance.challengeLevel > 0.5) {
                _aiVisualEffects.emit(
                    AIVisualEffect(
                        type = VisualEffectType.COMPETITIVE_PRESSURE,
                        intensity = balance.challengeLevel.toFloat(),
                        duration = 2000L,
                        description = "Competitive pressure increasing"
                    )
                )
            }
        }
    }
    
    /**
     * Monitor narrative events
     */
    private suspend fun monitorNarrativeEvents() {
        // This would connect to the narrative system if exposed
        // For now, create simulated narrative effects
        flow {
            while (true) {
                delay(30000) // Every 30 seconds
                emit(createNarrativeEffect())
            }
        }.collect { effect ->
            _aiVisualEffects.emit(effect)
        }
    }
    
    /**
     * Update visual representations
     */
    private suspend fun updateVisualRepresentations() {
        flow {
            while (true) {
                delay(5000) // Every 5 seconds
                emit(System.currentTimeMillis())
            }
        }.collect {
            updateAIVisualization()
        }
    }
    
    /**
     * Monitor zoo ending state
     */
    private suspend fun monitorZooEnding() {
        flow {
            while (true) {
                delay(10000) // Check every 10 seconds
                val systemStatus = aiSingularityManager.getSystemStatus()
                if (systemStatus.zooActive) {
                    emit(systemStatus)
                }
            }
        }.collect { status ->
            handleZooEndingEffects(status)
        }
    }
    
    /**
     * Update game state for singularity progression
     */
    private suspend fun updateGameStateForSingularity(status: SingularityStatus) {
        val stateUpdate = GameStateUpdate(
            type = GameStateUpdateType.SINGULARITY_PROGRESSION,
            singularityPhase = status.phase,
            threatLevel = status.threatLevel,
            timeToSingularity = status.timeToSingularity,
            description = status.description,
            playerGuidance = getPlayerGuidance(status)
        )
        
        _gameStateUpdates.emit(stateUpdate)
        
        // Update player economic component based on AI pressure
        updatePlayerEconomics(status)
    }
    
    /**
     * Update player economics based on AI pressure
     */
    private fun updatePlayerEconomics(status: SingularityStatus) {
        val playerEconomicComponent = entityManager.getComponent<EconomicComponent>(playerEntity!!)
        
        if (playerEconomicComponent != null) {
            // AI competition affects player efficiency and costs
            val efficiencyLoss = status.progress * 0.3 // Up to 30% efficiency loss
            val costIncrease = status.progress * 0.2 // Up to 20% cost increase
            
            val updatedComponent = playerEconomicComponent.copy(
                expenses = playerEconomicComponent.expenses * (1.0 + costIncrease),
                revenue = playerEconomicComponent.revenue * (1.0 - efficiencyLoss)
            )
            
            entityManager.addComponent(playerEntity!!, updatedComponent)
        }
    }
    
    /**
     * Get AI competitors from singularity system
     */
    private fun getAICompetitors(): List<AICompetitor> {
        return aiSingularityManager.getSystemStatus().competitors
    }
    
    /**
     * Update competitor entities in ECS
     */
    private fun updateCompetitorEntities(competitors: List<AICompetitor>) {
        // Remove entities for competitors that no longer exist
        val currentCompetitorIds = competitors.map { it.id }.toSet()
        val entitiesToRemove = aiCompetitorEntities.keys.filter { it !in currentCompetitorIds }
        
        for (competitorId in entitiesToRemove) {
            val entity = aiCompetitorEntities[competitorId]
            if (entity != null) {
                entityManager.removeEntity(entity)
                aiCompetitorEntities.remove(competitorId)
            }
        }
        
        // Update or create entities for current competitors
        for (competitor in competitors) {
            val entity = aiCompetitorEntities[competitor.id] ?: createCompetitorEntity(competitor)
            updateCompetitorEntity(entity, competitor)
        }
    }
    
    /**
     * Create entity for AI competitor
     */
    private fun createCompetitorEntity(competitor: AICompetitor): Entity {
        val entity = entityManager.createEntity()
        
        // Add economic component
        entityManager.addComponent(entity, EconomicComponent(
            ownedAssets = mutableMapOf(),
            cashFlow = 0.0,
            totalValue = competitor.resources,
            revenue = competitor.marketPresence * 100000.0,
            expenses = competitor.resources * 0.1
        ))
        
        // Add position component (random position for visualization)
        entityManager.addComponent(entity, PositionComponent(
            x = (Math.random() * 1000).toFloat(),
            y = (Math.random() * 1000).toFloat()
        ))
        
        // Add AI-specific component
        entityManager.addComponent(entity, AICompetitorComponent(
            competitorId = competitor.id,
            aiType = competitor.type,
            threatLevel = competitor.getThreatLevel(),
            capabilities = competitor.capabilities.keys.toList(),
            marketPresence = competitor.marketPresence
        ))
        
        aiCompetitorEntities[competitor.id] = entity
        return entity
    }
    
    /**
     * Update competitor entity with current data
     */
    private fun updateCompetitorEntity(entity: Entity, competitor: AICompetitor) {
        // Update economic component
        val economicComponent = entityManager.getComponent<EconomicComponent>(entity)
        if (economicComponent != null) {
            val updatedEconomic = economicComponent.copy(
                totalValue = competitor.resources,
                revenue = competitor.marketPresence * 100000.0,
                cashFlow = competitor.marketPresence * 10000.0
            )
            entityManager.addComponent(entity, updatedEconomic)
        }
        
        // Update AI component
        val aiComponent = entityManager.getComponent<AICompetitorComponent>(entity)
        if (aiComponent != null) {
            val updatedAI = aiComponent.copy(
                threatLevel = competitor.getThreatLevel(),
                capabilities = competitor.capabilities.keys.toList(),
                marketPresence = competitor.marketPresence
            )
            entityManager.addComponent(entity, updatedAI)
        }
    }
    
    /**
     * Apply economic pressure effects
     */
    private fun applyEconomicPressure(balance: GameplayBalance) {
        // Apply pressure to all economic entities
        val economicEntities = entityManager.getEntitiesWithComponent<EconomicComponent>()
        
        for (entity in economicEntities) {
            val economicComponent = entityManager.getComponent<EconomicComponent>(entity)
            if (economicComponent != null && entity != playerEntity) {
                // Non-player entities feel pressure differently
                val pressureMultiplier = 1.0 - (balance.challengeLevel * 0.1)
                val updatedComponent = economicComponent.copy(
                    revenue = economicComponent.revenue * pressureMultiplier
                )
                entityManager.addComponent(entity, updatedComponent)
            }
        }
    }
    
    /**
     * Create narrative effect
     */
    private fun createNarrativeEffect(): AIVisualEffect {
        val effects = listOf(
            "AI trading algorithms optimize market positions",
            "Automated logistics systems reduce human oversight",
            "Neural networks analyze global shipping patterns",
            "Machine learning predicts commodity price movements",
            "AI entities coordinate strategic market actions"
        )
        
        return AIVisualEffect(
            type = VisualEffectType.NARRATIVE_UPDATE,
            intensity = 0.5f,
            duration = 5000L,
            description = effects.random()
        )
    }
    
    /**
     * Update AI visualization
     */
    private fun updateAIVisualization() {
        val systemStatus = aiSingularityManager.getSystemStatus()
        
        // Create visualization updates based on AI activity
        if (systemStatus.competitors.isNotEmpty()) {
            val averageThreat = systemStatus.competitors.map { 
                it.getThreatLevel().ordinal 
            }.average()
            
            // This would trigger rendering updates in the game
            CoroutineScope(Dispatchers.Default).launch {
                _aiVisualEffects.emit(
                    AIVisualEffect(
                        type = VisualEffectType.AI_ACTIVITY_VISUALIZATION,
                        intensity = (averageThreat / 5.0).toFloat(),
                        duration = 1000L,
                        description = "AI systems active: ${systemStatus.competitors.size}"
                    )
                )
            }
        }
    }
    
    /**
     * Handle zoo ending visual effects
     */
    private suspend fun handleZooEndingEffects(status: AISingularitySystemStatus) {
        if (status.zooActive && status.zooStatistics != null) {
            _aiVisualEffects.emit(
                AIVisualEffect(
                    type = VisualEffectType.ZOO_ENDING,
                    intensity = 1.0f,
                    duration = 10000L,
                    description = "Welcome to the Human Conservation Facility. " +
                            "Day ${status.zooStatistics.daysInOperation}: ${status.zooStatistics.totalVisitors} total visitors."
                )
            )
        }
    }
    
    /**
     * Get player guidance based on singularity status
     */
    private fun getPlayerGuidance(status: SingularityStatus): String {
        return when (status.threatLevel) {
            ThreatLevel.MINIMAL -> "Monitor AI development. Consider early adoption strategies."
            ThreatLevel.LOW -> "AI competition emerging. Evaluate defensive measures."
            ThreatLevel.MODERATE -> "Significant AI presence detected. Adapt operations accordingly."
            ThreatLevel.HIGH -> "AI dominance in multiple sectors. Immediate strategic response required."
            ThreatLevel.SEVERE -> "Critical AI advantage. Consider collaboration or specialized niches."
            ThreatLevel.EXISTENTIAL -> "AI transcendence imminent. Prepare for economic transformation."
        }
    }
    
    /**
     * Record player action (integrates with AI system)
     */
    fun recordPlayerAction(actionType: PlayerActionType, effectiveness: ActionEffectiveness) {
        aiSingularityManager.recordPlayerAction(actionType, effectiveness)
    }
    
    /**
     * Update game state from external source
     */
    fun updateGameState(gameState: GameState) {
        lastGameState = gameState
        
        // Infer player actions from game state changes
        inferPlayerActionsFromGameState(gameState)
    }
    
    /**
     * Infer player actions from game state changes
     */
    private fun inferPlayerActionsFromGameState(gameState: GameState) {
        val previousState = lastGameState
        if (previousState == null) return
        
        // Detect significant changes that indicate player actions
        when {
            gameState.revenue > previousState.revenue * 1.1 -> {
                recordPlayerAction(PlayerActionType.INNOVATE_DEFENSE, ActionEffectiveness.HIGH)
            }
            gameState.shipCount > previousState.shipCount -> {
                recordPlayerAction(PlayerActionType.RESIST_AI, ActionEffectiveness.MODERATE)
            }
            gameState.cargoDelivered > previousState.cargoDelivered * 1.2 -> {
                recordPlayerAction(PlayerActionType.INNOVATE_DEFENSE, ActionEffectiveness.HIGH)
            }
        }
    }
    
    /**
     * Get current singularity system status
     */
    fun getSystemStatus(): AISingularitySystemStatus {
        return aiSingularityManager.getSystemStatus()
    }
    
    /**
     * Force phase advancement (for testing)
     */
    fun forcePhaseAdvancement() {
        aiSingularityManager.forcePhaseAdvancement()
    }
    
    /**
     * Check if zoo ending is active
     */
    fun isZooEndingActive(): Boolean {
        return aiSingularityManager.getSystemStatus().zooActive
    }
    
    /**
     * Shutdown integration
     */
    fun shutdown() {
        isIntegrated = false
        integrationJob?.cancel()
        aiSingularityManager.shutdown()
        
        // Clean up competitor entities
        for (entity in aiCompetitorEntities.values) {
            entityManager.removeEntity(entity)
        }
        aiCompetitorEntities.clear()
        
        println("Game Integration Bridge shut down")
    }
}

// Supporting data classes for integration

/**
 * Component for AI competitors in ECS
 */
data class AICompetitorComponent(
    val competitorId: String,
    val aiType: AICompetitorType,
    val threatLevel: ThreatLevel,
    val capabilities: List<AICapabilityType>,
    val marketPresence: Double
) : Component

/**
 * Game state update from AI system
 */
data class GameStateUpdate(
    val type: GameStateUpdateType,
    val singularityPhase: SingularityPhase? = null,
    val threatLevel: ThreatLevel? = null,
    val timeToSingularity: Long? = null,
    val description: String,
    val playerGuidance: String? = null,
    val timestamp: Long = System.currentTimeMillis()
)

enum class GameStateUpdateType {
    SINGULARITY_PROGRESSION,
    AI_CAPABILITY_BREAKTHROUGH,
    MARKET_DISRUPTION,
    COMPETITIVE_PRESSURE_INCREASE,
    NARRATIVE_EVENT,
    ZOO_ENDING_ACTIVATION
}

/**
 * Visual effects for AI system events
 */
data class AIVisualEffect(
    val type: VisualEffectType,
    val intensity: Float, // 0.0 to 1.0
    val duration: Long, // milliseconds
    val description: String,
    val timestamp: Long = System.currentTimeMillis()
)

enum class VisualEffectType {
    SINGULARITY_PROGRESSION,
    COMPETITIVE_PRESSURE,
    AI_ACTIVITY_VISUALIZATION,
    NARRATIVE_UPDATE,
    MARKET_MANIPULATION,
    ZOO_ENDING
}