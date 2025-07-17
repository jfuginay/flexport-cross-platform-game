package com.flexport.game.ui.screens

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.unit.dp
import com.flexport.game.networking.ConnectionState
import com.flexport.game.networking.GameSession
import com.flexport.game.ui.DeviceOrientation
import com.flexport.game.ui.DualViewState
import com.flexport.game.ui.components.*
import com.flexport.game.viewmodels.GameViewModel

/**
 * Main game screen that adapts to orientation changes
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DualViewGameScreen(
    orientation: DeviceOrientation,
    isTablet: Boolean,
    dualViewState: DualViewState,
    onDualViewStateChange: (DualViewState) -> Unit,
    connectionState: ConnectionState,
    currentSession: GameSession?,
    gameViewModel: GameViewModel,
    onNavigateBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    when (orientation) {
        DeviceOrientation.PORTRAIT -> {
            PortraitGameView(
                dualViewState = dualViewState,
                onDualViewStateChange = onDualViewStateChange,
                connectionState = connectionState,
                currentSession = currentSession,
                gameViewModel = gameViewModel,
                onNavigateBack = onNavigateBack,
                modifier = modifier
            )
        }
        DeviceOrientation.LANDSCAPE -> {
            if (isTablet && dualViewState.isDashboardExpanded) {
                // Tablet dual-pane view
                TabletDualPaneView(
                    dualViewState = dualViewState,
                    onDualViewStateChange = onDualViewStateChange,
                    connectionState = connectionState,
                    currentSession = currentSession,
                    gameViewModel = gameViewModel,
                    onNavigateBack = onNavigateBack,
                    modifier = modifier
                )
            } else {
                // Phone or collapsed tablet view
                LandscapeGameView(
                    dualViewState = dualViewState,
                    onDualViewStateChange = onDualViewStateChange,
                    connectionState = connectionState,
                    currentSession = currentSession,
                    gameViewModel = gameViewModel,
                    onNavigateBack = onNavigateBack,
                    isTablet = isTablet,
                    modifier = modifier
                )
            }
        }
    }
}

/**
 * Portrait mode - Material Design 3 fleet dashboard
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PortraitGameView(
    dualViewState: DualViewState,
    onDualViewStateChange: (DualViewState) -> Unit,
    connectionState: ConnectionState,
    currentSession: GameSession?,
    gameViewModel: GameViewModel,
    onNavigateBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("FlexPort Command") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    ConnectionIndicator(connectionState = connectionState)
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer,
                    titleContentColor = MaterialTheme.colorScheme.onPrimaryContainer
                )
            )
        },
        floatingActionButton = {
            ExpandedFloatingActionButton(
                onClick = { /* Quick action */ },
                expanded = true,
                icon = { Icon(Icons.Default.Add, contentDescription = null) },
                text = { Text("New Route") }
            )
        },
        bottomBar = {
            NavigationBar {
                NavigationBarItem(
                    selected = dualViewState.activeTab == com.flexport.game.ui.DashboardTab.FLEET,
                    onClick = { 
                        onDualViewStateChange(dualViewState.copy(activeTab = com.flexport.game.ui.DashboardTab.FLEET))
                    },
                    icon = { Icon(Icons.Default.DirectionsBoat, contentDescription = null) },
                    label = { Text("Fleet") }
                )
                NavigationBarItem(
                    selected = dualViewState.activeTab == com.flexport.game.ui.DashboardTab.ECONOMICS,
                    onClick = { 
                        onDualViewStateChange(dualViewState.copy(activeTab = com.flexport.game.ui.DashboardTab.ECONOMICS))
                    },
                    icon = { Icon(Icons.Default.TrendingUp, contentDescription = null) },
                    label = { Text("Economics") }
                )
                NavigationBarItem(
                    selected = dualViewState.activeTab == com.flexport.game.ui.DashboardTab.PORTS,
                    onClick = { 
                        onDualViewStateChange(dualViewState.copy(activeTab = com.flexport.game.ui.DashboardTab.PORTS))
                    },
                    icon = { Icon(Icons.Default.LocationCity, contentDescription = null) },
                    label = { Text("Ports") }
                )
                NavigationBarItem(
                    selected = dualViewState.activeTab == com.flexport.game.ui.DashboardTab.MULTIPLAYER,
                    onClick = { 
                        onDualViewStateChange(dualViewState.copy(activeTab = com.flexport.game.ui.DashboardTab.MULTIPLAYER))
                    },
                    icon = { Icon(Icons.Default.People, contentDescription = null) },
                    label = { Text("Players") }
                )
            }
        }
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .background(
                    brush = Brush.verticalGradient(
                        colors = listOf(
                            MaterialTheme.colorScheme.surface,
                            MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f)
                        )
                    )
                )
        ) {
            AnimatedContent(
                targetState = dualViewState.activeTab,
                transitionSpec = {
                    slideInHorizontally { it } + fadeIn() with
                    slideOutHorizontally { -it } + fadeOut()
                }
            ) { tab ->
                when (tab) {
                    com.flexport.game.ui.DashboardTab.FLEET -> {
                        FleetDashboard(
                            gameViewModel = gameViewModel,
                            modifier = Modifier.fillMaxSize()
                        )
                    }
                    com.flexport.game.ui.DashboardTab.ECONOMICS -> {
                        EconomicsDashboard(
                            gameViewModel = gameViewModel,
                            modifier = Modifier.fillMaxSize()
                        )
                    }
                    com.flexport.game.ui.DashboardTab.PORTS -> {
                        PortsDashboard(
                            gameViewModel = gameViewModel,
                            selectedPortId = dualViewState.selectedPortId,
                            onPortSelected = { portId ->
                                onDualViewStateChange(dualViewState.copy(selectedPortId = portId))
                            },
                            modifier = Modifier.fillMaxSize()
                        )
                    }
                    com.flexport.game.ui.DashboardTab.MULTIPLAYER -> {
                        MultiplayerDashboard(
                            currentSession = currentSession,
                            connectionState = connectionState,
                            modifier = Modifier.fillMaxSize()
                        )
                    }
                }
            }
        }
    }
}

/**
 * Landscape mode - Full-screen map with overlays
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun LandscapeGameView(
    dualViewState: DualViewState,
    onDualViewStateChange: (DualViewState) -> Unit,
    connectionState: ConnectionState,
    currentSession: GameSession?,
    gameViewModel: GameViewModel,
    onNavigateBack: () -> Unit,
    isTablet: Boolean,
    modifier: Modifier = Modifier
) {
    Box(modifier = modifier.fillMaxSize()) {
        // OpenGL ES Map View (placeholder for now)
        MapView(
            dualViewState = dualViewState,
            onDualViewStateChange = onDualViewStateChange,
            gameViewModel = gameViewModel,
            modifier = Modifier.fillMaxSize()
        )
        
        // Top controls overlay
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
                .align(Alignment.TopStart),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            // Left controls
            Card(
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.9f)
                ),
                elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
            ) {
                Row(
                    modifier = Modifier.padding(8.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                    if (isTablet) {
                        IconButton(
                            onClick = {
                                onDualViewStateChange(
                                    dualViewState.copy(isDashboardExpanded = true)
                                )
                            }
                        ) {
                            Icon(Icons.Default.Dashboard, contentDescription = "Show Dashboard")
                        }
                    }
                }
            }
            
            // Right controls
            Card(
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.9f)
                ),
                elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
            ) {
                Row(
                    modifier = Modifier.padding(8.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    ConnectionIndicator(connectionState = connectionState)
                    IconButton(onClick = { /* Toggle layers */ }) {
                        Icon(Icons.Default.Layers, contentDescription = "Map Layers")
                    }
                }
            }
        }
        
        // Bottom status bar
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
                .align(Alignment.BottomCenter),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.9f)
            ),
            elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
        ) {
            GameStatusBar(
                gameViewModel = gameViewModel,
                currentSession = currentSession,
                modifier = Modifier.padding(16.dp)
            )
        }
    }
}

/**
 * Tablet dual-pane view
 */
@Composable
private fun TabletDualPaneView(
    dualViewState: DualViewState,
    onDualViewStateChange: (DualViewState) -> Unit,
    connectionState: ConnectionState,
    currentSession: GameSession?,
    gameViewModel: GameViewModel,
    onNavigateBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(modifier = modifier.fillMaxSize()) {
        // Left pane - Dashboard (40% width)
        Box(
            modifier = Modifier
                .fillMaxHeight()
                .weight(0.4f)
        ) {
            PortraitGameView(
                dualViewState = dualViewState,
                onDualViewStateChange = onDualViewStateChange,
                connectionState = connectionState,
                currentSession = currentSession,
                gameViewModel = gameViewModel,
                onNavigateBack = {
                    onDualViewStateChange(dualViewState.copy(isDashboardExpanded = false))
                }
            )
        }
        
        // Divider
        VerticalDivider(
            modifier = Modifier.fillMaxHeight(),
            thickness = 1.dp,
            color = MaterialTheme.colorScheme.outline
        )
        
        // Right pane - Map (60% width)
        Box(
            modifier = Modifier
                .fillMaxHeight()
                .weight(0.6f)
        ) {
            MapView(
                dualViewState = dualViewState,
                onDualViewStateChange = onDualViewStateChange,
                gameViewModel = gameViewModel,
                modifier = Modifier.fillMaxSize()
            )
        }
    }
}

/**
 * Connection status indicator
 */
@Composable
private fun ConnectionIndicator(
    connectionState: ConnectionState,
    modifier: Modifier = Modifier
) {
    val color = when (connectionState) {
        ConnectionState.CONNECTED -> MaterialTheme.colorScheme.primary
        ConnectionState.CONNECTING, ConnectionState.RECONNECTING -> MaterialTheme.colorScheme.secondary
        ConnectionState.DISCONNECTED -> MaterialTheme.colorScheme.error
    }
    
    val infiniteTransition = rememberInfiniteTransition()
    val alpha by infiniteTransition.animateFloat(
        initialValue = if (connectionState == ConnectionState.CONNECTED) 1f else 0.3f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(1000),
            repeatMode = RepeatMode.Reverse
        )
    )
    
    Icon(
        imageVector = when (connectionState) {
            ConnectionState.CONNECTED -> Icons.Default.Wifi
            ConnectionState.DISCONNECTED -> Icons.Default.WifiOff
            else -> Icons.Default.Sync
        },
        contentDescription = connectionState.name,
        tint = color.copy(alpha = if (connectionState == ConnectionState.CONNECTED) 1f else alpha),
        modifier = modifier
    )
}

@Composable
private fun VerticalDivider(
    modifier: Modifier = Modifier,
    thickness: androidx.compose.ui.unit.Dp = 1.dp,
    color: androidx.compose.ui.graphics.Color = MaterialTheme.colorScheme.outline
) {
    Box(
        modifier = modifier
            .width(thickness)
            .background(color)
    )
}