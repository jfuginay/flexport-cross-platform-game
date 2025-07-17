package com.flexport.game.ui

import android.content.pm.ActivityInfo
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import com.flexport.game.networking.MultiplayerManager
import com.flexport.game.ui.screens.DualViewGameScreen
import com.flexport.game.ui.theme.FlexPortTheme
import com.flexport.game.viewmodels.GameViewModel

/**
 * Main game activity that handles orientation changes and dual-view system
 */
class GameActivity : ComponentActivity() {
    
    private lateinit var multiplayerManager: MultiplayerManager
    private lateinit var orientationManager: OrientationManager
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Initialize managers
        multiplayerManager = MultiplayerManager.getInstance(this)
        orientationManager = OrientationManager.getInstance(this)
        
        // Allow orientation changes
        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR
        
        setContent {
            FlexPortTheme {
                GameContent()
            }
        }
    }
    
    @OptIn(ExperimentalMaterial3Api::class)
    @Composable
    private fun GameContent() {
        val gameViewModel: GameViewModel = viewModel()
        val orientation by rememberOrientation()
        val isTablet by rememberIsTablet()
        
        // Maintain view state across orientation changes
        var dualViewState by rememberSaveable { mutableStateOf(DualViewState()) }
        
        // Collect multiplayer state
        val connectionState by multiplayerManager.connectionState.collectAsState()
        val currentSession by multiplayerManager.currentSession.collectAsState()
        val gameEvents by multiplayerManager.gameEvents.collectAsState(initial = null)
        
        Surface(
            modifier = Modifier.fillMaxSize(),
            color = MaterialTheme.colorScheme.background
        ) {
            DualViewGameScreen(
                orientation = orientation,
                isTablet = isTablet,
                dualViewState = dualViewState,
                onDualViewStateChange = { dualViewState = it },
                connectionState = connectionState,
                currentSession = currentSession,
                gameViewModel = gameViewModel,
                onNavigateBack = { finish() }
            )
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        // Clean up resources but don't disconnect if game is active
        if (!isChangingConfigurations) {
            // Only cleanup if not just rotating
            multiplayerManager.cleanup()
        }
    }
}