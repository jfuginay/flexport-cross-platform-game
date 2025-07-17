package com.flexport.game.progression

import android.content.Context
import android.content.SharedPreferences
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import com.google.android.gms.games.GamesClient
import com.google.android.gms.games.LeaderboardsClient
import com.google.android.gms.games.AchievementsClient
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import kotlinx.coroutines.*
import java.util.*
import kotlin.math.pow

/**
 * Android progression system matching iOS feature parity
 * Handles experience, levels, achievements, and Google Play Games integration
 */
class ProgressionSystem private constructor(private val context: Context) {
    
    companion object {
        @Volatile
        private var INSTANCE: ProgressionSystem? = null
        
        fun getInstance(context: Context): ProgressionSystem {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: ProgressionSystem(context.applicationContext).also { INSTANCE = it }
            }
        }
        
        // Constants
        private const val PREFS_NAME = "flexport_progression"
        private const val MAX_LEVEL = 50
        private const val BASE_XP_REQUIREMENT = 100
        private const val XP_GROWTH_RATE = 1.15f
        
        // Google Play Games leaderboard IDs
        private const val LEADERBOARD_TOTAL_EXPERIENCE = "CgkI2cT8-NgbEAIQAQ"
        private const val LEADERBOARD_PLAYER_LEVEL = "CgkI2cT8-NgbEAIQAg"
    }
    
    // LiveData for observing progression state
    private val _currentLevel = MutableLiveData(1)
    val currentLevel: LiveData<Int> = _currentLevel
    
    private val _currentExperience = MutableLiveData(0)
    val currentExperience: LiveData<Int> = _currentExperience
    
    private val _experienceToNextLevel = MutableLiveData(BASE_XP_REQUIREMENT)
    val experienceToNextLevel: LiveData<Int> = _experienceToNextLevel
    
    private val _unlockedFeatures = MutableLiveData<Set<String>>(emptySet())
    val unlockedFeatures: LiveData<Set<String>> = _unlockedFeatures
    
    private val _achievements = MutableLiveData<List<Achievement>>(emptyList())
    val achievements: LiveData<List<Achievement>> = _achievements
    
    private val _levelProgress = MutableLiveData(0f)
    val levelProgress: LiveData<Float> = _levelProgress
    
    // Internal state
    private val levelRequirements = mutableListOf<LevelRequirement>()
    private val experienceRewards = mutableListOf<ExperienceReward>()
    private val achievementsList = mutableListOf<Achievement>()
    
    // Google Play Games clients
    private var gamesClient: GamesClient? = null
    private var leaderboardsClient: LeaderboardsClient? = null
    private var achievementsClient: AchievementsClient? = null
    private var isPlayGamesAuthenticated = false
    
    // Persistence
    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val gson = Gson()
    
    // Coroutine scope for async operations
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    
    init {
        initializeLevelRequirements()
        initializeExperienceRewards()
        initializeAchievements()
        loadProgressFromPrefs()
    }
    
    // MARK: - Level Requirements
    
    private fun initializeLevelRequirements() {
        for (level in 1..MAX_LEVEL) {
            val experienceRequired = (BASE_XP_REQUIREMENT * XP_GROWTH_RATE.pow(level - 1)).toInt()
            
            val unlocks = mutableListOf<String>()
            val rewards = LevelReward()
            
            // Define level-specific unlocks and rewards (matching iOS/web versions)
            when (level) {
                2 -> unlocks.add("basic_trade_routes")
                3 -> unlocks.add("bulk_carrier_ships")
                5 -> {
                    unlocks.addAll(listOf("container_ships", "advanced_navigation"))
                    rewards.researchPoints = 5
                }
                8 -> {
                    unlocks.addAll(listOf("tanker_ships", "fuel_efficiency_upgrade"))
                    rewards.shipSlots = 1
                }
                10 -> {
                    unlocks.addAll(listOf("market_analytics", "crew_management"))
                    rewards.cash = 500000
                    rewards.researchPoints = 10
                }
                12 -> unlocks.add("general_cargo_ships")
                15 -> {
                    unlocks.addAll(listOf("trade_route_optimization", "roro_ships"))
                    rewards.routeSlots = 2
                    rewards.researchPoints = 15
                }
                18 -> unlocks.addAll(listOf("refrigerated_ships", "advanced_cargo_handling"))
                20 -> {
                    unlocks.addAll(listOf("fleet_management", "automated_trading"))
                    rewards.cash = 1000000
                    rewards.shipSlots = 2
                }
                22 -> unlocks.add("heavy_lift_ships")
                25 -> {
                    unlocks.addAll(listOf("ai_assisted_navigation", "predictive_maintenance"))
                    rewards.researchPoints = 25
                    rewards.routeSlots = 3
                }
                30 -> {
                    unlocks.addAll(listOf("global_trade_network", "market_manipulation"))
                    rewards.cash = 2500000
                    rewards.shipSlots = 3
                }
                35 -> {
                    unlocks.addAll(listOf("quantum_logistics", "hyperloop_integration"))
                    rewards.researchPoints = 50
                }
                40 -> {
                    unlocks.addAll(listOf("autonomous_fleet_operations", "supply_chain_ai"))
                    rewards.cash = 5000000
                    rewards.shipSlots = 5
                }
                45 -> {
                    unlocks.addAll(listOf("singularity_resistance", "market_dominance"))
                    rewards.researchPoints = 100
                }
                50 -> {
                    unlocks.addAll(listOf("logistics_mastery", "infinite_scalability"))
                    rewards.cash = 10000000
                    rewards.shipSlots = 10
                    rewards.routeSlots = 10
                }
            }
            
            // Every 5 levels, grant bonus rewards
            if (level % 5 == 0) {
                rewards.cash = (rewards.cash ?: 0) + level * 50000
                rewards.researchPoints = (rewards.researchPoints ?: 0) + level / 2
            }
            
            levelRequirements.add(
                LevelRequirement(
                    level = level,
                    experienceRequired = experienceRequired,
                    unlocks = unlocks,
                    rewards = rewards
                )
            )
        }
    }
    
    // MARK: - Experience Rewards
    
    private fun initializeExperienceRewards() {
        experienceRewards.addAll(listOf(
            // Trading XP
            ExperienceReward("complete_trade", 50, mapOf("profit_margin" to 2.0f, "distance" to 1.5f)),
            ExperienceReward("profitable_trade", 100, mapOf("profit_amount" to 0.001f)),
            ExperienceReward("establish_route", 200),
            ExperienceReward("optimize_route", 150),
            
            // Fleet Management XP
            ExperienceReward("purchase_ship", 300, mapOf("ship_tier" to 1.5f)),
            ExperienceReward("upgrade_ship", 100),
            ExperienceReward("maintain_fleet", 25),
            ExperienceReward("crew_hire", 50),
            
            // Market Activities XP
            ExperienceReward("market_analysis", 30),
            ExperienceReward("price_prediction", 75, mapOf("accuracy" to 2.0f)),
            ExperienceReward("arbitrage_success", 250),
            
            // Strategic Actions XP
            ExperienceReward("port_expansion", 500),
            ExperienceReward("research_complete", 150, mapOf("research_tier" to 1.5f)),
            ExperienceReward("compete_ai_win", 400),
            
            // Milestone XP
            ExperienceReward("first_million", 1000),
            ExperienceReward("fleet_size_milestone", 500, mapOf("fleet_size" to 10f)),
            ExperienceReward("trade_volume_milestone", 750, mapOf("volume" to 0.0001f)),
            
            // Daily/Recurring XP
            ExperienceReward("daily_login", 100),
            ExperienceReward("weekly_profit", 500, mapOf("profit_percentage" to 1.5f)),
            ExperienceReward("monthly_dominance", 2000),
            
            // Achievement XP
            ExperienceReward("achievement_unlocked", 200, mapOf("rarity" to 50f))
        ))
    }
    
    // MARK: - Grant Experience
    
    fun grantExperience(action: String, context: Map<String, Float> = emptyMap()): Int {
        val reward = experienceRewards.find { it.action == action } ?: return 0
        
        var xpGained = reward.baseXP.toFloat()
        
        // Apply multipliers
        reward.multipliers?.forEach { (key, multiplier) ->
            context[key]?.let { contextValue ->
                xpGained *= (1 + (contextValue * multiplier))
            }
        }
        
        // Apply level scaling
        val levelBonus = 1 + (_currentLevel.value!! * 0.02f)
        xpGained *= levelBonus
        
        val finalXP = xpGained.toInt()
        val newExperience = _currentExperience.value!! + finalXP
        _currentExperience.value = newExperience
        
        // Check for level up
        checkLevelUp()
        
        // Update achievement progress
        updateAchievementProgress(action, context)
        
        // Save progress
        saveProgressToPrefs()
        
        // Report to Google Play Games
        reportScoreToPlayGames(newExperience)
        
        return finalXP
    }
    
    // MARK: - Level Up
    
    private fun checkLevelUp() {
        val currentLevel = _currentLevel.value!!
        val currentExperience = _currentExperience.value!!
        val experienceToNext = _experienceToNextLevel.value!!
        
        if (currentLevel < MAX_LEVEL && currentExperience >= experienceToNext) {
            var newLevel = currentLevel
            var remainingExperience = currentExperience
            
            while (newLevel < MAX_LEVEL && remainingExperience >= experienceToNext) {
                remainingExperience -= experienceToNext
                newLevel++
                
                // Apply level up effects
                applyLevelUp(newLevel)
                
                // Get new experience requirement
                val nextLevelReq = levelRequirements.find { it.level == newLevel + 1 }
                _experienceToNextLevel.value = nextLevelReq?.experienceRequired ?: 0
            }
            
            _currentLevel.value = newLevel
            _currentExperience.value = remainingExperience
            
            updateLevelProgress()
            
            // Achievement for leveling
            updateAchievementProgress("level_reached", mapOf("level" to newLevel.toFloat()))
            
            // Report level to Google Play Games
            reportLevelToPlayGames(newLevel)
        } else {
            updateLevelProgress()
        }
    }
    
    private fun applyLevelUp(level: Int) {
        val levelReq = levelRequirements.find { it.level == level } ?: return
        
        // Apply unlocks
        val currentUnlocks = _unlockedFeatures.value!!.toMutableSet()
        levelReq.unlocks.forEach { unlock ->
            currentUnlocks.add(unlock)
            notifyFeatureUnlocked(unlock)
        }
        _unlockedFeatures.value = currentUnlocks
        
        // Apply rewards
        levelReq.rewards?.let { rewards ->
            applyRewards(rewards, level)
        }
        
        // Notify level up
        notifyLevelUp(level)
    }
    
    private fun updateLevelProgress() {
        val experienceToNext = _experienceToNextLevel.value!!
        if (experienceToNext > 0) {
            val progress = _currentExperience.value!!.toFloat() / experienceToNext.toFloat()
            _levelProgress.value = progress.coerceIn(0f, 1f)
        } else {
            _levelProgress.value = 1f
        }
    }
    
    // MARK: - Rewards
    
    private fun applyRewards(rewards: LevelReward, level: Int) {
        val rewardNotifications = mutableListOf<String>()
        
        rewards.cash?.let { cash ->
            rewardNotifications.add("💰 +$${String.format("%,d", cash)}")
            // Integrate with game economy system
            notifyReward("cash", cash)
        }
        
        rewards.researchPoints?.let { points ->
            rewardNotifications.add("🔬 +$points Research Points")
            notifyReward("research_points", points)
        }
        
        rewards.shipSlots?.let { slots ->
            rewardNotifications.add("🚢 +$slots Ship Slots")
            notifyReward("ship_slots", slots)
        }
        
        rewards.routeSlots?.let { slots ->
            rewardNotifications.add("🗺 +$slots Route Slots")
            notifyReward("route_slots", slots)
        }
        
        // Broadcast level up rewards
        ProgressionEventBus.publish(LevelUpEvent(level, rewardNotifications))
    }
    
    private fun notifyFeatureUnlocked(feature: String) {
        ProgressionEventBus.publish(FeatureUnlockedEvent(feature))
    }
    
    private fun notifyLevelUp(level: Int) {
        ProgressionEventBus.publish(LevelUpEvent(level, emptyList()))
    }
    
    private fun notifyReward(type: String, amount: Int) {
        ProgressionEventBus.publish(RewardEvent(type, amount))
    }
    
    // MARK: - Achievements
    
    private fun initializeAchievements() {
        achievementsList.addAll(listOf(
            // Trading Achievements
            Achievement("first_trade", "First Steps", "Complete your first trade", 1f),
            Achievement("trade_master", "Trade Master", "Complete 100 successful trades", 100f),
            Achievement("profit_king", "Profit King", "Earn $10 million in total profit", 10000000f),
            
            // Fleet Achievements
            Achievement("fleet_builder", "Fleet Builder", "Own 10 ships", 10f),
            Achievement("diverse_fleet", "Diverse Operations", "Own one ship of each type", 7f),
            Achievement("fleet_admiral", "Fleet Admiral", "Command 50 ships", 50f),
            
            // Route Achievements
            Achievement("route_planner", "Route Planner", "Establish 5 trade routes", 5f),
            Achievement("global_network", "Global Network", "Have routes connecting all continents", 7f),
            
            // Market Achievements
            Achievement("market_watcher", "Market Watcher", "Track market trends for 7 days", 7f),
            Achievement("arbitrage_expert", "Arbitrage Expert", "Profit from 50 arbitrage opportunities", 50f),
            
            // Progression Achievements
            Achievement("level_10", "Rising Star", "Reach level 10", 10f),
            Achievement("level_25", "Industry Leader", "Reach level 25", 25f),
            Achievement("level_50", "Logistics Legend", "Reach level 50", 50f),
            
            // Special Achievements
            Achievement("singularity_survivor", "Singularity Survivor", "Survive an AI singularity event", 1f),
            Achievement("efficiency_master", "Efficiency Master", "Achieve 95% fleet efficiency", 95f),
            Achievement("monopolist", "Monopolist", "Control 50% of a commodity market", 50f)
        ))
        
        _achievements.value = achievementsList
    }
    
    private fun updateAchievementProgress(action: String, context: Map<String, Float>) {
        var hasUpdates = false
        
        achievementsList.forEachIndexed { index, achievement ->
            if (achievement.isUnlocked) return@forEachIndexed
            
            var shouldUpdate = false
            var progressIncrement = 0f
            
            when (achievement.id) {
                "first_trade" -> {
                    if (action == "complete_trade") {
                        shouldUpdate = true
                        progressIncrement = 1f
                    }
                }
                "trade_master" -> {
                    if (action == "complete_trade") {
                        shouldUpdate = true
                        progressIncrement = 1f
                    }
                }
                "profit_king" -> {
                    if (action == "profitable_trade") {
                        context["profit_amount"]?.let { profit ->
                            shouldUpdate = true
                            progressIncrement = profit
                        }
                    }
                }
                "fleet_builder", "fleet_admiral" -> {
                    if (action == "purchase_ship") {
                        context["fleet_size"]?.let { fleetSize ->
                            shouldUpdate = true
                            achievement.progress = fleetSize
                        }
                    }
                }
                "level_10", "level_25", "level_50" -> {
                    if (action == "level_reached") {
                        context["level"]?.let { level ->
                            achievement.progress = level
                            shouldUpdate = true
                        }
                    }
                }
                "arbitrage_expert" -> {
                    if (action == "arbitrage_success") {
                        shouldUpdate = true
                        progressIncrement = 1f
                    }
                }
            }
            
            if (shouldUpdate) {
                hasUpdates = true
                
                if (progressIncrement > 0) {
                    achievement.progress = (achievement.progress + progressIncrement)
                        .coerceAtMost(achievement.maxProgress)
                }
                
                // Check if achievement is completed
                if (achievement.progress >= achievement.maxProgress && !achievement.isUnlocked) {
                    achievement.isUnlocked = true
                    achievement.unlockedDate = Date()
                    
                    // Grant achievement XP
                    val rarity = getAchievementRarity(achievement.id)
                    grantExperience("achievement_unlocked", mapOf("rarity" to rarity.toFloat()))
                    
                    // Report to Google Play Games
                    reportAchievementToPlayGames(achievement.id)
                    
                    // Notify UI
                    ProgressionEventBus.publish(AchievementUnlockedEvent(achievement))
                }
            }
        }
        
        if (hasUpdates) {
            _achievements.value = achievementsList
        }
    }
    
    private fun getAchievementRarity(achievementId: String): Int {
        val rarityMap = mapOf(
            "first_trade" to 1,
            "trade_master" to 2,
            "profit_king" to 3,
            "fleet_builder" to 2,
            "diverse_fleet" to 3,
            "fleet_admiral" to 4,
            "route_planner" to 2,
            "global_network" to 4,
            "market_watcher" to 2,
            "arbitrage_expert" to 3,
            "level_10" to 2,
            "level_25" to 3,
            "level_50" to 5,
            "singularity_survivor" to 5,
            "efficiency_master" to 4,
            "monopolist" to 5
        )
        
        return rarityMap[achievementId] ?: 1
    }
    
    // MARK: - Feature Checking
    
    fun isFeatureUnlocked(feature: String): Boolean {
        return _unlockedFeatures.value?.contains(feature) == true
    }
    
    fun getUnlocksForLevel(level: Int): List<String> {
        return levelRequirements.find { it.level == level }?.unlocks ?: emptyList()
    }
    
    fun getProgressToNextLevel(): ProgressInfo {
        return ProgressInfo(
            currentLevel = _currentLevel.value!!,
            nextLevel = (_currentLevel.value!! + 1).coerceAtMost(MAX_LEVEL),
            currentXP = _currentExperience.value!!,
            requiredXP = _experienceToNextLevel.value!!,
            progress = _levelProgress.value!!
        )
    }
    
    // MARK: - Google Play Games Integration
    
    fun initializePlayGames(
        gamesClient: GamesClient,
        leaderboardsClient: LeaderboardsClient,
        achievementsClient: AchievementsClient
    ) {
        this.gamesClient = gamesClient
        this.leaderboardsClient = leaderboardsClient
        this.achievementsClient = achievementsClient
        this.isPlayGamesAuthenticated = true
        
        syncWithPlayGames()
    }
    
    private fun syncWithPlayGames() {
        scope.launch {
            try {
                // Sync achievements
                achievementsClient?.let { client ->
                    // Load Play Games achievements and sync with local state
                    // This would require implementing the actual Play Games API calls
                }
                
                // Report current scores
                reportScoreToPlayGames(_currentExperience.value!!)
                reportLevelToPlayGames(_currentLevel.value!!)
                
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
    
    private fun reportScoreToPlayGames(score: Int) {
        if (!isPlayGamesAuthenticated) return
        
        scope.launch {
            try {
                leaderboardsClient?.submitScore(LEADERBOARD_TOTAL_EXPERIENCE, score.toLong())
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
    
    private fun reportLevelToPlayGames(level: Int) {
        if (!isPlayGamesAuthenticated) return
        
        scope.launch {
            try {
                leaderboardsClient?.submitScore(LEADERBOARD_PLAYER_LEVEL, level.toLong())
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
    
    private fun reportAchievementToPlayGames(achievementId: String) {
        if (!isPlayGamesAuthenticated) return
        
        scope.launch {
            try {
                achievementsClient?.unlock("CgkI2cT8-NgbEAIQ${achievementId.hashCode()}")
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
    
    // MARK: - Persistence
    
    private fun saveProgressToPrefs() {
        scope.launch(Dispatchers.IO) {
            try {
                prefs.edit().apply {
                    putInt("current_level", _currentLevel.value!!)
                    putInt("current_experience", _currentExperience.value!!)
                    putStringSet("unlocked_features", _unlockedFeatures.value!!)
                    putString("achievements", gson.toJson(achievementsList))
                    putLong("last_updated", System.currentTimeMillis())
                    apply()
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
    
    private fun loadProgressFromPrefs() {
        try {
            val level = prefs.getInt("current_level", 1)
            val experience = prefs.getInt("current_experience", 0)
            val features = prefs.getStringSet("unlocked_features", emptySet()) ?: emptySet()
            val achievementsJson = prefs.getString("achievements", null)
            
            _currentLevel.value = level
            _currentExperience.value = experience
            _unlockedFeatures.value = features
            
            achievementsJson?.let { json ->
                val type = object : TypeToken<List<Achievement>>() {}.type
                val loadedAchievements = gson.fromJson<List<Achievement>>(json, type)
                loadedAchievements?.let { achievements ->
                    achievementsList.clear()
                    achievementsList.addAll(achievements)
                    _achievements.value = achievementsList
                }
            }
            
            // Update experience requirement for current level
            val nextLevel = level + 1
            val levelReq = levelRequirements.find { it.level == nextLevel }
            _experienceToNextLevel.value = levelReq?.experienceRequired ?: 0
            
            updateLevelProgress()
            
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    // MARK: - Cleanup
    
    fun cleanup() {
        scope.cancel()
    }
}