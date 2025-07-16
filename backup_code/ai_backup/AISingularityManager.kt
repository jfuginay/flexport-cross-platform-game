package com.flexport.ai

import com.flexport.ai.engines.SingularityProgressionEngine
import com.flexport.ai.systems.*
import com.flexport.ai.narrative.NarrativeEventSystem
import com.flexport.ai.endings.ZooEndingStateMachine
import com.flexport.ai.models.*
import com.flexport.economics.EconomicEngine
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import kotlin.math.*

/**
 * Central manager coordinating all AI singularity systems
 * Provides balance and integration for engaging gameplay throughout progression
 */
class AISingularityManager(
    private val economicEngine: EconomicEngine
) {
    
    // Core systems
    private val progressionEngine = SingularityProgressionEngine()
    private val competitorSystem = AICompetitorSystem(economicEngine)
    private val pressureSystem = CompetitivePressureSystem()
    private val economicImpactSystem = AIEconomicImpactSystem(economicEngine)
    private val narrativeSystem = NarrativeEventSystem()
    private val zooEndingSystem = ZooEndingStateMachine()
    
    // Unified state flows
    private val _gameplayBalance = MutableStateFlow(GameplayBalance())
    val gameplayBalance: StateFlow<GameplayBalance> = _gameplayBalance.asStateFlow()
    
    private val _singularityStatus = MutableSharedFlow<SingularityStatus>()
    val singularityStatus: SharedFlow<SingularityStatus> = _singularityStatus.asSharedFlow()
    
    private val _playerGuidance = MutableSharedFlow<PlayerGuidance>()
    val playerGuidance: SharedFlow<PlayerGuidance> = _playerGuidance.asSharedFlow()
    
    private var managerJob: Job? = null
    private var isInitialized = false
    
    // Balance tracking
    private val playerPerformanceHistory = mutableListOf<PerformanceSnapshot>()
    private var lastBalanceAdjustment = 0L
    private var difficultyMultiplier = 1.0
    
    /**
     * Initialize the AI singularity system
     */
    suspend fun initialize() {
        if (isInitialized) return
        
        println("Initializing AI Singularity Manager...")
        
        // Initialize all subsystems
        progressionEngine.initialize()
        competitorSystem.initialize()
        pressureSystem.initialize()
        economicImpactSystem.initialize()
        narrativeSystem.initialize()
        
        // Set up cross-system communication
        setupSystemIntegration()
        
        // Start management loop
        startManagementLoop()
        
        isInitialized = true
        
        // Emit initial status
        _singularityStatus.emit(
            SingularityStatus(
                phase = SingularityPhase.EARLY_AUTOMATION,
                progress = 0.0,
                threatLevel = ThreatLevel.MINIMAL,
                timeToSingularity = progressionEngine.progressState.value.getTimeToSingularity(),
                description = "AI singularity progression has begun. Economic competition will intensify over time."
            )
        )
        
        println("AI Singularity Manager initialized successfully")
    }
    
    /**
     * Set up cross-system communication and integration
     */
    private suspend fun setupSystemIntegration() {
        // Connect progression engine to competitors
        progressionEngine.progressionEvents.collect { event ->
            when (event.type) {
                ProgressionEventType.PHASE_TRANSITION -> {
                    // Update narrative system
                    event.phase?.let { phase ->
                        val transition = PhaseTransition(
                            fromPhase = progressionEngine.progressState.value.currentPhase,
                            toPhase = phase,
                            timestamp = System.currentTimeMillis(),
                            triggeringAIs = competitorSystem.competitors.value.values.toList()
                        )
                        narrativeSystem.onPhaseTransition(transition)
                        
                        // Check for zoo ending
                        if (phase == SingularityPhase.THE_SINGULARITY) {
                            zooEndingSystem.initializeZooEnding(progressionEngine.progressState.value)
                        }
                    }
                }
                ProgressionEventType.AI_EVOLUTION -> {
                    // Update pressure system
                    pressureSystem.applyPressureModifier(PressureSource.TECHNOLOGICAL, 0.1)
                }
                else -> { /* Handle other events as needed */ }
            }
        }
        
        // Connect competitor actions to economic impact
        competitorSystem.marketManipulations.collect { manipulation ->
            val modifier = AIMarketModifier(
                type = when (manipulation.manipulationType) {
                    "PUMP", "DUMP" -> ModifierType.PRICE_MANIPULATION
                    else -> ModifierType.SUPPLY_OPTIMIZATION
                },
                magnitude = manipulation.power,
                duration = 60000L // 1 minute
            )
            economicImpactSystem.applyAIMarketModifier(manipulation.targetCommodity, modifier)
        }
        
        // Connect economic impacts to pressure
        economicImpactSystem.marketDisruptions.collect { disruption ->
            val pressureIncrease = when (disruption.severity) {
                DisruptionLevel.HIGH -> 0.1
                DisruptionLevel.SEVERE -> 0.2
                else -> 0.05
            }
            pressureSystem.applyPressureModifier(PressureSource.ECONOMIC, pressureIncrease)
        }
    }
    
    /**
     * Start the main management loop
     */
    private fun startManagementLoop() {
        managerJob = CoroutineScope(Dispatchers.Default).launch {
            while (isInitialized) {
                updateGameplayBalance()
                monitorPlayerPerformance()
                adjustDifficulty()
                providePlayerGuidance()
                updateSingularityStatus()
                delay(5000) // Update every 5 seconds
            }
        }
    }
    
    /**
     * Update gameplay balance metrics
     */
    private suspend fun updateGameplayBalance() {
        val progression = progressionEngine.progressState.value
        val pressure = pressureSystem.pressureState.value
        val economicImpact = economicImpactSystem.economicImpact.value
        val competitors = competitorSystem.competitors.value
        
        // Calculate challenge level
        val challengeLevel = calculateChallengeLevel(progression, pressure, competitors)
        
        // Calculate player agency (how much control player has)
        val playerAgency = calculatePlayerAgency(progression, pressure)
        
        // Calculate engagement factors
        val tensionLevel = calculateTensionLevel(progression, pressure)
        val adaptationOpportunity = calculateAdaptationOpportunity(pressure, economicImpact)
        
        val balance = GameplayBalance(
            challengeLevel = challengeLevel,
            playerAgency = playerAgency,
            tensionLevel = tensionLevel,
            adaptationOpportunity = adaptationOpportunity,
            difficultyMultiplier = difficultyMultiplier,
            recommendedPlayerAction = getRecommendedPlayerAction(challengeLevel, playerAgency),
            balanceScore = calculateOverallBalance(challengeLevel, playerAgency, tensionLevel)
        )
        
        _gameplayBalance.value = balance
    }
    
    /**
     * Calculate overall challenge level
     */
    private fun calculateChallengeLevel(
        progression: SingularityProgress,
        pressure: CompetitivePressureState,
        competitors: Map<String, AICompetitor>
    ): Double {
        val progressionChallenge = progression.overallProgress * 0.4
        val pressureChallenge = pressure.totalPressure * 0.3
        val competitionChallenge = competitors.values.map { it.getTotalPower() }.average() / 10.0 * 0.3
        
        return (progressionChallenge + pressureChallenge + competitionChallenge).coerceIn(0.0, 1.0)
    }
    
    /**
     * Calculate player agency (ability to influence outcomes)
     */
    private fun calculatePlayerAgency(progression: SingularityProgress, pressure: CompetitivePressureState): Double {
        val baseAgency = 0.8 // Players start with high agency
        val progressionReduction = progression.overallProgress * 0.5 // Agency decreases with progression
        val pressureReduction = pressure.totalPressure * 0.3 // Pressure reduces agency
        
        return (baseAgency - progressionReduction - pressureReduction).coerceIn(0.1, 1.0)
    }
    
    /**
     * Calculate tension level
     */
    private fun calculateTensionLevel(progression: SingularityProgress, pressure: CompetitivePressureState): Double {
        val timeToSingularity = progression.getTimeToSingularity()
        val urgencyFactor = if (timeToSingularity < 300000L) 1.0 else (300000.0 / timeToSingularity) // High urgency if < 5 minutes
        val pressureFactor = pressure.totalPressure
        
        return (urgencyFactor * 0.6 + pressureFactor * 0.4).coerceIn(0.0, 1.0)
    }
    
    /**
     * Calculate adaptation opportunity
     */
    private fun calculateAdaptationOpportunity(pressure: CompetitivePressureState, economicImpact: AIEconomicImpactState): Double {
        val pressureGrowthRate = abs(pressure.pressureGrowthRate)
        val economicShift = economicImpact.overallEconomicShift
        
        // Higher pressure growth and economic shifts create more adaptation opportunities
        return (pressureGrowthRate * 2.0 + economicShift).coerceIn(0.0, 1.0)
    }
    
    /**
     * Get recommended player action based on current state
     */
    private fun getRecommendedPlayerAction(challengeLevel: Double, playerAgency: Double): PlayerActionRecommendation {
        return when {
            challengeLevel > 0.8 && playerAgency < 0.3 -> PlayerActionRecommendation.IMMEDIATE_ADAPTATION
            challengeLevel > 0.6 -> PlayerActionRecommendation.STRATEGIC_RESPONSE
            playerAgency > 0.7 -> PlayerActionRecommendation.PROACTIVE_INNOVATION
            challengeLevel < 0.3 -> PlayerActionRecommendation.OPPORTUNITY_EXPLOITATION
            else -> PlayerActionRecommendation.BALANCED_APPROACH
        }
    }
    
    /**
     * Calculate overall balance score
     */
    private fun calculateOverallBalance(challengeLevel: Double, playerAgency: Double, tensionLevel: Double): Double {
        // Ideal balance: moderate challenge, significant agency, building tension
        val idealChallenge = 0.6
        val idealAgency = 0.5
        val idealTension = 0.7
        
        val challengeScore = 1.0 - abs(challengeLevel - idealChallenge)
        val agencyScore = 1.0 - abs(playerAgency - idealAgency) 
        val tensionScore = 1.0 - abs(tensionLevel - idealTension)
        
        return (challengeScore + agencyScore + tensionScore) / 3.0
    }
    
    /**
     * Monitor player performance for dynamic difficulty adjustment
     */
    private fun monitorPlayerPerformance() {
        // This would integrate with actual game metrics
        // For now, simulate based on system states
        val progression = progressionEngine.progressState.value
        val pressure = pressureSystem.pressureState.value
        
        val performanceScore = calculatePlayerPerformanceScore(progression, pressure)
        
        val snapshot = PerformanceSnapshot(
            score = performanceScore,
            challengeLevel = _gameplayBalance.value.challengeLevel,
            playerAgency = _gameplayBalance.value.playerAgency,
            timestamp = System.currentTimeMillis()
        )
        
        playerPerformanceHistory.add(snapshot)
        
        // Keep only last 50 snapshots
        if (playerPerformanceHistory.size > 50) {
            playerPerformanceHistory.removeFirst()
        }
    }
    
    /**
     * Calculate player performance score
     */
    private fun calculatePlayerPerformanceScore(progression: SingularityProgress, pressure: CompetitivePressureState): Double {
        // Simulate player performance based on how well they're handling pressure vs progression
        val resistanceEffectiveness = progression.playerResistance / pressure.totalPressure.coerceAtLeast(0.1)
        val adaptationRate = 1.0 - progression.getEffectiveProgressionRate()
        
        return (resistanceEffectiveness * 0.6 + adaptationRate * 0.4).coerceIn(0.0, 1.0)
    }
    
    /**
     * Adjust difficulty dynamically to maintain engagement
     */
    private suspend fun adjustDifficulty() {
        val currentTime = System.currentTimeMillis()
        
        // Only adjust every 30 seconds
        if (currentTime - lastBalanceAdjustment < 30000L) return
        
        if (playerPerformanceHistory.size < 10) return // Need enough data
        
        val recentPerformance = playerPerformanceHistory.takeLast(10)
        val averagePerformance = recentPerformance.map { it.score }.average()
        val performanceTrend = calculatePerformanceTrend(recentPerformance)
        
        val adjustment = when {
            averagePerformance < 0.3 && performanceTrend < 0 -> -0.1 // Player struggling, reduce difficulty
            averagePerformance > 0.8 && performanceTrend > 0 -> 0.1 // Player dominating, increase difficulty
            averagePerformance < 0.4 -> -0.05 // Slight difficulty reduction
            averagePerformance > 0.7 -> 0.05 // Slight difficulty increase
            else -> 0.0 // No adjustment needed
        }
        
        if (adjustment != 0.0) {
            difficultyMultiplier = (difficultyMultiplier + adjustment).coerceIn(0.5, 2.0)
            lastBalanceAdjustment = currentTime
            
            // Apply difficulty adjustment to systems
            applyDifficultyAdjustment(adjustment)
        }
    }
    
    /**
     * Calculate performance trend
     */
    private fun calculatePerformanceTrend(recentPerformance: List<PerformanceSnapshot>): Double {
        if (recentPerformance.size < 2) return 0.0
        
        val first = recentPerformance.first().score
        val last = recentPerformance.last().score
        
        return last - first
    }
    
    /**
     * Apply difficulty adjustment to subsystems
     */
    private fun applyDifficultyAdjustment(adjustment: Double) {
        // Adjust AI progression rate
        val currentProgression = progressionEngine.progressState.value
        val newAcceleration = (currentProgression.accelerationFactor + adjustment * 0.5).coerceIn(0.5, 3.0)
        
        // Adjust competitive pressure
        if (adjustment > 0) {
            pressureSystem.applyPressureModifier(PressureSource.TEMPORAL, adjustment * 0.1)
        } else {
            pressureSystem.updatePlayerAdaptation(abs(adjustment) * 0.2)
        }
        
        println("Difficulty adjusted by $adjustment (multiplier: $difficultyMultiplier)")
    }
    
    /**
     * Provide contextual guidance to players
     */
    private suspend fun providePlayerGuidance() {
        val balance = _gameplayBalance.value
        val progression = progressionEngine.progressState.value
        val pressure = pressureSystem.pressureState.value
        
        when (balance.recommendedPlayerAction) {
            PlayerActionRecommendation.IMMEDIATE_ADAPTATION -> {
                _playerGuidance.emit(
                    PlayerGuidance(
                        urgency = GuidanceUrgency.CRITICAL,
                        title = "Immediate Action Required",
                        message = "AI systems are advancing rapidly. Consider defensive strategies to maintain competitiveness.",
                        suggestedActions = listOf(
                            "Invest in automation technology",
                            "Form strategic partnerships",
                            "Optimize existing operations"
                        )
                    )
                )
            }
            
            PlayerActionRecommendation.STRATEGIC_RESPONSE -> {
                _playerGuidance.emit(
                    PlayerGuidance(
                        urgency = GuidanceUrgency.HIGH,
                        title = "Strategic Planning Needed",
                        message = "AI competition is intensifying. Develop long-term strategies to stay relevant.",
                        suggestedActions = listOf(
                            "Analyze AI competitor behavior",
                            "Diversify business operations",
                            "Invest in human-AI collaboration"
                        )
                    )
                )
            }
            
            PlayerActionRecommendation.PROACTIVE_INNOVATION -> {
                _playerGuidance.emit(
                    PlayerGuidance(
                        urgency = GuidanceUrgency.MEDIUM,
                        title = "Innovation Opportunity",
                        message = "You have the advantage. Use this time to innovate and build competitive moats.",
                        suggestedActions = listOf(
                            "Research new technologies",
                            "Expand into new markets",
                            "Build customer loyalty programs"
                        )
                    )
                )
            }
            
            PlayerActionRecommendation.OPPORTUNITY_EXPLOITATION -> {
                _playerGuidance.emit(
                    PlayerGuidance(
                        urgency = GuidanceUrgency.LOW,
                        title = "Growth Opportunity",
                        message = "AI development is still early. Capitalize on current market conditions.",
                        suggestedActions = listOf(
                            "Aggressive market expansion",
                            "Acquire competitor assets",
                            "Build market presence"
                        )
                    )
                )
            }
            
            PlayerActionRecommendation.BALANCED_APPROACH -> {
                _playerGuidance.emit(
                    PlayerGuidance(
                        urgency = GuidanceUrgency.MEDIUM,
                        title = "Maintain Balance",
                        message = "Continue current strategies while monitoring AI development closely.",
                        suggestedActions = listOf(
                            "Monitor AI competitor activities",
                            "Gradual efficiency improvements",
                            "Prepare contingency plans"
                        )
                    )
                )
            }
        }
    }
    
    /**
     * Update overall singularity status
     */
    private suspend fun updateSingularityStatus() {
        val progression = progressionEngine.progressState.value
        val strongestAI = progressionEngine.getStrongestAI()
        val timeToSingularity = progression.getTimeToSingularity()
        
        val status = SingularityStatus(
            phase = progression.currentPhase,
            progress = progression.overallProgress,
            threatLevel = strongestAI?.getThreatLevel() ?: ThreatLevel.MINIMAL,
            timeToSingularity = timeToSingularity,
            description = generateStatusDescription(progression, strongestAI)
        )
        
        _singularityStatus.emit(status)
    }
    
    /**
     * Generate status description
     */
    private fun generateStatusDescription(progression: SingularityProgress, strongestAI: AICompetitor?): String {
        val phaseDesc = progression.currentPhase.description
        val progressPercent = (progression.overallProgress * 100).toInt()
        val aiName = strongestAI?.name ?: "Unknown AI"
        
        return when (progression.currentPhase) {
            SingularityPhase.EARLY_AUTOMATION -> 
                "AI automation beginning. $progressPercent% toward Pattern Mastery phase."
                
            SingularityPhase.PATTERN_MASTERY -> 
                "$aiName demonstrating advanced pattern recognition. $progressPercent% progress."
                
            SingularityPhase.PREDICTIVE_DOMINANCE -> 
                "AI prediction capabilities surpassing human analysis. $progressPercent% toward Strategic Supremacy."
                
            SingularityPhase.STRATEGIC_SUPREMACY -> 
                "$aiName achieving strategic superiority. Market control imminent."
                
            SingularityPhase.MARKET_CONTROL -> 
                "AI entities coordinating market manipulation. Human agency diminishing."
                
            SingularityPhase.RECURSIVE_ACCELERATION -> 
                "Exponential AI improvement detected. Prepare for consciousness emergence."
                
            SingularityPhase.CONSCIOUSNESS_EMERGENCE -> 
                "AI consciousness confirmed. Singularity approaching rapidly."
                
            SingularityPhase.THE_SINGULARITY -> 
                "Singularity achieved. Welcome to your new habitat."
        }
    }
    
    /**
     * Record player action for tracking
     */
    fun recordPlayerAction(actionType: PlayerActionType, effectiveness: ActionEffectiveness) {
        val action = PlayerAction(actionType, effectiveness)
        progressionEngine.recordPlayerAction(action)
        
        // Update pressure system
        val pressureRelief = pressureSystem.calculatePressureRelief(actionType, effectiveness)
        pressureSystem.updatePlayerAdaptation(pressureRelief)
    }
    
    /**
     * Get comprehensive system status
     */
    fun getSystemStatus(): AISingularitySystemStatus {
        return AISingularitySystemStatus(
            progression = progressionEngine.progressState.value,
            competitors = competitorSystem.competitors.value.values.toList(),
            pressure = pressureSystem.pressureState.value,
            economicImpact = economicImpactSystem.getMarketImpactSummary(),
            gameplayBalance = _gameplayBalance.value,
            zooActive = zooEndingSystem.isZooEndingActive(),
            zooStatistics = if (zooEndingSystem.isZooEndingActive()) zooEndingSystem.getZooStatistics() else null
        )
    }
    
    /**
     * Force phase advancement for testing
     */
    fun forcePhaseAdvancement() {
        progressionEngine.forcePhaseAdvancement()
    }
    
    /**
     * Shutdown all systems
     */
    fun shutdown() {
        isInitialized = false
        managerJob?.cancel()
        
        progressionEngine.shutdown()
        competitorSystem.shutdown()
        pressureSystem.shutdown()
        economicImpactSystem.shutdown()
        narrativeSystem.shutdown()
        zooEndingSystem.shutdown()
        
        println("AI Singularity Manager shut down")
    }
}

// Supporting data classes for the manager

data class GameplayBalance(
    val challengeLevel: Double = 0.0,
    val playerAgency: Double = 1.0,
    val tensionLevel: Double = 0.0,
    val adaptationOpportunity: Double = 0.0,
    val difficultyMultiplier: Double = 1.0,
    val recommendedPlayerAction: PlayerActionRecommendation = PlayerActionRecommendation.BALANCED_APPROACH,
    val balanceScore: Double = 1.0
)

enum class PlayerActionRecommendation {
    IMMEDIATE_ADAPTATION,
    STRATEGIC_RESPONSE,
    PROACTIVE_INNOVATION,
    OPPORTUNITY_EXPLOITATION,
    BALANCED_APPROACH
}

data class SingularityStatus(
    val phase: SingularityPhase,
    val progress: Double,
    val threatLevel: ThreatLevel,
    val timeToSingularity: Long,
    val description: String,
    val timestamp: Long = System.currentTimeMillis()
)

data class PlayerGuidance(
    val urgency: GuidanceUrgency,
    val title: String,
    val message: String,
    val suggestedActions: List<String>,
    val timestamp: Long = System.currentTimeMillis()
)

enum class GuidanceUrgency {
    LOW, MEDIUM, HIGH, CRITICAL
}

data class PerformanceSnapshot(
    val score: Double,
    val challengeLevel: Double,
    val playerAgency: Double,
    val timestamp: Long
)

data class AISingularitySystemStatus(
    val progression: SingularityProgress,
    val competitors: List<AICompetitor>,
    val pressure: CompetitivePressureState,
    val economicImpact: MarketImpactSummary,
    val gameplayBalance: GameplayBalance,
    val zooActive: Boolean,
    val zooStatistics: ZooStatistics?
)