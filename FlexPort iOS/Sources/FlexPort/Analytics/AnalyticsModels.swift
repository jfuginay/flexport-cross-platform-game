import Foundation
import CoreData

// MARK: - Analytics Data Models

/// Core analytics event model with privacy-first design
public struct AnalyticsEvent: Codable, Identifiable {
    public let id = UUID()
    public let eventType: EventType
    public let timestamp: Date
    public let sessionId: UUID
    public let parameters: [String: AnalyticsValue]
    public let gameState: GameStateSnapshot?
    
    public init(eventType: EventType, parameters: [String: AnalyticsValue] = [:], gameState: GameStateSnapshot? = nil, sessionId: UUID) {
        self.eventType = eventType
        self.timestamp = Date()
        self.sessionId = sessionId
        self.parameters = parameters
        self.gameState = gameState
    }
}

/// Event types for comprehensive game analytics
public enum EventType: String, Codable, CaseIterable {
    // Session events
    case sessionStart = "session_start"
    case sessionEnd = "session_end"
    case sessionPause = "session_pause"
    case sessionResume = "session_resume"
    
    // Gameplay events
    case gameStart = "game_start"
    case gameEnd = "game_end"
    case levelUp = "level_up"
    case tutorialStep = "tutorial_step"
    case tutorialComplete = "tutorial_complete"
    case achievementUnlocked = "achievement_unlocked"
    
    // Economic events
    case tradeRouteCreated = "trade_route_created"
    case tradeRouteCompleted = "trade_route_completed"
    case shipPurchased = "ship_purchased"
    case warehousePurchased = "warehouse_purchased"
    case commodityTraded = "commodity_traded"
    case profitGenerated = "profit_generated"
    case lossIncurred = "loss_incurred"
    
    // Player behavior events
    case screenViewed = "screen_viewed"
    case featureUsed = "feature_used"
    case settingChanged = "setting_changed"
    case helpAccessed = "help_accessed"
    case errorEncountered = "error_encountered"
    
    // Social events
    case allianceJoined = "alliance_joined"
    case allianceLeft = "alliance_left"
    case playerInteraction = "player_interaction"
    case leaderboardViewed = "leaderboard_viewed"
    
    // Monetization events (ethical tracking)
    case storeViewed = "store_viewed"
    case itemConsidered = "item_considered"
    case purchaseInitiated = "purchase_initiated"
    case purchaseCompleted = "purchase_completed"
    case purchaseCancelled = "purchase_cancelled"
    
    // Performance events
    case performanceIssue = "performance_issue"
    case crashOccurred = "crash_occurred"
    case networkIssue = "network_issue"
    
    // A/B testing events
    case experimentViewed = "experiment_viewed"
    case experimentInteraction = "experiment_interaction"
    
    // Retention events
    case dailyRewardClaimed = "daily_reward_claimed"
    case notificationReceived = "notification_received"
    case deepLinkOpened = "deep_link_opened"
}

/// Type-safe analytics value wrapper
public enum AnalyticsValue: Codable, Equatable {
    case string(String)
    case integer(Int)
    case double(Double)
    case boolean(Bool)
    case array([AnalyticsValue])
    case dictionary([String: AnalyticsValue])
    
    public var rawValue: Any {
        switch self {
        case .string(let value): return value
        case .integer(let value): return value
        case .double(let value): return value
        case .boolean(let value): return value
        case .array(let values): return values.map { $0.rawValue }
        case .dictionary(let dict): return dict.mapValues { $0.rawValue }
        }
    }
}

/// Snapshot of game state for contextual analytics
public struct GameStateSnapshot: Codable {
    public let playerLevel: Int
    public let totalShips: Int
    public let totalWarehouses: Int
    public let currentCash: Double
    public let activeRoutes: Int
    public let gameTime: TimeInterval
    public let currentScreen: String
    public let tutorialProgress: Double
    public let hasCompletedTutorial: Bool
    public let achievementsUnlocked: Int
    public let totalPlayTime: TimeInterval
    
    public init(playerLevel: Int, totalShips: Int, totalWarehouses: Int, currentCash: Double,
                activeRoutes: Int, gameTime: TimeInterval, currentScreen: String,
                tutorialProgress: Double, hasCompletedTutorial: Bool, achievementsUnlocked: Int,
                totalPlayTime: TimeInterval) {
        self.playerLevel = playerLevel
        self.totalShips = totalShips
        self.totalWarehouses = totalWarehouses
        self.currentCash = currentCash
        self.activeRoutes = activeRoutes
        self.gameTime = gameTime
        self.currentScreen = currentScreen
        self.tutorialProgress = tutorialProgress
        self.hasCompletedTutorial = hasCompletedTutorial
        self.achievementsUnlocked = achievementsUnlocked
        self.totalPlayTime = totalPlayTime
    }
}

/// Player session model for comprehensive session tracking
public struct PlayerSession: Codable, Identifiable {
    public let id = UUID()
    public let userId: UUID?
    public let startTime: Date
    public var endTime: Date?
    public var duration: TimeInterval { endTime?.timeIntervalSince(startTime) ?? Date().timeIntervalSince(startTime) }
    public var events: [AnalyticsEvent] = []
    public let appVersion: String
    public let deviceInfo: DeviceInfo
    public var crashOccurred: Bool = false
    public var backgroundTime: TimeInterval = 0
    public let gameStateAtStart: GameStateSnapshot?
    public var gameStateAtEnd: GameStateSnapshot?
    
    public init(userId: UUID? = nil, appVersion: String, deviceInfo: DeviceInfo, gameStateAtStart: GameStateSnapshot? = nil) {
        self.userId = userId
        self.startTime = Date()
        self.appVersion = appVersion
        self.deviceInfo = deviceInfo
        self.gameStateAtStart = gameStateAtStart
    }
    
    public mutating func endSession(gameState: GameStateSnapshot? = nil) {
        self.endTime = Date()
        self.gameStateAtEnd = gameState
    }
}

/// Device information for analytics context
public struct DeviceInfo: Codable {
    public let deviceModel: String
    public let osVersion: String
    public let screenSize: String
    public let memoryGB: Double
    public let storageGB: Double
    public let batteryLevel: Double?
    public let networkType: String
    public let timezone: String
    public let locale: String
    
    public init(deviceModel: String, osVersion: String, screenSize: String, memoryGB: Double,
                storageGB: Double, batteryLevel: Double?, networkType: String, timezone: String, locale: String) {
        self.deviceModel = deviceModel
        self.osVersion = osVersion
        self.screenSize = screenSize
        self.memoryGB = memoryGB
        self.storageGB = storageGB
        self.batteryLevel = batteryLevel
        self.networkType = networkType
        self.timezone = timezone
        self.locale = locale
    }
}

/// Player behavior pattern analysis model
public struct PlayerBehaviorProfile: Codable {
    public let playerId: UUID
    public var sessionFrequency: SessionFrequency
    public var averageSessionDuration: TimeInterval
    public var preferredPlayTimes: [Int] // Hours of day
    public var gameplayStyle: GameplayStyle
    public var spendingBehavior: SpendingBehavior
    public var socialEngagement: SocialEngagement
    public var progressionRate: ProgressionRate
    public var retentionRisk: RetentionRisk
    public var lastActive: Date
    public var totalSessions: Int
    public var totalPlayTime: TimeInterval
    
    public init(playerId: UUID) {
        self.playerId = playerId
        self.sessionFrequency = .unknown
        self.averageSessionDuration = 0
        self.preferredPlayTimes = []
        self.gameplayStyle = .unknown
        self.spendingBehavior = .unknown
        self.socialEngagement = .unknown
        self.progressionRate = .unknown
        self.retentionRisk = .low
        self.lastActive = Date()
        self.totalSessions = 0
        self.totalPlayTime = 0
    }
}

public enum SessionFrequency: String, Codable {
    case daily = "daily"
    case frequent = "frequent" // Multiple times per day
    case regular = "regular" // 3-5 times per week
    case occasional = "occasional" // 1-2 times per week
    case rare = "rare" // Less than once per week
    case unknown = "unknown"
}

public enum GameplayStyle: String, Codable {
    case casual = "casual"
    case hardcore = "hardcore"
    case strategic = "strategic"
    case social = "social"
    case competitive = "competitive"
    case explorer = "explorer"
    case economic = "economic"
    case unknown = "unknown"
}

public enum SpendingBehavior: String, Codable {
    case nonSpender = "non_spender"
    case minnow = "minnow" // Small spender ($1-10)
    case dolphin = "dolphin" // Medium spender ($10-100)
    case whale = "whale" // High spender ($100+)
    case unknown = "unknown"
}

public enum SocialEngagement: String, Codable {
    case solo = "solo"
    case casual = "casual"
    case active = "active"
    case leader = "leader"
    case unknown = "unknown"
}

public enum ProgressionRate: String, Codable {
    case slow = "slow"
    case normal = "normal"
    case fast = "fast"
    case expert = "expert"
    case unknown = "unknown"
}

public enum RetentionRisk: String, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

/// Cohort analysis model for player retention tracking
public struct PlayerCohort: Codable, Identifiable {
    public let id = UUID()
    public let cohortDate: Date
    public let cohortName: String
    public var playerIds: Set<UUID>
    public var retentionData: [Int: Double] // Day -> Retention Rate
    public var revenueData: [Int: Double] // Day -> Revenue per User
    public var engagementData: [Int: Double] // Day -> Average Session Duration
    public let acquisitionChannel: String?
    
    public init(cohortDate: Date, cohortName: String, acquisitionChannel: String? = nil) {
        self.cohortDate = cohortDate
        self.cohortName = cohortName
        self.playerIds = []
        self.retentionData = [:]
        self.revenueData = [:]
        self.engagementData = [:]
        self.acquisitionChannel = acquisitionChannel
    }
    
    public var size: Int {
        playerIds.count
    }
    
    public func retentionRate(day: Int) -> Double {
        retentionData[day] ?? 0.0
    }
    
    public func ltv(day: Int) -> Double {
        revenueData[day] ?? 0.0
    }
}

/// Funnel analysis for understanding player drop-off points
public struct FunnelStep: Codable, Identifiable {
    public let id = UUID()
    public let stepName: String
    public let stepOrder: Int
    public var completions: Int = 0
    public var dropOffs: Int = 0
    public let eventType: EventType
    public let requiredParameters: [String]
    
    public init(stepName: String, stepOrder: Int, eventType: EventType, requiredParameters: [String] = []) {
        self.stepName = stepName
        self.stepOrder = stepOrder
        self.eventType = eventType
        self.requiredParameters = requiredParameters
    }
    
    public var conversionRate: Double {
        let total = completions + dropOffs
        guard total > 0 else { return 0 }
        return Double(completions) / Double(total)
    }
}

public struct AnalyticsFunnel: Codable, Identifiable {
    public let id = UUID()
    public let funnelName: String
    public let description: String
    public var steps: [FunnelStep]
    public let timeframe: TimeInterval
    
    public init(funnelName: String, description: String, steps: [FunnelStep], timeframe: TimeInterval) {
        self.funnelName = funnelName
        self.description = description
        self.steps = steps.sorted { $0.stepOrder < $1.stepOrder }
        self.timeframe = timeframe
    }
    
    public var overallConversionRate: Double {
        guard !steps.isEmpty else { return 0 }
        return steps.map { $0.conversionRate }.reduce(1.0, *)
    }
}