package com.flexport.economics.markets

import com.flexport.economics.models.Commodity
import com.flexport.economics.models.CommodityType
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.exp
import kotlin.math.ln
import kotlin.math.pow

/**
 * Market for trading commodities and goods.
 * Handles supply and demand dynamics for various commodity types.
 */
class GoodsMarket(
    private val commodityType: CommodityType,
    initialPrice: Double = 100.0,
    private val baseElasticity: Double = 1.2
) : AbstractMarket() {
    
    init {
        currentPrice = initialPrice
    }
    
    // Storage costs affect market dynamics
    private var storageCostPerUnit = 0.1
    private var spoilageRate = when (commodityType) {
        CommodityType.FOOD -> 0.05 // 5% spoilage per day
        CommodityType.PHARMACEUTICALS -> 0.02 // 2% spoilage per day
        else -> 0.0 // No spoilage for other goods
    }
    
    // Market-specific events
    private val supplyShocks = mutableListOf<SupplyShock>()
    private val demandShocks = mutableListOf<DemandShock>()
    
    // Seasonal effects
    private var seasonalMultiplier = 1.0
    
    /**
     * Execute trade with commodity-specific logic
     */
    override fun executeTrade(
        buyOrder: Order.BuyOrder,
        sellOrder: Order.SellOrder,
        price: Double,
        quantity: Double
    ) {
        // In a real implementation, this would update player inventories
        // For now, we'll just track the trade
        val trade = CommodityTrade(
            buyerId = buyOrder.buyerId,
            sellerId = sellOrder.sellerId,
            commodityType = commodityType,
            quantity = quantity,
            pricePerUnit = price,
            timestamp = System.currentTimeMillis()
        )
        
        // Notify trade listeners (would be implemented with event system)
        onTradeExecuted(trade)
    }
    
    /**
     * Update market with commodity-specific dynamics
     */
    override fun update(deltaTime: Float) {
        // Apply spoilage to existing sell orders
        if (spoilageRate > 0) {
            applySpoilage(deltaTime)
        }
        
        // Process supply and demand shocks
        processShocks(deltaTime)
        
        // Update seasonal effects
        updateSeasonalEffects()
        
        // Base market update
        super.update(deltaTime)
        
        // Adjust price based on storage costs
        currentPrice = adjustPriceForStorageCosts(currentPrice)
    }
    
    /**
     * Apply spoilage to perishable goods
     */
    private fun applySpoilage(deltaTime: Float) {
        val spoilageAmount = spoilageRate * (deltaTime / 86400f) // Convert to daily rate
        
        sellOrders.values.forEach { order ->
            val newQuantity = order.quantity * (1 - spoilageAmount)
            if (newQuantity < 0.01) {
                // Remove completely spoiled orders
                sellOrders.remove(order.id)
            } else {
                // Update order with reduced quantity
                sellOrders[order.id] = order.copy(quantity = newQuantity)
            }
        }
    }
    
    /**
     * Process active supply and demand shocks
     */
    private fun processShocks(deltaTime: Float) {
        // Remove expired shocks
        val currentTime = System.currentTimeMillis()
        supplyShocks.removeAll { it.endTime < currentTime }
        demandShocks.removeAll { it.endTime < currentTime }
        
        // Apply active shocks to price discovery
        val supplyMultiplier = supplyShocks.fold(1.0) { acc, shock -> 
            acc * shock.multiplier 
        }
        val demandMultiplier = demandShocks.fold(1.0) { acc, shock -> 
            acc * shock.multiplier 
        }
        
        // Adjust current price based on shocks
        if (supplyMultiplier != 1.0 || demandMultiplier != 1.0) {
            val shockEffect = demandMultiplier / supplyMultiplier
            currentPrice *= (1.0 + (shockEffect - 1.0) * 0.1) // Dampen shock effects
        }
    }
    
    /**
     * Update seasonal effects based on commodity type
     */
    private fun updateSeasonalEffects() {
        val dayOfYear = (System.currentTimeMillis() / 86400000 % 365).toInt()
        
        seasonalMultiplier = when (commodityType) {
            CommodityType.FOOD -> {
                // Food demand peaks in winter, supply peaks in harvest season
                1.0 + 0.3 * kotlin.math.sin(2 * Math.PI * dayOfYear / 365 - Math.PI / 2)
            }
            CommodityType.FUEL -> {
                // Fuel demand peaks in winter for heating
                1.0 + 0.2 * kotlin.math.cos(2 * Math.PI * dayOfYear / 365)
            }
            CommodityType.CLOTHING -> {
                // Clothing has seasonal fashion cycles
                1.0 + 0.15 * kotlin.math.sin(4 * Math.PI * dayOfYear / 365)
            }
            else -> 1.0
        }
    }
    
    /**
     * Adjust price for storage costs
     */
    private fun adjustPriceForStorageCosts(basePrice: Double): Double {
        // Higher inventory levels increase storage pressure, reducing prices
        val inventoryLevel = sellOrders.values.sumOf { it.quantity }
        val storagePressure = 1.0 - (storageCostPerUnit * ln(1.0 + inventoryLevel / 1000.0))
        return basePrice * storagePressure.coerceIn(0.8, 1.0)
    }
    
    /**
     * Add a supply shock event
     */
    fun addSupplyShock(description: String, multiplier: Double, durationMillis: Long) {
        supplyShocks.add(SupplyShock(
            description = description,
            multiplier = multiplier,
            startTime = System.currentTimeMillis(),
            endTime = System.currentTimeMillis() + durationMillis
        ))
    }
    
    /**
     * Add a demand shock event
     */
    fun addDemandShock(description: String, multiplier: Double, durationMillis: Long) {
        demandShocks.add(DemandShock(
            description = description,
            multiplier = multiplier,
            startTime = System.currentTimeMillis(),
            endTime = System.currentTimeMillis() + durationMillis
        ))
    }
    
    /**
     * Get commodity-specific market data
     */
    fun getCommodityMarketData(): CommodityMarketData {
        return CommodityMarketData(
            commodityType = commodityType,
            currentPrice = currentPrice,
            inventoryLevel = sellOrders.values.sumOf { it.quantity },
            demandLevel = buyOrders.values.sumOf { it.quantity },
            spoilageRate = spoilageRate,
            storageCostPerUnit = storageCostPerUnit,
            seasonalMultiplier = seasonalMultiplier,
            activeSupplyShocks = supplyShocks.size,
            activeDemandShocks = demandShocks.size
        )
    }
    
    override fun processEvent(event: MarketEvent) {
        when (event) {
            is CommodityMarketEvent -> {
                when (event) {
                    is CommodityMarketEvent.HarvestSeason -> {
                        // Increase supply during harvest
                        addSupplyShock("Harvest Season", 1.5, 30 * 24 * 60 * 60 * 1000L)
                    }
                    is CommodityMarketEvent.NaturalDisaster -> {
                        // Reduce supply due to disaster
                        addSupplyShock("Natural Disaster", 0.3, 7 * 24 * 60 * 60 * 1000L)
                    }
                    is CommodityMarketEvent.TradeEmbargo -> {
                        // Reduce both supply and increase demand
                        addSupplyShock("Trade Embargo", 0.5, event.durationMillis)
                        addDemandShock("Trade Embargo", 1.3, event.durationMillis)
                    }
                    is CommodityMarketEvent.TechnologicalBreakthrough -> {
                        // Increase supply efficiency
                        addSupplyShock("Tech Breakthrough", 1.2, Long.MAX_VALUE)
                        storageCostPerUnit *= 0.8 // Reduce storage costs
                    }
                }
            }
            else -> {
                // Handle other event types if needed
            }
        }
    }
    
    /**
     * Calculate price based on advanced supply-demand curves
     */
    override fun discoverPrice(): Double {
        val basePrice = super.discoverPrice()
        
        // Apply commodity-specific adjustments
        val elasticityAdjusted = applyElasticity(
            basePrice,
            getTotalSupply() / (getTotalDemand() + 1.0),
            baseElasticity * seasonalMultiplier
        )
        
        // Apply market depth effects (deeper markets are more stable)
        val depthStabilizer = 1.0 / (1.0 + calculateLiquidityDepth() / 10000.0)
        val volatility = 0.02 * depthStabilizer // 2% base volatility, reduced by depth
        
        // Add some random walk for realism
        val randomWalk = 1.0 + (Math.random() - 0.5) * volatility
        
        return elasticityAdjusted * randomWalk
    }
    
    private fun getTotalSupply(): Double = sellOrders.values.sumOf { it.quantity }
    private fun getTotalDemand(): Double = buyOrders.values.sumOf { it.quantity }
    
    /**
     * Callback for trade execution
     */
    private fun onTradeExecuted(trade: CommodityTrade) {
        // This would be connected to the game's event system
        // For now, it's a placeholder for trade notifications
    }
}

/**
 * Supply shock affecting the market
 */
data class SupplyShock(
    val description: String,
    val multiplier: Double,
    val startTime: Long,
    val endTime: Long
)

/**
 * Demand shock affecting the market
 */
data class DemandShock(
    val description: String,
    val multiplier: Double,
    val startTime: Long,
    val endTime: Long
)

/**
 * Commodity-specific market data
 */
data class CommodityMarketData(
    val commodityType: CommodityType,
    val currentPrice: Double,
    val inventoryLevel: Double,
    val demandLevel: Double,
    val spoilageRate: Double,
    val storageCostPerUnit: Double,
    val seasonalMultiplier: Double,
    val activeSupplyShocks: Int,
    val activeDemandShocks: Int
)

/**
 * Record of a commodity trade
 */
data class CommodityTrade(
    val buyerId: String,
    val sellerId: String,
    val commodityType: CommodityType,
    val quantity: Double,
    val pricePerUnit: Double,
    val timestamp: Long
)

/**
 * Commodity market specific events
 */
sealed class CommodityMarketEvent : MarketEvent() {
    data class HarvestSeason(
        override val timestamp: Long,
        override val impact: MarketImpact = MarketImpact.MEDIUM
    ) : CommodityMarketEvent()
    
    data class NaturalDisaster(
        override val timestamp: Long,
        override val impact: MarketImpact = MarketImpact.HIGH,
        val affectedRegion: String
    ) : CommodityMarketEvent()
    
    data class TradeEmbargo(
        override val timestamp: Long,
        override val impact: MarketImpact = MarketImpact.HIGH,
        val durationMillis: Long
    ) : CommodityMarketEvent()
    
    data class TechnologicalBreakthrough(
        override val timestamp: Long,
        override val impact: MarketImpact = MarketImpact.MEDIUM,
        val technology: String
    ) : CommodityMarketEvent()
}