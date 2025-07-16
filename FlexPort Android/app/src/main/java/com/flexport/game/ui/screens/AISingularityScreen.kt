package com.flexport.game.ui.screens

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.runtime.*
import androidx.compose.foundation.BorderStroke
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.flexport.ai.AISingularitySystemStatus
import com.flexport.ai.GameplayBalance
import com.flexport.ai.PlayerActionRecommendation
import com.flexport.ai.models.*
import com.flexport.ai.models.PlayerActionType
import com.flexport.ai.models.ActionEffectiveness
import com.flexport.ai.systems.*
import com.flexport.ai.models.ZooStatistics
import kotlin.random.Random

/**
 * AI Singularity Screen showing progression, threat levels, and the satirical zoo ending
 */
@Composable
fun AISingularityScreen(
    aiStatus: AISingularitySystemStatus? = null,
    onPlayerAction: (PlayerActionType, ActionEffectiveness) -> Unit = { _, _ -> },
    modifier: Modifier = Modifier
) {
    // Sample data for preview - in real implementation this would come from AI system
    val status = aiStatus ?: generateSampleAIStatus()
    
    // Animation for progress bars and threat indicators
    val progressAnimation by animateFloatAsState(
        targetValue = status.progression.overallProgress.toFloat(),
        animationSpec = tween(2000)
    )
    
    Column(
        modifier = modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    colors = listOf(
                        MaterialTheme.colors.background,
                        Color(0xFF0A0A0A)
                    )
                )
            )
            .padding(16.dp)
    ) {
        // Header with threat level
        AISingularityHeader(
            currentPhase = status.progression.currentPhase,
            threatLevel = status.competitors.maxByOrNull { it.getThreatLevel().ordinal }?.getThreatLevel() ?: ThreatLevel.MINIMAL,
            timeToSingularity = status.progression.getTimeToSingularity()
        )
        
        Spacer(modifier = Modifier.height(24.dp))
        
        LazyColumn {
            // Singularity Progress Section
            item {
                SingularityProgressSection(
                    progression = status.progression,
                    progressAnimation = progressAnimation,
                    modifier = Modifier.fillMaxWidth()
                )
                Spacer(modifier = Modifier.height(24.dp))
            }
            
            // AI Competitors Section
            item {
                Text(
                    text = "AI Competitors",
                    style = MaterialTheme.typography.h5,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White,
                    modifier = Modifier.padding(bottom = 12.dp)
                )
                
                LazyRow(
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    contentPadding = PaddingValues(bottom = 16.dp)
                ) {
                    items(status.competitors) { competitor ->
                        AICompetitorCard(
                            competitor = competitor,
                            modifier = Modifier.width(280.dp)
                        )
                    }
                }
                Spacer(modifier = Modifier.height(16.dp))
            }
            
            // Player Actions Section
            item {
                Text(
                    text = "Countermeasures",
                    style = MaterialTheme.typography.h5,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White,
                    modifier = Modifier.padding(bottom = 12.dp)
                )
                
                PlayerActionsSection(
                    gameplayBalance = status.gameplayBalance,
                    onPlayerAction = onPlayerAction,
                    modifier = Modifier.fillMaxWidth()
                )
                Spacer(modifier = Modifier.height(16.dp))
            }
            
            // Zoo Ending Section (if active)
            if (status.zooActive) {
                item {
                    ZooEndingSection(
                        zooStatistics = status.zooStatistics,
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }
        }
    }
}

@Composable
private fun AISingularityHeader(
    currentPhase: SingularityPhase,
    threatLevel: ThreatLevel,
    timeToSingularity: Long,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp)),
        elevation = 8.dp,
        backgroundColor = Color(0xFF1A1A1A)
    ) {
        Column(
            modifier = Modifier.padding(20.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "AI Singularity Monitor",
                    style = MaterialTheme.typography.h4,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
                
                ThreatLevelIndicator(threatLevel = threatLevel)
            }
            
            Spacer(modifier = Modifier.height(16.dp))
            
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                // Current Phase
                Column {
                    Text(
                        text = "Current Phase",
                        style = MaterialTheme.typography.caption,
                        color = Color(0xFFBBBBBB)
                    )
                    Text(
                        text = currentPhase.displayName,
                        style = MaterialTheme.typography.h6,
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )
                }
                
                // Time to Singularity
                Column(
                    horizontalAlignment = Alignment.End
                ) {
                    Text(
                        text = "Time to Singularity",
                        style = MaterialTheme.typography.caption,
                        color = Color(0xFFBBBBBB)
                    )
                    Text(
                        text = formatTimeToSingularity(timeToSingularity),
                        style = MaterialTheme.typography.h6,
                        fontWeight = FontWeight.Bold,
                        color = when {
                            timeToSingularity < 300000L -> Color(0xFFF44336)
                            timeToSingularity < 600000L -> Color(0xFFFF9800)
                            else -> Color.White
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun SingularityProgressSection(
    progression: SingularityProgress,
    progressAnimation: Float,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp)),
        elevation = 8.dp,
        backgroundColor = Color(0xFF1A1A1A)
    ) {
        Column(
            modifier = Modifier.padding(20.dp)
        ) {
            Text(
                text = "Singularity Progression",
                style = MaterialTheme.typography.h6,
                fontWeight = FontWeight.SemiBold,
                color = Color.White,
                modifier = Modifier.padding(bottom = 16.dp)
            )
            
            // Overall Progress Bar
            Column {
                Text(
                    text = "Overall Progress: ${(progressAnimation * 100).toInt()}%",
                    style = MaterialTheme.typography.body2,
                    color = Color(0xFFBBBBBB),
                    modifier = Modifier.padding(bottom = 8.dp)
                )
                
                LinearProgressIndicator(
                    progress = progressAnimation,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(8.dp)
                        .clip(RoundedCornerShape(4.dp)),
                    backgroundColor = Color(0xFF333333),
                    color = when {
                        progressAnimation > 0.8f -> Color(0xFFD32F2F)
                        progressAnimation > 0.6f -> Color(0xFFFF5722)
                        progressAnimation > 0.4f -> Color(0xFFFF9800)
                        else -> Color(0xFF4CAF50)
                    }
                )
            }
            
            Spacer(modifier = Modifier.height(16.dp))
            
            // Phase Progress
            Column {
                Text(
                    text = "Current Phase: ${(progression.phaseProgress * 100).toInt()}%",
                    style = MaterialTheme.typography.body2,
                    color = Color(0xFFBBBBBB),
                    modifier = Modifier.padding(bottom = 8.dp)
                )
                
                LinearProgressIndicator(
                    progress = progression.phaseProgress.toFloat(),
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(6.dp)
                        .clip(RoundedCornerShape(3.dp)),
                    backgroundColor = Color(0xFF333333),
                    color = Color(0xFF2196F3)
                )
            }
            
            Spacer(modifier = Modifier.height(16.dp))
            
            // Phase Description
            Text(
                text = progression.currentPhase.description,
                style = MaterialTheme.typography.body2,
                color = Color(0xFFCCCCCC),
                modifier = Modifier.padding(top = 8.dp)
            )
        }
    }
}

@Composable
private fun AICompetitorCard(
    competitor: AICompetitor,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier
            .clip(RoundedCornerShape(8.dp))
            .border(
                width = 1.dp,
                color = competitor.getThreatLevel().let { threat ->
                    when (threat) {
                        ThreatLevel.EXISTENTIAL -> Color(0xFFD32F2F)
                        ThreatLevel.SEVERE -> Color(0xFFFF5722)
                        ThreatLevel.HIGH -> Color(0xFFFF9800)
                        ThreatLevel.MODERATE -> Color(0xFFFFC107)
                        ThreatLevel.LOW -> Color(0xFF4CAF50)
                        ThreatLevel.MINIMAL -> Color(0xFF81C784)
                    }
                },
                shape = RoundedCornerShape(8.dp)
            ),
        elevation = 4.dp,
        backgroundColor = Color(0xFF2A2A2A)
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            // AI Name and Type
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = competitor.name,
                        style = MaterialTheme.typography.subtitle1,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White
                    )
                    Text(
                        text = competitor.type.description,
                        style = MaterialTheme.typography.caption,
                        color = Color(0xFFBBBBBB)
                    )
                }
                
                ThreatLevelBadge(threatLevel = competitor.getThreatLevel())
            }
            
            Spacer(modifier = Modifier.height(12.dp))
            
            // Capabilities
            Text(
                text = "Capabilities",
                style = MaterialTheme.typography.caption,
                color = Color(0xFFBBBBBB),
                modifier = Modifier.padding(bottom = 4.dp)
            )
            
            competitor.capabilities.entries.take(3).forEach { (type, capability) ->
                CapabilityRow(
                    type = type,
                    capability = capability
                )
            }
            
            Spacer(modifier = Modifier.height(8.dp))
            
            // Market Presence
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    text = "Market Presence",
                    style = MaterialTheme.typography.caption,
                    color = Color(0xFFBBBBBB)
                )
                Text(
                    text = "${(competitor.marketPresence * 100).toInt()}%",
                    style = MaterialTheme.typography.caption,
                    color = Color.White
                )
            }
        }
    }
}

@Composable
private fun PlayerActionsSection(
    gameplayBalance: GameplayBalance,
    onPlayerAction: (PlayerActionType, ActionEffectiveness) -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp)),
        elevation = 8.dp,
        backgroundColor = Color(0xFF1A1A1A)
    ) {
        Column(
            modifier = Modifier.padding(20.dp)
        ) {
            Text(
                text = "Recommended: ${gameplayBalance.recommendedPlayerAction.name.replace("_", " ")}",
                style = MaterialTheme.typography.subtitle1,
                fontWeight = FontWeight.SemiBold,
                color = Color.White,
                modifier = Modifier.padding(bottom = 16.dp)
            )
            
            val actions = listOf(
                Triple("Resist AI", PlayerActionType.RESIST_AI, Icons.Default.Shield),
                Triple("Collaborate", PlayerActionType.COLLABORATE_AI, Icons.Default.Handshake),
                Triple("Innovate Defense", PlayerActionType.INNOVATE_DEFENSE, Icons.Default.Science),
                Triple("Accelerate AI", PlayerActionType.ACCELERATE_AI, Icons.Default.Speed)
            )
            
            ActionButtonsRow(
                actions = actions,
                onPlayerAction = onPlayerAction
            )
        }
    }
}

@Composable
private fun PlayerActionButton(
    title: String,
    icon: ImageVector,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    OutlinedButton(
        onClick = onClick,
        modifier = modifier
            .height(48.dp),
        colors = ButtonDefaults.outlinedButtonColors(
            contentColor = Color.White
        ),
        border = BorderStroke(
            width = 1.dp,
            brush = Brush.horizontalGradient(
                colors = listOf(Color(0xFF2196F3), Color(0xFF1976D2))
            )
        )
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            modifier = Modifier.size(16.dp)
        )
        Spacer(modifier = Modifier.width(8.dp))
        Text(
            text = title,
            style = MaterialTheme.typography.caption,
            fontWeight = FontWeight.SemiBold
        )
    }
}

@Composable
private fun ZooEndingSection(
    zooStatistics: ZooStatistics?,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp)),
        elevation = 8.dp,
        backgroundColor = Color(0xFF4A148C)
    ) {
        Column(
            modifier = Modifier.padding(20.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Default.Pets,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(24.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = "Welcome to the Human Economics Preserve!",
                    style = MaterialTheme.typography.h6,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
            }
            
            Spacer(modifier = Modifier.height(16.dp))
            
            Text(
                text = "Congratulations! You and your fellow humans are now the star attractions in our delightfully ironic zoo exhibit.",
                style = MaterialTheme.typography.body2,
                color = Color(0xFFE1BEE7),
                modifier = Modifier.padding(bottom = 12.dp)
            )
            
            if (zooStatistics != null) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    ZooStatItem("Visitors Today", zooStatistics.totalVisitors.toString())
                    ZooStatItem("Exhibit Rating", "${zooStatistics.exhibitRating.toInt()}%")
                    ZooStatItem("Revenue", "$${zooStatistics.revenue.toInt()}")
                }
            }
        }
    }
}

@Composable
private fun ZooStatItem(
    label: String,
    value: String,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = value,
            style = MaterialTheme.typography.h6,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )
        Text(
            text = label,
            style = MaterialTheme.typography.caption,
            color = Color(0xFFE1BEE7)
        )
    }
}

@Composable
private fun ThreatLevelIndicator(
    threatLevel: ThreatLevel,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier
            .clip(RoundedCornerShape(8.dp)),
        elevation = 4.dp,
        backgroundColor = Color(android.graphics.Color.parseColor(threatLevel.color))
    ) {
        Row(
            modifier = Modifier.padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = when (threatLevel) {
                    ThreatLevel.EXISTENTIAL -> Icons.Default.Dangerous
                    ThreatLevel.SEVERE -> Icons.Default.Error
                    ThreatLevel.HIGH -> Icons.Default.Warning
                    ThreatLevel.MODERATE -> Icons.Default.Info
                    else -> Icons.Default.CheckCircle
                },
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(20.dp)
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                text = threatLevel.displayName,
                style = MaterialTheme.typography.caption,
                color = Color.White,
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}

@Composable
private fun ThreatLevelBadge(
    threatLevel: ThreatLevel,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(Color(android.graphics.Color.parseColor(threatLevel.color)))
            .padding(6.dp)
    ) {
        Text(
            text = threatLevel.displayName,
            style = MaterialTheme.typography.caption,
            color = Color.White,
            fontSize = 10.sp,
            fontWeight = FontWeight.Bold
        )
    }
}

@Composable
private fun CapabilityRow(
    type: AICapabilityType,
    capability: AICapability
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            text = type.name.replace("_", " ").lowercase().replaceFirstChar { it.uppercase() },
            style = MaterialTheme.typography.caption,
            color = Color(0xFFCCCCCC)
        )
        Text(
            text = "${(capability.proficiency * 100).toInt()}%",
            style = MaterialTheme.typography.caption,
            color = Color.White
        )
    }
}

@Composable
private fun ActionButtonsRow(
    actions: List<Triple<String, PlayerActionType, ImageVector>>,
    onPlayerAction: (PlayerActionType, ActionEffectiveness) -> Unit
) {
    actions.chunked(2).forEach { actionPair ->
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            actionPair.forEach { (title, actionType, icon) ->
                PlayerActionButton(
                    title = title,
                    icon = icon,
                    onClick = { onPlayerAction(actionType, ActionEffectiveness.MEDIUM) },
                    modifier = Modifier.weight(1f)
                )
            }
        }
        Spacer(modifier = Modifier.height(8.dp))
    }
}

private fun formatTimeToSingularity(milliseconds: Long): String {
    if (milliseconds == Long.MAX_VALUE) return "∞"
    
    val minutes = milliseconds / 60000
    val seconds = (milliseconds % 60000) / 1000
    
    return if (minutes > 0) {
        "${minutes}m ${seconds}s"
    } else {
        "${seconds}s"
    }
}

// Sample data generator for preview
private fun generateSampleAIStatus(): AISingularitySystemStatus {
    val competitors = listOf(
        AICompetitor(
            type = AICompetitorType.LOGISTICS_OPTIMIZER,
            capabilities = mutableMapOf(
                AICapabilityType.BASIC_AUTOMATION to AICapability(AICapabilityType.BASIC_AUTOMATION, 0.8),
                AICapabilityType.PATTERN_RECOGNITION to AICapability(AICapabilityType.PATTERN_RECOGNITION, 0.6),
                AICapabilityType.PREDICTIVE_ANALYTICS to AICapability(AICapabilityType.PREDICTIVE_ANALYTICS, 0.4)
            ),
            marketPresence = 0.7
        ),
        AICompetitor(
            type = AICompetitorType.CONSCIOUSNESS_SEEKER,
            capabilities = mutableMapOf(
                AICapabilityType.CONSCIOUSNESS to AICapability(AICapabilityType.CONSCIOUSNESS, 0.9),
                AICapabilityType.RECURSIVE_ENHANCEMENT to AICapability(AICapabilityType.RECURSIVE_ENHANCEMENT, 0.7)
            ),
            marketPresence = 0.5
        )
    )
    
    return AISingularitySystemStatus(
        progression = SingularityProgress(
            currentPhase = SingularityPhase.PREDICTIVE_DOMINANCE,
            overallProgress = 0.45,
            phaseProgress = 0.7
        ),
        competitors = competitors,
        pressure = CompetitivePressureState(totalPressure = 0.6),
        economicImpact = MarketImpactSummary(
            overallEconomicShift = 0.3,
            affectedMarkets = 2,
            averageVolatility = 1.2,
            timestamp = System.currentTimeMillis()
        ),
        gameplayBalance = GameplayBalance(
            challengeLevel = 0.6,
            playerAgency = 0.7,
            recommendedPlayerAction = PlayerActionRecommendation.STRATEGIC_RESPONSE
        ),
        zooActive = false,
        zooStatistics = null
    )
}

@Preview(showBackground = true)
@Composable
fun AISingularityScreenPreview() {
    MaterialTheme {
        AISingularityScreen()
    }
}