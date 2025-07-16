package com.flexport.assets.models

import com.flexport.economics.models.AssetCondition
import kotlinx.serialization.Serializable
import java.util.*

/**
 * Core asset model representing any owned asset in the logistics system
 */
@Serializable
data class Asset(
    val id: String = UUID.randomUUID().toString(),
    val entityId: String? = null, // ECS entity ID reference
    val name: String,
    val type: AssetType,
    val ownerId: String,
    val purchasePrice: Double,
    val currentValue: Double,
    val condition: AssetCondition,
    val location: AssetLocation,
    val specifications: AssetSpecifications,
    val operationalData: OperationalData,
    val maintenanceData: MaintenanceData,
    val isOperational: Boolean = true,
    val acquisitionDate: Long = System.currentTimeMillis(),
    val metadata: Map<String, String> = emptyMap()
)

/**
 * Location information for an asset
 */
@Serializable
data class AssetLocation(
    val latitude: Double? = null,
    val longitude: Double? = null,
    val portId: String? = null,
    val warehouseId: String? = null,
    val address: String? = null,
    val locationType: LocationType
)

@Serializable
enum class LocationType {
    AT_SEA,
    IN_PORT,
    IN_TRANSIT,
    AT_WAREHOUSE,
    AT_FACILITY,
    UNKNOWN
}

/**
 * Asset specifications based on type
 */
@Serializable
sealed class AssetSpecifications {
    @Serializable
    data class ShipSpecifications(
        val capacity: Int, // TEU for containers, tons for bulk/tanker
        val maxSpeed: Double, // knots
        val fuelCapacity: Double, // tons
        val length: Double, // meters
        val beam: Double, // meters
        val draft: Double, // meters
        val dwt: Double, // deadweight tonnage
        val manufacturer: String,
        val model: String,
        val yearBuilt: Int,
        val imo: String? = null, // International Maritime Organization number
        val flag: String? = null
    ) : AssetSpecifications()
    
    @Serializable
    data class AircraftSpecifications(
        val cargoCapacity: Double, // kg
        val passengerCapacity: Int,
        val maxRange: Double, // km
        val cruiseSpeed: Double, // km/h
        val maxAltitude: Double, // meters
        val fuelCapacity: Double, // liters
        val manufacturer: String,
        val model: String,
        val yearBuilt: Int,
        val registration: String? = null
    ) : AssetSpecifications()
    
    @Serializable
    data class WarehouseSpecifications(
        val totalArea: Double, // square meters
        val storageVolume: Double, // cubic meters
        val loadingDocks: Int,
        val rackingCapacity: Int, // pallet positions
        val temperatureControlled: Boolean,
        val hazmatCertified: Boolean,
        val securityLevel: String,
        val yearBuilt: Int
    ) : AssetSpecifications()
    
    @Serializable
    data class VehicleSpecifications(
        val payloadCapacity: Double, // tons
        val maxRange: Double, // km
        val fuelType: String,
        val fuelCapacity: Double, // liters
        val manufacturer: String,
        val model: String,
        val yearBuilt: Int,
        val licensePlate: String? = null,
        val axles: Int = 2
    ) : AssetSpecifications()
    
    @Serializable
    data class EquipmentSpecifications(
        val liftingCapacity: Double? = null, // tons
        val reachHeight: Double? = null, // meters
        val operatingWeight: Double, // kg
        val powerType: String, // electric, diesel, etc.
        val manufacturer: String,
        val model: String,
        val yearBuilt: Int,
        val serialNumber: String? = null
    ) : AssetSpecifications()
    
    @Serializable
    data class PortTerminalSpecifications(
        val totalArea: Double, // hectares
        val berthLength: Double, // meters
        val maxDraft: Double, // meters
        val craneCapacity: Int, // number of cranes
        val storageCapacity: Int, // TEU or tons
        val annualThroughput: Double, // TEU or tons
        val gateCapacity: Int // trucks per hour
    ) : AssetSpecifications()
}

/**
 * Operational data for tracking asset performance
 */
@Serializable
data class OperationalData(
    val utilizationRate: Double = 0.0, // percentage
    val totalOperatingHours: Double = 0.0,
    val totalDistance: Double = 0.0, // km or nautical miles
    val totalCargoMoved: Double = 0.0, // tons or TEU
    val averageSpeed: Double = 0.0,
    val fuelConsumption: Double = 0.0, // per hour or per km
    val revenue: Double = 0.0,
    val operatingCosts: Double = 0.0,
    val lastOperationalCheck: Long = System.currentTimeMillis()
)

/**
 * Maintenance tracking data
 */
@Serializable
data class MaintenanceData(
    val lastMaintenanceDate: Long = System.currentTimeMillis(),
    val nextScheduledMaintenance: Long = System.currentTimeMillis() + 90 * 24 * 60 * 60 * 1000L, // 90 days
    val maintenanceHistory: List<MaintenanceRecord> = emptyList(),
    val totalMaintenanceCost: Double = 0.0,
    val currentMaintenanceContract: MaintenanceContract? = null
)

@Serializable
data class MaintenanceRecord(
    val date: Long,
    val type: MaintenanceType,
    val description: String,
    val cost: Double,
    val performedBy: String,
    val hoursOutOfService: Double = 0.0
)

@Serializable
enum class MaintenanceType {
    ROUTINE,
    SCHEDULED,
    EMERGENCY,
    INSPECTION,
    OVERHAUL,
    UPGRADE
}

@Serializable
data class MaintenanceContract(
    val contractId: String,
    val provider: String,
    val startDate: Long,
    val endDate: Long,
    val monthlyCost: Double,
    val coverageType: String
)

/**
 * Extension functions for asset operations
 */
fun Asset.getDailyOperatingCost(): Double {
    return when (type) {
        AssetType.CONTAINER_SHIP, AssetType.BULK_CARRIER, AssetType.TANKER -> {
            val baseRate = currentValue * 0.0001 // 0.01% of value per day
            val conditionMultiplier = when (condition) {
                AssetCondition.EXCELLENT -> 1.0
                AssetCondition.GOOD -> 1.2
                AssetCondition.FAIR -> 1.5
                AssetCondition.POOR -> 2.0
            }
            baseRate * conditionMultiplier
        }
        AssetType.WAREHOUSE, AssetType.DISTRIBUTION_CENTER -> {
            currentValue * 0.00005 // Lower operating cost for facilities
        }
        else -> currentValue * 0.00008
    }
}

fun Asset.getMaintenanceCostPerDay(): Double {
    val baseMaintenanceCost = currentValue * 0.00002 // 0.002% of value per day
    val conditionMultiplier = when (condition) {
        AssetCondition.EXCELLENT -> 0.5
        AssetCondition.GOOD -> 1.0
        AssetCondition.FAIR -> 1.8
        AssetCondition.POOR -> 3.0
    }
    return baseMaintenanceCost * conditionMultiplier
}

fun Asset.getTotalDailyCost(): Double {
    return getDailyOperatingCost() + getMaintenanceCostPerDay()
}

fun Asset.getDepreciatedValue(currentTime: Long = System.currentTimeMillis()): Double {
    val ageInYears = (currentTime - acquisitionDate) / (365.25 * 24 * 60 * 60 * 1000L)
    val depreciationRate = when (type) {
        AssetType.CONTAINER_SHIP, AssetType.BULK_CARRIER, AssetType.TANKER -> 0.04 // 4% per year
        AssetType.CARGO_AIRCRAFT, AssetType.PASSENGER_AIRCRAFT -> 0.05 // 5% per year
        AssetType.WAREHOUSE, AssetType.DISTRIBUTION_CENTER -> 0.02 // 2% per year
        AssetType.TRUCK, AssetType.RAIL_CAR -> 0.08 // 8% per year
        else -> 0.06 // 6% per year for equipment
    }
    
    val depreciatedValue = purchasePrice * Math.pow(1 - depreciationRate, ageInYears)
    return maxOf(depreciatedValue, purchasePrice * 0.1) // Minimum 10% of purchase price
}