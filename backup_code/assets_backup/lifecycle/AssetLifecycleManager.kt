package com.flexport.assets.lifecycle

import com.flexport.assets.models.*
import com.flexport.economics.models.AssetCondition
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.time.LocalDateTime
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.min
import kotlin.math.max

/**
 * Manages the complete lifecycle of assets from acquisition to disposal
 */
class AssetLifecycleManager {
    
    private val _assets = MutableStateFlow<Map<String, FlexPortAsset>>(emptyMap())
    val assets: StateFlow<Map<String, FlexPortAsset>> = _assets.asStateFlow()
    
    private val assetRegistry = ConcurrentHashMap<String, FlexPortAsset>()
    private val maintenanceQueue = ConcurrentHashMap<String, MaintenanceJob>()
    private val upgradeRegistry = ConcurrentHashMap<String, AssetUpgrade>()
    private val disposalQueue = ConcurrentHashMap<String, DisposalRequest>()
    
    // Asset performance tracking
    private val performanceMetrics = ConcurrentHashMap<String, AssetPerformanceMetrics>()
    private val maintenanceHistory = ConcurrentHashMap<String, MutableList<MaintenanceRecord>>()
    
    /**
     * Purchase a new asset
     */
    suspend fun purchaseAsset(
        assetType: AssetType,
        ownerId: String,
        purchaseRequest: AssetPurchaseRequest
    ): AssetPurchaseResult {
        return try {
            val asset = createAssetFromRequest(assetType, ownerId, purchaseRequest)
            
            // Register the asset
            assetRegistry[asset.id] = asset
            updateAssetState()
            
            // Initialize performance tracking
            performanceMetrics[asset.id] = AssetPerformanceMetrics(
                assetId = asset.id,
                totalOperatingHours = 0.0,
                totalRevenue = 0.0,
                totalOperatingCosts = 0.0,
                utilizationHistory = mutableListOf(),
                maintenanceEvents = 0
            )
            
            // Initialize maintenance history
            maintenanceHistory[asset.id] = mutableListOf()
            
            AssetPurchaseResult.Success(asset)
        } catch (e: Exception) {
            AssetPurchaseResult.Failure(e.message ?: "Unknown error during asset purchase")
        }
    }
    
    /**
     * Schedule maintenance for an asset
     */
    suspend fun scheduleMaintenance(
        assetId: String,
        maintenanceType: MaintenanceType,
        scheduledDate: LocalDateTime,
        estimatedCost: Double,
        estimatedDuration: Int // hours
    ): MaintenanceScheduleResult {
        val asset = assetRegistry[assetId] 
            ?: return MaintenanceScheduleResult.AssetNotFound
        
        if (!asset.canOperate() && maintenanceType != MaintenanceType.EMERGENCY) {
            return MaintenanceScheduleResult.AssetNotOperational
        }
        
        val maintenanceJob = MaintenanceJob(
            id = "MNT-${System.currentTimeMillis()}",
            assetId = assetId,
            maintenanceType = maintenanceType,
            scheduledDate = scheduledDate,
            estimatedCost = estimatedCost,
            estimatedDuration = estimatedDuration,
            status = MaintenanceStatus.SCHEDULED,
            priority = determinePriority(asset, maintenanceType)
        )
        
        maintenanceQueue[maintenanceJob.id] = maintenanceJob
        
        // Update asset maintenance schedule
        asset.maintenanceSchedule.nextScheduledMaintenance = scheduledDate
        updateAssetState()
        
        return MaintenanceScheduleResult.Success(maintenanceJob.id)
    }
    
    /**
     * Execute maintenance on an asset
     */
    suspend fun executeMaintenance(maintenanceJobId: String): MaintenanceExecutionResult {
        val job = maintenanceQueue[maintenanceJobId] 
            ?: return MaintenanceExecutionResult.JobNotFound
        
        val asset = assetRegistry[job.assetId]
            ?: return MaintenanceExecutionResult.AssetNotFound
        
        if (job.status != MaintenanceStatus.SCHEDULED) {
            return MaintenanceExecutionResult.InvalidStatus
        }
        
        // Mark asset as non-operational during maintenance
        val originalOperationalStatus = asset.isOperational
        asset.isOperational = false
        
        // Update job status
        job.status = MaintenanceStatus.IN_PROGRESS
        job.actualStartDate = LocalDateTime.now()
        
        try {
            // Perform maintenance (simulate with delay and condition improvement)
            val maintenanceEffectiveness = calculateMaintenanceEffectiveness(asset, job.maintenanceType)
            
            // Improve asset condition based on maintenance type
            when (job.maintenanceType) {
                MaintenanceType.ROUTINE -> {
                    // Minor improvement
                    if (asset.condition == AssetCondition.FAIR) {
                        asset.condition = AssetCondition.GOOD
                    }
                }
                MaintenanceType.PREVENTIVE -> {
                    // Maintain current condition or improve slightly
                    asset.condition = improveCondition(asset.condition, 0.3)
                }
                MaintenanceType.OVERHAUL -> {
                    // Significant improvement
                    asset.condition = improveCondition(asset.condition, 0.8)
                }
                MaintenanceType.EMERGENCY -> {
                    // Fix critical issues
                    if (asset.condition == AssetCondition.NEEDS_REPAIR) {
                        asset.condition = AssetCondition.POOR
                    }
                }
                MaintenanceType.SCHEDULED -> {
                    // Standard improvement
                    asset.condition = improveCondition(asset.condition, 0.5)
                }
            }
            
            // Update maintenance schedule
            asset.maintenanceSchedule.lastMaintenance = LocalDateTime.now()
            asset.maintenanceSchedule.nextScheduledMaintenance = 
                LocalDateTime.now().plusDays(asset.maintenanceSchedule.maintenanceInterval.toLong())
            
            // Restore operational status
            asset.isOperational = originalOperationalStatus
            
            // Complete the job
            job.status = MaintenanceStatus.COMPLETED
            job.actualEndDate = LocalDateTime.now()
            job.actualCost = job.estimatedCost * (0.8 + Math.random() * 0.4) // ±20% variance
            
            // Record maintenance history
            val record = MaintenanceRecord(
                id = "REC-${System.currentTimeMillis()}",
                assetId = job.assetId,
                maintenanceJobId = job.id,
                maintenanceType = job.maintenanceType,
                date = LocalDateTime.now(),
                cost = job.actualCost!!,
                duration = job.estimatedDuration, // In real impl, calculate actual duration
                effectiveness = maintenanceEffectiveness,
                conditionBefore = asset.condition, // Simplified - would track before/after
                conditionAfter = asset.condition
            )
            
            maintenanceHistory.getOrPut(job.assetId) { mutableListOf() }.add(record)
            
            // Update performance metrics
            performanceMetrics[job.assetId]?.let { metrics ->
                metrics.maintenanceEvents++
                metrics.totalOperatingCosts += job.actualCost!!
            }
            
            updateAssetState()
            
            return MaintenanceExecutionResult.Success(record)
            
        } catch (e: Exception) {
            // Restore original status on failure
            asset.isOperational = originalOperationalStatus
            job.status = MaintenanceStatus.FAILED
            
            return MaintenanceExecutionResult.Failure(e.message ?: "Maintenance execution failed")
        }
    }
    
    /**
     * Upgrade an asset
     */
    suspend fun upgradeAsset(
        assetId: String,
        upgradeType: AssetUpgradeType,
        upgradeSpecs: UpgradeSpecifications
    ): AssetUpgradeResult {
        val asset = assetRegistry[assetId] 
            ?: return AssetUpgradeResult.AssetNotFound
        
        if (!asset.canOperate()) {
            return AssetUpgradeResult.AssetNotOperational
        }
        
        val upgrade = AssetUpgrade(
            id = "UPG-${System.currentTimeMillis()}",
            assetId = assetId,
            upgradeType = upgradeType,
            specifications = upgradeSpecs,
            estimatedCost = calculateUpgradeCost(asset, upgradeType, upgradeSpecs),
            estimatedDuration = calculateUpgradeDuration(upgradeType),
            status = UpgradeStatus.PLANNED
        )
        
        upgradeRegistry[upgrade.id] = upgrade
        
        // Execute upgrade
        return executeUpgrade(upgrade)
    }
    
    /**
     * Request asset disposal
     */
    suspend fun requestDisposal(
        assetId: String,
        disposalMethod: DisposalMethod,
        reason: DisposalReason
    ): DisposalRequestResult {
        val asset = assetRegistry[assetId] 
            ?: return DisposalRequestResult.AssetNotFound
        
        val disposalValue = calculateDisposalValue(asset, disposalMethod)
        
        val request = DisposalRequest(
            id = "DSP-${System.currentTimeMillis()}",
            assetId = assetId,
            disposalMethod = disposalMethod,
            reason = reason,
            requestDate = LocalDateTime.now(),
            estimatedValue = disposalValue,
            status = DisposalStatus.PENDING
        )
        
        disposalQueue[request.id] = request
        
        return DisposalRequestResult.Success(request.id, disposalValue)
    }
    
    /**
     * Execute asset disposal
     */
    suspend fun executeDisposal(disposalRequestId: String): DisposalExecutionResult {
        val request = disposalQueue[disposalRequestId] 
            ?: return DisposalExecutionResult.RequestNotFound
        
        val asset = assetRegistry[request.assetId]
            ?: return DisposalExecutionResult.AssetNotFound
        
        if (request.status != DisposalStatus.PENDING) {
            return DisposalExecutionResult.InvalidStatus
        }
        
        try {
            // Mark asset as non-operational
            asset.isOperational = false
            
            // Calculate actual disposal value
            val actualValue = request.estimatedValue * (0.9 + Math.random() * 0.2) // ±10% variance
            
            // Remove asset from registry
            assetRegistry.remove(request.assetId)
            
            // Update disposal request
            request.status = DisposalStatus.COMPLETED
            request.actualValue = actualValue
            request.completionDate = LocalDateTime.now()
            
            // Archive performance metrics
            val finalMetrics = performanceMetrics.remove(request.assetId)
            
            updateAssetState()
            
            return DisposalExecutionResult.Success(actualValue, finalMetrics)
            
        } catch (e: Exception) {
            request.status = DisposalStatus.FAILED
            return DisposalExecutionResult.Failure(e.message ?: "Disposal execution failed")
        }
    }
    
    /**
     * Get asset performance metrics
     */
    fun getAssetPerformance(assetId: String): AssetPerformanceMetrics? {
        return performanceMetrics[assetId]
    }
    
    /**
     * Get maintenance history for an asset
     */
    fun getMaintenanceHistory(assetId: String): List<MaintenanceRecord> {
        return maintenanceHistory[assetId] ?: emptyList()
    }
    
    /**
     * Update asset performance metrics
     */
    fun updateAssetPerformance(
        assetId: String,
        operatingHours: Double,
        revenue: Double,
        operatingCosts: Double,
        utilizationRate: Double
    ) {
        performanceMetrics[assetId]?.let { metrics ->
            metrics.totalOperatingHours += operatingHours
            metrics.totalRevenue += revenue
            metrics.totalOperatingCosts += operatingCosts
            metrics.utilizationHistory.add(
                UtilizationRecord(LocalDateTime.now(), utilizationRate)
            )
            
            // Keep only last 100 utilization records
            if (metrics.utilizationHistory.size > 100) {
                metrics.utilizationHistory.removeAt(0)
            }
        }
    }
    
    // Private helper methods
    private fun createAssetFromRequest(
        assetType: AssetType,
        ownerId: String,
        request: AssetPurchaseRequest
    ): FlexPortAsset {
        val id = "${assetType.name}-${System.currentTimeMillis()}"
        val location = AssetLocation(
            latitude = request.initialLocation.latitude,
            longitude = request.initialLocation.longitude,
            regionId = request.initialLocation.regionId,
            countryCode = request.initialLocation.countryCode
        )
        
        val maintenanceSchedule = MaintenanceSchedule(
            lastMaintenance = null,
            nextScheduledMaintenance = LocalDateTime.now().plusDays(30),
            maintenanceInterval = 30,
            maintenanceType = MaintenanceType.ROUTINE
        )
        
        return when (assetType) {
            AssetType.CONTAINER_SHIP -> ContainerShip(
                id = id,
                ownerId = ownerId,
                name = request.name,
                purchaseDate = LocalDateTime.now(),
                purchasePrice = request.purchasePrice,
                currentValue = request.purchasePrice,
                condition = AssetCondition.EXCELLENT,
                isOperational = true,
                location = location,
                maintenanceSchedule = maintenanceSchedule,
                specifications = request.specifications as ContainerShipSpecs,
                fuelTank = FuelTank(
                    capacity = (request.specifications as ContainerShipSpecs).fuelConsumption * 100,
                    currentLevel = (request.specifications as ContainerShipSpecs).fuelConsumption * 50,
                    currentFuelPrice = 1.2
                )
            )
            
            AssetType.CARGO_AIRCRAFT -> CargoAircraft(
                id = id,
                ownerId = ownerId,
                name = request.name,
                purchaseDate = LocalDateTime.now(),
                purchasePrice = request.purchasePrice,
                currentValue = request.purchasePrice,
                condition = AssetCondition.EXCELLENT,
                isOperational = true,
                location = location,
                maintenanceSchedule = maintenanceSchedule,
                specifications = request.specifications as CargoAircraftSpecs,
                fuelTank = AircraftFuelTank(
                    capacity = (request.specifications as CargoAircraftSpecs).fuelCapacity,
                    currentLevel = (request.specifications as CargoAircraftSpecs).fuelCapacity * 0.8,
                    currentFuelPrice = 2.5,
                    fuelType = AviationFuelType.JET_A1
                )
            )
            
            AssetType.WAREHOUSE -> Warehouse(
                id = id,
                ownerId = ownerId,
                name = request.name,
                purchaseDate = LocalDateTime.now(),
                purchasePrice = request.purchasePrice,
                currentValue = request.purchasePrice,
                condition = AssetCondition.EXCELLENT,
                isOperational = true,
                location = location,
                maintenanceSchedule = maintenanceSchedule,
                specifications = request.specifications as WarehouseSpecs,
                zones = createDefaultStorageZones(request.specifications as WarehouseSpecs)
            )
            
            else -> throw IllegalArgumentException("Asset type $assetType not supported")
        }
    }
    
    private fun createDefaultStorageZones(specs: WarehouseSpecs): List<StorageZone> {
        val zones = mutableListOf<StorageZone>()
        val zoneCapacity = specs.storageVolume / 4 // 4 default zones
        
        zones.add(StorageZone("ZONE-GEN", "General Storage", zoneCapacity, ZoneType.GENERAL, false, SecurityLevel.BASIC))
        zones.add(StorageZone("ZONE-HV", "High Value", zoneCapacity * 0.5, ZoneType.HIGH_VALUE, false, SecurityLevel.HIGH))
        
        if (specs.temperatureControlled) {
            zones.add(StorageZone("ZONE-TEMP", "Temperature Controlled", zoneCapacity, ZoneType.REFRIGERATED, true, SecurityLevel.MEDIUM))
        }
        
        zones.add(StorageZone("ZONE-HAZ", "Hazmat Storage", zoneCapacity * 0.3, ZoneType.HAZMAT, false, SecurityLevel.HIGH))
        
        return zones
    }
    
    private fun determinePriority(asset: FlexPortAsset, maintenanceType: MaintenanceType): MaintenancePriority {
        return when {
            maintenanceType == MaintenanceType.EMERGENCY -> MaintenancePriority.CRITICAL
            asset.condition == AssetCondition.NEEDS_REPAIR -> MaintenancePriority.HIGH
            asset.condition == AssetCondition.POOR -> MaintenancePriority.MEDIUM
            else -> MaintenancePriority.LOW
        }
    }
    
    private fun calculateMaintenanceEffectiveness(asset: FlexPortAsset, type: MaintenanceType): Double {
        val baseEffectiveness = when (type) {
            MaintenanceType.ROUTINE -> 0.6
            MaintenanceType.PREVENTIVE -> 0.8
            MaintenanceType.SCHEDULED -> 0.75
            MaintenanceType.OVERHAUL -> 0.95
            MaintenanceType.EMERGENCY -> 0.7
        }
        
        // Adjust based on asset condition
        val conditionMultiplier = when (asset.condition) {
            AssetCondition.EXCELLENT -> 1.0
            AssetCondition.GOOD -> 0.95
            AssetCondition.FAIR -> 0.85
            AssetCondition.POOR -> 0.7
            AssetCondition.NEEDS_REPAIR -> 0.5
        }
        
        return baseEffectiveness * conditionMultiplier
    }
    
    private fun improveCondition(current: AssetCondition, improvementFactor: Double): AssetCondition {
        if (Math.random() < improvementFactor) {
            return when (current) {
                AssetCondition.NEEDS_REPAIR -> AssetCondition.POOR
                AssetCondition.POOR -> AssetCondition.FAIR
                AssetCondition.FAIR -> AssetCondition.GOOD
                AssetCondition.GOOD -> AssetCondition.EXCELLENT
                AssetCondition.EXCELLENT -> AssetCondition.EXCELLENT
            }
        }
        return current
    }
    
    private fun calculateUpgradeCost(
        asset: FlexPortAsset,
        upgradeType: AssetUpgradeType,
        specs: UpgradeSpecifications
    ): Double {
        val baseCost = asset.currentValue * 0.1 // 10% of current value
        return when (upgradeType) {
            AssetUpgradeType.TECHNOLOGY -> baseCost * 1.5
            AssetUpgradeType.CAPACITY -> baseCost * 2.0
            AssetUpgradeType.EFFICIENCY -> baseCost * 1.2
            AssetUpgradeType.SAFETY -> baseCost * 0.8
        }
    }
    
    private fun calculateUpgradeDuration(upgradeType: AssetUpgradeType): Int {
        return when (upgradeType) {
            AssetUpgradeType.TECHNOLOGY -> 72 // 3 days
            AssetUpgradeType.CAPACITY -> 168 // 7 days
            AssetUpgradeType.EFFICIENCY -> 48 // 2 days
            AssetUpgradeType.SAFETY -> 24 // 1 day
        }
    }
    
    private fun executeUpgrade(upgrade: AssetUpgrade): AssetUpgradeResult {
        // Simplified upgrade execution
        upgrade.status = UpgradeStatus.COMPLETED
        upgrade.actualCost = upgrade.estimatedCost * (0.9 + Math.random() * 0.2)
        
        val asset = assetRegistry[upgrade.assetId]!!
        asset.currentValue += upgrade.actualCost!! * 0.7 // 70% value retention
        
        return AssetUpgradeResult.Success(upgrade.id, upgrade.actualCost!!)
    }
    
    private fun calculateDisposalValue(asset: FlexPortAsset, method: DisposalMethod): Double {
        val baseValue = asset.currentValue
        return when (method) {
            DisposalMethod.SALE -> baseValue * 0.8 // 80% of current value
            DisposalMethod.AUCTION -> baseValue * 0.6 // 60% of current value
            DisposalMethod.SCRAP -> baseValue * 0.2 // 20% of current value
            DisposalMethod.DONATION -> 0.0 // No value but tax benefits
        }
    }
    
    private fun updateAssetState() {
        _assets.value = assetRegistry.toMap()
    }
}

// Data classes for lifecycle management
data class AssetPurchaseRequest(
    val name: String,
    val purchasePrice: Double,
    val specifications: AssetSpecifications,
    val initialLocation: InitialLocation
)

data class InitialLocation(
    val latitude: Double,
    val longitude: Double,
    val regionId: String,
    val countryCode: String
)

data class MaintenanceJob(
    val id: String,
    val assetId: String,
    val maintenanceType: MaintenanceType,
    val scheduledDate: LocalDateTime,
    val estimatedCost: Double,
    val estimatedDuration: Int,
    var status: MaintenanceStatus,
    val priority: MaintenancePriority,
    var actualStartDate: LocalDateTime? = null,
    var actualEndDate: LocalDateTime? = null,
    var actualCost: Double? = null
)

data class MaintenanceRecord(
    val id: String,
    val assetId: String,
    val maintenanceJobId: String,
    val maintenanceType: MaintenanceType,
    val date: LocalDateTime,
    val cost: Double,
    val duration: Int,
    val effectiveness: Double,
    val conditionBefore: AssetCondition,
    val conditionAfter: AssetCondition
)

data class AssetUpgrade(
    val id: String,
    val assetId: String,
    val upgradeType: AssetUpgradeType,
    val specifications: UpgradeSpecifications,
    val estimatedCost: Double,
    val estimatedDuration: Int,
    var status: UpgradeStatus,
    var actualCost: Double? = null
)

data class DisposalRequest(
    val id: String,
    val assetId: String,
    val disposalMethod: DisposalMethod,
    val reason: DisposalReason,
    val requestDate: LocalDateTime,
    val estimatedValue: Double,
    var status: DisposalStatus,
    var actualValue: Double? = null,
    var completionDate: LocalDateTime? = null
)

data class AssetPerformanceMetrics(
    val assetId: String,
    var totalOperatingHours: Double,
    var totalRevenue: Double,
    var totalOperatingCosts: Double,
    val utilizationHistory: MutableList<UtilizationRecord>,
    var maintenanceEvents: Int
) {
    fun getROI(): Double = if (totalOperatingCosts > 0) totalRevenue / totalOperatingCosts else 0.0
    fun getAverageUtilization(): Double = utilizationHistory.map { it.rate }.average()
}

data class UtilizationRecord(
    val timestamp: LocalDateTime,
    val rate: Double
)

data class UpgradeSpecifications(
    val description: String,
    val expectedBenefit: String,
    val technicalSpecs: Map<String, Any>
)

// Enums
enum class MaintenanceStatus {
    SCHEDULED, IN_PROGRESS, COMPLETED, FAILED, CANCELLED
}

enum class MaintenancePriority {
    CRITICAL, HIGH, MEDIUM, LOW
}

enum class AssetUpgradeType {
    TECHNOLOGY, CAPACITY, EFFICIENCY, SAFETY
}

enum class UpgradeStatus {
    PLANNED, IN_PROGRESS, COMPLETED, FAILED, CANCELLED
}

enum class DisposalMethod {
    SALE, AUCTION, SCRAP, DONATION
}

enum class DisposalReason {
    END_OF_LIFE, OBSOLETE, DAMAGED, COST_INEFFECTIVE, STRATEGIC
}

enum class DisposalStatus {
    PENDING, APPROVED, IN_PROGRESS, COMPLETED, FAILED, CANCELLED
}

// Result sealed classes
sealed class AssetPurchaseResult {
    data class Success(val asset: FlexPortAsset) : AssetPurchaseResult()
    data class Failure(val error: String) : AssetPurchaseResult()
}

sealed class MaintenanceScheduleResult {
    data class Success(val jobId: String) : MaintenanceScheduleResult()
    object AssetNotFound : MaintenanceScheduleResult()
    object AssetNotOperational : MaintenanceScheduleResult()
}

sealed class MaintenanceExecutionResult {
    data class Success(val record: MaintenanceRecord) : MaintenanceExecutionResult()
    object JobNotFound : MaintenanceExecutionResult()
    object AssetNotFound : MaintenanceExecutionResult()
    object InvalidStatus : MaintenanceExecutionResult()
    data class Failure(val error: String) : MaintenanceExecutionResult()
}

sealed class AssetUpgradeResult {
    data class Success(val upgradeId: String, val actualCost: Double) : AssetUpgradeResult()
    object AssetNotFound : AssetUpgradeResult()
    object AssetNotOperational : AssetUpgradeResult()
    data class Failure(val error: String) : AssetUpgradeResult()
}

sealed class DisposalRequestResult {
    data class Success(val requestId: String, val estimatedValue: Double) : DisposalRequestResult()
    object AssetNotFound : DisposalRequestResult()
}

sealed class DisposalExecutionResult {
    data class Success(val actualValue: Double, val finalMetrics: AssetPerformanceMetrics?) : DisposalExecutionResult()
    object RequestNotFound : DisposalExecutionResult()
    object AssetNotFound : DisposalExecutionResult()
    object InvalidStatus : DisposalExecutionResult()
    data class Failure(val error: String) : DisposalExecutionResult()
}