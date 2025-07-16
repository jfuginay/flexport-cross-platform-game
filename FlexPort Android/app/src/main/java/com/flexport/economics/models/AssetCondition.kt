package com.flexport.economics.models

/**
 * Represents the condition of an asset
 */
enum class AssetCondition {
    EXCELLENT,  // Nearly new, perfect operating condition
    GOOD,       // Well-maintained, minor wear
    FAIR,       // Average condition, some maintenance needed
    POOR        // Significant wear, requires repairs
}