package com.flexport.game.ui.components

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.flexport.game.networking.GameSession
import com.flexport.game.viewmodels.GameViewModel

/**
 * Status bar showing key game information at the bottom of landscape view
 */
@Composable
fun GameStatusBar(
    gameViewModel: GameViewModel,
    currentSession: GameSession?,
    modifier: Modifier = Modifier
) {
    val money by gameViewModel.money.collectAsState()
    val ships by gameViewModel.ships.collectAsState()
    val fleetUtilization by gameViewModel.fleetUtilization.collectAsState()
    
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Left section - Financial info
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            StatusItem(
                icon = Icons.Default.AccountBalance,
                label = "Balance",
                value = "$${String.format("%,.0f", money)}",
                color = MaterialTheme.colorScheme.primary
            )
            
            VerticalDivider()
            
            StatusItem(
                icon = Icons.Default.DirectionsBoat,
                label = "Fleet",
                value = "${ships.size} ships",
                color = MaterialTheme.colorScheme.secondary
            )
        }
        
        // Center section - Performance
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            StatusItem(
                icon = Icons.Default.Speed,
                label = "Utilization",
                value = "${(fleetUtilization * 100).toInt()}%",
                color = when {
                    fleetUtilization > 0.8f -> Color.Green
                    fleetUtilization > 0.5f -> Color.Orange
                    else -> Color.Red
                }
            )
            
            if (currentSession != null) {
                VerticalDivider()
                
                StatusItem(
                    icon = Icons.Default.Groups,
                    label = "Players",
                    value = "${currentSession.players.size}",
                    color = MaterialTheme.colorScheme.tertiary
                )
            }
        }
        
        // Right section - Game time/turn
        Row(
            verticalAlignment = Alignment.CenterVertically
        ) {
            if (currentSession?.turn != null) {
                StatusItem(
                    icon = Icons.Default.RotateRight,
                    label = "Turn",
                    value = currentSession.turn.toString(),
                    color = MaterialTheme.colorScheme.outline
                )
            } else {
                StatusItem(
                    icon = Icons.Default.AccessTime,
                    label = "Time",
                    value = formatGameTime(),
                    color = MaterialTheme.colorScheme.outline
                )
            }
        }
    }
}

@Composable
private fun StatusItem(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    value: String,
    color: Color,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier,
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = color,
            modifier = Modifier.size(16.dp)
        )
        Column {
            Text(
                text = label,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Text(
                text = value,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Bold,
                color = color
            )
        }
    }
}

@Composable
private fun VerticalDivider(
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .width(1.dp)
            .height(24.dp)
            .padding(vertical = 4.dp)
    ) {
        Divider(
            modifier = Modifier.fillMaxHeight(),
            color = MaterialTheme.colorScheme.outlineVariant
        )
    }
}

private fun formatGameTime(): String {
    // Mock implementation - would calculate actual game time
    val hours = (System.currentTimeMillis() / 3600000) % 24
    val minutes = (System.currentTimeMillis() / 60000) % 60
    return String.format("%02d:%02d", hours, minutes)
}