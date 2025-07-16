package com.flexport.ai.models

/**
 * Economic state for the economic engine
 */
data class EconomicState(
    val totalMarketValue: Double = 1000000.0,
    val marketVolatility: Double = 0.1,
    val economicHealth: EconomicHealth = EconomicHealth.GOOD,
    val unemploymentRate: Double = 0.05,
    val inflationRate: Double = 0.02,
    val gdpGrowthRate: Double = 0.03,
    val lastUpdate: Long = System.currentTimeMillis()
)

/**
 * Market update notification
 */
data class MarketUpdate(
    val marketId: String,
    val priceChange: Double,
    val volumeChange: Double,
    val timestamp: Long = System.currentTimeMillis()
)

/**
 * Economic event notification
 */
data class EconomicEventNotification(
    val eventType: EconomicEventType,
    val severity: EconomicEventSeverity,
    val description: String,
    val impact: Double,
    val affectedMarkets: List<String> = emptyList(),
    val timestamp: Long = System.currentTimeMillis()
)

/**
 * Economic event types
 */
enum class EconomicEventType {
    MARKET_CRASH,
    ECONOMIC_BOOM,
    SUPPLY_CHAIN_DISRUPTION,
    REGULATORY_CHANGE,
    AI_AUTOMATION_WAVE,
    UNEMPLOYMENT_SPIKE,
    INFLATION_SURGE,
    DEFLATION_RISK
}

/**
 * Economic event severity levels
 */
enum class EconomicEventSeverity {
    LOW,
    MEDIUM,
    HIGH,
    CRITICAL
}

// Most other economic models are consolidated in ProgressionModels.kt
// This file contains core economic engine models