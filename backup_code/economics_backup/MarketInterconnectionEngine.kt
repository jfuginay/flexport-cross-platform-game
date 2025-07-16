package com.flexport.economics

import com.flexport.economics.markets.*
import com.flexport.economics.models.*
import com.flexport.economics.algorithms.PriceCalculationEngine
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.abs

/**
 * Engine that manages interconnections between different markets
 * and how they influence each other in the economic simulation
 */
class MarketInterconnectionEngine {
    
    private val markets = ConcurrentHashMap<String, Market>()
    private val interconnections = mutableListOf<MarketInterconnection>()
    private val priceCalculator = PriceCalculationEngine()
    
    // Market relationships
    private val correlationMatrix = ConcurrentHashMap<Pair<String, String>, Double>()
    private val influenceWeights = ConcurrentHashMap<Pair<String, String>, Double>()
    
    // Cross-market effects tracking
    private val pendingEffects = mutableListOf<CrossMarketEffect>()
    
    init {
        setupDefaultInterconnections()
    }
    
    /**
     * Register a market with the interconnection engine
     */
    fun registerMarket(marketId: String, market: Market) {
        markets[marketId] = market
    }
    
    /**
     * Add an interconnection between two markets
     */
    fun addInterconnection(
        fromMarketId: String,
        toMarketId: String,
        connectionType: ConnectionType,
        strength: Double,
        delay: Long = 0 // milliseconds
    ) {
        val interconnection = MarketInterconnection(
            fromMarketId = fromMarketId,
            toMarketId = toMarketId,
            connectionType = connectionType,
            strength = strength,
            delay = delay,
            lastActivation = 0L
        )
        
        interconnections.add(interconnection)
        
        // Update correlation matrix
        correlationMatrix[Pair(fromMarketId, toMarketId)] = 
            calculateBaseCorrelation(connectionType, strength)
    }
    
    /**
     * Process all market interconnections
     */
    fun processInterconnections(deltaTime: Float) {
        // Process pending cross-market effects
        processPendingEffects()
        
        // Analyze market changes and create new effects
        analyzeMarketChanges()
        
        // Update correlations based on recent data
        updateCorrelations()
        
        // Apply cross-market influences
        applyMarketInfluences()
    }
    
    /**
     * Process effects that are ready to be applied
     */
    private fun processPendingEffects() {
        val currentTime = System.currentTimeMillis()
        val readyEffects = pendingEffects.filter { it.activationTime <= currentTime }
        
        readyEffects.forEach { effect ->
            applyEffect(effect)
        }
        
        pendingEffects.removeAll(readyEffects)
    }
    
    /**
     * Analyze recent market changes to identify cross-market impacts
     */
    private fun analyzeMarketChanges() {
        markets.forEach { (marketId, market) ->
            val stats = market.getMarketStats()
            
            // Check for significant price changes
            if (abs(stats.priceChange24h) > 5.0) { // 5% threshold
                triggerPriceShockEffects(marketId, stats.priceChange24h / 100.0)
            }
            
            // Check for volume spikes
            if (stats.volume24h > getAverageVolume(marketId) * 2.0) {
                triggerVolumeShockEffects(marketId, stats.volume24h)
            }
            
            // Check for liquidity changes
            val avgLiquidity = getAverageLiquidity(marketId)
            if (avgLiquidity > 0 && stats.liquidityDepth < avgLiquidity * 0.5) {
                triggerLiquidityShockEffects(marketId, stats.liquidityDepth / avgLiquidity)
            }
        }
    }
    
    /**
     * Trigger price shock effects across connected markets
     */
    private fun triggerPriceShockEffects(sourceMarketId: String, priceChangeRatio: Double) {
        interconnections
            .filter { it.fromMarketId == sourceMarketId }
            .forEach { connection ->
                val effect = when (connection.connectionType) {
                    ConnectionType.SUBSTITUTE_GOODS -> {
                        // Substitute goods move in same direction
                        CrossMarketEffect(
                            sourceMarketId = sourceMarketId,
                            targetMarketId = connection.toMarketId,
                            effectType = EffectType.PRICE_INFLUENCE,
                            magnitude = priceChangeRatio * connection.strength * 0.7,
                            activationTime = System.currentTimeMillis() + connection.delay,
                            description = "Substitute goods price adjustment"
                        )
                    }
                    ConnectionType.COMPLEMENTARY_GOODS -> {
                        // Complementary goods move in opposite direction
                        CrossMarketEffect(
                            sourceMarketId = sourceMarketId,
                            targetMarketId = connection.toMarketId,
                            effectType = EffectType.PRICE_INFLUENCE,
                            magnitude = -priceChangeRatio * connection.strength * 0.5,
                            activationTime = System.currentTimeMillis() + connection.delay,
                            description = "Complementary goods price adjustment"
                        )
                    }
                    ConnectionType.INPUT_OUTPUT -> {
                        // Input cost changes affect output prices
                        CrossMarketEffect(
                            sourceMarketId = sourceMarketId,
                            targetMarketId = connection.toMarketId,
                            effectType = EffectType.COST_INFLUENCE,
                            magnitude = priceChangeRatio * connection.strength * 0.8,
                            activationTime = System.currentTimeMillis() + connection.delay,
                            description = "Input cost influence on output"
                        )
                    }
                    ConnectionType.FINANCIAL_LINKAGE -> {
                        // Financial markets influence each other through risk appetite
                        CrossMarketEffect(
                            sourceMarketId = sourceMarketId,
                            targetMarketId = connection.toMarketId,
                            effectType = EffectType.SENTIMENT_INFLUENCE,
                            magnitude = priceChangeRatio * connection.strength * 0.6,
                            activationTime = System.currentTimeMillis() + connection.delay,
                            description = "Financial market sentiment transmission"
                        )
                    }
                    ConnectionType.COMPETITION -> {
                        // Competitive markets react to maintain market share
                        CrossMarketEffect(
                            sourceMarketId = sourceMarketId,
                            targetMarketId = connection.toMarketId,
                            effectType = EffectType.COMPETITIVE_RESPONSE,
                            magnitude = -priceChangeRatio * connection.strength * 0.4,
                            activationTime = System.currentTimeMillis() + connection.delay,
                            description = "Competitive market response"
                        )
                    }
                }
                
                pendingEffects.add(effect)
            }
    }
    
    /**
     * Trigger volume shock effects
     */
    private fun triggerVolumeShockEffects(sourceMarketId: String, volume: Double) {
        interconnections
            .filter { it.fromMarketId == sourceMarketId }
            .forEach { connection ->
                if (connection.connectionType == ConnectionType.FINANCIAL_LINKAGE) {
                    val effect = CrossMarketEffect(
                        sourceMarketId = sourceMarketId,
                        targetMarketId = connection.toMarketId,
                        effectType = EffectType.LIQUIDITY_SPILLOVER,
                        magnitude = connection.strength * 0.3,
                        activationTime = System.currentTimeMillis() + connection.delay,
                        description = "Volume spillover effect"
                    )
                    pendingEffects.add(effect)
                }
            }
    }
    
    /**
     * Trigger liquidity shock effects
     */
    private fun triggerLiquidityShockEffects(sourceMarketId: String, liquidityRatio: Double) {
        interconnections
            .filter { it.fromMarketId == sourceMarketId }
            .forEach { connection ->
                val effect = CrossMarketEffect(
                    sourceMarketId = sourceMarketId,
                    targetMarketId = connection.toMarketId,
                    effectType = EffectType.LIQUIDITY_CONTAGION,
                    magnitude = (1.0 - liquidityRatio) * connection.strength,
                    activationTime = System.currentTimeMillis() + connection.delay,
                    description = "Liquidity contagion effect"
                )
                pendingEffects.add(effect)
            }
    }
    
    /**
     * Apply a cross-market effect
     */
    private fun applyEffect(effect: CrossMarketEffect) {
        val targetMarket = markets[effect.targetMarketId] ?: return
        
        when (effect.effectType) {
            EffectType.PRICE_INFLUENCE -> {
                // Create a synthetic market event to influence prices
                val event = SyntheticMarketEvent(
                    timestamp = System.currentTimeMillis(),
                    impact = when {
                        abs(effect.magnitude) > 0.1 -> MarketImpact.HIGH
                        abs(effect.magnitude) > 0.05 -> MarketImpact.MEDIUM
                        else -> MarketImpact.LOW
                    },
                    priceMultiplier = 1.0 + effect.magnitude,
                    description = effect.description
                )
                targetMarket.processEvent(event)
            }
            
            EffectType.COST_INFLUENCE -> {
                // Influence operating costs or input prices
                // Implementation would depend on market type
                applyCostInfluence(targetMarket, effect.magnitude)
            }
            
            EffectType.SENTIMENT_INFLUENCE -> {
                // Affect market sentiment and volatility
                applySentimentInfluence(targetMarket, effect.magnitude)
            }
            
            EffectType.COMPETITIVE_RESPONSE -> {
                // Trigger competitive pricing responses
                applyCompetitiveResponse(targetMarket, effect.magnitude)
            }
            
            EffectType.LIQUIDITY_SPILLOVER -> {
                // Improve liquidity in target market
                applyLiquiditySpillover(targetMarket, effect.magnitude)
            }
            
            EffectType.LIQUIDITY_CONTAGION -> {
                // Reduce liquidity in target market
                applyLiquidityContagion(targetMarket, effect.magnitude)
            }
        }
    }
    
    /**
     * Apply cost influence to a market
     */
    private fun applyCostInfluence(market: Market, magnitude: Double) {
        when (market) {
            is GoodsMarket -> {
                // Increase storage costs or spoilage rates
                if (magnitude > 0) {
                    market.addSupplyShock("Cross-market cost increase", 1.0 - magnitude * 0.1, 24 * 60 * 60 * 1000L)
                }
            }
            is AssetMarket -> {
                // Affect fuel prices or maintenance costs
                val event = AssetMarketEvent.MaintenanceCostChange(
                    timestamp = System.currentTimeMillis(),
                    impact = MarketImpact.MEDIUM,
                    newIndex = 1.0 + magnitude * 0.2
                )
                market.processEvent(event)
            }
            is LaborMarket -> {
                // Affect wage expectations
                // Implementation would adjust wage indices
            }
        }
    }
    
    /**
     * Apply sentiment influence
     */
    private fun applySentimentInfluence(market: Market, magnitude: Double) {
        // Create a sentiment-based market event
        val event = SyntheticMarketEvent(
            timestamp = System.currentTimeMillis(),
            impact = MarketImpact.MEDIUM,
            priceMultiplier = 1.0 + magnitude * 0.5,
            description = "Cross-market sentiment influence"
        )
        market.processEvent(event)
    }
    
    /**
     * Apply competitive response
     */
    private fun applyCompetitiveResponse(market: Market, magnitude: Double) {
        // Trigger competitive adjustments
        val event = SyntheticMarketEvent(
            timestamp = System.currentTimeMillis(),
            impact = MarketImpact.LOW,
            priceMultiplier = 1.0 + magnitude,
            description = "Competitive market response"
        )
        market.processEvent(event)
    }
    
    /**
     * Apply liquidity spillover
     */
    private fun applyLiquiditySpillover(market: Market, magnitude: Double) {
        // Increase market activity
        // Implementation would add synthetic orders to improve liquidity
    }
    
    /**
     * Apply liquidity contagion
     */
    private fun applyLiquidityContagion(market: Market, magnitude: Double) {
        // Reduce market activity
        // Implementation would remove some orders to reduce liquidity
    }
    
    /**
     * Update correlations between markets
     */
    private fun updateCorrelations() {
        val marketIds = markets.keys.toList()
        
        for (i in marketIds.indices) {
            for (j in i + 1 until marketIds.size) {
                val market1 = marketIds[i]
                val market2 = marketIds[j]
                
                val correlation = calculateRealTimeCorrelation(market1, market2)
                correlationMatrix[Pair(market1, market2)] = correlation
                correlationMatrix[Pair(market2, market1)] = correlation
            }
        }
    }
    
    /**
     * Calculate real-time correlation between two markets
     */
    private fun calculateRealTimeCorrelation(market1Id: String, market2Id: String): Double {
        val market1 = markets[market1Id] ?: return 0.0
        val market2 = markets[market2Id] ?: return 0.0
        
        val stats1 = market1.getMarketStats()
        val stats2 = market2.getMarketStats()
        
        // Simple correlation based on price changes
        val price1Change = stats1.priceChange24h
        val price2Change = stats2.priceChange24h
        
        // Return normalized correlation
        return when {
            price1Change * price2Change > 0 -> 0.5 // Same direction
            price1Change * price2Change < 0 -> -0.5 // Opposite direction
            else -> 0.0 // No correlation
        }
    }
    
    /**
     * Apply general market influences
     */
    private fun applyMarketInfluences() {
        correlationMatrix.forEach { (marketPair, correlation) ->
            if (abs(correlation) > 0.3) { // Only for strong correlations
                val market1 = markets[marketPair.first]
                val market2 = markets[marketPair.second]
                
                if (market1 != null && market2 != null) {
                    val stats1 = market1.getMarketStats()
                    val stats2 = market2.getMarketStats()
                    
                    // Apply influence based on correlation
                    val influence = correlation * 0.1 // 10% maximum influence
                    val priceEffect = stats1.priceChange24h * influence / 100.0
                    
                    if (abs(priceEffect) > 0.01) { // 1% threshold
                        val event = SyntheticMarketEvent(
                            timestamp = System.currentTimeMillis(),
                            impact = MarketImpact.LOW,
                            priceMultiplier = 1.0 + priceEffect,
                            description = "Cross-market correlation influence"
                        )
                        market2.processEvent(event)
                    }
                }
            }
        }
    }
    
    /**
     * Setup default interconnections between markets
     */
    private fun setupDefaultInterconnections() {
        // Fuel affects transport costs
        addInterconnection("fuel", "shipping", ConnectionType.INPUT_OUTPUT, 0.8, 3600000) // 1 hour delay
        addInterconnection("fuel", "aviation", ConnectionType.INPUT_OUTPUT, 0.9, 1800000) // 30 min delay
        
        // Labor affects all markets
        addInterconnection("labor", "goods", ConnectionType.INPUT_OUTPUT, 0.6, 7200000) // 2 hour delay
        addInterconnection("labor", "assets", ConnectionType.INPUT_OUTPUT, 0.5, 86400000) // 1 day delay
        
        // Capital affects asset purchases
        addInterconnection("capital", "assets", ConnectionType.FINANCIAL_LINKAGE, 0.9, 3600000)
        
        // Goods markets as substitutes/complements
        addInterconnection("food", "fuel", ConnectionType.SUBSTITUTE_GOODS, 0.3, 3600000)
        addInterconnection("electronics", "machinery", ConnectionType.COMPLEMENTARY_GOODS, 0.4, 7200000)
    }
    
    /**
     * Get average volume for a market (placeholder implementation)
     */
    private fun getAverageVolume(marketId: String): Double {
        // In real implementation, would calculate from historical data
        return 100000.0
    }
    
    /**
     * Get average liquidity for a market (placeholder implementation)
     */
    private fun getAverageLiquidity(marketId: String): Double {
        // In real implementation, would calculate from historical data
        return 500000.0
    }
    
    /**
     * Calculate base correlation for a connection type
     */
    private fun calculateBaseCorrelation(connectionType: ConnectionType, strength: Double): Double {
        return when (connectionType) {
            ConnectionType.SUBSTITUTE_GOODS -> strength * 0.8
            ConnectionType.COMPLEMENTARY_GOODS -> -strength * 0.6
            ConnectionType.INPUT_OUTPUT -> strength * 0.9
            ConnectionType.FINANCIAL_LINKAGE -> strength * 0.7
            ConnectionType.COMPETITION -> -strength * 0.5
        }
    }
    
    /**
     * Get current market interconnection statistics
     */
    fun getInterconnectionStats(): InterconnectionStats {
        return InterconnectionStats(
            totalConnections = interconnections.size,
            averageStrength = interconnections.map { it.strength }.average(),
            strongConnections = interconnections.count { it.strength > 0.7 },
            pendingEffects = pendingEffects.size,
            correlationSummary = correlationMatrix.values.let { correlations ->
                mapOf(
                    "average" to correlations.average(),
                    "positive" to correlations.count { it > 0.3 },
                    "negative" to correlations.count { it < -0.3 }
                )
            }
        )
    }
}

/**
 * Represents a connection between two markets
 */
data class MarketInterconnection(
    val fromMarketId: String,
    val toMarketId: String,
    val connectionType: ConnectionType,
    val strength: Double, // 0.0 to 1.0
    val delay: Long, // milliseconds
    var lastActivation: Long
)

/**
 * Types of market connections
 */
enum class ConnectionType {
    SUBSTITUTE_GOODS,     // Markets for substitute products
    COMPLEMENTARY_GOODS,  // Markets for complementary products
    INPUT_OUTPUT,         // One market provides inputs to another
    FINANCIAL_LINKAGE,    // Financial relationship (investment, lending)
    COMPETITION          // Direct competition between markets
}

/**
 * Cross-market effect
 */
data class CrossMarketEffect(
    val sourceMarketId: String,
    val targetMarketId: String,
    val effectType: EffectType,
    val magnitude: Double,
    val activationTime: Long,
    val description: String
)

/**
 * Types of cross-market effects
 */
enum class EffectType {
    PRICE_INFLUENCE,
    COST_INFLUENCE,
    SENTIMENT_INFLUENCE,
    COMPETITIVE_RESPONSE,
    LIQUIDITY_SPILLOVER,
    LIQUIDITY_CONTAGION
}

/**
 * Synthetic market event for cross-market influences
 */
data class SyntheticMarketEvent(
    override val timestamp: Long,
    override val impact: MarketImpact,
    val priceMultiplier: Double,
    val description: String
) : MarketEvent()

/**
 * Interconnection statistics
 */
data class InterconnectionStats(
    val totalConnections: Int,
    val averageStrength: Double,
    val strongConnections: Int,
    val pendingEffects: Int,
    val correlationSummary: Map<String, Any>
)