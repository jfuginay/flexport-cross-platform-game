package com.flexport.assets.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.*
import androidx.compose.material.ExperimentalMaterialApi
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.filled.DirectionsBoat
import androidx.compose.material.icons.filled.Flight
import androidx.compose.material.icons.filled.Warehouse
import androidx.compose.material.icons.filled.Anchor
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.Train
import androidx.compose.material.icons.filled.Construction
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.flexport.assets.models.*
import com.flexport.economics.models.AssetCondition
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterialApi::class)
@Composable
fun AssetManagementScreen(
    assets: List<Asset> = emptyList(),
    onNavigateBack: () -> Unit = {},
    onAssetClick: (Asset) -> Unit = {},
    onSellAsset: (Asset) -> Unit = {},
    onMaintenanceClick: (Asset) -> Unit = {},
    modifier: Modifier = Modifier
) {
    var selectedCategory by remember { mutableStateOf<AssetType?>(null) }
    var sortBy by remember { mutableStateOf(AssetSortOption.NAME) }
    var showFilters by remember { mutableStateOf(false) }
    
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        // Header
        AssetManagementHeader(
            assetCount = assets.size,
            totalValue = assets.sumOf { it.currentValue },
            onNavigateBack = onNavigateBack,
            onToggleFilters = { showFilters = !showFilters }
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        // Filters
        AnimatedVisibility(
            visible = showFilters,
            enter = expandVertically(),
            exit = shrinkVertically()
        ) {
            AssetFilters(
                selectedCategory = selectedCategory,
                onCategorySelected = { selectedCategory = it },
                sortBy = sortBy,
                onSortByChanged = { sortBy = it }
            )
        }
        
        // Asset Summary Cards
        AssetSummaryCards(assets = assets)
        
        Spacer(modifier = Modifier.height(16.dp))
        
        // Asset List
        val filteredAssets = assets
            .filter { selectedCategory == null || it.type == selectedCategory }
            .sortedWith { a, b ->
                when (sortBy) {
                    AssetSortOption.NAME -> a.name.compareTo(b.name)
                    AssetSortOption.VALUE -> b.currentValue.compareTo(a.currentValue)
                    AssetSortOption.CONDITION -> a.condition.ordinal.compareTo(b.condition.ordinal)
                    AssetSortOption.TYPE -> a.type.name.compareTo(b.type.name)
                    AssetSortOption.OPERATING_COST -> b.getTotalDailyCost().compareTo(a.getTotalDailyCost())
                }
            }
        
        LazyColumn(
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            items(filteredAssets) { asset ->
                AssetCard(
                    asset = asset,
                    onClick = { onAssetClick(asset) },
                    onSellClick = { onSellAsset(asset) },
                    onMaintenanceClick = { onMaintenanceClick(asset) }
                )
            }
        }
    }
}

@Composable
private fun AssetManagementHeader(
    assetCount: Int,
    totalValue: Double,
    onNavigateBack: () -> Unit,
    onToggleFilters: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = 4.dp,
        shape = RoundedCornerShape(12.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    IconButton(onClick = onNavigateBack) {
                        Icon(
                            imageVector = Icons.Default.ArrowBack,
                            contentDescription = "Back",
                            tint = MaterialTheme.colors.primary
                        )
                    }
                    
                    Column {
                        Text(
                            text = "Asset Management",
                            style = MaterialTheme.typography.h4,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colors.primary
                        )
                        Text(
                            text = "$assetCount assets owned",
                            style = MaterialTheme.typography.body2,
                            color = MaterialTheme.colors.onSurface.copy(alpha = 0.7f)
                        )
                    }
                }
                
                IconButton(onClick = onToggleFilters) {
                    Icon(
                        imageVector = Icons.Default.FilterList,
                        contentDescription = "Filters",
                        tint = MaterialTheme.colors.primary
                    )
                }
            }
            
            Spacer(modifier = Modifier.height(12.dp))
            
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        text = formatCurrency(totalValue),
                        style = MaterialTheme.typography.h5,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colors.primary
                    )
                    Text(
                        text = "Total Value",
                        style = MaterialTheme.typography.caption,
                        color = MaterialTheme.colors.onSurface.copy(alpha = 0.7f)
                    )
                }
                
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        text = formatCurrency(calculateDailyRevenue(emptyList())), // TODO: Connect to actual revenue data
                        style = MaterialTheme.typography.h5,
                        fontWeight = FontWeight.Bold,
                        color = Color(0xFF4CAF50)
                    )
                    Text(
                        text = "Daily Revenue",
                        style = MaterialTheme.typography.caption,
                        color = MaterialTheme.colors.onSurface.copy(alpha = 0.7f)
                    )
                }
                
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        text = formatCurrency(calculateDailyCosts(emptyList())), // TODO: Connect to actual cost data
                        style = MaterialTheme.typography.h5,
                        fontWeight = FontWeight.Bold,
                        color = Color(0xFFF44336)
                    )
                    Text(
                        text = "Daily Costs",
                        style = MaterialTheme.typography.caption,
                        color = MaterialTheme.colors.onSurface.copy(alpha = 0.7f)
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterialApi::class)
@Composable
private fun AssetFilters(
    selectedCategory: AssetType?,
    onCategorySelected: (AssetType?) -> Unit,
    sortBy: AssetSortOption,
    onSortByChanged: (AssetSortOption) -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        elevation = 2.dp,
        shape = RoundedCornerShape(8.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Text(
                text = "Filter by Type",
                style = MaterialTheme.typography.subtitle2,
                fontWeight = FontWeight.Bold
            )
            
            Spacer(modifier = Modifier.height(8.dp))
            
            // Asset type chips
            val categories = listOf(
                null to "All",
                AssetType.CONTAINER_SHIP to "Ships",
                AssetType.CARGO_AIRCRAFT to "Aircraft",
                AssetType.WAREHOUSE to "Warehouses",
                AssetType.TRUCK to "Trucks"
            )
            
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                categories.forEach { (type, label) ->
                    FilterChip(
                        selected = selectedCategory == type,
                        onClick = { onCategorySelected(type) },
                        selectedIcon = {
                            Icon(
                                Icons.Default.Check,
                                contentDescription = null,
                                modifier = Modifier.size(16.dp)
                            )
                        }
                    ) {
                        Text(label)
                    }
                }
            }
            
            Spacer(modifier = Modifier.height(16.dp))
            
            Text(
                text = "Sort By",
                style = MaterialTheme.typography.subtitle2,
                fontWeight = FontWeight.Bold
            )
            
            Spacer(modifier = Modifier.height(8.dp))
            
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                AssetSortOption.values().forEach { option ->
                    FilterChip(
                        selected = sortBy == option,
                        onClick = { onSortByChanged(option) }
                    ) {
                        Text(option.displayName)
                    }
                }
            }
        }
    }
}

@Composable
private fun AssetSummaryCards(assets: List<Asset>) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        // Operational Assets
        val operationalCount = assets.count { it.isOperational }
        SummaryCard(
            title = "Operational",
            value = "$operationalCount/${assets.size}",
            icon = Icons.Default.CheckCircle,
            color = Color(0xFF4CAF50),
            modifier = Modifier.weight(1f)
        )
        
        // Assets Needing Maintenance
        val maintenanceNeeded = assets.count { 
            it.condition == AssetCondition.FAIR || it.condition == AssetCondition.POOR 
        }
        SummaryCard(
            title = "Need Maintenance",
            value = maintenanceNeeded.toString(),
            icon = Icons.Default.Build,
            color = Color(0xFFFF9800),
            modifier = Modifier.weight(1f)
        )
        
        // Average Utilization
        val avgUtilization = if (assets.isNotEmpty()) {
            assets.map { it.operationalData.utilizationRate }.average()
        } else 0.0
        SummaryCard(
            title = "Avg. Utilization",
            value = "${(avgUtilization * 100).toInt()}%",
            icon = Icons.Default.TrendingUp,
            color = Color(0xFF2196F3),
            modifier = Modifier.weight(1f)
        )
    }
}

@Composable
private fun SummaryCard(
    title: String,
    value: String,
    icon: ImageVector,
    color: Color,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier,
        elevation = 2.dp,
        shape = RoundedCornerShape(8.dp)
    ) {
        Column(
            modifier = Modifier.padding(12.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Icon(
                imageVector = icon,
                contentDescription = title,
                tint = color,
                modifier = Modifier.size(24.dp)
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = value,
                style = MaterialTheme.typography.h6,
                fontWeight = FontWeight.Bold,
                color = color
            )
            Text(
                text = title,
                style = MaterialTheme.typography.caption,
                color = MaterialTheme.colors.onSurface.copy(alpha = 0.7f),
                textAlign = TextAlign.Center
            )
        }
    }
}

@Composable
private fun AssetCard(
    asset: Asset,
    onClick: () -> Unit,
    onSellClick: () -> Unit,
    onMaintenanceClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() },
        elevation = 4.dp,
        shape = RoundedCornerShape(12.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top
            ) {
                // Asset Info
                Column(modifier = Modifier.weight(1f)) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = getAssetTypeIcon(asset.type),
                            contentDescription = asset.type.name,
                            modifier = Modifier.size(24.dp),
                            tint = MaterialTheme.colors.primary
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = asset.name,
                            style = MaterialTheme.typography.h6,
                            fontWeight = FontWeight.Bold
                        )
                    }
                    
                    Text(
                        text = getAssetDescription(asset),
                        style = MaterialTheme.typography.body2,
                        color = MaterialTheme.colors.onSurface.copy(alpha = 0.7f)
                    )
                    
                    Spacer(modifier = Modifier.height(4.dp))
                    
                    Text(
                        text = getLocationText(asset.location),
                        style = MaterialTheme.typography.caption,
                        color = MaterialTheme.colors.onSurface.copy(alpha = 0.6f)
                    )
                }
                
                // Condition and Status
                Column(
                    horizontalAlignment = Alignment.End
                ) {
                    AssetConditionBadge(condition = asset.condition)
                    
                    Spacer(modifier = Modifier.height(4.dp))
                    
                    if (!asset.isOperational) {
                        Surface(
                            color = Color(0xFFF44336),
                            shape = RoundedCornerShape(4.dp)
                        ) {
                            Text(
                                text = "OFFLINE",
                                style = MaterialTheme.typography.caption,
                                color = Color.White,
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }
                }
            }
            
            Spacer(modifier = Modifier.height(12.dp))
            
            // Asset Metrics
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                MetricItem(
                    label = "Value",
                    value = formatCurrency(asset.currentValue),
                    trend = calculateValueTrend(asset)
                )
                
                MetricItem(
                    label = "Daily Cost",
                    value = formatCurrency(asset.getTotalDailyCost()),
                    isNegative = true
                )
                
                MetricItem(
                    label = "Utilization",
                    value = "${(asset.operationalData.utilizationRate * 100).toInt()}%"
                )
                
                MetricItem(
                    label = "Age",
                    value = getAssetAge(asset.acquisitionDate)
                )
            }
            
            Spacer(modifier = Modifier.height(12.dp))
            
            // Action Buttons
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                OutlinedButton(
                    onClick = onMaintenanceClick,
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Build,
                        contentDescription = "Maintenance",
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("Maintenance")
                }
                
                OutlinedButton(
                    onClick = onSellClick,
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(8.dp),
                    colors = ButtonDefaults.outlinedButtonColors(
                        contentColor = Color(0xFFF44336)
                    )
                ) {
                    Icon(
                        imageVector = Icons.Default.AttachMoney,
                        contentDescription = "Sell",
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("Sell")
                }
            }
        }
    }
}

@Composable
private fun MetricItem(
    label: String,
    value: String,
    trend: Double? = null,
    isNegative: Boolean = false
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = value,
                style = MaterialTheme.typography.body2,
                fontWeight = FontWeight.Bold,
                color = when {
                    isNegative -> Color(0xFFF44336)
                    trend != null && trend > 0 -> Color(0xFF4CAF50)
                    trend != null && trend < 0 -> Color(0xFFF44336)
                    else -> MaterialTheme.colors.onSurface
                }
            )
            
            trend?.let {
                Icon(
                    imageVector = if (it > 0) Icons.Default.TrendingUp else Icons.Default.TrendingDown,
                    contentDescription = null,
                    modifier = Modifier.size(16.dp),
                    tint = if (it > 0) Color(0xFF4CAF50) else Color(0xFFF44336)
                )
            }
        }
        
        Text(
            text = label,
            style = MaterialTheme.typography.caption,
            color = MaterialTheme.colors.onSurface.copy(alpha = 0.7f)
        )
    }
}

@Composable
private fun AssetConditionBadge(condition: AssetCondition) {
    val (backgroundColor, textColor) = when (condition) {
        AssetCondition.EXCELLENT -> Color(0xFF4CAF50) to Color.White
        AssetCondition.GOOD -> Color(0xFF2196F3) to Color.White
        AssetCondition.FAIR -> Color(0xFFFF9800) to Color.White
        AssetCondition.POOR -> Color(0xFFF44336) to Color.White
    }
    
    Surface(
        color = backgroundColor,
        shape = RoundedCornerShape(4.dp),
        elevation = 2.dp
    ) {
        Text(
            text = condition.name,
            style = MaterialTheme.typography.caption,
            color = textColor,
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
            fontWeight = FontWeight.Medium
        )
    }
}

// Helper functions
private fun getAssetTypeIcon(assetType: AssetType): ImageVector {
    return when (assetType) {
        AssetType.CONTAINER_SHIP, AssetType.BULK_CARRIER, AssetType.TANKER -> Icons.Default.DirectionsBoat
        AssetType.CARGO_AIRCRAFT, AssetType.PASSENGER_AIRCRAFT -> Icons.Default.Flight
        AssetType.WAREHOUSE, AssetType.DISTRIBUTION_CENTER -> Icons.Default.Warehouse
        AssetType.PORT_TERMINAL -> Icons.Default.Anchor
        AssetType.TRUCK -> Icons.Default.LocalShipping
        AssetType.RAIL_CAR -> Icons.Default.Train
        AssetType.CRANE, AssetType.FORKLIFT -> Icons.Default.Construction
    }
}

private fun getAssetDescription(asset: Asset): String {
    return when (val specs = asset.specifications) {
        is AssetSpecifications.ShipSpecifications -> 
            "${specs.manufacturer} ${specs.model} - ${specs.capacity} TEU"
        is AssetSpecifications.AircraftSpecifications -> 
            "${specs.manufacturer} ${specs.model} - ${specs.cargoCapacity}kg capacity"
        is AssetSpecifications.WarehouseSpecifications -> 
            "${specs.totalArea}m² - ${specs.loadingDocks} docks"
        is AssetSpecifications.VehicleSpecifications -> 
            "${specs.manufacturer} ${specs.model} - ${specs.payloadCapacity}t"
        is AssetSpecifications.EquipmentSpecifications -> 
            "${specs.manufacturer} ${specs.model}"
        is AssetSpecifications.PortTerminalSpecifications -> 
            "${specs.totalArea} hectares - ${specs.berthLength}m berth"
    }
}

private fun getLocationText(location: AssetLocation): String {
    return when (location.locationType) {
        LocationType.AT_SEA -> "At Sea (${location.latitude?.format(2)}, ${location.longitude?.format(2)})"
        LocationType.IN_PORT -> "Port: ${location.portId ?: "Unknown"}"
        LocationType.AT_WAREHOUSE -> "Warehouse: ${location.warehouseId ?: "Unknown"}"
        LocationType.IN_TRANSIT -> "In Transit"
        LocationType.AT_FACILITY -> location.address ?: "At Facility"
        LocationType.UNKNOWN -> "Location Unknown"
    }
}

private fun Double.format(decimals: Int): String {
    return "%.${decimals}f".format(this)
}

private fun formatCurrency(amount: Double): String {
    return NumberFormat.getCurrencyInstance(Locale.US).format(amount)
}

private fun calculateValueTrend(asset: Asset): Double {
    // Calculate depreciation trend
    val depreciatedValue = asset.getDepreciatedValue()
    return (asset.currentValue - depreciatedValue) / depreciatedValue
}

private fun getAssetAge(acquisitionDate: Long): String {
    val now = System.currentTimeMillis()
    val days = (now - acquisitionDate) / (24 * 60 * 60 * 1000L)
    
    return when {
        days < 30 -> "$days days"
        days < 365 -> "${days / 30} months"
        else -> "${days / 365} years"
    }
}

private fun calculateDailyRevenue(assets: List<Asset>): Double {
    // TODO: Implement actual revenue calculation
    return assets.size * 5000.0
}

private fun calculateDailyCosts(assets: List<Asset>): Double {
    return assets.sumOf { it.getTotalDailyCost() }
}


// Preview data generator
private fun generateSampleAssets(): List<Asset> {
    return listOf(
        Asset(
            id = "1",
            name = "Ocean Pioneer",
            type = AssetType.CONTAINER_SHIP,
            ownerId = "player1",
            purchasePrice = 50_000_000.0,
            currentValue = 45_000_000.0,
            condition = AssetCondition.EXCELLENT,
            location = AssetLocation(
                latitude = 1.2897,
                longitude = 103.8501,
                locationType = LocationType.AT_SEA
            ),
            specifications = AssetSpecifications.ShipSpecifications(
                capacity = 18000,
                maxSpeed = 23.0,
                fuelCapacity = 5000.0,
                length = 400.0,
                beam = 59.0,
                draft = 16.0,
                dwt = 180000.0,
                manufacturer = "Hyundai Heavy Industries",
                model = "Ultra Large Container Vessel",
                yearBuilt = 2021
            ),
            operationalData = OperationalData(
                utilizationRate = 0.85,
                totalOperatingHours = 5000.0,
                totalDistance = 120000.0,
                totalCargoMoved = 500000.0,
                averageSpeed = 20.0,
                fuelConsumption = 250.0,
                revenue = 15_000_000.0,
                operatingCosts = 5_000_000.0
            ),
            maintenanceData = MaintenanceData()
        ),
        Asset(
            id = "2",
            name = "Distribution Hub Central",
            type = AssetType.WAREHOUSE,
            ownerId = "player1",
            purchasePrice = 25_000_000.0,
            currentValue = 24_000_000.0,
            condition = AssetCondition.GOOD,
            location = AssetLocation(
                address = "123 Logistics Park, Rotterdam",
                locationType = LocationType.AT_FACILITY
            ),
            specifications = AssetSpecifications.WarehouseSpecifications(
                totalArea = 50000.0,
                storageVolume = 500000.0,
                loadingDocks = 24,
                rackingCapacity = 10000,
                temperatureControlled = true,
                hazmatCertified = true,
                securityLevel = "High",
                yearBuilt = 2020
            ),
            operationalData = OperationalData(
                utilizationRate = 0.92
            ),
            maintenanceData = MaintenanceData()
        )
    )
}

@Preview(showBackground = true)
@Composable
fun AssetManagementScreenPreview() {
    MaterialTheme {
        AssetManagementScreen(
            assets = generateSampleAssets()
        )
    }
}