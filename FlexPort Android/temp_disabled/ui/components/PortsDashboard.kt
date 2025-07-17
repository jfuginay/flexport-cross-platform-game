package com.flexport.game.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.flexport.game.models.Port
import com.flexport.game.models.PortType
import com.flexport.game.viewmodels.GameViewModel

/**
 * Ports dashboard showing all available ports and their status
 */
@Composable
fun PortsDashboard(
    gameViewModel: GameViewModel,
    selectedPortId: String?,
    onPortSelected: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val ports by gameViewModel.ports.collectAsState()
    
    LazyColumn(
        modifier = modifier,
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Header
        item {
            Text(
                text = "Global Ports Network",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "${ports.size} ports worldwide",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        
        // Port list
        items(ports, key = { it.id }) { port ->
            PortCard(
                port = port,
                isSelected = port.id == selectedPortId,
                onClick = { onPortSelected(port.id) }
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PortCard(
    port: Port,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    // Status indicator values available throughout the function
    val utilizationRate = 0.75f // Mock utilization for now
    val statusColor = when {
        utilizationRate > 0.9f -> Color.Red
        utilizationRate > 0.7f -> Color(0xFFFFA500)
        else -> Color.Green
    }
    
    Card(
        modifier = modifier
            .fillMaxWidth()
            .clickable { onClick() },
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = if (isSelected) {
                MaterialTheme.colorScheme.primaryContainer
            } else {
                MaterialTheme.colorScheme.surface
            }
        ),
        elevation = CardDefaults.cardElevation(
            defaultElevation = if (isSelected) 8.dp else 2.dp
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            // Port header
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Port type icon
                Box(
                    modifier = Modifier
                        .size(48.dp)
                        .clip(CircleShape)
                        .background(
                            when (port.type) {
                                PortType.SEA -> Color(0xFF1976D2).copy(alpha = 0.1f)
                                PortType.AIR -> Color(0xFF388E3C).copy(alpha = 0.1f)
                                PortType.RAIL -> Color(0xFFF57C00).copy(alpha = 0.1f)
                                PortType.MULTIMODAL -> Color(0xFF7B1FA2).copy(alpha = 0.1f)
                            }
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = when (port.type) {
                            PortType.SEA -> Icons.Default.DirectionsBoat
                            PortType.AIR -> Icons.Default.Flight
                            PortType.RAIL -> Icons.Default.Train
                            PortType.MULTIMODAL -> Icons.Default.Hub
                        },
                        contentDescription = null,
                        tint = when (port.type) {
                            PortType.SEA -> Color(0xFF1976D2)
                            PortType.AIR -> Color(0xFF388E3C)
                            PortType.RAIL -> Color(0xFFF57C00)
                            PortType.MULTIMODAL -> Color(0xFF7B1FA2)
                        },
                        modifier = Modifier.size(24.dp)
                    )
                }
                
                Spacer(modifier = Modifier.width(16.dp))
                
                // Port info
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = port.name,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold
                    )
                    Text(
                        text = "${port.position.latitude.toInt()}°, ${port.position.longitude.toInt()}°",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    
                    Spacer(modifier = Modifier.height(4.dp))
                    
                    // Port type chip
                    AssistChip(
                        onClick = { },
                        label = {
                            Text(
                                text = port.type.name,
                                style = MaterialTheme.typography.bodySmall
                            )
                        },
                        modifier = Modifier.height(24.dp)
                    )
                }
                
                // Status indicator
                Column(horizontalAlignment = Alignment.End) {
                    Box(
                        modifier = Modifier
                            .size(12.dp)
                            .clip(CircleShape)
                            .background(statusColor)
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = "${(utilizationRate * 100).toInt()}%",
                        style = MaterialTheme.typography.bodySmall,
                        color = statusColor
                    )
                }
            }
            
            Spacer(modifier = Modifier.height(16.dp))
            
            // Capacity bar
            Column {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(
                        text = "Capacity Utilization",
                        style = MaterialTheme.typography.bodyMedium
                    )
                    Text(
                        text = "${String.format("%,d", (port.capacity * utilizationRate).toInt())} / ${String.format("%,d", port.capacity)} TEU",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                
                Spacer(modifier = Modifier.height(8.dp))
                
                LinearProgressIndicator(
                    progress = utilizationRate,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(8.dp)
                        .clip(RoundedCornerShape(4.dp)),
                    color = when {
                        utilizationRate > 0.9f -> MaterialTheme.colorScheme.error
                        utilizationRate > 0.7f -> Color(0xFFFFA500)
                        else -> MaterialTheme.colorScheme.primary
                    },
                    trackColor = MaterialTheme.colorScheme.surfaceVariant
                )
            }
            
            Spacer(modifier = Modifier.height(16.dp))
            
            // Action buttons
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                OutlinedButton(
                    onClick = { /* TODO: View details */ },
                    modifier = Modifier.weight(1f)
                ) {
                    Icon(
                        imageVector = Icons.Default.Info,
                        contentDescription = null,
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("Details")
                }
                
                Button(
                    onClick = { /* TODO: Create route */ },
                    modifier = Modifier.weight(1f)
                ) {
                    Icon(
                        imageVector = Icons.Default.Route,
                        contentDescription = null,
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("Route")
                }
            }
        }
    }
}