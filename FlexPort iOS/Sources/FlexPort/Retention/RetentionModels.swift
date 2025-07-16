import Foundation

// MARK: - Retention System Models

/// Daily reward system to encourage regular play
public struct DailyReward: Identifiable, Codable {
    public let id = UUID()
    public let day: Int
    public let rewardType: RewardType
    public let name: String
    public let description: String
    public let value: Double
    public let rarity: RewardRarity
    public let requirements: DailyRewardRequirements
    public let isBonus: Bool // 7th day, 30th day bonuses
    
    public init(day: Int, rewardType: RewardType, name: String, description: String,
                value: Double, rarity: RewardRarity = .common,
                requirements: DailyRewardRequirements = DailyRewardRequirements(),
                isBonus: Bool = false) {
        self.day = day
        self.rewardType = rewardType
        self.name = name
        self.description = description
        self.value = value
        self.rarity = rarity
        self.requirements = requirements
        self.isBonus = isBonus
    }
}

public struct DailyRewardRequirements: Codable {
    public var minimumSessionDuration: TimeInterval?
    public var requiredActions: [RequiredAction]
    public var consecutiveDaysRequired: Int
    
    public init(minimumSessionDuration: TimeInterval? = nil,
                requiredActions: [RequiredAction] = [],
                consecutiveDaysRequired: Int = 1) {
        self.minimumSessionDuration = minimumSessionDuration
        self.requiredActions = requiredActions
        self.consecutiveDaysRequired = consecutiveDaysRequired
    }
}

public struct RequiredAction: Codable, Identifiable {
    public let id = UUID()
    public let actionType: ActionType
    public let count: Int
    public let description: String
    
    public init(actionType: ActionType, count: Int, description: String) {
        self.actionType = actionType
        self.count = count
        self.description = description
    }
}

public enum ActionType: String, Codable {
    case completeRoute = "complete_route"
    case earnRevenue = "earn_revenue"
    case visitPort = "visit_port"
    case socialInteraction = "social_interaction"
    case upgradeShip = "upgrade_ship"
    case trainCrew = "train_crew"
}

/// Player's daily reward progress
public struct DailyRewardProgress: Codable {
    public let playerId: UUID
    public var currentStreak: Int
    public var longestStreak: Int
    public var lastClaimDate: Date?
    public var claimedDays: Set<Int> // Days in current cycle
    public var currentCycle: Int // Resets every 7 or 30 days
    public var totalRewardsClaimed: Int
    public var nextRewardAvailable: Date
    
    public init(playerId: UUID) {
        self.playerId = playerId
        self.currentStreak = 0
        self.longestStreak = 0
        self.lastClaimDate = nil
        self.claimedDays = []
        self.currentCycle = 1
        self.totalRewardsClaimed = 0
        self.nextRewardAvailable = Date()
    }
    
    public var canClaimToday: Bool {
        guard let lastClaim = lastClaimDate else { return true }
        return !Calendar.current.isDate(lastClaim, inSameDayAs: Date()) && Date() >= nextRewardAvailable
    }
    
    public var streakWillBreak: Bool {
        guard let lastClaim = lastClaimDate else { return false }
        let daysSinceLastClaim = Calendar.current.dateComponents([.day], from: lastClaim, to: Date()).day ?? 0
        return daysSinceLastClaim > 1
    }
}

/// Achievement system for long-term engagement
public struct Achievement: Identifiable, Codable {
    public let id = UUID()
    public let achievementId: String
    public let name: String
    public let description: String
    public let category: AchievementCategory
    public let difficulty: AchievementDifficulty
    public let requirements: AchievementRequirements
    public let rewards: [EventReward]
    public let isSecret: Bool
    public let prerequisites: [String] // Other achievement IDs
    public var isRepeatable: Bool
    public let iconName: String
    
    public init(achievementId: String, name: String, description: String,
                category: AchievementCategory, difficulty: AchievementDifficulty,
                requirements: AchievementRequirements, rewards: [EventReward] = [],
                isSecret: Bool = false, prerequisites: [String] = [],
                isRepeatable: Bool = false, iconName: String = "achievement_default") {
        self.achievementId = achievementId
        self.name = name
        self.description = description
        self.category = category
        self.difficulty = difficulty
        self.requirements = requirements
        self.rewards = rewards
        self.isSecret = isSecret
        self.prerequisites = prerequisites
        self.isRepeatable = isRepeatable
        self.iconName = iconName
    }
}

public enum AchievementCategory: String, Codable, CaseIterable {
    case trading = "trading"
    case exploration = "exploration"
    case social = "social"
    case efficiency = "efficiency"
    case collection = "collection"
    case progression = "progression"
    case special = "special"
    case seasonal = "seasonal"
    case competitive = "competitive"
    case mastery = "mastery"
}

public enum AchievementDifficulty: String, Codable, CaseIterable {
    case bronze = "bronze"
    case silver = "silver"
    case gold = "gold"
    case platinum = "platinum"
    case diamond = "diamond"
    
    public var scoreMultiplier: Double {
        switch self {
        case .bronze: return 1.0
        case .silver: return 2.0
        case .gold: return 3.0
        case .platinum: return 5.0
        case .diamond: return 10.0
        }
    }
    
    public var displayColor: String {
        switch self {
        case .bronze: return "#CD7F32"
        case .silver: return "#C0C0C0"
        case .gold: return "#FFD700"
        case .platinum: return "#E5E4E2"
        case .diamond: return "#B9F2FF"
        }
    }
}

public struct AchievementRequirements: Codable {
    public var targetValue: Double
    public var measurementType: MeasurementType
    public var timeframe: TimeInterval? // Complete within this time
    public var conditions: [AchievementCondition]
    public var excludeConditions: [AchievementCondition]
    
    public init(targetValue: Double, measurementType: MeasurementType,
                timeframe: TimeInterval? = nil, conditions: [AchievementCondition] = [],
                excludeConditions: [AchievementCondition] = []) {
        self.targetValue = targetValue
        self.measurementType = measurementType
        self.timeframe = timeframe
        self.conditions = conditions
        self.excludeConditions = excludeConditions
    }
}

public enum MeasurementType: String, Codable {
    case total = "total"                    // Cumulative over all time
    case single = "single"                  // In a single session/action
    case consecutive = "consecutive"        // In a row without breaking
    case average = "average"               // Average over a period
    case unique = "unique"                 // Unique items/actions
    case simultaneous = "simultaneous"     // At the same time
}

public struct AchievementCondition: Codable, Identifiable {
    public let id = UUID()
    public let conditionType: ConditionType
    public let operator: ComparisonOperator
    public let value: Double
    public let description: String
    
    public init(conditionType: ConditionType, operator: ComparisonOperator, value: Double, description: String) {
        self.conditionType = conditionType
        self.operator = operator
        self.value = value
        self.description = description
    }
}

public enum ConditionType: String, Codable {
    case playerLevel = "player_level"
    case shipCount = "ship_count"
    case warehouseCount = "warehouse_count"
    case totalRevenue = "total_revenue"
    case sessionDuration = "session_duration"
    case routeDistance = "route_distance"
    case cargoValue = "cargo_value"
    case fuelEfficiency = "fuel_efficiency"
    case weatherCondition = "weather_condition"
    case timeOfDay = "time_of_day"
    case portType = "port_type"
    case shipType = "ship_type"
}

/// Player's achievement progress
public struct AchievementProgress: Codable {
    public let playerId: UUID
    public let achievementId: String
    public var currentValue: Double
    public var isCompleted: Bool
    public var completionDate: Date?
    public var startDate: Date
    public var milestones: [AchievementMilestone]
    public var attempts: Int // For repeatable achievements
    
    public init(playerId: UUID, achievementId: String) {
        self.playerId = playerId
        self.achievementId = achievementId
        self.currentValue = 0.0
        self.isCompleted = false
        self.completionDate = nil
        self.startDate = Date()
        self.milestones = []
        self.attempts = 0
    }
    
    public var progressPercentage: Double {
        // Would calculate based on achievement requirements
        return 0.0
    }
}

public struct AchievementMilestone: Codable, Identifiable {
    public let id = UUID()
    public let threshold: Double
    public let reachedDate: Date?
    public let rewards: [EventReward]
    
    public init(threshold: Double, rewards: [EventReward] = []) {
        self.threshold = threshold
        self.reachedDate = nil
        self.rewards = rewards
    }
}

/// Loyalty program with tiers and benefits
public struct LoyaltyProgram: Codable {
    public let programId: String
    public let name: String
    public let description: String
    public let tiers: [LoyaltyTier]
    public let pointsSystem: PointsSystem
    public let benefits: [LoyaltyBenefit]
    public let validityPeriod: TimeInterval
    
    public init(programId: String, name: String, description: String,
                tiers: [LoyaltyTier], pointsSystem: PointsSystem,
                benefits: [LoyaltyBenefit], validityPeriod: TimeInterval = 365 * 24 * 3600) {
        self.programId = programId
        self.name = name
        self.description = description
        self.tiers = tiers
        self.pointsSystem = pointsSystem
        self.benefits = benefits
        self.validityPeriod = validityPeriod
    }
}

public struct LoyaltyTier: Identifiable, Codable {
    public let id = UUID()
    public let tierName: String
    public let requiredPoints: Int
    public let tierLevel: Int
    public let benefits: [LoyaltyBenefit]
    public let badgeIcon: String
    public let tierColor: String
    
    public init(tierName: String, requiredPoints: Int, tierLevel: Int,
                benefits: [LoyaltyBenefit], badgeIcon: String, tierColor: String) {
        self.tierName = tierName
        self.requiredPoints = requiredPoints
        self.tierLevel = tierLevel
        self.benefits = benefits
        self.badgeIcon = badgeIcon
        self.tierColor = tierColor
    }
}

public struct PointsSystem: Codable {
    public let pointsPerAction: [ActionType: Int]
    public let bonusMultipliers: [BonusCondition: Double]
    public let decayRate: Double? // Points lost over time if inactive
    public let maxPoints: Int?
    
    public init(pointsPerAction: [ActionType: Int], bonusMultipliers: [BonusCondition: Double] = [:],
                decayRate: Double? = nil, maxPoints: Int? = nil) {
        self.pointsPerAction = pointsPerAction
        self.bonusMultipliers = bonusMultipliers
        self.decayRate = decayRate
        self.maxPoints = maxPoints
    }
}

public enum BonusCondition: String, Codable {
    case consecutiveDays = "consecutive_days"
    case perfectEfficiency = "perfect_efficiency"
    case socialPlay = "social_play"
    case challengeCompletion = "challenge_completion"
    case eventParticipation = "event_participation"
}

public struct LoyaltyBenefit: Identifiable, Codable {
    public let id = UUID()
    public let benefitType: BenefitType
    public let name: String
    public let description: String
    public let value: Double
    public let isActive: Bool
    public let duration: BenefitDuration
    
    public init(benefitType: BenefitType, name: String, description: String,
                value: Double, isActive: Bool = true, duration: BenefitDuration = .permanent) {
        self.benefitType = benefitType
        self.name = name
        self.description = description
        self.value = value
        self.isActive = isActive
        self.duration = duration
    }
}

/// Player's loyalty program status
public struct PlayerLoyaltyStatus: Codable {
    public let playerId: UUID
    public let programId: String
    public var currentPoints: Int
    public var totalPointsEarned: Int
    public var currentTier: Int
    public var nextTierPoints: Int
    public var activeBenefits: [LoyaltyBenefit]
    public var joinDate: Date
    public var lastActivityDate: Date
    public var pointsHistory: [PointsTransaction]
    
    public init(playerId: UUID, programId: String) {
        self.playerId = playerId
        self.programId = programId
        self.currentPoints = 0
        self.totalPointsEarned = 0
        self.currentTier = 0
        self.nextTierPoints = 1000 // Would be calculated from tier requirements
        self.activeBenefits = []
        self.joinDate = Date()
        self.lastActivityDate = Date()
        self.pointsHistory = []
    }
    
    public var progressToNextTier: Double {
        guard nextTierPoints > 0 else { return 1.0 }
        return Double(currentPoints) / Double(nextTierPoints)
    }
}

public struct PointsTransaction: Identifiable, Codable {
    public let id = UUID()
    public let points: Int
    public let transactionType: TransactionType
    public let reason: String
    public let date: Date
    public let relatedAction: ActionType?
    
    public init(points: Int, transactionType: TransactionType, reason: String, relatedAction: ActionType? = nil) {
        self.points = points
        self.transactionType = transactionType
        self.reason = reason
        self.date = Date()
        self.relatedAction = relatedAction
    }
}

public enum TransactionType: String, Codable {
    case earned = "earned"
    case bonus = "bonus"
    case spent = "spent"
    case expired = "expired"
    case refunded = "refunded"
}

/// Milestone system for long-term goals
public struct MilestoneSystem: Codable {
    public let systemId: String
    public let name: String
    public let description: String
    public let milestones: [PlayerMilestone]
    public let trackingPeriod: TrackingPeriod
    public let resetBehavior: ResetBehavior
    
    public init(systemId: String, name: String, description: String,
                milestones: [PlayerMilestone], trackingPeriod: TrackingPeriod,
                resetBehavior: ResetBehavior = .never) {
        self.systemId = systemId
        self.name = name
        self.description = description
        self.milestones = milestones
        self.trackingPeriod = trackingPeriod
        self.resetBehavior = resetBehavior
    }
}

public struct PlayerMilestone: Identifiable, Codable {
    public let id = UUID()
    public let name: String
    public let description: String
    public let targetValue: Double
    public let metricType: MilestoneMetric
    public let rewards: [EventReward]
    public let order: Int
    public let isSecret: Bool
    public let iconName: String
    
    public init(name: String, description: String, targetValue: Double,
                metricType: MilestoneMetric, rewards: [EventReward] = [],
                order: Int, isSecret: Bool = false, iconName: String = "milestone_default") {
        self.name = name
        self.description = description
        self.targetValue = targetValue
        self.metricType = metricType
        self.rewards = rewards
        self.order = order
        self.isSecret = isSecret
        self.iconName = iconName
    }
}

public enum MilestoneMetric: String, Codable {
    case totalRevenue = "total_revenue"
    case totalDistance = "total_distance"
    case routesCompleted = "routes_completed"
    case portsVisited = "ports_visited"
    case shipmentsDelivered = "shipments_delivered"
    case playTime = "play_time"
    case loginDays = "login_days"
    case socialInteractions = "social_interactions"
    case achievementsUnlocked = "achievements_unlocked"
    case eventsParticipated = "events_participated"
}

public enum TrackingPeriod: String, Codable {
    case allTime = "all_time"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case seasonal = "seasonal"
    case yearly = "yearly"
}

public enum ResetBehavior: String, Codable {
    case never = "never"
    case onCompletion = "on_completion"
    case periodic = "periodic"
    case onNewSeason = "on_new_season"
}

/// Player's milestone progress
public struct MilestoneProgress: Codable {
    public let playerId: UUID
    public let systemId: String
    public let milestoneId: UUID
    public var currentValue: Double
    public var isCompleted: Bool
    public var completionDate: Date?
    public var isActive: Bool
    
    public init(playerId: UUID, systemId: String, milestoneId: UUID) {
        self.playerId = playerId
        self.systemId = systemId
        self.milestoneId = milestoneId
        self.currentValue = 0.0
        self.isCompleted = false
        self.completionDate = nil
        self.isActive = true
    }
    
    public func progressPercentage(milestone: PlayerMilestone) -> Double {
        guard milestone.targetValue > 0 else { return 0.0 }
        return min(1.0, currentValue / milestone.targetValue)
    }
}

/// Retention intervention system
public struct RetentionIntervention: Identifiable, Codable {
    public let id = UUID()
    public let interventionType: InterventionType
    public let name: String
    public let description: String
    public let triggerConditions: [InterventionTrigger]
    public let actions: [InterventionAction]
    public let priority: InterventionPriority
    public let cooldownPeriod: TimeInterval
    public let maxTriggers: Int?
    public let isActive: Bool
    
    public init(interventionType: InterventionType, name: String, description: String,
                triggerConditions: [InterventionTrigger], actions: [InterventionAction],
                priority: InterventionPriority = .medium, cooldownPeriod: TimeInterval = 24 * 3600,
                maxTriggers: Int? = nil, isActive: Bool = true) {
        self.interventionType = interventionType
        self.name = name
        self.description = description
        self.triggerConditions = triggerConditions
        self.actions = actions
        self.priority = priority
        self.cooldownPeriod = cooldownPeriod
        self.maxTriggers = maxTriggers
        self.isActive = isActive
    }
}

public enum InterventionType: String, Codable {
    case churnPrevention = "churn_prevention"
    case engagementBoost = "engagement_boost"
    case reactivation = "reactivation"
    case progressAssistance = "progress_assistance"
    case socialEncouragement = "social_encouragement"
    case contentRecommendation = "content_recommendation"
}

public struct InterventionTrigger: Codable, Identifiable {
    public let id = UUID()
    public let triggerType: TriggerType
    public let threshold: Double
    public let timeframe: TimeInterval?
    public let description: String
    
    public init(triggerType: TriggerType, threshold: Double, timeframe: TimeInterval? = nil, description: String) {
        self.triggerType = triggerType
        self.threshold = threshold
        self.timeframe = timeframe
        self.description = description
    }
}

public enum TriggerType: String, Codable {
    case daysSinceLastPlay = "days_since_last_play"
    case sessionDurationDrop = "session_duration_drop"
    case progressStagnation = "progress_stagnation"
    case churnRiskScore = "churn_risk_score"
    case completionRateDecrease = "completion_rate_decrease"
    case socialDisengagement = "social_disengagement"
    case spendingDecrease = "spending_decrease"
    case errorRateIncrease = "error_rate_increase"
}

public struct InterventionAction: Codable, Identifiable {
    public let id = UUID()
    public let actionType: InterventionActionType
    public let content: InterventionContent
    public let timing: ActionTiming
    public let personalization: PersonalizationLevel
    
    public init(actionType: InterventionActionType, content: InterventionContent,
                timing: ActionTiming = .immediate, personalization: PersonalizationLevel = .basic) {
        self.actionType = actionType
        self.content = content
        self.timing = timing
        self.personalization = personalization
    }
}

public enum InterventionActionType: String, Codable {
    case pushNotification = "push_notification"
    case inGameMessage = "in_game_message"
    case emailCampaign = "email_campaign"
    case specialOffer = "special_offer"
    case contentUnlock = "content_unlock"
    case socialInvitation = "social_invitation"
    case tutorialSuggestion = "tutorial_suggestion"
    case progressBooster = "progress_booster"
}

public struct InterventionContent: Codable {
    public let title: String
    public let message: String
    public let callToAction: String?
    public let deepLink: String?
    public let mediaAssets: [String]
    public let localizationKey: String?
    
    public init(title: String, message: String, callToAction: String? = nil,
                deepLink: String? = nil, mediaAssets: [String] = [], localizationKey: String? = nil) {
        self.title = title
        self.message = message
        self.callToAction = callToAction
        self.deepLink = deepLink
        self.mediaAssets = mediaAssets
        self.localizationKey = localizationKey
    }
}

public enum ActionTiming: String, Codable {
    case immediate = "immediate"
    case nextSession = "next_session"
    case delayed = "delayed"
    case optimal = "optimal" // ML-determined best time
}

public enum PersonalizationLevel: String, Codable {
    case none = "none"
    case basic = "basic"       // Player name, level
    case behavioral = "behavioral" // Based on play style
    case advanced = "advanced"     // AI-generated content
}

public enum InterventionPriority: String, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

/// Player intervention history
public struct PlayerInterventionHistory: Codable {
    public let playerId: UUID
    public var triggeredInterventions: [TriggeredIntervention]
    public var responseRates: [UUID: Double] // Intervention ID -> Response rate
    public var effectivenessScores: [UUID: Double] // Intervention ID -> Effectiveness
    
    public init(playerId: UUID) {
        self.playerId = playerId
        self.triggeredInterventions = []
        self.responseRates = [:]
        self.effectivenessScores = [:]
    }
}

public struct TriggeredIntervention: Identifiable, Codable {
    public let id = UUID()
    public let interventionId: UUID
    public let triggerDate: Date
    public let playerResponse: InterventionResponse
    public let responseDate: Date?
    public let effectMeasured: Bool
    public let followUpRequired: Bool
    
    public init(interventionId: UUID, playerResponse: InterventionResponse = .pending) {
        self.interventionId = interventionId
        self.triggerDate = Date()
        self.playerResponse = playerResponse
        self.responseDate = nil
        self.effectMeasured = false
        self.followUpRequired = false
    }
}

public enum InterventionResponse: String, Codable {
    case pending = "pending"
    case opened = "opened"
    case clicked = "clicked"
    case completed = "completed"
    case dismissed = "dismissed"
    case ignored = "ignored"
}