package com.flexport.ecs.systems

import com.flexport.ecs.components.AssetComponent
import com.flexport.ecs.components.AssetType
import com.flexport.ecs.components.EconomicComponent
import com.flexport.ecs.core.ComponentType
import com.flexport.ecs.core.EntityManager
import com.flexport.ecs.core.System
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch

/**
 * System responsible for updating economic aspects of entities
 */
class EconomicUpdateSystem(
    entityManager: EntityManager
) : System(entityManager) {
    
    private var accumulatedTime = 0f
    private val updateInterval = 1f // Update economics every second
    
    override fun getRequiredComponents(): Array<ComponentType> {
        return arrayOf(AssetComponent::class, EconomicComponent::class)
    }
    
    override suspend fun update(deltaTime: Float) {
        accumulatedTime += deltaTime
        
        // Only update at intervals to reduce computation
        if (accumulatedTime < updateInterval) return
        
        val timeElapsed = accumulatedTime
        accumulatedTime = 0f
        
        val entities = entityManager.getEntitiesWithComponents(
            AssetComponent::class,
            EconomicComponent::class
        )
        
        // Process economic updates in parallel
        coroutineScope {
            entities.chunked(50).forEach { chunk ->
                launch {
                    chunk.forEach { entity ->
                        val asset = entityManager.getComponent(entity, AssetComponent::class)
                        val economic = entityManager.getComponent(entity, EconomicComponent::class)
                        
                        if (asset != null && economic != null) {
                            processEconomicUpdate(asset, economic, timeElapsed)
                        }
                    }
                }
            }
        }
    }
    
    private fun processEconomicUpdate(
        asset: AssetComponent,
        economic: EconomicComponent,
        timeElapsed: Float
    ) {
        // Apply maintenance costs
        if (asset.isOperational && asset.maintenanceCost > 0) {
            val maintenanceDue = asset.maintenanceCost * timeElapsed
            
            if (economic.canAfford(maintenanceDue)) {
                economic.processPayment(maintenanceDue)
            } else {
                // Can't afford maintenance - asset becomes non-operational
                asset.isOperational = false
            }
        }
        
        // Apply credit interest
        if (economic.creditUsed > 0) {
            val interestRate = 0.05f / 365f // 5% annual interest
            val interest = economic.creditUsed * interestRate * timeElapsed
            economic.creditUsed += interest
        }
        
        // Port-specific economic updates
        if (asset.assetType == AssetType.PORT) {
            // Ports generate passive income
            val baseIncome = 100f * timeElapsed
            economic.receivePayment(baseIncome)
        }
        
        // Warehouse storage fees
        if (asset.assetType == AssetType.WAREHOUSE && asset.currentLoad > 0) {
            val storageFee = asset.currentLoad * 0.1f * timeElapsed
            economic.processPayment(storageFee)
        }
    }
}