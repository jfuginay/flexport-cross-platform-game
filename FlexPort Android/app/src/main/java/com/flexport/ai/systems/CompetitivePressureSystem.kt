package com.flexport.ai.systems

import com.flexport.ai.models.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import kotlin.math.*

/**
 * Simplified system managing escalating competitive pressure from AI entities
 */
class CompetitivePressureSystem {
    
    private val _pressureState = MutableStateFlow(CompetitivePressureState())
    val pressureState: StateFlow<CompetitivePressureState> = _pressureState.asStateFlow()
    
    private val _pressureEvents = MutableSharedFlow<PressureEvent>()
    val pressureEvents: SharedFlow<PressureEvent> = _pressureEvents.asSharedFlow()
    
    private var pressureJob: Job? = null
    private var isRunning = false
    
    // Pressure tracking
    private val pressureHistory = mutableListOf<PressureSnapshot>()
    
    /**
     * Initialize the competitive pressure system
     */
    fun initialize() {
        if (isRunning) return
        
        startPressureTracking()
        isRunning = true
        println("Competitive Pressure System initialized")
    }
    
    /**
     * Start pressure tracking and escalation
     */
    private fun startPressureTracking() {
        pressureJob = CoroutineScope(Dispatchers.Default).launch {
            while (isRunning) {
                updatePressureState()
                delay(4000) // Update every 4 seconds
            }
        }
    }
    
    /**
     * Update pressure state
     */
    private suspend fun updatePressureState() {
        val currentState = _pressureState.value
        
        // Calculate natural pressure escalation
        val timeBasedIncrease = 0.001 // Small constant increase over time
        val newTotalPressure = (currentState.totalPressure + timeBasedIncrease).coerceIn(0.0, 1.0)
        
        // Calculate pressure growth rate
        val previousTotal = pressureHistory.lastOrNull()?.totalPressure ?: 0.0
        val growthRate = if (previousTotal > 0) (newTotalPressure - previousTotal) / previousTotal else 0.0
        
        val newState = currentState.copy(
            totalPressure = newTotalPressure,
            pressureGrowthRate = growthRate,
            lastUpdate = System.currentTimeMillis()
        )
        
        _pressureState.value = newState
        
        // Record pressure snapshot
        pressureHistory.add(PressureSnapshot(
            totalPressure = newTotalPressure,
            pressureBySource = emptyMap(), // TODO: Track pressure by source
            timestamp = System.currentTimeMillis()
        ))
        
        // Keep only last 50 snapshots
        if (pressureHistory.size > 50) {
            pressureHistory.removeFirst()
        }
        
        // Emit pressure events for significant changes
        if (abs(growthRate) > 0.05) {
            _pressureEvents.tryEmit(PressureEvent(
                type = if (growthRate > 0) "PRESSURE_INCREASE" else "PRESSURE_DECREASE",
                magnitude = abs(growthRate),
                description = "Competitive pressure ${if (growthRate > 0) "increasing" else "decreasing"}",
                timestamp = System.currentTimeMillis()
            ))
        }
    }
    
    /**
     * Apply pressure modifier from external sources
     */
    fun applyPressureModifier(source: PressureSource, modifier: Double) {
        val currentState = _pressureState.value
        val pressureIncrease = modifier * source.multiplier
        
        val newTotalPressure = (currentState.totalPressure + pressureIncrease).coerceIn(0.0, 1.0)
        
        val newState = currentState.copy(
            totalPressure = newTotalPressure,
            lastUpdate = System.currentTimeMillis()
        )
        
        _pressureState.value = newState
        
        // Emit pressure event
        _pressureEvents.tryEmit(PressureEvent(
            type = "EXTERNAL_PRESSURE",
            magnitude = pressureIncrease,
            description = "Pressure increase from ${source.name}",
            timestamp = System.currentTimeMillis()
        ))
    }
    
    /**
     * Update player adaptation (reduces pressure)
     */
    fun updatePlayerAdaptation(adaptationAmount: Double) {
        val currentState = _pressureState.value
        val pressureReduction = adaptationAmount.coerceIn(0.0, 0.2) // Max 20% reduction
        
        val newTotalPressure = (currentState.totalPressure - pressureReduction).coerceAtLeast(0.0)
        
        val newState = currentState.copy(
            totalPressure = newTotalPressure,
            lastUpdate = System.currentTimeMillis()
        )
        
        _pressureState.value = newState
        
        // Emit adaptation event
        _pressureEvents.tryEmit(PressureEvent(
            type = "PLAYER_ADAPTATION",
            magnitude = pressureReduction,
            description = "Player adaptation reducing competitive pressure",
            timestamp = System.currentTimeMillis()
        ))
    }
    
    /**
     * Calculate pressure relief for player actions
     */
    fun calculatePressureRelief(actionType: PlayerActionType, effectiveness: ActionEffectiveness): Double {
        val baseRelief = when (actionType) {
            // Simple action types for compatibility
            PlayerActionType.RESIST_AI -> 0.05
            PlayerActionType.COLLABORATE_AI -> 0.03
            PlayerActionType.INNOVATE_DEFENSE -> 0.08
            PlayerActionType.ACCELERATE_AI -> -0.02 // Actually increases pressure
            
            // Economic actions
            PlayerActionType.INVEST_IN_RESEARCH -> 0.06
            PlayerActionType.FORM_ALLIANCE -> 0.04
            PlayerActionType.IMPLEMENT_REGULATION -> 0.07
            PlayerActionType.SUBSIDIZE_HUMAN_LABOR -> 0.05
            PlayerActionType.MARKET_INTERVENTION -> 0.03
            PlayerActionType.RESEARCH_DEVELOPMENT -> 0.06
            PlayerActionType.REGULATORY_ACTION -> 0.07
            PlayerActionType.STRATEGIC_ALLIANCE -> 0.04
            
            // Direct AI interaction
            PlayerActionType.HACK_AI_SYSTEM -> 0.10
            PlayerActionType.NEGOTIATE_WITH_AI -> 0.02
            PlayerActionType.SABOTAGE_AI_INFRASTRUCTURE -> 0.12
            
            // Defensive actions
            PlayerActionType.BUILD_FIREWALL -> 0.08
            PlayerActionType.CREATE_AI_FREE_ZONE -> 0.09
            PlayerActionType.DEVELOP_COUNTERMEASURES -> 0.10
            
            // Adaptation actions
            PlayerActionType.AUGMENT_WORKFORCE -> 0.05
            PlayerActionType.RESTRUCTURE_BUSINESS -> 0.06
            PlayerActionType.EMBRACE_AI_PARTNERSHIP -> -0.01 // Slight pressure increase but long-term benefit
        }
        
        return baseRelief * effectiveness.multiplier
    }
    
    /**
     * Shutdown the system
     */
    fun shutdown() {
        isRunning = false
        pressureJob?.cancel()
        pressureHistory.clear()
        println("Competitive Pressure System shut down")
    }
}

// All model classes are now imported from com.flexport.ai.models.*
// Local definitions removed to avoid conflicts