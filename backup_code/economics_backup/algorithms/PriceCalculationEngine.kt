package com.flexport.economics.algorithms

import kotlin.math.*

/**
 * Advanced price calculation algorithms for the economic simulation
 */
class PriceCalculationEngine {
    
    /**
     * Calculate equilibrium price using supply and demand curves
     */
    fun calculateEquilibriumPrice(
        supplyFunction: SupplyFunction,
        demandFunction: DemandFunction,
        maxIterations: Int = 100,
        precision: Double = 0.01
    ): EquilibriumPoint {
        var lowPrice = 0.1
        var highPrice = 10000.0
        var iterations = 0
        
        while (iterations < maxIterations && (highPrice - lowPrice) > precision) {
            val midPrice = (lowPrice + highPrice) / 2
            val supply = supplyFunction.getQuantityAtPrice(midPrice)
            val demand = demandFunction.getQuantityAtPrice(midPrice)
            
            when {
                supply > demand -> highPrice = midPrice
                supply < demand -> lowPrice = midPrice
                else -> return EquilibriumPoint(midPrice, supply, demand)
            }
            iterations++
        }
        
        val equilibriumPrice = (lowPrice + highPrice) / 2
        return EquilibriumPoint(
            price = equilibriumPrice,
            supplyQuantity = supplyFunction.getQuantityAtPrice(equilibriumPrice),
            demandQuantity = demandFunction.getQuantityAtPrice(equilibriumPrice)
        )
    }
    
    /**
     * Calculate price elasticity of demand
     */
    fun calculatePriceElasticity(
        originalPrice: Double,
        newPrice: Double,
        originalQuantity: Double,
        newQuantity: Double
    ): Double {
        val percentageChangePrice = (newPrice - originalPrice) / originalPrice
        val percentageChangeQuantity = (newQuantity - originalQuantity) / originalQuantity
        
        return if (percentageChangePrice != 0.0) {
            percentageChangeQuantity / percentageChangePrice
        } else 0.0
    }
    
    /**
     * Apply elasticity to price changes
     */
    fun applyElasticity(
        currentPrice: Double,
        supplyChangePercent: Double,
        demandChangePercent: Double,
        priceElasticity: Double,
        supplyElasticity: Double = 1.0
    ): Double {
        // Calculate supply-demand imbalance
        val imbalance = demandChangePercent - supplyChangePercent
        
        // Apply elasticity: price change = imbalance / (price elasticity + supply elasticity)
        val priceChangePercent = imbalance / (abs(priceElasticity) + supplyElasticity)
        
        return currentPrice * (1 + priceChangePercent)
    }
    
    /**
     * Calculate compound annual growth rate (CAGR)
     */
    fun calculateCAGR(
        beginningValue: Double,
        endingValue: Double,
        periods: Double
    ): Double {
        return (endingValue / beginningValue).pow(1.0 / periods) - 1
    }
    
    /**
     * Calculate volatility using standard deviation of returns
     */
    fun calculateVolatility(priceHistory: List<Double>): Double {
        if (priceHistory.size < 2) return 0.0
        
        val returns = mutableListOf<Double>()
        for (i in 1 until priceHistory.size) {
            val return_ = ln(priceHistory[i] / priceHistory[i - 1])
            returns.add(return_)
        }
        
        val meanReturn = returns.average()
        val variance = returns.map { (it - meanReturn).pow(2) }.average()
        
        return sqrt(variance)
    }
    
    /**
     * Apply momentum-based price adjustments
     */
    fun applyMomentum(
        currentPrice: Double,
        priceHistory: List<Double>,
        momentumFactor: Double = 0.1
    ): Double {
        if (priceHistory.size < 2) return currentPrice
        
        // Calculate momentum as average of recent price changes
        val recentChanges = mutableListOf<Double>()
        val lookbackPeriod = min(5, priceHistory.size - 1)
        
        for (i in (priceHistory.size - lookbackPeriod) until priceHistory.size) {
            if (i > 0) {
                val change = (priceHistory[i] - priceHistory[i - 1]) / priceHistory[i - 1]
                recentChanges.add(change)
            }
        }
        
        val avgMomentum = recentChanges.average()
        return currentPrice * (1 + avgMomentum * momentumFactor)
    }
    
    /**
     * Apply mean reversion to prices
     */
    fun applyMeanReversion(
        currentPrice: Double,
        historicalMean: Double,
        reversionSpeed: Double = 0.1
    ): Double {
        val deviation = (currentPrice - historicalMean) / historicalMean
        val reversionForce = -deviation * reversionSpeed
        return currentPrice * (1 + reversionForce)
    }
    
    /**
     * Calculate option pricing using Black-Scholes model
     */
    fun calculateBlackScholesPrice(
        spotPrice: Double,
        strikePrice: Double,
        timeToExpiry: Double, // in years
        riskFreeRate: Double,
        volatility: Double,
        isCall: Boolean = true
    ): Double {
        val d1 = (ln(spotPrice / strikePrice) + (riskFreeRate + 0.5 * volatility.pow(2)) * timeToExpiry) / 
                 (volatility * sqrt(timeToExpiry))
        val d2 = d1 - volatility * sqrt(timeToExpiry)
        
        return if (isCall) {
            spotPrice * cumulativeNormalDistribution(d1) - 
            strikePrice * exp(-riskFreeRate * timeToExpiry) * cumulativeNormalDistribution(d2)
        } else {
            strikePrice * exp(-riskFreeRate * timeToExpiry) * cumulativeNormalDistribution(-d2) - 
            spotPrice * cumulativeNormalDistribution(-d1)
        }
    }
    
    /**
     * Calculate bond price using present value
     */
    fun calculateBondPrice(
        faceValue: Double,
        couponRate: Double,
        yieldToMaturity: Double,
        periodsToMaturity: Int,
        couponFrequency: Int = 2 // Semi-annual by default
    ): Double {
        val couponPayment = faceValue * couponRate / couponFrequency
        val discountRate = yieldToMaturity / couponFrequency
        
        var presentValue = 0.0
        
        // Present value of coupon payments
        for (period in 1..periodsToMaturity * couponFrequency) {
            presentValue += couponPayment / (1 + discountRate).pow(period)
        }
        
        // Present value of face value
        presentValue += faceValue / (1 + discountRate).pow(periodsToMaturity * couponFrequency)
        
        return presentValue
    }
    
    /**
     * Calculate Net Present Value (NPV)
     */
    fun calculateNPV(
        initialInvestment: Double,
        cashFlows: List<Double>,
        discountRate: Double
    ): Double {
        var npv = -initialInvestment
        
        cashFlows.forEachIndexed { index, cashFlow ->
            npv += cashFlow / (1 + discountRate).pow(index + 1)
        }
        
        return npv
    }
    
    /**
     * Calculate Internal Rate of Return (IRR)
     */
    fun calculateIRR(
        initialInvestment: Double,
        cashFlows: List<Double>,
        maxIterations: Int = 1000,
        precision: Double = 0.00001
    ): Double? {
        var lowRate = -0.99
        var highRate = 10.0
        
        repeat(maxIterations) {
            val midRate = (lowRate + highRate) / 2
            val npv = calculateNPV(initialInvestment, cashFlows, midRate)
            
            when {
                abs(npv) < precision -> return midRate
                npv > 0 -> lowRate = midRate
                else -> highRate = midRate
            }
        }
        
        return null // Failed to converge
    }
    
    /**
     * Calculate Value at Risk (VaR) using historical simulation
     */
    fun calculateVaR(
        returns: List<Double>,
        confidenceLevel: Double = 0.95
    ): Double {
        if (returns.isEmpty()) return 0.0
        
        val sortedReturns = returns.sorted()
        val index = ((1 - confidenceLevel) * sortedReturns.size).toInt()
        
        return -sortedReturns[index.coerceIn(0, sortedReturns.size - 1)]
    }
    
    /**
     * Calculate Sharpe ratio
     */
    fun calculateSharpeRatio(
        returns: List<Double>,
        riskFreeRate: Double
    ): Double {
        if (returns.isEmpty()) return 0.0
        
        val excessReturns = returns.map { it - riskFreeRate }
        val avgExcessReturn = excessReturns.average()
        val stdDev = sqrt(excessReturns.map { (it - avgExcessReturn).pow(2) }.average())
        
        return if (stdDev != 0.0) avgExcessReturn / stdDev else 0.0
    }
    
    /**
     * Calculate correlation coefficient between two price series
     */
    fun calculateCorrelation(series1: List<Double>, series2: List<Double>): Double {
        if (series1.size != series2.size || series1.isEmpty()) return 0.0
        
        val mean1 = series1.average()
        val mean2 = series2.average()
        
        val numerator = series1.zip(series2) { x, y -> (x - mean1) * (y - mean2) }.sum()
        val denominator = sqrt(
            series1.sumOf { (it - mean1).pow(2) } * 
            series2.sumOf { (it - mean2).pow(2) }
        )
        
        return if (denominator != 0.0) numerator / denominator else 0.0
    }
    
    /**
     * Approximate cumulative normal distribution
     */
    private fun cumulativeNormalDistribution(x: Double): Double {
        // Abramowitz and Stegun approximation
        val a1 = 0.254829592
        val a2 = -0.284496736
        val a3 = 1.421413741
        val a4 = -1.453152027
        val a5 = 1.061405429
        val p = 0.3275911
        
        val sign = if (x < 0) -1 else 1
        val absX = abs(x)
        
        val t = 1.0 / (1.0 + p * absX)
        val y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * exp(-absX * absX)
        
        return 0.5 * (1.0 + sign * y)
    }
}

/**
 * Represents a supply function
 */
interface SupplyFunction {
    fun getQuantityAtPrice(price: Double): Double
}

/**
 * Represents a demand function
 */
interface DemandFunction {
    fun getQuantityAtPrice(price: Double): Double
}

/**
 * Linear supply function: Q = a + b * P
 */
class LinearSupplyFunction(
    private val intercept: Double,
    private val slope: Double
) : SupplyFunction {
    override fun getQuantityAtPrice(price: Double): Double {
        return maxOf(0.0, intercept + slope * price)
    }
}

/**
 * Linear demand function: Q = a - b * P
 */
class LinearDemandFunction(
    private val intercept: Double,
    private val slope: Double
) : DemandFunction {
    override fun getQuantityAtPrice(price: Double): Double {
        return maxOf(0.0, intercept - slope * price)
    }
}

/**
 * Exponential supply function with elasticity
 */
class ElasticSupplyFunction(
    private val baseQuantity: Double,
    private val basePrice: Double,
    private val elasticity: Double
) : SupplyFunction {
    override fun getQuantityAtPrice(price: Double): Double {
        return baseQuantity * (price / basePrice).pow(elasticity)
    }
}

/**
 * Exponential demand function with elasticity
 */
class ElasticDemandFunction(
    private val baseQuantity: Double,
    private val basePrice: Double,
    private val elasticity: Double // Should be negative for normal goods
) : DemandFunction {
    override fun getQuantityAtPrice(price: Double): Double {
        return baseQuantity * (price / basePrice).pow(elasticity)
    }
}

/**
 * Represents market equilibrium point
 */
data class EquilibriumPoint(
    val price: Double,
    val supplyQuantity: Double,
    val demandQuantity: Double
) {
    val isEquilibrium: Boolean
        get() = abs(supplyQuantity - demandQuantity) < 0.01
}

/**
 * Market pricing strategy
 */
enum class PricingStrategy {
    COMPETITIVE, // Price based on market equilibrium
    PREMIUM,     // Price above market
    PENETRATION, // Price below market to gain share
    DYNAMIC,     // Adjust based on real-time conditions
    VALUE_BASED  // Price based on perceived value
}

/**
 * Price adjustment result
 */
data class PriceAdjustment(
    val oldPrice: Double,
    val newPrice: Double,
    val reason: String,
    val magnitude: Double
) {
    val changePercent: Double
        get() = ((newPrice - oldPrice) / oldPrice) * 100
}