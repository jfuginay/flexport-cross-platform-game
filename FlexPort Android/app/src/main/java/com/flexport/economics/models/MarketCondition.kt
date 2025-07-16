package com.flexport.economics.models

import kotlinx.serialization.Serializable

/**
 * Represents the current condition of a market segment
 */
@Serializable
data class MarketCondition(
    val name: String,
    val demandMultiplier: Double = 1.0,  // 0.5 = low demand, 2.0 = high demand
    val supplyMultiplier: Double = 1.0,   // 0.5 = low supply, 2.0 = high supply
    val volatility: Double = 0.1,         // How much the market fluctuates
    val trend: MarketTrend = MarketTrend.STABLE,
    val lastUpdate: Long = System.currentTimeMillis()
)

@Serializable
enum class MarketTrend {
    RISING,
    FALLING,
    STABLE,
    VOLATILE
}