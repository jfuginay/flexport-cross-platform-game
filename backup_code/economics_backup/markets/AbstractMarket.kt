package com.flexport.economics.markets

import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.abs
import kotlin.math.min
import kotlin.math.pow

/**
 * Abstract base implementation for markets with common functionality
 */
abstract class AbstractMarket : Market {
    protected val buyOrders = ConcurrentHashMap<String, Order.BuyOrder>()
    protected val sellOrders = ConcurrentHashMap<String, Order.SellOrder>()
    protected val priceHistory = mutableListOf<PricePoint>()
    
    protected var currentPrice: Double = 100.0
    protected var volume24h: Double = 0.0
    protected var lastUpdateTime: Long = System.currentTimeMillis()
    
    /**
     * Price discovery algorithm - finds equilibrium price where supply meets demand
     */
    protected fun discoverPrice(): Double {
        if (buyOrders.isEmpty() || sellOrders.isEmpty()) {
            return currentPrice
        }
        
        // Sort orders by price
        val sortedBuyOrders = buyOrders.values.sortedByDescending { it.pricePerUnit }
        val sortedSellOrders = sellOrders.values.sortedBy { it.pricePerUnit }
        
        // Find crossing point
        var buyIndex = 0
        var sellIndex = 0
        var accumulatedBuyQuantity = 0.0
        var accumulatedSellQuantity = 0.0
        
        while (buyIndex < sortedBuyOrders.size && sellIndex < sortedSellOrders.size) {
            val buyOrder = sortedBuyOrders[buyIndex]
            val sellOrder = sortedSellOrders[sellIndex]
            
            if (buyOrder.pricePerUnit >= sellOrder.pricePerUnit) {
                // Orders can be matched
                val matchQuantity = min(
                    buyOrder.quantity - accumulatedBuyQuantity,
                    sellOrder.quantity - accumulatedSellQuantity
                )
                
                accumulatedBuyQuantity += matchQuantity
                accumulatedSellQuantity += matchQuantity
                
                if (accumulatedBuyQuantity >= buyOrder.quantity) {
                    buyIndex++
                    accumulatedBuyQuantity = 0.0
                }
                
                if (accumulatedSellQuantity >= sellOrder.quantity) {
                    sellIndex++
                    accumulatedSellQuantity = 0.0
                }
                
                // Equilibrium price is average of matched orders
                return (buyOrder.pricePerUnit + sellOrder.pricePerUnit) / 2.0
            } else {
                break
            }
        }
        
        // No crossing point found, adjust price based on pressure
        val buyPressure = buyOrders.values.sumOf { it.quantity * it.pricePerUnit }
        val sellPressure = sellOrders.values.sumOf { it.quantity * it.pricePerUnit }
        
        return if (buyPressure > sellPressure) {
            currentPrice * 1.01 // Increase price by 1%
        } else {
            currentPrice * 0.99 // Decrease price by 1%
        }
    }
    
    /**
     * Match orders and execute trades
     */
    protected fun matchOrders() {
        val sortedBuyOrders = buyOrders.values.sortedByDescending { it.pricePerUnit }
        val sortedSellOrders = sellOrders.values.sortedBy { it.pricePerUnit }
        
        val executedBuyOrders = mutableSetOf<String>()
        val executedSellOrders = mutableSetOf<String>()
        
        for (buyOrder in sortedBuyOrders) {
            for (sellOrder in sortedSellOrders) {
                if (buyOrder.pricePerUnit >= sellOrder.pricePerUnit && 
                    !executedBuyOrders.contains(buyOrder.id) && 
                    !executedSellOrders.contains(sellOrder.id)) {
                    
                    val tradePrice = (buyOrder.pricePerUnit + sellOrder.pricePerUnit) / 2.0
                    val tradeQuantity = min(buyOrder.quantity, sellOrder.quantity)
                    
                    // Execute trade
                    executeTrade(buyOrder, sellOrder, tradePrice, tradeQuantity)
                    
                    // Update volume
                    volume24h += tradeQuantity * tradePrice
                    
                    // Mark orders as executed if fully filled
                    if (tradeQuantity >= buyOrder.quantity) {
                        executedBuyOrders.add(buyOrder.id)
                    }
                    if (tradeQuantity >= sellOrder.quantity) {
                        executedSellOrders.add(sellOrder.id)
                    }
                }
            }
        }
        
        // Remove executed orders
        executedBuyOrders.forEach { buyOrders.remove(it) }
        executedSellOrders.forEach { sellOrders.remove(it) }
    }
    
    /**
     * Execute a trade between buyer and seller
     */
    protected abstract fun executeTrade(
        buyOrder: Order.BuyOrder,
        sellOrder: Order.SellOrder,
        price: Double,
        quantity: Double
    )
    
    /**
     * Calculate liquidity depth based on order book
     */
    protected fun calculateLiquidityDepth(): Double {
        val buyDepth = buyOrders.values.sumOf { it.quantity * it.pricePerUnit }
        val sellDepth = sellOrders.values.sumOf { it.quantity * it.pricePerUnit }
        return buyDepth + sellDepth
    }
    
    /**
     * Apply price elasticity effects
     */
    protected fun applyElasticity(basePrice: Double, supplyDemandRatio: Double, elasticity: Double): Double {
        // Price elasticity formula: % change in price = (1/elasticity) * % change in supply/demand
        val priceMultiplier = (1.0 / elasticity) * (supplyDemandRatio - 1.0)
        return basePrice * (1.0 + priceMultiplier).coerceIn(0.5, 2.0) // Limit price swings
    }
    
    /**
     * Add a buy order to the market
     */
    fun addBuyOrder(quantity: Double, pricePerUnit: Double, buyerId: String): String {
        val orderId = UUID.randomUUID().toString()
        val order = Order.BuyOrder(
            id = orderId,
            quantity = quantity,
            pricePerUnit = pricePerUnit,
            timestamp = System.currentTimeMillis(),
            buyerId = buyerId
        )
        buyOrders[orderId] = order
        return orderId
    }
    
    /**
     * Add a sell order to the market
     */
    fun addSellOrder(quantity: Double, pricePerUnit: Double, sellerId: String): String {
        val orderId = UUID.randomUUID().toString()
        val order = Order.SellOrder(
            id = orderId,
            quantity = quantity,
            pricePerUnit = pricePerUnit,
            timestamp = System.currentTimeMillis(),
            sellerId = sellerId
        )
        sellOrders[orderId] = order
        return orderId
    }
    
    /**
     * Cancel an order
     */
    fun cancelOrder(orderId: String): Boolean {
        return buyOrders.remove(orderId) != null || sellOrders.remove(orderId) != null
    }
    
    override fun update(deltaTime: Float) {
        // Discover new price
        val newPrice = discoverPrice()
        
        // Apply smoothing to prevent wild swings
        currentPrice = currentPrice * 0.9 + newPrice * 0.1
        
        // Record price history
        priceHistory.add(PricePoint(System.currentTimeMillis(), currentPrice))
        
        // Keep only 24 hours of history
        val cutoffTime = System.currentTimeMillis() - 24 * 60 * 60 * 1000
        priceHistory.removeAll { it.timestamp < cutoffTime }
        
        // Match orders
        matchOrders()
        
        // Update volume (decay old volume)
        val hoursPassed = deltaTime / 3600f
        volume24h *= (1.0 - hoursPassed / 24.0).coerceAtLeast(0.0)
        
        lastUpdateTime = System.currentTimeMillis()
    }
    
    override fun clearMarket() {
        // Clear all pending orders
        buyOrders.clear()
        sellOrders.clear()
    }
    
    override fun getMarketStats(): MarketStats {
        val price24hAgo = priceHistory.firstOrNull()?.price ?: currentPrice
        val priceChange = ((currentPrice - price24hAgo) / price24hAgo) * 100
        
        return MarketStats(
            totalSupply = sellOrders.values.sumOf { it.quantity },
            totalDemand = buyOrders.values.sumOf { it.quantity },
            currentPrice = currentPrice,
            priceChange24h = priceChange,
            volume24h = volume24h,
            liquidityDepth = calculateLiquidityDepth()
        )
    }
}

/**
 * Price point in history
 */
data class PricePoint(
    val timestamp: Long,
    val price: Double
)