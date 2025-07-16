package com.flexport.game.ecs

import kotlinx.serialization.Serializable

/**
 * Base interface for all components in the ECS system.
 * Components hold data but no logic.
 */
interface Component

/**
 * Component for entities that have a position in the game world
 */
@Serializable
data class PositionComponent(
    val position: com.flexport.game.models.GeographicalPosition,
    val heading: Double = 0.0 // Bearing in degrees
) : Component

/**
 * Component for entities that can move
 */
@Serializable
data class MovementComponent(
    val speed: Double, // Current speed in knots
    val maxSpeed: Double,
    val acceleration: Double = 1.0,
    val destination: com.flexport.game.models.GeographicalPosition? = null,
    val isMoving: Boolean = false
) : Component

/**
 * Component for entities that can carry cargo
 */
@Serializable
data class CargoComponent(
    val capacity: Int,
    val currentCargo: List<com.flexport.game.models.CargoSlot> = emptyList()
) : Component {
    fun getCurrentWeight(): Int {
        return currentCargo.sumOf { it.quantity }
    }
    
    fun getRemainingCapacity(): Int {
        return capacity - getCurrentWeight()
    }
}

/**
 * Component for entities that are owned by a player
 */
@Serializable
data class OwnershipComponent(
    val playerId: String,
    val acquisitionDate: Long = java.lang.System.currentTimeMillis(),
    val purchasePrice: Double = 0.0
) : Component

/**
 * Component for entities that have economic value
 */
@Serializable
data class EconomicComponent(
    val currentValue: Double,
    val dailyOperatingCost: Double,
    val maintenanceCost: Double = 0.0,
    val insuranceCost: Double = 0.0
) : Component

/**
 * Component for entities that can be at ports
 */
@Serializable
data class DockingComponent(
    val currentPortId: String? = null,
    val dockingTime: Long? = null,
    val canDock: Boolean = true
) : Component

/**
 * Component for ships specifically
 */
@Serializable
data class ShipComponent(
    val shipType: com.flexport.game.models.ShipType,
    val fuelLevel: Double = 100.0,
    val condition: Double = 100.0,
    val fuelEfficiency: Double
) : Component

/**
 * Component for ports specifically
 */
@Serializable
data class PortComponent(
    val portType: com.flexport.game.models.PortType,
    val capacity: Int,
    val dockingFee: Double,
    val isOperational: Boolean = true,
    val dockedShips: List<String> = emptyList() // Entity IDs of docked ships
) : Component

/**
 * Component for commodities
 */
@Serializable
data class CommodityComponent(
    val commodityType: com.flexport.game.models.Commodity,
    val quantity: Int,
    val quality: Double = 1.0
) : Component