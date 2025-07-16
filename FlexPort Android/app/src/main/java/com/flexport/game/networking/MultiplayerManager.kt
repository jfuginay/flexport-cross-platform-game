package com.flexport.game.networking

import android.content.Context
import android.content.SharedPreferences
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import kotlinx.serialization.json.Json
import kotlinx.serialization.builtins.ListSerializer
import java.util.*

class MultiplayerManager private constructor(private val context: Context) {
    companion object {
        @Volatile
        private var INSTANCE: MultiplayerManager? = null
        
        fun getInstance(context: Context): MultiplayerManager {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: MultiplayerManager(context.applicationContext).also { INSTANCE = it }
            }
        }
    }
    
    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }
    
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private val prefs: SharedPreferences = context.getSharedPreferences("flexport_multiplayer", Context.MODE_PRIVATE)
    
    // Service components
    private val webSocketHandler = WebSocketHandler.getInstance()
    private val apiClient = ApiClient.getInstance()
    private val networkReachability = NetworkReachability.getInstance(context)
    
    // Published state
    private val _currentSession = MutableStateFlow<GameSession?>(null)
    val currentSession: StateFlow<GameSession?> = _currentSession.asStateFlow()
    
    private val _gameMode = MutableStateFlow(GameMode.REALTIME)
    val gameMode: StateFlow<GameMode> = _gameMode.asStateFlow()
    
    val connectionState: StateFlow<ConnectionState> = webSocketHandler.connectionState
    val isOnline: StateFlow<Boolean> = networkReachability.isConnected
    
    // Game state management
    private val gameActions = mutableMapOf<String, GameAction>()
    private val conflictResolver = ConflictResolver()
    private var syncJob: Job? = null
    
    // Message handling
    private val _gameEvents = MutableSharedFlow<GameEvent>()
    val gameEvents: SharedFlow<GameEvent> = _gameEvents.asSharedFlow()
    
    init {
        setupSubscriptions()
    }
    
    private fun setupSubscriptions() {
        // Handle incoming WebSocket messages
        scope.launch {
            webSocketHandler.messageFlow.collect { message ->
                handleIncomingMessage(message)
            }
        }
        
        // Handle network state changes
        scope.launch {
            isOnline.collect { online ->
                if (online) {
                    handleOnlineMode()
                } else {
                    handleOfflineMode()
                }
            }
        }
    }
    
    // Public Interface
    suspend fun startMultiplayerGame(gameMode: GameMode, region: String? = null): GameSession {
        _gameMode.value = gameMode
        
        if (!isOnline.value) {
            throw NetworkError.NoConnection
        }
        
        // Request matchmaking
        val matchRequest = MatchmakingRequest(
            playerId = getCurrentPlayerId(),
            gameMode = gameMode,
            preferredRegion = region,
            skillRating = getPlayerSkillRating()
        )
        
        val matchResponse = apiClient.requestMatch(matchRequest)
        
        // Wait for match to be found
        val session = waitForMatch(matchResponse.requestId)
        
        // Join the game session
        joinGameSession(session)
        
        return session
    }
    
    suspend fun joinGameSession(session: GameSession) {
        _currentSession.value = session
        
        // Get auth token
        val authToken = getAuthToken()
        
        // Connect WebSocket
        webSocketHandler.connect(session.id, authToken)
        
        // Start synchronization for turn-based games
        if (gameMode.value == GameMode.TURN_BASED) {
            startSyncTimer()
        }
        
        // Emit session joined event
        _gameEvents.emit(GameEvent.SessionJoined(session))
    }
    
    suspend fun leaveGameSession() {
        stopSyncTimer()
        webSocketHandler.disconnect()
        
        val session = _currentSession.value
        _currentSession.value = null
        
        session?.let {
            _gameEvents.emit(GameEvent.SessionLeft(it))
        }
    }
    
    suspend fun sendGameAction(action: GameAction) {
        if (isOnline.value && connectionState.value == ConnectionState.CONNECTED) {
            // Send via WebSocket for real-time games
            val message = GameMessage(
                id = UUID.randomUUID().toString(),
                type = MessageType.GAME_ACTION,
                timestamp = System.currentTimeMillis(),
                payload = MessagePayload.Action(action)
            )
            
            webSocketHandler.send(message)
            
            // Store action for conflict resolution
            gameActions[action.playerId] = action
        } else {
            // Store action offline
            saveOfflineAction(action, _currentSession.value?.id ?: "offline")
        }
    }
    
    suspend fun completeTurn(gameState: GameState) {
        val session = _currentSession.value ?: throw NetworkError.Custom("No active session")
        
        // Save state snapshot
        saveGameStateSnapshot(gameState, session.id)
        
        if (isOnline.value) {
            // Sync with server
            syncGameState(gameState)
        }
        
        // Notify other players
        val stateUpdate = GameStateUpdate(
            turn = gameState.turn,
            playerStates = createPlayerStateSnapshot(gameState),
            marketState = createMarketStateSnapshot(gameState)
        )
        
        val message = GameMessage(
            id = UUID.randomUUID().toString(),
            type = MessageType.STATE_UPDATE,
            timestamp = System.currentTimeMillis(),
            payload = MessagePayload.StateUpdate(stateUpdate)
        )
        
        if (connectionState.value == ConnectionState.CONNECTED) {
            webSocketHandler.send(message)
        }
    }
    
    // Message Handling
    private suspend fun handleIncomingMessage(message: GameMessage) {
        when (message.payload) {
            is MessagePayload.Action -> {
                handleGameAction(message.payload.action)
            }
            is MessagePayload.StateUpdate -> {
                handleStateUpdate(message.payload.update)
            }
            is MessagePayload.PlayerEvent -> {
                _gameEvents.emit(GameEvent.PlayerEventReceived(message.payload.event))
            }
            is MessagePayload.Chat -> {
                handleChatMessage(message.payload.message)
            }
            is MessagePayload.System -> {
                handleSystemMessage(message.payload.message)
            }
            is MessagePayload.Conflict -> {
                handleConflictResolution(message.payload.resolution)
            }
        }
    }
    
    private suspend fun handleGameAction(action: GameAction) {
        // Check for conflicts with local actions
        val localAction = gameActions[action.playerId]
        if (localAction != null && localAction.parameters != action.parameters) {
            // Conflict detected - server action takes precedence
            val conflict = ConflictResolution(
                conflictId = UUID.randomUUID().toString(),
                originalActions = listOf(localAction, action),
                resolution = action,
                reason = "Simultaneous action conflict"
            )
            
            conflictResolver.resolveConflict(conflict)
        }
        
        // Emit game action event
        _gameEvents.emit(GameEvent.ActionReceived(action))
    }
    
    private suspend fun handleStateUpdate(update: GameStateUpdate) {
        _gameEvents.emit(GameEvent.StateUpdated(update))
    }
    
    private suspend fun handlePlayerEvent(event: PlayerEvent) {
        _gameEvents.emit(GameEvent.PlayerEventReceived(event))
    }
    
    private suspend fun handleChatMessage(message: ChatMessage) {
        _gameEvents.emit(GameEvent.ChatReceived(message))
    }
    
    private suspend fun handleSystemMessage(message: SystemMessage) {
        _gameEvents.emit(GameEvent.SystemMessageReceived(message))
    }
    
    private suspend fun handleConflictResolution(resolution: ConflictResolution) {
        conflictResolver.resolveConflict(resolution)
        
        // Remove conflicted actions
        for (action in resolution.originalActions) {
            gameActions.remove(action.playerId)
        }
        
        // Apply resolved action
        _gameEvents.emit(GameEvent.ActionReceived(resolution.resolution))
    }
    
    // Network State Management
    private suspend fun handleOnlineMode() {
        // Sync pending offline data
        syncPendingData()
        
        // Reconnect to session if we have one
        _currentSession.value?.let { session ->
            try {
                webSocketHandler.connect(session.id, getAuthToken())
            } catch (e: Exception) {
                // Handle reconnection failure
            }
        }
    }
    
    private fun handleOfflineMode() {
        // Continue in offline mode
        // WebSocket will automatically disconnect
    }
    
    // Synchronization
    private suspend fun syncGameState(gameState: GameState) {
        val session = _currentSession.value ?: return
        
        val stateJson = json.encodeToString(GameState.serializer(), gameState)
        
        val syncRequest = GameStateSyncRequest(
            playerId = getCurrentPlayerId(),
            sessionId = session.id,
            localStateJson = stateJson,
            lastSyncTimestamp = System.currentTimeMillis(),
            pendingActions = gameActions.values.toList()
        )
        
        try {
            val response = apiClient.syncGameState(syncRequest)
            
            // Handle any conflicts
            for (conflict in response.conflicts) {
                conflictResolver.resolveConflict(conflict)
            }
        } catch (e: Exception) {
            // Handle sync error
        }
    }
    
    private fun startSyncTimer() {
        stopSyncTimer()
        syncJob = scope.launch {
            while (isActive) {
                delay(5000) // Sync every 5 seconds
                getCurrentGameState()?.let { gameState ->
                    try {
                        syncGameState(gameState)
                    } catch (e: Exception) {
                        // Handle sync error
                    }
                }
            }
        }
    }
    
    private fun stopSyncTimer() {
        syncJob?.cancel()
        syncJob = null
    }
    
    // Helper Methods
    private suspend fun waitForMatch(requestId: String): GameSession {
        // Poll for match completion
        var attempts = 0
        val maxAttempts = 60 // 60 seconds timeout
        
        while (attempts < maxAttempts) {
            delay(1000)
            attempts++
            
            // In a real implementation, you'd poll the matchmaking status
            // For now, return a mock session
            return GameSession(
                id = UUID.randomUUID().toString(),
                mode = _gameMode.value,
                players = listOf(
                    PlayerInfo(
                        id = getCurrentPlayerId(),
                        name = getPlayerName(),
                        isOnline = true
                    )
                ),
                status = SessionStatus.WAITING,
                createdAt = System.currentTimeMillis()
            )
        }
        
        throw NetworkError.Custom("Matchmaking timeout")
    }
    
    private fun createPlayerStateSnapshot(gameState: GameState): Map<String, PlayerStateSnapshot> {
        return mapOf(
            getCurrentPlayerId() to PlayerStateSnapshot(
                money = gameState.playerAssets.money,
                shipCount = gameState.playerAssets.ships.size,
                warehouseCount = gameState.playerAssets.warehouses.size,
                reputation = gameState.playerAssets.reputation
            )
        )
    }
    
    private fun createMarketStateSnapshot(gameState: GameState): MarketStateSnapshot {
        val commodityPrices = gameState.markets.goodsMarket.commodities.associate { 
            it.name to it.basePrice 
        }
        
        return MarketStateSnapshot(
            commodityPrices = commodityPrices,
            interestRate = gameState.markets.capitalMarket.interestRate
        )
    }
    
    private fun saveGameStateSnapshot(gameState: GameState, sessionId: String) {
        val stateJson = json.encodeToString(GameState.serializer(), gameState)
        prefs.edit()
            .putString("game_state_$sessionId", stateJson)
            .putLong("last_save_$sessionId", System.currentTimeMillis())
            .apply()
    }
    
    private fun saveOfflineAction(action: GameAction, sessionId: String) {
        val existingActions = getOfflineActions(sessionId).toMutableList()
        existingActions.add(action)
        
        val actionsJson = json.encodeToString(ListSerializer(GameAction.serializer()), existingActions)
        prefs.edit()
            .putString("offline_actions_$sessionId", actionsJson)
            .apply()
    }
    
    private fun getOfflineActions(sessionId: String): List<GameAction> {
        val actionsJson = prefs.getString("offline_actions_$sessionId", null) ?: return emptyList()
        return try {
            json.decodeFromString(ListSerializer(GameAction.serializer()), actionsJson)
        } catch (e: Exception) {
            emptyList()
        }
    }
    
    private suspend fun syncPendingData() {
        // Sync offline actions and state
        val sessionId = _currentSession.value?.id ?: return
        val offlineActions = getOfflineActions(sessionId)
        
        if (offlineActions.isNotEmpty()) {
            try {
                // Send offline actions
                for (action in offlineActions) {
                    sendGameAction(action)
                }
                
                // Clear offline actions after successful sync
                prefs.edit().remove("offline_actions_$sessionId").apply()
            } catch (e: Exception) {
                // Handle sync error
            }
        }
    }
    
    private fun getCurrentGameState(): GameState? {
        // In production, get from GameManager
        return null
    }
    
    private fun getCurrentPlayerId(): String {
        return prefs.getString("playerId", null) ?: run {
            val newId = UUID.randomUUID().toString()
            prefs.edit().putString("playerId", newId).apply()
            newId
        }
    }
    
    private fun getPlayerName(): String {
        return prefs.getString("playerName", "Player") ?: "Player"
    }
    
    private fun getAuthToken(): String {
        return prefs.getString("authToken", "mock_token") ?: "mock_token"
    }
    
    private fun getPlayerSkillRating(): Int {
        return prefs.getInt("skillRating", 1000)
    }
    
    fun cleanup() {
        scope.cancel()
        webSocketHandler.cleanup()
    }
}

// Conflict resolution
class ConflictResolver {
    fun resolveConflict(resolution: ConflictResolution) {
        // Log conflict resolution
        println("Resolving conflict: ${resolution.reason}")
        
        // In production, implement sophisticated conflict resolution
        // For now, server action takes precedence
    }
}

// Game events
sealed class GameEvent {
    data class SessionJoined(val session: GameSession) : GameEvent()
    data class SessionLeft(val session: GameSession) : GameEvent()
    data class ActionReceived(val action: GameAction) : GameEvent()
    data class StateUpdated(val update: GameStateUpdate) : GameEvent()
    data class PlayerEventReceived(val event: PlayerEvent) : GameEvent()
    data class ChatReceived(val message: ChatMessage) : GameEvent()
    data class SystemMessageReceived(val message: SystemMessage) : GameEvent()
}