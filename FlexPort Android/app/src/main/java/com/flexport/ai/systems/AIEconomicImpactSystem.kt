package com.flexport.ai.systems

import com.flexport.ai.models.*
import com.flexport.economics.EconomicEngine
import com.flexport.economics.EconomicImpact
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import kotlin.math.*

/**
 * Simplified system managing economic impact of AI advancement on markets
 */
class AIEconomicImpactSystem(
    private val economicEngine: EconomicEngine
) {
    
    private val _economicImpact = MutableStateFlow(AIEconomicImpactState())
    val economicImpact: StateFlow<AIEconomicImpactState> = _economicImpact.asStateFlow()
    
    private val _marketDisruptions = MutableSharedFlow<MarketDisruption>()
    val marketDisruptions: SharedFlow<MarketDisruption> = _marketDisruptions.asSharedFlow()
    
    private var impactJob: Job? = null
    private var isRunning = false
    
    // Market impact tracking
    private val aiMarketInfluence = mutableMapOf<String, Double>()
    
    /**
     * Initialize the AI economic impact system
     */
    fun initialize() {
        if (isRunning) return
        
        startImpactTracking()
        isRunning = true
        println("AI Economic Impact System initialized")
    }
    
    /**
     * Start tracking economic impacts
     */
    private fun startImpactTracking() {
        impactJob = CoroutineScope(Dispatchers.Default).launch {
            while (isRunning) {
                analyzeMarketImpacts()
                delay(5000) // Update every 5 seconds
            }
        }
    }
    
    /**
     * Analyze AI impacts on markets
     */
    private suspend fun analyzeMarketImpacts() {
        val currentImpact = _economicImpact.value
        
        // Calculate overall economic shift based on AI influence
        val totalInfluence = aiMarketInfluence.values.sum()
        val economicShift = (totalInfluence / 10.0).coerceIn(0.0, 1.0)
        
        val newState = currentImpact.copy(
            overallEconomicShift = economicShift,
            lastUpdate = System.currentTimeMillis()
        )
        
        _economicImpact.value = newState
    }
    
    /**
     * Apply AI market modifier
     */
    fun applyAIMarketModifier(commodity: String, modifier: AIMarketModifier) {
        // Update AI influence for this commodity
        val currentInfluence = aiMarketInfluence[commodity] ?: 0.0
        val newInfluence = (currentInfluence + modifier.magnitude * 0.1).coerceIn(0.0, 10.0)
        aiMarketInfluence[commodity] = newInfluence
        
        // Apply economic impact to the engine
        val impact = EconomicImpact(
            gdpChange = modifier.magnitude * 0.001,
            inflationChange = if (modifier.type == ModifierType.PRICE_MANIPULATION) modifier.magnitude * 0.1 else 0.0,
            confidenceChange = -modifier.magnitude * 5.0,
            description = "AI market manipulation in $commodity",
            severity = when {
                modifier.magnitude > 0.8 -> "HIGH"
                modifier.magnitude > 0.5 -> "MEDIUM"
                else -> "LOW"
            }
        )
        
        economicEngine.applyEconomicImpact(impact)
        
        // Emit market disruption event
        if (modifier.magnitude > 0.5) {
            _marketDisruptions.tryEmit(MarketDisruption(
                market = commodity,
                severity = if (modifier.magnitude > 0.8) DisruptionLevel.HIGH else DisruptionLevel.MODERATE,
                impact = modifier.magnitude,
                description = "AI systems manipulating $commodity market",
                timestamp = System.currentTimeMillis()
            ))
        }
    }
    
    /**
     * Get market impact summary
     */
    fun getMarketImpactSummary(): MarketImpactSummary {
        val state = _economicImpact.value
        val totalInfluence = aiMarketInfluence.values.sum()
        val averageVolatility = if (aiMarketInfluence.isNotEmpty()) {
            aiMarketInfluence.values.average() / 5.0 // Normalize volatility
        } else {
            0.0
        }
        
        return MarketImpactSummary(
            overallEconomicShift = state.overallEconomicShift,
            affectedMarkets = aiMarketInfluence.size,
            averageVolatility = averageVolatility,
            timestamp = System.currentTimeMillis()
        )
    }
    
    /**
     * Shutdown the system
     */
    fun shutdown() {
        isRunning = false
        impactJob?.cancel()
        aiMarketInfluence.clear()
        println("AI Economic Impact System shut down")
    }
}

