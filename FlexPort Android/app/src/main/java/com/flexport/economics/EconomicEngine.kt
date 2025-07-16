package com.flexport.economics

import com.flexport.ai.models.EconomicState
import com.flexport.ai.models.MarketUpdate
import com.flexport.ai.models.EconomicEventNotification
import com.flexport.ai.models.EconomicEventType
import com.flexport.ai.models.EconomicEventSeverity
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow

/**
 * Simplified Economic Engine for FlexPort Android Game
 * Provides basic economic functionality for AI system integration
 */
class EconomicEngine {
    
    // Basic economic state
    private val _economicState = MutableStateFlow(EconomicState())
    val economicState: StateFlow<EconomicState> = _economicState
    
    private val _marketUpdates = MutableSharedFlow<MarketUpdate>()
    val marketUpdates: SharedFlow<MarketUpdate> = _marketUpdates
    
    private val _economicEvents = MutableSharedFlow<EconomicEventNotification>()
    val economicEvents: SharedFlow<EconomicEventNotification> = _economicEvents
    
    private var isInitialized = false
    
    /**
     * Initialize the economic engine
     */
    fun initialize() {
        if (isInitialized) return
        
        // Initialize basic economic state
        _economicState.value = EconomicState(
            totalMarketValue = 1000000.0,
            marketVolatility = 0.1,
            unemploymentRate = 0.05,
            inflationRate = 0.025
        )
        
        isInitialized = true
        println("Economic Engine initialized successfully")
    }
    
    /**
     * Get current market volatility
     */
    fun getMarketVolatility(): Double {
        return _economicState.value.marketVolatility
    }
    
    /**
     * Update market conditions (for AI manipulation)
     */
    fun updateMarketConditions(marketId: String, priceChange: Double, volumeChange: Double) {
        // Emit market update
        _marketUpdates.tryEmit(MarketUpdate(
            marketId = marketId,
            priceChange = priceChange,
            volumeChange = volumeChange,
            timestamp = System.currentTimeMillis()
        ))
    }
    
    /**
     * Apply economic impact from AI actions
     */
    fun applyEconomicImpact(impact: EconomicImpact) {
        val currentState = _economicState.value
        
        val newState = currentState.copy(
            totalMarketValue = (currentState.totalMarketValue * (1.0 + impact.gdpChange)).coerceAtLeast(0.0),
            inflationRate = (currentState.inflationRate + impact.inflationChange).coerceIn(-0.1, 0.5),
            unemploymentRate = (currentState.unemploymentRate + impact.unemploymentChange).coerceIn(0.0, 1.0),
            marketVolatility = (currentState.marketVolatility + impact.confidenceChange).coerceIn(0.0, 1.0)
        )
        
        _economicState.value = newState
        
        // Emit economic event
        _economicEvents.tryEmit(EconomicEventNotification(
            eventType = EconomicEventType.AI_AUTOMATION_WAVE,
            severity = when (impact.severity) {
                "LOW" -> EconomicEventSeverity.LOW
                "MEDIUM" -> EconomicEventSeverity.MEDIUM
                "HIGH" -> EconomicEventSeverity.HIGH
                "CRITICAL" -> EconomicEventSeverity.CRITICAL
                else -> EconomicEventSeverity.LOW
            },
            description = impact.description,
            impact = impact.gdpChange,
            timestamp = System.currentTimeMillis()
        ))
    }
    
    /**
     * Get market summary for display
     */
    fun getMarketSummary(): MarketSummary {
        val state = _economicState.value
        return MarketSummary(
            totalMarketValue = state.totalMarketValue,
            inflationRate = state.inflationRate,
            unemploymentRate = state.unemploymentRate,
            marketVolatility = state.marketVolatility
        )
    }
    
    /**
     * Shutdown the economic engine
     */
    fun shutdown() {
        isInitialized = false
        println("Economic Engine shut down")
    }
}

/**
 * Economic impact from AI actions
 */
data class EconomicImpact(
    val gdpChange: Double = 0.0,       // Percentage change (-1.0 to 1.0)
    val inflationChange: Double = 0.0,  // Percentage point change
    val unemploymentChange: Double = 0.0, // Percentage point change
    val confidenceChange: Double = 0.0,   // Percentage point change
    val description: String,
    val severity: String = "LOW"
)

/**
 * Market summary for display
 */
data class MarketSummary(
    val totalMarketValue: Double,
    val inflationRate: Double,
    val unemploymentRate: Double,
    val marketVolatility: Double
)