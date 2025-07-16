package com.flexport.map.models

import com.flexport.economics.models.Commodity
import com.flexport.economics.models.CommodityType
import java.time.LocalDateTime
import java.util.*

/**
 * Represents a trade route between ports
 */
data class TradeRoute(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val origin: Port,
    val destination: Port,
    val waypoints: List<Port> = emptyList(),
    val cargo: List<CargoManifest>,
    val vessel: Vessel,
    val schedule: RouteSchedule,
    val status: RouteStatus,
    val createdAt: LocalDateTime = LocalDateTime.now(),
    val lastUpdated: LocalDateTime = LocalDateTime.now(),
    val performance: RoutePerformance? = null,
    val restrictions: Set<RouteRestriction> = emptySet()
) {
    
    /**
     * Get all ports in order (origin -> waypoints -> destination)
     */
    val allPorts: List<Port>
        get() = listOf(origin) + waypoints + listOf(destination)
    
    /**
     * Calculate total route distance in nautical miles
     */
    fun getTotalDistance(): Double {
        var totalDistance = 0.0
        val ports = allPorts
        
        for (i in 0 until ports.size - 1) {
            totalDistance += ports[i].position.distanceTo(ports[i + 1].position)
        }
        
        return totalDistance
    }
    
    /**
     * Calculate estimated transit time in hours
     */
    fun getEstimatedTransitTime(): Double {
        val distance = getTotalDistance()
        return distance / vessel.cruisingSpeed
    }
    
    /**
     * Get total cargo value
     */
    fun getTotalCargoValue(): Double {
        return cargo.sumOf { manifest ->
            manifest.commodity.baseValue * manifest.quantity
        }
    }
    
    /**
     * Check if route can accommodate additional cargo
     */
    fun canAccommodateCargo(commodity: Commodity, quantity: Double): Boolean {
        val currentWeight = cargo.sumOf { it.getTotalWeight() }
        val currentVolume = cargo.sumOf { it.getTotalVolume() }
        
        val additionalWeight = commodity.weight * quantity
        val additionalVolume = commodity.volume * quantity
        
        return (currentWeight + additionalWeight <= vessel.maxCargoWeight) &&
               (currentVolume + additionalVolume <= vessel.maxCargoVolume)
    }
    
    /**
     * Validate if route is operationally feasible
     */
    fun validateRoute(): List<ValidationIssue> {
        val issues = mutableListOf<ValidationIssue>()
        
        // Check if all ports can handle the vessel
        allPorts.forEach { port ->
            if (vessel.draft > port.infrastructure.waterDepth) {
                issues.add(ValidationIssue.INSUFFICIENT_WATER_DEPTH(port.name, vessel.draft, port.infrastructure.waterDepth))
            }
            
            if (vessel.length > port.infrastructure.berthLength / 10) { // Assuming multiple berths
                issues.add(ValidationIssue.INSUFFICIENT_BERTH_LENGTH(port.name))
            }
        }
        
        // Check cargo compatibility with ports
        cargo.forEach { manifest ->
            allPorts.forEach { port ->
                if (!port.canHandle(manifest.commodity.type)) {
                    issues.add(ValidationIssue.UNSUPPORTED_COMMODITY(port.name, manifest.commodity.type))
                }
            }
        }
        
        // Check vessel cargo capacity
        val totalWeight = cargo.sumOf { it.getTotalWeight() }
        val totalVolume = cargo.sumOf { it.getTotalVolume() }
        
        if (totalWeight > vessel.maxCargoWeight) {
            issues.add(ValidationIssue.OVERWEIGHT_CARGO)
        }
        
        if (totalVolume > vessel.maxCargoVolume) {
            issues.add(ValidationIssue.OVERVOLUME_CARGO)
        }
        
        return issues
    }
}

/**
 * Cargo manifest for a specific commodity on a route
 */
data class CargoManifest(
    val commodity: Commodity,
    val quantity: Double,
    val loadingPort: Port,
    val dischargingPort: Port,
    val priority: CargoPriority = CargoPriority.NORMAL,
    val specialInstructions: String = "",
    val value: Double = commodity.baseValue * quantity
) {
    fun getTotalWeight(): Double = commodity.weight * quantity
    fun getTotalVolume(): Double = commodity.volume * quantity
}

/**
 * Priority levels for cargo
 */
enum class CargoPriority {
    LOW,
    NORMAL,
    HIGH,
    URGENT
}

/**
 * Vessel information for the route
 */
data class Vessel(
    val id: String,
    val name: String,
    val type: VesselType,
    val length: Double,        // meters
    val beam: Double,          // meters
    val draft: Double,         // meters
    val maxCargoWeight: Double, // tonnes
    val maxCargoVolume: Double, // cubic meters
    val cruisingSpeed: Double,  // knots
    val fuelConsumption: Double, // litres per nautical mile
    val maxTEU: Int? = null,   // For container ships
    val capabilities: Set<VesselCapability> = emptySet()
)

/**
 * Types of vessels
 */
enum class VesselType {
    CONTAINER_SHIP,
    BULK_CARRIER,
    TANKER,
    GENERAL_CARGO,
    RORO,               // Roll-on/Roll-off
    LNG_CARRIER,
    CHEMICAL_TANKER,
    REFRIGERATED_CARGO,
    HEAVY_LIFT,
    MULTI_PURPOSE
}

/**
 * Special capabilities of vessels
 */
enum class VesselCapability {
    HEAVY_LIFT,
    REFRIGERATED,
    HAZMAT,
    SELF_UNLOADING,
    ICE_CLASS,
    DYNAMIC_POSITIONING
}

/**
 * Route schedule information
 */
data class RouteSchedule(
    val departureTime: LocalDateTime,
    val estimatedArrivalTime: LocalDateTime,
    val frequency: RouteFrequency,
    val servicePattern: ServicePattern,
    val portSchedules: List<PortSchedule>
) {
    /**
     * Get next departure time based on frequency
     */
    fun getNextDeparture(after: LocalDateTime = LocalDateTime.now()): LocalDateTime {
        return when (frequency) {
            RouteFrequency.ONE_TIME -> departureTime
            RouteFrequency.WEEKLY -> {
                val daysDiff = java.time.temporal.ChronoUnit.DAYS.between(departureTime, after)
                val weeksToAdd = (daysDiff / 7) + 1
                departureTime.plusWeeks(weeksToAdd)
            }
            RouteFrequency.BIWEEKLY -> {
                val daysDiff = java.time.temporal.ChronoUnit.DAYS.between(departureTime, after)
                val periodsToAdd = (daysDiff / 14) + 1
                departureTime.plusWeeks(periodsToAdd * 2)
            }
            RouteFrequency.MONTHLY -> {
                val monthsDiff = java.time.temporal.ChronoUnit.MONTHS.between(departureTime, after)
                departureTime.plusMonths(monthsDiff + 1)
            }
        }
    }
}

/**
 * Schedule for individual port calls
 */
data class PortSchedule(
    val port: Port,
    val arrivalTime: LocalDateTime,
    val departureTime: LocalDateTime,
    val operationType: PortOperationType,
    val expectedDuration: Int // hours
)

/**
 * Types of port operations
 */
enum class PortOperationType {
    LOADING_ONLY,
    DISCHARGING_ONLY,
    LOADING_AND_DISCHARGING,
    BUNKERING,          // Fuel stop
    CREW_CHANGE,
    MAINTENANCE,
    TRANSIT             // No cargo operations
}

/**
 * Route frequency options
 */
enum class RouteFrequency {
    ONE_TIME,
    WEEKLY,
    BIWEEKLY,
    MONTHLY
}

/**
 * Service patterns for regular routes
 */
enum class ServicePattern {
    PENDULUM,       // A-B-A pattern
    ROUND_TRIP,     // A-B-C-A pattern
    BUTTERFLY,      // A-B-C-B-A pattern
    LOOP           // A-B-C-D-A pattern
}

/**
 * Current status of the route
 */
enum class RouteStatus {
    PLANNING,       // Route being planned
    APPROVED,       // Route approved but not started
    ACTIVE,         // Route in operation
    DELAYED,        // Route experiencing delays
    SUSPENDED,      // Temporarily suspended
    COMPLETED,      // One-time route completed
    CANCELLED       // Route cancelled
}

/**
 * Performance metrics for a route
 */
data class RoutePerformance(
    val totalTrips: Int,
    val onTimePerformance: Double,     // Percentage
    val averageTransitTime: Double,    // Hours
    val totalCargoHandled: Double,     // Tonnes
    val totalRevenue: Double,
    val totalCosts: Double,
    val averageUtilization: Double,    // Percentage of vessel capacity used
    val co2Emissions: Double,          // Tonnes of CO2
    val fuelConsumption: Double,       // Litres
    val lastPerformanceUpdate: LocalDateTime = LocalDateTime.now()
) {
    val profitMargin: Double
        get() = if (totalRevenue > 0) ((totalRevenue - totalCosts) / totalRevenue) * 100 else 0.0
    
    val efficiency: Double
        get() = (onTimePerformance * averageUtilization) / 100.0
}

/**
 * Restrictions that may apply to routes
 */
enum class RouteRestriction {
    SEASONAL_CLOSURE,
    WEATHER_DEPENDENT,
    POLITICAL_RESTRICTION,
    ENVIRONMENTAL_PROTECTION,
    TRAFFIC_CONTROL,
    SECURITY_CLEARANCE_REQUIRED,
    SPECIAL_PERMIT_REQUIRED,
    HAZMAT_PROHIBITED,
    SIZE_RESTRICTION
}

/**
 * Validation issues that can occur with routes
 */
sealed class ValidationIssue {
    data class INSUFFICIENT_WATER_DEPTH(val portName: String, val vesselDraft: Double, val portDepth: Double) : ValidationIssue()
    data class INSUFFICIENT_BERTH_LENGTH(val portName: String) : ValidationIssue()
    data class UNSUPPORTED_COMMODITY(val portName: String, val commodityType: CommodityType) : ValidationIssue()
    object OVERWEIGHT_CARGO : ValidationIssue()
    object OVERVOLUME_CARGO : ValidationIssue()
    data class MISSING_FACILITY(val portName: String, val facility: String) : ValidationIssue()
    data class RESTRICTED_ACCESS(val portName: String, val restriction: RouteRestriction) : ValidationIssue()
}