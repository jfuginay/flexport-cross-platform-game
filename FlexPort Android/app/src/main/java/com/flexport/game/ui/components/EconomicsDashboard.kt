package com.flexport.game.ui.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.flexport.game.viewmodels.GameViewModel
import kotlin.math.cos
import kotlin.math.sin

/**
 * Material Design 3 Economics Dashboard with charts and metrics
 */
@Composable
fun EconomicsDashboard(
    gameViewModel: GameViewModel,
    modifier: Modifier = Modifier
) {
    val money by gameViewModel.money.collectAsState()
    val ships by gameViewModel.ships.collectAsState()
    
    // Calculate economic metrics
    val totalMaintenanceCost = remember(ships) {
        ships.sumOf { it.maintenanceCost }
    }
    
    val revenue = remember { 2_500_000.0 } // TODO: Calculate from routes
    val profit = revenue - totalMaintenanceCost
    val profitMargin = if (revenue > 0) (profit / revenue) * 100 else 0.0
    
    LazyColumn(
        modifier = modifier,
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Financial Summary
        item {
            FinancialSummaryCard(
                balance = money,
                revenue = revenue,
                expenses = totalMaintenanceCost,
                profit = profit
            )
        }
        
        // Performance Chart
        item {
            PerformanceChartCard(
                profitMargin = profitMargin.toFloat(),
                utilizationRate = 0.75f, // TODO: Get from view model
                efficiencyRate = 0.82f
            )
        }
        
        // Market Trends
        item {
            MarketTrendsCard()
        }
        
        // Quick Actions
        item {
            QuickActionsCard(
                onOptimizeRoutes = { /* TODO */ },
                onMarketAnalysis = { /* TODO */ },
                onFinancialReport = { /* TODO */ }
            )
        }
    }
}

@Composable
private fun FinancialSummaryCard(
    balance: Double,
    revenue: Double,
    expenses: Double,
    profit: Double,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(24.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.primaryContainer
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(24.dp)
        ) {
            Text(
                text = "Financial Overview",
                style = MaterialTheme.typography.headlineSmall,
                color = MaterialTheme.colorScheme.onPrimaryContainer,
                fontWeight = FontWeight.Bold
            )
            
            Spacer(modifier = Modifier.height(24.dp))
            
            // Balance
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Default.AccountBalance,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(24.dp)
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Text(
                        text = "Balance",
                        style = MaterialTheme.typography.titleMedium
                    )
                }
                Text(
                    text = "$${String.format("%,.0f", balance)}",
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.primary
                )
            }
            
            Spacer(modifier = Modifier.height(16.dp))
            Divider(color = MaterialTheme.colorScheme.outlineVariant)
            Spacer(modifier = Modifier.height(16.dp))
            
            // Metrics Grid
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                FinancialMetric(
                    icon = Icons.Default.TrendingUp,
                    label = "Revenue",
                    value = "$${String.format("%,.0f", revenue)}",
                    color = MaterialTheme.colorScheme.primary,
                    trend = 12.5f
                )
                FinancialMetric(
                    icon = Icons.Default.TrendingDown,
                    label = "Expenses",
                    value = "$${String.format("%,.0f", expenses)}",
                    color = MaterialTheme.colorScheme.error,
                    trend = -5.2f
                )
                FinancialMetric(
                    icon = Icons.Default.AttachMoney,
                    label = "Profit",
                    value = "$${String.format("%,.0f", profit)}",
                    color = if (profit > 0) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error,
                    trend = if (profit > 0) 8.3f else -8.3f
                )
            }
        }
    }
}

@Composable
private fun FinancialMetric(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    value: String,
    color: Color,
    trend: Float,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = color,
            modifier = Modifier.size(32.dp)
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = label,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Text(
            text = value,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = color
        )
        // Trend indicator
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center
        ) {
            Icon(
                imageVector = if (trend > 0) Icons.Default.ArrowUpward else Icons.Default.ArrowDownward,
                contentDescription = null,
                tint = if (trend > 0) Color.Green else Color.Red,
                modifier = Modifier.size(12.dp)
            )
            Text(
                text = "${kotlin.math.abs(trend)}%",
                style = MaterialTheme.typography.bodySmall,
                color = if (trend > 0) Color.Green else Color.Red
            )
        }
    }
}

@Composable
private fun PerformanceChartCard(
    profitMargin: Float,
    utilizationRate: Float,
    efficiencyRate: Float,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp)
        ) {
            Text(
                text = "Performance Metrics",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold
            )
            
            Spacer(modifier = Modifier.height(24.dp))
            
            // Circular chart
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(200.dp),
                contentAlignment = Alignment.Center
            ) {
                Canvas(
                    modifier = Modifier.size(180.dp)
                ) {
                    drawPerformanceChart(
                        profitMargin = profitMargin,
                        utilizationRate = utilizationRate,
                        efficiencyRate = efficiencyRate
                    )
                }
            }
            
            Spacer(modifier = Modifier.height(24.dp))
            
            // Legend
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                ChartLegendItem(
                    color = MaterialTheme.colorScheme.primary,
                    label = "Profit Margin",
                    value = "${profitMargin.toInt()}%"
                )
                ChartLegendItem(
                    color = MaterialTheme.colorScheme.secondary,
                    label = "Utilization",
                    value = "${(utilizationRate * 100).toInt()}%"
                )
                ChartLegendItem(
                    color = MaterialTheme.colorScheme.tertiary,
                    label = "Efficiency",
                    value = "${(efficiencyRate * 100).toInt()}%"
                )
            }
        }
    }
}

private fun DrawScope.drawPerformanceChart(
    profitMargin: Float,
    utilizationRate: Float,
    efficiencyRate: Float
) {
    val centerX = size.width / 2
    val centerY = size.height / 2
    val radius = size.minDimension / 2 * 0.8f
    
    // Background circle
    drawCircle(
        color = Color.LightGray.copy(alpha = 0.2f),
        radius = radius,
        center = Offset(centerX, centerY),
        style = Stroke(width = 40f)
    )
    
    // Profit margin arc
    drawArc(
        color = Color(0xFF1976D2),
        startAngle = -90f,
        sweepAngle = profitMargin * 3.6f,
        useCenter = false,
        topLeft = Offset(centerX - radius, centerY - radius),
        size = Size(radius * 2, radius * 2),
        style = Stroke(width = 30f, cap = StrokeCap.Round)
    )
    
    // Utilization arc (offset)
    val utilRadius = radius * 0.75f
    drawArc(
        color = Color(0xFF388E3C),
        startAngle = -90f,
        sweepAngle = utilizationRate * 360f,
        useCenter = false,
        topLeft = Offset(centerX - utilRadius, centerY - utilRadius),
        size = Size(utilRadius * 2, utilRadius * 2),
        style = Stroke(width = 20f, cap = StrokeCap.Round)
    )
    
    // Efficiency arc (inner)
    val effRadius = radius * 0.5f
    drawArc(
        color = Color(0xFFF57C00),
        startAngle = -90f,
        sweepAngle = efficiencyRate * 360f,
        useCenter = false,
        topLeft = Offset(centerX - effRadius, centerY - effRadius),
        size = Size(effRadius * 2, effRadius * 2),
        style = Stroke(width = 15f, cap = StrokeCap.Round)
    )
}

@Composable
private fun ChartLegendItem(
    color: Color,
    label: String,
    value: String,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(12.dp)
                .clip(RoundedCornerShape(2.dp))
                .background(color)
        )
        Spacer(modifier = Modifier.width(8.dp))
        Column {
            Text(
                text = label,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Text(
                text = value,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Bold
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MarketTrendsCard(
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Market Trends",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.SemiBold
                )
                AssistChip(
                    onClick = { /* TODO */ },
                    label = { Text("Live") },
                    leadingIcon = {
                        Icon(
                            imageVector = Icons.Default.RadioButtonChecked,
                            contentDescription = null,
                            modifier = Modifier.size(16.dp),
                            tint = Color.Red
                        )
                    }
                )
            }
            
            Spacer(modifier = Modifier.height(16.dp))
            
            // Sample trend items
            MarketTrendItem(
                commodity = "Electronics",
                price = 2450.0,
                change = 3.2f,
                volume = 15000
            )
            MarketTrendItem(
                commodity = "Textiles",
                price = 850.0,
                change = -1.5f,
                volume = 22000
            )
            MarketTrendItem(
                commodity = "Machinery",
                price = 5200.0,
                change = 0.8f,
                volume = 8000
            )
        }
    }
}

@Composable
private fun MarketTrendItem(
    commodity: String,
    price: Double,
    change: Float,
    volume: Int,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = commodity,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium
            )
            Text(
                text = "$volume TEU",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        
        Column(horizontalAlignment = Alignment.End) {
            Text(
                text = "$${String.format("%.2f", price)}",
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Bold
            )
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    imageVector = if (change > 0) Icons.Default.ArrowUpward else Icons.Default.ArrowDownward,
                    contentDescription = null,
                    tint = if (change > 0) Color.Green else Color.Red,
                    modifier = Modifier.size(12.dp)
                )
                Text(
                    text = "${kotlin.math.abs(change)}%",
                    style = MaterialTheme.typography.bodySmall,
                    color = if (change > 0) Color.Green else Color.Red
                )
            }
        }
    }
}

@Composable
private fun QuickActionsCard(
    onOptimizeRoutes: () -> Unit,
    onMarketAnalysis: () -> Unit,
    onFinancialReport: () -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.secondaryContainer
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp)
        ) {
            Text(
                text = "Quick Actions",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSecondaryContainer
            )
            
            Spacer(modifier = Modifier.height(16.dp))
            
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                OutlinedButton(
                    onClick = onOptimizeRoutes,
                    modifier = Modifier.weight(1f)
                ) {
                    Icon(
                        imageVector = Icons.Default.Route,
                        contentDescription = null,
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("Optimize")
                }
                
                OutlinedButton(
                    onClick = onMarketAnalysis,
                    modifier = Modifier.weight(1f)
                ) {
                    Icon(
                        imageVector = Icons.Default.Analytics,
                        contentDescription = null,
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("Analyze")
                }
                
                OutlinedButton(
                    onClick = onFinancialReport,
                    modifier = Modifier.weight(1f)
                ) {
                    Icon(
                        imageVector = Icons.Default.Description,
                        contentDescription = null,
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("Report")
                }
            }
        }
    }
}