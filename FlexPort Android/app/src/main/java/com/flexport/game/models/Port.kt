package com.flexport.game.models

import kotlinx.serialization.Serializable

/**
 * Represents a port in the FlexPort game world.
 * Ports are key locations where ships can dock, load/unload cargo, and conduct trade.
 */
@Serializable
data class Port(
    val id: String,
    val name: String,
    val position: GeographicalPosition,
    val type: PortType,
    val capacity: Int,
    val demandMultipliers: Map<String, Double> = emptyMap(), // Commodity name to demand multiplier
    val supplyMultipliers: Map<String, Double> = emptyMap(), // Commodity name to supply multiplier
    val dockingFee: Double = 1000.0,
    val isOperational: Boolean = true
) {
    /**
     * Calculate docking fee for a ship based on its size and cargo
     */
    fun calculateDockingFee(shipCapacity: Int, cargoValue: Double = 0.0): Double {
        val baseFee = dockingFee
        val capacityMultiplier = 1.0 + (shipCapacity / 1000.0) * 0.1
        val cargoMultiplier = 1.0 + (cargoValue / 100000.0) * 0.05
        return baseFee * capacityMultiplier * cargoMultiplier
    }
    
    /**
     * Get demand multiplier for a specific commodity
     */
    fun getDemandFor(commodityName: String): Double {
        return demandMultipliers[commodityName] ?: 1.0
    }
    
    /**
     * Get supply multiplier for a specific commodity
     */
    fun getSupplyFor(commodityName: String): Double {
        return supplyMultipliers[commodityName] ?: 1.0
    }
    
    /**
     * Check if port can accommodate ships of given type
     */
    fun canAccommodate(shipType: ShipType): Boolean {
        return when (type) {
            PortType.SEA -> shipType == ShipType.CARGO_SHIP || shipType == ShipType.CONTAINER_SHIP
            PortType.AIR -> shipType == ShipType.CARGO_PLANE
            PortType.RAIL -> shipType == ShipType.FREIGHT_TRAIN
            PortType.MULTIMODAL -> true
        }
    }
}

@Serializable
enum class PortType {
    SEA,
    AIR,
    RAIL,
    MULTIMODAL
}