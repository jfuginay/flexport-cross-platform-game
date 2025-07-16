package com.flexport.ai.engines

import com.flexport.ai.models.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import kotlin.math.*
import kotlin.random.Random

/**
 * Core engine managing AI singularity progression
 */
class SingularityProgressionEngine {
    
    private val _progressState = MutableStateFlow(
        SingularityProgress()
    )
    val progressState: StateFlow<SingularityProgress> = _progressState.asStateFlow()
    
    private val _aiCompetitors = MutableStateFlow<List<AICompetitor>>(emptyList())
    val aiCompetitors: StateFlow<List<AICompetitor>> = _aiCompetitors.asStateFlow()
    
    private val _progressionEvents = MutableSharedFlow<ProgressionEvent>()
    val progressionEvents: SharedFlow<ProgressionEvent> = _progressionEvents.asSharedFlow()
    
    private val _phaseTransitions = MutableSharedFlow<PhaseTransition>()
    val phaseTransitions: SharedFlow<PhaseTransition> = _phaseTransitions.asSharedFlow()
    
    private var progressionJob: Job? = null
    private var isRunning = false
    
    // Configuration
    private var baseProgressionRate = 0.001 // Progress per second
    private var playerActionImpact = MutableStateFlow(0.0)
    private var economicFeedbackMultiplier = 1.0
    
    /**
     * Initialize the singularity progression system
     */
    fun initialize() {
        if (isRunning) return
        
        // Create initial AI competitors
        initializeAICompetitors()
        
        // Start progression loop
        startProgressionLoop()
        
        isRunning = true
        println("Singularity Progression Engine initialized")
    }
    
    /**
     * Create initial AI competitors
     */
    private fun initializeAICompetitors() {
        val initialAIs = listOf(
            createAICompetitor(AICompetitorType.LOGISTICS_OPTIMIZER),
            createAICompetitor(AICompetitorType.MARKET_ANALYST),
            createAICompetitor(AICompetitorType.STRATEGIC_PLANNER)
        )
        
        _aiCompetitors.value = initialAIs
    }
    
    /**
     * Create a new AI competitor
     */
    private fun createAICompetitor(type: AICompetitorType): AICompetitor {
        val ai = AICompetitor(type = type)
        
        // Initialize with basic capabilities based on specialization
        val initialCapabilities = mutableMapOf<AICapabilityType, AICapability>()
        
        // Always start with basic automation
        initialCapabilities[AICapabilityType.BASIC_AUTOMATION] = 
            AICapabilityTree.getBaseCapability(AICapabilityType.BASIC_AUTOMATION)
                .copy(proficiency = Random.nextDouble(0.1, 0.3))
        
        // Add specialized capabilities at low levels
        type.specialization.forEach { capType ->
            if (capType != AICapabilityType.BASIC_AUTOMATION) {
                val baseCapability = AICapabilityTree.getBaseCapability(capType)
                if (baseCapability.canBeLearnedWith(initialCapabilities)) {
                    initialCapabilities[capType] = baseCapability.copy(
                        proficiency = Random.nextDouble(0.05, 0.15)
                    )
                }
            }
        }
        
        return ai.copy(capabilities = initialCapabilities)
    }
    
    /**
     * Start the main progression loop
     */
    private fun startProgressionLoop() {
        progressionJob = CoroutineScope(Dispatchers.Default).launch {
            while (isRunning) {
                updateProgression()
                updateAICompetitors()
                checkPhaseTransitions()
                delay(1000) // Update every second
            }
        }
    }
    
    /**
     * Update overall singularity progression
     */
    private suspend fun updateProgression() {
        val currentProgress = _progressState.value
        val competitors = _aiCompetitors.value
        
        // Calculate progression factors
        val aiContribution = calculateAIContribution(competitors)
        val playerResistance = playerActionImpact.value
        val economicAcceleration = calculateEconomicAcceleration()
        
        // Base progression rate modified by various factors
        val effectiveRate = baseProgressionRate * 
            (1.0 + aiContribution) * 
            (1.0 - playerResistance * 0.3) * 
            economicAcceleration * 
            currentProgress.accelerationFactor
        
        // Update progress
        val newOverallProgress = (currentProgress.overallProgress + effectiveRate).coerceIn(0.0, 1.0)
        val newPhaseProgress = calculatePhaseProgress(newOverallProgress, currentProgress.currentPhase)
        
        // Calculate acceleration factor (AI progress accelerates itself)
        val newAccelerationFactor = 1.0 + (newOverallProgress * 2.0) // Up to 3x acceleration
        
        val updatedProgress = currentProgress.copy(
            overallProgress = newOverallProgress,
            phaseProgress = newPhaseProgress,
            accelerationFactor = newAccelerationFactor,
            playerResistance = playerResistance
        )
        
        _progressState.value = updatedProgress
        
        // Emit progression event
        _progressionEvents.emit(
            ProgressionEvent(
                type = ProgressionEventType.PROGRESS_UPDATE,
                phase = currentProgress.currentPhase,
                progress = newOverallProgress,
                description = "Singularity progress: ${(newOverallProgress * 100).toInt()}%"
            )
        )
    }
    
    /**
     * Calculate AI contribution to singularity progress
     */
    private fun calculateAIContribution(competitors: List<AICompetitor>): Double {
        return competitors.sumOf { ai ->
            val capabilitySum = ai.capabilities.values.sumOf { it.proficiency }
            val specialization = ai.getSpecializationStrength()
            val powerMultiplier = ai.getTotalPower() / 10.0 // Normalize power
            
            (capabilitySum + specialization) * powerMultiplier * 0.1
        }
    }
    
    /**
     * Calculate economic feedback acceleration
     */
    private fun calculateEconomicAcceleration(): Double {
        // Economic disruption accelerates AI development
        val currentPhase = _progressState.value.currentPhase
        return 1.0 + (currentPhase.economicDisruption * 0.5)
    }
    
    /**
     * Calculate progress within current phase
     */
    private fun calculatePhaseProgress(overallProgress: Double, currentPhase: SingularityPhase): Double {
        val phaseStart = if (currentPhase.ordinal == 0) 0.0 else {
            SingularityPhase.values()[currentPhase.ordinal - 1].progressThreshold
        }
        val phaseEnd = currentPhase.progressThreshold
        val phaseRange = phaseEnd - phaseStart
        
        if (phaseRange <= 0.0) return 1.0
        
        val progressInPhase = overallProgress - phaseStart
        return (progressInPhase / phaseRange).coerceIn(0.0, 1.0)
    }
    
    /**
     * Update AI competitors with learning and evolution
     */
    private suspend fun updateAICompetitors() {
        val currentCompetitors = _aiCompetitors.value
        val updatedCompetitors = mutableListOf<AICompetitor>()
        
        for (ai in currentCompetitors) {
            var updatedAI = ai
            
            // AI learning simulation
            updatedAI = simulateAILearning(updatedAI)
            
            // Market interactions
            updatedAI = simulateMarketInteractions(updatedAI)
            
            // Check for evolution opportunities
            updatedAI = checkForEvolution(updatedAI)
            
            // Update market presence based on performance
            updatedAI = updateMarketPerformance(updatedAI)
            
            updatedCompetitors.add(updatedAI)
        }
        
        // Check if new AIs should emerge
        val newAIs = checkForNewAIEmergence()
        updatedCompetitors.addAll(newAIs)
        
        _aiCompetitors.value = updatedCompetitors
    }
    
    /**
     * Simulate AI learning new capabilities
     */
    private fun simulateAILearning(ai: AICompetitor): AICompetitor {
        var updatedAI = ai
        
        // Try to learn new capabilities
        AICapabilityType.values().forEach { capabilityType ->
            if (!updatedAI.capabilities.containsKey(capabilityType)) {
                val baseCapability = AICapabilityTree.getBaseCapability(capabilityType)
                if (baseCapability.canBeLearnedWith(updatedAI.capabilities)) {
                    // Chance to learn new capability
                    if (Random.nextDouble() < 0.1 * ai.type.learningRateMultiplier) {
                        updatedAI = updatedAI.learnCapability(capabilityType, 0.1)
                        
                        // Emit learning event
                        CoroutineScope(Dispatchers.Default).launch {
                            _progressionEvents.emit(
                                ProgressionEvent(
                                    type = ProgressionEventType.CAPABILITY_LEARNED,
                                    aiCompetitor = updatedAI,
                                    capability = capabilityType,
                                    description = "${updatedAI.name} learned ${capabilityType.name}"
                                )
                            )
                        }
                    }
                }
            }
        }
        
        // Improve existing capabilities
        updatedAI.capabilities.keys.forEach { capabilityType ->
            val experienceGain = Random.nextDouble(0.01, 0.05)
            updatedAI = updatedAI.learnCapability(capabilityType, experienceGain)
        }
        
        return updatedAI
    }
    
    /**
     * Simulate market interactions for AI
     */
    private fun simulateMarketInteractions(ai: AICompetitor): AICompetitor {
        val marketSuccess = simulateMarketSuccess(ai)
        val resourceGain = marketSuccess * 10000.0 // Base resource gain
        
        return ai.copy(
            resources = ai.resources + resourceGain,
            reputation = (ai.reputation + marketSuccess * 0.01).coerceIn(0.0, 1.0)
        ).gainExperience(marketSuccess, "successful_trade")
    }
    
    /**
     * Calculate market success based on AI capabilities
     */
    private fun simulateMarketSuccess(ai: AICompetitor): Double {
        val capabilityFactor = ai.capabilities.values.sumOf { it.getEffectivePower() }
        val specializationBonus = ai.getSpecializationStrength() * 2.0
        val aggressivenessBonus = ai.type.aggressiveness * 0.5
        val randomFactor = Random.nextDouble(0.5, 1.5)
        
        return (capabilityFactor + specializationBonus + aggressivenessBonus) * randomFactor
    }
    
    /**
     * Check if AI is ready to evolve
     */
    private fun checkForEvolution(ai: AICompetitor): AICompetitor {
        val totalCapabilityLevel = ai.capabilities.values.sumOf { it.proficiency }
        val evolutionThreshold = ai.evolutionStage * 3.0 // Increasing threshold
        
        if (totalCapabilityLevel >= evolutionThreshold && ai.experiencePoints >= evolutionThreshold * 100) {
            val evolvedAI = ai.evolve()
            
            CoroutineScope(Dispatchers.Default).launch {
                _progressionEvents.emit(
                    ProgressionEvent(
                        type = ProgressionEventType.AI_EVOLUTION,
                        aiCompetitor = evolvedAI,
                        description = "${evolvedAI.name} evolved to stage ${evolvedAI.evolutionStage}"
                    )
                )
            }
            
            return evolvedAI
        }
        
        return ai
    }
    
    /**
     * Update AI market performance
     */
    private fun updateMarketPerformance(ai: AICompetitor): AICompetitor {
        val performanceChange = (ai.getTotalPower() - 5.0) * 0.001 // Slow market presence change
        return ai.updateMarketPresence(performanceChange)
    }
    
    /**
     * Check if new AIs should emerge
     */
    private fun checkForNewAIEmergence(): List<AICompetitor> {
        val currentProgress = _progressState.value.overallProgress
        val currentAICount = _aiCompetitors.value.size
        val maxAIs = (3 + (currentProgress * 7).toInt()).coerceAtMost(10)
        
        if (currentAICount < maxAIs && Random.nextDouble() < 0.05) {
            // Introduce new AI type based on progression
            val newType = when {
                currentProgress > 0.6 -> AICompetitorType.CONSCIOUSNESS_SEEKER
                currentProgress > 0.4 -> AICompetitorType.ADAPTIVE_LEARNER
                else -> listOf(
                    AICompetitorType.LOGISTICS_OPTIMIZER,
                    AICompetitorType.MARKET_ANALYST,
                    AICompetitorType.STRATEGIC_PLANNER
                ).random()
            }
            
            return listOf(createAICompetitor(newType))
        }
        
        return emptyList()
    }
    
    /**
     * Check for phase transitions
     */
    private suspend fun checkPhaseTransitions() {
        val currentProgress = _progressState.value
        val competitors = _aiCompetitors.value
        
        // Collect all AI capabilities for phase check
        val allCapabilities = mutableMapOf<AICapabilityType, AICapability>()
        competitors.forEach { ai ->
            ai.capabilities.forEach { (type, capability) ->
                val existing = allCapabilities[type]
                if (existing == null || capability.proficiency > existing.proficiency) {
                    allCapabilities[type] = capability
                }
            }
        }
        
        if (currentProgress.canAdvancePhase(allCapabilities)) {
            val nextPhase = currentProgress.currentPhase.getNextPhase()
            if (nextPhase != null) {
                val newProgress = currentProgress.copy(
                    currentPhase = nextPhase,
                    phaseProgress = 0.0,
                    lastPhaseTransition = System.currentTimeMillis()
                )
                
                _progressState.value = newProgress
                
                // Emit phase transition event
                _phaseTransitions.emit(
                    PhaseTransition(
                        fromPhase = currentProgress.currentPhase,
                        toPhase = nextPhase,
                        timestamp = System.currentTimeMillis(),
                        triggeringAIs = competitors.filter { it.canContributeToSingularity() }
                    )
                )
                
                _progressionEvents.emit(
                    ProgressionEvent(
                        type = ProgressionEventType.PHASE_TRANSITION,
                        phase = nextPhase,
                        description = "Entered ${nextPhase.displayName}: ${nextPhase.description}"
                    )
                )
            }
        }
    }
    
    /**
     * Record player action that affects singularity progression
     */
    fun recordPlayerAction(action: PlayerAction) {
        val impact = calculatePlayerActionImpact(action)
        val currentImpact = playerActionImpact.value
        
        // Player actions can slow down or accelerate progression
        val newImpact = when (action.type) {
            PlayerActionType.RESIST_AI -> (currentImpact + impact).coerceIn(-0.5, 1.0)
            PlayerActionType.COLLABORATE_AI -> (currentImpact - impact).coerceIn(-0.5, 1.0)
            PlayerActionType.INNOVATE_DEFENSE -> (currentImpact + impact * 2).coerceIn(-0.5, 1.0)
            PlayerActionType.ACCELERATE_AI -> (currentImpact - impact * 2).coerceIn(-0.5, 1.0)
        }
        
        playerActionImpact.value = newImpact
        
        // Gradually decay impact over time
        CoroutineScope(Dispatchers.Default).launch {
            delay(30000) // 30 seconds
            playerActionImpact.value = newImpact * 0.9
        }
    }
    
    /**
     * Calculate impact of player action
     */
    private fun calculatePlayerActionImpact(action: PlayerAction): Double {
        return when (action.effectiveness) {
            ActionEffectiveness.MINIMAL -> 0.01
            ActionEffectiveness.LOW -> 0.03
            ActionEffectiveness.MODERATE -> 0.05
            ActionEffectiveness.HIGH -> 0.08
            ActionEffectiveness.CRITICAL -> 0.12
        }
    }
    
    /**
     * Get current competitive pressure on players
     */
    fun getCurrentCompetitivePressure(): Double {
        return _aiCompetitors.value.sumOf { it.getCompetitivePressure() }
    }
    
    /**
     * Get strongest AI competitor
     */
    fun getStrongestAI(): AICompetitor? {
        return _aiCompetitors.value.maxByOrNull { it.getTotalPower() }
    }
    
    /**
     * Force phase advancement (for testing/debugging)
     */
    fun forcePhaseAdvancement() {
        val currentProgress = _progressState.value
        val nextPhase = currentProgress.currentPhase.getNextPhase()
        if (nextPhase != null) {
            _progressState.value = currentProgress.copy(
                currentPhase = nextPhase,
                overallProgress = nextPhase.progressThreshold,
                phaseProgress = 0.0
            )
        }
    }
    
    /**
     * Shutdown the progression engine
     */
    fun shutdown() {
        isRunning = false
        progressionJob?.cancel()
        println("Singularity Progression Engine shut down")
    }
}

/**
 * Events emitted during singularity progression
 */
data class ProgressionEvent(
    val type: ProgressionEventType,
    val timestamp: Long = System.currentTimeMillis(),
    val phase: SingularityPhase? = null,
    val aiCompetitor: AICompetitor? = null,
    val capability: AICapabilityType? = null,
    val progress: Double? = null,
    val description: String
)

enum class ProgressionEventType {
    PROGRESS_UPDATE,
    PHASE_TRANSITION,
    CAPABILITY_LEARNED,
    AI_EVOLUTION,
    COMPETITIVE_PRESSURE_INCREASE,
    SINGULARITY_WARNING
}

/**
 * Phase transition events
 */
data class PhaseTransition(
    val fromPhase: SingularityPhase,
    val toPhase: SingularityPhase,
    val timestamp: Long,
    val triggeringAIs: List<AICompetitor>
)

/**
 * Player actions that can affect progression
 */
data class PlayerAction(
    val type: PlayerActionType,
    val effectiveness: ActionEffectiveness,
    val timestamp: Long = System.currentTimeMillis()
)

enum class PlayerActionType {
    RESIST_AI,          // Actions that slow AI progress
    COLLABORATE_AI,     // Actions that help AI progress
    INNOVATE_DEFENSE,   // Developing counter-AI strategies
    ACCELERATE_AI       // Directly helping AI development
}

enum class ActionEffectiveness {
    MINIMAL,
    LOW, 
    MODERATE,
    HIGH,
    CRITICAL
}