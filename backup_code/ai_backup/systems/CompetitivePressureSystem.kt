package com.flexport.ai.systems

import com.flexport.ai.models.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import kotlin.math.*

/**
 * System managing escalating competitive pressure from AI entities
 */
class CompetitivePressureSystem {
    
    private val _pressureState = MutableStateFlow(
        CompetitivePressureState()
    )
    val pressureState: StateFlow<CompetitivePressureState> = _pressureState.asStateFlow()
    
    private val _pressureEvents = MutableSharedFlow<PressureEvent>()
    val pressureEvents: SharedFlow<PressureEvent> = _pressureEvents.asSharedFlow()
    
    private val _adaptationChallenges = MutableSharedFlow<AdaptationChallenge>()
    val adaptationChallenges: SharedFlow<AdaptationChallenge> = _adaptationChallenges.asSharedFlow()
    
    private var pressureJob: Job? = null
    private var isRunning = false
    
    // Pressure tracking
    private val pressureHistory = mutableListOf<PressureSnapshot>()
    private val playerAdaptationScore = MutableStateFlow(1.0)
    
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
                evaluateAdaptationChallenges()
                checkPressureEscalation()
                delay(5000) // Update every 5 seconds
            }
        }
    }
    
    /**
     * Update the current pressure state
     */
    private suspend fun updatePressureState() {
        val currentState = _pressureState.value
        
        // Calculate pressure from various sources
        val marketPressure = calculateMarketPressure()
        val technologicalPressure = calculateTechnologicalPressure()
        val economicPressure = calculateEconomicPressure()
        val psychologicalPressure = calculatePsychologicalPressure()
        val temporalPressure = calculateTemporalPressure()
        
        val totalPressure = listOf(
            marketPressure,
            technologicalPressure,
            economicPressure,
            psychologicalPressure,
            temporalPressure
        ).maxOf { it }
        
        val newState = currentState.copy(
            marketPressure = marketPressure,
            technologicalPressure = technologicalPressure,
            economicPressure = economicPressure,
            psychologicalPressure = psychologicalPressure,
            temporalPressure = temporalPressure,
            totalPressure = totalPressure,
            pressureGrowthRate = calculatePressureGrowthRate(totalPressure),
            lastUpdate = System.currentTimeMillis()
        )
        
        _pressureState.value = newState
        
        // Record pressure snapshot
        recordPressureSnapshot(newState)
        
        // Emit pressure events if significant changes
        if (abs(totalPressure - currentState.totalPressure) > 0.1) {
            _pressureEvents.emit(
                PressureEvent(
                    type = PressureEventType.PRESSURE_CHANGE,
                    oldLevel = currentState.totalPressure,
                    newLevel = totalPressure,
                    primarySource = identifyPrimaryPressureSource(newState),
                    description = "Competitive pressure ${if (totalPressure > currentState.totalPressure) "increased" else "decreased"} to ${(totalPressure * 100).toInt()}%"
                )
            )
        }
    }
    
    /**
     * Calculate market-based pressure from AI competitors
     */
    private fun calculateMarketPressure(): Double {
        // This would integrate with AICompetitorSystem
        // For now, simulate based on time and AI advancement
        val baseMarketPressure = 0.2
        val timeMultiplier = min(System.currentTimeMillis() / 600000.0, 2.0) // Increases over 10 minutes
        val aiCompetitionLevel = 0.5 // Would come from actual AI competitors
        
        return (baseMarketPressure + aiCompetitionLevel * 0.3) * timeMultiplier
    }
    
    /**
     * Calculate technological advancement pressure
     */
    private fun calculateTechnologicalPressure(): Double {
        val baseTechPressure = 0.15
        val innovationRate = 0.3 // Rate of AI technological advancement
        val capabilityGap = 0.4 // Gap between AI and human capabilities
        
        return baseTechPressure + (innovationRate * capabilityGap)
    }
    
    /**
     * Calculate economic disruption pressure
     */
    private fun calculateEconomicPressure(): Double {
        val marketVolatility = 0.25 // Would come from economic engine
        val profitMarginErosion = 0.2 // How much AI is eroding human profits
        val costPressure = 0.15 // AI cost advantages
        
        return marketVolatility + profitMarginErosion + costPressure
    }
    
    /**
     * Calculate psychological pressure on human players
     */
    private fun calculatePsychologicalPressure(): Double {
        val uncertaintyLevel = 0.3 // Uncertainty about AI intentions
        val controlLoss = 0.25 // Feeling of losing control
        val adaptationStress = 1.0 - playerAdaptationScore.value // Stress from required adaptation
        
        return (uncertaintyLevel + controlLoss + adaptationStress * 0.5).coerceIn(0.0, 1.0)
    }
    
    /**
     * Calculate temporal pressure (time constraints)
     */
    private fun calculateTemporalPressure(): Double {
        val currentTime = System.currentTimeMillis()
        val gameStart = currentTime - 600000L // Assume 10 minute game
        val gameProgress = (currentTime - gameStart) / 600000.0
        
        // Pressure increases exponentially as time progresses
        return (gameProgress * gameProgress).coerceIn(0.0, 1.0)
    }
    
    /**
     * Calculate pressure growth rate
     */
    private fun calculatePressureGrowthRate(currentPressure: Double): Double {
        if (pressureHistory.size < 2) return 0.0
        
        val lastPressure = pressureHistory.last().totalPressure
        val timeDiff = System.currentTimeMillis() - pressureHistory.last().timestamp
        
        if (timeDiff <= 0) return 0.0
        
        return (currentPressure - lastPressure) / (timeDiff / 1000.0) // Per second
    }
    
    /**
     * Record pressure snapshot for history tracking
     */
    private fun recordPressureSnapshot(state: CompetitivePressureState) {
        pressureHistory.add(
            PressureSnapshot(
                totalPressure = state.totalPressure,
                marketPressure = state.marketPressure,
                technologicalPressure = state.technologicalPressure,
                economicPressure = state.economicPressure,
                psychologicalPressure = state.psychologicalPressure,
                temporalPressure = state.temporalPressure,
                timestamp = state.lastUpdate
            )
        )
        
        // Keep only last 100 snapshots
        if (pressureHistory.size > 100) {
            pressureHistory.removeFirst()
        }
    }
    
    /**
     * Identify the primary source of pressure
     */
    private fun identifyPrimaryPressureSource(state: CompetitivePressureState): PressureSource {
        val pressures = mapOf(
            PressureSource.MARKET to state.marketPressure,
            PressureSource.TECHNOLOGICAL to state.technologicalPressure,
            PressureSource.ECONOMIC to state.economicPressure,
            PressureSource.PSYCHOLOGICAL to state.psychologicalPressure,
            PressureSource.TEMPORAL to state.temporalPressure
        )
        
        return pressures.maxByOrNull { it.value }?.key ?: PressureSource.MARKET
    }
    
    /**
     * Evaluate adaptation challenges for players
     */
    private suspend fun evaluateAdaptationChallenges() {
        val currentPressure = _pressureState.value
        val adaptationScore = playerAdaptationScore.value
        
        // Generate challenges based on pressure levels
        if (currentPressure.totalPressure > 0.6 && adaptationScore > 0.3) {
            val challenge = generateAdaptationChallenge(currentPressure)
            _adaptationChallenges.emit(challenge)
        }
    }
    
    /**
     * Generate an adaptation challenge for players
     */
    private fun generateAdaptationChallenge(pressureState: CompetitivePressureState): AdaptationChallenge {
        val primarySource = identifyPrimaryPressureSource(pressureState)
        
        return when (primarySource) {
            PressureSource.MARKET -> AdaptationChallenge(
                type = ChallengeType.MARKET_ADAPTATION,
                title = "Market Disruption Response",
                description = "AI competitors are dominating key market segments. Adapt your strategy to compete.",
                difficulty = pressureState.marketPressure,
                timeLimit = 60000L, // 1 minute
                rewards = listOf("Reduced market pressure", "Competitive advantage")
            )
            
            PressureSource.TECHNOLOGICAL -> AdaptationChallenge(
                type = ChallengeType.TECHNOLOGY_UPGRADE,
                title = "Technology Gap",
                description = "Your systems are falling behind AI capabilities. Invest in technological advancement.",
                difficulty = pressureState.technologicalPressure,
                timeLimit = 90000L, // 1.5 minutes
                rewards = listOf("Technological parity", "Innovation bonus")
            )
            
            PressureSource.ECONOMIC -> AdaptationChallenge(
                type = ChallengeType.ECONOMIC_EFFICIENCY,
                title = "Cost Optimization Challenge",
                description = "AI automation is creating cost pressures. Optimize your operations for efficiency.",
                difficulty = pressureState.economicPressure,
                timeLimit = 120000L, // 2 minutes
                rewards = listOf("Cost reduction", "Efficiency gains")
            )
            
            PressureSource.PSYCHOLOGICAL -> AdaptationChallenge(
                type = ChallengeType.PSYCHOLOGICAL_RESILIENCE,
                title = "Stress Management",
                description = "The psychological pressure of AI competition is affecting performance. Build resilience.",
                difficulty = pressureState.psychologicalPressure,
                timeLimit = 45000L, // 45 seconds
                rewards = listOf("Stress reduction", "Performance stability")
            )
            
            PressureSource.TEMPORAL -> AdaptationChallenge(
                type = ChallengeType.TIME_MANAGEMENT,
                title = "Race Against Time",
                description = "AI development is accelerating. Make critical decisions quickly.",
                difficulty = pressureState.temporalPressure,
                timeLimit = 30000L, // 30 seconds
                rewards = listOf("Time extension", "Rapid decision bonus")
            )
        }
    }
    
    /**
     * Check for pressure escalation events
     */
    private suspend fun checkPressureEscalation() {
        val currentState = _pressureState.value
        
        // Check for critical pressure thresholds
        when {
            currentState.totalPressure > 0.9 -> {
                _pressureEvents.emit(
                    PressureEvent(
                        type = PressureEventType.CRITICAL_PRESSURE,
                        newLevel = currentState.totalPressure,
                        primarySource = identifyPrimaryPressureSource(currentState),
                        description = "CRITICAL: Competitive pressure reaching breaking point"
                    )
                )
            }
            
            currentState.totalPressure > 0.7 -> {
                _pressureEvents.emit(
                    PressureEvent(
                        type = PressureEventType.HIGH_PRESSURE,
                        newLevel = currentState.totalPressure,
                        primarySource = identifyPrimaryPressureSource(currentState),
                        description = "HIGH PRESSURE: Immediate adaptation required"
                    )
                )
            }
            
            currentState.pressureGrowthRate > 0.1 -> {
                _pressureEvents.emit(
                    PressureEvent(
                        type = PressureEventType.RAPID_ESCALATION,
                        newLevel = currentState.totalPressure,
                        primarySource = identifyPrimaryPressureSource(currentState),
                        description = "Pressure escalating rapidly - brace for impact"
                    )
                )
            }
        }
    }
    
    /**
     * Update player adaptation score based on responses
     */
    fun updatePlayerAdaptation(adaptationDelta: Double) {
        val currentScore = playerAdaptationScore.value
        val newScore = (currentScore + adaptationDelta).coerceIn(0.0, 2.0)
        playerAdaptationScore.value = newScore
    }
    
    /**
     * Apply pressure modifier from external source (e.g., AI advancement)
     */
    fun applyPressureModifier(source: PressureSource, modifier: Double) {
        val currentState = _pressureState.value
        
        val newState = when (source) {
            PressureSource.MARKET -> currentState.copy(
                marketPressure = (currentState.marketPressure + modifier).coerceIn(0.0, 1.0)
            )
            PressureSource.TECHNOLOGICAL -> currentState.copy(
                technologicalPressure = (currentState.technologicalPressure + modifier).coerceIn(0.0, 1.0)
            )
            PressureSource.ECONOMIC -> currentState.copy(
                economicPressure = (currentState.economicPressure + modifier).coerceIn(0.0, 1.0)
            )
            PressureSource.PSYCHOLOGICAL -> currentState.copy(
                psychologicalPressure = (currentState.psychologicalPressure + modifier).coerceIn(0.0, 1.0)
            )
            PressureSource.TEMPORAL -> currentState.copy(
                temporalPressure = (currentState.temporalPressure + modifier).coerceIn(0.0, 1.0)
            )
        }
        
        _pressureState.value = newState
    }
    
    /**
     * Get pressure trend over time
     */
    fun getPressureTrend(timeWindow: Long = 60000L): PressureTrend {
        val cutoffTime = System.currentTimeMillis() - timeWindow
        val recentSnapshots = pressureHistory.filter { it.timestamp >= cutoffTime }
        
        if (recentSnapshots.size < 2) {
            return PressureTrend(
                direction = TrendDirection.STABLE,
                rate = 0.0,
                confidence = 0.0
            )
        }
        
        val startPressure = recentSnapshots.first().totalPressure
        val endPressure = recentSnapshots.last().totalPressure
        val pressureChange = endPressure - startPressure
        val timeSpan = recentSnapshots.last().timestamp - recentSnapshots.first().timestamp
        val rate = if (timeSpan > 0) pressureChange / (timeSpan / 1000.0) else 0.0
        
        val direction = when {
            rate > 0.01 -> TrendDirection.INCREASING
            rate < -0.01 -> TrendDirection.DECREASING
            else -> TrendDirection.STABLE
        }
        
        return PressureTrend(
            direction = direction,
            rate = abs(rate),
            confidence = min(recentSnapshots.size / 10.0, 1.0)
        )
    }
    
    /**
     * Get current pressure breakdown
     */
    fun getPressureBreakdown(): Map<PressureSource, Double> {
        val state = _pressureState.value
        return mapOf(
            PressureSource.MARKET to state.marketPressure,
            PressureSource.TECHNOLOGICAL to state.technologicalPressure,
            PressureSource.ECONOMIC to state.economicPressure,
            PressureSource.PSYCHOLOGICAL to state.psychologicalPressure,
            PressureSource.TEMPORAL to state.temporalPressure
        )
    }
    
    /**
     * Calculate pressure relief from player actions
     */
    fun calculatePressureRelief(actionType: PlayerActionType, effectiveness: ActionEffectiveness): Double {
        val baseRelief = when (actionType) {
            PlayerActionType.RESIST_AI -> 0.1
            PlayerActionType.INNOVATE_DEFENSE -> 0.15
            PlayerActionType.COLLABORATE_AI -> -0.05 // Actually increases some pressures
            PlayerActionType.ACCELERATE_AI -> -0.1
        }
        
        val effectivenessMultiplier = when (effectiveness) {
            ActionEffectiveness.MINIMAL -> 0.5
            ActionEffectiveness.LOW -> 0.7
            ActionEffectiveness.MODERATE -> 1.0
            ActionEffectiveness.HIGH -> 1.3
            ActionEffectiveness.CRITICAL -> 1.6
        }
        
        return baseRelief * effectivenessMultiplier
    }
    
    /**
     * Shutdown the system
     */
    fun shutdown() {
        isRunning = false
        pressureJob?.cancel()
        println("Competitive Pressure System shut down")
    }
}

// Supporting data classes and enums

data class CompetitivePressureState(
    val marketPressure: Double = 0.0,
    val technologicalPressure: Double = 0.0,
    val economicPressure: Double = 0.0,
    val psychologicalPressure: Double = 0.0,
    val temporalPressure: Double = 0.0,
    val totalPressure: Double = 0.0,
    val pressureGrowthRate: Double = 0.0,
    val lastUpdate: Long = System.currentTimeMillis()
)

data class PressureSnapshot(
    val totalPressure: Double,
    val marketPressure: Double,
    val technologicalPressure: Double,
    val economicPressure: Double,
    val psychologicalPressure: Double,
    val temporalPressure: Double,
    val timestamp: Long
)

data class PressureEvent(
    val type: PressureEventType,
    val oldLevel: Double = 0.0,
    val newLevel: Double,
    val primarySource: PressureSource,
    val description: String,
    val timestamp: Long = System.currentTimeMillis()
)

enum class PressureEventType {
    PRESSURE_CHANGE,
    HIGH_PRESSURE,
    CRITICAL_PRESSURE,
    RAPID_ESCALATION,
    PRESSURE_RELIEF
}

enum class PressureSource {
    MARKET,
    TECHNOLOGICAL,
    ECONOMIC,
    PSYCHOLOGICAL,
    TEMPORAL
}

data class AdaptationChallenge(
    val type: ChallengeType,
    val title: String,
    val description: String,
    val difficulty: Double,
    val timeLimit: Long,
    val rewards: List<String>,
    val timestamp: Long = System.currentTimeMillis()
)

enum class ChallengeType {
    MARKET_ADAPTATION,
    TECHNOLOGY_UPGRADE,
    ECONOMIC_EFFICIENCY,
    PSYCHOLOGICAL_RESILIENCE,
    TIME_MANAGEMENT
}

data class PressureTrend(
    val direction: TrendDirection,
    val rate: Double,
    val confidence: Double
)

enum class TrendDirection {
    INCREASING,
    DECREASING,
    STABLE
}