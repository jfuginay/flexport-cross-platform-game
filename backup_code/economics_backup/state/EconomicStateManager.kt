package com.flexport.economics.state

import com.flexport.economics.markets.*
import com.flexport.economics.events.EconomicEventSystem
import com.flexport.economics.MarketInterconnectionEngine
import com.flexport.economics.TradeRouteProfitabilityEngine
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import java.util.concurrent.ConcurrentHashMap
import kotlin.coroutines.CoroutineContext

/**
 * Central manager for economic state in the FlexPort game
 * Handles real-time updates, persistence, and state synchronization
 */
class EconomicStateManager : CoroutineScope {
    
    private val job = SupervisorJob()
    override val coroutineContext: CoroutineContext = Dispatchers.Default + job
    
    // Core economic systems
    private val goodsMarkets = ConcurrentHashMap<String, GoodsMarket>()
    private val capitalMarket = CapitalMarket()
    private val assetMarket = AssetMarket()
    private val laborMarket = LaborMarket()
    
    // Economic engines
    private val interconnectionEngine = MarketInterconnectionEngine()
    private val eventSystem = EconomicEventSystem(interconnectionEngine)
    private val profitabilityEngine = TradeRouteProfitabilityEngine()
    
    // State flows for real-time updates
    private val _economicState = MutableStateFlow(EconomicState.initial())
    val economicState: StateFlow<EconomicState> = _economicState.asStateFlow()
    
    private val _marketUpdates = MutableSharedFlow<MarketUpdate>()
    val marketUpdates: SharedFlow<MarketUpdate> = _marketUpdates.asSharedFlow()
    
    private val _economicEvents = MutableSharedFlow<EconomicEventNotification>()
    val economicEvents: SharedFlow<EconomicEventNotification> = _economicEvents.asSharedFlow()
    
    // Update configuration
    private var updateIntervalMs = 60000L // 1 minute
    private var isRunning = false
    
    // Performance tracking
    private val updateTimes = mutableListOf<Long>()
    private var lastUpdateTime = 0L
    
    init {
        initializeMarkets()
        setupMarketInterconnections()
        startUpdateLoop()
    }
    
    /**
     * Initialize all markets with default settings
     */
    private fun initializeMarkets() {
        // Initialize goods markets for each commodity type
        CommodityType.values().forEach { commodityType ->
            val market = GoodsMarket(
                commodityType = commodityType,
                initialPrice = getInitialPrice(commodityType),
                baseElasticity = getBaseElasticity(commodityType)
            )
            goodsMarkets[commodityType.name] = market
            interconnectionEngine.registerMarket(commodityType.name, market)
        }
        
        // Register other markets
        interconnectionEngine.registerMarket("capital", capitalMarket)
        interconnectionEngine.registerMarket("assets", assetMarket)
        interconnectionEngine.registerMarket("labor", laborMarket)
    }
    
    /**
     * Setup interconnections between markets
     */
    private fun setupMarketInterconnections() {
        // Fuel affects transportation costs
        interconnectionEngine.addInterconnection(
            "FUEL", "assets", ConnectionType.INPUT_OUTPUT, 0.8, 3600000
        )
        
        // Labor affects all production
        CommodityType.values().forEach { commodity ->
            interconnectionEngine.addInterconnection(
                "labor", commodity.name, ConnectionType.INPUT_OUTPUT, 0.6, 7200000
            )
        }
        
        // Capital affects asset purchases
        interconnectionEngine.addInterconnection(
            "capital", "assets", ConnectionType.FINANCIAL_LINKAGE, 0.9, 1800000
        )
        
        // Substitutable commodities
        interconnectionEngine.addInterconnection(
            "FUEL", "ELECTRICITY", ConnectionType.SUBSTITUTE_GOODS, 0.4, 3600000
        )
        
        // Complementary relationships
        interconnectionEngine.addInterconnection(
            "ELECTRONICS", "MACHINERY", ConnectionType.COMPLEMENTARY_GOODS, 0.5, 7200000
        )
    }
    
    /**
     * Start the main update loop
     */
    private fun startUpdateLoop() {
        if (isRunning) return
        isRunning = true
        
        launch {
            while (isRunning) {
                val startTime = System.currentTimeMillis()
                
                try {
                    updateEconomicState()
                } catch (e: Exception) {
                    // Log error but continue running
                    println("Error in economic update: ${e.message}")
                }
                
                val updateDuration = System.currentTimeMillis() - startTime
                updateTimes.add(updateDuration)
                if (updateTimes.size > 100) updateTimes.removeAt(0)
                
                lastUpdateTime = System.currentTimeMillis()
                
                // Wait for next update cycle
                delay(updateIntervalMs)
            }
        }
    }
    
    /**
     * Update the complete economic state
     */
    private suspend fun updateEconomicState() {
        val deltaTime = if (lastUpdateTime > 0) {
            (System.currentTimeMillis() - lastUpdateTime) / 1000f
        } else {
            updateIntervalMs / 1000f
        }
        
        // Update all markets
        updateMarkets(deltaTime)
        
        // Process market interconnections
        interconnectionEngine.processInterconnections(deltaTime)
        
        // Generate economic events
        // (Event system runs on its own schedule)
        
        // Calculate current economic state
        val newState = calculateCurrentState()
        
        // Emit state update
        _economicState.value = newState
        
        // Emit market updates for any significant changes
        emitMarketUpdates(newState)
    }
    
    /**
     * Update all individual markets
     */
    private fun updateMarkets(deltaTime: Float) {
        // Update goods markets
        goodsMarkets.values.forEach { market ->
            market.update(deltaTime)
        }
        
        // Update other markets
        capitalMarket.update(deltaTime)
        assetMarket.update(deltaTime)
        laborMarket.update(deltaTime)
    }
    
    /**
     * Calculate current economic state
     */
    private fun calculateCurrentState(): EconomicState {
        val commodityPrices = goodsMarkets.mapValues { (_, market) ->
            market.getMarketStats().currentPrice
        }
        
        val marketConditions = capitalMarket.getMarketConditions()
        val laborStats = laborMarket.getLaborMarketStats()
        val interconnectionStats = interconnectionEngine.getInterconnectionStats()
        val eventConditions = eventSystem.getEconomicConditions()
        
        val economicIndicators = calculateEconomicIndicators(
            commodityPrices, marketConditions, laborStats
        )
        
        return EconomicState(
            timestamp = System.currentTimeMillis(),
            commodityPrices = commodityPrices,
            marketConditions = marketConditions,
            laborStatistics = laborStats,
            interconnectionStats = interconnectionStats,
            eventConditions = eventConditions,
            economicIndicators = economicIndicators,
            updatePerformance = UpdatePerformance(
                averageUpdateTimeMs = updateTimes.average(),
                lastUpdateTime = lastUpdateTime,
                updatesPerMinute = 60000.0 / updateIntervalMs
            )
        )
    }
    
    /**
     * Calculate high-level economic indicators
     */
    private fun calculateEconomicIndicators(
        commodityPrices: Map<String, Double>,
        marketConditions: MarketConditions,
        laborStats: LaborMarketStats
    ): EconomicIndicators {
        // Consumer Price Index (simplified)
        val cpi = calculateCPI(commodityPrices)
        
        // GDP Growth (simplified based on market activity)
        val gdpGrowth = calculateGDPGrowth(marketConditions)
        
        // Unemployment Rate
        val unemploymentRate = laborStats.unemploymentRates.values.average()
        
        // Inflation Rate (simplified)
        val inflationRate = calculateInflationRate(cpi)
        
        // Market Confidence Index
        val confidenceIndex = calculateConfidenceIndex(
            marketConditions, laborStats, commodityPrices
        )
        
        return EconomicIndicators(
            cpi = cpi,
            gdpGrowthRate = gdpGrowth,
            unemploymentRate = unemploymentRate,
            inflationRate = inflationRate,
            marketConfidenceIndex = confidenceIndex,
            tradeVolumeIndex = calculateTradeVolumeIndex(),
            economicComplexityIndex = calculateComplexityIndex()
        )
    }
    
    /**
     * Emit market updates for significant changes
     */
    private suspend fun emitMarketUpdates(newState: EconomicState) {
        val previousState = _economicState.value
        
        // Check for significant price changes
        newState.commodityPrices.forEach { (commodity, price) ->
            val previousPrice = previousState.commodityPrices[commodity]
            if (previousPrice != null) {
                val changePercent = abs((price - previousPrice) / previousPrice) * 100
                if (changePercent > 5.0) { // 5% threshold
                    _marketUpdates.emit(
                        MarketUpdate(
                            marketId = commodity,
                            updateType = MarketUpdateType.PRICE_CHANGE,
                            oldValue = previousPrice,
                            newValue = price,
                            changePercent = changePercent,
                            timestamp = System.currentTimeMillis()
                        )
                    )
                }
            }
        }
        
        // Check for significant economic indicator changes
        val indicators = newState.economicIndicators
        val previousIndicators = previousState.economicIndicators
        
        if (abs(indicators.inflationRate - previousIndicators.inflationRate) > 0.5) {
            _economicEvents.emit(
                EconomicEventNotification(
                    title = "Inflation Rate Change",
                    description = "Inflation rate changed from ${previousIndicators.inflationRate}% to ${indicators.inflationRate}%",
                    severity = EventSeverity.MODERATE,
                    timestamp = System.currentTimeMillis()
                )
            )
        }
    }
    
    // Market access methods
    
    /**
     * Get a specific goods market
     */
    fun getGoodsMarket(commodityType: CommodityType): GoodsMarket? {
        return goodsMarkets[commodityType.name]
    }
    
    /**
     * Get the capital market
     */
    fun getCapitalMarket(): CapitalMarket = capitalMarket
    
    /**
     * Get the asset market
     */
    fun getAssetMarket(): AssetMarket = assetMarket
    
    /**
     * Get the labor market
     */
    fun getLaborMarket(): LaborMarket = laborMarket
    
    /**
     * Get trade route profitability engine
     */
    fun getProfitabilityEngine(): TradeRouteProfitabilityEngine = profitabilityEngine
    
    // Configuration methods
    
    /**
     * Set update interval
     */
    fun setUpdateInterval(intervalMs: Long) {
        updateIntervalMs = intervalMs.coerceIn(1000L, 300000L) // 1 second to 5 minutes
    }
    
    /**
     * Get current performance metrics
     */
    fun getPerformanceMetrics(): PerformanceMetrics {
        return PerformanceMetrics(
            averageUpdateTimeMs = updateTimes.average(),
            maxUpdateTimeMs = updateTimes.maxOrNull() ?: 0.0,
            minUpdateTimeMs = updateTimes.minOrNull() ?: 0.0,
            totalUpdates = updateTimes.size.toLong(),
            memoryUsageMB = getMemoryUsage(),
            isHealthy = isSystemHealthy()
        )
    }
    
    /**
     * Save economic state to persistence layer
     */
    suspend fun saveState(): Boolean {
        return try {
            val state = _economicState.value
            // Implementation would save to database/file
            // For now, just return success
            true
        } catch (e: Exception) {
            false
        }
    }
    
    /**
     * Load economic state from persistence layer
     */
    suspend fun loadState(): Boolean {
        return try {
            // Implementation would load from database/file
            // For now, just return success
            true
        } catch (e: Exception) {
            false
        }
    }
    
    /**
     * Shutdown the economic state manager
     */
    fun shutdown() {
        isRunning = false
        eventSystem.shutdown()
        job.cancel()
    }
    
    // Helper methods
    
    private fun getInitialPrice(commodityType: CommodityType): Double {
        return when (commodityType) {
            CommodityType.FOOD -> 100.0
            CommodityType.FUEL -> 150.0
            CommodityType.RAW_MATERIALS -> 80.0
            CommodityType.ELECTRONICS -> 500.0
            CommodityType.MACHINERY -> 1000.0
            CommodityType.VEHICLES -> 25000.0
            CommodityType.CLOTHING -> 50.0
            CommodityType.PHARMACEUTICALS -> 200.0
            CommodityType.LUXURY_GOODS -> 1000.0
            CommodityType.CONSTRUCTION_MATERIALS -> 120.0
            CommodityType.ELECTRICITY -> 0.15
            CommodityType.NATURAL_GAS -> 4.0
            CommodityType.RENEWABLE_ENERGY_CREDITS -> 10.0
        }
    }
    
    private fun getBaseElasticity(commodityType: CommodityType): Double {
        return when (commodityType) {
            CommodityType.FOOD -> 0.8 // Inelastic
            CommodityType.FUEL -> 0.9 // Inelastic
            CommodityType.LUXURY_GOODS -> 2.0 // Elastic
            CommodityType.ELECTRONICS -> 1.5 // Elastic
            else -> 1.2 // Default elasticity
        }
    }
    
    private fun calculateCPI(commodityPrices: Map<String, Double>): Double {
        // Simplified CPI calculation using commodity prices
        val weights = mapOf(
            "FOOD" to 0.3,
            "FUEL" to 0.2,
            "CLOTHING" to 0.1,
            "ELECTRONICS" to 0.1,
            "CONSTRUCTION_MATERIALS" to 0.15,
            "PHARMACEUTICALS" to 0.1,
            "LUXURY_GOODS" to 0.05
        )
        
        return weights.entries.sumOf { (commodity, weight) ->
            (commodityPrices[commodity] ?: 100.0) * weight
        }
    }
    
    private fun calculateGDPGrowth(marketConditions: MarketConditions): Double {
        // Simplified GDP growth based on market activity
        val marketIndex = marketConditions.marketIndex
        return ((marketIndex - 1000.0) / 1000.0) * 100 // Percentage growth from baseline
    }
    
    private fun calculateInflationRate(cpi: Double): Double {
        // Simple inflation calculation (would need historical CPI data)
        return ((cpi - 100.0) / 100.0) * 100 // Percentage change from baseline
    }
    
    private fun calculateConfidenceIndex(
        marketConditions: MarketConditions,
        laborStats: LaborMarketStats,
        commodityPrices: Map<String, Double>
    ): Double {
        // Confidence index based on multiple factors
        val marketFactor = (marketConditions.marketIndex / 1000.0).coerceIn(0.5, 2.0)
        val unemploymentFactor = 1.0 - laborStats.unemploymentRates.values.average()
        val volatilityFactor = 1.0 - marketConditions.marketVolatility
        
        return ((marketFactor + unemploymentFactor + volatilityFactor) / 3.0) * 100
    }
    
    private fun calculateTradeVolumeIndex(): Double = 100.0 // Simplified
    
    private fun calculateComplexityIndex(): Double = 75.0 // Simplified
    
    private fun getMemoryUsage(): Double {
        val runtime = Runtime.getRuntime()
        return (runtime.totalMemory() - runtime.freeMemory()) / (1024.0 * 1024.0)
    }
    
    private fun isSystemHealthy(): Boolean {
        val avgUpdateTime = updateTimes.average()
        return avgUpdateTime < 1000.0 && // Updates complete within 1 second
               updateTimes.isNotEmpty() && // System is running
               getMemoryUsage() < 500.0 // Memory usage under 500MB
    }
}

/**
 * Complete economic state snapshot
 */
data class EconomicState(
    val timestamp: Long,
    val commodityPrices: Map<String, Double>,
    val marketConditions: MarketConditions,
    val laborStatistics: LaborMarketStats,
    val interconnectionStats: InterconnectionStats,
    val eventConditions: EconomicConditions,
    val economicIndicators: EconomicIndicators,
    val updatePerformance: UpdatePerformance
) {
    companion object {
        fun initial() = EconomicState(
            timestamp = System.currentTimeMillis(),
            commodityPrices = emptyMap(),
            marketConditions = MarketConditions(0.05, 0.02, 1000.0, 100.0, 0.15, 0.0, 0.0, 0.0),
            laborStatistics = LaborMarketStats(emptyMap(), emptyMap(), emptyMap(), 0, 0, 0.0),
            interconnectionStats = InterconnectionStats(0, 0.0, 0, 0, emptyMap()),
            eventConditions = EconomicConditions(0.0, EconomicCycle.EXPANSION, emptyList(), 0, emptyMap()),
            economicIndicators = EconomicIndicators(100.0, 0.0, 0.05, 0.0, 50.0, 100.0, 75.0),
            updatePerformance = UpdatePerformance(0.0, 0L, 0.0)
        )
    }
}

/**
 * High-level economic indicators
 */
data class EconomicIndicators(
    val cpi: Double, // Consumer Price Index
    val gdpGrowthRate: Double, // GDP growth rate (%)
    val unemploymentRate: Double, // Unemployment rate (%)
    val inflationRate: Double, // Inflation rate (%)
    val marketConfidenceIndex: Double, // Market confidence (0-100)
    val tradeVolumeIndex: Double, // Trade volume index
    val economicComplexityIndex: Double // Economic complexity index
)

/**
 * Market update notification
 */
data class MarketUpdate(
    val marketId: String,
    val updateType: MarketUpdateType,
    val oldValue: Double,
    val newValue: Double,
    val changePercent: Double,
    val timestamp: Long
)

/**
 * Types of market updates
 */
enum class MarketUpdateType {
    PRICE_CHANGE,
    VOLUME_SPIKE,
    LIQUIDITY_CHANGE,
    VOLATILITY_CHANGE
}

/**
 * Economic event notification
 */
data class EconomicEventNotification(
    val title: String,
    val description: String,
    val severity: EventSeverity,
    val timestamp: Long
)

/**
 * Update performance metrics
 */
data class UpdatePerformance(
    val averageUpdateTimeMs: Double,
    val lastUpdateTime: Long,
    val updatesPerMinute: Double
)

/**
 * System performance metrics
 */
data class PerformanceMetrics(
    val averageUpdateTimeMs: Double,
    val maxUpdateTimeMs: Double,
    val minUpdateTimeMs: Double,
    val totalUpdates: Long,
    val memoryUsageMB: Double,
    val isHealthy: Boolean
)