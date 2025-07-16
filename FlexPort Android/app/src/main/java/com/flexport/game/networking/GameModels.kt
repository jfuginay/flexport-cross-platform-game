package com.flexport.game.networking

import kotlinx.serialization.Serializable
import java.util.*

// Connection states
enum class ConnectionState {
    DISCONNECTED,
    CONNECTING,
    CONNECTED,
    RECONNECTING
}

// Game modes
@Serializable
enum class GameMode {
    REALTIME,
    TURN_BASED,
    COOPERATIVE,
    COMPETITIVE
}

// Session status
@Serializable
enum class SessionStatus {
    WAITING,
    ACTIVE,
    PAUSED,
    COMPLETED
}

// Matchmaking status
@Serializable
enum class MatchmakingStatus {
    SEARCHING,
    MATCHED,
    CANCELLED,
    FAILED
}

// Message types for WebSocket communication
@Serializable
enum class MessageType {
    GAME_ACTION,
    STATE_UPDATE,
    PLAYER_JOINED,
    PLAYER_LEFT,
    CHAT_MESSAGE,
    SYSTEM_MESSAGE,
    CONFLICT_RESOLUTION
}

// Leaderboard types
enum class LeaderboardType {
    WEALTH,
    EFFICIENCY,
    REPUTATION,
    SINGULARITY_PROGRESS
}

// Timeframes
enum class Timeframe {
    DAILY,
    WEEKLY,
    MONTHLY,
    ALL_TIME
}

// Core game models
@Serializable
data class GameState(
    val playerAssets: PlayerAssets = PlayerAssets(),
    val markets: Markets = Markets(),
    val aiCompetitors: List<AICompetitor> = emptyList(),
    val turn: Int = 0,
    val isGameActive: Boolean = true
)

@Serializable
data class PlayerAssets(
    val money: Double = 1_000_000.0,
    val ships: List<Ship> = emptyList(),
    val warehouses: List<Warehouse> = emptyList(),
    val reputation: Double = 50.0
)

@Serializable
data class Markets(
    val goodsMarket: GoodsMarket = GoodsMarket(),
    val capitalMarket: CapitalMarket = CapitalMarket(),
    val assetMarket: AssetMarket = AssetMarket(),
    val laborMarket: LaborMarket = LaborMarket()
)

@Serializable
data class GoodsMarket(
    val commodities: List<Commodity> = emptyList()
)

@Serializable
data class CapitalMarket(
    val interestRate: Double = 0.05,
    val availableCapital: Double = 10_000_000.0
)

@Serializable
data class AssetMarket(
    val availableShips: List<Ship> = emptyList(),
    val availableWarehouses: List<Warehouse> = emptyList()
)

@Serializable
data class LaborMarket(
    val availableWorkers: List<Worker> = emptyList(),
    val averageWage: Double = 50_000.0
)

@Serializable
data class Ship(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val capacity: Int,
    val speed: Double,
    val efficiency: Double,
    val maintenanceCost: Double
)

@Serializable
data class Warehouse(
    val id: String = UUID.randomUUID().toString(),
    val location: Location,
    val capacity: Int,
    val storageCost: Double
)

@Serializable
data class Location(
    val name: String,
    val coordinates: Coordinates,
    val portType: PortType
)

@Serializable
data class Coordinates(
    val latitude: Double,
    val longitude: Double
)

@Serializable
enum class PortType {
    SEA,
    AIR,
    RAIL,
    MULTIMODAL
}

@Serializable
data class Commodity(
    val name: String,
    val basePrice: Double,
    val volatility: Double,
    val supply: Double,
    val demand: Double
)

@Serializable
data class Worker(
    val specialization: WorkerSpecialization,
    val skill: Double,
    val wage: Double
)

@Serializable
enum class WorkerSpecialization {
    OPERATIONS,
    SALES,
    ENGINEERING,
    MANAGEMENT
}

@Serializable
data class AICompetitor(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val assets: PlayerAssets,
    val learningRate: Double,
    val singularityContribution: Double
)

// Networking models
@Serializable
data class GameSession(
    val id: String,
    val mode: GameMode,
    val players: List<PlayerInfo>,
    val status: SessionStatus,
    val createdAt: Long, // Unix timestamp
    val turn: Int? = null
)

@Serializable
data class PlayerInfo(
    val id: String,
    val name: String,
    val avatarURL: String? = null,
    val isOnline: Boolean
)

@Serializable
data class MatchmakingRequest(
    val playerId: String,
    val gameMode: GameMode,
    val preferredRegion: String? = null,
    val skillRating: Int? = null
)

@Serializable
data class MatchmakingResponse(
    val requestId: String,
    val status: MatchmakingStatus,
    val estimatedWaitTime: Long? = null,
    val sessionId: String? = null
)

@Serializable
data class GameStateSyncRequest(
    val playerId: String,
    val sessionId: String,
    val localStateJson: String, // JSON-encoded game state
    val lastSyncTimestamp: Long,
    val pendingActions: List<GameAction>
)

@Serializable
data class GameStateSyncResponse(
    val serverStateJson: String, // JSON-encoded game state
    val conflicts: List<ConflictResolution>,
    val serverTimestamp: Long
)

@Serializable
data class LeaderboardResponse(
    val entries: List<LeaderboardEntry>,
    val playerRank: Int? = null,
    val totalPlayers: Int
)

@Serializable
data class LeaderboardEntry(
    val rank: Int,
    val playerId: String,
    val playerName: String,
    val score: Double,
    val additionalData: Map<String, Double>? = null
)

@Serializable
data class PlayerStats(
    val playerId: String,
    val gamesPlayed: Int,
    val gamesWon: Int,
    val totalWealth: Double,
    val averageEfficiency: Double,
    val bestSingularityProgress: Double,
    val achievements: List<String>,
    val lastUpdated: Long
)

@Serializable
data class PlayerStatsUpdate(
    val deltaGamesPlayed: Int? = null,
    val deltaGamesWon: Int? = null,
    val newWealth: Double? = null,
    val newEfficiency: Double? = null,
    val newSingularityProgress: Double? = null,
    val newAchievements: List<String>? = null
)

// WebSocket message models
@Serializable
data class GameMessage(
    val id: String,
    val type: MessageType,
    val timestamp: Long,
    val payload: MessagePayload
)

@Serializable
sealed class MessagePayload {
    @Serializable
    data class Action(val action: GameAction) : MessagePayload()
    
    @Serializable
    data class StateUpdate(val update: GameStateUpdate) : MessagePayload()
    
    @Serializable
    data class PlayerEvent(val event: com.flexport.game.networking.PlayerEvent) : MessagePayload()
    
    @Serializable
    data class Chat(val message: ChatMessage) : MessagePayload()
    
    @Serializable
    data class System(val message: SystemMessage) : MessagePayload()
    
    @Serializable
    data class Conflict(val resolution: ConflictResolution) : MessagePayload()
}

@Serializable
data class GameAction(
    val playerId: String,
    val actionType: String,
    val parameters: Map<String, String> // Simplified to avoid complex Any type
)

@Serializable
data class GameStateUpdate(
    val turn: Int,
    val playerStates: Map<String, PlayerStateSnapshot>,
    val marketState: MarketStateSnapshot
)

@Serializable
data class PlayerEvent(
    val playerId: String,
    val eventType: String,
    val isJoining: Boolean
)

@Serializable
data class ChatMessage(
    val playerId: String,
    val message: String,
    val timestamp: Long
)

@Serializable
data class SystemMessage(
    val message: String,
    val severity: String
)

@Serializable
data class ConflictResolution(
    val conflictId: String,
    val originalActions: List<GameAction>,
    val resolution: GameAction,
    val reason: String
)

@Serializable
data class PlayerStateSnapshot(
    val money: Double,
    val shipCount: Int,
    val warehouseCount: Int,
    val reputation: Double
)

@Serializable
data class MarketStateSnapshot(
    val commodityPrices: Map<String, Double>,
    val interestRate: Double
)

// Network error types
sealed class NetworkError : Exception() {
    object NoConnection : NetworkError()
    object Timeout : NetworkError()
    object AuthenticationFailed : NetworkError()
    object RateLimited : NetworkError()
    data class ServerError(val code: Int) : NetworkError()
    data class Custom(override val message: String) : NetworkError()
    object InvalidResponse : NetworkError()
}