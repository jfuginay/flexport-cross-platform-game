package com.flexport.map.simulation

import com.flexport.map.models.*
import com.flexport.map.data.WorldPorts
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import java.time.LocalDateTime
import java.util.*
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.*
import kotlin.random.Random

/**
 * Simulates shipping lane traffic, congestion, and delays
 */
class ShippingLaneSimulator {
    
    private val _laneStates = ConcurrentHashMap<String, ShippingLaneState>()
    private val _vesselPositions = ConcurrentHashMap<String, SimulatedVessel>()
    private val _trafficEvents = MutableSharedFlow<TrafficEvent>()
    private val _weatherSystem = WeatherSimulationSystem()
    private val _politicalSystem = PoliticalEventSystem()
    
    private var isRunning = false
    private var simulationJob: Job? = null
    
    /**
     * Observable flow of traffic events
     */
    val trafficEvents: SharedFlow<TrafficEvent> = _trafficEvents.asSharedFlow()
    
    /**
     * Get current vessel positions
     */
    val vesselPositions: List<SimulatedVessel>
        get() = _vesselPositions.values.toList()
    
    /**
     * Initialize shipping lanes
     */
    suspend fun initializeShippingLanes(routes: List<TradeRoute>) = withContext(Dispatchers.Default) {
        
        // Create major shipping lanes from route data
        val laneSegments = extractShippingLanes(routes)
        
        laneSegments.forEach { segment ->
            val laneState = ShippingLaneState(
                id = segment.id,
                startPosition = segment.startPosition,
                endPosition = segment.endPosition,
                distance = segment.distance,
                capacity = calculateLaneCapacity(segment),
                currentTraffic = 0,
                averageSpeed = 12.0, // knots
                congestionLevel = CongestionLevel.CLEAR,
                weatherConditions = mutableMapOf(),
                restrictions = mutableSetOf(),
                lastUpdated = LocalDateTime.now()
            )
            
            _laneStates[segment.id] = laneState
        }
        
        // Initialize weather and political systems
        _weatherSystem.initialize(_laneStates.keys.toList())
        _politicalSystem.initialize(WorldPorts.ALL_PORTS.map { it.country }.distinct())
    }
    
    /**
     * Start the shipping lane simulation
     */
    suspend fun startSimulation() {
        if (isRunning) return
        
        isRunning = true
        simulationJob = CoroutineScope(Dispatchers.Default).launch {
            while (isRunning) {
                updateSimulation()
                delay(5000) // Update every 5 seconds
            }
        }
        
        _trafficEvents.emit(TrafficEvent.SimulationStarted)
    }
    
    /**
     * Stop the simulation
     */
    suspend fun stopSimulation() {
        isRunning = false
        simulationJob?.cancel()
        _trafficEvents.emit(TrafficEvent.SimulationStopped)
    }
    
    /**
     * Add a vessel to the simulation
     */
    suspend fun addVessel(route: TradeRoute, vessel: Vessel) = withContext(Dispatchers.Default) {
        val simulatedVessel = SimulatedVessel(
            id = "${vessel.id}_${System.currentTimeMillis()}",
            vessel = vessel,
            route = route,
            currentPosition = route.origin.position,
            targetPosition = getNextWaypoint(route, 0),
            waypointIndex = 0,
            speed = vessel.cruisingSpeed,
            heading = calculateInitialHeading(route),
            status = VesselSimulationStatus.SAILING,
            estimatedArrival = calculateEstimatedArrival(route, vessel),
            delays = mutableListOf(),
            fuelConsumed = 0.0,
            distanceTraveled = 0.0,
            lastUpdated = LocalDateTime.now()
        )
        
        _vesselPositions[simulatedVessel.id] = simulatedVessel
        _trafficEvents.emit(TrafficEvent.VesselAdded(simulatedVessel))
    }
    
    /**
     * Remove a vessel from simulation
     */
    suspend fun removeVessel(vesselId: String) {
        val vessel = _vesselPositions.remove(vesselId)
        vessel?.let {
            _trafficEvents.emit(TrafficEvent.VesselRemoved(it))
        }
    }
    
    /**
     * Get shipping lane state
     */
    fun getShippingLaneState(laneId: String): ShippingLaneState? {
        return _laneStates[laneId]
    }
    
    /**
     * Get all shipping lane states
     */
    fun getAllShippingLanes(): List<ShippingLaneState> {
        return _laneStates.values.toList()
    }
    
    /**
     * Get congested shipping lanes
     */
    fun getCongestedLanes(): List<ShippingLaneState> {
        return _laneStates.values.filter { 
            it.congestionLevel == CongestionLevel.HEAVY || it.congestionLevel == CongestionLevel.SEVERE 
        }
    }
    
    /**
     * Get vessels in a specific area
     */
    fun getVesselsInArea(bounds: GeographicalBounds): List<SimulatedVessel> {
        return _vesselPositions.values.filter { vessel ->
            bounds.contains(vessel.currentPosition)
        }
    }
    
    /**
     * Get traffic density for a shipping lane
     */
    fun getTrafficDensity(laneId: String): Double {
        val lane = _laneStates[laneId] ?: return 0.0
        return lane.currentTraffic.toDouble() / lane.capacity * 100.0
    }
    
    /**
     * Predict delays for a route
     */
    suspend fun predictDelays(route: TradeRoute): RouteDelayPrediction = withContext(Dispatchers.Default) {
        val delays = mutableListOf<DelayPrediction>()
        
        // Analyze each segment of the route
        val routeSegments = createRouteSegments(route)
        
        routeSegments.forEach { segment ->
            val laneId = findNearestLane(segment.startPosition, segment.endPosition)
            val lane = _laneStates[laneId]
            
            if (lane != null) {
                // Weather delays
                val weatherDelay = _weatherSystem.predictWeatherDelay(lane.id, segment.estimatedTransitTime)
                if (weatherDelay > 0) {
                    delays.add(DelayPrediction(
                        type = DelayType.WEATHER,
                        estimatedMinutes = weatherDelay,
                        probability = 0.7,
                        segment = segment
                    ))
                }
                
                // Congestion delays
                val congestionDelay = calculateCongestionDelay(lane, segment.estimatedTransitTime)
                if (congestionDelay > 0) {
                    delays.add(DelayPrediction(
                        type = DelayType.CONGESTION,
                        estimatedMinutes = congestionDelay,
                        probability = 0.8,
                        segment = segment
                    ))
                }
                
                // Political/regulatory delays
                val politicalDelay = _politicalSystem.predictPoliticalDelay(
                    segment.startPosition, 
                    segment.endPosition
                )
                if (politicalDelay > 0) {
                    delays.add(DelayPrediction(
                        type = DelayType.POLITICAL,
                        estimatedMinutes = politicalDelay,
                        probability = 0.3,
                        segment = segment
                    ))
                }
            }
        }
        
        RouteDelayPrediction(
            route = route,
            delayPredictions = delays,
            totalEstimatedDelay = delays.sumOf { it.estimatedMinutes },
            confidence = calculatePredictionConfidence(delays)
        )
    }
    
    /**
     * Get real-time traffic updates
     */
    fun getTrafficUpdates(): TrafficUpdate {
        val congestedLanes = getCongestedLanes()
        val totalVessels = _vesselPositions.size
        val averageCongestion = _laneStates.values.map { getTrafficDensity(it.id) }.average()
        val activeWeatherEvents = _weatherSystem.getActiveWeatherEvents()
        val activePoliticalEvents = _politicalSystem.getActivePoliticalEvents()
        
        return TrafficUpdate(
            timestamp = LocalDateTime.now(),
            totalVessels = totalVessels,
            congestedLanes = congestedLanes.map { it.id },
            averageCongestionLevel = averageCongestion.takeIf { !it.isNaN() } ?: 0.0,
            activeWeatherEvents = activeWeatherEvents,
            activePoliticalEvents = activePoliticalEvents,
            delayAlerts = generateDelayAlerts()
        )
    }
    
    // Private simulation methods
    
    private suspend fun updateSimulation() = withContext(Dispatchers.Default) {
        val currentTime = LocalDateTime.now()
        
        // Update vessel positions
        updateVesselPositions(currentTime)
        
        // Update traffic in shipping lanes
        updateShippingLaneTraffic()
        
        // Update weather conditions
        _weatherSystem.update(currentTime)
        
        // Update political events
        _politicalSystem.update(currentTime)
        
        // Check for new events and alerts
        checkForEvents(currentTime)
    }
    
    private suspend fun updateVesselPositions(currentTime: LocalDateTime) {
        _vesselPositions.values.forEach { vessel ->
            if (vessel.status == VesselSimulationStatus.SAILING) {
                updateSingleVessel(vessel, currentTime)
            }
        }
    }
    
    private suspend fun updateSingleVessel(vessel: SimulatedVessel, currentTime: LocalDateTime) {
        val timeDelta = java.time.Duration.between(vessel.lastUpdated, currentTime).seconds / 3600.0 // hours
        
        // Calculate movement based on current conditions
        val currentLane = findCurrentLane(vessel.currentPosition, vessel.targetPosition)
        val effectiveSpeed = calculateEffectiveSpeed(vessel, currentLane)
        
        // Calculate new position
        val distanceToTravel = effectiveSpeed * timeDelta // nautical miles
        val totalDistance = vessel.currentPosition.distanceTo(vessel.targetPosition)
        
        if (distanceToTravel >= totalDistance) {
            // Reached waypoint
            handleWaypointReached(vessel)
        } else {
            // Move towards target
            val progress = distanceToTravel / totalDistance
            val newPosition = interpolatePosition(vessel.currentPosition, vessel.targetPosition, progress)
            
            val updatedVessel = vessel.copy(
                currentPosition = newPosition,
                distanceTraveled = vessel.distanceTraveled + distanceToTravel,
                fuelConsumed = vessel.fuelConsumed + (distanceToTravel * vessel.vessel.fuelConsumption),
                lastUpdated = currentTime
            )
            
            _vesselPositions[vessel.id] = updatedVessel
            
            // Check for delays
            checkForVesselDelays(updatedVessel, currentLane)
        }
    }
    
    private suspend fun handleWaypointReached(vessel: SimulatedVessel) {
        val nextWaypointIndex = vessel.waypointIndex + 1
        val route = vessel.route
        
        if (nextWaypointIndex >= route.allPorts.size) {
            // Route completed
            val completedVessel = vessel.copy(
                status = VesselSimulationStatus.COMPLETED,
                lastUpdated = LocalDateTime.now()
            )
            _vesselPositions[vessel.id] = completedVessel
            _trafficEvents.emit(TrafficEvent.VesselCompleted(completedVessel))
        } else {
            // Move to next waypoint
            val nextTarget = getNextWaypoint(route, nextWaypointIndex)
            val updatedVessel = vessel.copy(
                currentPosition = vessel.targetPosition,
                targetPosition = nextTarget,
                waypointIndex = nextWaypointIndex,
                lastUpdated = LocalDateTime.now()
            )
            _vesselPositions[vessel.id] = updatedVessel
            _trafficEvents.emit(TrafficEvent.VesselWaypointReached(updatedVessel))
        }
    }
    
    private fun updateShippingLaneTraffic() {
        _laneStates.forEach { (laneId, lane) ->
            val vesselsInLane = countVesselsInLane(laneId)
            val congestionLevel = calculateCongestionLevel(vesselsInLane, lane.capacity)
            
            val updatedLane = lane.copy(
                currentTraffic = vesselsInLane,
                congestionLevel = congestionLevel,
                averageSpeed = calculateAverageSpeed(congestionLevel, lane.averageSpeed),
                lastUpdated = LocalDateTime.now()
            )
            
            _laneStates[laneId] = updatedLane
        }
    }
    
    private suspend fun checkForEvents(currentTime: LocalDateTime) {
        // Check for congestion events
        _laneStates.values.forEach { lane ->
            if (lane.congestionLevel == CongestionLevel.SEVERE) {
                _trafficEvents.emit(TrafficEvent.CongestionAlert(lane.id, lane.congestionLevel))
            }
        }
        
        // Check for weather events
        _weatherSystem.getActiveWeatherEvents().forEach { event ->
            _trafficEvents.emit(TrafficEvent.WeatherAlert(event))
        }
    }
    
    private suspend fun checkForVesselDelays(vessel: SimulatedVessel, lane: ShippingLaneState?) {
        val delays = mutableListOf<SimulationDelay>()
        
        // Weather delays
        lane?.let { laneState ->
            val weatherCondition = _weatherSystem.getWeatherCondition(laneState.id)
            if (weatherCondition == WeatherCondition.SEVERE || weatherCondition == WeatherCondition.POOR) {
                delays.add(SimulationDelay(
                    type = DelayType.WEATHER,
                    severity = when (weatherCondition) {
                        WeatherCondition.SEVERE -> DelaySeverity.HIGH
                        WeatherCondition.POOR -> DelaySeverity.MEDIUM
                        else -> DelaySeverity.LOW
                    },
                    estimatedDurationMinutes = Random.nextInt(30, 180),
                    cause = "Adverse weather conditions"
                ))
            }
        }
        
        // Congestion delays
        lane?.let { laneState ->
            if (laneState.congestionLevel == CongestionLevel.HEAVY || laneState.congestionLevel == CongestionLevel.SEVERE) {
                delays.add(SimulationDelay(
                    type = DelayType.CONGESTION,
                    severity = when (laneState.congestionLevel) {
                        CongestionLevel.SEVERE -> DelaySeverity.HIGH
                        CongestionLevel.HEAVY -> DelaySeverity.MEDIUM
                        else -> DelaySeverity.LOW
                    },
                    estimatedDurationMinutes = Random.nextInt(15, 90),
                    cause = "Traffic congestion"
                ))
            }
        }
        
        if (delays.isNotEmpty() && vessel.delays.none { it.isActive() }) {
            val updatedVessel = vessel.copy(delays = vessel.delays + delays)
            _vesselPositions[vessel.id] = updatedVessel
            _trafficEvents.emit(TrafficEvent.VesselDelayed(updatedVessel, delays))
        }
    }
    
    // Helper methods
    
    private fun extractShippingLanes(routes: List<TradeRoute>): List<ShippingLaneSegment> {
        val segments = mutableListOf<ShippingLaneSegment>()
        val segmentCounter = mutableMapOf<String, Int>()
        
        routes.forEach { route ->
            val routePorts = route.allPorts
            
            for (i in 0 until routePorts.size - 1) {
                val start = routePorts[i].position
                val end = routePorts[i + 1].position
                val segmentKey = "${start.latitude},${start.longitude}-${end.latitude},${end.longitude}"
                
                segmentCounter[segmentKey] = segmentCounter.getOrDefault(segmentKey, 0) + 1
                
                if (segmentCounter[segmentKey] == 1) { // First time seeing this segment
                    segments.add(ShippingLaneSegment(
                        id = "lane_${segments.size}",
                        startPosition = start,
                        endPosition = end,
                        distance = start.distanceTo(end),
                        importance = 1
                    ))
                }
            }
        }
        
        return segments
    }
    
    private fun calculateLaneCapacity(segment: ShippingLaneSegment): Int {
        // Base capacity calculation based on distance and importance
        val baseCapacity = max(10, (segment.distance / 100.0).toInt()) // 1 vessel per 100 nautical miles
        return baseCapacity * segment.importance
    }
    
    private fun findCurrentLane(currentPos: GeographicalPosition, targetPos: GeographicalPosition): ShippingLaneState? {
        return _laneStates.values.minByOrNull { lane ->
            val laneStart = lane.startPosition
            val laneEnd = lane.endPosition
            
            // Calculate distance from current position to the lane
            distanceToLineSegment(currentPos, laneStart, laneEnd)
        }
    }
    
    private fun distanceToLineSegment(point: GeographicalPosition, lineStart: GeographicalPosition, lineEnd: GeographicalPosition): Double {
        val A = point.latitude - lineStart.latitude
        val B = point.longitude - lineStart.longitude
        val C = lineEnd.latitude - lineStart.latitude
        val D = lineEnd.longitude - lineStart.longitude
        
        val dot = A * C + B * D
        val lenSq = C * C + D * D
        
        if (lenSq == 0.0) return point.distanceTo(lineStart)
        
        val param = dot / lenSq
        
        val closestPoint = when {
            param < 0 -> lineStart
            param > 1 -> lineEnd
            else -> GeographicalPosition(
                lineStart.latitude + param * C,
                lineStart.longitude + param * D
            )
        }
        
        return point.distanceTo(closestPoint)
    }
    
    private fun calculateEffectiveSpeed(vessel: SimulatedVessel, lane: ShippingLaneState?): Double {
        var effectiveSpeed = vessel.vessel.cruisingSpeed
        
        // Apply congestion factor
        lane?.let { laneState ->
            effectiveSpeed *= when (laneState.congestionLevel) {
                CongestionLevel.CLEAR -> 1.0
                CongestionLevel.LIGHT -> 0.95
                CongestionLevel.MODERATE -> 0.85
                CongestionLevel.HEAVY -> 0.7
                CongestionLevel.SEVERE -> 0.5
            }
        }
        
        // Apply weather factor
        val weatherCondition = lane?.let { _weatherSystem.getWeatherCondition(it.id) }
        effectiveSpeed *= when (weatherCondition) {
            WeatherCondition.EXCELLENT -> 1.0
            WeatherCondition.GOOD -> 0.95
            WeatherCondition.MODERATE -> 0.85
            WeatherCondition.POOR -> 0.7
            WeatherCondition.SEVERE -> 0.4
            null -> 1.0
        }
        
        return maxOf(effectiveSpeed, vessel.vessel.cruisingSpeed * 0.3) // Minimum 30% speed
    }
    
    private fun countVesselsInLane(laneId: String): Int {
        val lane = _laneStates[laneId] ?: return 0
        return _vesselPositions.values.count { vessel ->
            val currentLane = findCurrentLane(vessel.currentPosition, vessel.targetPosition)
            currentLane?.id == laneId
        }
    }
    
    private fun calculateCongestionLevel(traffic: Int, capacity: Int): CongestionLevel {
        val utilization = traffic.toDouble() / capacity
        
        return when {
            utilization < 0.3 -> CongestionLevel.CLEAR
            utilization < 0.5 -> CongestionLevel.LIGHT
            utilization < 0.7 -> CongestionLevel.MODERATE
            utilization < 0.9 -> CongestionLevel.HEAVY
            else -> CongestionLevel.SEVERE
        }
    }
    
    private fun calculateAverageSpeed(congestionLevel: CongestionLevel, baseSpeed: Double): Double {
        return baseSpeed * when (congestionLevel) {
            CongestionLevel.CLEAR -> 1.0
            CongestionLevel.LIGHT -> 0.95
            CongestionLevel.MODERATE -> 0.85
            CongestionLevel.HEAVY -> 0.7
            CongestionLevel.SEVERE -> 0.5
        }
    }
    
    private fun getNextWaypoint(route: TradeRoute, waypointIndex: Int): GeographicalPosition {
        val allPorts = route.allPorts
        return if (waypointIndex < allPorts.size) {
            allPorts[waypointIndex].position
        } else {
            route.destination.position
        }
    }
    
    private fun calculateInitialHeading(route: TradeRoute): Double {
        return route.origin.position.bearingTo(route.destination.position)
    }
    
    private fun calculateEstimatedArrival(route: TradeRoute, vessel: Vessel): LocalDateTime {
        val totalDistance = route.getTotalDistance()
        val estimatedHours = totalDistance / vessel.cruisingSpeed
        return LocalDateTime.now().plusMinutes((estimatedHours * 60).toLong())
    }
    
    private fun interpolatePosition(start: GeographicalPosition, end: GeographicalPosition, progress: Double): GeographicalPosition {
        val lat = start.latitude + (end.latitude - start.latitude) * progress
        val lon = start.longitude + (end.longitude - start.longitude) * progress
        return GeographicalPosition(lat, lon)
    }
    
    private fun createRouteSegments(route: TradeRoute): List<RouteSegment> {
        val segments = mutableListOf<RouteSegment>()
        val ports = route.allPorts
        
        for (i in 0 until ports.size - 1) {
            val start = ports[i].position
            val end = ports[i + 1].position
            val distance = start.distanceTo(end)
            
            segments.add(RouteSegment(
                startPosition = start,
                endPosition = end,
                distance = distance,
                estimatedTransitTime = (distance / route.vessel.cruisingSpeed * 60).toLong() // minutes
            ))
        }
        
        return segments
    }
    
    private fun findNearestLane(start: GeographicalPosition, end: GeographicalPosition): String {
        return _laneStates.values.minByOrNull { lane ->
            val startDist = start.distanceTo(lane.startPosition)
            val endDist = end.distanceTo(lane.endPosition)
            startDist + endDist
        }?.id ?: "default_lane"
    }
    
    private fun calculateCongestionDelay(lane: ShippingLaneState, transitTime: Long): Long {
        return when (lane.congestionLevel) {
            CongestionLevel.HEAVY -> (transitTime * 0.2).toLong()
            CongestionLevel.SEVERE -> (transitTime * 0.5).toLong()
            else -> 0L
        }
    }
    
    private fun calculatePredictionConfidence(delays: List<DelayPrediction>): Double {
        if (delays.isEmpty()) return 0.95
        
        val avgProbability = delays.map { it.probability }.average()
        return avgProbability * 0.9 // Slightly reduce confidence for complexity
    }
    
    private fun generateDelayAlerts(): List<DelayAlert> {
        val alerts = mutableListOf<DelayAlert>()
        
        // Generate alerts for severely congested lanes
        _laneStates.values.filter { it.congestionLevel == CongestionLevel.SEVERE }.forEach { lane ->
            alerts.add(DelayAlert(
                type = DelayType.CONGESTION,
                severity = DelaySeverity.HIGH,
                affectedArea = "Lane ${lane.id}",
                estimatedDelay = 60, // minutes
                message = "Severe congestion on shipping lane ${lane.id}"
            ))
        }
        
        return alerts
    }
}

// Supporting data classes and enums

/**
 * State of a shipping lane
 */
data class ShippingLaneState(
    val id: String,
    val startPosition: GeographicalPosition,
    val endPosition: GeographicalPosition,
    val distance: Double, // nautical miles
    val capacity: Int, // maximum vessels
    val currentTraffic: Int, // current vessels
    val averageSpeed: Double, // knots
    val congestionLevel: CongestionLevel,
    val weatherConditions: MutableMap<String, WeatherCondition>,
    val restrictions: MutableSet<LaneRestriction>,
    val lastUpdated: LocalDateTime
)

/**
 * Simulated vessel in the system
 */
data class SimulatedVessel(
    val id: String,
    val vessel: Vessel,
    val route: TradeRoute,
    val currentPosition: GeographicalPosition,
    val targetPosition: GeographicalPosition,
    val waypointIndex: Int,
    val speed: Double, // current speed in knots
    val heading: Double, // degrees
    val status: VesselSimulationStatus,
    val estimatedArrival: LocalDateTime,
    val delays: List<SimulationDelay>,
    val fuelConsumed: Double, // liters
    val distanceTraveled: Double, // nautical miles
    val lastUpdated: LocalDateTime
)

/**
 * Shipping lane segment
 */
data class ShippingLaneSegment(
    val id: String,
    val startPosition: GeographicalPosition,
    val endPosition: GeographicalPosition,
    val distance: Double,
    val importance: Int // Traffic importance factor
)

/**
 * Route segment for delay prediction
 */
data class RouteSegment(
    val startPosition: GeographicalPosition,
    val endPosition: GeographicalPosition,
    val distance: Double,
    val estimatedTransitTime: Long // minutes
)

/**
 * Traffic congestion levels
 */
enum class CongestionLevel {
    CLEAR,
    LIGHT,
    MODERATE,
    HEAVY,
    SEVERE
}

/**
 * Vessel simulation status
 */
enum class VesselSimulationStatus {
    SAILING,
    ANCHORED,
    IN_PORT,
    DELAYED,
    COMPLETED
}

/**
 * Shipping lane restrictions
 */
enum class LaneRestriction {
    WEATHER_CLOSED,
    POLITICAL_RESTRICTION,
    MAINTENANCE,
    SECURITY_ALERT,
    ENVIRONMENTAL_PROTECTION
}

/**
 * Simulation delay
 */
data class SimulationDelay(
    val type: DelayType,
    val severity: DelaySeverity,
    val estimatedDurationMinutes: Int,
    val cause: String,
    val startTime: LocalDateTime = LocalDateTime.now()
) {
    fun isActive(): Boolean {
        val endTime = startTime.plusMinutes(estimatedDurationMinutes.toLong())
        return LocalDateTime.now().isBefore(endTime)
    }
}

/**
 * Delay severity levels
 */
enum class DelaySeverity {
    LOW,
    MEDIUM,
    HIGH,
    CRITICAL
}

/**
 * Delay prediction for route planning
 */
data class DelayPrediction(
    val type: DelayType,
    val estimatedMinutes: Long,
    val probability: Double, // 0.0 to 1.0
    val segment: RouteSegment
)

/**
 * Complete route delay prediction
 */
data class RouteDelayPrediction(
    val route: TradeRoute,
    val delayPredictions: List<DelayPrediction>,
    val totalEstimatedDelay: Long, // minutes
    val confidence: Double // 0.0 to 1.0
)

/**
 * Real-time traffic update
 */
data class TrafficUpdate(
    val timestamp: LocalDateTime,
    val totalVessels: Int,
    val congestedLanes: List<String>,
    val averageCongestionLevel: Double,
    val activeWeatherEvents: List<WeatherEvent>,
    val activePoliticalEvents: List<PoliticalEvent>,
    val delayAlerts: List<DelayAlert>
)

/**
 * Delay alert for users
 */
data class DelayAlert(
    val type: DelayType,
    val severity: DelaySeverity,
    val affectedArea: String,
    val estimatedDelay: Int, // minutes
    val message: String
)

// Traffic events
sealed class TrafficEvent {
    object SimulationStarted : TrafficEvent()
    object SimulationStopped : TrafficEvent()
    data class VesselAdded(val vessel: SimulatedVessel) : TrafficEvent()
    data class VesselRemoved(val vessel: SimulatedVessel) : TrafficEvent()
    data class VesselCompleted(val vessel: SimulatedVessel) : TrafficEvent()
    data class VesselWaypointReached(val vessel: SimulatedVessel) : TrafficEvent()
    data class VesselDelayed(val vessel: SimulatedVessel, val delays: List<SimulationDelay>) : TrafficEvent()
    data class CongestionAlert(val laneId: String, val level: CongestionLevel) : TrafficEvent()
    data class WeatherAlert(val event: WeatherEvent) : TrafficEvent()
    data class PoliticalAlert(val event: PoliticalEvent) : TrafficEvent()
}

// Placeholder classes for weather and political systems
data class WeatherEvent(val type: String, val severity: String, val affectedArea: String)
data class PoliticalEvent(val type: String, val countries: List<String>, val impact: String)

class WeatherSimulationSystem {
    fun initialize(laneIds: List<String>) {}
    fun update(currentTime: LocalDateTime) {}
    fun getWeatherCondition(laneId: String): WeatherCondition = WeatherCondition.GOOD
    fun predictWeatherDelay(laneId: String, transitTime: Long): Long = 0L
    fun getActiveWeatherEvents(): List<WeatherEvent> = emptyList()
}

class PoliticalEventSystem {
    fun initialize(countries: List<String>) {}
    fun update(currentTime: LocalDateTime) {}
    fun predictPoliticalDelay(start: GeographicalPosition, end: GeographicalPosition): Long = 0L
    fun getActivePoliticalEvents(): List<PoliticalEvent> = emptyList()
}