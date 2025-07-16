package com.flexport.assets.data

import com.flexport.assets.models.*
import com.flexport.economics.models.AssetCondition
import com.flexport.game.ecs.Entity
import com.flexport.game.ecs.GameWorld
import com.flexport.game.ecs.components.*
import com.flexport.game.ecs.PositionComponent
import com.flexport.game.ecs.MovementComponent
import com.flexport.game.ecs.CargoComponent
import com.flexport.game.ecs.OwnershipComponent
import com.flexport.game.ecs.EconomicComponent
import com.flexport.game.ecs.ShipComponent
import com.flexport.game.ecs.DockingComponent
import com.flexport.game.ecs.PortComponent
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map

/**
 * Repository for managing assets and their integration with the ECS system
 */
class AssetRepository {
    
    private val _assets = MutableStateFlow<Map<String, Asset>>(emptyMap())
    val assets: Flow<List<Asset>> = _assets.asStateFlow().map { it.values.toList() }
    
    private val _assetEntityMapping = MutableStateFlow<Map<String, String>>(emptyMap()) // assetId -> entityId
    
    companion object {
        @Volatile
        private var INSTANCE: AssetRepository? = null
        
        fun getInstance(): AssetRepository {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: AssetRepository().also { INSTANCE = it }
            }
        }
    }
    
    /**
     * Create a new asset and corresponding ECS entity
     */
    suspend fun createAsset(
        name: String,
        type: AssetType,
        ownerId: String,
        purchasePrice: Double,
        location: AssetLocation,
        specifications: AssetSpecifications
    ): Asset {
        // Create the asset
        val asset = Asset(
            name = name,
            type = type,
            ownerId = ownerId,
            purchasePrice = purchasePrice,
            currentValue = purchasePrice,
            condition = AssetCondition.EXCELLENT,
            location = location,
            specifications = specifications,
            operationalData = OperationalData(),
            maintenanceData = MaintenanceData()
        )
        
        // Create corresponding ECS entity
        val entity = createAssetEntity(asset)
        
        // Update asset with entity ID
        val assetWithEntity = asset.copy(entityId = entity.id)
        
        // Store the asset
        _assets.value = _assets.value + (assetWithEntity.id to assetWithEntity)
        _assetEntityMapping.value = _assetEntityMapping.value + (assetWithEntity.id to entity.id)
        
        return assetWithEntity
    }
    
    /**
     * Create ECS entity for an asset with appropriate components
     */
    private fun createAssetEntity(asset: Asset): Entity {
        val world = GameWorld.instance
        val entity = world.entityManager.createEntity()
        
        // Add basic asset component
        world.entityManager.addComponent(entity, AssetComponent(
            assetId = asset.id,
            assetType = asset.type,
            assetName = asset.name,
            condition = asset.condition,
            currentValue = asset.currentValue,
            operationalStatus = if (asset.isOperational) OperationalStatus.OPERATIONAL else OperationalStatus.DAMAGED
        ))
        
        // Add ownership component
        world.entityManager.addComponent(entity, OwnershipComponent(
            playerId = asset.ownerId,
            acquisitionDate = asset.acquisitionDate,
            purchasePrice = asset.purchasePrice
        ))
        
        // Add economic component
        world.entityManager.addComponent(entity, EconomicComponent(
            currentValue = asset.currentValue,
            dailyOperatingCost = asset.getDailyOperatingCost(),
            maintenanceCost = asset.getMaintenanceCostPerDay()
        ))
        
        // Add type-specific components
        when (asset.specifications) {
            is AssetSpecifications.ShipSpecifications -> {
                addShipComponents(entity, asset, asset.specifications)
            }
            is AssetSpecifications.AircraftSpecifications -> {
                addAircraftComponents(entity, asset, asset.specifications)
            }
            is AssetSpecifications.WarehouseSpecifications -> {
                addWarehouseComponents(entity, asset, asset.specifications)
            }
            is AssetSpecifications.VehicleSpecifications -> {
                addVehicleComponents(entity, asset, asset.specifications)
            }
            is AssetSpecifications.EquipmentSpecifications -> {
                addEquipmentComponents(entity, asset, asset.specifications)
            }
            is AssetSpecifications.PortTerminalSpecifications -> {
                addPortTerminalComponents(entity, asset, asset.specifications)
            }
        }
        
        // Add utilization tracking
        world.entityManager.addComponent(entity, UtilizationComponent(
            utilizationRate = asset.operationalData.utilizationRate,
            lastActivityTime = asset.operationalData.lastOperationalCheck
        ))
        
        return entity
    }
    
    private fun addShipComponents(entity: Entity, asset: Asset, specs: AssetSpecifications.ShipSpecifications) {
        val world = GameWorld.instance
        
        // Add position component if location has coordinates
        asset.location.latitude?.let { lat ->
            asset.location.longitude?.let { lon ->
                world.entityManager.addComponent(entity, PositionComponent(
                    position = com.flexport.game.models.GeographicalPosition(lat, lon),
                    heading = 0.0
                ))
            }
        }
        
        // Add movement component
        world.entityManager.addComponent(entity, MovementComponent(
            speed = 0.0,
            maxSpeed = specs.maxSpeed,
            acceleration = 0.5
        ))
        
        // Add cargo component
        world.entityManager.addComponent(entity, CargoComponent(
            capacity = specs.capacity,
            currentCargo = emptyList()
        ))
        
        // Add ship-specific component
        val shipType = when (asset.type) {
            AssetType.CONTAINER_SHIP -> com.flexport.game.models.ShipType.CONTAINER_SHIP
            AssetType.BULK_CARRIER -> com.flexport.game.models.ShipType.CARGO_SHIP
            AssetType.TANKER -> com.flexport.game.models.ShipType.CARGO_SHIP
            else -> com.flexport.game.models.ShipType.CONTAINER_SHIP
        }
        
        world.entityManager.addComponent(entity, ShipComponent(
            shipType = shipType,
            fuelLevel = 100.0,
            condition = when (asset.condition) {
                AssetCondition.EXCELLENT -> 100.0
                AssetCondition.GOOD -> 80.0
                AssetCondition.FAIR -> 60.0
                AssetCondition.POOR -> 40.0
            },
            fuelEfficiency = 1.0
        ))
        
        // Add fuel component
        world.entityManager.addComponent(entity, FuelComponent(
            fuelCapacity = specs.fuelCapacity,
            currentFuel = specs.fuelCapacity * 0.8, // Start at 80% fuel
            fuelConsumptionRate = asset.operationalData.fuelConsumption,
            fuelType = FuelType.HEAVY_FUEL_OIL
        ))
        
        // Add docking component
        world.entityManager.addComponent(entity, DockingComponent(
            currentPortId = asset.location.portId,
            canDock = true
        ))
        
        // Add crew component
        val requiredCrew = when (specs.capacity) {
            in 0..5000 -> 15
            in 5001..10000 -> 20
            in 10001..15000 -> 25
            else -> 30
        }
        
        world.entityManager.addComponent(entity, CrewComponent(
            requiredCrew = requiredCrew,
            currentCrew = requiredCrew,
            crewEfficiency = 1.0,
            crewMorale = 1.0,
            monthlySalaryPerCrew = 5000.0
        ))
    }
    
    private fun addAircraftComponents(entity: Entity, asset: Asset, specs: AssetSpecifications.AircraftSpecifications) {
        val world = GameWorld.instance
        
        // Add position if available
        asset.location.latitude?.let { lat ->
            asset.location.longitude?.let { lon ->
                world.entityManager.addComponent(entity, PositionComponent(
                    position = com.flexport.game.models.GeographicalPosition(lat, lon),
                    heading = 0.0
                ))
            }
        }
        
        // Add movement component
        world.entityManager.addComponent(entity, MovementComponent(
            speed = 0.0,
            maxSpeed = specs.cruiseSpeed,
            acceleration = 50.0
        ))
        
        // Add cargo component
        world.entityManager.addComponent(entity, CargoComponent(
            capacity = specs.cargoCapacity.toInt(),
            currentCargo = emptyList()
        ))
        
        // Add fuel component
        world.entityManager.addComponent(entity, FuelComponent(
            fuelCapacity = specs.fuelCapacity,
            currentFuel = specs.fuelCapacity * 0.8,
            fuelConsumptionRate = specs.fuelCapacity / (specs.maxRange / specs.cruiseSpeed),
            fuelType = FuelType.AVIATION_FUEL
        ))
        
        // Add crew component
        world.entityManager.addComponent(entity, CrewComponent(
            requiredCrew = if (asset.type == AssetType.CARGO_AIRCRAFT) 3 else 5,
            currentCrew = if (asset.type == AssetType.CARGO_AIRCRAFT) 3 else 5,
            crewEfficiency = 1.0,
            crewMorale = 1.0,
            monthlySalaryPerCrew = 8000.0
        ))
    }
    
    private fun addWarehouseComponents(entity: Entity, asset: Asset, specs: AssetSpecifications.WarehouseSpecifications) {
        val world = GameWorld.instance
        
        // Warehouses don't move, but need position for location
        asset.location.latitude?.let { lat ->
            asset.location.longitude?.let { lon ->
                world.entityManager.addComponent(entity, PositionComponent(
                    position = com.flexport.game.models.GeographicalPosition(lat, lon),
                    heading = 0.0
                ))
            }
        }
        
        // Add cargo capacity based on volume
        world.entityManager.addComponent(entity, CargoComponent(
            capacity = specs.rackingCapacity * 1000, // Convert pallet positions to kg
            currentCargo = emptyList()
        ))
        
        // Add revenue generation
        val baseRevenue = specs.totalArea * 0.5 // $0.50 per square meter per day
        world.entityManager.addComponent(entity, RevenueComponent(
            baseRevenuePerDay = baseRevenue,
            revenueMultiplier = 1.0
        ))
    }
    
    private fun addVehicleComponents(entity: Entity, asset: Asset, specs: AssetSpecifications.VehicleSpecifications) {
        val world = GameWorld.instance
        
        // Add movement component
        world.entityManager.addComponent(entity, MovementComponent(
            speed = 0.0,
            maxSpeed = 90.0, // Average highway speed in km/h
            acceleration = 5.0
        ))
        
        // Add cargo component
        world.entityManager.addComponent(entity, CargoComponent(
            capacity = (specs.payloadCapacity * 1000).toInt(), // Convert tons to kg
            currentCargo = emptyList()
        ))
        
        // Add fuel component
        world.entityManager.addComponent(entity, FuelComponent(
            fuelCapacity = specs.fuelCapacity,
            currentFuel = specs.fuelCapacity * 0.8,
            fuelConsumptionRate = specs.fuelCapacity / specs.maxRange,
            fuelType = when (specs.fuelType.lowercase()) {
                "electric" -> FuelType.ELECTRIC
                "hybrid" -> FuelType.HYBRID
                else -> FuelType.DIESEL
            }
        ))
    }
    
    private fun addEquipmentComponents(entity: Entity, asset: Asset, specs: AssetSpecifications.EquipmentSpecifications) {
        val world = GameWorld.instance
        
        // Equipment typically generates revenue through utilization
        val baseRevenue = when (asset.type) {
            AssetType.CRANE -> 500.0 // $500 per day when utilized
            AssetType.FORKLIFT -> 200.0 // $200 per day when utilized
            else -> 100.0
        }
        
        world.entityManager.addComponent(entity, RevenueComponent(
            baseRevenuePerDay = baseRevenue,
            revenueMultiplier = asset.operationalData.utilizationRate
        ))
    }
    
    private fun addPortTerminalComponents(entity: Entity, asset: Asset, specs: AssetSpecifications.PortTerminalSpecifications) {
        val world = GameWorld.instance
        
        // Port terminals have port-specific components
        world.entityManager.addComponent(entity, PortComponent(
            portType = com.flexport.game.models.PortType.SEA, // Default to sea port
            capacity = specs.storageCapacity,
            dockingFee = 1000.0, // Base docking fee
            isOperational = asset.isOperational,
            dockedShips = emptyList()
        ))
        
        // Add revenue component for port fees
        val baseRevenue = specs.berthLength * 10.0 // $10 per meter of berth per day
        world.entityManager.addComponent(entity, RevenueComponent(
            baseRevenuePerDay = baseRevenue,
            revenueMultiplier = 1.0
        ))
    }
    
    /**
     * Get an asset by ID
     */
    suspend fun getAsset(assetId: String): Asset? {
        return _assets.value[assetId]
    }
    
    /**
     * Get assets by owner
     */
    fun getAssetsByOwner(ownerId: String): Flow<List<Asset>> {
        return assets.map { assetList ->
            assetList.filter { it.ownerId == ownerId }
        }
    }
    
    /**
     * Update an asset
     */
    suspend fun updateAsset(asset: Asset) {
        _assets.value = _assets.value + (asset.id to asset)
        
        // Update corresponding ECS entity components
        asset.entityId?.let { entityId ->
            val world = GameWorld.instance
            world.entityManager.getEntity(entityId)?.let { entity ->
                // Update asset component
                world.entityManager.getComponent(entity, AssetComponent::class)?.let { component ->
                    world.entityManager.removeComponent(entity, AssetComponent::class)
                    world.entityManager.addComponent(entity, component.copy(
                        assetName = asset.name,
                        condition = asset.condition,
                        currentValue = asset.currentValue,
                        operationalStatus = if (asset.isOperational) OperationalStatus.OPERATIONAL else OperationalStatus.DAMAGED
                    ))
                }
                
                // Update economic component
                world.entityManager.getComponent(entity, EconomicComponent::class)?.let { component ->
                    world.entityManager.removeComponent(entity, EconomicComponent::class)
                    world.entityManager.addComponent(entity, component.copy(
                        currentValue = asset.currentValue,
                        dailyOperatingCost = asset.getDailyOperatingCost(),
                        maintenanceCost = asset.getMaintenanceCostPerDay()
                    ))
                }
            }
        }
    }
    
    /**
     * Sell an asset
     */
    suspend fun sellAsset(assetId: String): Double {
        val asset = _assets.value[assetId] ?: return 0.0
        
        // Remove from repository
        _assets.value = _assets.value - assetId
        _assetEntityMapping.value = _assetEntityMapping.value - assetId
        
        // Destroy ECS entity
        asset.entityId?.let { entityId ->
            val world = GameWorld.instance
            world.entityManager.getEntity(entityId)?.let { entity ->
                world.entityManager.destroyEntity(entity)
            }
        }
        
        // Return sale price (depreciated value)
        return asset.getDepreciatedValue()
    }
    
    /**
     * Perform maintenance on an asset
     */
    suspend fun performMaintenance(
        assetId: String,
        maintenanceType: MaintenanceType,
        cost: Double,
        description: String
    ) {
        val asset = _assets.value[assetId] ?: return
        
        // Create maintenance record
        val maintenanceRecord = MaintenanceRecord(
            date = System.currentTimeMillis(),
            type = maintenanceType,
            description = description,
            cost = cost,
            performedBy = "Player Maintenance Team",
            hoursOutOfService = when (maintenanceType) {
                MaintenanceType.ROUTINE -> 4.0
                MaintenanceType.SCHEDULED -> 24.0
                MaintenanceType.EMERGENCY -> 8.0
                MaintenanceType.INSPECTION -> 2.0
                MaintenanceType.OVERHAUL -> 168.0 // 1 week
                MaintenanceType.UPGRADE -> 48.0
            }
        )
        
        // Update maintenance data
        val updatedMaintenanceData = asset.maintenanceData.copy(
            lastMaintenanceDate = System.currentTimeMillis(),
            nextScheduledMaintenance = System.currentTimeMillis() + 90 * 24 * 60 * 60 * 1000L,
            maintenanceHistory = asset.maintenanceData.maintenanceHistory + maintenanceRecord,
            totalMaintenanceCost = asset.maintenanceData.totalMaintenanceCost + cost
        )
        
        // Improve condition based on maintenance type
        val improvedCondition = when (maintenanceType) {
            MaintenanceType.OVERHAUL -> AssetCondition.EXCELLENT
            MaintenanceType.SCHEDULED -> when (asset.condition) {
                AssetCondition.POOR -> AssetCondition.FAIR
                AssetCondition.FAIR -> AssetCondition.GOOD
                else -> asset.condition
            }
            else -> asset.condition
        }
        
        // Update asset
        val updatedAsset = asset.copy(
            condition = improvedCondition,
            maintenanceData = updatedMaintenanceData,
            isOperational = true
        )
        
        updateAsset(updatedAsset)
    }
    
    /**
     * Get total asset value for a player
     */
    suspend fun getTotalAssetValue(ownerId: String): Double {
        return _assets.value.values
            .filter { it.ownerId == ownerId }
            .sumOf { it.currentValue }
    }
    
    /**
     * Get total daily costs for a player's assets
     */
    suspend fun getTotalDailyCosts(ownerId: String): Double {
        return _assets.value.values
            .filter { it.ownerId == ownerId }
            .sumOf { it.getTotalDailyCost() }
    }
}