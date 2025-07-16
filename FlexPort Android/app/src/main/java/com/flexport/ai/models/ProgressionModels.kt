package com.flexport.ai.models

/**
 * Progression event types for AI singularity progression
 */
enum class ProgressionEventType {
    PHASE_TRANSITION,
    AI_EVOLUTION,
    PLAYER_RESISTANCE,
    ACCELERATION_CHANGE
}

/**
 * Phase transition for narrative system
 */
data class PhaseTransition(
    val fromPhase: SingularityPhase,
    val toPhase: SingularityPhase,
    val timestamp: Long,
    val triggeringAIs: List<AICompetitor>
)

/**
 * Competitive pressure state
 */
data class CompetitivePressureState(
    val totalPressure: Double = 0.0,
    val pressureBySource: Map<PressureSource, Double> = emptyMap(),
    val pressureGrowthRate: Double = 0.0,
    val playerAdaptation: Double = 0.0,
    val criticalThreshold: Double = 0.8,
    val trend: PressureTrend = PressureTrend.STABLE,
    val level: Double = 0.0,
    val sources: Map<PressureSource, Double> = emptyMap(),
    val lastUpdate: Long = System.currentTimeMillis(),
    val timestamp: Long = System.currentTimeMillis()
)

/**
 * Pressure sources with different impact multipliers
 */
enum class PressureSource(val multiplier: Double) {
    TECHNOLOGICAL(1.2),
    ECONOMIC(1.0),
    TEMPORAL(1.5),
    COMPETITIVE(1.0),
    STRATEGIC(1.1),
    PLAYER_ACTIONS(0.8),
    MARKET_CONDITIONS(1.0),
    TECHNOLOGICAL_ADVANCEMENT(1.3),
    REGULATORY_CHANGES(0.9),
    COMPETITIVE_LANDSCAPE(1.1),
    // Additional sources from individual file
    MARKET_AUTOMATION(1.5),
    PRICE_MANIPULATION(2.0),
    SUPPLY_CHAIN_CONTROL(1.8),
    REGULATORY_BYPASS(1.2),
    ECONOMIC_MODELING(1.3),
    INFRASTRUCTURE_CONTROL(2.5),
    RESOURCE_MONOPOLIZATION(2.2),
    MARKET(0.8)
}

/**
 * Pressure trend direction
 */
enum class PressureTrend {
    DECREASING,
    STABLE,
    INCREASING,
    ACCELERATING
}

/**
 * Economic health status
 */
enum class EconomicHealth {
    CRITICAL,
    POOR,
    FAIR,
    GOOD,
    EXCELLENT
}

/**
 * Market impact summary
 */
data class MarketImpactSummary(
    val overallEconomicShift: Double,
    val affectedMarkets: Int,
    val averageVolatility: Double,
    val timestamp: Long
)

/**
 * Player action types
 */
enum class PlayerActionType {
    // Economic actions
    INVEST_IN_RESEARCH,
    FORM_ALLIANCE,
    IMPLEMENT_REGULATION,
    SUBSIDIZE_HUMAN_LABOR,
    MARKET_INTERVENTION,
    RESEARCH_DEVELOPMENT,
    REGULATORY_ACTION,
    STRATEGIC_ALLIANCE,
    
    // Direct AI interaction
    HACK_AI_SYSTEM,
    NEGOTIATE_WITH_AI,
    SABOTAGE_AI_INFRASTRUCTURE,
    
    // Defensive actions
    BUILD_FIREWALL,
    CREATE_AI_FREE_ZONE,
    DEVELOP_COUNTERMEASURES,
    
    // Adaptation actions
    AUGMENT_WORKFORCE,
    RESTRUCTURE_BUSINESS,
    EMBRACE_AI_PARTNERSHIP,
    
    // Simple action types for compatibility
    RESIST_AI,
    COLLABORATE_AI,
    INNOVATE_DEFENSE,
    ACCELERATE_AI
}

/**
 * Action effectiveness
 */
enum class ActionEffectiveness(val multiplier: Double) {
    CRITICAL_FAILURE(-0.2),
    FAILURE(-0.1),
    MINIMAL(0.1),
    LOW(0.3),
    MEDIUM(0.5),
    HIGH(0.7),
    EXCEPTIONAL(0.9),
    VERY_LOW(0.1),
    VERY_HIGH(0.9)
}

/**
 * Player action
 */
data class PlayerAction(
    val type: PlayerActionType,
    val effectiveness: ActionEffectiveness,
    val targetEntityId: String? = null,
    val magnitude: Double = 1.0,
    val timestamp: Long = System.currentTimeMillis()
)

/**
 * Zoo statistics for ending
 */
data class ZooStatistics(
    val totalVisitors: Long,
    val averageSatisfaction: Double,
    val revenue: Double,
    val exhibitRating: Double,
    val humanActivities: Map<String, Int>
)

/**
 * Progression event
 */
data class ProgressionEvent(
    val type: ProgressionEventType,
    val phase: SingularityPhase? = null,
    val data: Map<String, Any> = emptyMap(),
    val timestamp: Long = System.currentTimeMillis()
)

/**
 * Disruption level
 */
enum class DisruptionLevel {
    MINIMAL,
    LOW,
    MODERATE,
    HIGH,
    SEVERE,
    CATASTROPHIC
}

/**
 * Market disruption
 */
data class MarketDisruption(
    val market: String,
    val severity: DisruptionLevel,
    val impact: Double,
    val description: String,
    val timestamp: Long = System.currentTimeMillis()
)

/**
 * AI market modifier
 */
data class AIMarketModifier(
    val type: ModifierType,
    val magnitude: Double,
    val duration: Long,
    val market: String = "",
    val value: Double = 0.0,
    val timestamp: Long = System.currentTimeMillis()
)

/**
 * Modifier type
 */
enum class ModifierType {
    PRICE_MANIPULATION,
    SUPPLY_OPTIMIZATION,
    DEMAND_CREATION,
    MARKET_DISRUPTION,
    EFFICIENCY_BOOST
}

/**
 * Pressure event (comprehensive definition)
 */
data class PressureEvent(
    val type: PressureEventType,
    val source: PressureSource? = null,
    val magnitude: Double,
    val description: String,
    val timestamp: Long = System.currentTimeMillis()
) {
    // Convenience constructor for string-based type (for compatibility)
    constructor(
        type: String,
        magnitude: Double,
        description: String,
        timestamp: Long = System.currentTimeMillis()
    ) : this(
        type = when (type) {
            "PRESSURE_INCREASE" -> PressureEventType.PRESSURE_INCREASE
            "PRESSURE_DECREASE" -> PressureEventType.PRESSURE_RELIEF
            "EXTERNAL_PRESSURE" -> PressureEventType.PRESSURE_INCREASE
            "PLAYER_ADAPTATION" -> PressureEventType.ADAPTATION_SUCCESS
            else -> PressureEventType.PRESSURE_INCREASE
        },
        source = null,
        magnitude = magnitude,
        description = description,
        timestamp = timestamp
    )
}

/**
 * Pressure event types
 */
enum class PressureEventType {
    PRESSURE_INCREASE,
    PRESSURE_RELIEF,
    THRESHOLD_WARNING,
    THRESHOLD_EXCEEDED,
    ADAPTATION_SUCCESS
}

/**
 * Pressure snapshot
 */
data class PressureSnapshot(
    val totalPressure: Double,
    val pressureBySource: Map<PressureSource, Double>,
    val timestamp: Long
)

/**
 * AI economic impact state
 */
data class AIEconomicImpactState(
    val overallEconomicShift: Double = 0.0,
    val marketVolatility: Double = 0.0,
    val unemploymentImpact: Double = 0.0,
    val innovationRate: Double = 0.0,
    val marketModifiers: Map<String, List<AIMarketModifier>> = emptyMap(),
    val totalImpact: Double = 0.0,
    val marketDisruptions: List<MarketDisruption> = emptyList(),
    val economicHealth: EconomicHealth = EconomicHealth.GOOD,
    val lastUpdate: Long = System.currentTimeMillis(),
    val timestamp: Long = System.currentTimeMillis()
)