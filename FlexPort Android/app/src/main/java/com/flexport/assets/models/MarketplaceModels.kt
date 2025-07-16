package com.flexport.assets.models

import kotlinx.serialization.Serializable

/**
 * Represents an asset available for purchase in the marketplace
 */
@Serializable
data class MarketplaceAsset(
    val id: String,
    val name: String,
    val type: AssetType,
    val price: Double,
    val specifications: AssetSpecifications,
    val condition: com.flexport.economics.models.AssetCondition,
    val availableQuantity: Int = 1,
    val sellerId: String,
    val sellerName: String,
    val description: String = "",
    val images: List<String> = emptyList(),
    val location: AssetLocation,
    val listingDate: Long = System.currentTimeMillis(),
    val expirationDate: Long? = null,
    val featured: Boolean = false,
    val negotiable: Boolean = false,
    val minimumOfferPrice: Double? = null
)

/**
 * Events related to asset management
 */
@Serializable
sealed class AssetEvent {
    abstract val timestamp: Long
    abstract val assetId: String
    
    @Serializable
    data class AssetPurchased(
        override val assetId: String,
        val buyerId: String,
        val sellerId: String,
        val price: Double,
        val assetType: AssetType,
        override val timestamp: Long = System.currentTimeMillis()
    ) : AssetEvent()
    
    @Serializable
    data class AssetSold(
        override val assetId: String,
        val sellerId: String,
        val buyerId: String,
        val price: Double,
        val profit: Double,
        override val timestamp: Long = System.currentTimeMillis()
    ) : AssetEvent()
    
    @Serializable
    data class AssetListed(
        override val assetId: String,
        val sellerId: String,
        val listingPrice: Double,
        val marketplaceAssetId: String,
        override val timestamp: Long = System.currentTimeMillis()
    ) : AssetEvent()
    
    @Serializable
    data class AssetDelisted(
        override val assetId: String,
        val reason: String,
        override val timestamp: Long = System.currentTimeMillis()
    ) : AssetEvent()
    
    @Serializable
    data class AssetMaintenanceRequired(
        override val assetId: String,
        val maintenanceType: MaintenanceType,
        val estimatedCost: Double,
        val urgency: MaintenanceUrgency,
        override val timestamp: Long = System.currentTimeMillis()
    ) : AssetEvent()
    
    @Serializable
    data class AssetMaintenanceCompleted(
        override val assetId: String,
        val maintenanceType: MaintenanceType,
        val actualCost: Double,
        val downtime: Long,
        override val timestamp: Long = System.currentTimeMillis()
    ) : AssetEvent()
    
    @Serializable
    data class AssetConditionChanged(
        override val assetId: String,
        val previousCondition: com.flexport.economics.models.AssetCondition,
        val newCondition: com.flexport.economics.models.AssetCondition,
        val reason: String,
        override val timestamp: Long = System.currentTimeMillis()
    ) : AssetEvent()
    
    @Serializable
    data class AssetLocationChanged(
        override val assetId: String,
        val previousLocation: AssetLocation,
        val newLocation: AssetLocation,
        override val timestamp: Long = System.currentTimeMillis()
    ) : AssetEvent()
    
    @Serializable
    data class AssetUtilizationUpdated(
        override val assetId: String,
        val utilizationRate: Double,
        val revenue: Double,
        val operatingCosts: Double,
        override val timestamp: Long = System.currentTimeMillis()
    ) : AssetEvent()
    
    @Serializable
    data class AssetDecommissioned(
        override val assetId: String,
        val reason: String,
        val salvageValue: Double,
        override val timestamp: Long = System.currentTimeMillis()
    ) : AssetEvent()
}

/**
 * Urgency levels for maintenance
 */
@Serializable
enum class MaintenanceUrgency {
    LOW,
    MEDIUM,
    HIGH,
    CRITICAL
}

/**
 * Filter options for marketplace assets
 */
@Serializable
data class MarketplaceFilter(
    val assetTypes: List<AssetType>? = null,
    val minPrice: Double? = null,
    val maxPrice: Double? = null,
    val conditions: List<com.flexport.economics.models.AssetCondition>? = null,
    val locations: List<String>? = null,
    val sellerId: String? = null,
    val featured: Boolean? = null,
    val sortBy: MarketplaceSortOption = MarketplaceSortOption.PRICE_LOW_TO_HIGH
)

/**
 * Sort options for marketplace
 */
@Serializable
enum class MarketplaceSortOption {
    PRICE_LOW_TO_HIGH,
    PRICE_HIGH_TO_LOW,
    NEWEST_FIRST,
    CONDITION_BEST_FIRST,
    NAME_ALPHABETICAL
}

/**
 * Asset offer for negotiation
 */
@Serializable
data class AssetOffer(
    val id: String,
    val marketplaceAssetId: String,
    val buyerId: String,
    val offerPrice: Double,
    val message: String = "",
    val status: OfferStatus = OfferStatus.PENDING,
    val createdAt: Long = System.currentTimeMillis(),
    val expiresAt: Long = System.currentTimeMillis() + 48 * 60 * 60 * 1000L // 48 hours
)

/**
 * Status of an asset offer
 */
@Serializable
enum class OfferStatus {
    PENDING,
    ACCEPTED,
    REJECTED,
    COUNTER_OFFERED,
    EXPIRED,
    CANCELLED
}