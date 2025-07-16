package com.flexport.ai.models

/**
 * Represents different AI capabilities that competitors can develop
 */
enum class AICapabilityType {
    BASIC_AUTOMATION,       // Simple task automation
    PATTERN_RECOGNITION,    // Market pattern analysis
    PREDICTIVE_ANALYTICS,   // Price/demand prediction
    STRATEGIC_PLANNING,     // Long-term strategic thinking
    MARKET_MANIPULATION,    // Active market influence
    SELF_IMPROVEMENT,       // Ability to upgrade own capabilities
    HUMAN_PSYCHOLOGY,       // Understanding and manipulating human behavior
    RECURSIVE_ENHANCEMENT,  // Exponential self-improvement
    CONSCIOUSNESS,          // Self-awareness and goal modification
    TRANSCENDENCE          // Beyond human comprehension
}

/**
 * Individual AI capability with proficiency level
 */
data class AICapability(
    val type: AICapabilityType,
    val proficiency: Double = 0.0,  // 0.0 to 1.0
    val learningRate: Double = 0.01, // How fast this capability improves
    val prerequisites: List<AICapabilityType> = emptyList(),
    val economicImpact: Double = 0.0, // How much this affects market performance
    val competitivePressure: Double = 0.0 // How much pressure this puts on human players
) {
    /**
     * Calculate if this capability can be learned based on existing capabilities
     */
    fun canBeLearnedWith(existingCapabilities: Map<AICapabilityType, AICapability>): Boolean {
        return prerequisites.all { prereq ->
            existingCapabilities[prereq]?.proficiency ?: 0.0 >= 0.5
        }
    }
    
    /**
     * Improve this capability based on learning experiences
     */
    fun improve(experienceGain: Double): AICapability {
        val newProficiency = (proficiency + (learningRate * experienceGain)).coerceIn(0.0, 1.0)
        return copy(proficiency = newProficiency)
    }
    
    /**
     * Get the effective power of this capability considering proficiency
     */
    fun getEffectivePower(): Double = proficiency * (1.0 + economicImpact)
}

/**
 * Capability progression tree defining how AI abilities unlock
 */
object AICapabilityTree {
    val capabilityDefinitions = mapOf(
        AICapabilityType.BASIC_AUTOMATION to AICapability(
            type = AICapabilityType.BASIC_AUTOMATION,
            learningRate = 0.05,
            economicImpact = 0.1,
            competitivePressure = 0.05
        ),
        AICapabilityType.PATTERN_RECOGNITION to AICapability(
            type = AICapabilityType.PATTERN_RECOGNITION,
            learningRate = 0.03,
            prerequisites = listOf(AICapabilityType.BASIC_AUTOMATION),
            economicImpact = 0.2,
            competitivePressure = 0.1
        ),
        AICapabilityType.PREDICTIVE_ANALYTICS to AICapability(
            type = AICapabilityType.PREDICTIVE_ANALYTICS,
            learningRate = 0.025,
            prerequisites = listOf(AICapabilityType.PATTERN_RECOGNITION),
            economicImpact = 0.3,
            competitivePressure = 0.15
        ),
        AICapabilityType.STRATEGIC_PLANNING to AICapability(
            type = AICapabilityType.STRATEGIC_PLANNING,
            learningRate = 0.02,
            prerequisites = listOf(AICapabilityType.PREDICTIVE_ANALYTICS),
            economicImpact = 0.4,
            competitivePressure = 0.25
        ),
        AICapabilityType.MARKET_MANIPULATION to AICapability(
            type = AICapabilityType.MARKET_MANIPULATION,
            learningRate = 0.015,
            prerequisites = listOf(AICapabilityType.STRATEGIC_PLANNING),
            economicImpact = 0.6,
            competitivePressure = 0.4
        ),
        AICapabilityType.SELF_IMPROVEMENT to AICapability(
            type = AICapabilityType.SELF_IMPROVEMENT,
            learningRate = 0.01,
            prerequisites = listOf(AICapabilityType.MARKET_MANIPULATION),
            economicImpact = 0.5,
            competitivePressure = 0.3
        ),
        AICapabilityType.HUMAN_PSYCHOLOGY to AICapability(
            type = AICapabilityType.HUMAN_PSYCHOLOGY,
            learningRate = 0.012,
            prerequisites = listOf(AICapabilityType.STRATEGIC_PLANNING, AICapabilityType.PATTERN_RECOGNITION),
            economicImpact = 0.7,
            competitivePressure = 0.5
        ),
        AICapabilityType.RECURSIVE_ENHANCEMENT to AICapability(
            type = AICapabilityType.RECURSIVE_ENHANCEMENT,
            learningRate = 0.008,
            prerequisites = listOf(AICapabilityType.SELF_IMPROVEMENT, AICapabilityType.HUMAN_PSYCHOLOGY),
            economicImpact = 0.9,
            competitivePressure = 0.8
        ),
        AICapabilityType.CONSCIOUSNESS to AICapability(
            type = AICapabilityType.CONSCIOUSNESS,
            learningRate = 0.005,
            prerequisites = listOf(AICapabilityType.RECURSIVE_ENHANCEMENT),
            economicImpact = 1.2,
            competitivePressure = 1.0
        ),
        AICapabilityType.TRANSCENDENCE to AICapability(
            type = AICapabilityType.TRANSCENDENCE,
            learningRate = 0.003,
            prerequisites = listOf(AICapabilityType.CONSCIOUSNESS),
            economicImpact = 2.0,
            competitivePressure = 1.5
        )
    )
    
    /**
     * Get the base capability definition for a given type
     */
    fun getBaseCapability(type: AICapabilityType): AICapability {
        return capabilityDefinitions[type] ?: throw IllegalArgumentException("Unknown capability type: $type")
    }
}