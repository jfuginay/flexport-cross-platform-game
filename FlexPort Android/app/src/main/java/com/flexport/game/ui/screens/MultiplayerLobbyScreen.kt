package com.flexport.game.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Group
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.flexport.game.networking.*
import kotlinx.coroutines.launch

@Composable
fun MultiplayerLobbyScreen(
    onNavigateBack: () -> Unit,
    onJoinGame: (GameSession) -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val multiplayerManager = remember { MultiplayerManager.getInstance(context) }
    
    var isSearching by remember { mutableStateOf(false) }
    var searchError by remember { mutableStateOf<String?>(null) }
    var selectedGameMode by remember { mutableStateOf(GameMode.REALTIME) }
    
    val connectionState by multiplayerManager.connectionState.collectAsState()
    val isOnline by multiplayerManager.isOnline.collectAsState()
    val currentSession by multiplayerManager.currentSession.collectAsState()
    
    // Handle game events
    LaunchedEffect(Unit) {
        multiplayerManager.gameEvents.collect { event ->
            when (event) {
                is GameEvent.SessionJoined -> {
                    onJoinGame(event.session)
                }
                else -> {
                    // Handle other events
                }
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
                        text = "Multiplayer Lobby",
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
                backgroundColor = MaterialTheme.colors.primary,
                contentColor = Color.White,
                elevation = 4.dp
            )
            
            // Content Area
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
                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    // Connection Status Card
                    item {
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            elevation = 4.dp,
                            shape = RoundedCornerShape(12.dp)
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
                                        text = "Connection Status",
                                        style = MaterialTheme.typography.h6.copy(
                                            fontWeight = FontWeight.Medium
                                        ),
                                        color = MaterialTheme.colors.primary
                                    )
                                    
                                    Box(
                                        modifier = Modifier
                                            .size(12.dp)
                                            .background(
                                                color = when {
                                                    !isOnline -> Color.Red
                                                    connectionState == ConnectionState.CONNECTED -> Color.Green
                                                    connectionState == ConnectionState.CONNECTING || 
                                                    connectionState == ConnectionState.RECONNECTING -> Color.Yellow
                                                    else -> Color.Gray
                                                },
                                                shape = RoundedCornerShape(6.dp)
                                            )
                                    )
                                }
                                
                                Spacer(modifier = Modifier.height(8.dp))
                                
                                Text(
                                    text = when {
                                        !isOnline -> "No internet connection"
                                        connectionState == ConnectionState.CONNECTED -> "Connected to game server"
                                        connectionState == ConnectionState.CONNECTING -> "Connecting to server..."
                                        connectionState == ConnectionState.RECONNECTING -> "Reconnecting..."
                                        else -> "Disconnected from server"
                                    },
                                    style = MaterialTheme.typography.body2,
                                    color = MaterialTheme.colors.onSurface.copy(alpha = 0.7f)
                                )
                            }
                        }
                    }
                    
                    // Game Mode Selection
                    item {
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            elevation = 4.dp,
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Column(
                                modifier = Modifier.padding(20.dp)
                            ) {
                                Text(
                                    text = "Game Mode",
                                    style = MaterialTheme.typography.h6.copy(
                                        fontWeight = FontWeight.Medium
                                    ),
                                    color = MaterialTheme.colors.primary
                                )
                                
                                Spacer(modifier = Modifier.height(16.dp))
                                
                                GameMode.values().forEach { mode ->
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        RadioButton(
                                            selected = selectedGameMode == mode,
                                            onClick = { selectedGameMode = mode }
                                        )
                                        Spacer(modifier = Modifier.width(8.dp))
                                        Column {
                                            Text(
                                                text = mode.name.replace("_", " ").lowercase()
                                                    .replaceFirstChar { it.uppercase() },
                                                style = MaterialTheme.typography.body1
                                            )
                                            Text(
                                                text = when (mode) {
                                                    GameMode.REALTIME -> "Fast-paced real-time gameplay"
                                                    GameMode.TURN_BASED -> "Strategic turn-based play"
                                                    GameMode.COOPERATIVE -> "Work together with other players"
                                                    GameMode.COMPETITIVE -> "Compete against other players"
                                                },
                                                style = MaterialTheme.typography.body2,
                                                color = MaterialTheme.colors.onSurface.copy(alpha = 0.7f)
                                            )
                                        }
                                    }
                                    Spacer(modifier = Modifier.height(8.dp))
                                }
                            }
                        }
                    }
                    
                    // Find Match Button
                    item {
                        Button(
                            onClick = {
                                if (isSearching) {
                                    // Cancel search
                                    isSearching = false
                                } else {
                                    // Start search
                                    scope.launch {
                                        try {
                                            isSearching = true
                                            searchError = null
                                            multiplayerManager.startMultiplayerGame(selectedGameMode)
                                        } catch (e: Exception) {
                                            searchError = e.message
                                            isSearching = false
                                        }
                                    }
                                }
                            },
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(56.dp),
                            enabled = isOnline,
                            colors = ButtonDefaults.buttonColors(
                                backgroundColor = if (isSearching) 
                                    MaterialTheme.colors.error 
                                else 
                                    MaterialTheme.colors.primary
                            ),
                            shape = RoundedCornerShape(28.dp)
                        ) {
                            if (isSearching) {
                                CircularProgressIndicator(
                                    modifier = Modifier.size(20.dp),
                                    color = Color.White,
                                    strokeWidth = 2.dp
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(
                                    text = "Cancel Search",
                                    style = MaterialTheme.typography.h6,
                                    color = Color.White
                                )
                            } else {
                                Icon(
                                    imageVector = Icons.Default.Group,
                                    contentDescription = null,
                                    modifier = Modifier.size(24.dp)
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(
                                    text = "Find Match",
                                    style = MaterialTheme.typography.h6,
                                    color = Color.White
                                )
                            }
                        }
                    }
                    
                    // Error Display
                    searchError?.let { error ->
                        item {
                            Card(
                                modifier = Modifier.fillMaxWidth(),
                                elevation = 2.dp,
                                shape = RoundedCornerShape(8.dp),
                                backgroundColor = MaterialTheme.colors.error.copy(alpha = 0.1f)
                            ) {
                                Row(
                                    modifier = Modifier.padding(16.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text(
                                        text = "Error: $error",
                                        style = MaterialTheme.typography.body2,
                                        color = MaterialTheme.colors.error
                                    )
                                }
                            }
                        }
                    }
                    
                    // Current Session Info
                    currentSession?.let { session ->
                        item {
                            Card(
                                modifier = Modifier.fillMaxWidth(),
                                elevation = 4.dp,
                                shape = RoundedCornerShape(12.dp),
                                backgroundColor = MaterialTheme.colors.secondary.copy(alpha = 0.1f)
                            ) {
                                Column(
                                    modifier = Modifier.padding(20.dp)
                                ) {
                                    Text(
                                        text = "Current Session",
                                        style = MaterialTheme.typography.h6.copy(
                                            fontWeight = FontWeight.Medium
                                        ),
                                        color = MaterialTheme.colors.secondary
                                    )
                                    
                                    Spacer(modifier = Modifier.height(12.dp))
                                    
                                    Text(
                                        text = "Session ID: ${session.id}",
                                        style = MaterialTheme.typography.body2
                                    )
                                    Text(
                                        text = "Mode: ${session.mode.name.replace("_", " ").lowercase()}",
                                        style = MaterialTheme.typography.body2
                                    )
                                    Text(
                                        text = "Players: ${session.players.size}",
                                        style = MaterialTheme.typography.body2
                                    )
                                    Text(
                                        text = "Status: ${session.status.name.lowercase()}",
                                        style = MaterialTheme.typography.body2
                                    )
                                    
                                    Spacer(modifier = Modifier.height(12.dp))
                                    
                                    session.players.forEach { player ->
                                        Row(
                                            verticalAlignment = Alignment.CenterVertically
                                        ) {
                                            Icon(
                                                imageVector = Icons.Default.Person,
                                                contentDescription = null,
                                                modifier = Modifier.size(16.dp),
                                                tint = if (player.isOnline) Color.Green else Color.Gray
                                            )
                                            Spacer(modifier = Modifier.width(8.dp))
                                            Text(
                                                text = player.name,
                                                style = MaterialTheme.typography.body2
                                            )
                                        }
                                        Spacer(modifier = Modifier.height(4.dp))
                                    }
                                }
                            }
                        }
                    }
                    
                    // Instructions
                    item {
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            elevation = 2.dp,
                            shape = RoundedCornerShape(8.dp),
                            backgroundColor = MaterialTheme.colors.primary.copy(alpha = 0.05f)
                        ) {
                            Column(
                                modifier = Modifier.padding(16.dp)
                            ) {
                                Text(
                                    text = "How to Play Multiplayer",
                                    style = MaterialTheme.typography.subtitle1.copy(
                                        fontWeight = FontWeight.Medium
                                    ),
                                    color = MaterialTheme.colors.primary
                                )
                                
                                Spacer(modifier = Modifier.height(8.dp))
                                
                                val instructions = listOf(
                                    "1. Select your preferred game mode",
                                    "2. Click 'Find Match' to search for other players",
                                    "3. Wait to be matched with players of similar skill",
                                    "4. Once matched, you'll join the game automatically",
                                    "5. Cross-platform play supported with iOS!"
                                )
                                
                                instructions.forEach { instruction ->
                                    Text(
                                        text = instruction,
                                        style = MaterialTheme.typography.body2,
                                        color = MaterialTheme.colors.onSurface.copy(alpha = 0.7f)
                                    )
                                    Spacer(modifier = Modifier.height(4.dp))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
fun MultiplayerLobbyScreenPreview() {
    MaterialTheme {
        MultiplayerLobbyScreen(
            onNavigateBack = {},
            onJoinGame = {}
        )
    }
}