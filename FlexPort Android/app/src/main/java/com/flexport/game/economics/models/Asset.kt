package com.flexport.game.economics.models

import kotlinx.serialization.Serializable

/**
 * Base interface for all physical assets
 */
interface Asset {
    val id: String
    var ownerId: String
    var currentValue: Double
    var condition: AssetCondition
}

/**
 * Types of assets
 */
enum class AssetType {
    SHIP,
    AIRCRAFT,
    WAREHOUSE,
    VEHICLE
}

/**
 * Condition of physical assets
 */
enum class AssetCondition {
    EXCELLENT,
    GOOD,
    FAIR,
    POOR,
    NEEDS_REPAIR
}

/**
 * Ship asset
 */
@Serializable
data class Ship(
    override val id: String,
    override var ownerId: String,
    override var currentValue: Double,
    override var condition: AssetCondition,
    val model: String,
    val capacity: Double,
    val age: Int,
    val specifications: ShipSpecifications
) : Asset

/**
 * Aircraft asset
 */
@Serializable
data class Aircraft(
    override val id: String,
    override var ownerId: String,
    override var currentValue: Double,
    override var condition: AssetCondition,
    val model: String,
    val cargoCapacity: Double,
    val passengerCapacity: Int,
    val range: Double,
    val age: Int,
    val specifications: AircraftSpecifications
) : Asset

/**
 * Warehouse asset
 */
@Serializable
data class Warehouse(
    override val id: String,
    override var ownerId: String,
    override var currentValue: Double,
    override var condition: AssetCondition,
    val location: String,
    val storageCapacity: Double,
    val specifications: WarehouseSpecifications
) : Asset

/**
 * Ship specifications
 */
@Serializable
data class ShipSpecifications(
    val fuelEfficiency: Double,
    val maxSpeed: Double,
    val crewSize: Int,
    val specialFeatures: Set<String> = emptySet()
)

/**
 * Aircraft specifications
 */
@Serializable
data class AircraftSpecifications(
    val fuelEfficiency: Double,
    val maxSpeed: Double,
    val crewSize: Int,
    val specialFeatures: Set<String> = emptySet()
)

/**
 * Warehouse specifications
 */
@Serializable
data class WarehouseSpecifications(
    val temperatureControlled: Boolean,
    val securityLevel: SecurityLevel,
    val automationLevel: AutomationLevel,
    val specialFeatures: Set<String> = emptySet()
)

/**
 * Security level for warehouses
 */
enum class SecurityLevel {
    BASIC,
    ENHANCED,
    HIGH_SECURITY,
    MAXIMUM_SECURITY
}

/**
 * Automation level for warehouses
 */
enum class AutomationLevel {
    MANUAL,
    SEMI_AUTOMATED,
    FULLY_AUTOMATED,
    AI_OPTIMIZED
}

/**
 * Lease agreement for assets
 */
@Serializable
data class LeaseAgreement(
    val id: String,
    val assetId: String,
    val lesseeId: String,
    val monthlyPayment: Double,
    val termMonths: Int,
    val startDate: Long,
    val maintenanceIncluded: Boolean,
    val status: LeaseStatus
)

/**
 * Status of lease agreements
 */
enum class LeaseStatus {
    ACTIVE,
    PENDING,
    EXPIRED,
    TERMINATED
}

/**
 * Asset market statistics
 */
@Serializable
data class AssetMarketStats(
    val assetType: AssetType,
    val averagePrice: Double,
    val priceRange: Pair<Double, Double>,
    val totalListings: Int,
    val avgDaysOnMarket: Double,
    val demandIndex: Double
)