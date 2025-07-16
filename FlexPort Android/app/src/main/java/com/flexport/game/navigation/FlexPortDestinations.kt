package com.flexport.game.navigation

/**
 * Destinations used throughout the FlexPort app.
 */
object FlexPortDestinations {
    const val MAIN_MENU_ROUTE = "main_menu"
    const val GAME_WORLD_ROUTE = "game_world"
    const val WORLD_MAP_ROUTE = "world_map"
    const val AI_SINGULARITY_ROUTE = "ai_singularity"
    const val MULTIPLAYER_LOBBY_ROUTE = "multiplayer_lobby"
    const val ASSET_MANAGEMENT_ROUTE = "asset_management"
    const val ECONOMIC_DASHBOARD_ROUTE = "economic_dashboard"
    const val SETTINGS_ROUTE = "settings"
}

/**
 * Models the navigation screens in the app.
 */
sealed class Screen(val route: String, val title: String) {
    object MainMenu : Screen(FlexPortDestinations.MAIN_MENU_ROUTE, "FlexPort")
    object GameWorld : Screen(FlexPortDestinations.GAME_WORLD_ROUTE, "Game Hub")
    object WorldMap : Screen(FlexPortDestinations.WORLD_MAP_ROUTE, "World Map")
    object AISingularity : Screen(FlexPortDestinations.AI_SINGULARITY_ROUTE, "AI Monitor")
    object MultiplayerLobby : Screen(FlexPortDestinations.MULTIPLAYER_LOBBY_ROUTE, "Multiplayer")
    object AssetManagement : Screen(FlexPortDestinations.ASSET_MANAGEMENT_ROUTE, "Assets")
    object EconomicDashboard : Screen(FlexPortDestinations.ECONOMIC_DASHBOARD_ROUTE, "Economy")
    object Settings : Screen(FlexPortDestinations.SETTINGS_ROUTE, "Settings")
}

/**
 * Bottom navigation items for the main game screens.
 */
val bottomNavigationItems = listOf(
    Screen.WorldMap,
    Screen.AISingularity,
    Screen.EconomicDashboard,
    Screen.AssetManagement,
    Screen.Settings
)