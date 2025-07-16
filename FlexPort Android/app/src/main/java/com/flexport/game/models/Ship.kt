package com.flexport.game.models

import kotlinx.serialization.Serializable

/**
 * Represents a ship in the FlexPort game.
 * Ships are the primary vehicles for transporting goods between ports.
 */
@Serializable
data class Ship(
    val id: String,
    val name: String,
    val type: ShipType,
    val capacity: Int, // Total cargo capacity in tons
    val speed: Double, // Speed in knots
    val fuelEfficiency: Double, // Fuel consumption per nautical mile
    val maintenanceCost: Double, // Cost per day
    val purchasePrice: Double,
    val currentPosition: GeographicalPosition,
    val currentCargo: List<CargoSlot> = emptyList(),
    val destination: String? = null, // Port ID
    val status: ShipStatus = ShipStatus.DOCKED,
    val fuelLevel: Double = 100.0, // Percentage
    val condition: Double = 100.0 // Ship condition percentage
) {
    /**
     * Calculate current cargo weight
     */
    fun getCurrentCargoWeight(): Int {
        return currentCargo.sumOf { it.quantity }
    }
    
    /**
     * Calculate remaining cargo capacity
     */
    fun getRemainingCapacity(): Int {
        return capacity - getCurrentCargoWeight()
    }
    
    /**
     * Calculate estimated travel time to destination
     */
    fun estimatedTravelTime(destination: GeographicalPosition): Double {
        val distance = currentPosition.distanceTo(destination)
        return distance / speed // Hours
    }
    
    /**
     * Calculate fuel consumption for a journey
     */
    fun calculateFuelConsumption(destination: GeographicalPosition): Double {
        val distance = currentPosition.distanceTo(destination)
        return distance * fuelEfficiency
    }
    
    /**
     * Calculate daily operating costs
     */
    fun getDailyOperatingCost(): Double {
        val baseCost = maintenanceCost
        val conditionMultiplier = 2.0 - (condition / 100.0) // Higher cost for poor condition
        val utilizationMultiplier = 1.0 + (getCurrentCargoWeight().toDouble() / capacity * 0.2)
        return baseCost * conditionMultiplier * utilizationMultiplier
    }
    
    /**
     * Check if ship can carry additional cargo
     */
    fun canLoadCargo(quantity: Int): Boolean {
        return getRemainingCapacity() >= quantity && status == ShipStatus.DOCKED
    }
    
    /**
     * Calculate cargo value
     */
    fun getTotalCargoValue(): Double {
        return currentCargo.sumOf { it.commodity.basePrice * it.quantity }
    }
}

@Serializable
enum class ShipType {
    CARGO_SHIP,
    CONTAINER_SHIP,
    CARGO_PLANE,
    FREIGHT_TRAIN
}

@Serializable
enum class ShipStatus {
    DOCKED,
    IN_TRANSIT,
    LOADING,
    UNLOADING,
    MAINTENANCE,
    REFUELING
}

@Serializable
data class CargoSlot(
    val commodity: Commodity,
    val quantity: Int,
    val loadedAt: String, // Port ID where cargo was loaded
    val destination: String? = null // Target port ID
)