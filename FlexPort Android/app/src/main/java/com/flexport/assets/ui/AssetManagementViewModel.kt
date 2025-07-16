package com.flexport.assets.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.flexport.assets.models.*
import com.flexport.assets.services.AssetManager
import com.flexport.assets.services.AssetOperationEvent
import com.flexport.economics.services.EconomicEngine
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

/**
 * ViewModel for Asset Management Screen
 */
class AssetManagementViewModel : ViewModel() {
    
    private val assetManager = AssetManager.getInstance()
    private val economicEngine = EconomicEngine.getInstance()
    private val playerId = "player1" // TODO: Get from game state
    
    private val _uiState = MutableStateFlow(AssetManagementUiState())
    val uiState: StateFlow<AssetManagementUiState> = _uiState.asStateFlow()
    
    private val _events = MutableSharedFlow<AssetManagementEvent>()
    val events: SharedFlow<AssetManagementEvent> = _events.asSharedFlow()
    
    init {
        // Initialize player if needed
        economicEngine.initializePlayer(playerId)
        
        // Load player assets
        loadAssets()
        
        // Listen to asset events
        listenToAssetEvents()
    }
    
    private fun loadAssets() {
        viewModelScope.launch {
            assetManager.getPlayerAssets(playerId).collect { assets ->
                val totalValue = assets.sumOf { it.currentValue }
                val dailyCosts = assets.sumOf { it.getTotalDailyCost() }
                val playerBalance = economicEngine.getPlayerBalance(playerId)
                
                _uiState.update { currentState ->
                    currentState.copy(
                        assets = assets,
                        totalAssetValue = totalValue,
                        totalDailyCosts = dailyCosts,
                        playerBalance = playerBalance,
                        isLoading = false
                    )
                }
            }
        }
    }
    
    private fun listenToAssetEvents() {
        viewModelScope.launch {
            assetManager.assetEvents.collect { event ->
                when (event) {
                    is AssetOperationEvent.AssetPurchased -> {
                        _events.emit(AssetManagementEvent.ShowMessage(
                            "Purchased ${event.asset.name} for ${formatCurrency(event.price)}"
                        ))
                    }
                    is AssetOperationEvent.AssetSold -> {
                        _events.emit(AssetManagementEvent.ShowMessage(
                            "Sold ${event.asset.name} for ${formatCurrency(event.price)}"
                        ))
                    }
                    is AssetOperationEvent.MaintenancePerformed -> {
                        _events.emit(AssetManagementEvent.ShowMessage(
                            "Maintenance completed on ${event.asset.name}"
                        ))
                    }
                    is AssetOperationEvent.ConditionDegraded -> {
                        _events.emit(AssetManagementEvent.ShowWarning(
                            "${event.asset.name} condition degraded to ${event.newCondition.name}"
                        ))
                    }
                    is AssetOperationEvent.AssetBrokenDown -> {
                        _events.emit(AssetManagementEvent.ShowError(
                            "${event.asset.name} has broken down! Maintenance required."
                        ))
                    }
                    is AssetOperationEvent.RevenueGenerated -> {
                        _events.emit(AssetManagementEvent.ShowMessage(
                            "Revenue generated: ${formatCurrency(event.amount)} from ${event.asset.name}"
                        ))
                    }
                }
            }
        }
    }
    
    fun sellAsset(asset: Asset) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            
            assetManager.sellAsset(asset.id).fold(
                onSuccess = { salePrice ->
                    _events.emit(AssetManagementEvent.AssetSold(asset, salePrice))
                },
                onFailure = { error ->
                    _events.emit(AssetManagementEvent.ShowError(
                        error.message ?: "Failed to sell asset"
                    ))
                }
            )
            
            _uiState.update { it.copy(isLoading = false) }
        }
    }
    
    fun performMaintenance(asset: Asset) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            
            // Show maintenance dialog
            _events.emit(AssetManagementEvent.ShowMaintenanceDialog(asset))
            
            _uiState.update { it.copy(isLoading = false) }
        }
    }
    
    fun confirmMaintenance(asset: Asset, maintenanceType: MaintenanceType) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            
            assetManager.performMaintenance(asset.id, maintenanceType).fold(
                onSuccess = {
                    _events.emit(AssetManagementEvent.MaintenanceCompleted(asset))
                },
                onFailure = { error ->
                    _events.emit(AssetManagementEvent.ShowError(
                        error.message ?: "Failed to perform maintenance"
                    ))
                }
            )
            
            _uiState.update { it.copy(isLoading = false) }
        }
    }
    
    fun navigateToAssetDetails(asset: Asset) {
        viewModelScope.launch {
            _events.emit(AssetManagementEvent.NavigateToAssetDetails(asset))
        }
    }
    
    fun navigateToMarketplace() {
        viewModelScope.launch {
            _events.emit(AssetManagementEvent.NavigateToMarketplace)
        }
    }
    
    private fun formatCurrency(amount: Double): String {
        return "$${String.format("%,.2f", amount)}"
    }
}

/**
 * UI State for Asset Management Screen
 */
data class AssetManagementUiState(
    val assets: List<Asset> = emptyList(),
    val totalAssetValue: Double = 0.0,
    val totalDailyCosts: Double = 0.0,
    val playerBalance: Double = 0.0,
    val isLoading: Boolean = true,
    val selectedCategory: AssetType? = null,
    val sortOption: AssetSortOption = AssetSortOption.NAME
)

enum class AssetSortOption(val displayName: String) {
    NAME("Name"),
    VALUE("Value"),
    CONDITION("Condition"),
    TYPE("Type"),
    OPERATING_COST("Cost")
}

/**
 * Events for Asset Management Screen
 */
sealed class AssetManagementEvent {
    data class ShowMessage(val message: String) : AssetManagementEvent()
    data class ShowWarning(val message: String) : AssetManagementEvent()
    data class ShowError(val message: String) : AssetManagementEvent()
    data class NavigateToAssetDetails(val asset: Asset) : AssetManagementEvent()
    object NavigateToMarketplace : AssetManagementEvent()
    data class ShowMaintenanceDialog(val asset: Asset) : AssetManagementEvent()
    data class AssetSold(val asset: Asset, val price: Double) : AssetManagementEvent()
    data class MaintenanceCompleted(val asset: Asset) : AssetManagementEvent()
}