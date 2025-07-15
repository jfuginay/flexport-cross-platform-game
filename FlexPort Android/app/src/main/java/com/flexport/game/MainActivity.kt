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
                onSettings = {
                    // Settings navigation will be implemented later
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
    }
}

@Preview(showBackground = true)
@Composable
fun DefaultPreview() {
    MaterialTheme {
        MainMenuScreen(
            onStartGame = {},
            onSettings = {}
        )
    }
}