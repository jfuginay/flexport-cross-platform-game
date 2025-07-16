package com.flexport.assets.models

import com.flexport.economics.models.AssetCondition
import java.time.LocalDateTime
import java.util.*

/**
 * Core asset interface with enhanced capabilities
 */
interface FlexPortAsset {
    val id: String
    val ownerId: String
    val name: String
    val assetType: AssetType
    val purchaseDate: LocalDateTime
    val purchasePrice: Double
    var currentValue: Double
    var condition: AssetCondition
    var isOperational: Boolean
    var location: AssetLocation
    var maintenanceSchedule: MaintenanceSchedule
    val specifications: AssetSpecifications
    
    fun calculateDepreciation(): Double
    fun calculateMaintenanceCost(): Double
    fun calculateOperatingCost(): Double
    fun getUtilizationRate(): Double
    fun canOperate(): Boolean
}

/**
 * Enhanced asset types for FlexPort
 */
enum class AssetType {
    CONTAINER_SHIP,
    BULK_CARRIER,
    TANKER,
    CARGO_AIRCRAFT,
    PASSENGER_AIRCRAFT,
    WAREHOUSE,
    DISTRIBUTION_CENTER,
    PORT_TERMINAL,
    TRUCK,
    RAIL_CAR,
    CRANE,
    FORKLIFT
}

/**
 * Asset location with detailed positioning
 */
data class AssetLocation(
    val latitude: Double,
    val longitude: Double,
    val portId: String? = null,
    val warehouseId: String? = null,
    val airportId: String? = null,
    val regionId: String,
    val countryCode: String,
    val isInTransit: Boolean = false,
    val destinationId: String? = null,
    val estimatedArrival: LocalDateTime? = null
)

/**
 * Base specifications interface
 */
interface AssetSpecifications {
    val manufacturer: String
    val model: String
    val yearBuilt: Int
    val serialNumber: String
}

/**
 * Container ship with realistic specifications
 */
data class ContainerShip(
    override val id: String,
    override val ownerId: String,
    override val name: String,
    override val purchaseDate: LocalDateTime,
    override val purchasePrice: Double,
    override var currentValue: Double,
    override var condition: AssetCondition,
    override var isOperational: Boolean,
    override var location: AssetLocation,
    override var maintenanceSchedule: MaintenanceSchedule,
    override val specifications: ContainerShipSpecs,
    
    // Ship-specific properties
    var currentCargo: MutableList<CargoContainer> = mutableListOf(),
    var assignedRoute: String? = null,
    var crewAssignment: CrewAssignment? = null,
    val fuelTank: FuelTank,
    var engineHours: Double = 0.0,
    var lastDryDock: LocalDateTime? = null
) : FlexPortAsset {
    
    override val assetType = AssetType.CONTAINER_SHIP
    
    override fun calculateDepreciation(): Double {
        val age = java.time.Period.between(purchaseDate.toLocalDate(), LocalDateTime.now().toLocalDate()).years
        val baseDepreciation = purchasePrice * 0.05 * age // 5% per year
        val conditionMultiplier = when (condition) {
            AssetCondition.EXCELLENT -> 0.8
            AssetCondition.GOOD -> 1.0
            AssetCondition.FAIR -> 1.3
            AssetCondition.POOR -> 1.8
            AssetCondition.NEEDS_REPAIR -> 2.5
        }
        return baseDepreciation * conditionMultiplier
    }
    
    override fun calculateMaintenanceCost(): Double {
        val baseCost = specifications.deadweightTonnage * 50.0 // $50 per DWT annually
        val conditionMultiplier = when (condition) {
            AssetCondition.EXCELLENT -> 0.7
            AssetCondition.GOOD -> 1.0
            AssetCondition.FAIR -> 1.5
            AssetCondition.POOR -> 2.2
            AssetCondition.NEEDS_REPAIR -> 3.5
        }
        val utilizationMultiplier = 0.5 + (getUtilizationRate() * 0.5)
        return baseCost * conditionMultiplier * utilizationMultiplier
    }
    
    override fun calculateOperatingCost(): Double {
        val fuelCost = (specifications.fuelConsumption * fuelTank.currentFuelPrice) * 
                      if (location.isInTransit) 24.0 else 8.0 // Transit vs port consumption
        val crewCost = crewAssignment?.getTotalDailyCost() ?: 0.0
        val portFees = if (!location.isInTransit && location.portId != null) {
            specifications.deadweightTonnage * 2.0 // $2 per DWT port fee
        } else 0.0
        return fuelCost + crewCost + portFees
    }
    
    override fun getUtilizationRate(): Double {
        val loadedContainers = currentCargo.size
        val totalCapacity = specifications.containerCapacity
        return if (totalCapacity > 0) loadedContainers.toDouble() / totalCapacity else 0.0
    }
    
    override fun canOperate(): Boolean {
        return isOperational && 
               condition != AssetCondition.NEEDS_REPAIR &&
               fuelTank.currentLevel > fuelTank.capacity * 0.1 &&
               crewAssignment?.isAdequate() == true
    }
    
    fun getCargoCapacityUtilization(): Double {
        val usedTEU = currentCargo.sumOf { it.teuSize }
        return usedTEU / specifications.containerCapacity
    }
    
    fun canLoadContainer(container: CargoContainer): Boolean {
        val currentTEU = currentCargo.sumOf { it.teuSize }
        return canOperate() && 
               (currentTEU + container.teuSize) <= specifications.containerCapacity &&
               (currentCargo.sumOf { it.weight } + container.weight) <= specifications.cargoCapacity
    }
}

/**
 * Container ship specifications
 */
data class ContainerShipSpecs(
    override val manufacturer: String,
    override val model: String,
    override val yearBuilt: Int,
    override val serialNumber: String,
    val deadweightTonnage: Double,
    val grossTonnage: Double,
    val length: Double, // meters
    val beam: Double, // meters
    val draft: Double, // meters
    val containerCapacity: Double, // TEU
    val cargoCapacity: Double, // metric tons
    val maxSpeed: Double, // knots
    val cruiseSpeed: Double, // knots
    val fuelConsumption: Double, // liters per hour at cruise
    val crewRequirements: CrewRequirements,
    val refrigeratedContainerSlots: Int,
    val hazmatCapability: Boolean,
    val iceClass: IceClass? = null
) : AssetSpecifications

/**
 * Cargo aircraft with detailed specifications
 */
data class CargoAircraft(
    override val id: String,
    override val ownerId: String,
    override val name: String,
    override val purchaseDate: LocalDateTime,
    override val purchasePrice: Double,
    override var currentValue: Double,
    override var condition: AssetCondition,
    override var isOperational: Boolean,
    override var location: AssetLocation,
    override var maintenanceSchedule: MaintenanceSchedule,
    override val specifications: CargoAircraftSpecs,
    
    // Aircraft-specific properties
    var currentCargo: MutableList<AirCargo> = mutableListOf(),
    var assignedRoute: String? = null,
    var crewAssignment: FlightCrew? = null,
    val fuelTank: AircraftFuelTank,
    var flightHours: Double = 0.0,
    var cycleCount: Int = 0,
    var lastMajorInspection: LocalDateTime? = null
) : FlexPortAsset {
    
    override val assetType = AssetType.CARGO_AIRCRAFT
    
    override fun calculateDepreciation(): Double {
        val age = java.time.Period.between(purchaseDate.toLocalDate(), LocalDateTime.now().toLocalDate()).years
        val baseDepreciation = purchasePrice * 0.07 * age // 7% per year for aircraft
        val flightHoursMultiplier = 1.0 + (flightHours / 100000.0) // Additional depreciation for high hours
        val conditionMultiplier = when (condition) {
            AssetCondition.EXCELLENT -> 0.8
            AssetCondition.GOOD -> 1.0
            AssetCondition.FAIR -> 1.4
            AssetCondition.POOR -> 2.0
            AssetCondition.NEEDS_REPAIR -> 3.0
        }
        return baseDepreciation * flightHoursMultiplier * conditionMultiplier
    }
    
    override fun calculateMaintenanceCost(): Double {
        val baseCost = specifications.maxTakeoffWeight * 100.0 // $100 per kg MTOW annually
        val flightHoursMultiplier = 1.0 + (flightHours / 50000.0)
        val cycleMultiplier = 1.0 + (cycleCount / 100000.0)
        return baseCost * flightHoursMultiplier * cycleMultiplier
    }
    
    override fun calculateOperatingCost(): Double {
        val fuelCost = specifications.fuelConsumptionPerHour * fuelTank.currentFuelPrice * 8.0 // 8 hours average
        val crewCost = crewAssignment?.getTotalDailyCost() ?: 0.0
        val landingFees = if (location.airportId != null) 5000.0 else 0.0
        return fuelCost + crewCost + landingFees
    }
    
    override fun getUtilizationRate(): Double {
        val usedWeight = currentCargo.sumOf { it.weight }
        return usedWeight / specifications.maxCargoWeight
    }
    
    override fun canOperate(): Boolean {
        return isOperational &&
               condition != AssetCondition.NEEDS_REPAIR &&
               fuelTank.currentLevel > fuelTank.capacity * 0.15 &&
               crewAssignment?.isAdequate() == true &&
               flightHours < specifications.maxFlightHours
    }
}

/**
 * Aircraft specifications
 */
data class CargoAircraftSpecs(
    override val manufacturer: String,
    override val model: String,
    override val yearBuilt: Int,
    override val serialNumber: String,
    val maxTakeoffWeight: Double, // kg
    val maxCargoWeight: Double, // kg
    val cargoVolume: Double, // cubic meters
    val maxRange: Double, // km
    val cruiseSpeed: Double, // km/h
    val serviceceiling: Double, // meters
    val fuelCapacity: Double, // liters
    val fuelConsumptionPerHour: Double, // liters/hour
    val crewRequirements: FlightCrewRequirements,
    val maxFlightHours: Double,
    val cargoCompartments: List<CargoCompartment>,
    val hazmatCapability: Boolean,
    val temperatureControlled: Boolean
) : AssetSpecifications

/**
 * Warehouse facility
 */
data class Warehouse(
    override val id: String,
    override val ownerId: String,
    override val name: String,
    override val purchaseDate: LocalDateTime,
    override val purchasePrice: Double,
    override var currentValue: Double,
    override var condition: AssetCondition,
    override var isOperational: Boolean,
    override var location: AssetLocation,
    override var maintenanceSchedule: MaintenanceSchedule,
    override val specifications: WarehouseSpecs,
    
    // Warehouse-specific properties
    var currentInventory: MutableList<InventoryItem> = mutableListOf(),
    var staffing: WarehouseStaffing? = null,
    val zones: List<StorageZone>,
    var equipmentAssets: MutableList<WarehouseEquipment> = mutableListOf()
) : FlexPortAsset {
    
    override val assetType = AssetType.WAREHOUSE
    
    override fun calculateDepreciation(): Double {
        val age = java.time.Period.between(purchaseDate.toLocalDate(), LocalDateTime.now().toLocalDate()).years
        return purchasePrice * 0.02 * age // 2% per year for real estate
    }
    
    override fun calculateMaintenanceCost(): Double {
        val baseCost = specifications.floorArea * 20.0 // $20 per sqm annually
        val facilityMultiplier = when {
            specifications.temperatureControlled -> 1.5
            specifications.automationLevel == AutomationLevel.HIGH -> 1.8
            else -> 1.0
        }
        return baseCost * facilityMultiplier
    }
    
    override fun calculateOperatingCost(): Double {
        val utilityCost = specifications.floorArea * 2.0 // $2 per sqm monthly
        val staffCost = staffing?.getTotalMonthlyCost() ?: 0.0
        val equipmentCost = equipmentAssets.sumOf { it.monthlyOperatingCost }
        return (utilityCost + equipmentCost) * 30 + staffCost // Daily cost
    }
    
    override fun getUtilizationRate(): Double {
        val usedVolume = currentInventory.sumOf { it.volume }
        return usedVolume / specifications.storageVolume
    }
    
    override fun canOperate(): Boolean {
        return isOperational &&
               condition != AssetCondition.NEEDS_REPAIR &&
               staffing?.isAdequate() == true
    }
    
    fun getAvailableCapacity(): Double {
        val usedVolume = currentInventory.sumOf { it.volume }
        return specifications.storageVolume - usedVolume
    }
    
    fun canStoreItem(item: InventoryItem): Boolean {
        return canOperate() &&
               getAvailableCapacity() >= item.volume &&
               zones.any { it.canAccommodate(item) }
    }
}

/**
 * Warehouse specifications
 */
data class WarehouseSpecs(
    override val manufacturer: String = "Custom Build",
    override val model: String,
    override val yearBuilt: Int,
    override val serialNumber: String,
    val floorArea: Double, // square meters
    val storageVolume: Double, // cubic meters
    val ceilingHeight: Double, // meters
    val loadingDocks: Int,
    val temperatureControlled: Boolean,
    val temperatureRange: TemperatureRange? = null,
    val securityLevel: SecurityLevel,
    val automationLevel: AutomationLevel,
    val fireSuppressionSystem: Boolean,
    val powerBackup: Boolean,
    val rackingSystem: RackingSystem
) : AssetSpecifications

/**
 * Supporting data classes
 */
data class CargoContainer(
    val id: String,
    val teuSize: Double, // 1.0 for 20ft, 2.0 for 40ft
    val weight: Double, // metric tons
    val cargoType: CargoType,
    val origin: String,
    val destination: String,
    val isHazmat: Boolean = false,
    val isRefrigerated: Boolean = false,
    val temperature: Double? = null
)

data class AirCargo(
    val id: String,
    val weight: Double, // kg
    val volume: Double, // cubic meters
    val cargoType: CargoType,
    val priority: CargoPriority,
    val isHazmat: Boolean = false,
    val temperatureControlled: Boolean = false
)

data class InventoryItem(
    val id: String,
    val sku: String,
    val quantity: Int,
    val volume: Double, // cubic meters
    val weight: Double, // kg
    val storageRequirements: StorageRequirements
)

data class FuelTank(
    val capacity: Double, // liters
    var currentLevel: Double, // liters
    val currentFuelPrice: Double // per liter
)

data class AircraftFuelTank(
    val capacity: Double, // liters
    var currentLevel: Double, // liters
    val currentFuelPrice: Double, // per liter
    val fuelType: AviationFuelType
)

data class CrewAssignment(
    val captain: CrewMember,
    val officers: List<CrewMember>,
    val engineers: List<CrewMember>,
    val crew: List<CrewMember>
) {
    fun getTotalDailyCost(): Double = 
        (listOf(captain) + officers + engineers + crew).sumOf { it.dailyWage }
    
    fun isAdequate(): Boolean = 
        officers.isNotEmpty() && engineers.isNotEmpty() && crew.size >= 8
}

data class FlightCrew(
    val captain: CrewMember,
    val firstOfficer: CrewMember,
    val engineer: CrewMember? = null,
    val loadmaster: CrewMember
) {
    fun getTotalDailyCost(): Double = 
        listOfNotNull(captain, firstOfficer, engineer, loadmaster).sumOf { it.dailyWage }
    
    fun isAdequate(): Boolean = true // Basic crew is adequate
}

data class WarehouseStaffing(
    val manager: CrewMember,
    val supervisors: List<CrewMember>,
    val operators: List<CrewMember>,
    val guards: List<CrewMember>
) {
    fun getTotalMonthlyCost(): Double = 
        (listOf(manager) + supervisors + operators + guards).sumOf { it.dailyWage * 30 }
    
    fun isAdequate(): Boolean = 
        supervisors.isNotEmpty() && operators.size >= 5
}

data class CrewMember(
    val id: String,
    val name: String,
    val role: CrewRole,
    val certification: String,
    val dailyWage: Double,
    val experience: Int // years
)

data class MaintenanceSchedule(
    var lastMaintenance: LocalDateTime?,
    var nextScheduledMaintenance: LocalDateTime,
    val maintenanceInterval: Int, // days
    val maintenanceType: MaintenanceType
)

data class StorageZone(
    val id: String,
    val name: String,
    val capacity: Double, // cubic meters
    val zoneType: ZoneType,
    val temperatureControlled: Boolean = false,
    val securityLevel: SecurityLevel
) {
    fun canAccommodate(item: InventoryItem): Boolean {
        return when (zoneType) {
            ZoneType.GENERAL -> !item.storageRequirements.requiresSpecialHandling
            ZoneType.HAZMAT -> item.storageRequirements.isHazmat
            ZoneType.REFRIGERATED -> item.storageRequirements.requiresTemperatureControl
            ZoneType.HIGH_VALUE -> item.storageRequirements.isHighValue
        }
    }
}

data class WarehouseEquipment(
    val id: String,
    val type: EquipmentType,
    val model: String,
    val monthlyOperatingCost: Double,
    val condition: AssetCondition
)

data class CargoCompartment(
    val id: String,
    val volume: Double, // cubic meters
    val maxWeight: Double, // kg
    val temperatureControlled: Boolean
)

data class StorageRequirements(
    val requiresTemperatureControl: Boolean = false,
    val temperatureRange: TemperatureRange? = null,
    val isHazmat: Boolean = false,
    val requiresSpecialHandling: Boolean = false,
    val isHighValue: Boolean = false
)

data class TemperatureRange(
    val minTemperature: Double, // Celsius
    val maxTemperature: Double, // Celsius
    val humidity: Double? = null // percentage
)

data class CrewRequirements(
    val minimumCrew: Int,
    val recommendedCrew: Int,
    val officerPositions: Int,
    val engineerPositions: Int
)

data class FlightCrewRequirements(
    val pilots: Int,
    val engineers: Int,
    val loadmasters: Int
)

// Enums
enum class CargoType {
    GENERAL, BULK, LIQUID, HAZMAT, PERISHABLE, AUTOMOTIVE, ELECTRONICS, TEXTILES
}

enum class CargoPriority {
    LOW, STANDARD, HIGH, URGENT
}

enum class CrewRole {
    CAPTAIN, FIRST_OFFICER, CHIEF_ENGINEER, ENGINEER, OFFICER, SAILOR, 
    LOADMASTER, WAREHOUSE_MANAGER, SUPERVISOR, OPERATOR, SECURITY_GUARD
}

enum class MaintenanceType {
    ROUTINE, SCHEDULED, PREVENTIVE, EMERGENCY, OVERHAUL
}

enum class SecurityLevel {
    BASIC, MEDIUM, HIGH, MAXIMUM
}

enum class AutomationLevel {
    MANUAL, SEMI_AUTOMATED, AUTOMATED, HIGH
}

enum class ZoneType {
    GENERAL, HAZMAT, REFRIGERATED, HIGH_VALUE
}

enum class EquipmentType {
    FORKLIFT, CRANE, CONVEYOR, SORTER, SCANNER
}

enum class IceClass {
    NONE, LIGHT, MEDIUM, HEAVY, POLAR
}

enum class RackingSystem {
    SELECTIVE, DRIVE_IN, PUSH_BACK, PALLET_FLOW, CANTILEVER
}

enum class AviationFuelType {
    JET_A, JET_A1, JP_8, AVGAS
}