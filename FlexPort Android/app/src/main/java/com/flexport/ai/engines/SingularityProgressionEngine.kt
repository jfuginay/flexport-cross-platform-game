package com.flexport.ai.engines

import com.flexport.ai.models.*
import com.flexport.ai.systems.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import kotlin.math.*

/**
 * Simplified engine managing singularity progression
 */
class SingularityProgressionEngine {
    
    private val _progressState = MutableStateFlow(SingularityProgress())
    val progressState: StateFlow<SingularityProgress> = _progressState.asStateFlow()
    
    private val _progressionEvents = MutableSharedFlow<ProgressionEvent>()
    val progressionEvents: SharedFlow<ProgressionEvent> = _progressionEvents.asSharedFlow()
    
    private var progressionJob: Job? = null
    private var isRunning = false
    
    // Player action tracking
    private val playerActions = mutableListOf<PlayerAction>()
    
    /**
     * Initialize the progression engine
     */
    fun initialize() {
        if (isRunning) return
        
        startProgressionTracking()
        isRunning = true
        println("Singularity Progression Engine initialized")
    }
    
    /**
     * Start progression tracking
     */
    private fun startProgressionTracking() {
        progressionJob = CoroutineScope(Dispatchers.Default).launch {
            while (isRunning) {
                updateProgression()
                checkPhaseTransitions()
                delay(7000) // Update every 7 seconds
            }
        }
    }
    
    /**
     * Update progression state
     */
    private suspend fun updateProgression() {
        val currentState = _progressState.value
        
        // Calculate progression rate
        val baseRate = 0.001 // Base progression per update
        val acceleratedRate = baseRate * currentState.accelerationFactor
        val resistanceReduction = acceleratedRate * currentState.playerResistance * 0.5
        val effectiveRate = (acceleratedRate - resistanceReduction).coerceAtLeast(0.0)
        
        // Update phase progress
        val newPhaseProgress = (currentState.phaseProgress + effectiveRate * 10).coerceIn(0.0, 1.0)
        
        // Update overall progress
        val phaseWeight = 1.0 / SingularityPhase.values().size
        val overallProgressIncrease = effectiveRate * phaseWeight
        val newOverallProgress = (currentState.overallProgress + overallProgressIncrease).coerceIn(0.0, 1.0)
        
        val newState = currentState.copy(
            phaseProgress = newPhaseProgress,
            overallProgress = newOverallProgress
        )
        
        _progressState.value = newState
    }
    
    /**
     * Check for phase transitions
     */
    private suspend fun checkPhaseTransitions() {
        val currentState = _progressState.value
        
        if (currentState.phaseProgress >= 1.0) {
            val nextPhase = currentState.currentPhase.getNextPhase()
            if (nextPhase != null) {
                // Transition to next phase
                val newState = currentState.copy(
                    currentPhase = nextPhase,
                    phaseProgress = 0.0,
                    lastPhaseTransition = System.currentTimeMillis()
                )
                
                _progressState.value = newState
                
                // Emit phase transition event
                _progressionEvents.tryEmit(ProgressionEvent(
                    type = ProgressionEventType.PHASE_TRANSITION,
                    phase = nextPhase,
                    data = mapOf("description" to "Advanced to ${nextPhase.displayName}"),
                    timestamp = System.currentTimeMillis()
                ))
                
                println("AI Singularity phase transition: ${nextPhase.displayName}")
            }
        }
    }
    
    /**
     * Record player action
     */
    fun recordPlayerAction(action: PlayerAction) {
        playerActions.add(action)
        
        // Keep only last 20 actions
        if (playerActions.size > 20) {
            playerActions.removeFirst()
        }
        
        // Update player resistance based on recent actions
        updatePlayerResistance()
    }
    
    /**
     * Update player resistance based on actions
     */
    private fun updatePlayerResistance() {
        val currentState = _progressState.value
        
        // Calculate resistance based on recent player actions
        val recentActions = playerActions.takeLast(10)
        val resistanceActions = recentActions.count { action ->
            when (action.type) {
                PlayerActionType.RESIST_AI,
                PlayerActionType.INNOVATE_DEFENSE,
                PlayerActionType.HACK_AI_SYSTEM,
                PlayerActionType.SABOTAGE_AI_INFRASTRUCTURE,
                PlayerActionType.BUILD_FIREWALL,
                PlayerActionType.CREATE_AI_FREE_ZONE,
                PlayerActionType.DEVELOP_COUNTERMEASURES,
                PlayerActionType.IMPLEMENT_REGULATION,
                PlayerActionType.REGULATORY_ACTION -> true
                else -> false
            }
        }
        val collaborativeActions = recentActions.count { action ->
            when (action.type) {
                PlayerActionType.COLLABORATE_AI,
                PlayerActionType.ACCELERATE_AI,
                PlayerActionType.NEGOTIATE_WITH_AI,
                PlayerActionType.EMBRACE_AI_PARTNERSHIP -> true
                else -> false
            }
        }
        
        val netResistance = (resistanceActions - collaborativeActions).toDouble() / 10.0
        val newResistance = (netResistance * 0.5).coerceIn(0.0, 0.8) // Max 80% resistance
        
        val newState = currentState.copy(playerResistance = newResistance)
        _progressState.value = newState
    }
    
    /**
     * Get strongest AI (placeholder for interface compatibility)
     */
    fun getStrongestAI(): AICompetitor? {
        // This would typically come from the competitor system
        // For now, return a mock strongest AI
        return AICompetitor(
            type = AICompetitorType.CONSCIOUSNESS_SEEKER,
            name = "Prometheus AI",
            capabilities = mutableMapOf(
                AICapabilityType.CONSCIOUSNESS to AICapability(
                    type = AICapabilityType.CONSCIOUSNESS,
                    proficiency = 0.8
                )
            ),
            marketPresence = 0.7
        )
    }
    
    /**
     * Force phase advancement for testing
     */
    fun forcePhaseAdvancement() {
        val currentState = _progressState.value
        val newState = currentState.copy(phaseProgress = 1.0)
        _progressState.value = newState
    }
    
    /**
     * Shutdown the engine
     */
    fun shutdown() {
        isRunning = false
        progressionJob?.cancel()
        playerActions.clear()
        println("Singularity Progression Engine shut down")
    }
}

// ProgressionEvent is now imported from com.flexport.ai.models.*

