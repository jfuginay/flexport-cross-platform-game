package com.flexport.game.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Stop
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
import com.flexport.game.ecs.GameEngine
import com.flexport.game.ecs.GameStats
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking

@Composable
fun GameScreen(
    onNavigateBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    // ECS Game Engine State
    val gameEngine = remember { GameEngine() }
    var gameStats by remember { mutableStateOf(GameStats()) }
    var isEngineRunning by remember { mutableStateOf(false) }
    var isInitialized by remember { mutableStateOf(false) }
    
    // Initialize the game engine
    LaunchedEffect(Unit) {
        gameEngine.initialize()
        isInitialized = true
    }
    
    // Update game stats periodically
    LaunchedEffect(isEngineRunning) {
        while (isEngineRunning) {
            gameStats = gameEngine.getGameStats()
            delay(1000) // Update every second
        }
    }
    
    // Handle disposal
    DisposableEffect(Unit) {
        onDispose {
            runBlocking {
                gameEngine.dispose()
            }
        }
    }
    
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
                        text = "FlexPort ECS Engine",
                        style = MaterialTheme.typography.h6.copy(
                            fontWeight = FontWeight.Medium
                        )
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(
                            imageVector = Icons.Default.ArrowBack,
                            contentDescription = "Back to Main Menu"
                        )
                    }
                },
                actions = {
                    // Engine control button
                    IconButton(
                        onClick = {
                            if (isEngineRunning) {
                                gameEngine.stop()
                                isEngineRunning = false
                            } else {
                                gameEngine.start()
                                isEngineRunning = true
                            }
                        },
                        enabled = isInitialized
                    ) {
                        Icon(
                            imageVector = if (isEngineRunning) Icons.Default.Stop else Icons.Default.PlayArrow,
                            contentDescription = if (isEngineRunning) "Stop Engine" else "Start Engine"
                        )
                    }
                },
                backgroundColor = MaterialTheme.colors.primary,
                contentColor = Color.White,
                elevation = 4.dp
            )
            
            // Game Content Area
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        brush = Brush.verticalGradient(
                            colors = listOf(
                                MaterialTheme.colors.primary.copy(alpha = 0.1f),
                                MaterialTheme.colors.background
                            )
                        )
                    )
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    // Engine Status Card
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        elevation = 4.dp,
                        shape = RoundedCornerShape(12.dp),
                        backgroundColor = if (isEngineRunning) 
                            MaterialTheme.colors.primary.copy(alpha = 0.1f) 
                        else 
                            MaterialTheme.colors.surface
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
                                    text = "ECS Engine Status",
                                    style = MaterialTheme.typography.h6.copy(
                                        fontWeight = FontWeight.Medium
                                    ),
                                    color = MaterialTheme.colors.primary
                                )
                                
                                Box(
                                    modifier = Modifier
                                        .size(12.dp)
                                        .background(
                                            color = if (isEngineRunning) Color.Green else Color.Gray,
                                            shape = RoundedCornerShape(6.dp)
                                        )
                                )
                            }
                            
                            Spacer(modifier = Modifier.height(8.dp))
                            
                            Text(
                                text = if (isEngineRunning) "Engine is running and processing entities" else "Engine is stopped",
                                style = MaterialTheme.typography.body2,
                                color = MaterialTheme.colors.onSurface.copy(alpha = 0.7f)
                            )
                        }
                    }
                    
                    // Game Statistics
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        elevation = 4.dp,
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Column(
                            modifier = Modifier.padding(20.dp)
                        ) {
                            Text(
                                text = "Live Game Statistics",
                                style = MaterialTheme.typography.h6.copy(
                                    fontWeight = FontWeight.Medium
                                ),
                                color = MaterialTheme.colors.primary
                            )
                            
                            Spacer(modifier = Modifier.height(12.dp))
                            
                            val stats = listOf(
                                "Total Entities" to "${gameStats.totalEntities}",
                                "Moving Entities" to "${gameStats.movingEntities}",
                                "Economic Entities" to "${gameStats.economicEntities}",
                                "Systems Active" to if (gameStats.systemsActive) "Yes" else "No"
                            )
                            
                            stats.forEach { (label, value) ->
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Text(
                                        text = label,
                                        style = MaterialTheme.typography.body2,
                                        color = MaterialTheme.colors.onSurface.copy(alpha = 0.8f)
                                    )
                                    Text(
                                        text = value,
                                        style = MaterialTheme.typography.body2.copy(
                                            fontWeight = FontWeight.Medium
                                        ),
                                        color = MaterialTheme.colors.onSurface
                                    )
                                }
                                Spacer(modifier = Modifier.height(4.dp))
                            }
                        }
                    }
                    
                    // Test Entities Information
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        elevation = 4.dp,
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Column(
                            modifier = Modifier.padding(20.dp)
                        ) {
                            Text(
                                text = "Test Entities Created",
                                style = MaterialTheme.typography.h6.copy(
                                    fontWeight = FontWeight.Medium
                                ),
                                color = MaterialTheme.colors.primary
                            )
                            
                            Spacer(modifier = Modifier.height(12.dp))
                            
                            val entities = listOf(
                                "Test Cargo Ship - Moving with velocity and economic components",
                                "Test Port - Static with economic income generation",
                                "Moving Entity - Demonstrates movement system with rotation"
                            )
                            
                            entities.forEach { entity ->
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    verticalAlignment = Alignment.Top
                                ) {
                                    Box(
                                        modifier = Modifier
                                            .size(6.dp)
                                            .background(
                                                color = MaterialTheme.colors.primary.copy(alpha = 0.6f),
                                                shape = RoundedCornerShape(3.dp)
                                            )
                                    )
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Text(
                                        text = entity,
                                        style = MaterialTheme.typography.body2,
                                        color = MaterialTheme.colors.onSurface.copy(alpha = 0.8f)
                                    )
                                }
                                if (entity != entities.last()) {
                                    Spacer(modifier = Modifier.height(8.dp))
                                }
                            }
                        }
                    }
                    
                    // Instructions
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        elevation = 2.dp,
                        shape = RoundedCornerShape(8.dp),
                        backgroundColor = MaterialTheme.colors.secondary.copy(alpha = 0.1f)
                    ) {
                        Column(
                            modifier = Modifier.padding(16.dp)
                        ) {
                            Text(
                                text = "Instructions",
                                style = MaterialTheme.typography.subtitle1.copy(
                                    fontWeight = FontWeight.Medium
                                ),
                                color = MaterialTheme.colors.secondary
                            )
                            
                            Spacer(modifier = Modifier.height(8.dp))
                            
                            Text(
                                text = "Click the play/stop button in the top bar to start/stop the ECS engine. Watch the statistics update in real-time as the systems process entities.",
                                style = MaterialTheme.typography.body2,
                                color = MaterialTheme.colors.onSurface.copy(alpha = 0.7f)
                            )
                        }
                    }
                }
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
fun GameScreenPreview() {
    MaterialTheme {
        GameScreen(
            onNavigateBack = {}
        )
    }
}