package com.flexport.map.models

import com.flexport.economics.models.CommodityType

/**
 * Represents a port in the world map
 */
data class Port(
    val id: String,
    val name: String,
    val position: GeographicalPosition,
    val country: String,
    val region: String,
    val portType: PortType,
    val size: PortSize,
    val capacity: PortCapacity,
    val specializations: Set<CommodityType>,
    val facilities: Set<PortFacility>,
    val operationalHours: OperationalHours,
    val weatherConditions: WeatherConditions,
    val politicalStability: PoliticalStability,
    val infrastructure: PortInfrastructure,
    val costs: PortCosts,
    val description: String
) {
    /**
     * Check if port can handle a specific commodity type
     */
    fun canHandle(commodityType: CommodityType): Boolean {
        return specializations.contains(commodityType) || 
               (specializations.isEmpty() && portType != PortType.SPECIALIZED)
    }
    
    /**
     * Calculate efficiency factor for handling operations
     */
    fun getEfficiencyFactor(): Double {
        var efficiency = 1.0
        
        // Size factor
        efficiency *= when (size) {
            PortSize.SMALL -> 0.8
            PortSize.MEDIUM -> 1.0
            PortSize.LARGE -> 1.2
            PortSize.MEGA -> 1.5
        }
        
        // Infrastructure factor
        efficiency *= infrastructure.overallRating
        
        // Political stability factor
        efficiency *= politicalStability.stabilityFactor
        
        return efficiency.coerceIn(0.1, 2.0)
    }
}

/**
 * Types of ports based on their primary function
 */
enum class PortType {
    COMMERCIAL,      // General cargo and container handling
    INDUSTRIAL,      // Manufacturing and processing
    ENERGY,          // Oil, gas, and energy commodities
    BULK,           // Dry and liquid bulk commodities
    CONTAINER,      // Containerized cargo
    PASSENGER,      // Cruise and ferry terminals
    FISHING,        // Fishing and seafood processing
    MILITARY,       // Naval and defense facilities
    SPECIALIZED     // Specialized cargo types
}

/**
 * Port size classification
 */
enum class PortSize {
    SMALL,    // Local/regional ports
    MEDIUM,   // National importance
    LARGE,    // International hub
    MEGA      // Global super-hub
}

/**
 * Port capacity specifications
 */
data class PortCapacity(
    val maxVessels: Int,                    // Maximum vessels at once
    val maxTEU: Int,                        // Twenty-foot Equivalent Units
    val maxBulkTonnage: Double,             // Max bulk cargo in tons
    val maxLiquidVolume: Double,            // Max liquid cargo in cubic meters
    val maxGeneralCargo: Double,            // Max general cargo in tons
    val storageCapacity: Map<CommodityType, Double>, // Storage by commodity type
    val turnAroundTime: TurnAroundTime      // Average processing times
)

/**
 * Turn around times for different vessel types
 */
data class TurnAroundTime(
    val containerShip: Int,    // Hours
    val bulkCarrier: Int,      // Hours
    val tanker: Int,           // Hours
    val generalCargo: Int,     // Hours
    val roro: Int              // Roll-on/Roll-off vessels
)

/**
 * Available facilities at the port
 */
enum class PortFacility {
    CONTAINER_TERMINAL,
    BULK_TERMINAL,
    LIQUID_TERMINAL,
    GENERAL_CARGO_TERMINAL,
    RORO_TERMINAL,
    CRUISE_TERMINAL,
    COLD_STORAGE,
    HAZMAT_HANDLING,
    HEAVY_LIFT_CRANES,
    RAIL_CONNECTION,
    ROAD_CONNECTION,
    PIPELINE_CONNECTION,
    BUNKERING,           // Fuel services
    SHIP_REPAIR,
    CUSTOMS_FACILITY,
    QUARANTINE_FACILITY,
    WAREHOUSE_COMPLEX
}

/**
 * Port operational hours and restrictions
 */
data class OperationalHours(
    val is24Hour: Boolean,
    val workingHours: IntRange,        // 0-23 hour format
    val weekendOperations: Boolean,
    val holidayRestrictions: Set<String>, // Holiday names
    val tideRestrictions: Boolean,     // Operations dependent on tides
    val weatherRestrictions: Set<WeatherCondition>
)

/**
 * Weather conditions affecting port operations
 */
data class WeatherConditions(
    val averageConditions: Map<Int, WeatherCondition>, // Month -> Condition
    val extremeWeatherRisk: ExtremeWeatherRisk,
    val seasonalRestrictions: Map<Int, Set<PortRestriction>> // Month -> Restrictions
)

enum class WeatherCondition {
    EXCELLENT,
    GOOD,
    MODERATE,
    POOR,
    SEVERE
}

data class ExtremeWeatherRisk(
    val hurricaneRisk: RiskLevel,
    val typhoonRisk: RiskLevel,
    val iceRisk: RiskLevel,
    val fogRisk: RiskLevel,
    val stormRisk: RiskLevel
)

enum class RiskLevel {
    NONE, LOW, MEDIUM, HIGH, EXTREME
}

enum class PortRestriction {
    NO_LARGE_VESSELS,
    NO_HAZMAT,
    REDUCED_CAPACITY,
    EMERGENCY_ONLY,
    CLOSED
}

/**
 * Political stability and security rating
 */
data class PoliticalStability(
    val stabilityRating: Int,      // 1-10 scale
    val securityLevel: SecurityLevel,
    val corruptionIndex: Double,   // 0.0-1.0, lower is better
    val tradeAgreements: Set<String>, // Countries with favorable trade
    val sanctions: Set<String>,    // Countries under sanctions
    val stabilityFactor: Double    // Calculated efficiency factor
) {
    init {
        require(stabilityRating in 1..10) { "Stability rating must be 1-10" }
        require(corruptionIndex in 0.0..1.0) { "Corruption index must be 0.0-1.0" }
    }
}

enum class SecurityLevel {
    VERY_HIGH, HIGH, MEDIUM, LOW, VERY_LOW
}

/**
 * Port infrastructure quality and capabilities
 */
data class PortInfrastructure(
    val roadQuality: InfrastructureQuality,
    val railQuality: InfrastructureQuality,
    val craneCapacity: Int,           // Max tonnes per crane
    val numberOfCranes: Int,
    val waterDepth: Double,           // Meters, max vessel draft
    val berthLength: Int,             // Total berth length in meters
    val digitalSystems: DigitalCapability,
    val overallRating: Double         // Calculated 0.0-2.0 efficiency factor
)

enum class InfrastructureQuality {
    POOR, BASIC, GOOD, EXCELLENT, WORLD_CLASS
}

data class DigitalCapability(
    val automatedSystems: Boolean,
    val realTimeTracking: Boolean,
    val ediIntegration: Boolean,      // Electronic Data Interchange
    val predictiveAnalytics: Boolean,
    val iotSensors: Boolean          // Internet of Things
)

/**
 * Port operational costs
 */
data class PortCosts(
    val berthingFee: Double,         // Per day
    val handlingCost: Map<CommodityType, Double>, // Per unit handled
    val storageeCost: Map<CommodityType, Double>, // Per unit per day
    val fuelCost: Double,            // Per liter
    val pilotage: Double,            // Fixed fee for port entry
    val towage: Double,              // Tugboat services
    val agencyFees: Double,          // Port agent services
    val customs: Double,             // Customs processing
    val security: Double             // Security screening
)