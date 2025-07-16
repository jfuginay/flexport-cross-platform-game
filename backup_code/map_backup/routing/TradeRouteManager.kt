package com.flexport.map.routing

import com.flexport.economics.models.Commodity
import com.flexport.economics.models.CommodityType
import com.flexport.map.models.*
import java.time.LocalDateTime
import java.util.*
import java.util.concurrent.ConcurrentHashMap
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*

/**
 * Manages trade routes, their creation, modification, and lifecycle
 */
class TradeRouteManager {
    
    private val _routes = ConcurrentHashMap<String, TradeRoute>()
    private val _routeEvents = MutableSharedFlow<RouteEvent>()
    
    /**
     * Observable flow of route events
     */
    val routeEvents: SharedFlow<RouteEvent> = _routeEvents.asSharedFlow()
    
    /**
     * Get all active routes
     */
    val activeRoutes: List<TradeRoute>
        get() = _routes.values.filter { it.status == RouteStatus.ACTIVE }
    
    /**
     * Get all routes
     */
    val allRoutes: List<TradeRoute>
        get() = _routes.values.toList()
    
    /**
     * Create a new trade route
     */
    suspend fun createRoute(
        name: String,
        origin: Port,
        destination: Port,
        waypoints: List<Port> = emptyList(),
        cargo: List<CargoManifest>,
        vessel: Vessel,
        schedule: RouteSchedule
    ): Result<TradeRoute> = withContext(Dispatchers.Default) {
        
        try {
            val route = TradeRoute(
                name = name,
                origin = origin,
                destination = destination,
                waypoints = waypoints,
                cargo = cargo,
                vessel = vessel,
                schedule = schedule,
                status = RouteStatus.PLANNING
            )
            
            // Validate the route
            val validationIssues = route.validateRoute()
            if (validationIssues.isNotEmpty()) {
                return@withContext Result.failure(
                    RouteValidationException("Route validation failed", validationIssues)
                )
            }
            
            // Store the route
            _routes[route.id] = route
            
            // Emit event
            _routeEvents.emit(RouteEvent.RouteCreated(route))
            
            Result.success(route)
            
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * Update an existing route
     */
    suspend fun updateRoute(routeId: String, updater: (TradeRoute) -> TradeRoute): Result<TradeRoute> {
        return withContext(Dispatchers.Default) {
            try {
                val existingRoute = _routes[routeId]
                    ?: return@withContext Result.failure(RouteNotFoundException(routeId))
                
                val updatedRoute = updater(existingRoute).copy(
                    lastUpdated = LocalDateTime.now()
                )
                
                // Validate updated route
                val validationIssues = updatedRoute.validateRoute()
                if (validationIssues.isNotEmpty()) {
                    return@withContext Result.failure(
                        RouteValidationException("Route update validation failed", validationIssues)
                    )
                }
                
                _routes[routeId] = updatedRoute
                _routeEvents.emit(RouteEvent.RouteUpdated(updatedRoute))
                
                Result.success(updatedRoute)
                
            } catch (e: Exception) {
                Result.failure(e)
            }
        }
    }
    
    /**
     * Delete a route
     */
    suspend fun deleteRoute(routeId: String): Result<Unit> {
        return withContext(Dispatchers.Default) {
            try {
                val route = _routes.remove(routeId)
                    ?: return@withContext Result.failure(RouteNotFoundException(routeId))
                
                _routeEvents.emit(RouteEvent.RouteDeleted(route))
                Result.success(Unit)
                
            } catch (e: Exception) {
                Result.failure(e)
            }
        }
    }
    
    /**
     * Activate a route (change status from PLANNING to ACTIVE)
     */
    suspend fun activateRoute(routeId: String): Result<TradeRoute> {
        return updateRoute(routeId) { route ->
            when (route.status) {
                RouteStatus.PLANNING, RouteStatus.APPROVED -> route.copy(status = RouteStatus.ACTIVE)
                else -> throw IllegalStateException("Cannot activate route in status ${route.status}")
            }
        }
    }
    
    /**
     * Suspend a route
     */
    suspend fun suspendRoute(routeId: String, reason: String): Result<TradeRoute> {
        return updateRoute(routeId) { route ->
            route.copy(status = RouteStatus.SUSPENDED)
        }
    }
    
    /**
     * Cancel a route
     */
    suspend fun cancelRoute(routeId: String, reason: String): Result<TradeRoute> {
        return updateRoute(routeId) { route ->
            route.copy(status = RouteStatus.CANCELLED)
        }
    }
    
    /**
     * Add cargo to a route
     */
    suspend fun addCargo(
        routeId: String,
        commodity: Commodity,
        quantity: Double,
        loadingPort: Port,
        dischargingPort: Port,
        priority: CargoPriority = CargoPriority.NORMAL
    ): Result<TradeRoute> {
        return updateRoute(routeId) { route ->
            if (!route.canAccommodateCargo(commodity, quantity)) {
                throw InsufficientCapacityException("Cannot accommodate additional cargo")
            }
            
            val newManifest = CargoManifest(
                commodity = commodity,
                quantity = quantity,
                loadingPort = loadingPort,
                dischargingPort = dischargingPort,
                priority = priority
            )
            
            route.copy(cargo = route.cargo + newManifest)
        }
    }
    
    /**
     * Remove cargo from a route
     */
    suspend fun removeCargo(routeId: String, manifestIndex: Int): Result<TradeRoute> {
        return updateRoute(routeId) { route ->
            if (manifestIndex < 0 || manifestIndex >= route.cargo.size) {
                throw IndexOutOfBoundsException("Invalid manifest index")
            }
            
            route.copy(cargo = route.cargo.filterIndexed { index, _ -> index != manifestIndex })
        }
    }
    
    /**
     * Find routes by origin port
     */
    fun findRoutesByOrigin(portId: String): List<TradeRoute> {
        return _routes.values.filter { it.origin.id == portId }
    }
    
    /**
     * Find routes by destination port
     */
    fun findRoutesByDestination(portId: String): List<TradeRoute> {
        return _routes.values.filter { it.destination.id == portId }
    }
    
    /**
     * Find routes by commodity type
     */
    fun findRoutesByCommodity(commodityType: CommodityType): List<TradeRoute> {
        return _routes.values.filter { route ->
            route.cargo.any { it.commodity.type == commodityType }
        }
    }
    
    /**
     * Find routes by vessel
     */
    fun findRoutesByVessel(vesselId: String): List<TradeRoute> {
        return _routes.values.filter { it.vessel.id == vesselId }
    }
    
    /**
     * Get route by ID
     */
    fun getRoute(routeId: String): TradeRoute? {
        return _routes[routeId]
    }
    
    /**
     * Get routes within a geographical area
     */
    fun getRoutesInArea(bounds: GeographicalBounds): List<TradeRoute> {
        return _routes.values.filter { route ->
            route.allPorts.any { port ->
                bounds.contains(port.position)
            }
        }
    }
    
    /**
     * Get route statistics
     */
    fun getRouteStatistics(): RouteStatistics {
        val routes = _routes.values
        
        return RouteStatistics(
            totalRoutes = routes.size,
            activeRoutes = routes.count { it.status == RouteStatus.ACTIVE },
            plannedRoutes = routes.count { it.status == RouteStatus.PLANNING },
            suspendedRoutes = routes.count { it.status == RouteStatus.SUSPENDED },
            cancelledRoutes = routes.count { it.status == RouteStatus.CANCELLED },
            totalCargo = routes.sumOf { it.getTotalCargoValue() },
            averageDistance = routes.map { it.getTotalDistance() }.average().takeIf { !it.isNaN() } ?: 0.0,
            routesByRegion = routes.groupBy { it.origin.region }.mapValues { it.value.size }
        )
    }
    
    /**
     * Update route performance metrics
     */
    suspend fun updateRoutePerformance(routeId: String, performance: RoutePerformance): Result<TradeRoute> {
        return updateRoute(routeId) { route ->
            route.copy(performance = performance)
        }
    }
    
    /**
     * Get routes requiring attention (delayed, issues, etc.)
     */
    fun getRoutesRequiringAttention(): List<TradeRoute> {
        return _routes.values.filter { route ->
            route.status == RouteStatus.DELAYED ||
            route.performance?.onTimePerformance?.let { it < 80.0 } == true ||
            route.validateRoute().isNotEmpty()
        }
    }
    
    /**
     * Simulate route execution for performance testing
     */
    suspend fun simulateRoute(routeId: String, iterations: Int = 100): RouteSimulationResult = 
        withContext(Dispatchers.Default) {
            val route = _routes[routeId] ?: throw RouteNotFoundException(routeId)
            
            val results = mutableListOf<SimulationIteration>()
            
            repeat(iterations) { iteration ->
                // Simulate various factors affecting the route
                val weatherDelay = simulateWeatherDelay(route)
                val portDelay = simulatePortDelay(route)
                val fuelConsumption = simulateFuelConsumption(route)
                val actualTransitTime = route.getEstimatedTransitTime() + weatherDelay + portDelay
                
                results.add(
                    SimulationIteration(
                        iteration = iteration,
                        transitTime = actualTransitTime,
                        fuelConsumption = fuelConsumption,
                        weatherDelay = weatherDelay,
                        portDelay = portDelay,
                        onTime = actualTransitTime <= route.getEstimatedTransitTime() * 1.1 // 10% tolerance
                    )
                )
            }
            
            RouteSimulationResult(
                routeId = routeId,
                iterations = results,
                averageTransitTime = results.map { it.transitTime }.average(),
                onTimePerformance = results.count { it.onTime }.toDouble() / iterations * 100,
                averageFuelConsumption = results.map { it.fuelConsumption }.average(),
                averageWeatherDelay = results.map { it.weatherDelay }.average(),
                averagePortDelay = results.map { it.portDelay }.average()
            )
        }
    
    private fun simulateWeatherDelay(route: TradeRoute): Double {
        // Simple weather delay simulation based on route and season
        val baseDelay = Random().nextGaussian() * 2.0 // Hours
        return maxOf(0.0, baseDelay)
    }
    
    private fun simulatePortDelay(route: TradeRoute): Double {
        // Port congestion and handling delays
        val totalPorts = route.allPorts.size
        val baseDelayPerPort = Random().nextGaussian() * 4.0 // Hours per port
        return maxOf(0.0, baseDelayPerPort * totalPorts)
    }
    
    private fun simulateFuelConsumption(route: TradeRoute): Double {
        // Fuel consumption with weather and cargo factors
        val baseConsumption = route.vessel.fuelConsumption * route.getTotalDistance()
        val variation = Random().nextGaussian() * 0.1 // 10% variation
        return baseConsumption * (1.0 + variation)
    }
}

/**
 * Route events for observing changes
 */
sealed class RouteEvent {
    data class RouteCreated(val route: TradeRoute) : RouteEvent()
    data class RouteUpdated(val route: TradeRoute) : RouteEvent()
    data class RouteDeleted(val route: TradeRoute) : RouteEvent()
    data class RouteStatusChanged(val route: TradeRoute, val oldStatus: RouteStatus) : RouteEvent()
    data class CargoAdded(val route: TradeRoute, val manifest: CargoManifest) : RouteEvent()
    data class CargoRemoved(val route: TradeRoute, val manifest: CargoManifest) : RouteEvent()
}

/**
 * Route statistics summary
 */
data class RouteStatistics(
    val totalRoutes: Int,
    val activeRoutes: Int,
    val plannedRoutes: Int,
    val suspendedRoutes: Int,
    val cancelledRoutes: Int,
    val totalCargo: Double,
    val averageDistance: Double,
    val routesByRegion: Map<String, Int>
)

/**
 * Route simulation results
 */
data class RouteSimulationResult(
    val routeId: String,
    val iterations: List<SimulationIteration>,
    val averageTransitTime: Double,
    val onTimePerformance: Double,
    val averageFuelConsumption: Double,
    val averageWeatherDelay: Double,
    val averagePortDelay: Double
)

/**
 * Single simulation iteration result
 */
data class SimulationIteration(
    val iteration: Int,
    val transitTime: Double,
    val fuelConsumption: Double,
    val weatherDelay: Double,
    val portDelay: Double,
    val onTime: Boolean
)

/**
 * Custom exceptions for route management
 */
class RouteNotFoundException(routeId: String) : Exception("Route not found: $routeId")

class RouteValidationException(
    message: String,
    val issues: List<ValidationIssue>
) : Exception(message)

class InsufficientCapacityException(message: String) : Exception(message)