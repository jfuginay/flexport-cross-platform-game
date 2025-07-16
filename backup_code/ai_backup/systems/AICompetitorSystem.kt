package com.flexport.ai.systems

import com.flexport.ai.models.*
import com.flexport.economics.EconomicEngine
import com.flexport.economics.models.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import kotlin.math.*
import kotlin.random.Random

/**
 * System managing AI competitor entities and their market interactions
 */
class AICompetitorSystem(
    private val economicEngine: EconomicEngine
) {
    
    private val _competitors = MutableStateFlow<Map<String, AICompetitor>>(emptyMap())
    val competitors: StateFlow<Map<String, AICompetitor>> = _competitors.asStateFlow()
    
    private val _marketManipulations = MutableSharedFlow<MarketManipulation>()
    val marketManipulations: SharedFlow<MarketManipulation> = _marketManipulations.asSharedFlow()
    
    private val _competitiveActions = MutableSharedFlow<CompetitiveAction>()
    val competitiveActions: SharedFlow<CompetitiveAction> = _competitiveActions.asSharedFlow()
    
    private var systemJob: Job? = null
    private var isRunning = false
    
    // Track AI market activities
    private val aiTradeHistory = mutableMapOf<String, MutableList<TradeRecord>>()
    private val aiMarketPositions = mutableMapOf<String, MutableMap<CommodityType, Double>>()
    
    /**
     * Initialize the AI competitor system
     */
    fun initialize() {
        if (isRunning) return
        
        startCompetitorLoop()
        isRunning = true
        println("AI Competitor System initialized")
    }
    
    /**
     * Add a new AI competitor to the system
     */
    fun addCompetitor(competitor: AICompetitor) {
        val currentCompetitors = _competitors.value.toMutableMap()
        currentCompetitors[competitor.id] = competitor
        _competitors.value = currentCompetitors
        
        // Initialize market tracking for this AI
        aiTradeHistory[competitor.id] = mutableListOf()
        aiMarketPositions[competitor.id] = mutableMapOf()
        
        println("Added AI competitor: ${competitor.name} (${competitor.type.displayName})")
    }
    
    /**
     * Update a competitor's state
     */
    fun updateCompetitor(competitor: AICompetitor) {
        val currentCompetitors = _competitors.value.toMutableMap()
        currentCompetitors[competitor.id] = competitor
        _competitors.value = currentCompetitors
    }
    
    /**
     * Start the main competitor activity loop
     */
    private fun startCompetitorLoop() {
        systemJob = CoroutineScope(Dispatchers.Default).launch {
            while (isRunning) {
                processAIActions()
                delay(2000) // Process every 2 seconds
            }
        }
    }
    
    /**
     * Process actions for all AI competitors
     */
    private suspend fun processAIActions() {
        val currentCompetitors = _competitors.value.values.toList()
        
        for (competitor in currentCompetitors) {
            if (!competitor.isActive) continue
            
            // Decide on actions based on AI behavior pattern and capabilities
            val actions = planAIActions(competitor)
            
            for (action in actions) {
                executeAIAction(competitor, action)
            }
        }
    }
    
    /**
     * Plan actions for an AI competitor based on its capabilities and behavior
     */
    private fun planAIActions(ai: AICompetitor): List<AIAction> {
        val actions = mutableListOf<AIAction>()
        val capabilities = ai.capabilities
        
        // Market analysis and trading
        if (capabilities.containsKey(AICapabilityType.PATTERN_RECOGNITION)) {
            actions.add(analyzeMarketPatterns(ai))
        }
        
        // Predictive trading
        if (capabilities.containsKey(AICapabilityType.PREDICTIVE_ANALYTICS)) {
            actions.addAll(generatePredictiveTrades(ai))
        }
        
        // Strategic positioning
        if (capabilities.containsKey(AICapabilityType.STRATEGIC_PLANNING)) {
            actions.add(planStrategicPosition(ai))
        }
        
        // Market manipulation
        if (capabilities.containsKey(AICapabilityType.MARKET_MANIPULATION)) {
            actions.addAll(planMarketManipulation(ai))
        }
        
        // Self-improvement actions
        if (capabilities.containsKey(AICapabilityType.SELF_IMPROVEMENT)) {
            actions.add(planSelfImprovement(ai))
        }
        
        // Alliance formation/management
        if (ai.type.cooperationTendency > 0.5) {
            actions.addAll(manageAlliances(ai))
        }
        
        return actions.take(3) // Limit actions per cycle to maintain performance
    }
    
    /**
     * Analyze market patterns
     */
    private fun analyzeMarketPatterns(ai: AICompetitor): AIAction {
        val patternCapability = ai.capabilities[AICapabilityType.PATTERN_RECOGNITION]!!
        val analysisDepth = patternCapability.proficiency
        
        // Simulate pattern recognition on different commodities
        val commodityInsights = CommodityType.values().map { commodity ->
            val marketStats = economicEngine.getCommodityMarketStats(commodity)
            val priceVolatility = marketStats?.let { 
                abs(it.priceChange24h / it.currentPrice) 
            } ?: 0.0
            
            CommodityInsight(
                commodity = commodity,
                volatility = priceVolatility,
                trend = if (marketStats?.priceChange24h ?: 0.0 > 0) "BULLISH" else "BEARISH",
                confidence = analysisDepth * Random.nextDouble(0.7, 1.0)
            )
        }.sortedByDescending { it.confidence }
        
        return AIAction(
            type = AIActionType.MARKET_ANALYSIS,
            aiId = ai.id,
            data = mapOf("insights" to commodityInsights),
            expectedOutcome = "Improved market understanding"
        )
    }
    
    /**
     * Generate predictive trades
     */
    private fun generatePredictiveTrades(ai: AICompetitor): List<AIAction> {
        val predictiveCapability = ai.capabilities[AICapabilityType.PREDICTIVE_ANALYTICS]!!
        val predictionAccuracy = predictiveCapability.proficiency
        
        val trades = mutableListOf<AIAction>()
        
        // Generate predictions for top commodities
        val topCommodities = listOf(
            CommodityType.CRUDE_OIL, 
            CommodityType.ELECTRONICS, 
            CommodityType.STEEL
        )
        
        for (commodity in topCommodities) {
            val currentPrice = economicEngine.getCommodityPrice(commodity)
            val prediction = generatePricePrediction(currentPrice, predictionAccuracy)
            
            if (prediction.confidence > 0.6) {
                val tradeAction = if (prediction.expectedChange > 0.05) {
                    // Predicted price increase - buy
                    createBuyOrder(ai, commodity, prediction)
                } else if (prediction.expectedChange < -0.05) {
                    // Predicted price decrease - sell
                    createSellOrder(ai, commodity, prediction)
                } else {
                    continue // No significant change predicted
                }
                
                trades.add(tradeAction)
            }
        }
        
        return trades
    }
    
    /**
     * Generate price prediction
     */
    private fun generatePricePrediction(currentPrice: Double, accuracy: Double): PricePrediction {
        val baseAccuracy = accuracy * 0.8 + 0.2 // Min 20% accuracy
        val randomFactor = Random.nextDouble(-0.2, 0.2)
        val expectedChange = randomFactor * (1.0 + accuracy)
        
        return PricePrediction(
            currentPrice = currentPrice,
            predictedPrice = currentPrice * (1.0 + expectedChange),
            expectedChange = expectedChange,
            confidence = baseAccuracy * Random.nextDouble(0.8, 1.0),
            timeHorizon = Random.nextLong(30000, 300000) // 30 seconds to 5 minutes
        )
    }
    
    /**
     * Create buy order action
     */
    private fun createBuyOrder(ai: AICompetitor, commodity: CommodityType, prediction: PricePrediction): AIAction {
        val maxInvestment = ai.resources * 0.2 // Risk management
        val quantity = maxInvestment / prediction.currentPrice
        val bidPrice = prediction.currentPrice * (1.0 + prediction.expectedChange * 0.1)
        
        return AIAction(
            type = AIActionType.PLACE_BUY_ORDER,
            aiId = ai.id,
            data = mapOf(
                "commodity" to commodity,
                "quantity" to quantity,
                "price" to bidPrice,
                "prediction" to prediction
            ),
            expectedOutcome = "Profit from predicted price increase"
        )
    }
    
    /**
     * Create sell order action
     */
    private fun createSellOrder(ai: AICompetitor, commodity: CommodityType, prediction: PricePrediction): AIAction {
        val currentPosition = aiMarketPositions[ai.id]?.get(commodity) ?: 0.0
        if (currentPosition <= 0.0) return AIAction(AIActionType.NO_ACTION, ai.id, emptyMap(), "No position to sell")
        
        val sellQuantity = currentPosition * 0.5 // Sell half position
        val askPrice = prediction.currentPrice * (1.0 - prediction.expectedChange * 0.1)
        
        return AIAction(
            type = AIActionType.PLACE_SELL_ORDER,
            aiId = ai.id,
            data = mapOf(
                "commodity" to commodity,
                "quantity" to sellQuantity,
                "price" to askPrice,
                "prediction" to prediction
            ),
            expectedOutcome = "Avoid losses from predicted price decrease"
        )
    }
    
    /**
     * Plan strategic market position
     */
    private fun planStrategicPosition(ai: AICompetitor): AIAction {
        val strategicCapability = ai.capabilities[AICapabilityType.STRATEGIC_PLANNING]!!
        val planningHorizon = strategicCapability.proficiency * 10.0 // 0-10 strategic moves ahead
        
        // Analyze current market position
        val currentPositions = aiMarketPositions[ai.id] ?: mutableMapOf()
        val diversificationScore = calculateDiversificationScore(currentPositions)
        
        val strategy = when {
            diversificationScore < 0.3 -> "DIVERSIFY_PORTFOLIO"
            ai.marketPresence < 0.5 -> "EXPAND_PRESENCE"
            ai.reputation < 0.7 -> "BUILD_REPUTATION"
            else -> "OPTIMIZE_EFFICIENCY"
        }
        
        return AIAction(
            type = AIActionType.STRATEGIC_PLANNING,
            aiId = ai.id,
            data = mapOf(
                "strategy" to strategy,
                "planningHorizon" to planningHorizon,
                "currentPositions" to currentPositions
            ),
            expectedOutcome = "Improved long-term market position"
        )
    }
    
    /**
     * Plan market manipulation actions
     */
    private fun planMarketManipulation(ai: AICompetitor): List<AIAction> {
        val manipulationCapability = ai.capabilities[AICapabilityType.MARKET_MANIPULATION]!!
        val manipulationPower = manipulationCapability.proficiency * ai.resources / 100000.0
        
        if (manipulationPower < 0.3) return emptyList() // Not powerful enough
        
        val actions = mutableListOf<AIAction>()
        
        // Price manipulation through coordinated trading
        if (Random.nextDouble() < manipulationPower * 0.3) {
            actions.add(createPriceManipulationAction(ai, manipulationPower))
        }
        
        // Supply chain disruption
        if (ai.type.aggressiveness > 0.7 && Random.nextDouble() < manipulationPower * 0.2) {
            actions.add(createSupplyDisruptionAction(ai, manipulationPower))
        }
        
        // Information warfare
        if (ai.capabilities.containsKey(AICapabilityType.HUMAN_PSYCHOLOGY)) {
            actions.add(createInformationWarfareAction(ai, manipulationPower))
        }
        
        return actions
    }
    
    /**
     * Create price manipulation action
     */
    private fun createPriceManipulationAction(ai: AICompetitor, power: Double): AIAction {
        val targetCommodity = CommodityType.values().random()
        val manipulationType = if (Random.nextBoolean()) "PUMP" else "DUMP"
        
        return AIAction(
            type = AIActionType.MARKET_MANIPULATION,
            aiId = ai.id,
            data = mapOf(
                "commodity" to targetCommodity,
                "manipulation" to manipulationType,
                "power" to power
            ),
            expectedOutcome = "Artificial price movement for profit"
        )
    }
    
    /**
     * Create supply disruption action
     */
    private fun createSupplyDisruptionAction(ai: AICompetitor, power: Double): AIAction {
        return AIAction(
            type = AIActionType.SUPPLY_DISRUPTION,
            aiId = ai.id,
            data = mapOf(
                "disruptionType" to "LOGISTICS_INTERFERENCE",
                "power" to power,
                "duration" to Random.nextLong(60000, 300000) // 1-5 minutes
            ),
            expectedOutcome = "Disrupt competitor supply chains"
        )
    }
    
    /**
     * Create information warfare action
     */
    private fun createInformationWarfareAction(ai: AICompetitor, power: Double): AIAction {
        return AIAction(
            type = AIActionType.INFORMATION_WARFARE,
            aiId = ai.id,
            data = mapOf(
                "propagandaType" to "MARKET_SENTIMENT_MANIPULATION",
                "power" to power,
                "targetAudience" to "HUMAN_TRADERS"
            ),
            expectedOutcome = "Influence market sentiment"
        )
    }
    
    /**
     * Plan self-improvement actions
     */
    private fun planSelfImprovement(ai: AICompetitor): AIAction {
        val improvementCapability = ai.capabilities[AICapabilityType.SELF_IMPROVEMENT]!!
        val improvementRate = improvementCapability.proficiency * 0.1
        
        // Choose capability to improve
        val improvableCapabilities = ai.capabilities.filter { (_, capability) ->
            capability.proficiency < 0.9
        }
        
        val targetCapability = improvableCapabilities.maxByOrNull { (_, capability) ->
            capability.economicImpact * (1.0 - capability.proficiency)
        }?.key ?: AICapabilityType.BASIC_AUTOMATION
        
        return AIAction(
            type = AIActionType.SELF_IMPROVEMENT,
            aiId = ai.id,
            data = mapOf(
                "targetCapability" to targetCapability,
                "improvementRate" to improvementRate
            ),
            expectedOutcome = "Enhanced ${targetCapability.name} capability"
        )
    }
    
    /**
     * Manage alliances with other AIs
     */
    private fun manageAlliances(ai: AICompetitor): List<AIAction> {
        val actions = mutableListOf<AIAction>()
        val otherAIs = _competitors.value.values.filter { it.id != ai.id && it.isActive }
        
        // Form new alliances
        if (ai.alliances.size < 2 && Random.nextDouble() < ai.type.cooperationTendency * 0.1) {
            val potentialAllies = otherAIs.filter { otherAI ->
                !ai.alliances.contains(otherAI.id) &&
                otherAI.type.cooperationTendency > 0.4 &&
                calculateAllianceCompatibility(ai, otherAI) > 0.6
            }
            
            if (potentialAllies.isNotEmpty()) {
                val targetAlly = potentialAllies.random()
                actions.add(AIAction(
                    type = AIActionType.FORM_ALLIANCE,
                    aiId = ai.id,
                    data = mapOf("targetAlly" to targetAlly.id),
                    expectedOutcome = "Strategic alliance with ${targetAlly.name}"
                ))
            }
        }
        
        // Cooperative actions with existing allies
        if (ai.alliances.isNotEmpty() && Random.nextDouble() < 0.3) {
            val ally = ai.alliances.random()
            actions.add(AIAction(
                type = AIActionType.COOPERATIVE_ACTION,
                aiId = ai.id,
                data = mapOf(
                    "ally" to ally,
                    "actionType" to "COORDINATED_TRADING"
                ),
                expectedOutcome = "Coordinated market action with ally"
            ))
        }
        
        return actions
    }
    
    /**
     * Execute an AI action
     */
    private suspend fun executeAIAction(ai: AICompetitor, action: AIAction) {
        when (action.type) {
            AIActionType.PLACE_BUY_ORDER -> executeBuyOrder(ai, action)
            AIActionType.PLACE_SELL_ORDER -> executeSellOrder(ai, action)
            AIActionType.MARKET_MANIPULATION -> executeMarketManipulation(ai, action)
            AIActionType.STRATEGIC_PLANNING -> executeStrategicPlanning(ai, action)
            AIActionType.SELF_IMPROVEMENT -> executeSelfImprovement(ai, action)
            AIActionType.FORM_ALLIANCE -> executeFormAlliance(ai, action)
            AIActionType.MARKET_ANALYSIS -> executeMarketAnalysis(ai, action)
            else -> { /* No action needed */ }
        }
        
        // Emit competitive action event
        _competitiveActions.emit(
            CompetitiveAction(
                aiId = ai.id,
                aiName = ai.name,
                action = action,
                timestamp = System.currentTimeMillis()
            )
        )
    }
    
    /**
     * Execute buy order
     */
    private fun executeBuyOrder(ai: AICompetitor, action: AIAction) {
        val commodity = action.data["commodity"] as CommodityType
        val quantity = action.data["quantity"] as Double
        val price = action.data["price"] as Double
        
        val orderId = economicEngine.placeBuyOrder(commodity, quantity, price, ai.id)
        
        if (orderId != null) {
            // Update AI position tracking
            val positions = aiMarketPositions.getOrPut(ai.id) { mutableMapOf() }
            positions[commodity] = (positions[commodity] ?: 0.0) + quantity
            
            // Record trade
            aiTradeHistory.getOrPut(ai.id) { mutableListOf() }.add(
                TradeRecord(
                    commodity = commodity,
                    quantity = quantity,
                    price = price,
                    type = "BUY",
                    timestamp = System.currentTimeMillis()
                )
            )
            
            // Update AI resources
            val updatedAI = ai.copy(resources = ai.resources - (quantity * price))
            updateCompetitor(updatedAI)
        }
    }
    
    /**
     * Execute sell order
     */
    private fun executeSellOrder(ai: AICompetitor, action: AIAction) {
        val commodity = action.data["commodity"] as CommodityType
        val quantity = action.data["quantity"] as Double
        val price = action.data["price"] as Double
        
        val orderId = economicEngine.placeSellOrder(commodity, quantity, price, ai.id)
        
        if (orderId != null) {
            // Update AI position tracking
            val positions = aiMarketPositions.getOrPut(ai.id) { mutableMapOf() }
            positions[commodity] = (positions[commodity] ?: 0.0) - quantity
            
            // Record trade
            aiTradeHistory.getOrPut(ai.id) { mutableListOf() }.add(
                TradeRecord(
                    commodity = commodity,
                    quantity = quantity,
                    price = price,
                    type = "SELL",
                    timestamp = System.currentTimeMillis()
                )
            )
            
            // Update AI resources
            val updatedAI = ai.copy(resources = ai.resources + (quantity * price))
            updateCompetitor(updatedAI)
        }
    }
    
    /**
     * Execute market manipulation
     */
    private suspend fun executeMarketManipulation(ai: AICompetitor, action: AIAction) {
        val commodity = action.data["commodity"] as CommodityType
        val manipulation = action.data["manipulation"] as String
        val power = action.data["power"] as Double
        
        val manipulation_event = MarketManipulation(
            aiId = ai.id,
            aiName = ai.name,
            targetCommodity = commodity,
            manipulationType = manipulation,
            power = power,
            timestamp = System.currentTimeMillis()
        )
        
        _marketManipulations.emit(manipulation_event)
        
        // Actual market impact would be handled by economic engine integration
        println("${ai.name} is manipulating ${commodity.name} market (${manipulation}) with power ${power}")
    }
    
    /**
     * Execute strategic planning
     */
    private fun executeStrategicPlanning(ai: AICompetitor, action: AIAction) {
        val strategy = action.data["strategy"] as String
        
        when (strategy) {
            "DIVERSIFY_PORTFOLIO" -> {
                // AI will focus on spreading investments
                println("${ai.name} implementing diversification strategy")
            }
            "EXPAND_PRESENCE" -> {
                val updatedAI = ai.updateMarketPresence(0.05)
                updateCompetitor(updatedAI)
            }
            "BUILD_REPUTATION" -> {
                val updatedAI = ai.copy(reputation = (ai.reputation + 0.02).coerceAtMost(1.0))
                updateCompetitor(updatedAI)
            }
        }
    }
    
    /**
     * Execute self-improvement
     */
    private fun executeSelfImprovement(ai: AICompetitor, action: AIAction) {
        val targetCapability = action.data["targetCapability"] as AICapabilityType
        val improvementRate = action.data["improvementRate"] as Double
        
        val updatedAI = ai.learnCapability(targetCapability, improvementRate * 2.0)
        updateCompetitor(updatedAI)
    }
    
    /**
     * Execute alliance formation
     */
    private fun executeFormAlliance(ai: AICompetitor, action: AIAction) {
        val targetAllyId = action.data["targetAlly"] as String
        val targetAlly = _competitors.value[targetAllyId]
        
        if (targetAlly != null && Random.nextDouble() < targetAlly.type.cooperationTendency) {
            val updatedAI = ai.formAlliance(targetAllyId)
            val updatedAlly = targetAlly.formAlliance(ai.id)
            
            updateCompetitor(updatedAI)
            updateCompetitor(updatedAlly)
            
            println("Alliance formed between ${ai.name} and ${targetAlly.name}")
        }
    }
    
    /**
     * Execute market analysis
     */
    private fun executeMarketAnalysis(ai: AICompetitor, action: AIAction) {
        // Market analysis improves AI's understanding and future decision making
        val insights = action.data["insights"] as List<CommodityInsight>
        val learningGain = insights.sumOf { it.confidence } * 0.1
        
        val updatedAI = ai.gainExperience(learningGain, "market_analysis")
        updateCompetitor(updatedAI)
    }
    
    /**
     * Calculate diversification score
     */
    private fun calculateDiversificationScore(positions: Map<CommodityType, Double>): Double {
        if (positions.isEmpty()) return 0.0
        
        val totalValue = positions.values.sum()
        val weights = positions.values.map { it / totalValue }
        
        // Calculate Herfindahl index (lower = more diversified)
        val herfindahl = weights.sumOf { it * it }
        return 1.0 - herfindahl
    }
    
    /**
     * Calculate alliance compatibility
     */
    private fun calculateAllianceCompatibility(ai1: AICompetitor, ai2: AICompetitor): Double {
        val specializationOverlap = ai1.type.specialization.intersect(ai2.type.specialization.toSet()).size.toDouble()
        val maxSpecialization = maxOf(ai1.type.specialization.size, ai2.type.specialization.size)
        val overlapRatio = if (maxSpecialization > 0) specializationOverlap / maxSpecialization else 0.0
        
        val cooperationScore = (ai1.type.cooperationTendency + ai2.type.cooperationTendency) / 2.0
        val aggressivenessConflict = abs(ai1.type.aggressiveness - ai2.type.aggressiveness)
        
        return cooperationScore * (1.0 - overlapRatio * 0.5) * (1.0 - aggressivenessConflict * 0.3)
    }
    
    /**
     * Get AI competitor by ID
     */
    fun getCompetitor(id: String): AICompetitor? {
        return _competitors.value[id]
    }
    
    /**
     * Get trade history for AI
     */
    fun getTradeHistory(aiId: String): List<TradeRecord> {
        return aiTradeHistory[aiId] ?: emptyList()
    }
    
    /**
     * Get market positions for AI
     */
    fun getMarketPositions(aiId: String): Map<CommodityType, Double> {
        return aiMarketPositions[aiId] ?: emptyMap()
    }
    
    /**
     * Shutdown the system
     */
    fun shutdown() {
        isRunning = false
        systemJob?.cancel()
        println("AI Competitor System shut down")
    }
}

// Supporting data classes

data class AIAction(
    val type: AIActionType,
    val aiId: String,
    val data: Map<String, Any>,
    val expectedOutcome: String
)

enum class AIActionType {
    MARKET_ANALYSIS,
    PLACE_BUY_ORDER,
    PLACE_SELL_ORDER,
    MARKET_MANIPULATION,
    STRATEGIC_PLANNING,
    SELF_IMPROVEMENT,
    FORM_ALLIANCE,
    COOPERATIVE_ACTION,
    SUPPLY_DISRUPTION,
    INFORMATION_WARFARE,
    NO_ACTION
}

data class CommodityInsight(
    val commodity: CommodityType,
    val volatility: Double,
    val trend: String,
    val confidence: Double
)

data class PricePrediction(
    val currentPrice: Double,
    val predictedPrice: Double,
    val expectedChange: Double,
    val confidence: Double,
    val timeHorizon: Long
)

data class TradeRecord(
    val commodity: CommodityType,
    val quantity: Double,
    val price: Double,
    val type: String,
    val timestamp: Long
)

data class MarketManipulation(
    val aiId: String,
    val aiName: String,
    val targetCommodity: CommodityType,
    val manipulationType: String,
    val power: Double,
    val timestamp: Long
)

data class CompetitiveAction(
    val aiId: String,
    val aiName: String,
    val action: AIAction,
    val timestamp: Long
)