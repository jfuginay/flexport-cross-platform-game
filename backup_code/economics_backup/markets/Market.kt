package com.flexport.economics.markets

/**
 * Base interface for all market types in the FlexPort economic system.
 * Markets handle supply and demand dynamics for their respective assets/commodities.
 */
interface Market {
    /**
     * Update market state based on time delta
     * @param deltaTime Time passed since last update in seconds
     */
    fun update(deltaTime: Float)
    
    /**
     * Clear the market's outstanding orders at the end of a trading period
     */
    fun clearMarket()
    
    /**
     * Get current market statistics
     */
    fun getMarketStats(): MarketStats
    
    /**
     * Process a market event that might affect prices or supply/demand
     */
    fun processEvent(event: MarketEvent)
}

/**
 * Common market statistics
 */
data class MarketStats(
    val totalSupply: Double,
    val totalDemand: Double,
    val currentPrice: Double,
    val priceChange24h: Double,
    val volume24h: Double,
    val liquidityDepth: Double
)

/**
 * Base class for market events
 */
sealed class MarketEvent {
    abstract val timestamp: Long
    abstract val impact: MarketImpact
}

/**
 * Represents the impact level of a market event
 */
enum class MarketImpact {
    LOW,
    MEDIUM,
    HIGH,
    CRITICAL
}

/**
 * Supply and demand representation
 */
data class SupplyDemand(
    val quantity: Double,
    val pricePerUnit: Double,
    val elasticity: Double = 1.0
)

/**
 * Order types in markets
 */
sealed class Order {
    abstract val id: String
    abstract val quantity: Double
    abstract val pricePerUnit: Double
    abstract val timestamp: Long
    
    data class BuyOrder(
        override val id: String,
        override val quantity: Double,
        override val pricePerUnit: Double,
        override val timestamp: Long,
        val buyerId: String
    ) : Order()
    
    data class SellOrder(
        override val id: String,
        override val quantity: Double,
        override val pricePerUnit: Double,
        override val timestamp: Long,
        val sellerId: String
    ) : Order()
}