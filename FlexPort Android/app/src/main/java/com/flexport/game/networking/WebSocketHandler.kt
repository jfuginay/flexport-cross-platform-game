package com.flexport.game.networking

import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.json.Json
import org.java_websocket.client.WebSocketClient
import org.java_websocket.handshake.ServerHandshake
import java.net.URI
import java.util.concurrent.ConcurrentHashMap

class WebSocketHandler private constructor() {
    companion object {
        @Volatile
        private var INSTANCE: WebSocketHandler? = null
        
        fun getInstance(): WebSocketHandler {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: WebSocketHandler().also { INSTANCE = it }
            }
        }
    }
    
    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }
    
    private var webSocketClient: WebSocketClient? = null
    private var reconnectJob: Job? = null
    private var pingJob: Job? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    // Connection state
    private val _connectionState = MutableStateFlow(ConnectionState.DISCONNECTED)
    val connectionState: StateFlow<ConnectionState> = _connectionState.asStateFlow()
    
    // Message flow
    private val _messageFlow = MutableSharedFlow<GameMessage>()
    val messageFlow: SharedFlow<GameMessage> = _messageFlow.asSharedFlow()
    
    // Connection tracking
    private var reconnectAttempts = 0
    private val maxReconnectAttempts = 5
    private var lastSessionId: String? = null
    private var lastAuthToken: String? = null
    
    suspend fun connect(sessionId: String, authToken: String) {
        if (_connectionState.value == ConnectionState.CONNECTED) return
        
        lastSessionId = sessionId
        lastAuthToken = authToken
        
        _connectionState.value = ConnectionState.CONNECTING
        
        try {
            disconnect() // Ensure clean state
            
            val headers = ConcurrentHashMap<String, String>().apply {
                put("Authorization", "Bearer $authToken")
                put("X-Session-ID", sessionId)
            }
            
            webSocketClient = object : WebSocketClient(URI(NetworkConfiguration.WEBSOCKET_URL), headers) {
                override fun onOpen(handshake: ServerHandshake?) {
                    if (NetworkConfiguration.ENABLE_WEBSOCKET_LOGS) {
                        println("WebSocket connected: ${handshake?.httpStatus}")
                    }
                    _connectionState.value = ConnectionState.CONNECTED
                    reconnectAttempts = 0
                    startPingTimer()
                }
                
                override fun onMessage(message: String?) {
                    message?.let { handleMessage(it) }
                }
                
                override fun onClose(code: Int, reason: String?, remote: Boolean) {
                    if (NetworkConfiguration.ENABLE_WEBSOCKET_LOGS) {
                        println("WebSocket closed: $code, $reason, remote: $remote")
                    }
                    handleConnectionLost()
                }
                
                override fun onError(ex: Exception?) {
                    if (NetworkConfiguration.ENABLE_WEBSOCKET_LOGS) {
                        println("WebSocket error: ${ex?.message}")
                    }
                    handleConnectionError(ex)
                }
            }
            
            webSocketClient?.connect()
            
        } catch (e: Exception) {
            _connectionState.value = ConnectionState.DISCONNECTED
            throw NetworkError.Custom("Failed to connect: ${e.message}")
        }
    }
    
    suspend fun disconnect() {
        stopPingTimer()
        reconnectJob?.cancel()
        
        webSocketClient?.let { client ->
            if (client.isOpen) {
                client.close()
            }
        }
        webSocketClient = null
        
        _connectionState.value = ConnectionState.DISCONNECTED
    }
    
    suspend fun send(message: GameMessage) {
        val client = webSocketClient
        if (client == null || !client.isOpen) {
            throw NetworkError.NoConnection
        }
        
        try {
            val jsonMessage = json.encodeToString(GameMessage.serializer(), message)
            client.send(jsonMessage)
        } catch (e: Exception) {
            throw NetworkError.Custom("Failed to send message: ${e.message}")
        }
    }
    
    private fun handleMessage(message: String) {
        try {
            val gameMessage = json.decodeFromString(GameMessage.serializer(), message)
            scope.launch {
                _messageFlow.emit(gameMessage)
            }
        } catch (e: Exception) {
            if (NetworkConfiguration.ENABLE_WEBSOCKET_LOGS) {
                println("Failed to decode message: ${e.message}")
            }
        }
    }
    
    private fun handleConnectionLost() {
        _connectionState.value = ConnectionState.DISCONNECTED
        stopPingTimer()
        
        // Attempt reconnection if appropriate
        if (reconnectAttempts < maxReconnectAttempts && lastSessionId != null && lastAuthToken != null) {
            attemptReconnection()
        }
    }
    
    private fun handleConnectionError(exception: Exception?) {
        _connectionState.value = ConnectionState.DISCONNECTED
        stopPingTimer()
        
        if (NetworkConfiguration.ENABLE_WEBSOCKET_LOGS) {
            println("Connection error: ${exception?.message}")
        }
        
        // Attempt reconnection for recoverable errors
        if (reconnectAttempts < maxReconnectAttempts && shouldRetryConnection(exception)) {
            attemptReconnection()
        }
    }
    
    private fun attemptReconnection() {
        reconnectJob?.cancel()
        reconnectJob = scope.launch {
            reconnectAttempts++
            _connectionState.value = ConnectionState.RECONNECTING
            
            val delayMs = NetworkConfiguration.RETRY_DELAY * (1L shl (reconnectAttempts - 1))
            delay(delayMs)
            
            try {
                lastSessionId?.let { sessionId ->
                    lastAuthToken?.let { authToken ->
                        connect(sessionId, authToken)
                    }
                }
            } catch (e: Exception) {
                if (NetworkConfiguration.ENABLE_WEBSOCKET_LOGS) {
                    println("Reconnection failed: ${e.message}")
                }
                
                if (reconnectAttempts >= maxReconnectAttempts) {
                    _connectionState.value = ConnectionState.DISCONNECTED
                }
            }
        }
    }
    
    private fun shouldRetryConnection(exception: Exception?): Boolean {
        return when {
            exception?.message?.contains("timeout", ignoreCase = true) == true -> true
            exception?.message?.contains("network", ignoreCase = true) == true -> true
            exception?.message?.contains("connection", ignoreCase = true) == true -> true
            else -> false
        }
    }
    
    private fun startPingTimer() {
        stopPingTimer()
        pingJob = scope.launch {
            while (isActive && webSocketClient?.isOpen == true) {
                delay(NetworkConfiguration.PING_INTERVAL)
                try {
                    webSocketClient?.sendPing()
                } catch (e: Exception) {
                    if (NetworkConfiguration.ENABLE_WEBSOCKET_LOGS) {
                        println("Ping failed: ${e.message}")
                    }
                    break
                }
            }
        }
    }
    
    private fun stopPingTimer() {
        pingJob?.cancel()
        pingJob = null
    }
    
    fun cleanup() {
        scope.cancel()
        disconnect()
    }
}