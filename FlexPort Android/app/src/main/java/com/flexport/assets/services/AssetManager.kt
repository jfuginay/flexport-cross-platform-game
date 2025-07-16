package com.flexport.assets.services

import com.flexport.assets.data.AssetRepository
import com.flexport.assets.models.*
import com.flexport.economics.models.AssetCondition
import com.flexport.economics.services.EconomicEngine
import com.flexport.game.ecs.GameWorld
import com.flexport.game.ecs.components.*
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

/**
 * Manager service that integrates assets with the economic system and ECS
 */
class AssetManager private constructor(
    private val assetRepository: AssetRepository,
    private val economicEngine: EconomicEngine,
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.Default)
) {
    
    companion object {
        @Volatile
        private var INSTANCE: AssetManager? = null
        
        fun getInstance(): AssetManager {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: AssetManager(
                    AssetRepository.getInstance(),
                    EconomicEngine.getInstance()
                ).also { INSTANCE = it }
            }
        }
    }
    
    private val _assetEvents = MutableSharedFlow<AssetOperationEvent>()
    val assetEvents: SharedFlow<AssetOperationEvent> = _assetEvents.asSharedFlow()
    
    init {
        // Start monitoring asset revenue and costs
        startAssetMonitoring()
    }
    
    /**
     * Purchase an asset from the marketplace
     */
    suspend fun purchaseAsset(
        playerId: String,
        marketplaceAsset: MarketplaceAsset
    ): Result<Asset> {
        return try {
            // Check if player has sufficient funds
            val playerBalance = economicEngine.getPlayerBalance(playerId)
            if (playerBalance < marketplaceAsset.price) {
                return Result.failure(InsufficientFundsException(
                    "Insufficient funds. Need ${marketplaceAsset.price}, have $playerBalance"
                ))
            }
            
            // Create asset specifications based on type
            val specifications = createSpecifications(marketplaceAsset)
            
            // Create location based on asset type
            val location = createInitialLocation(marketplaceAsset)
            
            // Deduct funds from player
            economicEngine.deductFunds(playerId, marketplaceAsset.price, "Asset Purchase: ${marketplaceAsset.name}")
            
            // Create the asset
            val asset = assetRepository.createAsset(
                name = marketplaceAsset.name,
                type = marketplaceAsset.type,
                ownerId = playerId,
                purchasePrice = marketplaceAsset.price,
                location = location,
                specifications = specifications
            )
            
            // Emit purchase event
            _assetEvents.emit(AssetOperationEvent.AssetPurchased(asset, marketplaceAsset.price))
            
            Result.success(asset)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * Sell an asset
     */
    suspend fun sellAsset(assetId: String): Result<Double> {
        return try {
            val asset = assetRepository.getAsset(assetId)
                ?: return Result.failure(AssetNotFoundException("Asset not found: $assetId"))
            
            // Calculate sale price (depreciated value with market conditions)
            val basePrice = asset.getDepreciatedValue()
            val marketMultiplier = economicEngine.getMarketCondition("asset_market").demandMultiplier
            val conditionMultiplier = when (asset.condition) {
                AssetCondition.EXCELLENT -> 1.1
                AssetCondition.GOOD -> 1.0
                AssetCondition.FAIR -> 0.85
                AssetCondition.POOR -> 0.7
            }
            val salePrice = basePrice * marketMultiplier * conditionMultiplier
            
            // Process the sale
            val actualSalePrice = assetRepository.sellAsset(assetId)
            
            // Add funds to player
            economicEngine.addFunds(asset.ownerId, salePrice, "Asset Sale: ${asset.name}")
            
            // Emit sale event
            _assetEvents.emit(AssetOperationEvent.AssetSold(asset, salePrice))
            
            Result.success(salePrice)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * Perform maintenance on an asset
     */
    suspend fun performMaintenance(
        assetId: String,
        maintenanceType: MaintenanceType
    ): Result<Unit> {
        return try {
            val asset = assetRepository.getAsset(assetId)
                ?: return Result.failure(AssetNotFoundException("Asset not found: $assetId"))
            
            // Calculate maintenance cost
            val baseCost = asset.currentValue * when (maintenanceType) {
                MaintenanceType.ROUTINE -> 0.001
                MaintenanceType.SCHEDULED -> 0.005
                MaintenanceType.EMERGENCY -> 0.01
                MaintenanceType.INSPECTION -> 0.0005
                MaintenanceType.OVERHAUL -> 0.05
                MaintenanceType.UPGRADE -> 0.1
            }
            
            // Check if player has sufficient funds
            val playerBalance = economicEngine.getPlayerBalance(asset.ownerId)
            if (playerBalance < baseCost) {
                return Result.failure(InsufficientFundsException(
                    "Insufficient funds for maintenance. Need $baseCost, have $playerBalance"
                ))
            }
            
            // Deduct maintenance cost
            economicEngine.deductFunds(
                asset.ownerId, 
                baseCost, 
                "Maintenance: ${asset.name} - ${maintenanceType.name}"
            )
            
            // Perform maintenance
            assetRepository.performMaintenance(
                assetId,
                maintenanceType,
                baseCost,
                "Performed ${maintenanceType.name} maintenance"
            )
            
            // Emit maintenance event
            _assetEvents.emit(AssetOperationEvent.MaintenancePerformed(asset, maintenanceType, baseCost))
            
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * Start monitoring assets for revenue and costs
     */
    private fun startAssetMonitoring() {
        scope.launch {
            // Monitor all assets every game hour (configurable)
            assetRepository.assets.collect { assets ->
                assets.forEach { asset ->
                    processAssetOperations(asset)
                }
            }
        }
    }
    
    /**
     * Process operational revenue and costs for an asset
     */
    private suspend fun processAssetOperations(asset: Asset) {
        // Skip if asset is not operational
        if (!asset.isOperational) return
        
        val world = GameWorld.instance
        asset.entityId?.let { entityId ->
            world.entityManager.getEntity(entityId)?.let { entity ->
                // Process revenue if applicable
                world.entityManager.getComponent(entity, RevenueComponent::class)?.let { revenueComponent ->
                    val hoursSinceLastCollection = (System.currentTimeMillis() - revenueComponent.lastRevenueCollection) / (1000.0 * 60 * 60)
                    if (hoursSinceLastCollection >= 1.0) { // Collect every hour
                        val revenue = (revenueComponent.baseRevenuePerDay / 24) * hoursSinceLastCollection * revenueComponent.revenueMultiplier
                        
                        // Add revenue to player
                        economicEngine.addFunds(asset.ownerId, revenue, "Revenue: ${asset.name}")
                        
                        // Update revenue component
                        val updatedComponent = revenueComponent.copy(
                            lastRevenueCollection = System.currentTimeMillis(),
                            totalRevenue = revenueComponent.totalRevenue + revenue,
                            revenueHistory = revenueComponent.revenueHistory + RevenueRecord(
                                timestamp = System.currentTimeMillis(),
                                amount = revenue,
                                source = "Operations",
                                description = "Hourly operational revenue"
                            )
                        )
                        world.entityManager.removeComponent(entity, RevenueComponent::class)
                        world.entityManager.addComponent(entity, updatedComponent)
                        
                        _assetEvents.emit(AssetOperationEvent.RevenueGenerated(asset, revenue))
                    }
                }
                
                // Process operating costs
                val hourlyCost = asset.getTotalDailyCost() / 24
                economicEngine.deductFunds(asset.ownerId, hourlyCost, "Operating Cost: ${asset.name}")
                
                // Process crew costs if applicable
                world.entityManager.getComponent(entity, CrewComponent::class)?.let { crewComponent ->
                    val monthlySalary = crewComponent.currentCrew * crewComponent.monthlySalaryPerCrew
                    val hourlySalary = monthlySalary / (30 * 24)
                    economicEngine.deductFunds(asset.ownerId, hourlySalary, "Crew Salary: ${asset.name}")
                }
                
                // Process insurance if applicable
                world.entityManager.getComponent(entity, InsuranceComponent::class)?.let { insuranceComponent ->
                    val hourlyPremium = insuranceComponent.monthlyPremium / (30 * 24)
                    economicEngine.deductFunds(asset.ownerId, hourlyPremium, "Insurance: ${asset.name}")
                }
                
                // Update asset condition over time
                updateAssetCondition(asset)
            }
        }
    }
    
    /**
     * Update asset condition based on usage and maintenance
     */
    private suspend fun updateAssetCondition(asset: Asset) {
        // Condition degrades over time
        val daysSinceLastMaintenance = (System.currentTimeMillis() - asset.maintenanceData.lastMaintenanceDate) / (1000L * 60 * 60 * 24)
        
        if (daysSinceLastMaintenance > 30) { // Condition starts degrading after 30 days
            val degradationChance = (daysSinceLastMaintenance - 30) / 365.0 // Higher chance as time passes
            if (Math.random() < degradationChance * 0.1) { // 10% max chance per check
                val newCondition = when (asset.condition) {
                    AssetCondition.EXCELLENT -> AssetCondition.GOOD
                    AssetCondition.GOOD -> AssetCondition.FAIR
                    AssetCondition.FAIR -> AssetCondition.POOR
                    AssetCondition.POOR -> {
                        // Asset breaks down
                        val updatedAsset = asset.copy(isOperational = false)
                        assetRepository.updateAsset(updatedAsset)
                        _assetEvents.emit(AssetOperationEvent.AssetBrokenDown(asset))
                        AssetCondition.POOR
                    }
                }
                
                if (newCondition != asset.condition) {
                    val updatedAsset = asset.copy(condition = newCondition)
                    assetRepository.updateAsset(updatedAsset)
                    _assetEvents.emit(AssetOperationEvent.ConditionDegraded(asset, newCondition))
                }
            }
        }
    }
    
    /**
     * Create specifications from marketplace asset
     */
    private fun createSpecifications(marketplaceAsset: MarketplaceAsset): AssetSpecifications {
        // Extract manufacturer, model, yearBuilt from the marketplace asset's specifications
        val specs = marketplaceAsset.specifications
        val manufacturer = when (specs) {
            is AssetSpecifications.ShipSpecifications -> specs.manufacturer
            is AssetSpecifications.AircraftSpecifications -> specs.manufacturer
            is AssetSpecifications.VehicleSpecifications -> specs.manufacturer
            is AssetSpecifications.EquipmentSpecifications -> specs.manufacturer
            else -> "Unknown"
        }
        val model = when (specs) {
            is AssetSpecifications.ShipSpecifications -> specs.model
            is AssetSpecifications.AircraftSpecifications -> specs.model
            is AssetSpecifications.VehicleSpecifications -> specs.model
            is AssetSpecifications.EquipmentSpecifications -> specs.model
            else -> "Unknown"
        }
        val yearBuilt = when (specs) {
            is AssetSpecifications.ShipSpecifications -> specs.yearBuilt
            is AssetSpecifications.AircraftSpecifications -> specs.yearBuilt
            is AssetSpecifications.VehicleSpecifications -> specs.yearBuilt
            is AssetSpecifications.EquipmentSpecifications -> specs.yearBuilt
            is AssetSpecifications.WarehouseSpecifications -> specs.yearBuilt
            is AssetSpecifications.PortTerminalSpecifications -> 2000 // Default year for port terminals
        }
        
        return when (marketplaceAsset.type) {
            AssetType.CONTAINER_SHIP, AssetType.BULK_CARRIER, AssetType.TANKER -> {
                when (specs) {
                    is AssetSpecifications.ShipSpecifications -> specs
                    else -> AssetSpecifications.ShipSpecifications(
                        capacity = 10000,
                        maxSpeed = 20.0,
                        fuelCapacity = 5000.0,
                        length = 400.0,
                        beam = 59.0,
                        draft = 16.0,
                        dwt = 100000.0,
                        manufacturer = manufacturer,
                        model = model,
                        yearBuilt = yearBuilt
                    )
                }
            }
            AssetType.CARGO_AIRCRAFT, AssetType.PASSENGER_AIRCRAFT -> {
                when (specs) {
                    is AssetSpecifications.AircraftSpecifications -> specs
                    else -> AssetSpecifications.AircraftSpecifications(
                        cargoCapacity = 100000.0,
                        passengerCapacity = 0,
                        maxRange = 8000.0,
                        cruiseSpeed = 850.0,
                        maxAltitude = 12000.0,
                        fuelCapacity = 200000.0,
                        manufacturer = manufacturer,
                        model = model,
                        yearBuilt = yearBuilt
                    )
                }
            }
            AssetType.WAREHOUSE, AssetType.DISTRIBUTION_CENTER -> {
                when (specs) {
                    is AssetSpecifications.WarehouseSpecifications -> specs
                    else -> AssetSpecifications.WarehouseSpecifications(
                        totalArea = 50000.0,
                        storageVolume = 500000.0,
                        loadingDocks = 20,
                        rackingCapacity = 10000,
                        temperatureControlled = true,
                        hazmatCertified = false,
                        securityLevel = "High",
                        yearBuilt = yearBuilt
                    )
                }
            }
            AssetType.TRUCK -> {
                when (specs) {
                    is AssetSpecifications.VehicleSpecifications -> specs
                    else -> AssetSpecifications.VehicleSpecifications(
                        payloadCapacity = 40.0,
                        maxRange = 1500.0,
                        fuelType = "Diesel",
                        fuelCapacity = 500.0,
                        manufacturer = manufacturer,
                        model = model,
                        yearBuilt = yearBuilt
                    )
                }
            }
            else -> {
                when (specs) {
                    is AssetSpecifications.EquipmentSpecifications -> specs
                    else -> AssetSpecifications.EquipmentSpecifications(
                        operatingWeight = 5000.0,
                        powerType = "Diesel",
                        manufacturer = manufacturer,
                        model = model,
                        yearBuilt = yearBuilt
                    )
                }
            }
        }
    }
    
    /**
     * Create initial location for an asset
     */
    private fun createInitialLocation(marketplaceAsset: MarketplaceAsset): AssetLocation {
        return when (marketplaceAsset.type) {
            AssetType.CONTAINER_SHIP, AssetType.BULK_CARRIER, AssetType.TANKER -> {
                AssetLocation(
                    latitude = 1.2897, // Singapore port coordinates
                    longitude = 103.8501,
                    portId = "singapore_port",
                    locationType = LocationType.IN_PORT
                )
            }
            AssetType.WAREHOUSE, AssetType.DISTRIBUTION_CENTER, AssetType.PORT_TERMINAL -> {
                AssetLocation(
                    latitude = marketplaceAsset.location.latitude,
                    longitude = marketplaceAsset.location.longitude,
                    address = marketplaceAsset.location.address,
                    locationType = LocationType.AT_FACILITY
                )
            }
            else -> {
                AssetLocation(
                    locationType = LocationType.UNKNOWN
                )
            }
        }
    }
    
    /**
     * Get player's assets
     */
    fun getPlayerAssets(playerId: String): Flow<List<Asset>> {
        return assetRepository.getAssetsByOwner(playerId)
    }
    
    /**
     * Get player's total asset value
     */
    suspend fun getPlayerAssetValue(playerId: String): Double {
        return assetRepository.getTotalAssetValue(playerId)
    }
    
    /**
     * Get player's total daily costs
     */
    suspend fun getPlayerDailyCosts(playerId: String): Double {
        return assetRepository.getTotalDailyCosts(playerId)
    }
}

/**
 * Asset operation events (different from marketplace AssetEvent)
 */
sealed class AssetOperationEvent {
    data class AssetPurchased(val asset: Asset, val price: Double) : AssetOperationEvent()
    data class AssetSold(val asset: Asset, val price: Double) : AssetOperationEvent()
    data class MaintenancePerformed(val asset: Asset, val type: MaintenanceType, val cost: Double) : AssetOperationEvent()
    data class RevenueGenerated(val asset: Asset, val amount: Double) : AssetOperationEvent()
    data class ConditionDegraded(val asset: Asset, val newCondition: AssetCondition) : AssetOperationEvent()
    data class AssetBrokenDown(val asset: Asset) : AssetOperationEvent()
}

/**
 * Exceptions
 */
class InsufficientFundsException(message: String) : Exception(message)
class AssetNotFoundException(message: String) : Exception(message)