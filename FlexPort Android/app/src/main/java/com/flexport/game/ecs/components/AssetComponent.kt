package com.flexport.game.ecs.components

import com.flexport.game.ecs.core.Component

/**
 * Asset types in the game
 */
enum class AssetType {
    SHIP,
    WAREHOUSE,
    PORT,
    ROUTE_NODE,
    CARGO
}

/**
 * Component representing game assets like ships, warehouses, ports, etc.
 */
data class AssetComponent(
    var assetType: AssetType,
    var assetId: String,
    var name: String = "",
    var owner: String = "", // Player or AI owner ID
    var capacity: Int = 0, // Cargo capacity for ships/warehouses
    var currentLoad: Int = 0,
    var maintenanceCost: Float = 0f, // Per day maintenance cost
    var isOperational: Boolean = true
) : Component {
    
    /**
     * Get available capacity
     */
    fun getAvailableCapacity(): Int = capacity - currentLoad
    
    /**
     * Check if can load cargo
     */
    fun canLoadCargo(amount: Int): Boolean {
        return isOperational && getAvailableCapacity() >= amount
    }
    
    /**
     * Load cargo
     */
    fun loadCargo(amount: Int): Boolean {
        if (canLoadCargo(amount)) {
            currentLoad += amount
            return true
        }
        return false
    }
    
    /**
     * Unload cargo
     */
    fun unloadCargo(amount: Int): Int {
        val actualAmount = minOf(amount, currentLoad)
        currentLoad -= actualAmount
        return actualAmount
    }
    
    /**
     * Get load percentage
     */
    fun getLoadPercentage(): Float {
        return if (capacity > 0) currentLoad.toFloat() / capacity else 0f
    }
}