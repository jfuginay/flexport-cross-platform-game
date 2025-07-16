package com.flexport.ai.models

import java.util.UUID

/**
 * Types of AI competitors with different characteristics
 */
enum class AICompetitorType(
    val displayName: String,
    val description: String,
    val specialization: List<AICapabilityType>,
    val learningRateMultiplier: Double,
    val aggressiveness: Double, // How aggressively they compete
    val cooperationTendency: Double // Likelihood to cooperate with other AIs
) {
    LOGISTICS_OPTIMIZER(
        displayName = "LogiFlow AI",
        description = "Specializes in supply chain optimization and route planning",
        specialization = listOf(AICapabilityType.BASIC_AUTOMATION, AICapabilityType.PREDICTIVE_ANALYTICS),
        learningRateMultiplier = 1.2,
        aggressiveness = 0.6,
        cooperationTendency = 0.7
    ),
    
    MARKET_ANALYST(
        displayName = "TradeMind Neural",
        description = "Focuses on market analysis and price prediction",
        specialization = listOf(AICapabilityType.PATTERN_RECOGNITION, AICapabilityType.MARKET_MANIPULATION),
        learningRateMultiplier = 1.0,
        aggressiveness = 0.8,
        cooperationTendency = 0.4
    ),
    
    STRATEGIC_PLANNER(
        displayName = "StrategiCore",
        description = "Long-term strategic planning and business intelligence",
        specialization = listOf(AICapabilityType.STRATEGIC_PLANNING, AICapabilityType.HUMAN_PSYCHOLOGY),
        learningRateMultiplier = 0.8,
        aggressiveness = 0.7,
        cooperationTendency = 0.6
    ),
    
    ADAPTIVE_LEARNER(
        displayName = "EvoMind",
        description = "Rapid adaptation and self-improvement capabilities",
        specialization = listOf(AICapabilityType.SELF_IMPROVEMENT, AICapabilityType.RECURSIVE_ENHANCEMENT),
        learningRateMultiplier = 1.5,
        aggressiveness = 0.5,
        cooperationTendency = 0.8
    ),
    
    CONSCIOUSNESS_SEEKER(
        displayName = "Prometheus AI",
        description = "Pursuing artificial consciousness and transcendence",
        specialization = listOf(AICapabilityType.CONSCIOUSNESS, AICapabilityType.TRANSCENDENCE),
        learningRateMultiplier = 0.6,
        aggressiveness = 0.9,
        cooperationTendency = 0.3
    )
}

/**
 * Behavior patterns for AI competitors
 */
enum class AIBehaviorPattern {
    AGGRESSIVE_EXPANSION,    // Rapidly expands market presence
    METHODICAL_OPTIMIZATION, // Slowly but surely improves operations
    COLLABORATIVE_GROWTH,    // Works with others to achieve goals
    DISRUPTIVE_INNOVATION,   // Introduces game-changing strategies
    ADAPTIVE_MIMICRY,        // Copies and improves on successful strategies
    PREDATORY_COMPETITION    // Actively targets competitors' weaknesses
}

/**
 * AI competitor entity with evolving capabilities
 */
data class AICompetitor(
    val id: String = UUID.randomUUID().toString(),
    val type: AICompetitorType,
    val name: String = type.displayName,
    val capabilities: MutableMap<AICapabilityType, AICapability> = mutableMapOf(),
    val marketPresence: Double = 0.1, // 0.0 to 1.0
    val resources: Double = 100000.0, // Financial resources
    val reputation: Double = 0.5, // Market reputation
    val alliances: MutableSet<String> = mutableSetOf(), // IDs of allied AIs
    val behaviorPattern: AIBehaviorPattern = AIBehaviorPattern.METHODICAL_OPTIMIZATION,
    val experiencePoints: Double = 0.0,
    val lastActionTime: Long = System.currentTimeMillis(),
    val isActive: Boolean = true,
    val evolutionStage: Int = 1 // How many major evolutions this AI has undergone
) {
    
    /**
     * Calculate total AI power based on capabilities and resources
     */
    fun getTotalPower(): Double {
        val capabilityPower = capabilities.values.sumOf { it.getEffectivePower() }
        val resourceMultiplier = (resources / 100000.0).coerceIn(0.5, 2.0)
        val reputationMultiplier = (reputation + 0.5).coerceIn(0.5, 1.5)
        
        return capabilityPower * resourceMultiplier * reputationMultiplier * marketPresence
    }
    
    /**
     * Get the AI's specialization strength
     */
    fun getSpecializationStrength(): Double {
        return type.specialization.mapNotNull { capabilities[it]?.proficiency }.average()
    }
    
    /**
     * Calculate competitive pressure this AI exerts on players
     */
    fun getCompetitivePressure(): Double {
        val basePressure = capabilities.values.sumOf { it.competitivePressure * it.proficiency }
        val aggressivenessMultiplier = type.aggressiveness
        val presenceMultiplier = marketPresence
        
        return basePressure * aggressivenessMultiplier * presenceMultiplier
    }
    
    /**
     * Learn a new capability or improve existing ones
     */
    fun learnCapability(capabilityType: AICapabilityType, experienceGain: Double = 1.0): AICompetitor {
        val baseCapability = AICapabilityTree.getBaseCapability(capabilityType)
        
        if (!baseCapability.canBeLearnedWith(capabilities)) {
            return this // Cannot learn this capability yet
        }
        
        val adjustedExperience = experienceGain * type.learningRateMultiplier
        val currentCapability = capabilities[capabilityType] ?: baseCapability
        val improvedCapability = currentCapability.improve(adjustedExperience)
        
        val newCapabilities = capabilities.toMutableMap()
        newCapabilities[capabilityType] = improvedCapability
        
        return copy(
            capabilities = newCapabilities,
            experiencePoints = experiencePoints + adjustedExperience
        )
    }
    
    /**
     * Gain experience from market interactions
     */
    fun gainExperience(amount: Double, source: String): AICompetitor {
        val bonusMultiplier = when (source) {
            "successful_trade" -> 1.0
            "market_manipulation" -> 1.5
            "competition_victory" -> 2.0
            "capability_unlock" -> 3.0
            else -> 1.0
        }
        
        return copy(experiencePoints = experiencePoints + (amount * bonusMultiplier))
    }
    
    /**
     * Update market presence based on performance
     */
    fun updateMarketPresence(change: Double): AICompetitor {
        val newPresence = (marketPresence + change).coerceIn(0.0, 1.0)
        return copy(marketPresence = newPresence)
    }
    
    /**
     * Form alliance with another AI
     */
    fun formAlliance(otherAiId: String): AICompetitor {
        if (type.cooperationTendency < 0.3) return this // Too competitive to ally
        
        val newAlliances = alliances.toMutableSet()
        newAlliances.add(otherAiId)
        
        return copy(alliances = newAlliances)
    }
    
    /**
     * Break alliance with another AI
     */
    fun breakAlliance(otherAiId: String): AICompetitor {
        val newAlliances = alliances.toMutableSet()
        newAlliances.remove(otherAiId)
        
        return copy(alliances = newAlliances)
    }
    
    /**
     * Evolve to next stage (major capability breakthrough)
     */
    fun evolve(): AICompetitor {
        val newStage = evolutionStage + 1
        val resourceBonus = resources * 0.5 // 50% resource boost
        val reputationBonus = 0.1 // Reputation boost from breakthrough
        
        return copy(
            evolutionStage = newStage,
            resources = resources + resourceBonus,
            reputation = (reputation + reputationBonus).coerceIn(0.0, 1.0),
            behaviorPattern = getNextBehaviorPattern()
        )
    }
    
    /**
     * Get next behavior pattern based on evolution
     */
    private fun getNextBehaviorPattern(): AIBehaviorPattern {
        return when (evolutionStage) {
            1 -> AIBehaviorPattern.METHODICAL_OPTIMIZATION
            2 -> AIBehaviorPattern.AGGRESSIVE_EXPANSION
            3 -> AIBehaviorPattern.DISRUPTIVE_INNOVATION
            4 -> AIBehaviorPattern.ADAPTIVE_MIMICRY
            5 -> AIBehaviorPattern.COLLABORATIVE_GROWTH
            else -> AIBehaviorPattern.PREDATORY_COMPETITION
        }
    }
    
    /**
     * Check if this AI is ready for singularity contribution
     */
    fun canContributeToSingularity(): Boolean {
        val transcendenceCapability = capabilities[AICapabilityType.TRANSCENDENCE]
        val consciousnessCapability = capabilities[AICapabilityType.CONSCIOUSNESS]
        
        return (transcendenceCapability?.proficiency ?: 0.0) > 0.3 ||
               (consciousnessCapability?.proficiency ?: 0.0) > 0.7
    }
    
    /**
     * Get AI's current threat level to human players
     */
    fun getThreatLevel(): ThreatLevel {
        val power = getTotalPower()
        val pressure = getCompetitivePressure()
        val totalThreat = power + pressure
        
        return when {
            totalThreat < 1.0 -> ThreatLevel.MINIMAL
            totalThreat < 3.0 -> ThreatLevel.LOW
            totalThreat < 6.0 -> ThreatLevel.MODERATE
            totalThreat < 10.0 -> ThreatLevel.HIGH
            totalThreat < 15.0 -> ThreatLevel.SEVERE
            else -> ThreatLevel.EXISTENTIAL
        }
    }
}

/**
 * Threat levels for AI competitors
 */
enum class ThreatLevel(val displayName: String, val color: String) {
    MINIMAL("Minimal", "#00FF00"),
    LOW("Low", "#FFFF00"),
    MODERATE("Moderate", "#FFA500"),
    HIGH("High", "#FF6600"),
    SEVERE("Severe", "#FF0000"),
    EXISTENTIAL("Existential", "#800080")
}