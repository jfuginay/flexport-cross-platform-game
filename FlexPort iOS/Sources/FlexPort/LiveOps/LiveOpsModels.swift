import Foundation

// MARK: - Live Operations Models

/// Live event that provides time-limited content and challenges
public struct LiveEvent: Identifiable, Codable {
    public let id = UUID()
    public let eventId: String
    public let name: String
    public let description: String
    public let eventType: EventType
    public let theme: EventTheme
    public let startDate: Date
    public let endDate: Date
    public let configuration: EventConfiguration
    public let rewards: [EventReward]
    public let challenges: [EventChallenge]
    public let leaderboard: EventLeaderboard?
    public let targetAudience: EventAudience
    public var status: EventStatus
    public var participation: EventParticipation
    
    public init(eventId: String, name: String, description: String, eventType: EventType,
                theme: EventTheme, startDate: Date, endDate: Date,
                configuration: EventConfiguration = EventConfiguration(),
                rewards: [EventReward] = [], challenges: [EventChallenge] = [],
                leaderboard: EventLeaderboard? = nil,
                targetAudience: EventAudience = EventAudience()) {
        self.eventId = eventId
        self.name = name
        self.description = description
        self.eventType = eventType
        self.theme = theme
        self.startDate = startDate
        self.endDate = endDate
        self.configuration = configuration
        self.rewards = rewards
        self.challenges = challenges
        self.leaderboard = leaderboard
        self.targetAudience = targetAudience
        self.status = .scheduled
        self.participation = EventParticipation()
    }
    
    public var isActive: Bool {
        let now = Date()
        return status == .active && now >= startDate && now <= endDate
    }
    
    public var timeRemaining: TimeInterval {
        max(0, endDate.timeIntervalSinceNow)
    }
    
    public var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
}

/// Types of live events
public enum EventType: String, Codable, CaseIterable {
    case seasonal = "seasonal"
    case holiday = "holiday"
    case competition = "competition"
    case communityGoal = "community_goal"
    case flashSale = "flash_sale"
    case specialChallenge = "special_challenge"
    case historicalCommemoration = "historical_commemoration"
    case anniversaryCelebration = "anniversary_celebration"
    case playerMilestone = "player_milestone"
    case newFeatureLaunch = "new_feature_launch"
}

/// Visual and thematic styling for events
public enum EventTheme: String, Codable, CaseIterable {
    case maritime = "maritime"
    case historical = "historical"
    case seasonal = "seasonal"
    case futuristic = "futuristic"
    case celebration = "celebration"
    case challenge = "challenge"
    case exploration = "exploration"
    case trading = "trading"
    case collaboration = "collaboration"
    case innovation = "innovation"
    
    public var primaryColor: String {
        switch self {
        case .maritime: return "#0066CC"
        case .historical: return "#8B4513"
        case .seasonal: return "#228B22"
        case .futuristic: return "#9400D3"
        case .celebration: return "#FFD700"
        case .challenge: return "#DC143C"
        case .exploration: return "#FF8C00"
        case .trading: return "#32CD32"
        case .collaboration: return "#4169E1"
        case .innovation: return "#FF1493"
        }
    }
}

/// Event status during its lifecycle
public enum EventStatus: String, Codable {
    case scheduled = "scheduled"
    case preEvent = "pre_event"     // Announcement phase
    case active = "active"
    case paused = "paused"
    case ending = "ending"          // Final hours
    case completed = "completed"
    case cancelled = "cancelled"
}

/// Configuration parameters for event behavior
public struct EventConfiguration: Codable {
    public var allowLateJoin: Bool
    public var autoEnroll: Bool
    public var requiresProgress: Bool
    public var maxParticipants: Int?
    public var minParticipants: Int
    public var gracePeriod: TimeInterval
    public var notificationSettings: EventNotificationSettings
    public var difficultyScaling: DifficultyScaling
    public var rewardMultipliers: RewardMultipliers
    
    public init(allowLateJoin: Bool = true,
                autoEnroll: Bool = false,
                requiresProgress: Bool = false,
                maxParticipants: Int? = nil,
                minParticipants: Int = 1,
                gracePeriod: TimeInterval = 3600, // 1 hour
                notificationSettings: EventNotificationSettings = EventNotificationSettings(),
                difficultyScaling: DifficultyScaling = DifficultyScaling(),
                rewardMultipliers: RewardMultipliers = RewardMultipliers()) {
        self.allowLateJoin = allowLateJoin
        self.autoEnroll = autoEnroll
        self.requiresProgress = requiresProgress
        self.maxParticipants = maxParticipants
        self.minParticipants = minParticipants
        self.gracePeriod = gracePeriod
        self.notificationSettings = notificationSettings
        self.difficultyScaling = difficultyScaling
        self.rewardMultipliers = rewardMultipliers
    }
}

public struct EventNotificationSettings: Codable {
    public var announceStart: Bool
    public var announceEnd: Bool
    public var remindBeforeEnd: Bool
    public var reminderHours: [Int] // Hours before end to send reminders
    public var milestoneNotifications: Bool
    
    public init(announceStart: Bool = true,
                announceEnd: Bool = true,
                remindBeforeEnd: Bool = true,
                reminderHours: [Int] = [24, 6, 1],
                milestoneNotifications: Bool = true) {
        self.announceStart = announceStart
        self.announceEnd = announceEnd
        self.remindBeforeEnd = remindBeforeEnd
        self.reminderHours = reminderHours
        self.milestoneNotifications = milestoneNotifications
    }
}

public struct DifficultyScaling: Codable {
    public var enabled: Bool
    public var basedOnPlayerLevel: Bool
    public var basedOnParticipation: Bool
    public var scalingFactor: Double
    
    public init(enabled: Bool = false,
                basedOnPlayerLevel: Bool = true,
                basedOnParticipation: Bool = false,
                scalingFactor: Double = 1.0) {
        self.enabled = enabled
        self.basedOnPlayerLevel = basedOnPlayerLevel
        self.basedOnParticipation = basedOnParticipation
        self.scalingFactor = scalingFactor
    }
}

public struct RewardMultipliers: Codable {
    public var earlyParticipation: Double
    public var perfectCompletion: Double
    public var communityBonus: Double
    public var streakBonus: Double
    
    public init(earlyParticipation: Double = 1.1,
                perfectCompletion: Double = 1.25,
                communityBonus: Double = 1.15,
                streakBonus: Double = 1.2) {
        self.earlyParticipation = earlyParticipation
        self.perfectCompletion = perfectCompletion
        self.communityBonus = communityBonus
        self.streakBonus = streakBonus
    }
}

/// Target audience criteria for events
public struct EventAudience: Codable {
    public var allPlayers: Bool
    public var minLevel: Int?
    public var maxLevel: Int?
    public var playerSegments: [String]
    public var geoTargeting: [String] // Country codes
    public var excludedUsers: Set<UUID>
    
    public init(allPlayers: Bool = true,
                minLevel: Int? = nil,
                maxLevel: Int? = nil,
                playerSegments: [String] = [],
                geoTargeting: [String] = [],
                excludedUsers: Set<UUID> = []) {
        self.allPlayers = allPlayers
        self.minLevel = minLevel
        self.maxLevel = maxLevel
        self.playerSegments = playerSegments
        self.geoTargeting = geoTargeting
        self.excludedUsers = excludedUsers
    }
    
    public func isEligible(playerLevel: Int, playerSegment: String, countryCode: String, playerId: UUID) -> Bool {
        if excludedUsers.contains(playerId) { return false }
        
        if !allPlayers {
            if let minLevel = minLevel, playerLevel < minLevel { return false }
            if let maxLevel = maxLevel, playerLevel > maxLevel { return false }
            
            if !playerSegments.isEmpty && !playerSegments.contains(playerSegment) { return false }
            if !geoTargeting.isEmpty && !geoTargeting.contains(countryCode) { return false }
        }
        
        return true
    }
}

/// Rewards that can be earned from events
public struct EventReward: Identifiable, Codable {
    public let id = UUID()
    public let rewardType: RewardType
    public let name: String
    public let description: String
    public let value: Double
    public let rarity: RewardRarity
    public let requirements: RewardRequirements
    public let isExclusive: Bool
    public let expirationDate: Date?
    
    public init(rewardType: RewardType, name: String, description: String, value: Double,
                rarity: RewardRarity = .common, requirements: RewardRequirements = RewardRequirements(),
                isExclusive: Bool = false, expirationDate: Date? = nil) {
        self.rewardType = rewardType
        self.name = name
        self.description = description
        self.value = value
        self.rarity = rarity
        self.requirements = requirements
        self.isExclusive = isExclusive
        self.expirationDate = expirationDate
    }
}

public enum RewardType: String, Codable, CaseIterable {
    case currency = "currency"
    case cosmetic = "cosmetic"
    case booster = "booster"
    case title = "title"
    case badge = "badge"
    case ship = "ship"
    case warehouse = "warehouse"
    case experience = "experience"
    case premiumTime = "premium_time"
    case specialAccess = "special_access"
    case commemorative = "commemorative"
}

public enum RewardRarity: String, Codable, CaseIterable {
    case common = "common"
    case uncommon = "uncommon"
    case rare = "rare"
    case epic = "epic"
    case legendary = "legendary"
    case mythic = "mythic"
    
    public var multiplier: Double {
        switch self {
        case .common: return 1.0
        case .uncommon: return 1.2
        case .rare: return 1.5
        case .epic: return 2.0
        case .legendary: return 3.0
        case .mythic: return 5.0
        }
    }
}

public struct RewardRequirements: Codable {
    public var minimumScore: Double?
    public var minimumRank: Int?
    public var completionPercentage: Double?
    public var participationDays: Int?
    public var specificChallenges: [UUID]
    
    public init(minimumScore: Double? = nil,
                minimumRank: Int? = nil,
                completionPercentage: Double? = nil,
                participationDays: Int? = nil,
                specificChallenges: [UUID] = []) {
        self.minimumScore = minimumScore
        self.minimumRank = minimumRank
        self.completionPercentage = completionPercentage
        self.participationDays = participationDays
        self.specificChallenges = specificChallenges
    }
}

/// Individual challenges within an event
public struct EventChallenge: Identifiable, Codable {
    public let id = UUID()
    public let name: String
    public let description: String
    public let challengeType: ChallengeType
    public let target: ChallengeTarget
    public let difficulty: ChallengeDifficulty
    public let rewards: [EventReward]
    public let prerequisites: [UUID] // Other challenge IDs
    public let timeLimit: TimeInterval?
    public var isActive: Bool
    public var completionCount: Int
    
    public init(name: String, description: String, challengeType: ChallengeType,
                target: ChallengeTarget, difficulty: ChallengeDifficulty = .normal,
                rewards: [EventReward] = [], prerequisites: [UUID] = [],
                timeLimit: TimeInterval? = nil) {
        self.name = name
        self.description = description
        self.challengeType = challengeType
        self.target = target
        self.difficulty = difficulty
        self.rewards = rewards
        self.prerequisites = prerequisites
        self.timeLimit = timeLimit
        self.isActive = true
        self.completionCount = 0
    }
}

public enum ChallengeType: String, Codable, CaseIterable {
    case delivery = "delivery"
    case earnings = "earnings"
    case exploration = "exploration"
    case efficiency = "efficiency"
    case social = "social"
    case collection = "collection"
    case speed = "speed"
    case endurance = "endurance"
    case precision = "precision"
    case innovation = "innovation"
}

public struct ChallengeTarget: Codable {
    public let targetType: TargetType
    public let targetValue: Double
    public let timeframe: TimeInterval?
    public let conditions: [String: String]
    
    public init(targetType: TargetType, targetValue: Double, timeframe: TimeInterval? = nil, conditions: [String: String] = [:]) {
        self.targetType = targetType
        self.targetValue = targetValue
        self.timeframe = timeframe
        self.conditions = conditions
    }
}

public enum TargetType: String, Codable {
    case deliveriesCompleted = "deliveries_completed"
    case revenueGenerated = "revenue_generated"
    case routesCreated = "routes_created"
    case portsVisited = "ports_visited"
    case playersInteracted = "players_interacted"
    case itemsCollected = "items_collected"
    case timeSpent = "time_spent"
    case efficiencyRating = "efficiency_rating"
    case distance = "distance"
    case fuelSaved = "fuel_saved"
}

public enum ChallengeDifficulty: String, Codable, CaseIterable {
    case easy = "easy"
    case normal = "normal"
    case hard = "hard"
    case expert = "expert"
    case legendary = "legendary"
    
    public var scoreMultiplier: Double {
        switch self {
        case .easy: return 0.8
        case .normal: return 1.0
        case .hard: return 1.5
        case .expert: return 2.0
        case .legendary: return 3.0
        }
    }
}

/// Leaderboard for competitive events
public struct EventLeaderboard: Codable {
    public let leaderboardType: LeaderboardType
    public let scoringMethod: ScoringMethod
    public let updateFrequency: UpdateFrequency
    public let maxEntries: Int
    public let tierRewards: [LeaderboardTier: [EventReward]]
    public var entries: [LeaderboardEntry]
    
    public init(leaderboardType: LeaderboardType = .global,
                scoringMethod: ScoringMethod = .cumulative,
                updateFrequency: UpdateFrequency = .realTime,
                maxEntries: Int = 1000,
                tierRewards: [LeaderboardTier: [EventReward]] = [:]) {
        self.leaderboardType = leaderboardType
        self.scoringMethod = scoringMethod
        self.updateFrequency = updateFrequency
        self.maxEntries = maxEntries
        self.tierRewards = tierRewards
        self.entries = []
    }
}

public enum LeaderboardType: String, Codable {
    case global = "global"
    case regional = "regional"
    case alliance = "alliance"
    case friends = "friends"
}

public enum ScoringMethod: String, Codable {
    case cumulative = "cumulative"
    case highest = "highest"
    case average = "average"
    case efficiency = "efficiency"
    case timeToComplete = "time_to_complete"
}

public enum UpdateFrequency: String, Codable {
    case realTime = "real_time"
    case hourly = "hourly"
    case daily = "daily"
    case endOfEvent = "end_of_event"
}

public enum LeaderboardTier: String, Codable, CaseIterable {
    case top1 = "top_1"
    case top3 = "top_3"
    case top10 = "top_10"
    case top50 = "top_50"
    case top100 = "top_100"
    case top25Percent = "top_25_percent"
    case top50Percent = "top_50_percent"
    case participation = "participation"
}

public struct LeaderboardEntry: Identifiable, Codable {
    public let id = UUID()
    public let playerId: UUID
    public let playerName: String
    public let score: Double
    public let rank: Int
    public let lastUpdated: Date
    public let region: String?
    public let allianceId: UUID?
    
    public init(playerId: UUID, playerName: String, score: Double, rank: Int, region: String? = nil, allianceId: UUID? = nil) {
        self.playerId = playerId
        self.playerName = playerName
        self.score = score
        self.rank = rank
        self.lastUpdated = Date()
        self.region = region
        self.allianceId = allianceId
    }
}

/// Participation tracking for events
public struct EventParticipation: Codable {
    public var totalParticipants: Int
    public var activeParticipants: Int
    public var completedParticipants: Int
    public var participantsByRegion: [String: Int]
    public var participantsByLevel: [Int: Int]
    public var averageCompletionRate: Double
    public var peakConcurrency: Int
    public var dailyActiveUsers: [String: Int] // Date -> DAU count
    
    public init() {
        self.totalParticipants = 0
        self.activeParticipants = 0
        self.completedParticipants = 0
        self.participantsByRegion = [:]
        self.participantsByLevel = [:]
        self.averageCompletionRate = 0.0
        self.peakConcurrency = 0
        self.dailyActiveUsers = [:]
    }
    
    public var completionRate: Double {
        guard totalParticipants > 0 else { return 0.0 }
        return Double(completedParticipants) / Double(totalParticipants)
    }
}

/// Player's individual participation in an event
public struct PlayerEventParticipation: Identifiable, Codable {
    public let id = UUID()
    public let playerId: UUID
    public let eventId: String
    public let joinDate: Date
    public var currentScore: Double
    public var challengesCompleted: Set<UUID>
    public var rewardsEarned: [EventReward]
    public var currentRank: Int?
    public var isActive: Bool
    public var lastActivityDate: Date
    public var completionPercentage: Double
    public var streakDays: Int
    
    public init(playerId: UUID, eventId: String) {
        self.playerId = playerId
        self.eventId = eventId
        self.joinDate = Date()
        self.currentScore = 0.0
        self.challengesCompleted = []
        self.rewardsEarned = []
        self.currentRank = nil
        self.isActive = true
        self.lastActivityDate = Date()
        self.completionPercentage = 0.0
        self.streakDays = 1
    }
    
    public mutating func updateActivity() {
        lastActivityDate = Date()
    }
    
    public mutating func completeChallenge(_ challengeId: UUID, score: Double, rewards: [EventReward]) {
        challengesCompleted.insert(challengeId)
        currentScore += score
        rewardsEarned.append(contentsOf: rewards)
        updateActivity()
    }
}

/// Seasonal content that changes based on real-world calendar
public struct SeasonalContent: Identifiable, Codable {
    public let id = UUID()
    public let season: Season
    public let year: Int
    public let theme: EventTheme
    public let assets: SeasonalAssets
    public let events: [LiveEvent]
    public let specialOffers: [SeasonalOffer]
    public let environmentalChanges: EnvironmentalChanges
    public let duration: DateInterval
    
    public init(season: Season, year: Int, theme: EventTheme, assets: SeasonalAssets,
                events: [LiveEvent] = [], specialOffers: [SeasonalOffer] = [],
                environmentalChanges: EnvironmentalChanges = EnvironmentalChanges()) {
        self.season = season
        self.year = year
        self.theme = theme
        self.assets = assets
        self.events = events
        self.specialOffers = specialOffers
        self.environmentalChanges = environmentalChanges
        self.duration = season.dateInterval(for: year)
    }
    
    public var isActive: Bool {
        duration.contains(Date())
    }
}

public enum Season: String, Codable, CaseIterable {
    case spring = "spring"
    case summer = "summer"
    case autumn = "autumn"
    case winter = "winter"
    
    public func dateInterval(for year: Int) -> DateInterval {
        let calendar = Calendar.current
        var components = DateComponents(year: year)
        
        switch self {
        case .spring:
            components.month = 3
            components.day = 20
        case .summer:
            components.month = 6
            components.day = 21
        case .autumn:
            components.month = 9
            components.day = 22
        case .winter:
            components.month = 12
            components.day = 21
        }
        
        let startDate = calendar.date(from: components)!
        let endDate = calendar.date(byAdding: .month, value: 3, to: startDate)!
        
        return DateInterval(start: startDate, end: endDate)
    }
}

public struct SeasonalAssets: Codable {
    public let backgroundImages: [String]
    public let musicTracks: [String]
    public let uiElements: [String]
    public let particleEffects: [String]
    public let iconOverrides: [String: String] // Original icon -> Seasonal icon
    
    public init(backgroundImages: [String] = [], musicTracks: [String] = [],
                uiElements: [String] = [], particleEffects: [String] = [],
                iconOverrides: [String: String] = [:]) {
        self.backgroundImages = backgroundImages
        self.musicTracks = musicTracks
        self.uiElements = uiElements
        self.particleEffects = particleEffects
        self.iconOverrides = iconOverrides
    }
}

public struct SeasonalOffer: Identifiable, Codable {
    public let id = UUID()
    public let name: String
    public let description: String
    public let items: [String] // Item IDs
    public let originalPrice: Double
    public let discountedPrice: Double
    public let availabilityPeriod: DateInterval
    public let purchaseLimit: Int?
    
    public init(name: String, description: String, items: [String], originalPrice: Double,
                discountedPrice: Double, availabilityPeriod: DateInterval, purchaseLimit: Int? = nil) {
        self.name = name
        self.description = description
        self.items = items
        self.originalPrice = originalPrice
        self.discountedPrice = discountedPrice
        self.availabilityPeriod = availabilityPeriod
        self.purchaseLimit = purchaseLimit
    }
    
    public var discountPercentage: Double {
        guard originalPrice > 0 else { return 0 }
        return ((originalPrice - discountedPrice) / originalPrice) * 100
    }
    
    public var isAvailable: Bool {
        availabilityPeriod.contains(Date())
    }
}

public struct EnvironmentalChanges: Codable {
    public let weatherPatterns: [String: Double] // Weather type -> Frequency modifier
    public let visualFilters: [String] // Visual effect names
    public let ambientSounds: [String]
    public let gameplayModifiers: [String: Double] // Modifier type -> Value
    
    public init(weatherPatterns: [String: Double] = [:], visualFilters: [String] = [],
                ambientSounds: [String] = [], gameplayModifiers: [String: Double] = [:]) {
        self.weatherPatterns = weatherPatterns
        self.visualFilters = visualFilters
        self.ambientSounds = ambientSounds
        self.gameplayModifiers = gameplayModifiers
    }
}