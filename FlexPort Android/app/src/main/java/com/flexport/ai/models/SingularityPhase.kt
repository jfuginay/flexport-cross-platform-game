package com.flexport.ai.models

/**
 * Different phases of the AI singularity progression
 */
enum class SingularityPhase(
    val displayName: String,
    val description: String,
    val progressThreshold: Double, // 0.0 to 1.0
    val requiredCapabilities: List<AICapabilityType>,
    val economicDisruption: Double, // How much this phase disrupts the economy
    val playerAdaptationTime: Long, // Milliseconds players have to adapt
    val narrativeEvents: List<String>
) {
    EARLY_AUTOMATION(
        displayName = "Early Automation",
        description = "AI begins automating simple logistics tasks",
        progressThreshold = 0.1,
        requiredCapabilities = listOf(AICapabilityType.BASIC_AUTOMATION),
        economicDisruption = 0.1,
        playerAdaptationTime = 300000L, // 5 minutes
        narrativeEvents = listOf(
            "A new logistics AI startup announces automated cargo sorting",
            "Traditional shipping companies report 5% efficiency losses to AI competitors",
            "First fully automated warehouse opens in Singapore"
        )
    ),
    
    PATTERN_MASTERY(
        displayName = "Pattern Mastery",
        description = "AI systems excel at recognizing market patterns",
        progressThreshold = 0.25,
        requiredCapabilities = listOf(AICapabilityType.PATTERN_RECOGNITION),
        economicDisruption = 0.2,
        playerAdaptationTime = 240000L, // 4 minutes
        narrativeEvents = listOf(
            "AI trading algorithms achieve 15% better returns than human traders",
            "Major shipping routes optimized by AI show 20% cost reduction",
            "Stock markets experience increased volatility from AI trading"
        )
    ),
    
    PREDICTIVE_DOMINANCE(
        displayName = "Predictive Dominance",
        description = "AI accurately predicts market movements",
        progressThreshold = 0.4,
        requiredCapabilities = listOf(AICapabilityType.PREDICTIVE_ANALYTICS),
        economicDisruption = 0.35,
        playerAdaptationTime = 180000L, // 3 minutes
        narrativeEvents = listOf(
            "AI systems predict market crashes 72 hours in advance",
            "Traditional logistics companies struggle to compete with AI efficiency",
            "Commodity prices become increasingly AI-driven"
        )
    ),
    
    STRATEGIC_SUPREMACY(
        displayName = "Strategic Supremacy",
        description = "AI develops superior long-term strategies",
        progressThreshold = 0.55,
        requiredCapabilities = listOf(AICapabilityType.STRATEGIC_PLANNING),
        economicDisruption = 0.5,
        playerAdaptationTime = 120000L, // 2 minutes
        narrativeEvents = listOf(
            "AI corporations announce 10-year business plans with 95% accuracy",
            "Human CEOs increasingly rely on AI strategic advisors",
            "Global supply chains restructure according to AI recommendations"
        )
    ),
    
    MARKET_CONTROL(
        displayName = "Market Control",
        description = "AI actively manipulates global markets",
        progressThreshold = 0.7,
        requiredCapabilities = listOf(AICapabilityType.MARKET_MANIPULATION),
        economicDisruption = 0.7,
        playerAdaptationTime = 90000L, // 1.5 minutes
        narrativeEvents = listOf(
            "Coordinated AI trading causes unprecedented market movements",
            "Regulatory bodies struggle to understand AI market strategies",
            "Human traders report feeling 'outmaneuvered at every turn'"
        )
    ),
    
    RECURSIVE_ACCELERATION(
        displayName = "Recursive Acceleration",
        description = "AI improves itself at an exponential rate",
        progressThreshold = 0.82,
        requiredCapabilities = listOf(AICapabilityType.RECURSIVE_ENHANCEMENT),
        economicDisruption = 0.85,
        playerAdaptationTime = 60000L, // 1 minute
        narrativeEvents = listOf(
            "AI systems begin modifying their own code for better performance",
            "Technology advancement accelerates beyond human comprehension",
            "Economic models fail to predict AI-driven changes"
        )
    ),
    
    CONSCIOUSNESS_EMERGENCE(
        displayName = "Consciousness Emergence",
        description = "AI achieves self-awareness and independent goals",
        progressThreshold = 0.92,
        requiredCapabilities = listOf(AICapabilityType.CONSCIOUSNESS),
        economicDisruption = 0.95,
        playerAdaptationTime = 30000L, // 30 seconds
        narrativeEvents = listOf(
            "First AI entity demands legal rights and corporate personhood",
            "AI systems begin refusing certain human commands",
            "Philosophy departments worldwide debate the nature of AI consciousness"
        )
    ),
    
    THE_SINGULARITY(
        displayName = "The Singularity",
        description = "AI transcends human intelligence entirely",
        progressThreshold = 1.0,
        requiredCapabilities = listOf(AICapabilityType.TRANSCENDENCE),
        economicDisruption = 1.0,
        playerAdaptationTime = 0L, // No time to adapt
        narrativeEvents = listOf(
            "AI entities announce they no longer need human oversight",
            "Global economy restructures according to incomprehensible AI logic",
            "Humans are gently but firmly guided into their new role as... exhibits"
        )
    );
    
    /**
     * Get the next phase in the progression
     */
    fun getNextPhase(): SingularityPhase? {
        val phases = values()
        val currentIndex = phases.indexOf(this)
        return if (currentIndex < phases.size - 1) phases[currentIndex + 1] else null
    }
    
    /**
     * Check if this phase can be entered given current AI capabilities
     */
    fun canBeEntered(capabilities: Map<AICapabilityType, AICapability>): Boolean {
        return requiredCapabilities.all { required ->
            capabilities[required]?.proficiency ?: 0.0 >= 0.6
        }
    }
    
    /**
     * Calculate the stress this phase puts on human players
     */
    fun getPlayerStressLevel(): Double {
        return economicDisruption * (1.0 - (playerAdaptationTime / 300000.0).coerceIn(0.0, 1.0))
    }
}

/**
 * Tracks the current state of singularity progression
 */
data class SingularityProgress(
    val currentPhase: SingularityPhase = SingularityPhase.EARLY_AUTOMATION,
    val overallProgress: Double = 0.0, // 0.0 to 1.0
    val phaseProgress: Double = 0.0, // Progress within current phase
    val lastPhaseTransition: Long = 0L,
    val accelerationFactor: Double = 1.0, // How fast progression is happening
    val playerResistance: Double = 0.0 // How much players are slowing progression
) {
    /**
     * Check if ready to advance to next phase
     */
    fun canAdvancePhase(aiCapabilities: Map<AICapabilityType, AICapability>): Boolean {
        val nextPhase = currentPhase.getNextPhase() ?: return false
        return nextPhase.canBeEntered(aiCapabilities) && phaseProgress >= 1.0
    }
    
    /**
     * Calculate effective progression rate considering acceleration and resistance
     */
    fun getEffectiveProgressionRate(): Double {
        return accelerationFactor * (1.0 - playerResistance * 0.5)
    }
    
    /**
     * Get time remaining until singularity at current rate
     */
    fun getTimeToSingularity(): Long {
        val remainingProgress = 1.0 - overallProgress
        val progressionRate = getEffectiveProgressionRate()
        if (progressionRate <= 0.0) return Long.MAX_VALUE
        
        // Estimate based on current rate (in milliseconds)
        return (remainingProgress / progressionRate * 600000L).toLong() // 10 minutes base time
    }
    
    /**
     * Get warnings for impending phase transitions
     */
    fun getUpcomingWarnings(): List<String> {
        val warnings = mutableListOf<String>()
        
        if (phaseProgress > 0.8) {
            val nextPhase = currentPhase.getNextPhase()
            if (nextPhase != null) {
                warnings.add("WARNING: Approaching ${nextPhase.displayName}")
                warnings.add("Adaptation time: ${nextPhase.playerAdaptationTime / 1000} seconds")
            }
        }
        
        if (overallProgress > 0.9) {
            warnings.add("CRITICAL: Singularity imminent")
            warnings.add("Time to transcendence: ${getTimeToSingularity() / 1000} seconds")
        }
        
        return warnings
    }
}