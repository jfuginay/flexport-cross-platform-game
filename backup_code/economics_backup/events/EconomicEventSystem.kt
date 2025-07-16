package com.flexport.economics.events

import com.flexport.economics.markets.*
import com.flexport.economics.MarketInterconnectionEngine
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlin.random.Random

/**
 * System for generating and managing economic events that affect markets
 */
class EconomicEventSystem(
    private val interconnectionEngine: MarketInterconnectionEngine
) {
    
    private val eventQueue = mutableListOf<ScheduledEconomicEvent>()
    private val eventHistory = mutableListOf<EconomicEvent>()
    private val eventGenerators = mutableListOf<EventGenerator>()
    
    // Event probability modifiers
    private val eventProbabilities = ConcurrentHashMap<EventCategory, Double>()
    private val globalEventModifiers = ConcurrentHashMap<String, Double>()
    
    // Scheduled executor for timed events
    private val scheduler: ScheduledExecutorService = Executors.newScheduledThreadPool(2)
    
    // Event severity tracking
    private var currentMarketStress = 0.0 // 0.0 to 1.0
    private var economicCyclePhase = EconomicCycle.EXPANSION
    
    init {
        initializeEventProbabilities()
        setupEventGenerators()
        startEventScheduler()
    }
    
    /**
     * Initialize base probabilities for different event categories
     */
    private fun initializeEventProbabilities() {
        eventProbabilities[EventCategory.MARKET_SHOCK] = 0.02 // 2% daily
        eventProbabilities[EventCategory.SUPPLY_DISRUPTION] = 0.05 // 5% daily
        eventProbabilities[EventCategory.DEMAND_SHIFT] = 0.08 // 8% daily
        eventProbabilities[EventCategory.REGULATORY_CHANGE] = 0.01 // 1% daily
        eventProbabilities[EventCategory.TECHNOLOGICAL_CHANGE] = 0.03 // 3% daily
        eventProbabilities[EventCategory.NATURAL_DISASTER] = 0.005 // 0.5% daily
        eventProbabilities[EventCategory.GEOPOLITICAL] = 0.02 // 2% daily
        eventProbabilities[EventCategory.SEASONAL] = 0.15 // 15% daily (seasonal events are common)
    }
    
    /**
     * Setup event generators for different types of events
     */
    private fun setupEventGenerators() {
        eventGenerators.add(MarketShockGenerator())
        eventGenerators.add(SupplyDisruptionGenerator())
        eventGenerators.add(DemandShiftGenerator())
        eventGenerators.add(RegulatoryChangeGenerator())
        eventGenerators.add(TechnologicalChangeGenerator())
        eventGenerators.add(NaturalDisasterGenerator())
        eventGenerators.add(GeopoliticalEventGenerator())
        eventGenerators.add(SeasonalEventGenerator())
        eventGenerators.add(CyclicalEventGenerator())
    }
    
    /**
     * Start the event scheduler
     */
    private fun startEventScheduler() {
        // Schedule random event generation every hour
        scheduler.scheduleAtFixedRate({
            generateRandomEvents()
        }, 1, 1, TimeUnit.HOURS)
        
        // Process scheduled events every minute
        scheduler.scheduleAtFixedRate({
            processScheduledEvents()
        }, 1, 1, TimeUnit.MINUTES)
        
        // Update economic indicators every 6 hours
        scheduler.scheduleAtFixedRate({
            updateEconomicIndicators()
        }, 6, 6, TimeUnit.HOURS)
    }
    
    /**
     * Generate random events based on probabilities
     */
    private fun generateRandomEvents() {
        eventGenerators.forEach { generator ->
            val baseProb = eventProbabilities[generator.category] ?: 0.0
            val adjustedProb = adjustProbabilityForConditions(baseProb, generator.category)
            
            if (Random.nextDouble() < adjustedProb) {
                val event = generator.generateEvent(currentMarketStress, economicCyclePhase)
                scheduleEvent(event, 0) // Execute immediately
            }
        }
    }
    
    /**
     * Adjust event probability based on current economic conditions
     */
    private fun adjustProbabilityForConditions(baseProb: Double, category: EventCategory): Double {
        var adjustedProb = baseProb
        
        // Market stress increases negative event probability
        when (category) {
            EventCategory.MARKET_SHOCK, EventCategory.SUPPLY_DISRUPTION -> {
                adjustedProb *= (1.0 + currentMarketStress)
            }
            EventCategory.TECHNOLOGICAL_CHANGE, EventCategory.DEMAND_SHIFT -> {
                adjustedProb *= (1.0 + (1.0 - currentMarketStress) * 0.5)
            }
            else -> {
                // Other events not directly affected by market stress
            }
        }
        
        // Economic cycle affects event types
        when (economicCyclePhase) {
            EconomicCycle.RECESSION -> {
                if (category == EventCategory.MARKET_SHOCK) adjustedProb *= 2.0
                if (category == EventCategory.REGULATORY_CHANGE) adjustedProb *= 1.5
            }
            EconomicCycle.EXPANSION -> {
                if (category == EventCategory.TECHNOLOGICAL_CHANGE) adjustedProb *= 1.5
                if (category == EventCategory.DEMAND_SHIFT) adjustedProb *= 1.3
            }
            else -> { /* Normal probabilities */ }
        }
        
        return adjustedProb.coerceIn(0.0, 1.0)
    }
    
    /**
     * Schedule an event for execution
     */
    fun scheduleEvent(event: EconomicEvent, delayMillis: Long) {
        val scheduledEvent = ScheduledEconomicEvent(
            event = event,
            executionTime = System.currentTimeMillis() + delayMillis
        )
        
        synchronized(eventQueue) {
            eventQueue.add(scheduledEvent)
            eventQueue.sortBy { it.executionTime }
        }
    }
    
    /**
     * Process events that are ready for execution
     */
    private fun processScheduledEvents() {
        val currentTime = System.currentTimeMillis()
        val readyEvents = synchronized(eventQueue) {
            eventQueue.filter { it.executionTime <= currentTime }
        }
        
        readyEvents.forEach { scheduledEvent ->
            executeEvent(scheduledEvent.event)
            synchronized(eventQueue) {
                eventQueue.remove(scheduledEvent)
            }
        }
    }
    
    /**
     * Execute an economic event
     */
    private fun executeEvent(event: EconomicEvent) {
        // Add to history
        eventHistory.add(event)
        
        // Apply to affected markets
        event.affectedMarkets.forEach { marketId ->
            // The interconnection engine would handle applying the event
            // to the appropriate market through the market registry
        }
        
        // Update market stress based on event impact
        updateMarketStress(event)
        
        // Trigger cascade effects if the event is severe enough
        if (event.severity >= EventSeverity.MAJOR) {
            triggerCascadeEffects(event)
        }
        
        // Log the event
        println("Economic Event: ${event.title} - Impact: ${event.severity}")
    }
    
    /**
     * Update market stress level based on events
     */
    private fun updateMarketStress(event: EconomicEvent) {
        val stressChange = when (event.severity) {
            EventSeverity.MINOR -> 0.01
            EventSeverity.MODERATE -> 0.05
            EventSeverity.MAJOR -> 0.15
            EventSeverity.CRITICAL -> 0.30
        }
        
        // Negative events increase stress, positive events decrease it
        val modifier = if (event.isPositive) -1.0 else 1.0
        currentMarketStress = (currentMarketStress + stressChange * modifier).coerceIn(0.0, 1.0)
        
        // Market stress naturally decays over time
        currentMarketStress *= 0.99
    }
    
    /**
     * Trigger cascade effects for major events
     */
    private fun triggerCascadeEffects(event: EconomicEvent) {
        when (event.category) {
            EventCategory.MARKET_SHOCK -> {
                // Financial shocks spread to other markets
                scheduleEvent(
                    createCascadeEvent(
                        "Credit Market Freeze",
                        EventCategory.MARKET_SHOCK,
                        listOf("capital", "assets"),
                        EventSeverity.MODERATE
                    ),
                    2 * 60 * 60 * 1000L // 2 hours later
                )
            }
            EventCategory.NATURAL_DISASTER -> {
                // Natural disasters affect supply chains
                scheduleEvent(
                    createCascadeEvent(
                        "Supply Chain Disruption",
                        EventCategory.SUPPLY_DISRUPTION,
                        listOf("goods", "labor"),
                        EventSeverity.MODERATE
                    ),
                    6 * 60 * 60 * 1000L // 6 hours later
                )
            }
            EventCategory.GEOPOLITICAL -> {
                // Geopolitical events affect trade
                scheduleEvent(
                    createCascadeEvent(
                        "Trade Route Restrictions",
                        EventCategory.REGULATORY_CHANGE,
                        listOf("goods", "assets"),
                        EventSeverity.MODERATE
                    ),
                    24 * 60 * 60 * 1000L // 1 day later
                )
            }
            else -> {
                // Other events may have specific cascade patterns
            }
        }
    }
    
    /**
     * Create a cascade event
     */
    private fun createCascadeEvent(
        title: String,
        category: EventCategory,
        affectedMarkets: List<String>,
        severity: EventSeverity
    ): EconomicEvent {
        return EconomicEvent(
            id = "CASCADE-${System.currentTimeMillis()}",
            title = title,
            description = "Cascade effect from previous economic event",
            category = category,
            severity = severity,
            affectedMarkets = affectedMarkets,
            duration = 7 * 24 * 60 * 60 * 1000L, // 1 week
            timestamp = System.currentTimeMillis(),
            isPositive = false,
            effects = mapOf(
                "priceVolatility" to 0.2,
                "liquidityReduction" to 0.1
            )
        )
    }
    
    /**
     * Update economic indicators and cycle phase
     */
    private fun updateEconomicIndicators() {
        // Update economic cycle based on market conditions
        updateEconomicCycle()
        
        // Adjust global event modifiers
        updateGlobalModifiers()
    }
    
    /**
     * Update the current economic cycle phase
     */
    private fun updateEconomicCycle() {
        // Simplified cycle detection based on market stress
        economicCyclePhase = when {
            currentMarketStress > 0.7 -> EconomicCycle.RECESSION
            currentMarketStress > 0.4 -> EconomicCycle.CONTRACTION
            currentMarketStress < 0.2 -> EconomicCycle.EXPANSION
            else -> EconomicCycle.RECOVERY
        }
    }
    
    /**
     * Update global event modifiers
     */
    private fun updateGlobalModifiers() {
        // Example: Increase technology event probability in expansion
        when (economicCyclePhase) {
            EconomicCycle.EXPANSION -> {
                globalEventModifiers["tech_innovation"] = 1.5
                globalEventModifiers["market_optimism"] = 1.3
            }
            EconomicCycle.RECESSION -> {
                globalEventModifiers["market_pessimism"] = 1.8
                globalEventModifiers["regulatory_response"] = 1.4
            }
            else -> {
                globalEventModifiers.clear()
            }
        }
    }
    
    /**
     * Get current economic conditions
     */
    fun getEconomicConditions(): EconomicConditions {
        return EconomicConditions(
            marketStress = currentMarketStress,
            economicCycle = economicCyclePhase,
            recentEvents = eventHistory.takeLast(10),
            scheduledEvents = eventQueue.size,
            eventProbabilities = eventProbabilities.toMap()
        )
    }
    
    /**
     * Force trigger a specific event (for testing or admin purposes)
     */
    fun triggerEvent(event: EconomicEvent) {
        scheduleEvent(event, 0)
    }
    
    /**
     * Get event statistics
     */
    fun getEventStatistics(): EventStatistics {
        val totalEvents = eventHistory.size
        val eventsByCategory = eventHistory.groupBy { it.category }.mapValues { it.value.size }
        val eventsBySeverity = eventHistory.groupBy { it.severity }.mapValues { it.value.size }
        val averageMarketStress = eventHistory.takeLast(100).map { currentMarketStress }.average()
        
        return EventStatistics(
            totalEvents = totalEvents,
            eventsByCategory = eventsByCategory,
            eventsBySeverity = eventsBySeverity,
            averageMarketStress = averageMarketStress,
            currentCyclePhase = economicCyclePhase
        )
    }
    
    /**
     * Shutdown the event system
     */
    fun shutdown() {
        scheduler.shutdown()
        try {
            if (!scheduler.awaitTermination(5, TimeUnit.SECONDS)) {
                scheduler.shutdownNow()
            }
        } catch (e: InterruptedException) {
            scheduler.shutdownNow()
        }
    }
}

/**
 * Scheduled economic event
 */
data class ScheduledEconomicEvent(
    val event: EconomicEvent,
    val executionTime: Long
)

/**
 * Economic event data class
 */
data class EconomicEvent(
    val id: String,
    val title: String,
    val description: String,
    val category: EventCategory,
    val severity: EventSeverity,
    val affectedMarkets: List<String>,
    val duration: Long, // milliseconds
    val timestamp: Long,
    val isPositive: Boolean,
    val effects: Map<String, Double> // Effect type to magnitude
)

/**
 * Event categories
 */
enum class EventCategory {
    MARKET_SHOCK,
    SUPPLY_DISRUPTION,
    DEMAND_SHIFT,
    REGULATORY_CHANGE,
    TECHNOLOGICAL_CHANGE,
    NATURAL_DISASTER,
    GEOPOLITICAL,
    SEASONAL,
    CYCLICAL
}

/**
 * Event severity levels
 */
enum class EventSeverity {
    MINOR,
    MODERATE,
    MAJOR,
    CRITICAL
}

/**
 * Economic cycle phases
 */
enum class EconomicCycle {
    EXPANSION,
    PEAK,
    CONTRACTION,
    RECESSION,
    TROUGH,
    RECOVERY
}

/**
 * Current economic conditions
 */
data class EconomicConditions(
    val marketStress: Double,
    val economicCycle: EconomicCycle,
    val recentEvents: List<EconomicEvent>,
    val scheduledEvents: Int,
    val eventProbabilities: Map<EventCategory, Double>
)

/**
 * Event statistics
 */
data class EventStatistics(
    val totalEvents: Int,
    val eventsByCategory: Map<EventCategory, Int>,
    val eventsBySeverity: Map<EventSeverity, Int>,
    val averageMarketStress: Double,
    val currentCyclePhase: EconomicCycle
)

/**
 * Base class for event generators
 */
abstract class EventGenerator {
    abstract val category: EventCategory
    abstract fun generateEvent(marketStress: Double, cyclePhase: EconomicCycle): EconomicEvent
}

/**
 * Market shock event generator
 */
class MarketShockGenerator : EventGenerator() {
    override val category = EventCategory.MARKET_SHOCK
    
    override fun generateEvent(marketStress: Double, cyclePhase: EconomicCycle): EconomicEvent {
        val shockTypes = listOf(
            "Flash Crash",
            "Liquidity Crisis",
            "Margin Call Cascade",
            "High-Frequency Trading Glitch",
            "Central Bank Intervention"
        )
        
        val title = shockTypes.random()
        val severity = when {
            marketStress > 0.6 -> EventSeverity.CRITICAL
            marketStress > 0.3 -> EventSeverity.MAJOR
            else -> EventSeverity.MODERATE
        }
        
        return EconomicEvent(
            id = "SHOCK-${System.currentTimeMillis()}",
            title = title,
            description = "Sudden market disruption causing price volatility",
            category = category,
            severity = severity,
            affectedMarkets = listOf("capital", "assets"),
            duration = 4 * 60 * 60 * 1000L, // 4 hours
            timestamp = System.currentTimeMillis(),
            isPositive = false,
            effects = mapOf(
                "priceVolatility" to 0.3,
                "liquidityReduction" to 0.2
            )
        )
    }
}

/**
 * Supply disruption event generator
 */
class SupplyDisruptionGenerator : EventGenerator() {
    override val category = EventCategory.SUPPLY_DISRUPTION
    
    override fun generateEvent(marketStress: Double, cyclePhase: EconomicCycle): EconomicEvent {
        val disruptionTypes = listOf(
            "Port Strike",
            "Shipping Lane Closure",
            "Factory Shutdown",
            "Raw Material Shortage",
            "Transportation Bottleneck"
        )
        
        return EconomicEvent(
            id = "SUPPLY-${System.currentTimeMillis()}",
            title = disruptionTypes.random(),
            description = "Supply chain disruption affecting goods availability",
            category = category,
            severity = EventSeverity.MODERATE,
            affectedMarkets = listOf("goods", "assets"),
            duration = 3 * 24 * 60 * 60 * 1000L, // 3 days
            timestamp = System.currentTimeMillis(),
            isPositive = false,
            effects = mapOf(
                "supplyReduction" to 0.2,
                "priceIncrease" to 0.15
            )
        )
    }
}

/**
 * Demand shift event generator
 */
class DemandShiftGenerator : EventGenerator() {
    override val category = EventCategory.DEMAND_SHIFT
    
    override fun generateEvent(marketStress: Double, cyclePhase: EconomicCycle): EconomicEvent {
        val shiftTypes = listOf(
            "Consumer Preference Change",
            "New Market Trend",
            "Demographic Shift",
            "Income Level Change",
            "Lifestyle Change"
        )
        
        val isPositive = Random.nextBoolean()
        
        return EconomicEvent(
            id = "DEMAND-${System.currentTimeMillis()}",
            title = shiftTypes.random(),
            description = "Change in consumer demand patterns",
            category = category,
            severity = EventSeverity.MINOR,
            affectedMarkets = listOf("goods", "labor"),
            duration = 30 * 24 * 60 * 60 * 1000L, // 30 days
            timestamp = System.currentTimeMillis(),
            isPositive = isPositive,
            effects = mapOf(
                "demandChange" to if (isPositive) 0.1 else -0.1
            )
        )
    }
}

/**
 * Additional event generators would be implemented similarly
 */
class RegulatoryChangeGenerator : EventGenerator() {
    override val category = EventCategory.REGULATORY_CHANGE
    override fun generateEvent(marketStress: Double, cyclePhase: EconomicCycle): EconomicEvent {
        return EconomicEvent(
            id = "REG-${System.currentTimeMillis()}",
            title = "New Regulation",
            description = "Government regulatory change",
            category = category,
            severity = EventSeverity.MODERATE,
            affectedMarkets = listOf("all"),
            duration = 90 * 24 * 60 * 60 * 1000L,
            timestamp = System.currentTimeMillis(),
            isPositive = Random.nextBoolean(),
            effects = mapOf("compliance_cost" to 0.05)
        )
    }
}

class TechnologicalChangeGenerator : EventGenerator() {
    override val category = EventCategory.TECHNOLOGICAL_CHANGE
    override fun generateEvent(marketStress: Double, cyclePhase: EconomicCycle): EconomicEvent {
        return EconomicEvent(
            id = "TECH-${System.currentTimeMillis()}",
            title = "Technology Breakthrough",
            description = "New technology affecting efficiency",
            category = category,
            severity = EventSeverity.MINOR,
            affectedMarkets = listOf("goods", "assets"),
            duration = 180 * 24 * 60 * 60 * 1000L,
            timestamp = System.currentTimeMillis(),
            isPositive = true,
            effects = mapOf("efficiency_gain" to 0.1)
        )
    }
}

class NaturalDisasterGenerator : EventGenerator() {
    override val category = EventCategory.NATURAL_DISASTER
    override fun generateEvent(marketStress: Double, cyclePhase: EconomicCycle): EconomicEvent {
        return EconomicEvent(
            id = "DISASTER-${System.currentTimeMillis()}",
            title = "Natural Disaster",
            description = "Natural disaster affecting infrastructure",
            category = category,
            severity = EventSeverity.MAJOR,
            affectedMarkets = listOf("goods", "assets", "labor"),
            duration = 14 * 24 * 60 * 60 * 1000L,
            timestamp = System.currentTimeMillis(),
            isPositive = false,
            effects = mapOf("infrastructure_damage" to 0.3)
        )
    }
}

class GeopoliticalEventGenerator : EventGenerator() {
    override val category = EventCategory.GEOPOLITICAL
    override fun generateEvent(marketStress: Double, cyclePhase: EconomicCycle): EconomicEvent {
        return EconomicEvent(
            id = "GEO-${System.currentTimeMillis()}",
            title = "Geopolitical Event",
            description = "International relations affecting trade",
            category = category,
            severity = EventSeverity.MODERATE,
            affectedMarkets = listOf("all"),
            duration = 60 * 24 * 60 * 60 * 1000L,
            timestamp = System.currentTimeMillis(),
            isPositive = false,
            effects = mapOf("trade_friction" to 0.15)
        )
    }
}

class SeasonalEventGenerator : EventGenerator() {
    override val category = EventCategory.SEASONAL
    override fun generateEvent(marketStress: Double, cyclePhase: EconomicCycle): EconomicEvent {
        return EconomicEvent(
            id = "SEASONAL-${System.currentTimeMillis()}",
            title = "Seasonal Demand Change",
            description = "Predictable seasonal market change",
            category = category,
            severity = EventSeverity.MINOR,
            affectedMarkets = listOf("goods"),
            duration = 90 * 24 * 60 * 60 * 1000L,
            timestamp = System.currentTimeMillis(),
            isPositive = Random.nextBoolean(),
            effects = mapOf("seasonal_adjustment" to 0.05)
        )
    }
}

class CyclicalEventGenerator : EventGenerator() {
    override val category = EventCategory.CYCLICAL
    override fun generateEvent(marketStress: Double, cyclePhase: EconomicCycle): EconomicEvent {
        return EconomicEvent(
            id = "CYCLE-${System.currentTimeMillis()}",
            title = "Economic Cycle Shift",
            description = "Business cycle phase change",
            category = category,
            severity = EventSeverity.MAJOR,
            affectedMarkets = listOf("all"),
            duration = 365 * 24 * 60 * 60 * 1000L,
            timestamp = System.currentTimeMillis(),
            isPositive = cyclePhase == EconomicCycle.EXPANSION,
            effects = mapOf("cycle_adjustment" to 0.2)
        )
    }
}