package com.flexport.economics.services

import com.flexport.economics.models.MarketCondition
import kotlinx.coroutines.flow.*
import java.util.concurrent.ConcurrentHashMap

/**
 * Economic Engine that manages player finances and market conditions
 */
class EconomicEngine private constructor() {
    
    companion object {
        @Volatile
        private var INSTANCE: EconomicEngine? = null
        
        fun getInstance(): EconomicEngine {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: EconomicEngine().also { INSTANCE = it }
            }
        }
    }
    
    // Player balances
    private val playerBalances = ConcurrentHashMap<String, Double>()
    
    // Transaction history
    private val _transactions = MutableSharedFlow<Transaction>()
    val transactions: SharedFlow<Transaction> = _transactions.asSharedFlow()
    
    // Market conditions
    private val _marketConditions = MutableStateFlow(
        mapOf(
            "asset_market" to MarketCondition(
                name = "Asset Market",
                demandMultiplier = 1.0,
                supplyMultiplier = 1.0,
                volatility = 0.1
            ),
            "commodity_market" to MarketCondition(
                name = "Commodity Market",
                demandMultiplier = 1.0,
                supplyMultiplier = 1.0,
                volatility = 0.15
            ),
            "labor_market" to MarketCondition(
                name = "Labor Market",
                demandMultiplier = 1.0,
                supplyMultiplier = 1.0,
                volatility = 0.05
            )
        )
    )
    val marketConditions: StateFlow<Map<String, MarketCondition>> = _marketConditions.asStateFlow()
    
    /**
     * Initialize a player's balance
     */
    fun initializePlayer(playerId: String, initialBalance: Double = 1_000_000.0) {
        playerBalances[playerId] = initialBalance
    }
    
    /**
     * Get player's current balance
     */
    fun getPlayerBalance(playerId: String): Double {
        return playerBalances[playerId] ?: 0.0
    }
    
    /**
     * Add funds to player's balance
     */
    suspend fun addFunds(playerId: String, amount: Double, description: String) {
        if (amount <= 0) return
        
        val currentBalance = playerBalances[playerId] ?: 0.0
        val newBalance = currentBalance + amount
        playerBalances[playerId] = newBalance
        
        // Record transaction
        val transaction = Transaction(
            playerId = playerId,
            type = TransactionType.CREDIT,
            amount = amount,
            description = description,
            balanceAfter = newBalance,
            timestamp = System.currentTimeMillis()
        )
        _transactions.emit(transaction)
    }
    
    /**
     * Deduct funds from player's balance
     */
    suspend fun deductFunds(playerId: String, amount: Double, description: String): Boolean {
        if (amount <= 0) return true
        
        val currentBalance = playerBalances[playerId] ?: 0.0
        if (currentBalance < amount) {
            return false // Insufficient funds
        }
        
        val newBalance = currentBalance - amount
        playerBalances[playerId] = newBalance
        
        // Record transaction
        val transaction = Transaction(
            playerId = playerId,
            type = TransactionType.DEBIT,
            amount = amount,
            description = description,
            balanceAfter = newBalance,
            timestamp = System.currentTimeMillis()
        )
        _transactions.emit(transaction)
        
        return true
    }
    
    /**
     * Transfer funds between players
     */
    suspend fun transferFunds(
        fromPlayerId: String,
        toPlayerId: String,
        amount: Double,
        description: String
    ): Boolean {
        if (amount <= 0) return false
        
        val fromBalance = playerBalances[fromPlayerId] ?: 0.0
        if (fromBalance < amount) return false
        
        // Perform atomic transfer
        synchronized(playerBalances) {
            playerBalances[fromPlayerId] = fromBalance - amount
            playerBalances[toPlayerId] = (playerBalances[toPlayerId] ?: 0.0) + amount
        }
        
        // Record transactions
        _transactions.emit(Transaction(
            playerId = fromPlayerId,
            type = TransactionType.DEBIT,
            amount = amount,
            description = "Transfer to $toPlayerId: $description",
            balanceAfter = playerBalances[fromPlayerId]!!,
            timestamp = System.currentTimeMillis()
        ))
        
        _transactions.emit(Transaction(
            playerId = toPlayerId,
            type = TransactionType.CREDIT,
            amount = amount,
            description = "Transfer from $fromPlayerId: $description",
            balanceAfter = playerBalances[toPlayerId]!!,
            timestamp = System.currentTimeMillis()
        ))
        
        return true
    }
    
    /**
     * Get market condition for a specific market
     */
    fun getMarketCondition(marketName: String): MarketCondition {
        return _marketConditions.value[marketName] ?: MarketCondition(
            name = marketName,
            demandMultiplier = 1.0,
            supplyMultiplier = 1.0,
            volatility = 0.1
        )
    }
    
    /**
     * Update market conditions
     */
    fun updateMarketCondition(marketName: String, condition: MarketCondition) {
        _marketConditions.value = _marketConditions.value + (marketName to condition)
    }
    
    /**
     * Simulate market fluctuations
     */
    fun simulateMarketFluctuations() {
        val updatedConditions = _marketConditions.value.mapValues { (_, condition) ->
            val demandChange = (Math.random() - 0.5) * 2 * condition.volatility
            val supplyChange = (Math.random() - 0.5) * 2 * condition.volatility
            
            condition.copy(
                demandMultiplier = (condition.demandMultiplier + demandChange).coerceIn(0.5, 2.0),
                supplyMultiplier = (condition.supplyMultiplier + supplyChange).coerceIn(0.5, 2.0)
            )
        }
        _marketConditions.value = updatedConditions
    }
    
    /**
     * Get transaction history for a player
     */
    fun getPlayerTransactions(playerId: String): Flow<List<Transaction>> {
        return transactions
            .scan(emptyList<Transaction>()) { acc, transaction ->
                if (transaction.playerId == playerId) acc + transaction else acc
            }
    }
    
    /**
     * Calculate net worth including assets
     */
    suspend fun calculateNetWorth(playerId: String, assetValue: Double): Double {
        val cashBalance = getPlayerBalance(playerId)
        return cashBalance + assetValue
    }
    
    /**
     * Check if player can afford a purchase
     */
    fun canAfford(playerId: String, amount: Double): Boolean {
        return getPlayerBalance(playerId) >= amount
    }
}

/**
 * Transaction record
 */
data class Transaction(
    val playerId: String,
    val type: TransactionType,
    val amount: Double,
    val description: String,
    val balanceAfter: Double,
    val timestamp: Long
)

enum class TransactionType {
    CREDIT,
    DEBIT
}

/**
 * Market condition data
 */
data class MarketCondition(
    val name: String,
    val demandMultiplier: Double,
    val supplyMultiplier: Double,
    val volatility: Double
)