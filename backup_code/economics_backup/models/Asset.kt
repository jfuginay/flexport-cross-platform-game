package com.flexport.economics.models

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