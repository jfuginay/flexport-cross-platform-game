package com.flexport.ai.systems

import com.flexport.ai.models.*
import com.flexport.economics.EconomicEngine
import com.flexport.economics.models.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import kotlin.math.*
import kotlin.random.Random

/**
 * System managing economic impact of AI advancement on markets
 */
class AIEconomicImpactSystem(
    private val economicEngine: EconomicEngine
) {
    
    private val _economicImpact = MutableStateFlow(
        AIEconomicImpactState()
    )
    val economicImpact: StateFlow<AIEconomicImpactState> = _economicImpact.asStateFlow()
    
    private val _marketDisruptions = MutableSharedFlow<MarketDisruption>()
    val marketDisruptions: SharedFlow<MarketDisruption> = _marketDisruptions.asSharedFlow()
    
    private val _economicShifts = MutableSharedFlow<EconomicShift>()
    val economicShifts: SharedFlow<EconomicShift> = _economicShifts.asSharedFlow()
    
    private var impactJob: Job? = null
    private var isRunning = false
    
    // Market impact tracking
    private val priceHistory = mutableMapOf<CommodityType, MutableList<PricePoint>>()
    private val volatilityMetrics = mutableMapOf<CommodityType, VolatilityMetrics>()
    private val aiMarketShare = mutableMapOf<CommodityType, Double>()
    
    // Economic transformation tracking
    private val economicIndicatorHistory = mutableListOf<EconomicIndicatorSnapshot>()
    private var baselineEconomicState: EconomicIndicators? = null
    
    /**
     * Initialize the AI economic impact system
     */
    fun initialize() {
        if (isRunning) return
        
        // Capture baseline economic state
        baselineEconomicState = economicEngine.getEconomicIndicators()
        
        startImpactTracking()
        isRunning = true
        println("AI Economic Impact System initialized")
    }
    
    /**
     * Start tracking economic impacts
     */
    private fun startImpactTracking() {
        impactJob = CoroutineScope(Dispatchers.Default).launch {
            while (isRunning) {
                analyzeMarketImpacts()
                trackEconomicShifts()
                simulateAIMarketInfluence()
                detectMarketDisruptions()
                delay(3000) // Update every 3 seconds
            }
        }
    }
    
    /**
     * Analyze AI impacts on individual markets
     */
    private suspend fun analyzeMarketImpacts() {
        val currentImpact = _economicImpact.value
        val updatedMarketImpacts = mutableMapOf<CommodityType, MarketImpactMetrics>()
        
        for (commodity in CommodityType.values()) {
            val impact = analyzeMarketImpact(commodity)
            updatedMarketImpacts[commodity] = impact
            
            // Update price history
            val currentPrice = economicEngine.getCommodityPrice(commodity)
            updatePriceHistory(commodity, currentPrice)
            
            // Update volatility metrics
            updateVolatilityMetrics(commodity)
        }
        
        val newState = currentImpact.copy(
            marketImpacts = updatedMarketImpacts,
            lastUpdate = System.currentTimeMillis()
        )
        
        _economicImpact.value = newState
    }
    
    /**
     * Analyze AI impact on a specific market
     */
    private fun analyzeMarketImpact(commodity: CommodityType): MarketImpactMetrics {
        val marketStats = economicEngine.getCommodityMarketStats(commodity)
        val currentPrice = economicEngine.getCommodityPrice(commodity)
        
        // Calculate various impact metrics
        val priceVolatility = calculatePriceVolatility(commodity)
        val liquidityImpact = calculateLiquidityImpact(commodity)
        val efficiencyChange = calculateEfficiencyChange(commodity)
        val aiDominance = calculateAIDominance(commodity)
        val humanCompetitiveness = calculateHumanCompetitiveness(commodity, aiDominance)
        
        return MarketImpactMetrics(
            commodity = commodity,
            priceVolatility = priceVolatility,
            liquidityImpact = liquidityImpact,
            efficiencyChange = efficiencyChange,
            aiMarketShare = aiDominance,
            humanCompetitiveness = humanCompetitiveness,
            disruptionLevel = calculateDisruptionLevel(priceVolatility, aiDominance),
            adaptationRequired = calculateAdaptationRequired(aiDominance, efficiencyChange)
        )
    }
    
    /**
     * Calculate price volatility influenced by AI
     */
    private fun calculatePriceVolatility(commodity: CommodityType): Double {
        val history = priceHistory[commodity] ?: return 0.1
        if (history.size < 10) return 0.1
        
        val recent = history.takeLast(10)
        val prices = recent.map { it.price }
        val mean = prices.average()
        val variance = prices.map { (it - mean).pow(2) }.average()
        val stdDev = sqrt(variance)
        
        return (stdDev / mean).coerceIn(0.0, 1.0)
    }
    
    /**
     * Calculate liquidity impact from AI trading
     */
    private fun calculateLiquidityImpact(commodity: CommodityType): Double {
        val aiShare = aiMarketShare[commodity] ?: 0.0
        // AI typically increases liquidity initially, then can create fragility
        return if (aiShare < 0.5) {
            aiShare * 0.4 // Positive liquidity impact
        } else {
            0.2 - (aiShare - 0.5) * 0.8 // Negative impact as AI dominates
        }
    }
    
    /**
     * Calculate efficiency changes from AI participation
     */
    private fun calculateEfficiencyChange(commodity: CommodityType): Double {
        val aiShare = aiMarketShare[commodity] ?: 0.0
        val baseEfficiency = 0.7 // Baseline human efficiency
        val aiEfficiencyBonus = aiShare * 0.6 // AI efficiency gains
        
        return (baseEfficiency + aiEfficiencyBonus).coerceAtMost(1.0)
    }
    
    /**
     * Calculate AI dominance in market
     */
    private fun calculateAIDominance(commodity: CommodityType): Double {
        // Simulate AI market share growth based on capabilities
        val currentShare = aiMarketShare[commodity] ?: 0.1
        val growthRate = Random.nextDouble(0.01, 0.05) // 1-5% growth per update
        val newShare = (currentShare + growthRate).coerceAtMost(0.95)
        
        aiMarketShare[commodity] = newShare
        return newShare
    }
    
    /**
     * Calculate human competitiveness in AI-dominated market
     */
    private fun calculateHumanCompetitiveness(commodity: CommodityType, aiDominance: Double): Double {
        val competitivenessDecay = aiDominance * 0.8
        return (1.0 - competitivenessDecay).coerceIn(0.05, 1.0)
    }
    
    /**
     * Calculate market disruption level
     */
    private fun calculateDisruptionLevel(volatility: Double, aiDominance: Double): DisruptionLevel {
        val disruptionScore = volatility * 0.6 + aiDominance * 0.4
        
        return when {
            disruptionScore < 0.2 -> DisruptionLevel.MINIMAL
            disruptionScore < 0.4 -> DisruptionLevel.LOW
            disruptionScore < 0.6 -> DisruptionLevel.MODERATE
            disruptionScore < 0.8 -> DisruptionLevel.HIGH
            else -> DisruptionLevel.SEVERE
        }
    }
    
    /**
     * Calculate adaptation required for human players
     */
    private fun calculateAdaptationRequired(aiDominance: Double, efficiency: Double): AdaptationLevel {
        val adaptationScore = aiDominance * 0.7 + (1.0 - efficiency) * 0.3
        
        return when {
            adaptationScore < 0.2 -> AdaptationLevel.MINIMAL
            adaptationScore < 0.4 -> AdaptationLevel.MODERATE
            adaptationScore < 0.6 -> AdaptationLevel.SIGNIFICANT
            adaptationScore < 0.8 -> AdaptationLevel.MAJOR
            else -> AdaptationLevel.FUNDAMENTAL
        }
    }
    
    /**
     * Update price history for volatility calculations
     */
    private fun updatePriceHistory(commodity: CommodityType, price: Double) {
        val history = priceHistory.getOrPut(commodity) { mutableListOf() }
        history.add(PricePoint(price, System.currentTimeMillis()))
        
        // Keep only last 100 price points
        if (history.size > 100) {
            history.removeFirst()
        }
    }
    
    /**
     * Update volatility metrics
     */
    private fun updateVolatilityMetrics(commodity: CommodityType) {
        val history = priceHistory[commodity] ?: return
        if (history.size < 5) return
        
        val recent = history.takeLast(20)
        val prices = recent.map { it.price }
        
        val mean = prices.average()
        val variance = prices.map { (it - mean).pow(2) }.average()
        val stdDev = sqrt(variance)
        
        val metrics = VolatilityMetrics(
            mean = mean,
            standardDeviation = stdDev,
            coefficient = if (mean > 0) stdDev / mean else 0.0,
            lastUpdate = System.currentTimeMillis()
        )
        
        volatilityMetrics[commodity] = metrics
    }
    
    /**
     * Track broader economic shifts
     */
    private suspend fun trackEconomicShifts() {
        val currentIndicators = economicEngine.getEconomicIndicators()
        val baseline = baselineEconomicState ?: return
        
        // Record snapshot
        economicIndicatorHistory.add(
            EconomicIndicatorSnapshot(
                indicators = currentIndicators,
                timestamp = System.currentTimeMillis()
            )
        )
        
        // Keep only last 200 snapshots
        if (economicIndicatorHistory.size > 200) {
            economicIndicatorHistory.removeFirst()
        }
        
        // Detect significant shifts
        val shifts = detectEconomicShifts(baseline, currentIndicators)
        
        for (shift in shifts) {
            _economicShifts.emit(shift)
        }
        
        // Update economic impact state
        val currentImpact = _economicImpact.value
        val newState = currentImpact.copy(
            overallEconomicShift = calculateOverallEconomicShift(baseline, currentIndicators),
            gdpImpact = calculateGDPImpact(baseline, currentIndicators),
            unemploymentImpact = calculateUnemploymentImpact(baseline, currentIndicators),
            inflationImpact = calculateInflationImpact(baseline, currentIndicators),
            productivityGains = calculateProductivityGains()
        )
        
        _economicImpact.value = newState
    }
    
    /**
     * Detect significant economic shifts
     */
    private fun detectEconomicShifts(baseline: EconomicIndicators, current: EconomicIndicators): List<EconomicShift> {
        val shifts = mutableListOf<EconomicShift>()
        
        // GDP shift
        val gdpChange = current.gdpGrowthRate - baseline.gdpGrowthRate
        if (abs(gdpChange) > 0.5) {
            shifts.add(EconomicShift(
                type = EconomicShiftType.GDP_DISRUPTION,
                magnitude = abs(gdpChange),
                direction = if (gdpChange > 0) ShiftDirection.POSITIVE else ShiftDirection.NEGATIVE,
                description = "AI impact causing ${if (gdpChange > 0) "accelerated" else "disrupted"} GDP growth"
            ))
        }
        
        // Unemployment shift
        val unemploymentChange = current.unemploymentRate - baseline.unemploymentRate
        if (abs(unemploymentChange) > 1.0) {
            shifts.add(EconomicShift(
                type = EconomicShiftType.LABOR_DISPLACEMENT,
                magnitude = abs(unemploymentChange),
                direction = if (unemploymentChange > 0) ShiftDirection.NEGATIVE else ShiftDirection.POSITIVE,
                description = "AI automation ${if (unemploymentChange > 0) "increasing" else "reducing"} unemployment"
            ))
        }
        
        // Market confidence shift
        val confidenceChange = current.marketConfidenceIndex - baseline.marketConfidenceIndex
        if (abs(confidenceChange) > 10.0) {
            shifts.add(EconomicShift(
                type = EconomicShiftType.MARKET_CONFIDENCE,
                magnitude = abs(confidenceChange) / 100.0,
                direction = if (confidenceChange > 0) ShiftDirection.POSITIVE else ShiftDirection.NEGATIVE,
                description = "AI developments ${if (confidenceChange > 0) "boosting" else "undermining"} market confidence"
            ))
        }
        
        return shifts
    }
    
    /**
     * Simulate AI market influence through direct economic actions
     */
    private suspend fun simulateAIMarketInfluence() {
        // Simulate AI-driven market manipulation and efficiency improvements
        val totalAIImpact = calculateTotalAIMarketImpact()
        
        if (totalAIImpact > 0.3) {
            // Significant AI presence - create market effects
            simulateMarketEfficiencies()
            simulatePriceOptimization()
            simulateSupplyChainOptimization()
        }
    }
    
    /**
     * Calculate total AI impact across all markets
     */
    private fun calculateTotalAIMarketImpact(): Double {
        return aiMarketShare.values.average()
    }
    
    /**
     * Simulate market efficiency improvements from AI
     */
    private fun simulateMarketEfficiencies() {
        // AI reduces transaction costs and improves market making
        val efficiencyGain = Random.nextDouble(0.01, 0.03)
        
        // This would integrate with the economic engine to reduce spreads,
        // improve liquidity, and optimize pricing
    }
    
    /**
     * Simulate AI-driven price optimization
     */
    private fun simulatePriceOptimization() {
        // AI competitors optimize pricing strategies
        // This could affect commodity prices through the economic engine
        CommodityType.values().forEach { commodity ->
            val aiShare = aiMarketShare[commodity] ?: 0.0
            if (aiShare > 0.4) {
                // High AI presence leads to more efficient pricing
                val optimizationFactor = aiShare * 0.1
                // Apply price optimization through economic engine
            }
        }
    }
    
    /**
     * Simulate supply chain optimization by AI
     */
    private fun simulateSupplyChainOptimization() {
        // AI optimizes logistics and reduces costs
        val costReduction = Random.nextDouble(0.02, 0.08)
        
        // This would reduce transportation costs and improve delivery times
        // affecting the overall economic efficiency
    }
    
    /**
     * Detect market disruptions caused by AI
     */
    private suspend fun detectMarketDisruptions() {
        val currentImpact = _economicImpact.value
        
        for ((commodity, impact) in currentImpact.marketImpacts) {
            if (impact.disruptionLevel == DisruptionLevel.HIGH || 
                impact.disruptionLevel == DisruptionLevel.SEVERE) {
                
                val disruption = MarketDisruption(
                    commodity = commodity,
                    disruptionType = determineDisruptionType(impact),
                    severity = impact.disruptionLevel,
                    aiMarketShare = impact.aiMarketShare,
                    humanImpact = calculateHumanImpact(impact),
                    description = generateDisruptionDescription(commodity, impact),
                    timestamp = System.currentTimeMillis()
                )
                
                _marketDisruptions.emit(disruption)
            }
        }
    }
    
    /**
     * Determine type of market disruption
     */
    private fun determineDisruptionType(impact: MarketImpactMetrics): DisruptionType {
        return when {
            impact.priceVolatility > 0.6 -> DisruptionType.PRICE_VOLATILITY
            impact.aiMarketShare > 0.8 -> DisruptionType.MARKET_DOMINANCE
            impact.liquidityImpact < -0.3 -> DisruptionType.LIQUIDITY_CRISIS
            impact.humanCompetitiveness < 0.2 -> DisruptionType.COMPETITIVE_DISPLACEMENT
            else -> DisruptionType.EFFICIENCY_DISRUPTION
        }
    }
    
    /**
     * Calculate impact on human participants
     */
    private fun calculateHumanImpact(impact: MarketImpactMetrics): HumanImpactLevel {
        val impactScore = (1.0 - impact.humanCompetitiveness) * 0.6 + 
                         impact.aiMarketShare * 0.4
        
        return when {
            impactScore < 0.2 -> HumanImpactLevel.MINIMAL
            impactScore < 0.4 -> HumanImpactLevel.MODERATE
            impactScore < 0.6 -> HumanImpactLevel.SIGNIFICANT
            impactScore < 0.8 -> HumanImpactLevel.SEVERE
            else -> HumanImpactLevel.EXISTENTIAL
        }
    }
    
    /**
     * Generate disruption description
     */
    private fun generateDisruptionDescription(commodity: CommodityType, impact: MarketImpactMetrics): String {
        val aiSharePercent = (impact.aiMarketShare * 100).toInt()
        val competitivenessPercent = (impact.humanCompetitiveness * 100).toInt()
        
        return "AI entities control ${aiSharePercent}% of ${commodity.name} market. " +
               "Human competitiveness down to ${competitivenessPercent}%. " +
               "Adaptation level: ${impact.adaptationRequired.name}"
    }
    
    /**
     * Calculate overall economic shift magnitude
     */
    private fun calculateOverallEconomicShift(baseline: EconomicIndicators, current: EconomicIndicators): Double {
        val gdpShift = abs(current.gdpGrowthRate - baseline.gdpGrowthRate) / 10.0
        val unemploymentShift = abs(current.unemploymentRate - baseline.unemploymentRate) / 20.0
        val inflationShift = abs(current.inflationRate - baseline.inflationRate) / 10.0
        val confidenceShift = abs(current.marketConfidenceIndex - baseline.marketConfidenceIndex) / 100.0
        
        return (gdpShift + unemploymentShift + inflationShift + confidenceShift) / 4.0
    }
    
    /**
     * Calculate GDP impact from AI
     */
    private fun calculateGDPImpact(baseline: EconomicIndicators, current: EconomicIndicators): Double {
        return current.gdpGrowthRate - baseline.gdpGrowthRate
    }
    
    /**
     * Calculate unemployment impact from AI
     */
    private fun calculateUnemploymentImpact(baseline: EconomicIndicators, current: EconomicIndicators): Double {
        return current.unemploymentRate - baseline.unemploymentRate
    }
    
    /**
     * Calculate inflation impact from AI
     */
    private fun calculateInflationImpact(baseline: EconomicIndicators, current: EconomicIndicators): Double {
        return current.inflationRate - baseline.inflationRate
    }
    
    /**
     * Calculate productivity gains from AI
     */
    private fun calculateProductivityGains(): Double {
        val totalAIShare = aiMarketShare.values.average()
        val efficiencyGains = _economicImpact.value.marketImpacts.values
            .map { it.efficiencyChange }.average()
        
        return totalAIShare * efficiencyGains * 0.5
    }
    
    /**
     * Apply AI-driven market modifier
     */
    fun applyAIMarketModifier(commodity: CommodityType, modifier: AIMarketModifier) {
        when (modifier.type) {
            ModifierType.PRICE_MANIPULATION -> {
                // Would integrate with economic engine to affect prices
                println("AI price manipulation on ${commodity.name}: ${modifier.magnitude}")
            }
            ModifierType.SUPPLY_OPTIMIZATION -> {
                // Improve supply chain efficiency
                println("AI supply optimization for ${commodity.name}: +${modifier.magnitude}")
            }
            ModifierType.DEMAND_PREDICTION -> {
                // Better demand forecasting affects market dynamics
                println("AI demand prediction for ${commodity.name}: ${modifier.magnitude}")
            }
            ModifierType.LIQUIDITY_INJECTION -> {
                // AI market makers improve liquidity
                println("AI liquidity injection for ${commodity.name}: +${modifier.magnitude}")
            }
        }
    }
    
    /**
     * Get market impact summary
     */
    fun getMarketImpactSummary(): MarketImpactSummary {
        val currentState = _economicImpact.value
        
        return MarketImpactSummary(
            totalMarketsAffected = currentState.marketImpacts.size,
            averageAIMarketShare = currentState.marketImpacts.values.map { it.aiMarketShare }.average(),
            averageHumanCompetitiveness = currentState.marketImpacts.values.map { it.humanCompetitiveness }.average(),
            highDisruptionMarkets = currentState.marketImpacts.values.count { 
                it.disruptionLevel == DisruptionLevel.HIGH || it.disruptionLevel == DisruptionLevel.SEVERE 
            },
            overallEconomicShift = currentState.overallEconomicShift,
            productivityGains = currentState.productivityGains
        )
    }
    
    /**
     * Shutdown the system
     */
    fun shutdown() {
        isRunning = false
        impactJob?.cancel()
        println("AI Economic Impact System shut down")
    }
}

// Supporting data classes and enums

data class AIEconomicImpactState(
    val marketImpacts: Map<CommodityType, MarketImpactMetrics> = emptyMap(),
    val overallEconomicShift: Double = 0.0,
    val gdpImpact: Double = 0.0,
    val unemploymentImpact: Double = 0.0,
    val inflationImpact: Double = 0.0,
    val productivityGains: Double = 0.0,
    val lastUpdate: Long = System.currentTimeMillis()
)

data class MarketImpactMetrics(
    val commodity: CommodityType,
    val priceVolatility: Double,
    val liquidityImpact: Double,
    val efficiencyChange: Double,
    val aiMarketShare: Double,
    val humanCompetitiveness: Double,
    val disruptionLevel: DisruptionLevel,
    val adaptationRequired: AdaptationLevel
)

data class PricePoint(
    val price: Double,
    val timestamp: Long
)

data class VolatilityMetrics(
    val mean: Double,
    val standardDeviation: Double,
    val coefficient: Double,
    val lastUpdate: Long
)

data class EconomicIndicatorSnapshot(
    val indicators: EconomicIndicators,
    val timestamp: Long
)

data class MarketDisruption(
    val commodity: CommodityType,
    val disruptionType: DisruptionType,
    val severity: DisruptionLevel,
    val aiMarketShare: Double,
    val humanImpact: HumanImpactLevel,
    val description: String,
    val timestamp: Long
)

data class EconomicShift(
    val type: EconomicShiftType,
    val magnitude: Double,
    val direction: ShiftDirection,
    val description: String,
    val timestamp: Long = System.currentTimeMillis()
)

data class AIMarketModifier(
    val type: ModifierType,
    val magnitude: Double,
    val duration: Long
)

data class MarketImpactSummary(
    val totalMarketsAffected: Int,
    val averageAIMarketShare: Double,
    val averageHumanCompetitiveness: Double,
    val highDisruptionMarkets: Int,
    val overallEconomicShift: Double,
    val productivityGains: Double
)

enum class DisruptionLevel {
    MINIMAL, LOW, MODERATE, HIGH, SEVERE
}

enum class AdaptationLevel {
    MINIMAL, MODERATE, SIGNIFICANT, MAJOR, FUNDAMENTAL
}

enum class DisruptionType {
    PRICE_VOLATILITY,
    MARKET_DOMINANCE,
    LIQUIDITY_CRISIS,
    COMPETITIVE_DISPLACEMENT,
    EFFICIENCY_DISRUPTION
}

enum class HumanImpactLevel {
    MINIMAL, MODERATE, SIGNIFICANT, SEVERE, EXISTENTIAL
}

enum class EconomicShiftType {
    GDP_DISRUPTION,
    LABOR_DISPLACEMENT,
    MARKET_CONFIDENCE,
    PRODUCTIVITY_BOOST,
    INFLATION_PRESSURE
}

enum class ShiftDirection {
    POSITIVE, NEGATIVE, NEUTRAL
}

enum class ModifierType {
    PRICE_MANIPULATION,
    SUPPLY_OPTIMIZATION,
    DEMAND_PREDICTION,
    LIQUIDITY_INJECTION
}