package com.flexport.game.progression

import java.util.*

/**
 * Data models for the Android progression system
 */

data class LevelRequirement(
    val level: Int,
    val experienceRequired: Int,
    val unlocks: List<String>,
    val rewards: LevelReward?
)

data class LevelReward(
    var cash: Int? = null,
    var researchPoints: Int? = null,
    var shipSlots: Int? = null,
    var routeSlots: Int? = null
)

data class ExperienceReward(
    val action: String,
    val baseXP: Int,
    val multipliers: Map<String, Float>? = null
)

data class Achievement(
    val id: String,
    val name: String,
    val description: String,
    var progress: Float = 0f,
    val maxProgress: Float,
    var isUnlocked: Boolean = false,
    var unlockedDate: Date? = null
) {
    val progressPercentage: Float
        get() = if (maxProgress > 0) (progress / maxProgress * 100).coerceIn(0f, 100f) else 0f
    
    val isComplete: Boolean
        get() = progress >= maxProgress
}

data class ProgressInfo(
    val currentLevel: Int,
    val nextLevel: Int,
    val currentXP: Int,
    val requiredXP: Int,
    val progress: Float
)

// Event models for the progression system
sealed class ProgressionEvent

data class LevelUpEvent(
    val newLevel: Int,
    val rewards: List<String>
) : ProgressionEvent()

data class FeatureUnlockedEvent(
    val feature: String
) : ProgressionEvent()

data class AchievementUnlockedEvent(
    val achievement: Achievement
) : ProgressionEvent()

data class RewardEvent(
    val type: String,
    val amount: Int
) : ProgressionEvent()

data class ExperienceGainedEvent(
    val action: String,
    val xpGained: Int,
    val totalXP: Int
) : ProgressionEvent()