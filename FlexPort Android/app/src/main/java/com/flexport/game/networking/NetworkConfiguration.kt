package com.flexport.game.networking

object NetworkConfiguration {
    // Base URLs - configurable for development vs production
    // Using the same server as web for cross-platform multiplayer
    const val BASE_URL = "https://flexport-multiplayer.herokuapp.com/api/v1"
    const val WEBSOCKET_URL = "wss://flexport-multiplayer.herokuapp.com/ws"
    
    // Timeout configurations (in milliseconds)
    const val REQUEST_TIMEOUT = 30_000L
    const val WEBSOCKET_TIMEOUT = 30_000L
    const val RETRY_DELAY = 2_000L
    
    // Retry configurations
    const val MAX_RETRIES = 3
    
    // API endpoints
    object Endpoints {
        const val MATCHMAKING = "matchmaking"
        const val SYNC_GAME_STATE = "game/sync"
        const val LEADERBOARD = "leaderboard"
        
        fun gameSession(sessionId: String) = "game/session/$sessionId"
        fun playerStats(playerId: String) = "player/$playerId/stats"
    }
    
    // WebSocket ping interval (in milliseconds)
    const val PING_INTERVAL = 30_000L
    
    // Development/debug settings
    const val ENABLE_NETWORK_LOGS = true
    const val ENABLE_WEBSOCKET_LOGS = true
}