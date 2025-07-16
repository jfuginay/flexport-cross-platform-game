package com.flexport.game.ecs.systems

import com.flexport.game.ecs.System
import com.flexport.game.ecs.ComponentManager
import com.flexport.game.ecs.Entity
import com.flexport.game.ecs.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * System responsible for economic calculations and updates
 */
class EconomicSystem(private val componentManager: ComponentManager) : System {
    
    private val _economicEvents = MutableStateFlow<List<EconomicEvent>>(emptyList())
    val economicEvents: StateFlow<List<EconomicEvent>> = _economicEvents
    
    override fun getPriority(): Int = 20
    
    override fun update(deltaTime: Float) {
        val events = mutableListOf<EconomicEvent>()
        
        // Update all entities with economic components
        val entities = componentManager.getEntitiesWithComponents(
            EconomicComponent::class
        )
        
        entities.forEach { entityId ->
            val entity = Entity.create(entityId)
            val economic = componentManager.getComponent(entity, EconomicComponent::class) ?: return@forEach
            
            // Calculate maintenance costs (per second, scaled by deltaTime)
            val maintenanceCost = economic.maintenanceCost * (deltaTime / 3600f) // Convert hourly to per-frame
            var updatedValue = economic.currentValue - maintenanceCost
            
            // Check for cargo sales if entity has cargo
            componentManager.getComponent(entity, CargoComponent::class)?.let { cargo ->
                if (cargo.currentCargo.isNotEmpty()) {
                    // Check if docked at port
                    componentManager.getComponent(entity, DockingComponent::class)?.let { docking ->
                        if (docking.currentPortId != null) {
                            // Calculate cargo value (simplified) - use list size as quantity
                            val cargoValue = cargo.currentCargo.size * 1000.0 // Simplified value
                            if (cargoValue > 0) {
                                val revenue = cargoValue * 1.2 // 20% profit margin
                                updatedValue += revenue
                                
                                events.add(EconomicEvent(
                                    entityId = entityId,
                                    type = EconomicEventType.CARGO_SALE,
                                    amount = revenue,
                                    description = "Sold cargo at port ${docking.currentPortId}"
                                ))
                                
                                // Clear cargo after sale - using Component.kt structure
                                val updatedCargo = cargo.copy(
                                    currentCargo = emptyList()
                                )
                                componentManager.removeComponent(entity, CargoComponent::class)
                                componentManager.addComponent(entity, updatedCargo)
                            }
                        }
                    }
                }
            }
            
            // Apply economic updates
            val finalEconomic = economic.copy(currentValue = updatedValue)
            componentManager.removeComponent(entity, EconomicComponent::class)
            componentManager.addComponent(entity, finalEconomic)
            
            // Generate maintenance event periodically (simplified timing)
            events.add(EconomicEvent(
                entityId = entityId,
                type = EconomicEventType.MAINTENANCE,
                amount = -maintenanceCost,
                description = "Routine maintenance costs"
            ))
        }
        
        // Update events flow
        if (events.isNotEmpty()) {
            _economicEvents.value = events
        }
    }
}


/**
 * Economic event data
 */
data class EconomicEvent(
    val entityId: String,
    val type: EconomicEventType,
    val amount: Double,
    val description: String,
    val timestamp: Long = java.lang.System.currentTimeMillis()
)

enum class EconomicEventType {
    CARGO_SALE,
    CARGO_PURCHASE,
    MAINTENANCE,
    DOCKING_FEE,
    FUEL_PURCHASE,
    REPAIR_COST
}