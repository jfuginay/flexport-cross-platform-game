package com.flexport.map.optimization

import com.flexport.economics.models.Commodity
import com.flexport.map.models.*
import kotlinx.coroutines.*
import java.util.*
import kotlin.math.*

/**
 * Advanced route optimization algorithms for trade routes
 */
class RouteOptimizer {
    
    /**
     * Find optimal route between ports using multiple optimization criteria
     */
    suspend fun optimizeRoute(
        origin: Port,
        destination: Port,
        availablePorts: List<Port>,
        vessel: Vessel,
        cargo: List<CargoManifest>,
        criteria: OptimizationCriteria = OptimizationCriteria.BALANCED
    ): OptimizationResult = withContext(Dispatchers.Default) {
        
        when (criteria) {
            OptimizationCriteria.SHORTEST_DISTANCE -> findShortestPath(origin, destination, availablePorts)
            OptimizationCriteria.FASTEST_TIME -> findFastestRoute(origin, destination, availablePorts, vessel)
            OptimizationCriteria.LOWEST_COST -> findLowestCostRoute(origin, destination, availablePorts, vessel, cargo)
            OptimizationCriteria.HIGHEST_PROFIT -> findMostProfitableRoute(origin, destination, availablePorts, vessel, cargo)
            OptimizationCriteria.BALANCED -> findBalancedRoute(origin, destination, availablePorts, vessel, cargo)
            OptimizationCriteria.ENVIRONMENTAL -> findEcoFriendlyRoute(origin, destination, availablePorts, vessel)
        }
    }
    
    /**
     * Find shortest path using Dijkstra's algorithm
     */
    private suspend fun findShortestPath(
        origin: Port,
        destination: Port,
        availablePorts: List<Port>
    ): OptimizationResult = withContext(Dispatchers.Default) {
        
        val allPorts = (availablePorts + origin + destination).distinctBy { it.id }
        val distances = mutableMapOf<String, Double>()
        val previous = mutableMapOf<String, Port?>()
        val unvisited = mutableSetOf<Port>()
        
        // Initialize distances
        allPorts.forEach { port ->
            distances[port.id] = if (port.id == origin.id) 0.0 else Double.MAX_VALUE
            previous[port.id] = null
            unvisited.add(port)
        }
        
        while (unvisited.isNotEmpty()) {
            // Find unvisited port with minimum distance
            val current = unvisited.minByOrNull { distances[it.id] ?: Double.MAX_VALUE }
                ?: break
            
            if (current.id == destination.id) break
            
            unvisited.remove(current)
            
            // Update distances to neighbors
            unvisited.forEach { neighbor ->
                val distance = current.position.distanceTo(neighbor.position)
                val totalDistance = distances[current.id]!! + distance
                
                if (totalDistance < distances[neighbor.id]!!) {
                    distances[neighbor.id] = totalDistance
                    previous[neighbor.id] = current
                }
            }
        }
        
        // Reconstruct path
        val path = reconstructPath(previous, origin, destination)
        val totalDistance = distances[destination.id] ?: Double.MAX_VALUE
        
        OptimizationResult(
            waypoints = path.drop(1).dropLast(1), // Remove origin and destination
            totalDistance = totalDistance,
            estimatedTransitTime = totalDistance / 12.0, // Assume 12 knots average
            estimatedCost = calculateBasicCost(totalDistance),
            optimizationCriteria = OptimizationCriteria.SHORTEST_DISTANCE,
            confidence = 0.95
        )
    }
    
    /**
     * Find fastest route considering port efficiency and weather
     */
    private suspend fun findFastestRoute(
        origin: Port,
        destination: Port,
        availablePorts: List<Port>,
        vessel: Vessel
    ): OptimizationResult = withContext(Dispatchers.Default) {
        
        val allPorts = (availablePorts + origin + destination).distinctBy { it.id }
        val times = mutableMapOf<String, Double>()
        val previous = mutableMapOf<String, Port?>()
        val unvisited = mutableSetOf<Port>()
        
        // Initialize times
        allPorts.forEach { port ->
            times[port.id] = if (port.id == origin.id) 0.0 else Double.MAX_VALUE
            previous[port.id] = null
            unvisited.add(port)
        }
        
        while (unvisited.isNotEmpty()) {
            val current = unvisited.minByOrNull { times[it.id] ?: Double.MAX_VALUE }
                ?: break
            
            if (current.id == destination.id) break
            
            unvisited.remove(current)
            
            unvisited.forEach { neighbor ->
                val sailingTime = calculateSailingTime(current, neighbor, vessel)
                val portTime = calculatePortTime(neighbor, vessel)
                val totalTime = times[current.id]!! + sailingTime + portTime
                
                if (totalTime < times[neighbor.id]!!) {
                    times[neighbor.id] = totalTime
                    previous[neighbor.id] = current
                }
            }
        }
        
        val path = reconstructPath(previous, origin, destination)
        val totalTime = times[destination.id] ?: Double.MAX_VALUE
        val totalDistance = calculatePathDistance(path)
        
        OptimizationResult(
            waypoints = path.drop(1).dropLast(1),
            totalDistance = totalDistance,
            estimatedTransitTime = totalTime,
            estimatedCost = calculateBasicCost(totalDistance),
            optimizationCriteria = OptimizationCriteria.FASTEST_TIME,
            confidence = 0.90
        )
    }
    
    /**
     * Find lowest cost route considering fuel, port fees, and delays
     */
    private suspend fun findLowestCostRoute(
        origin: Port,
        destination: Port,
        availablePorts: List<Port>,
        vessel: Vessel,
        cargo: List<CargoManifest>
    ): OptimizationResult = withContext(Dispatchers.Default) {
        
        val allPorts = (availablePorts + origin + destination).distinctBy { it.id }
        val costs = mutableMapOf<String, Double>()
        val previous = mutableMapOf<String, Port?>()
        val unvisited = mutableSetOf<Port>()
        
        allPorts.forEach { port ->
            costs[port.id] = if (port.id == origin.id) 0.0 else Double.MAX_VALUE
            previous[port.id] = null
            unvisited.add(port)
        }
        
        while (unvisited.isNotEmpty()) {
            val current = unvisited.minByOrNull { costs[it.id] ?: Double.MAX_VALUE }
                ?: break
            
            if (current.id == destination.id) break
            
            unvisited.remove(current)
            
            unvisited.forEach { neighbor ->
                val routeCost = calculateRouteCost(current, neighbor, vessel, cargo)
                val totalCost = costs[current.id]!! + routeCost
                
                if (totalCost < costs[neighbor.id]!!) {
                    costs[neighbor.id] = totalCost
                    previous[neighbor.id] = current
                }
            }
        }
        
        val path = reconstructPath(previous, origin, destination)
        val totalCost = costs[destination.id] ?: Double.MAX_VALUE
        val totalDistance = calculatePathDistance(path)
        
        OptimizationResult(
            waypoints = path.drop(1).dropLast(1),
            totalDistance = totalDistance,
            estimatedTransitTime = calculatePathTime(path, vessel),
            estimatedCost = totalCost,
            optimizationCriteria = OptimizationCriteria.LOWEST_COST,
            confidence = 0.85
        )
    }
    
    /**
     * Find most profitable route considering cargo values and market demand
     */
    private suspend fun findMostProfitableRoute(
        origin: Port,
        destination: Port,
        availablePorts: List<Port>,
        vessel: Vessel,
        cargo: List<CargoManifest>
    ): OptimizationResult = withContext(Dispatchers.Default) {
        
        // Use genetic algorithm for profit optimization
        val population = generateInitialPopulation(origin, destination, availablePorts, 50)
        val generations = 100
        
        var bestRoute = population.maxByOrNull { 
            calculateRouteProfitability(it, vessel, cargo) 
        } ?: listOf(origin, destination)
        
        repeat(generations) {
            val newPopulation = evolvePopulation(population, vessel, cargo)
            val generationBest = newPopulation.maxByOrNull { 
                calculateRouteProfitability(it, vessel, cargo) 
            }
            
            if (generationBest != null && 
                calculateRouteProfitability(generationBest, vessel, cargo) > 
                calculateRouteProfitability(bestRoute, vessel, cargo)) {
                bestRoute = generationBest
            }
        }
        
        val totalDistance = calculatePathDistance(bestRoute)
        val totalCost = calculatePathCost(bestRoute, vessel, cargo)
        val totalRevenue = calculatePathRevenue(bestRoute, cargo)
        
        OptimizationResult(
            waypoints = bestRoute.drop(1).dropLast(1),
            totalDistance = totalDistance,
            estimatedTransitTime = calculatePathTime(bestRoute, vessel),
            estimatedCost = totalCost,
            estimatedRevenue = totalRevenue,
            optimizationCriteria = OptimizationCriteria.HIGHEST_PROFIT,
            confidence = 0.80
        )
    }
    
    /**
     * Find balanced route optimizing multiple factors
     */
    private suspend fun findBalancedRoute(
        origin: Port,
        destination: Port,
        availablePorts: List<Port>,
        vessel: Vessel,
        cargo: List<CargoManifest>
    ): OptimizationResult = withContext(Dispatchers.Default) {
        
        // Multi-criteria optimization using weighted sum
        val criteria = listOf(
            OptimizationCriteria.SHORTEST_DISTANCE,
            OptimizationCriteria.FASTEST_TIME,
            OptimizationCriteria.LOWEST_COST,
            OptimizationCriteria.HIGHEST_PROFIT
        )
        
        val weights = listOf(0.25, 0.25, 0.25, 0.25) // Equal weights
        
        val results = criteria.map { criterion ->
            when (criterion) {
                OptimizationCriteria.SHORTEST_DISTANCE -> findShortestPath(origin, destination, availablePorts)
                OptimizationCriteria.FASTEST_TIME -> findFastestRoute(origin, destination, availablePorts, vessel)
                OptimizationCriteria.LOWEST_COST -> findLowestCostRoute(origin, destination, availablePorts, vessel, cargo)
                OptimizationCriteria.HIGHEST_PROFIT -> findMostProfitableRoute(origin, destination, availablePorts, vessel, cargo)
                else -> findShortestPath(origin, destination, availablePorts)
            }
        }
        
        // Score each result and select best balanced option
        val scores = results.mapIndexed { index, result ->
            calculateBalancedScore(result, weights[index])
        }
        
        val bestIndex = scores.indices.maxByOrNull { scores[it] } ?: 0
        results[bestIndex].copy(
            optimizationCriteria = OptimizationCriteria.BALANCED,
            confidence = 0.88
        )
    }
    
    /**
     * Find environmentally friendly route minimizing emissions
     */
    private suspend fun findEcoFriendlyRoute(
        origin: Port,
        destination: Port,
        availablePorts: List<Port>,
        vessel: Vessel
    ): OptimizationResult = withContext(Dispatchers.Default) {
        
        val allPorts = (availablePorts + origin + destination).distinctBy { it.id }
        val emissions = mutableMapOf<String, Double>()
        val previous = mutableMapOf<String, Port?>()
        val unvisited = mutableSetOf<Port>()
        
        allPorts.forEach { port ->
            emissions[port.id] = if (port.id == origin.id) 0.0 else Double.MAX_VALUE
            previous[port.id] = null
            unvisited.add(port)
        }
        
        while (unvisited.isNotEmpty()) {
            val current = unvisited.minByOrNull { emissions[it.id] ?: Double.MAX_VALUE }
                ?: break
            
            if (current.id == destination.id) break
            
            unvisited.remove(current)
            
            unvisited.forEach { neighbor ->
                val routeEmissions = calculateRouteEmissions(current, neighbor, vessel)
                val totalEmissions = emissions[current.id]!! + routeEmissions
                
                if (totalEmissions < emissions[neighbor.id]!!) {
                    emissions[neighbor.id] = totalEmissions
                    previous[neighbor.id] = current
                }
            }
        }
        
        val path = reconstructPath(previous, origin, destination)
        val totalEmissions = emissions[destination.id] ?: Double.MAX_VALUE
        val totalDistance = calculatePathDistance(path)
        
        OptimizationResult(
            waypoints = path.drop(1).dropLast(1),
            totalDistance = totalDistance,
            estimatedTransitTime = calculatePathTime(path, vessel),
            estimatedCost = calculateBasicCost(totalDistance),
            estimatedEmissions = totalEmissions,
            optimizationCriteria = OptimizationCriteria.ENVIRONMENTAL,
            confidence = 0.90
        )
    }
    
    /**
     * Multi-port cargo optimization for complex routes
     */
    suspend fun optimizeMultiPortRoute(
        ports: List<Port>,
        vessel: Vessel,
        cargoRequests: List<CargoRequest>
    ): MultiPortOptimizationResult = withContext(Dispatchers.Default) {
        
        // This is a variant of the Vehicle Routing Problem (VRP)
        // Use a combination of nearest neighbor and 2-opt improvement
        
        val servicePorts = ports.filter { port ->
            cargoRequests.any { request ->
                request.origin.id == port.id || request.destination.id == port.id
            }
        }
        
        if (servicePorts.isEmpty()) {
            return@withContext MultiPortOptimizationResult(
                route = emptyList(),
                cargoAssignments = emptyList(),
                totalDistance = 0.0,
                totalCost = 0.0,
                totalRevenue = 0.0,
                vesselUtilization = 0.0
            )
        }
        
        // Start with nearest neighbor heuristic
        var currentRoute = buildNearestNeighborRoute(servicePorts)
        
        // Improve with 2-opt
        currentRoute = improve2Opt(currentRoute)
        
        // Assign cargo to route
        val cargoAssignments = assignCargoToRoute(currentRoute, cargoRequests, vessel)
        
        val totalDistance = calculatePathDistance(currentRoute)
        val totalCost = calculatePathCost(currentRoute, vessel, cargoAssignments.map { it.manifest })
        val totalRevenue = cargoAssignments.sumOf { it.manifest.value }
        val vesselUtilization = calculateVesselUtilization(cargoAssignments, vessel)
        
        MultiPortOptimizationResult(
            route = currentRoute,
            cargoAssignments = cargoAssignments,
            totalDistance = totalDistance,
            totalCost = totalCost,
            totalRevenue = totalRevenue,
            vesselUtilization = vesselUtilization
        )
    }
    
    // Helper functions
    
    private fun reconstructPath(
        previous: Map<String, Port?>,
        origin: Port,
        destination: Port
    ): List<Port> {
        val path = mutableListOf<Port>()
        var current: Port? = destination
        
        while (current != null) {
            path.add(0, current)
            current = previous[current.id]
        }
        
        return if (path.isNotEmpty() && path[0].id == origin.id) path else emptyList()
    }
    
    private fun calculateSailingTime(from: Port, to: Port, vessel: Vessel): Double {
        val distance = from.position.distanceTo(to.position)
        val weatherFactor = getWeatherFactor(from, to)
        return (distance / vessel.cruisingSpeed) * weatherFactor
    }
    
    private fun calculatePortTime(port: Port, vessel: Vessel): Double {
        val efficiency = port.getEfficiencyFactor()
        val baseTime = when (vessel.type) {
            VesselType.CONTAINER_SHIP -> 24.0
            VesselType.BULK_CARRIER -> 48.0
            VesselType.TANKER -> 36.0
            else -> 30.0
        }
        return baseTime / efficiency
    }
    
    private fun calculateRouteCost(from: Port, to: Port, vessel: Vessel, cargo: List<CargoManifest>): Double {
        val distance = from.position.distanceTo(to.position)
        val fuelCost = distance * vessel.fuelConsumption * 1.2 // Assume fuel price
        val portCost = to.costs.berthingFee + to.costs.pilotage + to.costs.towage
        val handlingCost = cargo.sumOf { manifest ->
            (to.costs.handlingCost[manifest.commodity.type] ?: 50.0) * manifest.quantity
        }
        return fuelCost + portCost + handlingCost
    }
    
    private fun calculateRouteEmissions(from: Port, to: Port, vessel: Vessel): Double {
        val distance = from.position.distanceTo(to.position)
        val fuelConsumption = distance * vessel.fuelConsumption
        return fuelConsumption * 3.14 // CO2 emission factor for marine fuel
    }
    
    private fun calculateRouteProfitability(path: List<Port>, vessel: Vessel, cargo: List<CargoManifest>): Double {
        val revenue = calculatePathRevenue(path, cargo)
        val cost = calculatePathCost(path, vessel, cargo)
        return revenue - cost
    }
    
    private fun calculatePathDistance(path: List<Port>): Double {
        var totalDistance = 0.0
        for (i in 0 until path.size - 1) {
            totalDistance += path[i].position.distanceTo(path[i + 1].position)
        }
        return totalDistance
    }
    
    private fun calculatePathTime(path: List<Port>, vessel: Vessel): Double {
        val distance = calculatePathDistance(path)
        return distance / vessel.cruisingSpeed
    }
    
    private fun calculatePathCost(path: List<Port>, vessel: Vessel, cargo: List<CargoManifest>): Double {
        var totalCost = 0.0
        for (i in 0 until path.size - 1) {
            totalCost += calculateRouteCost(path[i], path[i + 1], vessel, cargo)
        }
        return totalCost
    }
    
    private fun calculatePathRevenue(path: List<Port>, cargo: List<CargoManifest>): Double {
        return cargo.sumOf { it.value }
    }
    
    private fun calculateBasicCost(distance: Double): Double {
        return distance * 2.5 // Basic cost per nautical mile
    }
    
    private fun getWeatherFactor(from: Port, to: Port): Double {
        // Simplified weather factor calculation
        return 1.1 // 10% additional time for weather
    }
    
    private fun calculateBalancedScore(result: OptimizationResult, weight: Double): Double {
        // Normalize and combine metrics for balanced scoring
        val distanceScore = 1.0 / (1.0 + result.totalDistance / 1000.0)
        val timeScore = 1.0 / (1.0 + result.estimatedTransitTime / 100.0)
        val costScore = 1.0 / (1.0 + result.estimatedCost / 10000.0)
        val profitScore = (result.estimatedRevenue ?: 0.0) / max(1.0, result.estimatedCost)
        
        return weight * (distanceScore + timeScore + costScore + profitScore) / 4.0
    }
    
    private fun generateInitialPopulation(
        origin: Port,
        destination: Port,
        availablePorts: List<Port>,
        populationSize: Int
    ): List<List<Port>> {
        val population = mutableListOf<List<Port>>()
        
        repeat(populationSize) {
            val shuffledPorts = availablePorts.shuffled().take(Random().nextInt(min(5, availablePorts.size) + 1))
            population.add(listOf(origin) + shuffledPorts + listOf(destination))
        }
        
        return population
    }
    
    private fun evolvePopulation(
        population: List<List<Port>>,
        vessel: Vessel,
        cargo: List<CargoManifest>
    ): List<List<Port>> {
        // Simplified genetic algorithm evolution
        return population.shuffled().take(population.size / 2).map { route ->
            if (Random().nextDouble() < 0.1) {
                mutateRoute(route)
            } else {
                route
            }
        } + population.take(population.size / 2)
    }
    
    private fun mutateRoute(route: List<Port>): List<Port> {
        if (route.size <= 2) return route
        
        val mutableRoute = route.toMutableList()
        val waypoints = mutableRoute.subList(1, mutableRoute.size - 1)
        
        if (waypoints.size >= 2) {
            waypoints.shuffle()
        }
        
        return mutableRoute
    }
    
    private fun buildNearestNeighborRoute(ports: List<Port>): List<Port> {
        if (ports.isEmpty()) return emptyList()
        
        val unvisited = ports.toMutableSet()
        val route = mutableListOf<Port>()
        var current = ports.first()
        
        route.add(current)
        unvisited.remove(current)
        
        while (unvisited.isNotEmpty()) {
            val nearest = unvisited.minByOrNull { current.position.distanceTo(it.position) }
            if (nearest != null) {
                route.add(nearest)
                unvisited.remove(nearest)
                current = nearest
            } else {
                break
            }
        }
        
        return route
    }
    
    private fun improve2Opt(route: List<Port>): List<Port> {
        var bestRoute = route
        var improved = true
        
        while (improved) {
            improved = false
            val currentDistance = calculatePathDistance(bestRoute)
            
            for (i in 1 until bestRoute.size - 2) {
                for (j in i + 1 until bestRoute.size - 1) {
                    val newRoute = bestRoute.toMutableList()
                    
                    // Reverse the segment between i and j
                    val segment = newRoute.subList(i, j + 1)
                    segment.reverse()
                    
                    val newDistance = calculatePathDistance(newRoute)
                    if (newDistance < currentDistance) {
                        bestRoute = newRoute
                        improved = true
                    }
                }
            }
        }
        
        return bestRoute
    }
    
    private fun assignCargoToRoute(
        route: List<Port>,
        cargoRequests: List<CargoRequest>,
        vessel: Vessel
    ): List<CargoAssignment> {
        val assignments = mutableListOf<CargoAssignment>()
        var currentWeight = 0.0
        var currentVolume = 0.0
        
        // Sort cargo by profitability
        val sortedRequests = cargoRequests.sortedByDescending { 
            it.value / (it.commodity.weight * it.quantity) 
        }
        
        for (request in sortedRequests) {
            val originIndex = route.indexOfFirst { it.id == request.origin.id }
            val destinationIndex = route.indexOfFirst { it.id == request.destination.id }
            
            if (originIndex >= 0 && destinationIndex > originIndex) {
                val cargoWeight = request.commodity.weight * request.quantity
                val cargoVolume = request.commodity.volume * request.quantity
                
                if (currentWeight + cargoWeight <= vessel.maxCargoWeight &&
                    currentVolume + cargoVolume <= vessel.maxCargoVolume) {
                    
                    val manifest = CargoManifest(
                        commodity = request.commodity,
                        quantity = request.quantity,
                        loadingPort = request.origin,
                        dischargingPort = request.destination,
                        value = request.value
                    )
                    
                    assignments.add(CargoAssignment(manifest, originIndex, destinationIndex))
                    currentWeight += cargoWeight
                    currentVolume += cargoVolume
                }
            }
        }
        
        return assignments
    }
    
    private fun calculateVesselUtilization(assignments: List<CargoAssignment>, vessel: Vessel): Double {
        val totalWeight = assignments.sumOf { it.manifest.getTotalWeight() }
        val totalVolume = assignments.sumOf { it.manifest.getTotalVolume() }
        
        val weightUtilization = totalWeight / vessel.maxCargoWeight
        val volumeUtilization = totalVolume / vessel.maxCargoVolume
        
        return min(weightUtilization, volumeUtilization) * 100.0
    }
}

/**
 * Optimization criteria for route planning
 */
enum class OptimizationCriteria {
    SHORTEST_DISTANCE,
    FASTEST_TIME,
    LOWEST_COST,
    HIGHEST_PROFIT,
    BALANCED,
    ENVIRONMENTAL
}

/**
 * Result of route optimization
 */
data class OptimizationResult(
    val waypoints: List<Port>,
    val totalDistance: Double,
    val estimatedTransitTime: Double,
    val estimatedCost: Double,
    val estimatedRevenue: Double? = null,
    val estimatedEmissions: Double? = null,
    val optimizationCriteria: OptimizationCriteria,
    val confidence: Double // 0.0 to 1.0
)

/**
 * Cargo request for multi-port optimization
 */
data class CargoRequest(
    val commodity: Commodity,
    val quantity: Double,
    val origin: Port,
    val destination: Port,
    val value: Double,
    val deadline: java.time.LocalDateTime? = null,
    val priority: CargoPriority = CargoPriority.NORMAL
)

/**
 * Cargo assignment in a multi-port route
 */
data class CargoAssignment(
    val manifest: CargoManifest,
    val pickupIndex: Int,
    val deliveryIndex: Int
)

/**
 * Result of multi-port route optimization
 */
data class MultiPortOptimizationResult(
    val route: List<Port>,
    val cargoAssignments: List<CargoAssignment>,
    val totalDistance: Double,
    val totalCost: Double,
    val totalRevenue: Double,
    val vesselUtilization: Double // Percentage
)