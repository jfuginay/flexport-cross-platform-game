package com.flexport.game

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.flexport.game.navigation.FlexPortDestinations
import com.flexport.game.ui.screens.GameScreen
import com.flexport.game.ui.screens.MainMenuScreen
import com.flexport.game.ui.screens.MultiplayerLobbyScreen
import com.flexport.game.ui.screens.EconomicDashboardScreen
import com.flexport.game.ui.screens.FleetManagementScreen
import com.flexport.assets.ui.AssetManagementScreen

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                FlexPortApp()
            }
        }
    }
}

@Composable
fun FlexPortApp() {
    val navController = rememberNavController()
    
    NavHost(
        navController = navController,
        startDestination = FlexPortDestinations.MAIN_MENU_ROUTE,
        modifier = Modifier.fillMaxSize()
    ) {
        composable(FlexPortDestinations.MAIN_MENU_ROUTE) {
            MainMenuScreen(
                onStartGame = {
                    navController.navigate(FlexPortDestinations.GAME_WORLD_ROUTE)
                },
                onStartMultiplayer = {
                    navController.navigate(FlexPortDestinations.MULTIPLAYER_LOBBY_ROUTE)
                },
                onEconomicDashboard = {
                    navController.navigate(FlexPortDestinations.ECONOMIC_DASHBOARD_ROUTE)
                },
                onAssetManagement = {
                    navController.navigate(FlexPortDestinations.ASSET_MANAGEMENT_ROUTE)
                },
                onFleetManagement = {
                    navController.navigate(FlexPortDestinations.FLEET_MANAGEMENT_ROUTE)
                },
                onSettings = {
                    // Settings navigation will be implemented later
                }
            )
        }
        
        composable(FlexPortDestinations.MULTIPLAYER_LOBBY_ROUTE) {
            MultiplayerLobbyScreen(
                onNavigateBack = {
                    navController.popBackStack()
                },
                onJoinGame = { _ ->
                    navController.navigate(FlexPortDestinations.GAME_WORLD_ROUTE)
                }
            )
        }
        
        composable(FlexPortDestinations.GAME_WORLD_ROUTE) {
            GameScreen(
                onNavigateBack = {
                    navController.popBackStack()
                }
            )
        }
        
        composable(FlexPortDestinations.ECONOMIC_DASHBOARD_ROUTE) {
            EconomicDashboardScreen()
        }
        
        composable(FlexPortDestinations.ASSET_MANAGEMENT_ROUTE) {
            AssetManagementScreen()
        }
        
        composable(FlexPortDestinations.FLEET_MANAGEMENT_ROUTE) {
            FleetManagementScreen(
                onNavigateBack = {
                    navController.popBackStack()
                }
            )
        }
    }
}

@Preview(showBackground = true)
@Composable
fun DefaultPreview() {
    MaterialTheme {
        MainMenuScreen(
            onStartGame = {},
            onStartMultiplayer = {},
            onEconomicDashboard = {},
            onAssetManagement = {},
            onFleetManagement = {},
            onSettings = {}
        )
    }
}