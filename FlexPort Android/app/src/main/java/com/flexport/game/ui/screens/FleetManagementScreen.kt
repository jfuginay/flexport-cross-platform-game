package com.flexport.game.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.flexport.game.models.Ship

@Composable
fun FleetManagementScreen(
    onNavigateBack: () -> Unit = {},
    modifier: Modifier = Modifier
) {
    var selectedShip by remember { mutableStateOf<Ship?>(null) }
    var showingShipDetails by remember { mutableStateOf(false) }
    var showingPurchaseView by remember { mutableStateOf(false) }
    
    // Sample ships data (in real app this would come from ViewModel)
    val ships = remember { generateSampleShips() }
    
    Surface(
        modifier = modifier.fillMaxSize(),
        color = MaterialTheme.colors.background
    ) {
        Column(
            modifier = Modifier.fillMaxSize()
        ) {
            // Top App Bar
            TopAppBar(
                title = { 
                    Text(
                        text = "Fleet Management",
                        style = MaterialTheme.typography.h6.copy(
                            fontWeight = FontWeight.Medium
                        )
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(
                            imageVector = Icons.Default.ArrowBack,
                            contentDescription = "Back"
                        )
                    }
                },
                actions = {
                    IconButton(onClick = { showingPurchaseView = true }) {
                        Icon(
                            imageVector = Icons.Default.Add,
                            contentDescription = "Buy Ship"
                        )
                    }
                },
                backgroundColor = MaterialTheme.colors.primary,
                contentColor = Color.White,
                elevation = 4.dp
            )
            
            // Fleet Summary Header
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        brush = Brush.verticalGradient(
                            colors = listOf(
                                MaterialTheme.colors.primary.copy(alpha = 0.1f),
                                MaterialTheme.colors.background
                            )
                        )
                    )
                    .padding(16.dp)
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
                            Column {
                                Text(
                                    text = "Fleet Overview",
                                    style = MaterialTheme.typography.h5,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colors.primary
                                )
                                Text(
                                    text = "${ships.size} Ships",
                                    style = MaterialTheme.typography.body2,
                                    color = MaterialTheme.colors.onSurface.copy(alpha = 0.7f)
                                )
                            }
                            
                            OutlinedButton(
                                onClick = { showingPurchaseView = true },
                                shape = RoundedCornerShape(8.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Add,
                                    contentDescription = "Buy Ship",
                                    modifier = Modifier.size(16.dp)
                                )
                                Spacer(modifier = Modifier.width(4.dp))
                                Text("Buy Ship")
                            }
                        }
                        
                        Spacer(modifier = Modifier.height(16.dp))
                        
                        // Fleet Statistics
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceEvenly
                        ) {
                            FleetStatItem(
                                label = "Total Capacity",
                                value = "${ships.sumOf { it.capacity }} TEU",
                                icon = Icons.Default.Inventory
                            )
                            FleetStatItem(
                                label = "In Transit",
                                value = ships.count { it.status == com.flexport.game.models.ShipStatus.IN_TRANSIT }.toString(),
                                icon = Icons.Default.Route
                            )
                            FleetStatItem(
                                label = "Avg Speed",
                                value = "${ships.map { it.speed }.average().toInt()} kn",
                                icon = Icons.Default.Speed
                            )
                        }
                    }
                }
            }
            
            // Ship List
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                items(ships) { ship ->
                    ShipCard(
                        ship = ship,
                        isSelected = selectedShip?.id == ship.id,
                        onClick = {
                            selectedShip = ship
                            showingShipDetails = true
                        }
                    )
                }
            }
        }
    }
    
    // Ship Details Dialog
    if (showingShipDetails && selectedShip != null) {
        ShipDetailsDialog(
            ship = selectedShip!!,
            onDismiss = { showingShipDetails = false }
        )
    }
    
    // Ship Purchase Dialog
    if (showingPurchaseView) {
        ShipPurchaseDialog(
            onDismiss = { showingPurchaseView = false },
            onPurchase = { shipType ->
                // Handle ship purchase
                showingPurchaseView = false
            }
        )
    }
}

@Composable
private fun FleetStatItem(
    label: String,
    value: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(
            imageVector = icon,
            contentDescription = label,
            modifier = Modifier.size(24.dp),
            tint = MaterialTheme.colors.primary
        )
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = value,
            style = MaterialTheme.typography.h6,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colors.primary
        )
        Text(
            text = label,
            style = MaterialTheme.typography.caption,
            color = MaterialTheme.colors.onSurface.copy(alpha = 0.7f),
            textAlign = TextAlign.Center
        )
    }
}

@Composable
private fun ShipCard(
    ship: Ship,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth(),
        elevation = if (isSelected) 8.dp else 4.dp,
        shape = RoundedCornerShape(12.dp),
        backgroundColor = if (isSelected) MaterialTheme.colors.primary.copy(alpha = 0.1f) else MaterialTheme.colors.surface
    ) {
        Column(
            modifier = Modifier
                .padding(16.dp)
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
                            imageVector = Icons.Default.DirectionsBoat,
                            contentDescription = "Ship",
                            modifier = Modifier.size(28.dp),
                            tint = MaterialTheme.colors.primary
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = ship.name,
                            style = MaterialTheme.typography.h6,
                            fontWeight = FontWeight.Bold
                        )
                    }
                    
                    Spacer(modifier = Modifier.height(8.dp))
                    
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(16.dp)
                    ) {
                        ShipStatChip(
                            icon = Icons.Default.Inventory,
                            label = "${ship.capacity} TEU"
                        )
                        ShipStatChip(
                            icon = Icons.Default.Speed,
                            label = "${ship.speed.toInt()} knots"
                        )
                        ShipStatChip(
                            icon = Icons.Default.Engineering,
                            label = "${(ship.condition).toInt()}%"
                        )
                    }
                }
                
                Column(
                    horizontalAlignment = Alignment.End
                ) {
                    Surface(
                        color = Color(0xFF4CAF50),
                        shape = RoundedCornerShape(4.dp)
                    ) {
                        Text(
                            text = "ACTIVE",
                            style = MaterialTheme.typography.caption,
                            color = Color.White,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }
            
            Spacer(modifier = Modifier.height(12.dp))
            
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    text = "Status: ${ship.status.name}",
                    style = MaterialTheme.typography.body2,
                    color = MaterialTheme.colors.onSurface.copy(alpha = 0.7f)
                )
                
                Text(
                    text = "Maintenance: $${ship.maintenanceCost.toInt()}/day",
                    style = MaterialTheme.typography.body2,
                    color = Color(0xFFFF9800)
                )
            }
            
            Spacer(modifier = Modifier.height(8.dp))
            
            OutlinedButton(
                onClick = onClick,
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(8.dp)
            ) {
                Text("View Details")
            }
        }
    }
}

@Composable
private fun ShipStatChip(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String
) {
    Surface(
        color = MaterialTheme.colors.primary.copy(alpha = 0.1f),
        shape = RoundedCornerShape(6.dp)
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                modifier = Modifier.size(12.dp),
                tint = MaterialTheme.colors.primary
            )
            Spacer(modifier = Modifier.width(4.dp))
            Text(
                text = label,
                style = MaterialTheme.typography.caption,
                color = MaterialTheme.colors.primary
            )
        }
    }
}

@Composable
private fun ShipDetailsDialog(
    ship: Ship,
    onDismiss: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(
                text = ship.name,
                style = MaterialTheme.typography.h6,
                fontWeight = FontWeight.Bold
            )
        },
        text = {
            Column {
                DetailRow("Type", "Container Ship")
                DetailRow("Capacity", "${ship.capacity} TEU")
                DetailRow("Speed", "${ship.speed.toInt()} knots")
                DetailRow("Condition", "${ship.condition.toInt()}%")
                DetailRow("Daily Maintenance", "$${ship.maintenanceCost.toInt()}")
                DetailRow("Status", ship.status.name)
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text("Close")
            }
        }
    )
}

@Composable
private fun DetailRow(label: String, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 2.dp),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.body2,
            color = MaterialTheme.colors.onSurface.copy(alpha = 0.7f)
        )
        Text(
            text = value,
            style = MaterialTheme.typography.body2,
            fontWeight = FontWeight.Medium
        )
    }
}

@Composable
private fun ShipPurchaseDialog(
    onDismiss: () -> Unit,
    onPurchase: (String) -> Unit
) {
    val shipTypes = listOf(
        "Small Container Ship" to "$1,250,000",
        "Large Container Ship" to "$2,500,000",
        "Ultra Large Container Ship" to "$5,000,000"
    )
    
    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(
                text = "Ship Market",
                style = MaterialTheme.typography.h6,
                fontWeight = FontWeight.Bold
            )
        },
        text = {
            Column {
                shipTypes.forEach { (type, price) ->
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 4.dp),
                        elevation = 2.dp
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(12.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column {
                                Text(
                                    text = type,
                                    style = MaterialTheme.typography.body1,
                                    fontWeight = FontWeight.Medium
                                )
                                Text(
                                    text = price,
                                    style = MaterialTheme.typography.body2,
                                    color = Color(0xFF4CAF50)
                                )
                            }
                            OutlinedButton(
                                onClick = { onPurchase(type) },
                                shape = RoundedCornerShape(6.dp)
                            ) {
                                Text("Buy", fontSize = 12.sp)
                            }
                        }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )
}

// Sample data
private fun generateSampleShips(): List<Ship> {
    return listOf(
        Ship(
            id = "ship1",
            name = "Ocean Pioneer",
            type = com.flexport.game.models.ShipType.CONTAINER_SHIP,
            capacity = 18000,
            speed = 23.0,
            fuelEfficiency = 0.85,
            maintenanceCost = 15000.0,
            purchasePrice = 50000000.0,
            currentPosition = com.flexport.game.models.GeographicalPosition(1.3521, 103.8198), // Singapore
            status = com.flexport.game.models.ShipStatus.IN_TRANSIT,
            condition = 92.0
        ),
        Ship(
            id = "ship2", 
            name = "Pacific Voyager",
            type = com.flexport.game.models.ShipType.CONTAINER_SHIP,
            capacity = 14000,
            speed = 21.5,
            fuelEfficiency = 0.82,
            maintenanceCost = 12000.0,
            purchasePrice = 35000000.0,
            currentPosition = com.flexport.game.models.GeographicalPosition(22.3193, 114.1694), // Hong Kong
            status = com.flexport.game.models.ShipStatus.DOCKED,
            condition = 85.0
        ),
        Ship(
            id = "ship3",
            name = "Atlantic Express",
            type = com.flexport.game.models.ShipType.CONTAINER_SHIP,
            capacity = 10000,
            speed = 19.0,
            fuelEfficiency = 0.78,
            maintenanceCost = 9000.0,
            purchasePrice = 25000000.0,
            currentPosition = com.flexport.game.models.GeographicalPosition(40.7128, -74.0060), // New York
            status = com.flexport.game.models.ShipStatus.DOCKED,
            condition = 78.0
        )
    )
}

@Preview(showBackground = true)
@Composable
fun FleetManagementScreenPreview() {
    MaterialTheme {
        FleetManagementScreen()
    }
}