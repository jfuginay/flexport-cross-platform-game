package com.flexport.assets.assignment

import com.flexport.assets.models.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.time.LocalDateTime
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.min
import kotlin.math.sqrt

/**
 * Manages assignment of assets to routes, cargo, and operational tasks
 */
class AssetAssignmentManager {
    
    private val _assignments = MutableStateFlow<Map<String, AssetAssignment>>(emptyMap())
    val assignments: StateFlow<Map<String, AssetAssignment>> = _assignments.asStateFlow()
    
    private val assignmentRegistry = ConcurrentHashMap<String, AssetAssignment>()
    private val routeRegistry = ConcurrentHashMap<String, TradeRoute>()
    private val cargoQueue = ConcurrentHashMap<String, CargoJob>()
    private val warehouseAllocations = ConcurrentHashMap<String, WarehouseAllocation>()
    
    // Assignment optimization data
    private val assignmentHistory = ConcurrentHashMap<String, MutableList<AssignmentRecord>>()
    private val routePerformance = ConcurrentHashMap<String, RoutePerformanceMetrics>()
    
    /**
     * Assign a ship to a trade route
     */
    suspend fun assignShipToRoute(
        shipId: String,
        routeId: String,
        priority: AssignmentPriority = AssignmentPriority.NORMAL
    ): ShipAssignmentResult {
        val route = routeRegistry[routeId] 
            ?: return ShipAssignmentResult.RouteNotFound
        
        // Validate ship availability and suitability
        val suitability = validateShipSuitability(shipId, route)
        if (suitability !is SuitabilityResult.Suitable) {
            return ShipAssignmentResult.Unsuitable(suitability.reason)
        }
        
        val assignment = AssetAssignment(
            id = "ASSIGN-${System.currentTimeMillis()}",
            assetId = shipId,
            assetType = AssetType.CONTAINER_SHIP,
            assignmentType = AssignmentType.ROUTE,
            targetId = routeId,
            startDate = LocalDateTime.now(),
            priority = priority,
            status = AssignmentStatus.ACTIVE,
            estimatedDuration = calculateRouteDuration(route),
            estimatedRevenue = calculateRouteRevenue(shipId, route)
        )
        
        assignmentRegistry[assignment.id] = assignment
        
        // Record assignment history
        recordAssignment(shipId, assignment)
        
        updateAssignmentState()
        
        return ShipAssignmentResult.Success(assignment.id)
    }
    
    /**
     * Assign aircraft to cargo route
     */
    suspend fun assignAircraftToRoute(
        aircraftId: String,
        cargoJobId: String,
        priority: AssignmentPriority = AssignmentPriority.NORMAL
    ): AircraftAssignmentResult {
        val cargoJob = cargoQueue[cargoJobId] 
            ?: return AircraftAssignmentResult.CargoJobNotFound
        
        val suitability = validateAircraftSuitability(aircraftId, cargoJob)
        if (suitability !is SuitabilityResult.Suitable) {
            return AircraftAssignmentResult.Unsuitable(suitability.reason)
        }
        
        val assignment = AssetAssignment(
            id = "ASSIGN-${System.currentTimeMillis()}",
            assetId = aircraftId,
            assetType = AssetType.CARGO_AIRCRAFT,
            assignmentType = AssignmentType.CARGO_JOB,
            targetId = cargoJobId,
            startDate = LocalDateTime.now(),
            priority = priority,
            status = AssignmentStatus.ACTIVE,
            estimatedDuration = calculateFlightDuration(cargoJob),
            estimatedRevenue = cargoJob.totalValue
        )
        
        assignmentRegistry[assignment.id] = assignment
        cargoJob.assignedAircraftId = aircraftId
        
        recordAssignment(aircraftId, assignment)
        updateAssignmentState()
        
        return AircraftAssignmentResult.Success(assignment.id)
    }
    
    /**
     * Assign warehouse space to cargo
     */
    suspend fun assignWarehouseSpace(
        warehouseId: String,
        cargoId: String,
        requestedSpace: Double,
        storageRequirements: StorageRequirements
    ): WarehouseAssignmentResult {
        val allocation = findOptimalWarehouseAllocation(
            warehouseId, 
            requestedSpace, 
            storageRequirements
        )
        
        if (allocation == null) {
            return WarehouseAssignmentResult.InsufficientSpace
        }
        
        val assignment = AssetAssignment(
            id = "ASSIGN-${System.currentTimeMillis()}",
            assetId = warehouseId,
            assetType = AssetType.WAREHOUSE,
            assignmentType = AssignmentType.STORAGE,
            targetId = cargoId,
            startDate = LocalDateTime.now(),
            priority = AssignmentPriority.NORMAL,
            status = AssignmentStatus.ACTIVE,
            estimatedDuration = null, // Open-ended storage
            estimatedRevenue = calculateStorageRevenue(requestedSpace, storageRequirements)
        )
        
        assignmentRegistry[assignment.id] = assignment
        warehouseAllocations[assignment.id] = allocation
        
        recordAssignment(warehouseId, assignment)
        updateAssignmentState()
        
        return WarehouseAssignmentResult.Success(assignment.id, allocation.zoneId)
    }
    
    /**
     * Optimize asset assignments using AI algorithms
     */
    suspend fun optimizeAssignments(
        optimizationCriteria: OptimizationCriteria
    ): OptimizationResult {
        val currentAssignments = assignmentRegistry.values.filter { 
            it.status == AssignmentStatus.ACTIVE 
        }
        
        val optimizationSuggestions = mutableListOf<OptimizationSuggestion>()
        
        when (optimizationCriteria) {
            OptimizationCriteria.MAXIMIZE_REVENUE -> {
                optimizationSuggestions.addAll(optimizeForRevenue(currentAssignments))
            }
            OptimizationCriteria.MINIMIZE_COST -> {
                optimizationSuggestions.addAll(optimizeForCost(currentAssignments))
            }
            OptimizationCriteria.MAXIMIZE_UTILIZATION -> {
                optimizationSuggestions.addAll(optimizeForUtilization(currentAssignments))
            }
            OptimizationCriteria.MINIMIZE_TRANSIT_TIME -> {
                optimizationSuggestions.addAll(optimizeForSpeed(currentAssignments))
            }
            OptimizationCriteria.BALANCED -> {
                // Weighted combination of all criteria
                optimizationSuggestions.addAll(optimizeBalanced(currentAssignments))
            }
        }
        
        return OptimizationResult(
            criteria = optimizationCriteria,
            suggestions = optimizationSuggestions,
            potentialImprovement = calculatePotentialImprovement(optimizationSuggestions),
            timestamp = LocalDateTime.now()
        )
    }
    
    /**
     * Get assignment recommendations for a specific asset
     */
    suspend fun getAssignmentRecommendations(
        assetId: String,
        assetType: AssetType
    ): List<AssignmentRecommendation> {
        return when (assetType) {
            AssetType.CONTAINER_SHIP -> getShipRecommendations(assetId)
            AssetType.CARGO_AIRCRAFT -> getAircraftRecommendations(assetId)
            AssetType.WAREHOUSE -> getWarehouseRecommendations(assetId)
            else -> emptyList()
        }
    }
    
    /**
     * Unassign an asset from its current assignment
     */
    suspend fun unassignAsset(
        assignmentId: String,
        reason: UnassignmentReason
    ): UnassignmentResult {
        val assignment = assignmentRegistry[assignmentId] 
            ?: return UnassignmentResult.AssignmentNotFound
        
        if (assignment.status != AssignmentStatus.ACTIVE) {
            return UnassignmentResult.InvalidStatus
        }
        
        // Update assignment status
        assignment.status = AssignmentStatus.COMPLETED
        assignment.endDate = LocalDateTime.now()
        assignment.unassignmentReason = reason
        
        // Clean up related data
        when (assignment.assignmentType) {
            AssignmentType.CARGO_JOB -> {
                cargoQueue[assignment.targetId]?.let { job ->
                    job.assignedAircraftId = null
                }
            }
            AssignmentType.STORAGE -> {
                warehouseAllocations.remove(assignmentId)
            }
            else -> {
                // No specific cleanup needed
            }
        }
        
        updateAssignmentState()
        
        return UnassignmentResult.Success
    }
    
    /**
     * Register a new trade route
     */
    fun registerRoute(route: TradeRoute) {
        routeRegistry[route.id] = route
        routePerformance[route.id] = RoutePerformanceMetrics(
            routeId = route.id,
            totalTrips = 0,
            averageRevenue = 0.0,
            averageDuration = 0.0,
            utilizationRate = 0.0,
            lastUpdated = LocalDateTime.now()
        )
    }
    
    /**
     * Register a new cargo job
     */
    fun registerCargoJob(cargoJob: CargoJob) {
        cargoQueue[cargoJob.id] = cargoJob
    }
    
    /**
     * Get assignment statistics
     */
    fun getAssignmentStatistics(): AssignmentStatistics {
        val activeAssignments = assignmentRegistry.values.filter { it.status == AssignmentStatus.ACTIVE }
        
        return AssignmentStatistics(
            totalActiveAssignments = activeAssignments.size,
            assignmentsByType = activeAssignments.groupBy { it.assignmentType }
                .mapValues { it.value.size },
            averageUtilization = calculateAverageUtilization(),
            totalRevenue = activeAssignments.sumOf { it.estimatedRevenue },
            totalAssetsCovered = activeAssignments.map { it.assetId }.distinct().size
        )
    }
    
    // Private helper methods
    private fun validateShipSuitability(shipId: String, route: TradeRoute): SuitabilityResult {
        // In a real implementation, this would check ship specifications against route requirements
        // For now, return suitable with a confidence score
        return SuitabilityResult.Suitable(0.85, "Ship meets route requirements")
    }
    
    private fun validateAircraftSuitability(aircraftId: String, cargoJob: CargoJob): SuitabilityResult {
        // Check aircraft capability against cargo requirements
        val totalWeight = cargoJob.cargoItems.sumOf { it.weight }
        val totalVolume = cargoJob.cargoItems.sumOf { it.volume }
        
        // Simplified validation - in real implementation would check actual aircraft specs
        return if (totalWeight <= 50000 && totalVolume <= 500) {
            SuitabilityResult.Suitable(0.9, "Aircraft suitable for cargo requirements")
        } else {
            SuitabilityResult.Unsuitable("Cargo exceeds aircraft capacity")
        }
    }
    
    private fun findOptimalWarehouseAllocation(
        warehouseId: String,
        requestedSpace: Double,
        requirements: StorageRequirements
    ): WarehouseAllocation? {
        // Simplified allocation - in real implementation would use warehouse layout optimization
        return WarehouseAllocation(
            warehouseId = warehouseId,
            zoneId = "ZONE-GEN", // Default to general zone
            allocatedSpace = requestedSpace,
            location = AllocationLocation(0, 0, 0, 0) // Simplified coordinates
        )
    }
    
    private fun calculateRouteDuration(route: TradeRoute): Int {
        // Simplified calculation based on distance
        return (route.totalDistance / 20).toInt() // Assume 20 km/h average speed
    }
    
    private fun calculateRouteRevenue(shipId: String, route: TradeRoute): Double {
        // Simplified revenue calculation
        return route.estimatedRevenue
    }
    
    private fun calculateFlightDuration(cargoJob: CargoJob): Int {
        // Simplified flight duration calculation
        return (cargoJob.distance / 800).toInt() // Assume 800 km/h average speed
    }
    
    private fun calculateStorageRevenue(space: Double, requirements: StorageRequirements): Double {
        val baseRate = 5.0 // $5 per cubic meter per month
        val multiplier = when {
            requirements.requiresTemperatureControl -> 2.0
            requirements.isHazmat -> 1.8
            requirements.isHighValue -> 1.5
            else -> 1.0
        }
        return space * baseRate * multiplier
    }
    
    private fun optimizeForRevenue(assignments: List<AssetAssignment>): List<OptimizationSuggestion> {
        val suggestions = mutableListOf<OptimizationSuggestion>()
        
        // Find underutilized high-revenue potential assets
        assignments.forEach { assignment ->
            val currentRevenue = assignment.estimatedRevenue
            val potentialRevenue = currentRevenue * 1.2 // Assume 20% improvement possible
            
            if (potentialRevenue > currentRevenue * 1.1) {
                suggestions.add(
                    OptimizationSuggestion(
                        type = SuggestionType.REASSIGN,
                        assetId = assignment.assetId,
                        currentAssignmentId = assignment.id,
                        suggestedAction = "Consider reassigning to higher-revenue route",
                        expectedImprovement = potentialRevenue - currentRevenue,
                        confidence = 0.7
                    )
                )
            }
        }
        
        return suggestions
    }
    
    private fun optimizeForCost(assignments: List<AssetAssignment>): List<OptimizationSuggestion> {
        // Implement cost optimization logic
        return emptyList()
    }
    
    private fun optimizeForUtilization(assignments: List<AssetAssignment>): List<OptimizationSuggestion> {
        // Implement utilization optimization logic
        return emptyList()
    }
    
    private fun optimizeForSpeed(assignments: List<AssetAssignment>): List<OptimizationSuggestion> {
        // Implement speed optimization logic
        return emptyList()
    }
    
    private fun optimizeBalanced(assignments: List<AssetAssignment>): List<OptimizationSuggestion> {
        // Implement balanced optimization combining multiple criteria
        val revenueSuggestions = optimizeForRevenue(assignments)
        // Weight and combine suggestions from different optimization approaches
        return revenueSuggestions // Simplified for now
    }
    
    private fun calculatePotentialImprovement(suggestions: List<OptimizationSuggestion>): Double {
        return suggestions.sumOf { it.expectedImprovement }
    }
    
    private fun getShipRecommendations(shipId: String): List<AssignmentRecommendation> {
        // Analyze available routes and recommend best assignments
        return routeRegistry.values.map { route ->
            AssignmentRecommendation(
                targetId = route.id,
                targetType = "Trade Route",
                targetName = route.name,
                suitabilityScore = 0.8,
                expectedRevenue = route.estimatedRevenue,
                expectedDuration = calculateRouteDuration(route),
                riskLevel = RiskLevel.LOW,
                recommendation = "High-revenue route with good port facilities"
            )
        }.sortedByDescending { it.suitabilityScore }
    }
    
    private fun getAircraftRecommendations(aircraftId: String): List<AssignmentRecommendation> {
        // Analyze available cargo jobs
        return cargoQueue.values.filter { it.assignedAircraftId == null }.map { job ->
            AssignmentRecommendation(
                targetId = job.id,
                targetType = "Cargo Job",
                targetName = "Cargo delivery to ${job.destination}",
                suitabilityScore = 0.75,
                expectedRevenue = job.totalValue,
                expectedDuration = calculateFlightDuration(job),
                riskLevel = if (job.cargoItems.any { it.isHazmat }) RiskLevel.HIGH else RiskLevel.LOW,
                recommendation = "Time-sensitive cargo with good profit margin"
            )
        }.sortedByDescending { it.expectedRevenue }
    }
    
    private fun getWarehouseRecommendations(warehouseId: String): List<AssignmentRecommendation> {
        // Analyze storage demand and recommend optimal allocation strategies
        return emptyList() // Simplified for now
    }
    
    private fun calculateAverageUtilization(): Double {
        val activeAssignments = assignmentRegistry.values.filter { it.status == AssignmentStatus.ACTIVE }
        return if (activeAssignments.isNotEmpty()) {
            activeAssignments.mapNotNull { assignment ->
                // Get utilization based on assignment type
                when (assignment.assignmentType) {
                    AssignmentType.ROUTE -> 0.8 // Assume 80% utilization for route assignments
                    AssignmentType.CARGO_JOB -> 0.9 // Higher utilization for specific cargo jobs
                    AssignmentType.STORAGE -> 0.6 // Variable storage utilization
                }
            }.average()
        } else 0.0
    }
    
    private fun recordAssignment(assetId: String, assignment: AssetAssignment) {
        val record = AssignmentRecord(
            assignmentId = assignment.id,
            assetId = assetId,
            assignmentType = assignment.assignmentType,
            startDate = assignment.startDate,
            endDate = assignment.endDate,
            success = assignment.status == AssignmentStatus.COMPLETED,
            revenue = assignment.estimatedRevenue
        )
        
        assignmentHistory.getOrPut(assetId) { mutableListOf() }.add(record)
    }
    
    private fun updateAssignmentState() {
        _assignments.value = assignmentRegistry.toMap()
    }
}

// Data classes for assignment system
data class AssetAssignment(
    val id: String,
    val assetId: String,
    val assetType: AssetType,
    val assignmentType: AssignmentType,
    val targetId: String,
    val startDate: LocalDateTime,
    val priority: AssignmentPriority,
    var status: AssignmentStatus,
    val estimatedDuration: Int?, // hours
    val estimatedRevenue: Double,
    var endDate: LocalDateTime? = null,
    var actualRevenue: Double? = null,
    var unassignmentReason: UnassignmentReason? = null
)

data class TradeRoute(
    val id: String,
    val name: String,
    val originPort: String,
    val destinationPort: String,
    val intermediateStops: List<String>,
    val totalDistance: Double, // nautical miles
    val estimatedRevenue: Double,
    val cargoTypes: List<CargoType>,
    val seasonalFactors: Map<String, Double>,
    val riskFactors: List<String>
)

data class CargoJob(
    val id: String,
    val origin: String,
    val destination: String,
    val cargoItems: List<AirCargo>,
    val deadline: LocalDateTime,
    val totalValue: Double,
    val distance: Double, // km
    val priority: CargoPriority,
    var assignedAircraftId: String? = null
)

data class WarehouseAllocation(
    val warehouseId: String,
    val zoneId: String,
    val allocatedSpace: Double,
    val location: AllocationLocation
)

data class AllocationLocation(
    val section: Int,
    val row: Int,
    val column: Int,
    val level: Int
)

data class AssignmentRecord(
    val assignmentId: String,
    val assetId: String,
    val assignmentType: AssignmentType,
    val startDate: LocalDateTime,
    val endDate: LocalDateTime?,
    val success: Boolean,
    val revenue: Double
)

data class RoutePerformanceMetrics(
    val routeId: String,
    var totalTrips: Int,
    var averageRevenue: Double,
    var averageDuration: Double,
    var utilizationRate: Double,
    var lastUpdated: LocalDateTime
)

data class OptimizationResult(
    val criteria: OptimizationCriteria,
    val suggestions: List<OptimizationSuggestion>,
    val potentialImprovement: Double,
    val timestamp: LocalDateTime
)

data class OptimizationSuggestion(
    val type: SuggestionType,
    val assetId: String,
    val currentAssignmentId: String?,
    val suggestedAction: String,
    val expectedImprovement: Double,
    val confidence: Double
)

data class AssignmentRecommendation(
    val targetId: String,
    val targetType: String,
    val targetName: String,
    val suitabilityScore: Double,
    val expectedRevenue: Double,
    val expectedDuration: Int,
    val riskLevel: RiskLevel,
    val recommendation: String
)

data class AssignmentStatistics(
    val totalActiveAssignments: Int,
    val assignmentsByType: Map<AssignmentType, Int>,
    val averageUtilization: Double,
    val totalRevenue: Double,
    val totalAssetsCovered: Int
)

// Enums
enum class AssignmentType {
    ROUTE, CARGO_JOB, STORAGE, MAINTENANCE, STANDBY
}

enum class AssignmentStatus {
    PLANNED, ACTIVE, COMPLETED, CANCELLED, FAILED
}

enum class AssignmentPriority {
    LOW, NORMAL, HIGH, CRITICAL
}

enum class OptimizationCriteria {
    MAXIMIZE_REVENUE, MINIMIZE_COST, MAXIMIZE_UTILIZATION, MINIMIZE_TRANSIT_TIME, BALANCED
}

enum class SuggestionType {
    REASSIGN, OPTIMIZE_ROUTE, ADJUST_CAPACITY, SCHEDULE_MAINTENANCE
}

enum class UnassignmentReason {
    COMPLETED, CANCELLED, MAINTENANCE_REQUIRED, ASSET_UNAVAILABLE, ROUTE_CHANGED
}

enum class RiskLevel {
    LOW, MEDIUM, HIGH, CRITICAL
}

// Sealed classes for results
sealed class SuitabilityResult {
    data class Suitable(val confidence: Double, val reason: String) : SuitabilityResult()
    data class Unsuitable(val reason: String) : SuitabilityResult()
}

sealed class ShipAssignmentResult {
    data class Success(val assignmentId: String) : ShipAssignmentResult()
    object RouteNotFound : ShipAssignmentResult()
    data class Unsuitable(val reason: String) : ShipAssignmentResult()
}

sealed class AircraftAssignmentResult {
    data class Success(val assignmentId: String) : AircraftAssignmentResult()
    object CargoJobNotFound : AircraftAssignmentResult()
    data class Unsuitable(val reason: String) : AircraftAssignmentResult()
}

sealed class WarehouseAssignmentResult {
    data class Success(val assignmentId: String, val zoneId: String) : WarehouseAssignmentResult()
    object InsufficientSpace : WarehouseAssignmentResult()
    data class UnsuitableRequirements(val reason: String) : WarehouseAssignmentResult()
}

sealed class UnassignmentResult {
    object Success : UnassignmentResult()
    object AssignmentNotFound : UnassignmentResult()
    object InvalidStatus : UnassignmentResult()
}