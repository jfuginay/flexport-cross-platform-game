package com.flexport.map.events

import com.flexport.map.models.*
import com.flexport.map.data.WorldPorts
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import java.time.LocalDateTime
import java.time.temporal.ChronoUnit
import java.util.*
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.*
import kotlin.random.Random

/**
 * System for simulating real-world events that affect trade routes
 * Includes weather, political events, economic crises, and other disruptions
 */
class RealWorldEventSystem {
    
    private val _activeEvents = ConcurrentHashMap<String, WorldEvent>()
    private val _eventHistory = mutableListOf<WorldEvent>()
    private val _eventNotifications = MutableSharedFlow<EventNotification>()
    private val _weatherSystem = WeatherEventSystem()
    private val _politicalSystem = PoliticalEventSystem()
    private val _economicSystem = EconomicEventSystem()
    private val _naturalDisasterSystem = NaturalDisasterSystem()
    private val _pandemicSystem = PandemicEventSystem()
    private val _cyberSecuritySystem = CyberSecurityEventSystem()
    
    private var systemJob: Job? = null
    private var isRunning = false
    
    /**
     * Observable flow of event notifications
     */
    val eventNotifications: SharedFlow<EventNotification> = _eventNotifications.asSharedFlow()
    
    /**
     * Get all active events
     */
    val activeEvents: List<WorldEvent>
        get() = _activeEvents.values.toList()
    
    /**
     * Start the event system
     */
    suspend fun startEventSystem() {
        if (isRunning) return
        
        isRunning = true
        systemJob = CoroutineScope(Dispatchers.Default).launch {
            // Initialize subsystems
            _weatherSystem.initialize()
            _politicalSystem.initialize()
            _economicSystem.initialize()
            _naturalDisasterSystem.initialize()
            _pandemicSystem.initialize()
            _cyberSecuritySystem.initialize()
            
            // Main event loop
            launch { eventGenerationLoop() }
            launch { eventUpdateLoop() }
            launch { eventCleanupLoop() }
            
            // Subsystem monitoring
            launch { monitorWeatherEvents() }
            launch { monitorPoliticalEvents() }
            launch { monitorEconomicEvents() }
            launch { monitorNaturalDisasters() }
            launch { monitorPandemicEvents() }
            launch { monitorCyberSecurityEvents() }
        }
        
        _eventNotifications.emit(EventNotification.SystemStarted)
    }
    
    /**
     * Stop the event system
     */
    suspend fun stopEventSystem() {
        isRunning = false
        systemJob?.cancel()
        _eventNotifications.emit(EventNotification.SystemStopped)
    }
    
    /**
     * Get events affecting a specific route
     */
    fun getEventsAffectingRoute(route: TradeRoute): List<RouteEventImpact> {
        val impacts = mutableListOf<RouteEventImpact>()
        
        _activeEvents.values.forEach { event ->
            val impact = calculateEventImpactOnRoute(event, route)
            if (impact.impactLevel != ImpactLevel.NONE) {
                impacts.add(impact)
            }
        }
        
        return impacts.sortedByDescending { it.impactLevel.ordinal }
    }
    
    /**
     * Get events affecting a specific port
     */
    fun getEventsAffectingPort(port: Port): List<PortEventImpact> {
        val impacts = mutableListOf<PortEventImpact>()
        
        _activeEvents.values.forEach { event ->
            val impact = calculateEventImpactOnPort(event, port)
            if (impact.impactLevel != ImpactLevel.NONE) {
                impacts.add(impact)
            }
        }
        
        return impacts.sortedByDescending { it.impactLevel.ordinal }
    }
    
    /**
     * Get events in a geographical area
     */
    fun getEventsInArea(bounds: GeographicalBounds): List<WorldEvent> {
        return _activeEvents.values.filter { event ->
            when (event.scope) {
                is EventScope.Global -> true
                is EventScope.Regional -> bounds.contains(event.scope.centerPoint)
                is EventScope.Port -> bounds.contains(event.scope.port.position)
                is EventScope.Route -> event.scope.route.allPorts.any { port ->
                    bounds.contains(port.position)
                }
                is EventScope.Country -> {
                    WorldPorts.ALL_PORTS.filter { it.country == event.scope.country }
                        .any { bounds.contains(it.position) }
                }
            }
        }
    }
    
    /**
     * Get current global risk assessment
     */
    fun getGlobalRiskAssessment(): GlobalRiskAssessment {
        val risks = mutableMapOf<RiskCategory, Double>()
        
        _activeEvents.values.forEach { event ->
            val category = when (event.type) {
                EventType.WEATHER -> RiskCategory.WEATHER
                EventType.POLITICAL -> RiskCategory.POLITICAL
                EventType.ECONOMIC -> RiskCategory.ECONOMIC
                EventType.NATURAL_DISASTER -> RiskCategory.NATURAL_DISASTER
                EventType.PANDEMIC -> RiskCategory.HEALTH
                EventType.CYBER_SECURITY -> RiskCategory.CYBER_SECURITY
                EventType.PIRACY -> RiskCategory.SECURITY
                EventType.LABOR_STRIKE -> RiskCategory.LABOR
                EventType.INFRASTRUCTURE -> RiskCategory.INFRASTRUCTURE
            }
            
            val currentRisk = risks.getOrDefault(category, 0.0)
            val eventRisk = calculateEventRiskScore(event)
            risks[category] = maxOf(currentRisk, eventRisk)
        }
        
        val overallRisk = risks.values.average().takeIf { !it.isNaN() } ?: 0.0
        
        return GlobalRiskAssessment(
            overallRisk = overallRisk,
            riskByCategory = risks,
            activeEventCount = _activeEvents.size,
            highImpactEvents = _activeEvents.values.count { it.severity == EventSeverity.CRITICAL || it.severity == EventSeverity.HIGH },
            riskTrend = calculateRiskTrend(),
            lastUpdated = LocalDateTime.now()
        )
    }
    
    /**
     * Generate event forecast
     */
    suspend fun generateEventForecast(days: Int = 7): EventForecast = withContext(Dispatchers.Default) {
        val predictions = mutableListOf<EventPrediction>()
        
        // Weather predictions
        predictions.addAll(_weatherSystem.generateWeatherForecast(days))
        
        // Political event predictions
        predictions.addAll(_politicalSystem.generatePoliticalForecast(days))
        
        // Economic event predictions
        predictions.addAll(_economicSystem.generateEconomicForecast(days))
        
        // Natural disaster predictions
        predictions.addAll(_naturalDisasterSystem.generateDisasterForecast(days))
        
        EventForecast(
            forecastPeriod = days,
            predictions = predictions.sortedByDescending { it.probability },
            confidenceLevel = calculateForecastConfidence(predictions),
            generatedAt = LocalDateTime.now()
        )
    }
    
    /**
     * Force trigger a specific event (for testing or scenarios)
     */
    suspend fun triggerEvent(eventTemplate: EventTemplate): WorldEvent {
        val event = createEventFromTemplate(eventTemplate)
        activateEvent(event)
        return event
    }
    
    /**
     * Resolve an event manually
     */
    suspend fun resolveEvent(eventId: String, resolutionType: EventResolution) {
        val event = _activeEvents[eventId]
        if (event != null) {
            val resolvedEvent = event.copy(
                status = EventStatus.RESOLVED,
                endTime = LocalDateTime.now(),
                resolution = resolutionType
            )
            
            _activeEvents.remove(eventId)
            _eventHistory.add(resolvedEvent)
            
            _eventNotifications.emit(EventNotification.EventResolved(resolvedEvent))
        }
    }
    
    // Private implementation methods
    
    private suspend fun eventGenerationLoop() {
        while (isRunning) {
            try {
                // Generate random events based on probabilities
                generateRandomEvents()
                
                // Check for triggered events based on conditions
                checkTriggeredEvents()
                
                delay(300000) // Check every 5 minutes
            } catch (e: Exception) {
                // Log error and continue
                delay(60000)
            }
        }
    }
    
    private suspend fun eventUpdateLoop() {
        while (isRunning) {
            try {
                val currentTime = LocalDateTime.now()
                
                _activeEvents.values.forEach { event ->
                    updateEvent(event, currentTime)
                }
                
                delay(60000) // Update every minute
            } catch (e: Exception) {
                delay(30000)
            }
        }
    }
    
    private suspend fun eventCleanupLoop() {
        while (isRunning) {
            try {
                cleanupExpiredEvents()
                delay(600000) // Cleanup every 10 minutes
            } catch (e: Exception) {
                delay(300000)
            }
        }
    }
    
    private suspend fun generateRandomEvents() {
        val eventTypes = EventType.values()
        
        eventTypes.forEach { eventType ->
            val probability = getEventProbability(eventType)
            
            if (Random.nextDouble() < probability) {
                val event = generateRandomEvent(eventType)
                if (event != null && canEventOccur(event)) {
                    activateEvent(event)
                }
            }
        }
    }
    
    private fun getEventProbability(eventType: EventType): Double {
        // Base probabilities per check (every 5 minutes)
        return when (eventType) {
            EventType.WEATHER -> 0.001 // 0.1% chance
            EventType.POLITICAL -> 0.0005 // 0.05% chance
            EventType.ECONOMIC -> 0.0003 // 0.03% chance
            EventType.NATURAL_DISASTER -> 0.0001 // 0.01% chance
            EventType.PANDEMIC -> 0.00001 // 0.001% chance
            EventType.CYBER_SECURITY -> 0.0002 // 0.02% chance
            EventType.PIRACY -> 0.0001 // 0.01% chance
            EventType.LABOR_STRIKE -> 0.0002 // 0.02% chance
            EventType.INFRASTRUCTURE -> 0.0001 // 0.01% chance
        }
    }
    
    private fun generateRandomEvent(eventType: EventType): WorldEvent? {
        return when (eventType) {
            EventType.WEATHER -> generateWeatherEvent()
            EventType.POLITICAL -> generatePoliticalEvent()
            EventType.ECONOMIC -> generateEconomicEvent()
            EventType.NATURAL_DISASTER -> generateNaturalDisaster()
            EventType.PANDEMIC -> generatePandemicEvent()
            EventType.CYBER_SECURITY -> generateCyberSecurityEvent()
            EventType.PIRACY -> generatePiracyEvent()
            EventType.LABOR_STRIKE -> generateLaborStrikeEvent()
            EventType.INFRASTRUCTURE -> generateInfrastructureEvent()
        }
    }
    
    private fun generateWeatherEvent(): WorldEvent? {
        val weatherTypes = listOf("Hurricane", "Typhoon", "Storm", "Fog", "Ice")
        val weatherType = weatherTypes.random()
        
        val affectedPorts = WorldPorts.ALL_PORTS.filter { port ->
            when (weatherType) {
                "Hurricane" -> port.region == "North America" && port.position.latitude < 35.0
                "Typhoon" -> port.region == "Asia Pacific" && port.position.latitude > 5.0
                "Storm" -> true // Can affect any port
                "Fog" -> port.weatherConditions.extremeWeatherRisk.fogRisk != RiskLevel.NONE
                "Ice" -> port.position.latitude > 50.0 || port.position.latitude < -50.0
                else -> true
            }
        }
        
        if (affectedPorts.isEmpty()) return null
        
        val targetPort = affectedPorts.random()
        val severity = when (weatherType) {
            "Hurricane", "Typhoon" -> listOf(EventSeverity.HIGH, EventSeverity.CRITICAL).random()
            else -> listOf(EventSeverity.LOW, EventSeverity.MEDIUM).random()
        }
        
        return WorldEvent(
            id = UUID.randomUUID().toString(),
            type = EventType.WEATHER,
            name = "$weatherType near ${targetPort.name}",
            description = "Severe $weatherType affecting shipping operations in the ${targetPort.region} region",
            severity = severity,
            scope = EventScope.Regional(
                centerPoint = targetPort.position,
                radiusNauticalMiles = when (severity) {
                    EventSeverity.CRITICAL -> 500.0
                    EventSeverity.HIGH -> 300.0
                    EventSeverity.MEDIUM -> 150.0
                    EventSeverity.LOW -> 75.0
                }
            ),
            startTime = LocalDateTime.now(),
            estimatedEndTime = LocalDateTime.now().plusHours(
                when (severity) {
                    EventSeverity.CRITICAL -> Random.nextLong(24, 72)
                    EventSeverity.HIGH -> Random.nextLong(12, 48)
                    EventSeverity.MEDIUM -> Random.nextLong(6, 24)
                    EventSeverity.LOW -> Random.nextLong(2, 12)
                }
            ),
            status = EventStatus.ACTIVE,
            impacts = generateWeatherImpacts(weatherType, severity),
            tags = setOf("weather", weatherType.lowercase())
        )
    }
    
    private fun generatePoliticalEvent(): WorldEvent? {
        val eventTypes = listOf("Trade Dispute", "Sanctions", "Border Closure", "Policy Change", "Diplomatic Crisis")
        val eventType = eventTypes.random()
        
        val countries = WorldPorts.ALL_PORTS.map { it.country }.distinct()
        val affectedCountries = when (eventType) {
            "Trade Dispute", "Sanctions", "Diplomatic Crisis" -> {
                val country1 = countries.random()
                val country2 = countries.filter { it != country1 }.random()
                listOf(country1, country2)
            }
            else -> listOf(countries.random())
        }
        
        val severity = listOf(EventSeverity.LOW, EventSeverity.MEDIUM, EventSeverity.HIGH).random()
        
        return WorldEvent(
            id = UUID.randomUUID().toString(),
            type = EventType.POLITICAL,
            name = "$eventType - ${affectedCountries.joinToString(" vs ")}", 
            description = "Political event affecting trade relations between ${affectedCountries.joinToString(" and ")}",
            severity = severity,
            scope = if (affectedCountries.size == 1) {
                EventScope.Country(affectedCountries.first())
            } else {
                EventScope.Global // Multi-country events are considered global
            },
            startTime = LocalDateTime.now(),
            estimatedEndTime = LocalDateTime.now().plusDays(
                when (severity) {
                    EventSeverity.HIGH -> Random.nextLong(30, 180)
                    EventSeverity.MEDIUM -> Random.nextLong(7, 60)
                    EventSeverity.LOW -> Random.nextLong(1, 14)
                    else -> 7
                }
            ),
            status = EventStatus.ACTIVE,
            impacts = generatePoliticalImpacts(eventType, severity),
            tags = setOf("political", eventType.lowercase().replace(" ", "_")) + affectedCountries.map { it.lowercase() }
        )
    }
    
    private fun generateEconomicEvent(): WorldEvent? {
        val eventTypes = listOf("Market Crash", "Currency Crisis", "Inflation Spike", "Recession", "Trade War")
        val eventType = eventTypes.random()
        
        val severity = when (eventType) {
            "Market Crash", "Recession" -> listOf(EventSeverity.HIGH, EventSeverity.CRITICAL).random()
            "Currency Crisis" -> listOf(EventSeverity.MEDIUM, EventSeverity.HIGH).random()
            else -> listOf(EventSeverity.LOW, EventSeverity.MEDIUM, EventSeverity.HIGH).random()
        }
        
        val scope = if (eventType == "Trade War") {
            val countries = WorldPorts.ALL_PORTS.map { it.country }.distinct()
            EventScope.Country(countries.random())
        } else {
            EventScope.Global
        }
        
        return WorldEvent(
            id = UUID.randomUUID().toString(),
            type = EventType.ECONOMIC,
            name = eventType,
            description = "Economic event affecting global trade: $eventType",
            severity = severity,
            scope = scope,
            startTime = LocalDateTime.now(),
            estimatedEndTime = LocalDateTime.now().plusDays(
                when (severity) {
                    EventSeverity.CRITICAL -> Random.nextLong(90, 365)
                    EventSeverity.HIGH -> Random.nextLong(30, 180)
                    EventSeverity.MEDIUM -> Random.nextLong(7, 60)
                    EventSeverity.LOW -> Random.nextLong(1, 14)
                }
            ),
            status = EventStatus.ACTIVE,
            impacts = generateEconomicImpacts(eventType, severity),
            tags = setOf("economic", eventType.lowercase().replace(" ", "_"))
        )
    }
    
    private fun generateNaturalDisaster(): WorldEvent? {
        val disasterTypes = listOf("Earthquake", "Tsunami", "Volcanic Eruption", "Wildfire", "Flood")
        val disasterType = disasterTypes.random()
        
        // Find suitable ports for the disaster type
        val suitablePorts = WorldPorts.ALL_PORTS.filter { port ->
            when (disasterType) {
                "Earthquake", "Tsunami" -> port.region == "Asia Pacific" // Higher seismic activity
                "Volcanic Eruption" -> port.region == "Asia Pacific" || port.country == "Italy"
                "Wildfire" -> port.region == "North America" || port.country == "Australia"
                "Flood" -> true // Can happen anywhere
                else -> true
            }
        }
        
        if (suitablePorts.isEmpty()) return null
        
        val affectedPort = suitablePorts.random()
        val severity = listOf(EventSeverity.MEDIUM, EventSeverity.HIGH, EventSeverity.CRITICAL).random()
        
        return WorldEvent(
            id = UUID.randomUUID().toString(),
            type = EventType.NATURAL_DISASTER,
            name = "$disasterType near ${affectedPort.name}",
            description = "$disasterType affecting port operations and surrounding infrastructure",
            severity = severity,
            scope = EventScope.Regional(
                centerPoint = affectedPort.position,
                radiusNauticalMiles = when (severity) {
                    EventSeverity.CRITICAL -> 200.0
                    EventSeverity.HIGH -> 100.0
                    EventSeverity.MEDIUM -> 50.0
                    else -> 25.0
                }
            ),
            startTime = LocalDateTime.now(),
            estimatedEndTime = LocalDateTime.now().plusDays(
                when (severity) {
                    EventSeverity.CRITICAL -> Random.nextLong(14, 90)
                    EventSeverity.HIGH -> Random.nextLong(7, 30)
                    EventSeverity.MEDIUM -> Random.nextLong(1, 14)
                    else -> Random.nextLong(1, 7)
                }
            ),
            status = EventStatus.ACTIVE,
            impacts = generateDisasterImpacts(disasterType, severity),
            tags = setOf("natural_disaster", disasterType.lowercase().replace(" ", "_"))
        )
    }
    
    private fun generatePandemicEvent(): WorldEvent? {
        // Pandemics are rare but global
        val severity = listOf(EventSeverity.HIGH, EventSeverity.CRITICAL).random()
        
        return WorldEvent(
            id = UUID.randomUUID().toString(),
            type = EventType.PANDEMIC,
            name = "Global Health Emergency",
            description = "Pandemic affecting global trade and transportation",
            severity = severity,
            scope = EventScope.Global,
            startTime = LocalDateTime.now(),
            estimatedEndTime = LocalDateTime.now().plusDays(
                when (severity) {
                    EventSeverity.CRITICAL -> Random.nextLong(365, 1095) // 1-3 years
                    EventSeverity.HIGH -> Random.nextLong(180, 730) // 6 months - 2 years
                    else -> Random.nextLong(90, 365)
                }
            ),
            status = EventStatus.ACTIVE,
            impacts = generatePandemicImpacts(severity),
            tags = setOf("pandemic", "health", "global")
        )
    }
    
    private fun generateCyberSecurityEvent(): WorldEvent? {
        val eventTypes = listOf("Port System Hack", "Shipping Network Attack", "GPS Spoofing", "Data Breach")
        val eventType = eventTypes.random()
        
        val severity = listOf(EventSeverity.MEDIUM, EventSeverity.HIGH).random()
        
        val scope = if (eventType == "Port System Hack") {
            EventScope.Port(WorldPorts.ALL_PORTS.random())
        } else {
            EventScope.Global
        }
        
        return WorldEvent(
            id = UUID.randomUUID().toString(),
            type = EventType.CYBER_SECURITY,
            name = eventType,
            description = "Cyber security incident affecting shipping operations",
            severity = severity,
            scope = scope,
            startTime = LocalDateTime.now(),
            estimatedEndTime = LocalDateTime.now().plusHours(
                when (severity) {
                    EventSeverity.HIGH -> Random.nextLong(24, 168) // 1-7 days
                    EventSeverity.MEDIUM -> Random.nextLong(4, 48) // 4-48 hours
                    else -> Random.nextLong(1, 12)
                }
            ),
            status = EventStatus.ACTIVE,
            impacts = generateCyberSecurityImpacts(eventType, severity),
            tags = setOf("cyber_security", eventType.lowercase().replace(" ", "_"))
        )
    }
    
    private fun generatePiracyEvent(): WorldEvent? {
        // Piracy more common in certain regions
        val piracyPorts = WorldPorts.ALL_PORTS.filter { port ->
            port.region == "Middle East" || 
            (port.region == "Asia Pacific" && port.position.latitude < 20.0) ||
            (port.region == "Africa" && port.position.longitude > 30.0)
        }
        
        if (piracyPorts.isEmpty()) return null
        
        val affectedPort = piracyPorts.random()
        val severity = listOf(EventSeverity.LOW, EventSeverity.MEDIUM, EventSeverity.HIGH).random()
        
        return WorldEvent(
            id = UUID.randomUUID().toString(),
            type = EventType.PIRACY,
            name = "Piracy Activity near ${affectedPort.name}",
            description = "Increased piracy activity affecting shipping safety",
            severity = severity,
            scope = EventScope.Regional(
                centerPoint = affectedPort.position,
                radiusNauticalMiles = when (severity) {
                    EventSeverity.HIGH -> 300.0
                    EventSeverity.MEDIUM -> 150.0
                    else -> 75.0
                }
            ),
            startTime = LocalDateTime.now(),
            estimatedEndTime = LocalDateTime.now().plusDays(Random.nextLong(7, 60)),
            status = EventStatus.ACTIVE,
            impacts = generatePiracyImpacts(severity),
            tags = setOf("piracy", "security")
        )
    }
    
    private fun generateLaborStrikeEvent(): WorldEvent? {
        val strikeTypes = listOf("Port Workers Strike", "Truckers Strike", "Maritime Union Strike", "Customs Strike")
        val strikeType = strikeTypes.random()
        
        val affectedPort = WorldPorts.ALL_PORTS.random()
        val severity = listOf(EventSeverity.LOW, EventSeverity.MEDIUM, EventSeverity.HIGH).random()
        
        val scope = when (strikeType) {
            "Port Workers Strike" -> EventScope.Port(affectedPort)
            "Customs Strike" -> EventScope.Country(affectedPort.country)
            else -> EventScope.Regional(affectedPort.position, 200.0)
        }
        
        return WorldEvent(
            id = UUID.randomUUID().toString(),
            type = EventType.LABOR_STRIKE,
            name = strikeType,
            description = "Labor strike affecting port and shipping operations",
            severity = severity,
            scope = scope,
            startTime = LocalDateTime.now(),
            estimatedEndTime = LocalDateTime.now().plusDays(
                when (severity) {
                    EventSeverity.HIGH -> Random.nextLong(14, 60)
                    EventSeverity.MEDIUM -> Random.nextLong(3, 21)
                    else -> Random.nextLong(1, 7)
                }
            ),
            status = EventStatus.ACTIVE,
            impacts = generateLaborStrikeImpacts(strikeType, severity),
            tags = setOf("labor", "strike", strikeType.lowercase().replace(" ", "_"))
        )
    }
    
    private fun generateInfrastructureEvent(): WorldEvent? {
        val eventTypes = listOf("Port Equipment Failure", "Channel Blockage", "Bridge Collapse", "Power Outage")
        val eventType = eventTypes.random()
        
        val affectedPort = WorldPorts.ALL_PORTS.random()
        val severity = listOf(EventSeverity.MEDIUM, EventSeverity.HIGH).random()
        
        return WorldEvent(
            id = UUID.randomUUID().toString(),
            type = EventType.INFRASTRUCTURE,
            name = "$eventType at ${affectedPort.name}",
            description = "Infrastructure failure affecting port operations",
            severity = severity,
            scope = EventScope.Port(affectedPort),
            startTime = LocalDateTime.now(),
            estimatedEndTime = LocalDateTime.now().plusDays(
                when (severity) {
                    EventSeverity.HIGH -> Random.nextLong(7, 30)
                    EventSeverity.MEDIUM -> Random.nextLong(1, 14)
                    else -> Random.nextLong(1, 7)
                }
            ),
            status = EventStatus.ACTIVE,
            impacts = generateInfrastructureImpacts(eventType, severity),
            tags = setOf("infrastructure", eventType.lowercase().replace(" ", "_"))
        )
    }
    
    // Impact generation methods
    
    private fun generateWeatherImpacts(weatherType: String, severity: EventSeverity): List<EventImpact> {
        val impacts = mutableListOf<EventImpact>()
        
        when (weatherType) {
            "Hurricane", "Typhoon" -> {
                impacts.add(EventImpact.PortClosure(100.0)) // Complete closure
                impacts.add(EventImpact.SpeedReduction(50.0))
                impacts.add(EventImpact.CostIncrease(75.0))
                if (severity == EventSeverity.CRITICAL) {
                    impacts.add(EventImpact.RouteDisruption(100.0))
                }
            }
            "Storm" -> {
                impacts.add(EventImpact.SpeedReduction(30.0))
                impacts.add(EventImpact.CostIncrease(20.0))
                impacts.add(EventImpact.DelayIncrease(60.0))
            }
            "Fog" -> {
                impacts.add(EventImpact.SpeedReduction(50.0))
                impacts.add(EventImpact.DelayIncrease(120.0))
            }
            "Ice" -> {
                impacts.add(EventImpact.RouteDisruption(80.0))
                impacts.add(EventImpact.SpeedReduction(70.0))
                impacts.add(EventImpact.CostIncrease(40.0))
            }
        }
        
        return impacts
    }
    
    private fun generatePoliticalImpacts(eventType: String, severity: EventSeverity): List<EventImpact> {
        val impacts = mutableListOf<EventImpact>()
        
        val intensityMultiplier = when (severity) {
            EventSeverity.HIGH -> 2.0
            EventSeverity.MEDIUM -> 1.0
            EventSeverity.LOW -> 0.5
            else -> 1.5
        }
        
        when (eventType) {
            "Trade Dispute", "Trade War" -> {
                impacts.add(EventImpact.CostIncrease(30.0 * intensityMultiplier))
                impacts.add(EventImpact.DelayIncrease(50.0 * intensityMultiplier))
            }
            "Sanctions" -> {
                impacts.add(EventImpact.RouteDisruption(70.0 * intensityMultiplier))
                impacts.add(EventImpact.CostIncrease(100.0 * intensityMultiplier))
            }
            "Border Closure" -> {
                impacts.add(EventImpact.RouteDisruption(100.0))
                impacts.add(EventImpact.PortClosure(100.0))
            }
        }
        
        return impacts
    }
    
    private fun generateEconomicImpacts(eventType: String, severity: EventSeverity): List<EventImpact> {
        val impacts = mutableListOf<EventImpact>()
        
        val intensityMultiplier = when (severity) {
            EventSeverity.CRITICAL -> 3.0
            EventSeverity.HIGH -> 2.0
            EventSeverity.MEDIUM -> 1.0
            EventSeverity.LOW -> 0.5
        }
        
        when (eventType) {
            "Market Crash", "Recession" -> {
                impacts.add(EventImpact.DemandReduction(40.0 * intensityMultiplier))
                impacts.add(EventImpact.CostIncrease(20.0 * intensityMultiplier))
            }
            "Currency Crisis" -> {
                impacts.add(EventImpact.CostIncrease(50.0 * intensityMultiplier))
                impacts.add(EventImpact.PriceVolatility(80.0 * intensityMultiplier))
            }
            "Inflation Spike" -> {
                impacts.add(EventImpact.CostIncrease(60.0 * intensityMultiplier))
            }
        }
        
        return impacts
    }
    
    private fun generateDisasterImpacts(disasterType: String, severity: EventSeverity): List<EventImpact> {
        val impacts = mutableListOf<EventImpact>()
        
        when (disasterType) {
            "Earthquake", "Tsunami" -> {
                impacts.add(EventImpact.PortClosure(100.0))
                impacts.add(EventImpact.RouteDisruption(90.0))
                impacts.add(EventImpact.InfrastructureDamage(80.0))
            }
            "Volcanic Eruption" -> {
                impacts.add(EventImpact.RouteDisruption(100.0))
                impacts.add(EventImpact.SpeedReduction(80.0))
            }
            "Wildfire", "Flood" -> {
                impacts.add(EventImpact.PortClosure(60.0))
                impacts.add(EventImpact.DelayIncrease(200.0))
            }
        }
        
        return impacts
    }
    
    private fun generatePandemicImpacts(severity: EventSeverity): List<EventImpact> {
        val impacts = mutableListOf<EventImpact>()
        
        val intensityMultiplier = when (severity) {
            EventSeverity.CRITICAL -> 2.0
            EventSeverity.HIGH -> 1.5
            else -> 1.0
        }
        
        impacts.add(EventImpact.CapacityReduction(40.0 * intensityMultiplier))
        impacts.add(EventImpact.DelayIncrease(100.0 * intensityMultiplier))
        impacts.add(EventImpact.CostIncrease(30.0 * intensityMultiplier))
        impacts.add(EventImpact.DemandReduction(20.0 * intensityMultiplier))
        
        return impacts
    }
    
    private fun generateCyberSecurityImpacts(eventType: String, severity: EventSeverity): List<EventImpact> {
        val impacts = mutableListOf<EventImpact>()
        
        when (eventType) {
            "Port System Hack" -> {
                impacts.add(EventImpact.PortClosure(80.0))
                impacts.add(EventImpact.DelayIncrease(300.0))
            }
            "Shipping Network Attack" -> {
                impacts.add(EventImpact.CommunicationDisruption(90.0))
                impacts.add(EventImpact.DelayIncrease(150.0))
            }
            "GPS Spoofing" -> {
                impacts.add(EventImpact.NavigationDisruption(70.0))
                impacts.add(EventImpact.SpeedReduction(40.0))
            }
        }
        
        return impacts
    }
    
    private fun generatePiracyImpacts(severity: EventSeverity): List<EventImpact> {
        val impacts = mutableListOf<EventImpact>()
        
        val intensityMultiplier = when (severity) {
            EventSeverity.HIGH -> 2.0
            EventSeverity.MEDIUM -> 1.0
            else -> 0.5
        }
        
        impacts.add(EventImpact.RouteDisruption(30.0 * intensityMultiplier))
        impacts.add(EventImpact.CostIncrease(50.0 * intensityMultiplier)) // Security costs
        impacts.add(EventImpact.SpeedReduction(20.0 * intensityMultiplier))
        
        return impacts
    }
    
    private fun generateLaborStrikeImpacts(strikeType: String, severity: EventSeverity): List<EventImpact> {
        val impacts = mutableListOf<EventImpact>()
        
        val intensityMultiplier = when (severity) {
            EventSeverity.HIGH -> 2.0
            EventSeverity.MEDIUM -> 1.0
            else -> 0.5
        }
        
        when (strikeType) {
            "Port Workers Strike" -> {
                impacts.add(EventImpact.PortClosure(90.0 * intensityMultiplier))
                impacts.add(EventImpact.DelayIncrease(400.0 * intensityMultiplier))
            }
            "Truckers Strike" -> {
                impacts.add(EventImpact.CapacityReduction(60.0 * intensityMultiplier))
                impacts.add(EventImpact.DelayIncrease(200.0 * intensityMultiplier))
            }
            "Customs Strike" -> {
                impacts.add(EventImpact.DelayIncrease(500.0 * intensityMultiplier))
                impacts.add(EventImpact.CostIncrease(40.0 * intensityMultiplier))
            }
        }
        
        return impacts
    }
    
    private fun generateInfrastructureImpacts(eventType: String, severity: EventSeverity): List<EventImpact> {
        val impacts = mutableListOf<EventImpact>()
        
        when (eventType) {
            "Port Equipment Failure" -> {
                impacts.add(EventImpact.CapacityReduction(50.0))
                impacts.add(EventImpact.DelayIncrease(100.0))
            }
            "Channel Blockage" -> {
                impacts.add(EventImpact.RouteDisruption(100.0))
                impacts.add(EventImpact.PortClosure(80.0))
            }
            "Bridge Collapse" -> {
                impacts.add(EventImpact.RouteDisruption(90.0))
                impacts.add(EventImpact.DelayIncrease(300.0))
            }
            "Power Outage" -> {
                impacts.add(EventImpact.PortClosure(60.0))
                impacts.add(EventImpact.CapacityReduction(70.0))
            }
        }
        
        return impacts
    }
    
    // Additional helper methods...
    
    private fun calculateEventImpactOnRoute(event: WorldEvent, route: TradeRoute): RouteEventImpact {
        val affectedPorts = route.allPorts.filter { port ->
            isPortAffectedByEvent(port, event)
        }
        
        if (affectedPorts.isEmpty()) {
            return RouteEventImpact(
                event = event,
                route = route,
                affectedPorts = emptyList(),
                impactLevel = ImpactLevel.NONE,
                estimatedDelay = 0.0,
                additionalCost = 0.0,
                alternativeRoutesAvailable = true
            )
        }
        
        val totalImpact = event.impacts.sumOf { impact ->
            when (impact) {
                is EventImpact.DelayIncrease -> impact.percentageIncrease
                is EventImpact.CostIncrease -> impact.percentageIncrease
                is EventImpact.RouteDisruption -> impact.disruptionPercentage
                else -> 0.0
            }
        }
        
        val impactLevel = when {
            totalImpact > 200.0 -> ImpactLevel.CRITICAL
            totalImpact > 100.0 -> ImpactLevel.HIGH
            totalImpact > 50.0 -> ImpactLevel.MEDIUM
            totalImpact > 10.0 -> ImpactLevel.LOW
            else -> ImpactLevel.NONE
        }
        
        return RouteEventImpact(
            event = event,
            route = route,
            affectedPorts = affectedPorts,
            impactLevel = impactLevel,
            estimatedDelay = calculateDelayImpact(event, route),
            additionalCost = calculateCostImpact(event, route),
            alternativeRoutesAvailable = hasAlternativeRoutes(route, event)
        )
    }
    
    private fun calculateEventImpactOnPort(event: WorldEvent, port: Port): PortEventImpact {
        val isAffected = isPortAffectedByEvent(port, event)
        
        if (!isAffected) {
            return PortEventImpact(
                event = event,
                port = port,
                impactLevel = ImpactLevel.NONE,
                operationalCapacity = 100.0,
                estimatedDelays = 0.0,
                serviceLimitations = emptyList()
            )
        }
        
        var operationalCapacity = 100.0
        var estimatedDelays = 0.0
        val serviceLimitations = mutableListOf<String>()
        
        event.impacts.forEach { impact ->
            when (impact) {
                is EventImpact.PortClosure -> {
                    operationalCapacity = minOf(operationalCapacity, 100.0 - impact.closurePercentage)
                    serviceLimitations.add("Port operations restricted")
                }
                is EventImpact.CapacityReduction -> {
                    operationalCapacity = minOf(operationalCapacity, 100.0 - impact.reductionPercentage)
                }
                is EventImpact.DelayIncrease -> {
                    estimatedDelays += impact.percentageIncrease
                }
                else -> {}
            }
        }
        
        val impactLevel = when {
            operationalCapacity < 20.0 -> ImpactLevel.CRITICAL
            operationalCapacity < 50.0 -> ImpactLevel.HIGH
            operationalCapacity < 80.0 -> ImpactLevel.MEDIUM
            estimatedDelays > 50.0 -> ImpactLevel.MEDIUM
            estimatedDelays > 10.0 -> ImpactLevel.LOW
            else -> ImpactLevel.NONE
        }
        
        return PortEventImpact(
            event = event,
            port = port,
            impactLevel = impactLevel,
            operationalCapacity = operationalCapacity,
            estimatedDelays = estimatedDelays,
            serviceLimitations = serviceLimitations
        )
    }
    
    private fun isPortAffectedByEvent(port: Port, event: WorldEvent): Boolean {
        return when (event.scope) {
            is EventScope.Global -> true
            is EventScope.Regional -> {
                port.position.distanceTo(event.scope.centerPoint) <= event.scope.radiusNauticalMiles
            }
            is EventScope.Port -> event.scope.port.id == port.id
            is EventScope.Country -> event.scope.country == port.country
            is EventScope.Route -> event.scope.route.allPorts.any { it.id == port.id }
        }
    }
    
    private fun calculateDelayImpact(event: WorldEvent, route: TradeRoute): Double {
        return event.impacts.filterIsInstance<EventImpact.DelayIncrease>()
            .sumOf { it.percentageIncrease }
    }
    
    private fun calculateCostImpact(event: WorldEvent, route: TradeRoute): Double {
        val baseCost = 50000.0 // Estimated base route cost
        return event.impacts.filterIsInstance<EventImpact.CostIncrease>()
            .sumOf { baseCost * (it.percentageIncrease / 100.0) }
    }
    
    private fun hasAlternativeRoutes(route: TradeRoute, event: WorldEvent): Boolean {
        // Simplified check - in reality would check for actual alternative routes
        return when (event.scope) {
            is EventScope.Global -> false
            is EventScope.Regional -> route.allPorts.size > 2 // Has waypoints
            else -> true
        }
    }
    
    // Monitoring methods for subsystems
    
    private suspend fun monitorWeatherEvents() {
        _weatherSystem.weatherEvents.collect { weatherEvent ->
            _eventNotifications.emit(EventNotification.WeatherEventDetected(weatherEvent))
        }
    }
    
    private suspend fun monitorPoliticalEvents() {
        _politicalSystem.politicalEvents.collect { politicalEvent ->
            _eventNotifications.emit(EventNotification.PoliticalEventDetected(politicalEvent))
        }
    }
    
    private suspend fun monitorEconomicEvents() {
        _economicSystem.economicEvents.collect { economicEvent ->
            _eventNotifications.emit(EventNotification.EconomicEventDetected(economicEvent))
        }
    }
    
    private suspend fun monitorNaturalDisasters() {
        _naturalDisasterSystem.disasterEvents.collect { disasterEvent ->
            _eventNotifications.emit(EventNotification.NaturalDisasterDetected(disasterEvent))
        }
    }
    
    private suspend fun monitorPandemicEvents() {
        _pandemicSystem.pandemicEvents.collect { pandemicEvent ->
            _eventNotifications.emit(EventNotification.PandemicEventDetected(pandemicEvent))
        }
    }
    
    private suspend fun monitorCyberSecurityEvents() {
        _cyberSecuritySystem.cyberEvents.collect { cyberEvent ->
            _eventNotifications.emit(EventNotification.CyberSecurityEventDetected(cyberEvent))
        }
    }
    
    private fun canEventOccur(event: WorldEvent): Boolean {
        // Check if similar event is already active
        val similarEvents = _activeEvents.values.filter { 
            it.type == event.type && it.severity >= event.severity 
        }
        
        return when (event.type) {
            EventType.PANDEMIC -> similarEvents.isEmpty() // Only one pandemic at a time
            EventType.ECONOMIC -> similarEvents.size < 2 // Max 2 economic events
            else -> similarEvents.size < 5 // Max 5 of other types
        }
    }
    
    private suspend fun activateEvent(event: WorldEvent) {
        _activeEvents[event.id] = event
        _eventNotifications.emit(EventNotification.EventActivated(event))
    }
    
    private suspend fun updateEvent(event: WorldEvent, currentTime: LocalDateTime) {
        // Update event based on time progression
        if (event.estimatedEndTime?.isBefore(currentTime) == true) {
            // Event should end
            resolveEvent(event.id, EventResolution.NATURAL_RESOLUTION)
        } else {
            // Update event intensity based on time
            val updatedEvent = updateEventIntensity(event, currentTime)
            if (updatedEvent != event) {
                _activeEvents[event.id] = updatedEvent
                _eventNotifications.emit(EventNotification.EventUpdated(updatedEvent))
            }
        }
    }
    
    private fun updateEventIntensity(event: WorldEvent, currentTime: LocalDateTime): WorldEvent {
        // Events can intensify or diminish over time
        val duration = ChronoUnit.HOURS.between(event.startTime, currentTime)
        
        return when (event.type) {
            EventType.WEATHER -> {
                // Weather events typically peak and then diminish
                if (duration > 12) {
                    event.copy(severity = when (event.severity) {
                        EventSeverity.CRITICAL -> EventSeverity.HIGH
                        EventSeverity.HIGH -> EventSeverity.MEDIUM
                        EventSeverity.MEDIUM -> EventSeverity.LOW
                        else -> event.severity
                    })
                } else event
            }
            EventType.PANDEMIC -> {
                // Pandemics can intensify over time
                if (duration > 168 && Random.nextDouble() < 0.1) { // 1 week, 10% chance
                    event.copy(severity = when (event.severity) {
                        EventSeverity.LOW -> EventSeverity.MEDIUM
                        EventSeverity.MEDIUM -> EventSeverity.HIGH
                        EventSeverity.HIGH -> EventSeverity.CRITICAL
                        else -> event.severity
                    })
                } else event
            }
            else -> event
        }
    }
    
    private suspend fun cleanupExpiredEvents() {
        val currentTime = LocalDateTime.now()
        val expiredEvents = _activeEvents.values.filter { event ->
            event.estimatedEndTime?.isBefore(currentTime) == true ||
            ChronoUnit.DAYS.between(event.startTime, currentTime) > 365 // Max 1 year
        }
        
        expiredEvents.forEach { event ->
            resolveEvent(event.id, EventResolution.AUTOMATIC_EXPIRY)
        }
    }
    
    private suspend fun checkTriggeredEvents() {
        // Check for events triggered by specific conditions
        // This would check economic indicators, other events, etc.
    }
    
    private fun calculateEventRiskScore(event: WorldEvent): Double {
        val severityScore = when (event.severity) {
            EventSeverity.CRITICAL -> 100.0
            EventSeverity.HIGH -> 75.0
            EventSeverity.MEDIUM -> 50.0
            EventSeverity.LOW -> 25.0
        }
        
        val scopeMultiplier = when (event.scope) {
            is EventScope.Global -> 2.0
            is EventScope.Regional -> 1.5
            is EventScope.Country -> 1.2
            is EventScope.Route -> 1.0
            is EventScope.Port -> 0.8
        }
        
        return severityScore * scopeMultiplier
    }
    
    private fun calculateRiskTrend(): TrendDirection {
        if (_eventHistory.size < 10) return TrendDirection.STABLE
        
        val recent = _eventHistory.takeLast(5)
        val previous = _eventHistory.dropLast(5).takeLast(5)
        
        val recentRisk = recent.sumOf { calculateEventRiskScore(it) }
        val previousRisk = previous.sumOf { calculateEventRiskScore(it) }
        
        return when {
            recentRisk > previousRisk * 1.2 -> TrendDirection.INCREASING
            recentRisk < previousRisk * 0.8 -> TrendDirection.DECREASING
            else -> TrendDirection.STABLE
        }
    }
    
    private fun calculateForecastConfidence(predictions: List<EventPrediction>): Double {
        return predictions.map { it.probability }.average().takeIf { !it.isNaN() } ?: 0.0
    }
    
    private fun createEventFromTemplate(template: EventTemplate): WorldEvent {
        return WorldEvent(
            id = UUID.randomUUID().toString(),
            type = template.type,
            name = template.name,
            description = template.description,
            severity = template.severity,
            scope = template.scope,
            startTime = LocalDateTime.now(),
            estimatedEndTime = template.duration?.let { LocalDateTime.now().plus(it) },
            status = EventStatus.ACTIVE,
            impacts = template.impacts,
            tags = template.tags
        )
    }
}

// Supporting classes and data structures

/**
 * Subsystem for weather events
 */
class WeatherEventSystem {
    val weatherEvents = MutableSharedFlow<String>()
    
    fun initialize() {}
    
    suspend fun generateWeatherForecast(days: Int): List<EventPrediction> {
        // Generate weather predictions
        return emptyList()
    }
}

/**
 * Subsystem for political events
 */
class PoliticalEventSystem {
    val politicalEvents = MutableSharedFlow<String>()
    
    fun initialize() {}
    
    suspend fun generatePoliticalForecast(days: Int): List<EventPrediction> {
        return emptyList()
    }
}

/**
 * Subsystem for economic events
 */
class EconomicEventSystem {
    val economicEvents = MutableSharedFlow<String>()
    
    fun initialize() {}
    
    suspend fun generateEconomicForecast(days: Int): List<EventPrediction> {
        return emptyList()
    }
}

/**
 * Subsystem for natural disasters
 */
class NaturalDisasterSystem {
    val disasterEvents = MutableSharedFlow<String>()
    
    fun initialize() {}
    
    suspend fun generateDisasterForecast(days: Int): List<EventPrediction> {
        return emptyList()
    }
}

/**
 * Subsystem for pandemic events
 */
class PandemicEventSystem {
    val pandemicEvents = MutableSharedFlow<String>()
    
    fun initialize() {}
}

/**
 * Subsystem for cyber security events
 */
class CyberSecurityEventSystem {
    val cyberEvents = MutableSharedFlow<String>()
    
    fun initialize() {}
}

// Data classes for events

/**
 * World event affecting trade routes
 */
data class WorldEvent(
    val id: String,
    val type: EventType,
    val name: String,
    val description: String,
    val severity: EventSeverity,
    val scope: EventScope,
    val startTime: LocalDateTime,
    val estimatedEndTime: LocalDateTime? = null,
    val endTime: LocalDateTime? = null,
    val status: EventStatus,
    val impacts: List<EventImpact>,
    val tags: Set<String> = emptySet(),
    val resolution: EventResolution? = null
)

/**
 * Event scope definitions
 */
sealed class EventScope {
    object Global : EventScope()
    data class Regional(val centerPoint: GeographicalPosition, val radiusNauticalMiles: Double) : EventScope()
    data class Country(val country: String) : EventScope()
    data class Port(val port: com.flexport.map.models.Port) : EventScope()
    data class Route(val route: TradeRoute) : EventScope()
}

/**
 * Event impacts on operations
 */
sealed class EventImpact {
    data class PortClosure(val closurePercentage: Double) : EventImpact()
    data class RouteDisruption(val disruptionPercentage: Double) : EventImpact()
    data class SpeedReduction(val reductionPercentage: Double) : EventImpact()
    data class CostIncrease(val percentageIncrease: Double) : EventImpact()
    data class DelayIncrease(val percentageIncrease: Double) : EventImpact()
    data class CapacityReduction(val reductionPercentage: Double) : EventImpact()
    data class DemandReduction(val reductionPercentage: Double) : EventImpact()
    data class PriceVolatility(val volatilityIncrease: Double) : EventImpact()
    data class InfrastructureDamage(val damagePercentage: Double) : EventImpact()
    data class CommunicationDisruption(val disruptionPercentage: Double) : EventImpact()
    data class NavigationDisruption(val disruptionPercentage: Double) : EventImpact()
}

/**
 * Route impact assessment
 */
data class RouteEventImpact(
    val event: WorldEvent,
    val route: TradeRoute,
    val affectedPorts: List<Port>,
    val impactLevel: ImpactLevel,
    val estimatedDelay: Double, // minutes
    val additionalCost: Double,
    val alternativeRoutesAvailable: Boolean
)

/**
 * Port impact assessment
 */
data class PortEventImpact(
    val event: WorldEvent,
    val port: Port,
    val impactLevel: ImpactLevel,
    val operationalCapacity: Double, // percentage
    val estimatedDelays: Double, // percentage increase
    val serviceLimitations: List<String>
)

/**
 * Global risk assessment
 */
data class GlobalRiskAssessment(
    val overallRisk: Double,
    val riskByCategory: Map<RiskCategory, Double>,
    val activeEventCount: Int,
    val highImpactEvents: Int,
    val riskTrend: TrendDirection,
    val lastUpdated: LocalDateTime
)

/**
 * Event forecast
 */
data class EventForecast(
    val forecastPeriod: Int,
    val predictions: List<EventPrediction>,
    val confidenceLevel: Double,
    val generatedAt: LocalDateTime
)

/**
 * Event prediction
 */
data class EventPrediction(
    val eventType: EventType,
    val name: String,
    val probability: Double,
    val expectedTimeframe: String,
    val expectedImpact: ImpactLevel,
    val affectedRegions: List<String>
)

/**
 * Event template for manual triggering
 */
data class EventTemplate(
    val type: EventType,
    val name: String,
    val description: String,
    val severity: EventSeverity,
    val scope: EventScope,
    val duration: java.time.Duration? = null,
    val impacts: List<EventImpact>,
    val tags: Set<String> = emptySet()
)

// Enums

enum class EventType {
    WEATHER,
    POLITICAL,
    ECONOMIC,
    NATURAL_DISASTER,
    PANDEMIC,
    CYBER_SECURITY,
    PIRACY,
    LABOR_STRIKE,
    INFRASTRUCTURE
}

enum class EventSeverity {
    LOW,
    MEDIUM,
    HIGH,
    CRITICAL
}

enum class EventStatus {
    ACTIVE,
    ESCALATING,
    DE_ESCALATING,
    RESOLVED,
    CANCELLED
}

enum class EventResolution {
    NATURAL_RESOLUTION,
    GOVERNMENT_INTERVENTION,
    INTERNATIONAL_AID,
    PRIVATE_SECTOR_RESPONSE,
    AUTOMATIC_EXPIRY,
    MANUAL_RESOLUTION
}

enum class ImpactLevel {
    NONE,
    LOW,
    MEDIUM,
    HIGH,
    CRITICAL
}

enum class RiskCategory {
    WEATHER,
    POLITICAL,
    ECONOMIC,
    NATURAL_DISASTER,
    HEALTH,
    CYBER_SECURITY,
    SECURITY,
    LABOR,
    INFRASTRUCTURE
}

enum class TrendDirection {
    INCREASING,
    STABLE,
    DECREASING
}

// Event notifications
sealed class EventNotification {
    object SystemStarted : EventNotification()
    object SystemStopped : EventNotification()
    data class EventActivated(val event: WorldEvent) : EventNotification()
    data class EventUpdated(val event: WorldEvent) : EventNotification()
    data class EventResolved(val event: WorldEvent) : EventNotification()
    data class WeatherEventDetected(val event: String) : EventNotification()
    data class PoliticalEventDetected(val event: String) : EventNotification()
    data class EconomicEventDetected(val event: String) : EventNotification()
    data class NaturalDisasterDetected(val event: String) : EventNotification()
    data class PandemicEventDetected(val event: String) : EventNotification()
    data class CyberSecurityEventDetected(val event: String) : EventNotification()
}