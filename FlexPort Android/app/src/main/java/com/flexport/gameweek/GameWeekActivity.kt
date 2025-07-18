package com.flexport.gameweek

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import com.flexport.gameweek.viewmodels.GameWeekViewModel
import com.flexport.gameweek.viewmodels.TradeEmpireViewModel
import com.flexport.gameweek.viewmodels.SingularityViewModel
import com.flexport.gameweek.ui.components.*
import com.flexport.gameweek.ui.theme.FlexPortGameWeekTheme
import com.flexport.gameweek.models.*

/**
 * Game Week Android Companion App
 * Parallel iOS functionality with Unity integration
 * Focus: CRUD monitoring and asset management
 */
class GameWeekActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        setContent {
            FlexPortGameWeekTheme {
                GameWeekDashboard()
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GameWeekDashboard() {
    val gameWeekViewModel: GameWeekViewModel = viewModel()
    val empireViewModel: TradeEmpireViewModel = viewModel()
    val singularityViewModel: SingularityViewModel = viewModel()
    
    var selectedTab by remember { mutableStateOf(0) }
    val scope = rememberCoroutineScope()
    
    // Auto-sync with Unity every 5 seconds
    LaunchedEffect(Unit) {
        while (true) {
            scope.launch {
                gameWeekViewModel.syncWithUnity()
                empireViewModel.syncWithUnity()
                singularityViewModel.syncWithUnity()
            }
            delay(5000) // 5 seconds
        }
    }
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { 
                    Text(
                        "FlexPort Game Week",
                        fontWeight = FontWeight.Bold
                    )
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer
                ),
                actions = {
                    // Unity connection status indicator
                    UnityConnectionIndicator(
                        isConnected = gameWeekViewModel.isConnectedToUnity.collectAsState().value
                    )
                }
            )
        },
        bottomBar = {
            NavigationBar {
                val tabs = listOf(
                    "Game Monitor" to "monitor_heart",
                    "Trade Empire" to "business",
                    "Markets" to "trending_up",
                    "AI Progress" to "psychology"
                )
                
                tabs.forEachIndexed { index, (title, icon) ->
                    NavigationBarItem(
                        selected = selectedTab == index,
                        onClick = { selectedTab = index },
                        icon = { 
                            Icon(
                                painter = painterResource(id = getIconResource(icon)),
                                contentDescription = title
                            )
                        },
                        label = { Text(title) }
                    )
                }
            }
        }
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            when (selectedTab) {
                0 -> GameMonitorTab(gameWeekViewModel, singularityViewModel)
                1 -> TradeEmpireTab(empireViewModel)
                2 -> MarketsTab(empireViewModel)
                3 -> SingularityTab(singularityViewModel)
            }
        }
    }
}

@Composable
fun GameMonitorTab(
    gameWeekViewModel: GameWeekViewModel,
    singularityViewModel: SingularityViewModel
) {
    val gameState by gameWeekViewModel.gameState.collectAsState()
    val singularityProgress by singularityViewModel.progress.collectAsState()
    
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Unity Connection Status Card
        item {
            UnityConnectionCard(
                isConnected = gameWeekViewModel.isConnectedToUnity.collectAsState().value,
                lastSyncTime = gameWeekViewModel.lastSyncTime.collectAsState().value
            )
        }
        
        // Unity Game View Placeholder (monitoring mode)
        item {
            UnityGameViewCard(
                singularityProgress = singularityProgress
            )
        }
        
        // Game Statistics Grid
        item {
            GameStatsGrid(
                connectedPlayers = gameState?.connectedPlayers ?: 0,
                globalTradeVolume = gameState?.globalTradeVolume ?: 0f,
                singularityProgress = singularityProgress,
                sessionTime = gameState?.sessionTime ?: 0f
            )
        }
        
        // Recent Game Events
        item {
            RecentEventsCard(
                events = gameWeekViewModel.recentEvents.collectAsState().value
            )
        }
    }
}

@Composable
fun TradeEmpireTab(empireViewModel: TradeEmpireViewModel) {
    val empireData by empireViewModel.empireData.collectAsState()
    val tradeRoutes by empireViewModel.ownedRoutes.collectAsState()
    val availableRoutes by empireViewModel.availableRoutes.collectAsState()
    
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Empire Status Card
        item {
            EmpireStatusCard(
                empireData = empireData,
                onLevelUpInfo = { /* Show level up requirements */ }
            )
        }
        
        // Owned Trade Routes Section
        item {
            Text(
                "Your Trade Routes",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold
            )
        }
        
        items(tradeRoutes) { route ->
            TradeRouteCard(
                route = route,
                isOwned = true,
                onInvest = { amount ->
                    empireViewModel.investInRoute(route.id, amount)
                },
                onUpgrade = { amount ->
                    empireViewModel.upgradeRoute(route.id, amount)
                }
            )
        }
        
        // Available Routes Section
        item {
            Text(
                "Available Routes",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold
            )
        }
        
        items(availableRoutes.take(10)) { route -> // Show top 10 available routes
            TradeRouteCard(
                route = route,
                isOwned = false,
                onClaim = {
                    empireViewModel.claimRoute(route.id)
                }
            )
        }
    }
}

@Composable
fun MarketsTab(empireViewModel: TradeEmpireViewModel) {
    val marketData by empireViewModel.marketData.collectAsState()
    val marketEvents by empireViewModel.marketEvents.collectAsState()
    
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Ryan's Four Markets Overview
        item {
            FourMarketsCard(marketData = marketData)
        }
        
        // Market Performance Charts
        item {
            MarketPerformanceCard(marketData = marketData)
        }
        
        // Investment Opportunities
        item {
            InvestmentOpportunitiesCard(
                opportunities = empireViewModel.investmentOpportunities.collectAsState().value,
                onInvest = { marketType, amount ->
                    empireViewModel.investInMarket(marketType, amount)
                }
            )
        }
        
        // Recent Market Events
        item {
            Text(
                "Recent Market Events",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold
            )
        }
        
        items(marketEvents) { event ->
            MarketEventCard(event = event)
        }
    }
}

@Composable
fun SingularityTab(singularityViewModel: SingularityViewModel) {
    val progress by singularityViewModel.progress.collectAsState()
    val currentPhase by singularityViewModel.currentPhase.collectAsState()
    val aiMilestones by singularityViewModel.aiMilestones.collectAsState()
    val estimatedTimeToSingularity by singularityViewModel.estimatedTimeToSingularity.collectAsState()
    
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Singularity Progress Card
        item {
            SingularityProgressCard(
                progress = progress,
                currentPhase = currentPhase,
                timeRemaining = estimatedTimeToSingularity
            )
        }
        
        // AI Milestones Section
        item {
            Text(
                "AI Development Milestones",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold
            )
        }
        
        items(aiMilestones) { milestone ->
            AIMilestoneCard(milestone = milestone)
        }
        
        // Threat Assessment
        item {
            ThreatAssessmentCard(
                automationLevel = singularityViewModel.playerAutomationLevel.collectAsState().value,
                currentAICapabilities = singularityViewModel.currentAICapabilities.collectAsState().value
            )
        }
        
        // Zoo Ending Preview (if close to singularity)
        if (progress > 80f) {
            item {
                ZooEndingPreviewCard(
                    progress = progress,
                    onShowFullPreview = {
                        singularityViewModel.showZooEndingPreview()
                    }
                )
            }
        }
    }
}

// Supporting Composables
@Composable
fun UnityConnectionIndicator(isConnected: Boolean) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.padding(horizontal = 16.dp)
    ) {
        Box(
            modifier = Modifier
                .size(8.dp)
                .padding(end = 4.dp)
        ) {
            Card(
                colors = CardDefaults.cardColors(
                    containerColor = if (isConnected) Color.Green else Color.Red
                ),
                modifier = Modifier.fillMaxSize()
            ) {}
        }
        
        Text(
            text = if (isConnected) "Unity" else "Offline",
            style = MaterialTheme.typography.labelSmall,
            color = if (isConnected) Color.Green else Color.Red
        )
    }
}

@Composable
fun GameStatsGrid(
    connectedPlayers: Int,
    globalTradeVolume: Float,
    singularityProgress: Float,
    sessionTime: Float
) {
    Card(
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Text(
                "Game Statistics",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            
            Spacer(modifier = Modifier.height(12.dp))
            
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                StatItem("Players", connectedPlayers.toString(), Color.Green)
                StatItem("Trade Vol.", "${globalTradeVolume.toInt()}B", Color.Blue)
                StatItem("AI Progress", "${singularityProgress.toInt()}%", 
                    if (singularityProgress > 50) Color.Red else Color.Orange)
                StatItem("Session", "${(sessionTime / 60).toInt()}m", Color.Purple)
            }
        }
    }
}

@Composable
fun StatItem(label: String, value: String, color: Color) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            value,
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            color = color
        )
        Text(
            label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

// Helper function for icon resources
private fun getIconResource(iconName: String): Int {
    return when (iconName) {
        "monitor_heart" -> android.R.drawable.ic_menu_view
        "business" -> android.R.drawable.ic_menu_manage
        "trending_up" -> android.R.drawable.ic_menu_sort_by_size
        "psychology" -> android.R.drawable.ic_menu_info_details
        else -> android.R.drawable.ic_menu_help
    }
}

@Preview(showBackground = true)
@Composable
fun GameWeekDashboardPreview() {
    FlexPortGameWeekTheme {
        GameWeekDashboard()
    }
}