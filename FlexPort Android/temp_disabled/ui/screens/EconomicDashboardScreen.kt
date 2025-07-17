package com.flexport.game.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.random.Random

/**
 * Economic Dashboard Screen showing live market data and financial metrics
 */
@Composable
fun EconomicDashboardScreen(
    modifier: Modifier = Modifier
) {
    // Sample data - in real implementation this would come from EconomicEngine
    val marketData = remember { generateSampleMarketData() }
    val playerFinancials = remember { generateSamplePlayerData() }
    
    Column(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colors.background)
            .padding(16.dp)
    ) {
        // Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "Economic Dashboard",
                style = MaterialTheme.typography.h4,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colors.onBackground
            )
            
            // Economic Health Indicator
            EconomicHealthCard(
                health = marketData.economicHealth,
                modifier = Modifier
            )
        }
        
        Spacer(modifier = Modifier.height(24.dp))
        
        LazyColumn {
            // Player Financials Section
            item {
                PlayerFinancialsSection(
                    financials = playerFinancials,
                    modifier = Modifier.fillMaxWidth()
                )
                Spacer(modifier = Modifier.height(24.dp))
            }
            
            // Live Market Prices Section
            item {
                Text(
                    text = "Live Market Prices",
                    style = MaterialTheme.typography.h5,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colors.onBackground,
                    modifier = Modifier.padding(bottom = 12.dp)
                )
                
                LazyRow(
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    contentPadding = PaddingValues(bottom = 16.dp)
                ) {
                    items(marketData.commodityMarkets) { market ->
                        CommodityMarketCard(
                            market = market,
                            modifier = Modifier.width(200.dp)
                        )
                    }
                }
                Spacer(modifier = Modifier.height(16.dp))
            }
            
            // Market Sectors Section
            item {
                Text(
                    text = "Market Sectors",
                    style = MaterialTheme.typography.h5,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colors.onBackground,
                    modifier = Modifier.padding(bottom = 12.dp)
                )
                
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    // Capital Market
                    MarketSectorCard(
                        title = "Capital Market",
                        value = "$${String.format("%.2f", marketData.capitalMarket.marketIndex)}",
                        change = "${String.format("%.1f", marketData.capitalMarket.volatility)}%",
                        isPositive = marketData.capitalMarket.volatility > 0,
                        icon = Icons.Default.TrendingUp,
                        modifier = Modifier.weight(1f)
                    )
                    
                    // Labor Market
                    MarketSectorCard(
                        title = "Labor Market",
                        value = "${String.format("%.1f", marketData.laborMarket.averageUnemployment)}%",
                        change = "Unemployment",
                        isPositive = marketData.laborMarket.averageUnemployment < 5.0,
                        icon = Icons.Default.Group,
                        modifier = Modifier.weight(1f)
                    )
                }
                Spacer(modifier = Modifier.height(16.dp))
            }
            
            // Market Actions Section
            item {
                Text(
                    text = "Market Actions",
                    style = MaterialTheme.typography.h5,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colors.onBackground,
                    modifier = Modifier.padding(bottom = 12.dp)
                )
                
                LazyRow(
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    contentPadding = PaddingValues(bottom = 16.dp)
                ) {
                    items(listOf("Buy Orders", "Sell Orders", "Trade Routes", "Market Analysis")) { action ->
                        ActionCard(
                            title = action,
                            onClick = { /* Handle action */ },
                            modifier = Modifier.width(160.dp)
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun PlayerFinancialsSection(
    financials: PlayerFinancials,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp)),
        elevation = 8.dp,
        backgroundColor = MaterialTheme.colors.surface
    ) {
        Column(
            modifier = Modifier.padding(20.dp)
        ) {
            Text(
                text = "Your Portfolio",
                style = MaterialTheme.typography.h5,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colors.onSurface,
                modifier = Modifier.padding(bottom = 16.dp)
            )
            
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                // Cash
                FinancialMetric(
                    label = "Cash",
                    value = "$${String.format("%.0f", financials.cash)}",
                    change = "+${String.format("%.1f", financials.cashChange)}%",
                    isPositive = financials.cashChange > 0,
                    modifier = Modifier.weight(1f)
                )
                
                // Assets
                FinancialMetric(
                    label = "Assets",
                    value = "$${String.format("%.0f", financials.totalAssets)}",
                    change = "+${String.format("%.1f", financials.assetChange)}%",
                    isPositive = financials.assetChange > 0,
                    modifier = Modifier.weight(1f)
                )
                
                // P&L
                FinancialMetric(
                    label = "P&L (24h)",
                    value = "$${String.format("%.0f", financials.profitLoss)}",
                    change = "${String.format("%.1f", financials.profitLossChange)}%",
                    isPositive = financials.profitLoss > 0,
                    modifier = Modifier.weight(1f)
                )
                
                // ROI
                FinancialMetric(
                    label = "ROI",
                    value = "${String.format("%.1f", financials.roi)}%",
                    change = "Annual",
                    isPositive = financials.roi > 0,
                    modifier = Modifier.weight(1f)
                )
            }
        }
    }
}

@Composable
private fun FinancialMetric(
    label: String,
    value: String,
    change: String,
    isPositive: Boolean,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.caption,
            color = MaterialTheme.colors.onSurface.copy(alpha = 0.7f)
        )
        Text(
            text = value,
            style = MaterialTheme.typography.h6,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colors.onSurface
        )
        Text(
            text = change,
            style = MaterialTheme.typography.caption,
            color = if (isPositive) Color(0xFF4CAF50) else Color(0xFFF44336)
        )
    }
}

@Composable
private fun CommodityMarketCard(
    market: CommodityMarketData,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier
            .clip(RoundedCornerShape(8.dp)),
        elevation = 4.dp,
        backgroundColor = MaterialTheme.colors.surface
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = market.name,
                    style = MaterialTheme.typography.subtitle1,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colors.onSurface
                )
                SupplyDemandIndicator(
                    supplyLevel = market.supplyLevel,
                    demandLevel = market.demandLevel
                )
            }
            
            Spacer(modifier = Modifier.height(8.dp))
            
            Text(
                text = "$${String.format("%.2f", market.currentPrice)}",
                style = MaterialTheme.typography.h6,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colors.onSurface
            )
            
            Row(
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = if (market.priceChange > 0) Icons.Default.TrendingUp else Icons.Default.TrendingDown,
                    contentDescription = null,
                    tint = if (market.priceChange > 0) Color(0xFF4CAF50) else Color(0xFFF44336),
                    modifier = Modifier.size(16.dp)
                )
                Text(
                    text = "${if (market.priceChange > 0) "+" else ""}${String.format("%.1f", market.priceChange)}%",
                    style = MaterialTheme.typography.caption,
                    color = if (market.priceChange > 0) Color(0xFF4CAF50) else Color(0xFFF44336),
                    modifier = Modifier.padding(start = 4.dp)
                )
            }
        }
    }
}

@Composable
private fun SupplyDemandIndicator(
    supplyLevel: Float,
    demandLevel: Float,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier,
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Supply indicator
        Box(
            modifier = Modifier
                .size(8.dp)
                .clip(RoundedCornerShape(4.dp))
                .background(
                    when {
                        supplyLevel > 0.7f -> Color(0xFF4CAF50) // High supply - green
                        supplyLevel > 0.3f -> Color(0xFFFF9800) // Medium supply - orange
                        else -> Color(0xFFF44336) // Low supply - red
                    }
                )
        )
        
        Spacer(modifier = Modifier.width(4.dp))
        
        // Demand indicator
        Box(
            modifier = Modifier
                .size(8.dp)
                .clip(RoundedCornerShape(4.dp))
                .background(
                    when {
                        demandLevel > 0.7f -> Color(0xFFF44336) // High demand - red
                        demandLevel > 0.3f -> Color(0xFFFF9800) // Medium demand - orange
                        else -> Color(0xFF4CAF50) // Low demand - green
                    }
                )
        )
    }
}

@Composable
private fun MarketSectorCard(
    title: String,
    value: String,
    change: String,
    isPositive: Boolean,
    icon: ImageVector,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier
            .clip(RoundedCornerShape(8.dp)),
        elevation = 4.dp,
        backgroundColor = MaterialTheme.colors.surface
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = MaterialTheme.colors.primary,
                modifier = Modifier.size(32.dp)
            )
            
            Spacer(modifier = Modifier.height(8.dp))
            
            Text(
                text = title,
                style = MaterialTheme.typography.caption,
                color = MaterialTheme.colors.onSurface.copy(alpha = 0.7f),
                textAlign = TextAlign.Center
            )
            
            Text(
                text = value,
                style = MaterialTheme.typography.h6,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colors.onSurface
            )
            
            Text(
                text = change,
                style = MaterialTheme.typography.caption,
                color = if (isPositive) Color(0xFF4CAF50) else Color(0xFFF44336)
            )
        }
    }
}

@Composable
private fun ActionCard(
    title: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier
            .clip(RoundedCornerShape(8.dp)),
        elevation = 4.dp,
        backgroundColor = MaterialTheme.colors.primary
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.subtitle2,
                color = MaterialTheme.colors.onPrimary,
                textAlign = TextAlign.Center,
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}

@Composable
private fun EconomicHealthCard(
    health: EconomicHealth,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier
            .clip(RoundedCornerShape(8.dp)),
        elevation = 4.dp,
        backgroundColor = when (health.status) {
            EconomicHealthStatus.EXCELLENT -> Color(0xFF4CAF50)
            EconomicHealthStatus.GOOD -> Color(0xFF8BC34A)
            EconomicHealthStatus.FAIR -> Color(0xFFFF9800)
            EconomicHealthStatus.POOR -> Color(0xFFF44336)
        }
    ) {
        Row(
            modifier = Modifier.padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Default.TrendingUp,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(20.dp)
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                text = health.status.name,
                style = MaterialTheme.typography.caption,
                color = Color.White,
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}

// Data classes for UI
data class MarketData(
    val commodityMarkets: List<CommodityMarketData>,
    val capitalMarket: CapitalMarketData,
    val laborMarket: LaborMarketData,
    val economicHealth: EconomicHealth
)

data class CommodityMarketData(
    val name: String,
    val currentPrice: Double,
    val priceChange: Double,
    val supplyLevel: Float,
    val demandLevel: Float
)

data class CapitalMarketData(
    val marketIndex: Double,
    val volatility: Double,
    val interestRate: Double
)

data class LaborMarketData(
    val averageUnemployment: Double,
    val totalEmployed: Int,
    val totalUnemployed: Int
)

data class EconomicHealth(
    val status: EconomicHealthStatus,
    val gdpGrowth: Double,
    val inflation: Double,
    val confidence: Double
)

enum class EconomicHealthStatus {
    EXCELLENT, GOOD, FAIR, POOR
}

data class PlayerFinancials(
    val cash: Double,
    val cashChange: Double,
    val totalAssets: Double,
    val assetChange: Double,
    val profitLoss: Double,
    val profitLossChange: Double,
    val roi: Double
)

// Sample data generators
private fun generateSampleMarketData(): MarketData {
    val commodities = listOf(
        CommodityMarketData("Wheat", 250.75, Random.nextDouble(-5.0, 5.0), Random.nextFloat(), Random.nextFloat()),
        CommodityMarketData("Crude Oil", 82.40, Random.nextDouble(-3.0, 3.0), Random.nextFloat(), Random.nextFloat()),
        CommodityMarketData("Electronics", 15000.0, Random.nextDouble(-2.0, 4.0), Random.nextFloat(), Random.nextFloat()),
        CommodityMarketData("Steel", 850.25, Random.nextDouble(-1.5, 2.5), Random.nextFloat(), Random.nextFloat())
    )
    
    return MarketData(
        commodityMarkets = commodities,
        capitalMarket = CapitalMarketData(
            marketIndex = 3250.75,
            volatility = Random.nextDouble(-1.0, 2.0),
            interestRate = 4.25
        ),
        laborMarket = LaborMarketData(
            averageUnemployment = Random.nextDouble(3.0, 8.0),
            totalEmployed = 1250000,
            totalUnemployed = 95000
        ),
        economicHealth = EconomicHealth(
            status = EconomicHealthStatus.values().random(),
            gdpGrowth = Random.nextDouble(1.0, 4.0),
            inflation = Random.nextDouble(1.5, 3.5),
            confidence = Random.nextDouble(50.0, 85.0)
        )
    )
}

private fun generateSamplePlayerData(): PlayerFinancials {
    return PlayerFinancials(
        cash = Random.nextDouble(500000.0, 2000000.0),
        cashChange = Random.nextDouble(-5.0, 10.0),
        totalAssets = Random.nextDouble(2000000.0, 10000000.0),
        assetChange = Random.nextDouble(-2.0, 8.0),
        profitLoss = Random.nextDouble(-50000.0, 150000.0),
        profitLossChange = Random.nextDouble(-10.0, 15.0),
        roi = Random.nextDouble(5.0, 25.0)
    )
}

@Preview(showBackground = true)
@Composable
fun EconomicDashboardScreenPreview() {
    MaterialTheme {
        EconomicDashboardScreen()
    }
}