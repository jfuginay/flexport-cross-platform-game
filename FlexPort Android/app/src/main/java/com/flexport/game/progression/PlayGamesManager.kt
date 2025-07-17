package com.flexport.game.progression

import android.app.Activity
import android.content.Context
import android.content.Intent
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInClient
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.games.Games
import com.google.android.gms.games.GamesClient
import com.google.android.gms.games.LeaderboardsClient
import com.google.android.gms.games.AchievementsClient
import com.google.android.gms.games.PlayGames
import com.google.android.gms.games.leaderboard.LeaderboardVariant
import com.google.android.gms.games.achievement.Achievement
import com.google.android.gms.tasks.Task
import kotlinx.coroutines.*

/**
 * Google Play Games Services integration for FlexPort
 * Handles authentication, achievements, leaderboards, and cloud save
 */
class PlayGamesManager private constructor(private val context: Context) {
    
    companion object {
        @Volatile
        private var INSTANCE: PlayGamesManager? = null
        
        fun getInstance(context: Context): PlayGamesManager {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: PlayGamesManager(context.applicationContext).also { INSTANCE = it }
            }
        }
        
        // Request codes
        const val RC_SIGN_IN = 9001
        const val RC_ACHIEVEMENT_UI = 9002
        const val RC_LEADERBOARD_UI = 9003
        
        // Achievement IDs (these would be configured in Google Play Console)
        object AchievementIds {
            const val FIRST_TRADE = "CgkI2cT8-NgbEAIQAQ"
            const val TRADE_MASTER = "CgkI2cT8-NgbEAIQAg"
            const val PROFIT_KING = "CgkI2cT8-NgbEAIQAw"
            const val FLEET_BUILDER = "CgkI2cT8-NgbEAIQBA"
            const val DIVERSE_FLEET = "CgkI2cT8-NgbEAIQBQ"
            const val FLEET_ADMIRAL = "CgkI2cT8-NgbEAIQBg"
            const val ROUTE_PLANNER = "CgkI2cT8-NgbEAIQBw"
            const val GLOBAL_NETWORK = "CgkI2cT8-NgbEAIQCA"
            const val MARKET_WATCHER = "CgkI2cT8-NgbEAIQCQ"
            const val ARBITRAGE_EXPERT = "CgkI2cT8-NgbEAIQCg"
            const val LEVEL_10 = "CgkI2cT8-NgbEAIQCw"
            const val LEVEL_25 = "CgkI2cT8-NgbEAIQDA"
            const val LEVEL_50 = "CgkI2cT8-NgbEAIQDQ"
            const val SINGULARITY_SURVIVOR = "CgkI2cT8-NgbEAIQDg"
            const val EFFICIENCY_MASTER = "CgkI2cT8-NgbEAIQDw"
            const val MONOPOLIST = "CgkI2cT8-NgbEAIQEA"
        }
        
        // Leaderboard IDs
        object LeaderboardIds {
            const val TOTAL_EXPERIENCE = "CgkI2cT8-NgbEAIQEQ"
            const val PLAYER_LEVEL = "CgkI2cT8-NgbEAIQEg"
            const val TOTAL_PROFIT = "CgkI2cT8-NgbEAIQEw"
            const val FLEET_SIZE = "CgkI2cT8-NgbEAIQFA"
            const val TRADE_ROUTES = "CgkI2cT8-NgbEAIQFQ"
        }
    }
    
    // Authentication state
    private val _isAuthenticated = MutableLiveData(false)
    val isAuthenticated: LiveData<Boolean> = _isAuthenticated
    
    private val _playerDisplayName = MutableLiveData<String?>()
    val playerDisplayName: LiveData<String?> = _playerDisplayName
    
    // Google Play Games clients
    private var gamesClient: GamesClient? = null
    private var leaderboardsClient: LeaderboardsClient? = null
    private var achievementsClient: AchievementsClient? = null
    private var googleSignInClient: GoogleSignInClient? = null
    
    // Achievement mapping for local to Play Games IDs
    private val achievementMapping = mapOf(
        "first_trade" to AchievementIds.FIRST_TRADE,
        "trade_master" to AchievementIds.TRADE_MASTER,
        "profit_king" to AchievementIds.PROFIT_KING,
        "fleet_builder" to AchievementIds.FLEET_BUILDER,
        "diverse_fleet" to AchievementIds.DIVERSE_FLEET,
        "fleet_admiral" to AchievementIds.FLEET_ADMIRAL,
        "route_planner" to AchievementIds.ROUTE_PLANNER,
        "global_network" to AchievementIds.GLOBAL_NETWORK,
        "market_watcher" to AchievementIds.MARKET_WATCHER,
        "arbitrage_expert" to AchievementIds.ARBITRAGE_EXPERT,
        "level_10" to AchievementIds.LEVEL_10,
        "level_25" to AchievementIds.LEVEL_25,
        "level_50" to AchievementIds.LEVEL_50,
        "singularity_survivor" to AchievementIds.SINGULARITY_SURVIVOR,
        "efficiency_master" to AchievementIds.EFFICIENCY_MASTER,
        "monopolist" to AchievementIds.MONOPOLIST
    )
    
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    
    init {
        initializeGoogleSignIn()
        checkAutoSignIn()
    }
    
    // MARK: - Authentication
    
    private fun initializeGoogleSignIn() {
        val gso = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_GAMES_SIGN_IN)
            .requestEmail()
            .build()
        
        googleSignInClient = GoogleSignIn.getClient(context, gso)
    }
    
    private fun checkAutoSignIn() {
        val lastSignedInAccount = GoogleSignIn.getLastSignedInAccount(context)
        if (lastSignedInAccount != null && GoogleSignIn.hasPermissions(lastSignedInAccount, *getGoogleSignInOptions().scopeArray)) {
            onSignInSuccess(lastSignedInAccount)
        }
    }
    
    private fun getGoogleSignInOptions(): GoogleSignInOptions {
        return GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_GAMES_SIGN_IN)
            .requestEmail()
            .build()
    }
    
    fun startSignInIntent(activity: Activity) {
        val signInIntent = googleSignInClient?.signInIntent
        signInIntent?.let { intent ->
            activity.startActivityForResult(intent, RC_SIGN_IN)
        }
    }
    
    fun handleSignInResult(data: Intent?) {
        GoogleSignIn.getSignedInAccountFromIntent(data)
            .addOnCompleteListener { task ->
                if (task.isSuccessful) {
                    val account = task.result
                    onSignInSuccess(account)
                } else {
                    onSignInFailure(task.exception)
                }
            }
    }
    
    private fun onSignInSuccess(account: com.google.android.gms.auth.api.signin.GoogleSignInAccount) {
        _isAuthenticated.value = true
        _playerDisplayName.value = account.displayName
        
        // Initialize Play Games clients
        gamesClient = Games.getGamesClient(context, account)
        leaderboardsClient = Games.getLeaderboardsClient(context, account)
        achievementsClient = Games.getAchievementsClient(context, account)
        
        // Integrate with progression system
        val progressionSystem = ProgressionSystem.getInstance(context)
        gamesClient?.let { games ->
            leaderboardsClient?.let { leaderboards ->
                achievementsClient?.let { achievements ->
                    progressionSystem.initializePlayGames(games, leaderboards, achievements)
                }
            }
        }
        
        // Sync existing data
        syncLocalDataToPlayGames()
        
        // Notify success
        ProgressionEventBus.publish(PlayGamesAuthenticatedEvent(account.displayName ?: "Player"))
    }
    
    private fun onSignInFailure(exception: Exception?) {
        _isAuthenticated.value = false
        _playerDisplayName.value = null
        
        // Clear clients
        gamesClient = null
        leaderboardsClient = null
        achievementsClient = null
        
        // Notify failure
        ProgressionEventBus.publish(PlayGamesAuthenticationFailedEvent(exception?.message ?: "Unknown error"))
    }
    
    fun signOut() {
        googleSignInClient?.signOut()?.addOnCompleteListener {
            _isAuthenticated.value = false
            _playerDisplayName.value = null
            gamesClient = null
            leaderboardsClient = null
            achievementsClient = null
        }
    }
    
    // MARK: - Achievements
    
    fun unlockAchievement(localAchievementId: String) {
        val playGamesId = achievementMapping[localAchievementId] ?: return
        
        achievementsClient?.unlock(playGamesId)?.addOnCompleteListener { task ->
            if (task.isSuccessful) {
                // Achievement unlocked successfully
            } else {
                // Handle error
            }
        }
    }
    
    fun incrementAchievement(localAchievementId: String, numSteps: Int) {
        val playGamesId = achievementMapping[localAchievementId] ?: return
        
        achievementsClient?.increment(playGamesId, numSteps)?.addOnCompleteListener { task ->
            if (task.isSuccessful) {
                // Achievement incremented successfully
            } else {
                // Handle error
            }
        }
    }
    
    fun setAchievementSteps(localAchievementId: String, numSteps: Int) {
        val playGamesId = achievementMapping[localAchievementId] ?: return
        
        achievementsClient?.setSteps(playGamesId, numSteps)?.addOnCompleteListener { task ->
            if (task.isSuccessful) {
                // Achievement steps set successfully
            } else {
                // Handle error
            }
        }
    }
    
    fun showAchievements(activity: Activity) {
        achievementsClient?.achievementsIntent?.addOnSuccessListener { intent ->
            activity.startActivityForResult(intent, RC_ACHIEVEMENT_UI)
        }
    }
    
    // MARK: - Leaderboards
    
    fun submitScore(leaderboardId: String, score: Long) {
        leaderboardsClient?.submitScore(leaderboardId, score)?.addOnCompleteListener { task ->
            if (task.isSuccessful) {
                // Score submitted successfully
            } else {
                // Handle error
            }
        }
    }
    
    fun submitExperienceScore(experience: Int) {
        submitScore(LeaderboardIds.TOTAL_EXPERIENCE, experience.toLong())
    }
    
    fun submitLevelScore(level: Int) {
        submitScore(LeaderboardIds.PLAYER_LEVEL, level.toLong())
    }
    
    fun submitProfitScore(profit: Long) {
        submitScore(LeaderboardIds.TOTAL_PROFIT, profit)
    }
    
    fun submitFleetSizeScore(fleetSize: Int) {
        submitScore(LeaderboardIds.FLEET_SIZE, fleetSize.toLong())
    }
    
    fun submitTradeRoutesScore(routes: Int) {
        submitScore(LeaderboardIds.TRADE_ROUTES, routes.toLong())
    }
    
    fun showLeaderboard(activity: Activity, leaderboardId: String) {
        leaderboardsClient?.getLeaderboardIntent(leaderboardId)?.addOnSuccessListener { intent ->
            activity.startActivityForResult(intent, RC_LEADERBOARD_UI)
        }
    }
    
    fun showAllLeaderboards(activity: Activity) {
        leaderboardsClient?.allLeaderboardsIntent?.addOnSuccessListener { intent ->
            activity.startActivityForResult(intent, RC_LEADERBOARD_UI)
        }
    }
    
    // MARK: - Data Sync
    
    private fun syncLocalDataToPlayGames() {
        scope.launch {
            try {
                val progressionSystem = ProgressionSystem.getInstance(context)
                
                // Submit current scores
                progressionSystem.currentExperience.value?.let { exp ->
                    submitExperienceScore(exp)
                }
                
                progressionSystem.currentLevel.value?.let { level ->
                    submitLevelScore(level)
                }
                
                // Sync achievements
                progressionSystem.achievements.value?.forEach { achievement ->
                    if (achievement.isUnlocked) {
                        unlockAchievement(achievement.id)
                    } else if (achievement.progress > 0) {
                        // For incremental achievements, set the current progress
                        val playGamesId = achievementMapping[achievement.id]
                        if (playGamesId != null && achievement.maxProgress > 1) {
                            setAchievementSteps(achievement.id, achievement.progress.toInt())
                        }
                    }
                }
                
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
    
    fun loadPlayGamesAchievements(): Task<com.google.android.gms.games.AnnotatedData<com.google.android.gms.games.achievement.AchievementBuffer>>? {
        return achievementsClient?.load(false)
    }
    
    fun loadLeaderboardScores(leaderboardId: String): Task<com.google.android.gms.games.AnnotatedData<com.google.android.gms.games.leaderboard.LeaderboardScoreBuffer>>? {
        return leaderboardsClient?.loadCurrentPlayerLeaderboardScore(
            leaderboardId,
            LeaderboardVariant.TIME_SPAN_ALL_TIME,
            LeaderboardVariant.COLLECTION_PUBLIC
        )
    }
    
    // MARK: - Player Stats and Social
    
    fun loadPlayerStats() {
        gamesClient?.loadGame()?.addOnSuccessListener { game ->
            // Handle game info
        }
    }
    
    fun showGameProfile(activity: Activity) {
        gamesClient?.setViewForPopups(activity.findViewById(android.R.id.content))
        gamesClient?.setGravityForPopups(android.view.Gravity.TOP or android.view.Gravity.CENTER_HORIZONTAL)
    }
    
    // MARK: - Events and Cleanup
    
    fun cleanup() {
        scope.cancel()
    }
}

// Additional event types for Play Games
data class PlayGamesAuthenticatedEvent(val playerName: String) : ProgressionEvent()
data class PlayGamesAuthenticationFailedEvent(val error: String) : ProgressionEvent()