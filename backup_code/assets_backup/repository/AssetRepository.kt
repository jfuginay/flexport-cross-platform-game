package com.flexport.assets.repository

import com.flexport.assets.models.*
import com.flexport.assets.assignment.AssetAssignment
import com.flexport.assets.analytics.AssetPerformanceData
import kotlinx.coroutines.flow.Flow
import java.time.LocalDateTime

/**
 * Repository interface for asset data access
 */
interface AssetRepository {
    
    // Asset CRUD operations
    suspend fun createAsset(asset: FlexPortAsset): Result<String>
    suspend fun getAsset(assetId: String): Result<FlexPortAsset?>
    suspend fun updateAsset(asset: FlexPortAsset): Result<Unit>
    suspend fun deleteAsset(assetId: String): Result<Unit>
    
    // Asset queries
    suspend fun getAllAssets(): Result<List<FlexPortAsset>>
    suspend fun getAssetsByOwner(ownerId: String): Result<List<FlexPortAsset>>
    suspend fun getAssetsByType(assetType: AssetType): Result<List<FlexPortAsset>>
    suspend fun getAssetsByLocation(regionId: String): Result<List<FlexPortAsset>>
    suspend fun getAssetsByCondition(condition: AssetCondition): Result<List<FlexPortAsset>>
    suspend fun getOperationalAssets(): Result<List<FlexPortAsset>>
    
    // Asset search and filtering
    suspend fun searchAssets(query: AssetSearchQuery): Result<List<FlexPortAsset>>
    suspend fun getAssetsInRadius(latitude: Double, longitude: Double, radiusKm: Double): Result<List<FlexPortAsset>>
    suspend fun getAvailableAssets(assetType: AssetType): Result<List<FlexPortAsset>>
    
    // Assignment operations
    suspend fun createAssignment(assignment: AssetAssignment): Result<String>
    suspend fun getAssignment(assignmentId: String): Result<AssetAssignment?>
    suspend fun updateAssignment(assignment: AssetAssignment): Result<Unit>
    suspend fun getAssignmentsByAsset(assetId: String): Result<List<AssetAssignment>>
    suspend fun getActiveAssignments(): Result<List<AssetAssignment>>
    suspend fun getAssignmentHistory(assetId: String): Result<List<AssetAssignment>>
    
    // Performance data
    suspend fun savePerformanceData(performanceData: AssetPerformanceData): Result<Unit>
    suspend fun getPerformanceData(assetId: String): Result<AssetPerformanceData?>
    suspend fun getPerformanceHistory(assetId: String, from: LocalDateTime, to: LocalDateTime): Result<List<AssetPerformanceData>>
    
    // Maintenance operations
    suspend fun getMaintenanceSchedule(assetId: String): Result<MaintenanceSchedule?>
    suspend fun updateMaintenanceSchedule(assetId: String, schedule: MaintenanceSchedule): Result<Unit>
    suspend fun getUpcomingMaintenance(days: Int): Result<List<MaintenanceItem>>
    suspend fun getMaintenanceHistory(assetId: String): Result<List<MaintenanceRecord>>
    
    // Real-time subscriptions
    fun observeAsset(assetId: String): Flow<FlexPortAsset?>
    fun observeAssetsByType(assetType: AssetType): Flow<List<FlexPortAsset>>
    fun observeAssignments(): Flow<List<AssetAssignment>>
    fun observePerformanceAlerts(): Flow<List<PerformanceAlert>>
    
    // Batch operations
    suspend fun batchUpdateAssets(assets: List<FlexPortAsset>): Result<Unit>
    suspend fun batchCreateAssignments(assignments: List<AssetAssignment>): Result<List<String>>
    
    // Statistics and aggregation
    suspend fun getAssetStatistics(): Result<AssetStatistics>
    suspend fun getUtilizationStatistics(assetType: AssetType?): Result<UtilizationStatistics>
    suspend fun getMaintenanceStatistics(): Result<MaintenanceStatistics>
}

/**
 * Asset repository implementation
 */
class AssetRepositoryImpl(
    private val localDataSource: AssetLocalDataSource,
    private val remoteDataSource: AssetRemoteDataSource?,
    private val cacheManager: AssetCacheManager
) : AssetRepository {
    
    override suspend fun createAsset(asset: FlexPortAsset): Result<String> {
        return try {
            // Save to local database
            val localResult = localDataSource.insertAsset(asset.toEntity())
            if (localResult.isFailure) {
                return localResult.map { "" }
            }
            
            // Cache the asset
            cacheManager.cacheAsset(asset)
            
            // Sync to remote if available
            remoteDataSource?.let { remote ->
                try {
                    remote.createAsset(asset.toDto())
                } catch (e: Exception) {
                    // Continue if remote sync fails
                }
            }
            
            Result.success(asset.id)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    override suspend fun getAsset(assetId: String): Result<FlexPortAsset?> {
        return try {
            // Check cache first
            cacheManager.getAsset(assetId)?.let { asset ->
                return Result.success(asset)
            }
            
            // Get from local database
            val localResult = localDataSource.getAsset(assetId)
            if (localResult.isSuccess) {
                val entity = localResult.getOrNull()
                if (entity != null) {
                    val asset = entity.toModel()
                    cacheManager.cacheAsset(asset)
                    return Result.success(asset)
                }
            }
            
            // Try remote if local fails
            remoteDataSource?.let { remote ->
                try {
                    val remoteAsset = remote.getAsset(assetId)
                    if (remoteAsset != null) {
                        val asset = remoteAsset.toModel()
                        // Save to local and cache
                        localDataSource.insertAsset(asset.toEntity())
                        cacheManager.cacheAsset(asset)
                        return Result.success(asset)
                    }
                } catch (e: Exception) {
                    // Continue if remote fails
                }
            }
            
            Result.success(null)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    override suspend fun updateAsset(asset: FlexPortAsset): Result<Unit> {
        return try {
            // Update local database
            val localResult = localDataSource.updateAsset(asset.toEntity())
            if (localResult.isFailure) {
                return localResult
            }
            
            // Update cache
            cacheManager.cacheAsset(asset)
            
            // Sync to remote
            remoteDataSource?.let { remote ->
                try {
                    remote.updateAsset(asset.toDto())
                } catch (e: Exception) {
                    // Continue if remote sync fails
                }
            }
            
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    override suspend fun deleteAsset(assetId: String): Result<Unit> {
        return try {
            // Delete from local database
            val localResult = localDataSource.deleteAsset(assetId)
            if (localResult.isFailure) {
                return localResult
            }
            
            // Remove from cache
            cacheManager.removeAsset(assetId)
            
            // Delete from remote
            remoteDataSource?.let { remote ->
                try {
                    remote.deleteAsset(assetId)
                } catch (e: Exception) {
                    // Continue if remote delete fails
                }
            }
            
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    override suspend fun getAllAssets(): Result<List<FlexPortAsset>> {
        return try {
            val localResult = localDataSource.getAllAssets()
            if (localResult.isSuccess) {
                val assets = localResult.getOrNull()?.map { it.toModel() } ?: emptyList()
                // Cache all assets
                assets.forEach { cacheManager.cacheAsset(it) }
                Result.success(assets)
            } else {
                localResult.map { emptyList() }
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    override suspend fun getAssetsByOwner(ownerId: String): Result<List<FlexPortAsset>> {
        return try {
            val localResult = localDataSource.getAssetsByOwner(ownerId)
            if (localResult.isSuccess) {
                val assets = localResult.getOrNull()?.map { it.toModel() } ?: emptyList()
                Result.success(assets)
            } else {
                localResult.map { emptyList() }
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    override suspend fun getAssetsByType(assetType: AssetType): Result<List<FlexPortAsset>> {
        return try {
            val localResult = localDataSource.getAssetsByType(assetType)
            if (localResult.isSuccess) {
                val assets = localResult.getOrNull()?.map { it.toModel() } ?: emptyList()
                Result.success(assets)
            } else {
                localResult.map { emptyList() }
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    override suspend fun getAssetsByLocation(regionId: String): Result<List<FlexPortAsset>> {
        return try {
            val localResult = localDataSource.getAssetsByLocation(regionId)
            if (localResult.isSuccess) {
                val assets = localResult.getOrNull()?.map { it.toModel() } ?: emptyList()
                Result.success(assets)
            } else {
                localResult.map { emptyList() }
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    override suspend fun getAssetsByCondition(condition: AssetCondition): Result<List<FlexPortAsset>> {
        return try {
            val localResult = localDataSource.getAssetsByCondition(condition)
            if (localResult.isSuccess) {
                val assets = localResult.getOrNull()?.map { it.toModel() } ?: emptyList()
                Result.success(assets)
            } else {
                localResult.map { emptyList() }
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    override suspend fun getOperationalAssets(): Result<List<FlexPortAsset>> {
        return try {
            val localResult = localDataSource.getOperationalAssets()
            if (localResult.isSuccess) {
                val assets = localResult.getOrNull()?.map { it.toModel() } ?: emptyList()
                Result.success(assets)
            } else {
                localResult.map { emptyList() }
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    override suspend fun searchAssets(query: AssetSearchQuery): Result<List<FlexPortAsset>> {
        return try {
            val localResult = localDataSource.searchAssets(query)
            if (localResult.isSuccess) {
                val assets = localResult.getOrNull()?.map { it.toModel() } ?: emptyList()
                Result.success(assets)
            } else {
                localResult.map { emptyList() }
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    override suspend fun getAssetsInRadius(
        latitude: Double, 
        longitude: Double, 
        radiusKm: Double
    ): Result<List<FlexPortAsset>> {
        return try {
            val localResult = localDataSource.getAssetsInRadius(latitude, longitude, radiusKm)
            if (localResult.isSuccess) {
                val assets = localResult.getOrNull()?.map { it.toModel() } ?: emptyList()
                Result.success(assets)
            } else {
                localResult.map { emptyList() }
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    override suspend fun getAvailableAssets(assetType: AssetType): Result<List<FlexPortAsset>> {
        return try {
            // Get operational assets of the specified type that are not currently assigned
            val assetsResult = getAssetsByType(assetType)
            val assignmentsResult = getActiveAssignments()
            
            if (assetsResult.isSuccess && assignmentsResult.isSuccess) {
                val assets = assetsResult.getOrNull() ?: emptyList()
                val assignments = assignmentsResult.getOrNull() ?: emptyList()
                val assignedAssetIds = assignments.map { it.assetId }.toSet()
                
                val availableAssets = assets.filter { asset ->
                    asset.isOperational && 
                    asset.condition != AssetCondition.NEEDS_REPAIR &&
                    asset.id !in assignedAssetIds
                }
                
                Result.success(availableAssets)
            } else {
                Result.failure(Exception("Failed to fetch assets or assignments"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    override suspend fun createAssignment(assignment: AssetAssignment): Result<String> {
        return try {
            val localResult = localDataSource.insertAssignment(assignment.toEntity())
            if (localResult.isFailure) {
                return localResult.map { "" }
            }
            
            // Sync to remote
            remoteDataSource?.let { remote ->
                try {
                    remote.createAssignment(assignment.toDto())
                } catch (e: Exception) {
                    // Continue if remote sync fails
                }
            }
            
            Result.success(assignment.id)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    override suspend fun getAssignment(assignmentId: String): Result<AssetAssignment?> {
        return try {
            val localResult = localDataSource.getAssignment(assignmentId)
            if (localResult.isSuccess) {
                val assignment = localResult.getOrNull()?.toModel()
                Result.success(assignment)
            } else {
                localResult.map { null }
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    override suspend fun updateAssignment(assignment: AssetAssignment): Result<Unit> {
        return try {
            val localResult = localDataSource.updateAssignment(assignment.toEntity())
            if (localResult.isFailure) {
                return localResult
            }
            
            // Sync to remote
            remoteDataSource?.let { remote ->
                try {
                    remote.updateAssignment(assignment.toDto())
                } catch (e: Exception) {
                    // Continue if remote sync fails
                }
            }
            
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    override suspend fun getAssignmentsByAsset(assetId: String): Result<List<AssetAssignment>> {
        return try {
            val localResult = localDataSource.getAssignmentsByAsset(assetId)
            if (localResult.isSuccess) {
                val assignments = localResult.getOrNull()?.map { it.toModel() } ?: emptyList()
                Result.success(assignments)
            } else {
                localResult.map { emptyList() }
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    override suspend fun getActiveAssignments(): Result<List<AssetAssignment>> {
        return try {
            val localResult = localDataSource.getActiveAssignments()
            if (localResult.isSuccess) {
                val assignments = localResult.getOrNull()?.map { it.toModel() } ?: emptyList()
                Result.success(assignments)
            } else {
                localResult.map { emptyList() }
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    override suspend fun getAssignmentHistory(assetId: String): Result<List<AssetAssignment>> {
        return try {
            val localResult = localDataSource.getAssignmentHistory(assetId)
            if (localResult.isSuccess) {
                val assignments = localResult.getOrNull()?.map { it.toModel() } ?: emptyList()
                Result.success(assignments)
            } else {
                localResult.map { emptyList() }
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    override suspend fun savePerformanceData(performanceData: AssetPerformanceData): Result<Unit> {
        return try {
            val localResult = localDataSource.insertPerformanceData(performanceData.toEntity())
            if (localResult.isFailure) {
                return localResult
            }
            
            // Sync to remote
            remoteDataSource?.let { remote ->
                try {
                    remote.savePerformanceData(performanceData.toDto())
                } catch (e: Exception) {
                    // Continue if remote sync fails
                }
            }
            
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    override suspend fun getPerformanceData(assetId: String): Result<AssetPerformanceData?> {
        return try {
            val localResult = localDataSource.getPerformanceData(assetId)
            if (localResult.isSuccess) {
                val performanceData = localResult.getOrNull()?.toModel()
                Result.success(performanceData)
            } else {
                localResult.map { null }
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    override suspend fun getPerformanceHistory(
        assetId: String, 
        from: LocalDateTime, 
        to: LocalDateTime
    ): Result<List<AssetPerformanceData>> {
        return try {
            val localResult = localDataSource.getPerformanceHistory(assetId, from, to)
            if (localResult.isSuccess) {
                val history = localResult.getOrNull()?.map { it.toModel() } ?: emptyList()
                Result.success(history)
            } else {
                localResult.map { emptyList() }
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    override suspend fun getMaintenanceSchedule(assetId: String): Result<MaintenanceSchedule?> {
        return try {
            val localResult = localDataSource.getMaintenanceSchedule(assetId)
            if (localResult.isSuccess) {
                val schedule = localResult.getOrNull()?.toModel()
                Result.success(schedule)
            } else {
                localResult.map { null }
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    override suspend fun updateMaintenanceSchedule(
        assetId: String, 
        schedule: MaintenanceSchedule
    ): Result<Unit> {
        return try {
            val localResult = localDataSource.updateMaintenanceSchedule(assetId, schedule.toEntity())
            if (localResult.isFailure) {
                return localResult
            }
            
            // Sync to remote
            remoteDataSource?.let { remote ->
                try {
                    remote.updateMaintenanceSchedule(assetId, schedule.toDto())
                } catch (e: Exception) {
                    // Continue if remote sync fails
                }
            }
            
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    override suspend fun getUpcomingMaintenance(days: Int): Result<List<MaintenanceItem>> {
        return try {
            val localResult = localDataSource.getUpcomingMaintenance(days)
            if (localResult.isSuccess) {
                val items = localResult.getOrNull()?.map { it.toModel() } ?: emptyList()
                Result.success(items)
            } else {
                localResult.map { emptyList() }
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    override suspend fun getMaintenanceHistory(assetId: String): Result<List<MaintenanceRecord>> {
        return try {
            val localResult = localDataSource.getMaintenanceHistory(assetId)
            if (localResult.isSuccess) {
                val history = localResult.getOrNull()?.map { it.toModel() } ?: emptyList()
                Result.success(history)
            } else {
                localResult.map { emptyList() }
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    override fun observeAsset(assetId: String): Flow<FlexPortAsset?> {
        return localDataSource.observeAsset(assetId)
    }
    
    override fun observeAssetsByType(assetType: AssetType): Flow<List<FlexPortAsset>> {
        return localDataSource.observeAssetsByType(assetType)
    }
    
    override fun observeAssignments(): Flow<List<AssetAssignment>> {
        return localDataSource.observeAssignments()
    }
    
    override fun observePerformanceAlerts(): Flow<List<PerformanceAlert>> {
        return localDataSource.observePerformanceAlerts()
    }
    
    override suspend fun batchUpdateAssets(assets: List<FlexPortAsset>): Result<Unit> {
        return try {
            val entities = assets.map { it.toEntity() }
            val localResult = localDataSource.batchUpdateAssets(entities)
            if (localResult.isFailure) {
                return localResult
            }
            
            // Update cache
            assets.forEach { cacheManager.cacheAsset(it) }
            
            // Sync to remote
            remoteDataSource?.let { remote ->
                try {
                    remote.batchUpdateAssets(assets.map { it.toDto() })
                } catch (e: Exception) {
                    // Continue if remote sync fails
                }
            }
            
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    override suspend fun batchCreateAssignments(assignments: List<AssetAssignment>): Result<List<String>> {
        return try {
            val entities = assignments.map { it.toEntity() }
            val localResult = localDataSource.batchCreateAssignments(entities)
            if (localResult.isFailure) {
                return localResult.map { emptyList() }
            }
            
            // Sync to remote
            remoteDataSource?.let { remote ->
                try {
                    remote.batchCreateAssignments(assignments.map { it.toDto() })
                } catch (e: Exception) {
                    // Continue if remote sync fails
                }
            }
            
            Result.success(assignments.map { it.id })
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    override suspend fun getAssetStatistics(): Result<AssetStatistics> {
        return try {
            val localResult = localDataSource.getAssetStatistics()
            if (localResult.isSuccess) {
                val stats = localResult.getOrNull()?.toModel()
                Result.success(stats ?: AssetStatistics.empty())
            } else {
                localResult.map { AssetStatistics.empty() }
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    override suspend fun getUtilizationStatistics(assetType: AssetType?): Result<UtilizationStatistics> {
        return try {
            val localResult = localDataSource.getUtilizationStatistics(assetType)
            if (localResult.isSuccess) {
                val stats = localResult.getOrNull()?.toModel()
                Result.success(stats ?: UtilizationStatistics.empty())
            } else {
                localResult.map { UtilizationStatistics.empty() }
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    override suspend fun getMaintenanceStatistics(): Result<MaintenanceStatistics> {
        return try {
            val localResult = localDataSource.getMaintenanceStatistics()
            if (localResult.isSuccess) {
                val stats = localResult.getOrNull()?.toModel()
                Result.success(stats ?: MaintenanceStatistics.empty())
            } else {
                localResult.map { MaintenanceStatistics.empty() }
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}

// Data source interfaces
interface AssetLocalDataSource {
    suspend fun insertAsset(asset: AssetEntity): Result<Unit>
    suspend fun getAsset(assetId: String): Result<AssetEntity?>
    suspend fun updateAsset(asset: AssetEntity): Result<Unit>
    suspend fun deleteAsset(assetId: String): Result<Unit>
    suspend fun getAllAssets(): Result<List<AssetEntity>>
    suspend fun getAssetsByOwner(ownerId: String): Result<List<AssetEntity>>
    suspend fun getAssetsByType(assetType: AssetType): Result<List<AssetEntity>>
    suspend fun getAssetsByLocation(regionId: String): Result<List<AssetEntity>>
    suspend fun getAssetsByCondition(condition: AssetCondition): Result<List<AssetEntity>>
    suspend fun getOperationalAssets(): Result<List<AssetEntity>>
    suspend fun searchAssets(query: AssetSearchQuery): Result<List<AssetEntity>>
    suspend fun getAssetsInRadius(latitude: Double, longitude: Double, radiusKm: Double): Result<List<AssetEntity>>
    
    suspend fun insertAssignment(assignment: AssetAssignmentEntity): Result<Unit>
    suspend fun getAssignment(assignmentId: String): Result<AssetAssignmentEntity?>
    suspend fun updateAssignment(assignment: AssetAssignmentEntity): Result<Unit>
    suspend fun getAssignmentsByAsset(assetId: String): Result<List<AssetAssignmentEntity>>
    suspend fun getActiveAssignments(): Result<List<AssetAssignmentEntity>>
    suspend fun getAssignmentHistory(assetId: String): Result<List<AssetAssignmentEntity>>
    
    suspend fun insertPerformanceData(performanceData: AssetPerformanceEntity): Result<Unit>
    suspend fun getPerformanceData(assetId: String): Result<AssetPerformanceEntity?>
    suspend fun getPerformanceHistory(assetId: String, from: LocalDateTime, to: LocalDateTime): Result<List<AssetPerformanceEntity>>
    
    suspend fun getMaintenanceSchedule(assetId: String): Result<MaintenanceScheduleEntity?>
    suspend fun updateMaintenanceSchedule(assetId: String, schedule: MaintenanceScheduleEntity): Result<Unit>
    suspend fun getUpcomingMaintenance(days: Int): Result<List<MaintenanceItemEntity>>
    suspend fun getMaintenanceHistory(assetId: String): Result<List<MaintenanceRecordEntity>>
    
    suspend fun batchUpdateAssets(assets: List<AssetEntity>): Result<Unit>
    suspend fun batchCreateAssignments(assignments: List<AssetAssignmentEntity>): Result<Unit>
    
    suspend fun getAssetStatistics(): Result<AssetStatisticsEntity?>
    suspend fun getUtilizationStatistics(assetType: AssetType?): Result<UtilizationStatisticsEntity?>
    suspend fun getMaintenanceStatistics(): Result<MaintenanceStatisticsEntity?>
    
    fun observeAsset(assetId: String): Flow<FlexPortAsset?>
    fun observeAssetsByType(assetType: AssetType): Flow<List<FlexPortAsset>>
    fun observeAssignments(): Flow<List<AssetAssignment>>
    fun observePerformanceAlerts(): Flow<List<PerformanceAlert>>
}

interface AssetRemoteDataSource {
    suspend fun createAsset(asset: AssetDto): AssetDto
    suspend fun getAsset(assetId: String): AssetDto?
    suspend fun updateAsset(asset: AssetDto): AssetDto
    suspend fun deleteAsset(assetId: String)
    
    suspend fun createAssignment(assignment: AssetAssignmentDto): AssetAssignmentDto
    suspend fun updateAssignment(assignment: AssetAssignmentDto): AssetAssignmentDto
    
    suspend fun savePerformanceData(performanceData: AssetPerformanceDto)
    suspend fun updateMaintenanceSchedule(assetId: String, schedule: MaintenanceScheduleDto)
    
    suspend fun batchUpdateAssets(assets: List<AssetDto>)
    suspend fun batchCreateAssignments(assignments: List<AssetAssignmentDto>)
}

interface AssetCacheManager {
    fun cacheAsset(asset: FlexPortAsset)
    fun getAsset(assetId: String): FlexPortAsset?
    fun removeAsset(assetId: String)
    fun clearCache()
    fun getCacheStatistics(): CacheStatistics
}

// Search and filter data classes
data class AssetSearchQuery(
    val query: String? = null,
    val assetTypes: List<AssetType>? = null,
    val ownerId: String? = null,
    val regionId: String? = null,
    val conditions: List<AssetCondition>? = null,
    val operationalOnly: Boolean = false,
    val assignedOnly: Boolean? = null,
    val minValue: Double? = null,
    val maxValue: Double? = null,
    val sortBy: AssetSortBy = AssetSortBy.NAME,
    val sortOrder: SortOrder = SortOrder.ASC,
    val limit: Int? = null,
    val offset: Int = 0
)

data class AssetStatistics(
    val totalAssets: Int,
    val assetsByType: Map<AssetType, Int>,
    val operationalAssets: Int,
    val totalValue: Double,
    val averageUtilization: Double,
    val maintenanceScheduled: Int
) {
    companion object {
        fun empty() = AssetStatistics(0, emptyMap(), 0, 0.0, 0.0, 0)
    }
}

data class UtilizationStatistics(
    val averageUtilization: Double,
    val utilizationByType: Map<AssetType, Double>,
    val underutilizedAssets: Int,
    val overutilizedAssets: Int,
    val totalCapacity: Double,
    val usedCapacity: Double
) {
    companion object {
        fun empty() = UtilizationStatistics(0.0, emptyMap(), 0, 0, 0.0, 0.0)
    }
}

data class MaintenanceStatistics(
    val scheduledMaintenance: Int,
    val overdueMaintenance: Int,
    val totalMaintenanceCost: Double,
    val averageMaintenanceInterval: Double,
    val maintenanceByType: Map<MaintenanceType, Int>
) {
    companion object {
        fun empty() = MaintenanceStatistics(0, 0, 0.0, 0.0, emptyMap())
    }
}

data class CacheStatistics(
    val totalCachedAssets: Int,
    val cacheHitRate: Double,
    val cacheMissRate: Double,
    val lastClearTime: LocalDateTime?
)

// Enums
enum class AssetSortBy {
    NAME, TYPE, VALUE, CONDITION, UTILIZATION, PURCHASE_DATE, LAST_MAINTENANCE
}

enum class SortOrder {
    ASC, DESC
}

// Extension functions for mapping (simplified - would need full implementation)
private fun FlexPortAsset.toEntity(): AssetEntity {
    // Implementation would map domain model to database entity
    return AssetEntity(
        id = this.id,
        ownerId = this.ownerId,
        name = this.name,
        assetType = this.assetType,
        currentValue = this.currentValue,
        condition = this.condition,
        isOperational = this.isOperational
        // ... other fields
    )
}

private fun AssetEntity.toModel(): FlexPortAsset {
    // Implementation would map database entity to domain model
    // This is simplified - actual implementation would need to handle all asset types
    TODO("Full implementation needed based on asset type")
}

private fun FlexPortAsset.toDto(): AssetDto {
    // Implementation would map domain model to API DTO
    return AssetDto(
        id = this.id,
        ownerId = this.ownerId,
        name = this.name,
        assetType = this.assetType.name,
        currentValue = this.currentValue
        // ... other fields
    )
}

private fun AssetDto.toModel(): FlexPortAsset {
    // Implementation would map API DTO to domain model
    TODO("Full implementation needed")
}

private fun AssetAssignment.toEntity(): AssetAssignmentEntity {
    return AssetAssignmentEntity(
        id = this.id,
        assetId = this.assetId,
        assetType = this.assetType,
        assignmentType = this.assignmentType,
        targetId = this.targetId,
        startDate = this.startDate,
        priority = this.priority,
        status = this.status
        // ... other fields
    )
}

private fun AssetAssignmentEntity.toModel(): AssetAssignment {
    return AssetAssignment(
        id = this.id,
        assetId = this.assetId,
        assetType = this.assetType,
        assignmentType = this.assignmentType,
        targetId = this.targetId,
        startDate = this.startDate,
        priority = this.priority,
        status = this.status,
        estimatedDuration = this.estimatedDuration,
        estimatedRevenue = this.estimatedRevenue
        // ... other fields
    )
}

private fun AssetAssignment.toDto(): AssetAssignmentDto {
    return AssetAssignmentDto(
        id = this.id,
        assetId = this.assetId,
        targetId = this.targetId,
        status = this.status.name
        // ... other fields
    )
}

private fun AssetPerformanceData.toEntity(): AssetPerformanceEntity {
    return AssetPerformanceEntity(
        assetId = this.assetId,
        assetType = this.assetType,
        trackingStartDate = this.trackingStartDate,
        totalOperatingHours = this.totalOperatingHours,
        totalRevenue = this.totalRevenue,
        totalOperatingCosts = this.totalOperatingCosts
        // ... other fields
    )
}

private fun AssetPerformanceEntity.toModel(): AssetPerformanceData {
    TODO("Implementation needed")
}

private fun AssetPerformanceData.toDto(): AssetPerformanceDto {
    return AssetPerformanceDto(
        assetId = this.assetId,
        totalRevenue = this.totalRevenue,
        totalOperatingCosts = this.totalOperatingCosts
        // ... other fields
    )
}

private fun MaintenanceSchedule.toEntity(): MaintenanceScheduleEntity {
    return MaintenanceScheduleEntity(
        lastMaintenance = this.lastMaintenance,
        nextScheduledMaintenance = this.nextScheduledMaintenance,
        maintenanceInterval = this.maintenanceInterval,
        maintenanceType = this.maintenanceType
    )
}

private fun MaintenanceScheduleEntity.toModel(): MaintenanceSchedule {
    return MaintenanceSchedule(
        lastMaintenance = this.lastMaintenance,
        nextScheduledMaintenance = this.nextScheduledMaintenance,
        maintenanceInterval = this.maintenanceInterval,
        maintenanceType = this.maintenanceType
    )
}

private fun MaintenanceSchedule.toDto(): MaintenanceScheduleDto {
    return MaintenanceScheduleDto(
        nextScheduledMaintenance = this.nextScheduledMaintenance.toString(),
        maintenanceType = this.maintenanceType.name
    )
}

private fun MaintenanceItemEntity.toModel(): MaintenanceItem {
    TODO("Implementation needed")
}

private fun MaintenanceRecordEntity.toModel(): MaintenanceRecord {
    TODO("Implementation needed")
}

private fun AssetStatisticsEntity.toModel(): AssetStatistics {
    TODO("Implementation needed")
}

private fun UtilizationStatisticsEntity.toModel(): UtilizationStatistics {
    TODO("Implementation needed")
}

private fun MaintenanceStatisticsEntity.toModel(): MaintenanceStatistics {
    TODO("Implementation needed")
}

// Entity and DTO placeholder classes (would be implemented separately)
data class AssetEntity(
    val id: String,
    val ownerId: String,
    val name: String,
    val assetType: AssetType,
    val currentValue: Double,
    val condition: AssetCondition,
    val isOperational: Boolean
)

data class AssetAssignmentEntity(
    val id: String,
    val assetId: String,
    val assetType: AssetType,
    val assignmentType: AssignmentType,
    val targetId: String,
    val startDate: LocalDateTime,
    val priority: AssignmentPriority,
    val status: AssignmentStatus,
    val estimatedDuration: Int?,
    val estimatedRevenue: Double
)

data class AssetPerformanceEntity(
    val assetId: String,
    val assetType: AssetType,
    val trackingStartDate: LocalDateTime,
    val totalOperatingHours: Double,
    val totalRevenue: Double,
    val totalOperatingCosts: Double
)

data class MaintenanceScheduleEntity(
    val lastMaintenance: LocalDateTime?,
    val nextScheduledMaintenance: LocalDateTime,
    val maintenanceInterval: Int,
    val maintenanceType: MaintenanceType
)

data class MaintenanceItemEntity(val placeholder: String)
data class MaintenanceRecordEntity(val placeholder: String)
data class AssetStatisticsEntity(val placeholder: String)
data class UtilizationStatisticsEntity(val placeholder: String)
data class MaintenanceStatisticsEntity(val placeholder: String)

data class AssetDto(
    val id: String,
    val ownerId: String,
    val name: String,
    val assetType: String,
    val currentValue: Double
)

data class AssetAssignmentDto(
    val id: String,
    val assetId: String,
    val targetId: String,
    val status: String
)

data class AssetPerformanceDto(
    val assetId: String,
    val totalRevenue: Double,
    val totalOperatingCosts: Double
)

data class MaintenanceScheduleDto(
    val nextScheduledMaintenance: String,
    val maintenanceType: String
)