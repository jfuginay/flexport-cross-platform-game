package com.flexport.game.networking

import kotlinx.coroutines.delay
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import okhttp3.logging.HttpLoggingInterceptor
import java.io.IOException
import java.util.concurrent.TimeUnit

class ApiClient private constructor() {
    companion object {
        @Volatile
        private var INSTANCE: ApiClient? = null
        
        fun getInstance(): ApiClient {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: ApiClient().also { INSTANCE = it }
            }
        }
    }
    
    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }
    
    private val httpClient: OkHttpClient by lazy {
        val builder = OkHttpClient.Builder()
            .connectTimeout(NetworkConfiguration.REQUEST_TIMEOUT, TimeUnit.MILLISECONDS)
            .readTimeout(NetworkConfiguration.REQUEST_TIMEOUT, TimeUnit.MILLISECONDS)
            .writeTimeout(NetworkConfiguration.REQUEST_TIMEOUT, TimeUnit.MILLISECONDS)
        
        if (NetworkConfiguration.ENABLE_NETWORK_LOGS) {
            val loggingInterceptor = HttpLoggingInterceptor().apply {
                level = HttpLoggingInterceptor.Level.BODY
            }
            builder.addInterceptor(loggingInterceptor)
        }
        
        builder.build()
    }
    
    private var authToken: String? = null
    
    fun setAuthToken(token: String) {
        authToken = token
    }
    
    // Generic request method with retry logic
    private suspend inline fun <reified T> request(
        endpoint: String,
        method: String = "GET",
        body: Any? = null,
        retryCount: Int = 0
    ): T {
        val url = "${NetworkConfiguration.BASE_URL}/$endpoint"
        val requestBuilder = Request.Builder().url(url)
        
        // Add auth header if available
        authToken?.let { token ->
            requestBuilder.addHeader("Authorization", "Bearer $token")
        }
        
        // Add common headers
        requestBuilder.addHeader("Accept", "application/json")
        requestBuilder.addHeader("Content-Type", "application/json")
        
        // Add body if provided
        if (body != null && method != "GET") {
            val jsonBody = json.encodeToString(body::class.serializer() as kotlinx.serialization.KSerializer<Any>, body)
            requestBuilder.method(method, jsonBody.toRequestBody("application/json".toMediaType()))
        } else {
            requestBuilder.method(method, null)
        }
        
        try {
            val response = httpClient.newCall(requestBuilder.build()).execute()
            
            when (response.code) {
                in 200..299 -> {
                    val responseBody = response.body?.string() ?: ""
                    return json.decodeFromString<T>(responseBody)
                }
                401 -> throw NetworkError.AuthenticationFailed
                429 -> throw NetworkError.RateLimited
                in 500..599 -> throw NetworkError.ServerError(response.code)
                else -> throw NetworkError.Custom("Unexpected status code: ${response.code}")
            }
        } catch (e: IOException) {
            // Retry logic for transient failures
            if (retryCount < NetworkConfiguration.MAX_RETRIES && shouldRetry(e)) {
                val delayMs = NetworkConfiguration.RETRY_DELAY * (1L shl retryCount) // Exponential backoff
                delay(delayMs)
                return request<T>(endpoint, method, body, retryCount + 1)
            }
            
            throw when {
                e.message?.contains("timeout", ignoreCase = true) == true -> NetworkError.Timeout
                e.message?.contains("network", ignoreCase = true) == true -> NetworkError.NoConnection
                else -> NetworkError.Custom(e.message ?: "Unknown network error")
            }
        }
    }
    
    private fun shouldRetry(error: Throwable): Boolean {
        return when (error) {
            is IOException -> true
            is NetworkError.Timeout -> true
            is NetworkError.NoConnection -> true
            is NetworkError.ServerError -> true
            else -> false
        }
    }
    
    // Matchmaking API
    suspend fun requestMatch(request: MatchmakingRequest): MatchmakingResponse {
        return request(NetworkConfiguration.Endpoints.MATCHMAKING, "POST", request)
    }
    
    suspend fun cancelMatchmaking(requestId: String) {
        val cancelRequest = mapOf("requestId" to requestId)
        request<Unit>(NetworkConfiguration.Endpoints.MATCHMAKING, "DELETE", cancelRequest)
    }
    
    // Game Session API
    suspend fun getGameSession(sessionId: String): GameSession {
        return request(NetworkConfiguration.Endpoints.gameSession(sessionId))
    }
    
    suspend fun syncGameState(state: GameStateSyncRequest): GameStateSyncResponse {
        return request(NetworkConfiguration.Endpoints.SYNC_GAME_STATE, "POST", state)
    }
    
    // Leaderboard API
    suspend fun getLeaderboard(type: LeaderboardType, timeframe: Timeframe): LeaderboardResponse {
        val endpoint = "${NetworkConfiguration.Endpoints.LEADERBOARD}?type=${type.name.lowercase()}&timeframe=${timeframe.name.lowercase()}"
        return request(endpoint)
    }
    
    // Player Stats API
    suspend fun getPlayerStats(playerId: String): PlayerStats {
        return request(NetworkConfiguration.Endpoints.playerStats(playerId))
    }
    
    suspend fun updatePlayerStats(playerId: String, stats: PlayerStatsUpdate): PlayerStats {
        return request(NetworkConfiguration.Endpoints.playerStats(playerId), "PATCH", stats)
    }
}