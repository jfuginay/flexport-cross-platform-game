package com.flexport.assets.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.*
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

@Composable
fun AssetMarketplaceScreen(
    onNavigateBack: () -> Unit = {},
    modifier: Modifier = Modifier
) {
    var selectedCategory by remember { mutableStateOf(AssetType.CONTAINER_SHIP) }
    val marketplaceAssets = remember { generateMarketplaceAssets() }
    
    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Header
        item {
            MarketplaceHeader(
                onNavigateBack = onNavigateBack
            )
        }
        
        // Asset Category Tabs
        item {
            AssetCategoryTabs(
                selectedCategory = selectedCategory,
                onCategorySelected = { selectedCategory = it }
            )
        }
        
        // Asset Listings
        val filteredAssets = marketplaceAssets.filter { it.assetType == selectedCategory }
        items(filteredAssets) { asset ->
            MarketplaceAssetCard(
                asset = asset,
                onPurchaseClicked = { /* Handle purchase */ },
                onDetailsClicked = { /* Show details */ }
            )
        }
    }
}

@Composable
private fun MarketplaceHeader(
    onNavigateBack: () -> Unit
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
                            text = "Asset Marketplace",
                            style = MaterialTheme.typography.h4,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colors.primary
                        )
                        Text(
                            text = "Expand your logistics fleet",
                            style = MaterialTheme.typography.body2,
                            color = MaterialTheme.colors.onSurface.copy(alpha = 0.7f)
                        )
                    }
                }
                
                Icon(
                    imageVector = Icons.Default.ShoppingCart,
                    contentDescription = "Marketplace",
                    tint = MaterialTheme.colors.primary,
                    modifier = Modifier.size(32.dp)
                )
            }
        }
    }
}

@Composable
private fun AssetCategoryTabs(
    selectedCategory: AssetType,
    onCategorySelected: (AssetType) -> Unit
) {
    val categories = listOf(
        AssetType.CONTAINER_SHIP,
        AssetType.CARGO_AIRCRAFT,
        AssetType.WAREHOUSE,
        AssetType.TRUCK
    )
    
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        categories.forEach { category ->
            CategoryTab(
                category = category,
                isSelected = selectedCategory == category,
                onClick = { onCategorySelected(category) },
                modifier = Modifier.weight(1f)
            )
        }
    }
}

@Composable
private fun CategoryTab(
    category: AssetType,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Surface(
        modifier = modifier
            .clickable { onClick() },
        color = if (isSelected) MaterialTheme.colors.primary else MaterialTheme.colors.surface,
        shape = RoundedCornerShape(8.dp),
        elevation = if (isSelected) 4.dp else 2.dp
    ) {
        Column(
            modifier = Modifier.padding(12.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Icon(
                imageVector = getAssetTypeIcon(category),
                contentDescription = category.name,
                tint = if (isSelected) Color.White else MaterialTheme.colors.primary,
                modifier = Modifier.size(24.dp)
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = category.name.replace("_", " "),
                style = MaterialTheme.typography.caption,
                color = if (isSelected) Color.White else MaterialTheme.colors.onSurface,
                textAlign = TextAlign.Center,
                maxLines = 1
            )
        }
    }
}

@Composable
private fun MarketplaceAssetCard(
    asset: MarketplaceAsset,
    onPurchaseClicked: () -> Unit,
    onDetailsClicked: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onDetailsClicked() },
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
                Column(modifier = Modifier.weight(1f)) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = getAssetTypeIcon(asset.assetType),
                            contentDescription = asset.assetType.name,
                            modifier = Modifier.size(24.dp),
                            tint = MaterialTheme.colors.primary
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = asset.name,
                            style = MaterialTheme.typography.h6,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colors.onSurface
                        )
                    }
                    
                    Text(
                        text = "${asset.manufacturer} ${asset.model} (${asset.yearBuilt})",
                        style = MaterialTheme.typography.body2,
                        color = MaterialTheme.colors.onSurface.copy(alpha = 0.7f)
                    )
                }
                
                AssetConditionBadge(condition = asset.condition)
            }
            
            Spacer(modifier = Modifier.height(12.dp))
            
            // Price and Value
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = "Price",
                        style = MaterialTheme.typography.caption,
                        color = MaterialTheme.colors.onSurface.copy(alpha = 0.7f)
                    )
                    Text(
                        text = formatCurrency(asset.price),
                        style = MaterialTheme.typography.h5,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colors.primary
                    )
                }
                
                if (asset.originalPrice > asset.price) {
                    Column(
                        horizontalAlignment = Alignment.End
                    ) {
                        Text(
                            text = "Save ${formatCurrency(asset.originalPrice - asset.price)}",
                            style = MaterialTheme.typography.caption,
                            color = Color.Green,
                            fontWeight = FontWeight.Medium
                        )
                        Text(
                            text = formatCurrency(asset.originalPrice),
                            style = MaterialTheme.typography.caption,
                            color = MaterialTheme.colors.onSurface.copy(alpha = 0.5f)
                        )
                    }
                }
            }
            
            Spacer(modifier = Modifier.height(12.dp))
            
            // Asset Specifications Row
            AssetSpecificationsRow(asset = asset)
            
            Spacer(modifier = Modifier.height(16.dp))
            
            // Purchase Button
            Button(
                onClick = onPurchaseClicked,
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(
                    backgroundColor = MaterialTheme.colors.primary
                ),
                shape = RoundedCornerShape(8.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.ShoppingCart,
                    contentDescription = "Purchase",
                    modifier = Modifier.size(18.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = "Purchase Asset",
                    style = MaterialTheme.typography.button,
                    color = Color.White
                )
            }
        }
    }
}

@Composable
private fun AssetSpecificationsRow(asset: MarketplaceAsset) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceEvenly
    ) {
        when (asset.assetType) {
            AssetType.CONTAINER_SHIP -> {
                SpecificationItem("Capacity", "${asset.specifications["capacity"] ?: "Unknown"} TEU")
                SpecificationItem("Speed", "${asset.specifications["speed"] ?: "Unknown"} kt")
                SpecificationItem("DWT", "${asset.specifications["dwt"] ?: "Unknown"}")
            }
            AssetType.CARGO_AIRCRAFT -> {
                SpecificationItem("Capacity", "${asset.specifications["capacity"] ?: "Unknown"} kg")
                SpecificationItem("Range", "${asset.specifications["range"] ?: "Unknown"} km")
                SpecificationItem("Speed", "${asset.specifications["speed"] ?: "Unknown"} km/h")
            }
            AssetType.WAREHOUSE -> {
                SpecificationItem("Area", "${asset.specifications["area"] ?: "Unknown"} m²")
                SpecificationItem("Volume", "${asset.specifications["volume"] ?: "Unknown"} m³")
                SpecificationItem("Docks", "${asset.specifications["docks"] ?: "Unknown"}")
            }
            AssetType.TRUCK -> {
                SpecificationItem("Capacity", "${asset.specifications["capacity"] ?: "Unknown"} tons")
                SpecificationItem("Range", "${asset.specifications["range"] ?: "Unknown"} km")
                SpecificationItem("Year", "${asset.yearBuilt}")
            }
            else -> {
                SpecificationItem("Type", asset.assetType.name)
                SpecificationItem("Condition", asset.condition.name)
                SpecificationItem("Year", "${asset.yearBuilt}")
            }
        }
    }
}

@Composable
private fun SpecificationItem(
    label: String,
    value: String
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = value,
            style = MaterialTheme.typography.body2,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colors.onSurface
        )
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

private fun formatCurrency(amount: Double): String {
    return when {
        amount >= 1_000_000 -> "$${(amount / 1_000_000).toInt()}M"
        amount >= 1_000 -> "$${(amount / 1_000).toInt()}K"
        else -> "$${amount.toInt()}"
    }
}

// Data class for marketplace assets
data class MarketplaceAsset(
    val id: String,
    val name: String,
    val assetType: AssetType,
    val manufacturer: String,
    val model: String,
    val yearBuilt: Int,
    val condition: AssetCondition,
    val price: Double,
    val originalPrice: Double,
    val specifications: Map<String, Any>,
    val seller: String,
    val location: String,
    val isAvailable: Boolean = true,
    val description: String = ""
)

// Sample data generator
private fun generateMarketplaceAssets(): List<MarketplaceAsset> {
    return listOf(
        // Container Ships
        MarketplaceAsset(
            id = "mp-ship-001",
            name = "Ocean Pioneer",
            assetType = AssetType.CONTAINER_SHIP,
            manufacturer = "Hyundai Heavy Industries",
            model = "Ultra Large Container Vessel",
            yearBuilt = 2021,
            condition = AssetCondition.EXCELLENT,
            price = 45_000_000.0,
            originalPrice = 50_000_000.0,
            specifications = mapOf(
                "capacity" to 18000,
                "speed" to 23,
                "dwt" to 180000
            ),
            seller = "Global Shipping Corp",
            location = "South Korea"
        ),
        MarketplaceAsset(
            id = "mp-ship-002",
            name = "Atlantic Express",
            assetType = AssetType.CONTAINER_SHIP,
            manufacturer = "Samsung Heavy Industries",
            model = "Large Container Ship",
            yearBuilt = 2019,
            condition = AssetCondition.GOOD,
            price = 35_000_000.0,
            originalPrice = 42_000_000.0,
            specifications = mapOf(
                "capacity" to 14000,
                "speed" to 22,
                "dwt" to 140000
            ),
            seller = "Maritime Solutions Ltd",
            location = "Singapore"
        ),
        
        // Cargo Aircraft
        MarketplaceAsset(
            id = "mp-aircraft-001",
            name = "Sky Cargo Master",
            assetType = AssetType.CARGO_AIRCRAFT,
            manufacturer = "Boeing",
            model = "747-8F",
            yearBuilt = 2022,
            condition = AssetCondition.EXCELLENT,
            price = 180_000_000.0,
            originalPrice = 200_000_000.0,
            specifications = mapOf(
                "capacity" to 140000,
                "range" to 8130,
                "speed" to 907
            ),
            seller = "AirCargo International",
            location = "USA"
        ),
        MarketplaceAsset(
            id = "mp-aircraft-002",
            name = "Freight Express",
            assetType = AssetType.CARGO_AIRCRAFT,
            manufacturer = "Airbus",
            model = "A330-200F",
            yearBuilt = 2020,
            condition = AssetCondition.GOOD,
            price = 120_000_000.0,
            originalPrice = 140_000_000.0,
            specifications = mapOf(
                "capacity" to 70000,
                "range" to 7400,
                "speed" to 871
            ),
            seller = "European Air Freight",
            location = "Germany"
        ),
        
        // Warehouses
        MarketplaceAsset(
            id = "mp-warehouse-001",
            name = "Distribution Hub Central",
            assetType = AssetType.WAREHOUSE,
            manufacturer = "Modern Logistics",
            model = "Automated Distribution Center",
            yearBuilt = 2021,
            condition = AssetCondition.EXCELLENT,
            price = 25_000_000.0,
            originalPrice = 30_000_000.0,
            specifications = mapOf(
                "area" to 50000,
                "volume" to 500000,
                "docks" to 24
            ),
            seller = "Logistics Real Estate",
            location = "Netherlands"
        ),
        
        // Trucks
        MarketplaceAsset(
            id = "mp-truck-001",
            name = "Heavy Duty Transporter",
            assetType = AssetType.TRUCK,
            manufacturer = "Volvo",
            model = "FH16",
            yearBuilt = 2022,
            condition = AssetCondition.EXCELLENT,
            price = 150_000.0,
            originalPrice = 180_000.0,
            specifications = mapOf(
                "capacity" to 40,
                "range" to 1500,
                "horsepower" to 750
            ),
            seller = "Commercial Vehicles Inc",
            location = "Sweden"
        )
    )
}

@Preview(showBackground = true)
@Composable
fun AssetMarketplaceScreenPreview() {
    MaterialTheme {
        AssetMarketplaceScreen()
    }
}