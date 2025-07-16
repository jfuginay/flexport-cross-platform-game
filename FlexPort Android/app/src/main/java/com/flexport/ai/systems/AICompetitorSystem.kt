package com.flexport.ai.systems

import com.flexport.ai.models.*
import com.flexport.economics.EconomicEngine
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import kotlin.random.Random

/**
 * Simplified system managing AI competitors and their evolution
 */
class AICompetitorSystem(
    private val economicEngine: EconomicEngine
) {
    
    private val _competitors = MutableStateFlow<Map<String, AICompetitor>>(emptyMap())
    val competitors: StateFlow<Map<String, AICompetitor>> = _competitors.asStateFlow()
    
    private val _marketManipulations = MutableSharedFlow<MarketManipulation>()
    val marketManipulations: SharedFlow<MarketManipulation> = _marketManipulations.asSharedFlow()
    
    private val _competitorEvents = MutableSharedFlow<CompetitorEvent>()
    val competitorEvents: SharedFlow<CompetitorEvent> = _competitorEvents.asSharedFlow()
    
    private var competitorJob: Job? = null
    private var isRunning = false
    
    /**
     * Initialize the AI competitor system
     */
    fun initialize() {
        if (isRunning) return
        
        // Create initial AI competitors
        createInitialCompetitors()
        
        startCompetitorManagement()
        isRunning = true
        println("AI Competitor System initialized")
    }
    
    /**
     * Create initial AI competitors
     */
    private fun createInitialCompetitors() {
        val initialCompetitors = mutableMapOf<String, AICompetitor>()
        
        // Create one of each competitor type
        AICompetitorType.values().forEach { type ->
            val competitor = AICompetitor(
                type = type,
                capabilities = mutableMapOf(
                    // Start with basic automation capability
                    AICapabilityType.BASIC_AUTOMATION to AICapabilityTree.getBaseCapability(AICapabilityType.BASIC_AUTOMATION).copy(proficiency = 0.3)
                )
            )
            initialCompetitors[competitor.id] = competitor
        }
        
        _competitors.value = initialCompetitors
    }
    
    /**
     * Start competitor management and evolution
     */
    private fun startCompetitorManagement() {
        competitorJob = CoroutineScope(Dispatchers.Default).launch {
            while (isRunning) {
                evolveCompetitors()
                performMarketActions()
                delay(6000) // Update every 6 seconds
            }
        }
    }
    
    /**
     * Evolve AI competitors over time
     */
    private suspend fun evolveCompetitors() {
        val currentCompetitors = _competitors.value
        val updatedCompetitors = mutableMapOf<String, AICompetitor>()
        
        currentCompetitors.forEach { (id, competitor) ->
            var evolvedCompetitor = competitor
            
            // AI learns and improves capabilities
            if (Random.nextFloat() < 0.3) { // 30% chance to learn each update
                val learningCapability = selectLearningCapability(competitor)
                if (learningCapability != null) {
                    evolvedCompetitor = competitor.learnCapability(learningCapability, Random.nextDouble(0.5, 2.0))
                    
                    // Emit learning event
                    _competitorEvents.tryEmit(CompetitorEvent(
                        competitorId = id,
                        type = "CAPABILITY_LEARNED",
                        description = "${competitor.name} improved ${learningCapability.name}",
                        timestamp = System.currentTimeMillis()
                    ))
                }
            }
            
            // Gain experience
            evolvedCompetitor = evolvedCompetitor.gainExperience(Random.nextDouble(0.1, 0.5), "market_activity")
            
            // Update market presence based on capabilities
            val presenceChange = (evolvedCompetitor.getTotalPower() - competitor.getTotalPower()) * 0.01
            evolvedCompetitor = evolvedCompetitor.updateMarketPresence(presenceChange)
            
            updatedCompetitors[id] = evolvedCompetitor
        }
        
        _competitors.value = updatedCompetitors
    }
    
    /**
     * Select next capability for AI to learn
     */
    private fun selectLearningCapability(competitor: AICompetitor): AICapabilityType? {
        // Focus on specializations first
        val unlearned = competitor.type.specialization.filter { 
            (competitor.capabilities[it]?.proficiency ?: 0.0) < 0.8 
        }
        
        if (unlearned.isNotEmpty()) {
            return unlearned.random()
        }
        
        // Then learn any other available capability
        val allCapabilities = AICapabilityType.values().filter { capability ->
            val current = competitor.capabilities[capability]?.proficiency ?: 0.0
            current < 0.9 && AICapabilityTree.getBaseCapability(capability).canBeLearnedWith(competitor.capabilities)
        }
        
        return allCapabilities.randomOrNull()
    }
    
    /**
     * Perform market actions by AI competitors
     */
    private suspend fun performMarketActions() {
        val currentCompetitors = _competitors.value
        
        currentCompetitors.values.forEach { competitor ->
            // AI with market manipulation capability might manipulate markets
            val marketCap = competitor.capabilities[AICapabilityType.MARKET_MANIPULATION]
            if (marketCap != null && marketCap.proficiency > 0.5 && Random.nextFloat() < 0.2) {
                performMarketManipulation(competitor)
            }
            
            // AI with predictive analytics might make market predictions
            val predictiveCap = competitor.capabilities[AICapabilityType.PREDICTIVE_ANALYTICS]
            if (predictiveCap != null && predictiveCap.proficiency > 0.5 && Random.nextFloat() < 0.15) {
                performMarketPrediction(competitor)
            }
        }
    }
    
    /**
     * AI performs market manipulation
     */
    private suspend fun performMarketManipulation(competitor: AICompetitor) {
        val commodities = listOf("Oil", "Steel", "Electronics", "Food", "Textiles")
        val targetCommodity = commodities.random()
        val manipulationType = listOf("PUMP", "DUMP", "STABILIZE").random()
        
        val manipulation = MarketManipulation(
            aiId = competitor.id,
            aiName = competitor.name,
            targetCommodity = targetCommodity,
            manipulationType = manipulationType,
            power = competitor.capabilities[AICapabilityType.MARKET_MANIPULATION]?.proficiency ?: 0.5,
            timestamp = System.currentTimeMillis()
        )
        
        _marketManipulations.tryEmit(manipulation)
        
        // Emit competitor event
        _competitorEvents.tryEmit(CompetitorEvent(
            competitorId = competitor.id,
            type = "MARKET_MANIPULATION",
            description = "${competitor.name} is performing ${manipulationType} manipulation on $targetCommodity",
            timestamp = System.currentTimeMillis()
        ))
    }
    
    /**
     * AI performs market prediction
     */
    private suspend fun performMarketPrediction(competitor: AICompetitor) {
        _competitorEvents.tryEmit(CompetitorEvent(
            competitorId = competitor.id,
            type = "MARKET_PREDICTION",
            description = "${competitor.name} is analyzing market trends with advanced predictive analytics",
            timestamp = System.currentTimeMillis()
        ))
    }
    
    /**
     * Get the strongest AI competitor
     */
    fun getStrongestAI(): AICompetitor? {
        return _competitors.value.values.maxByOrNull { it.getTotalPower() }
    }
    
    /**
     * Shutdown the system
     */
    fun shutdown() {
        isRunning = false
        competitorJob?.cancel()
        println("AI Competitor System shut down")
    }
}

/**
 * Market manipulation event
 */
data class MarketManipulation(
    val aiId: String,
    val aiName: String,
    val targetCommodity: String,
    val manipulationType: String,
    val power: Double,
    val timestamp: Long
)

/**
 * Competitor event
 */
data class CompetitorEvent(
    val competitorId: String,
    val type: String,
    val description: String,
    val timestamp: Long
)