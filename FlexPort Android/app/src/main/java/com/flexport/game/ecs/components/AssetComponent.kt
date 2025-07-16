package com.flexport.game.ecs.components

import com.flexport.assets.models.AssetType
import com.flexport.economics.models.AssetCondition
import com.flexport.game.ecs.Component
import kotlinx.serialization.Serializable

/**
 * Component that links an ECS entity to an asset in the asset management system
 */
@Serializable
data class AssetComponent(
    val assetId: String, // Reference to Asset.id
    val assetType: AssetType,
    val assetName: String,
    val condition: AssetCondition,
    val currentValue: Double,
    val operationalStatus: OperationalStatus = OperationalStatus.OPERATIONAL
) : Component

@Serializable
enum class OperationalStatus {
    OPERATIONAL,
    UNDER_MAINTENANCE,
    DAMAGED,
    DECOMMISSIONED,
    IN_TRANSIT
}

/**
 * Component for assets that require crew
 */
@Serializable
data class CrewComponent(
    val requiredCrew: Int,
    val currentCrew: Int = 0,
    val crewEfficiency: Double = 1.0,
    val crewMorale: Double = 1.0,
    val monthlySalaryPerCrew: Double
) : Component

/**
 * Component for assets that consume fuel
 */
@Serializable
data class FuelComponent(
    val fuelCapacity: Double, // Maximum fuel capacity
    val currentFuel: Double, // Current fuel level
    val fuelConsumptionRate: Double, // Units per hour or per km
    val fuelType: FuelType,
    val fuelEfficiency: Double = 1.0 // Multiplier for consumption
) : Component

@Serializable
enum class FuelType {
    MARINE_DIESEL,
    HEAVY_FUEL_OIL,
    AVIATION_FUEL,
    DIESEL,
    ELECTRIC,
    HYBRID,
    LNG
}

/**
 * Component for assets that generate revenue
 */
@Serializable
data class RevenueComponent(
    val baseRevenuePerDay: Double,
    val revenueMultiplier: Double = 1.0,
    val lastRevenueCollection: Long = System.currentTimeMillis(),
    val totalRevenue: Double = 0.0,
    val revenueHistory: List<RevenueRecord> = emptyList()
) : Component

@Serializable
data class RevenueRecord(
    val timestamp: Long,
    val amount: Double,
    val source: String,
    val description: String? = null
)

/**
 * Component for assets that require insurance
 */
@Serializable
data class InsuranceComponent(
    val insuranceProvider: String,
    val monthlyPremium: Double,
    val coverageAmount: Double,
    val deductible: Double,
    val policyStartDate: Long,
    val policyEndDate: Long,
    val coverageType: InsuranceCoverageType,
    val claimsHistory: List<InsuranceClaim> = emptyList()
) : Component

@Serializable
enum class InsuranceCoverageType {
    COMPREHENSIVE,
    LIABILITY_ONLY,
    CARGO_COVERAGE,
    HULL_AND_MACHINERY,
    WAR_RISK,
    ENVIRONMENTAL
}

@Serializable
data class InsuranceClaim(
    val claimId: String,
    val date: Long,
    val amount: Double,
    val description: String,
    val status: ClaimStatus
)

@Serializable
enum class ClaimStatus {
    PENDING,
    APPROVED,
    DENIED,
    PAID
}

/**
 * Component for assets that can be upgraded
 */
@Serializable
data class UpgradeableComponent(
    val currentLevel: Int = 1,
    val maxLevel: Int = 5,
    val availableUpgrades: List<AssetUpgrade> = emptyList(),
    val appliedUpgrades: List<String> = emptyList() // Upgrade IDs
) : Component

@Serializable
data class AssetUpgrade(
    val upgradeId: String,
    val name: String,
    val description: String,
    val cost: Double,
    val timeToInstall: Long, // milliseconds
    val effects: UpgradeEffects,
    val requiredLevel: Int = 1,
    val prerequisites: List<String> = emptyList() // Other upgrade IDs required
)

@Serializable
data class UpgradeEffects(
    val capacityIncrease: Double? = null,
    val speedIncrease: Double? = null,
    val efficiencyIncrease: Double? = null,
    val maintenanceReduction: Double? = null,
    val revenueIncrease: Double? = null,
    val fuelEfficiencyIncrease: Double? = null
)

/**
 * Component for tracking asset utilization
 */
@Serializable
data class UtilizationComponent(
    val utilizationRate: Double = 0.0, // 0-1 percentage
    val idleTime: Long = 0L, // milliseconds
    val activeTime: Long = 0L, // milliseconds
    val lastActivityTime: Long = System.currentTimeMillis(),
    val utilizationHistory: List<UtilizationRecord> = emptyList()
) : Component

@Serializable
data class UtilizationRecord(
    val date: Long,
    val utilizationRate: Double,
    val idleHours: Double,
    val activeHours: Double,
    val revenue: Double
)

/**
 * Component for assets that can be leased
 */
@Serializable
data class LeaseComponent(
    val isLeased: Boolean,
    val lessorId: String? = null,
    val lesseeId: String? = null,
    val monthlyLeasePayment: Double,
    val leaseStartDate: Long,
    val leaseEndDate: Long,
    val leaseTerms: LeaseTerms
) : Component

@Serializable
data class LeaseTerms(
    val minimumTerm: Long, // milliseconds
    val earlyTerminationPenalty: Double,
    val maintenanceResponsibility: MaintenanceResponsibility,
    val insuranceResponsibility: InsuranceResponsibility,
    val utilizationRestrictions: List<String> = emptyList()
)

@Serializable
enum class MaintenanceResponsibility {
    LESSOR,
    LESSEE,
    SHARED
}

@Serializable
enum class InsuranceResponsibility {
    LESSOR,
    LESSEE,
    BOTH
}