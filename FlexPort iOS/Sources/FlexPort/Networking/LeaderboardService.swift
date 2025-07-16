import Foundation
import Combine

/// Enhanced leaderboard service with advanced filtering and social features
class LeaderboardService: ObservableObject {
    static let shared = LeaderboardService()
    
    @Published private(set) var globalLeaderboard: [LeaderboardEntry] = []
    @Published private(set) var playerRank: Int?
    @Published private(set) var playerStats: PlayerStats?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var socialLeaderboards: [SocialLeaderboard] = []
    @Published private(set) var customFilters: [LeaderboardFilter] = []
    @Published private(set) var followedPlayers: [String] = []
    @Published private(set) var leaderboardNotifications: [LeaderboardNotification] = []
    
    private let apiClient = APIClient.shared
    private let securityManager = SecurityManager.shared
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // Enhanced cache management with filtering
    private var leaderboardCache: [String: (data: LeaderboardResponse, timestamp: Date)] = [:]
    private var filteredLeaderboards: [String: FilteredLeaderboard] = [:]
    private let cacheTimeout: TimeInterval = 300 // 5 minutes
    
    // Social features
    private var friendsManager = FriendsManager()
    private var rivalryTracker = RivalryTracker()
    private var achievementTracker = AchievementTracker()
    
    private init() {
        startPeriodicRefresh()
    }
    
    deinit {
        stopPeriodicRefresh()
    }
    
    /// Load leaderboard data
    func loadLeaderboard(type: LeaderboardType, timeframe: Timeframe, forceRefresh: Bool = false) async {
        let cacheKey = "\(type.rawValue)_\(timeframe.rawValue)"
        
        // Check cache first
        if !forceRefresh,
           let cached = leaderboardCache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < cacheTimeout {
            
            await MainActor.run {
                self.globalLeaderboard = cached.data.entries
                self.playerRank = cached.data.playerRank
            }
            return
        }
        
        await MainActor.run {
            self.isLoading = true
        }
        
        do {
            let response = try await apiClient.getLeaderboard(type: type, timeframe: timeframe)
            
            // Cache the response
            leaderboardCache[cacheKey] = (response, Date())
            
            await MainActor.run {
                self.globalLeaderboard = response.entries
                self.playerRank = response.playerRank
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
            print("Failed to load leaderboard: \(error)")
        }
    }
    
    /// Load player statistics
    func loadPlayerStats(playerId: String? = nil, forceRefresh: Bool = false) async {
        let targetPlayerId = playerId ?? getCurrentPlayerId()
        
        // Check if we need to refresh
        if !forceRefresh,
           let stats = playerStats,
           stats.playerId == targetPlayerId,
           Date().timeIntervalSince(stats.lastUpdated) < cacheTimeout {
            return
        }
        
        await MainActor.run {
            self.isLoading = true
        }
        
        do {
            let stats = try await apiClient.getPlayerStats(playerId: targetPlayerId)
            
            await MainActor.run {
                self.playerStats = stats
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
            print("Failed to load player stats: \(error)")
        }
    }
    
    /// Update player statistics after game completion
    func updatePlayerStats(gameResult: GameResult) async {
        let playerId = getCurrentPlayerId()
        
        let update = PlayerStatsUpdate(
            deltaGamesPlayed: 1,
            deltaGamesWon: gameResult.isWin ? 1 : 0,
            newWealth: gameResult.finalWealth,
            newEfficiency: gameResult.efficiency,
            newSingularityProgress: gameResult.singularityProgress,
            newAchievements: gameResult.newAchievements
        )
        
        do {
            let updatedStats = try await apiClient.updatePlayerStats(playerId: playerId, stats: update)
            
            await MainActor.run {
                self.playerStats = updatedStats
            }
            
            // Refresh leaderboards if player made significant progress
            if gameResult.isWin || gameResult.newAchievements.count > 0 {
                await refreshAllLeaderboards()
            }
            
        } catch {
            print("Failed to update player stats: \(error)")
        }
    }
    
    /// Get player's rank in a specific leaderboard
    func getPlayerRank(for type: LeaderboardType, timeframe: Timeframe) async -> Int? {
        await loadLeaderboard(type: type, timeframe: timeframe)
        return playerRank
    }
    
    /// Get top players around current player's rank
    func getPlayersAroundRank(type: LeaderboardType, timeframe: Timeframe, range: Int = 5) async -> [LeaderboardEntry] {
        await loadLeaderboard(type: type, timeframe: timeframe)
        
        guard let currentRank = playerRank else {
            // Return top players if we don't have player rank
            return Array(globalLeaderboard.prefix(range * 2))
        }
        
        let startIndex = max(0, currentRank - range - 1)
        let endIndex = min(globalLeaderboard.count, currentRank + range)
        
        return Array(globalLeaderboard[startIndex..<endIndex])
    }
    
    /// Compare player with friends or specific players
    func compareWithPlayers(_ playerIds: [String], type: LeaderboardType) async -> [PlayerComparison] {
        var comparisons: [PlayerComparison] = []
        
        // Get current player stats
        await loadPlayerStats()
        guard let currentStats = playerStats else { return [] }
        
        // Get stats for other players
        for playerId in playerIds {
            do {
                let stats = try await apiClient.getPlayerStats(playerId: playerId)
                let comparison = createComparison(current: currentStats, other: stats, type: type)
                comparisons.append(comparison)
            } catch {
                print("Failed to get stats for player \(playerId): \(error)")
            }
        }
        
        return comparisons.sorted { $0.score > $1.score }
    }
    
    private func createComparison(current: PlayerStats, other: PlayerStats, type: LeaderboardType) -> PlayerComparison {
        let currentScore = getScore(from: current, type: type)
        let otherScore = getScore(from: other, type: type)
        
        return PlayerComparison(
            playerId: other.playerId,
            score: otherScore,
            scoreDifference: currentScore - otherScore,
            isAhead: currentScore > otherScore
        )
    }
    
    private func getScore(from stats: PlayerStats, type: LeaderboardType) -> Double {
        switch type {
        case .wealth:
            return stats.totalWealth
        case .efficiency:
            return stats.averageEfficiency
        case .reputation:
            return 0 // Would need reputation from stats
        case .singularityProgress:
            return stats.bestSingularityProgress
        }
    }
    
    /// Start periodic refresh of leaderboards
    private func startPeriodicRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task {
                await self.refreshAllLeaderboards()
            }
        }
    }
    
    private func stopPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    private func refreshAllLeaderboards() async {
        // Refresh the most commonly viewed leaderboards
        let commonLeaderboards: [(LeaderboardType, Timeframe)] = [
            (.wealth, .weekly),
            (.efficiency, .monthly),
            (.singularityProgress, .allTime)
        ]
        
        for (type, timeframe) in commonLeaderboards {
            await loadLeaderboard(type: type, timeframe: timeframe, forceRefresh: true)
        }
        
        // Refresh player stats
        await loadPlayerStats(forceRefresh: true)
    }
    
    /// Clear cached data
    func clearCache() {
        leaderboardCache.removeAll()
        
        DispatchQueue.main.async {
            self.globalLeaderboard = []
            self.playerRank = nil
            self.playerStats = nil
        }
    }
    
    private func getCurrentPlayerId() -> String {
        return UserDefaults.standard.string(forKey: "playerId") ?? "unknown"
    }
}

// MARK: - Supporting Types
struct GameResult {
    let isWin: Bool
    let finalWealth: Double
    let efficiency: Double
    let singularityProgress: Double
    let newAchievements: [String]
    let sessionDuration: TimeInterval
}

struct PlayerComparison {
    let playerId: String
    let score: Double
    let scoreDifference: Double
    let isAhead: Bool
}

// MARK: - Achievement System
extension LeaderboardService {
    /// Check for new achievements based on game result
    func checkAchievements(gameResult: GameResult) -> [Achievement] {
        var newAchievements: [Achievement] = []
        
        // Wealth achievements
        if gameResult.finalWealth >= 10_000_000 {
            newAchievements.append(.millionaire)
        }
        if gameResult.finalWealth >= 100_000_000 {
            newAchievements.append(.centimillionaire)
        }
        
        // Efficiency achievements
        if gameResult.efficiency >= 95.0 {
            newAchievements.append(.efficientOperator)
        }
        
        // Singularity achievements
        if gameResult.singularityProgress >= 50.0 {
            newAchievements.append(.singularityContributor)
        }
        if gameResult.singularityProgress >= 100.0 {
            newAchievements.append(.singularityArchitect)
        }
        
        // Speed achievements
        if gameResult.sessionDuration < 1800 && gameResult.isWin { // 30 minutes
            newAchievements.append(.speedRunner)
        }
        
        return newAchievements
    }
}

enum Achievement: String, CaseIterable {
    case millionaire = "Millionaire"
    case centimillionaire = "Centimillionaire"
    case efficientOperator = "Efficient Operator"
    case singularityContributor = "Singularity Contributor"
    case singularityArchitect = "Singularity Architect"
    case speedRunner = "Speed Runner"
    
    var description: String {
        switch self {
        case .millionaire:
            return "Accumulate $10 million in wealth"
        case .centimillionaire:
            return "Accumulate $100 million in wealth"
        case .efficientOperator:
            return "Achieve 95% operational efficiency"
        case .singularityContributor:
            return "Contribute 50% to singularity progress"
        case .singularityArchitect:
            return "Complete singularity development"
        case .speedRunner:
            return "Win a game in under 30 minutes"
        }
    }
    
    var iconName: String {
        switch self {
        case .millionaire, .centimillionaire:
            return "dollarsign.circle.fill"
        case .efficientOperator:
            return "gauge.badge.plus"
        case .singularityContributor, .singularityArchitect:
            return "brain.head.profile"
        case .speedRunner:
            return "timer"
        }
    }
}

// MARK: - Enhanced Leaderboard Features

extension LeaderboardService {
    
    /// Load leaderboard with advanced filtering
    func loadFilteredLeaderboard(filter: LeaderboardFilter) async {
        let filterId = filter.id
        
        await MainActor.run {
            self.isLoading = true
        }
        
        do {
            let response = try await apiClient.getFilteredLeaderboard(filter: filter)
            
            let filteredLeaderboard = FilteredLeaderboard(
                filter: filter,
                entries: response.entries,
                metadata: response.metadata,
                lastUpdated: Date()
            )
            
            await MainActor.run {
                self.filteredLeaderboards[filterId] = filteredLeaderboard
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
            print("Failed to load filtered leaderboard: \(error)")
        }
    }
    
    /// Create custom leaderboard filter
    func createCustomFilter(name: String, criteria: FilterCriteria) async throws -> LeaderboardFilter {
        let filter = LeaderboardFilter(
            id: UUID().uuidString,
            name: name,
            criteria: criteria,
            isCustom: true,
            createdBy: getCurrentPlayerId(),
            createdAt: Date()
        )
        
        try await apiClient.saveCustomFilter(filter: filter)
        
        await MainActor.run {
            self.customFilters.append(filter)
        }
        
        return filter
    }
    
    /// Load social leaderboards (friends, rivals, alliance members)
    func loadSocialLeaderboards() async {
        do {
            let socialBoards = try await apiClient.getSocialLeaderboards(playerId: getCurrentPlayerId())
            
            await MainActor.run {
                self.socialLeaderboards = socialBoards
            }
            
        } catch {
            print("Failed to load social leaderboards: \(error)")
        }
    }
    
    /// Follow a player for leaderboard notifications
    func followPlayer(_ playerId: String) async throws {
        guard !followedPlayers.contains(playerId) else { return }
        
        try await apiClient.followPlayer(followerId: getCurrentPlayerId(), followeeId: playerId)
        
        await MainActor.run {
            self.followedPlayers.append(playerId)
        }
        
        // Start tracking this player's progress
        await trackPlayerProgress(playerId)
    }
    
    /// Unfollow a player
    func unfollowPlayer(_ playerId: String) async throws {
        try await apiClient.unfollowPlayer(followerId: getCurrentPlayerId(), followeeId: playerId)
        
        await MainActor.run {
            self.followedPlayers.removeAll { $0 == playerId }
        }
    }
    
    /// Get comprehensive player comparison
    func getPlayerComparison(targetPlayerId: String, metrics: [ComparisonMetric]) async -> PlayerComparison? {
        do {
            let currentPlayerId = getCurrentPlayerId()
            let comparison = try await apiClient.getPlayerComparison(
                player1: currentPlayerId,
                player2: targetPlayerId,
                metrics: metrics
            )
            
            return comparison
            
        } catch {
            print("Failed to get player comparison: \(error)")
            return nil
        }
    }
    
    /// Search leaderboards with advanced criteria
    func searchLeaderboards(query: LeaderboardSearchQuery) async -> [LeaderboardEntry] {
        do {
            let results = try await apiClient.searchLeaderboards(query: query)
            return results.entries
            
        } catch {
            print("Failed to search leaderboards: \(error)")
            return []
        }
    }
    
    /// Get historical leaderboard data
    func getLeaderboardHistory(type: LeaderboardType, playerId: String? = nil, timeRange: TimeRange) async -> LeaderboardHistory? {
        do {
            let targetPlayerId = playerId ?? getCurrentPlayerId()
            let history = try await apiClient.getLeaderboardHistory(
                type: type,
                playerId: targetPlayerId,
                timeRange: timeRange
            )
            
            return history
            
        } catch {
            print("Failed to get leaderboard history: \(error)")
            return nil
        }
    }
    
    /// Set up leaderboard alerts
    func setupLeaderboardAlert(alert: LeaderboardAlert) async throws {
        try await apiClient.createLeaderboardAlert(alert: alert)
        
        // Monitor alert conditions locally
        await monitorAlertCondition(alert)
    }
    
    /// Get leaderboard insights and analytics
    func getLeaderboardInsights(timeframe: Timeframe) async -> LeaderboardInsights? {
        do {
            let insights = try await apiClient.getLeaderboardInsights(
                playerId: getCurrentPlayerId(),
                timeframe: timeframe
            )
            
            return insights
            
        } catch {
            print("Failed to get leaderboard insights: \(error)")
            return nil
        }
    }
    
    /// Get predicted rank based on current performance
    func getPredictedRank(type: LeaderboardType, timeframe: Timeframe) async -> RankPrediction? {
        do {
            let prediction = try await apiClient.getPredictedRank(
                playerId: getCurrentPlayerId(),
                type: type,
                timeframe: timeframe
            )
            
            return prediction
            
        } catch {
            print("Failed to get rank prediction: \(error)")
            return nil
        }
    }
    
    // MARK: - Social Features
    
    private func trackPlayerProgress(_ playerId: String) async {
        // Set up monitoring for followed player's rank changes
        try? await apiClient.subscribeToPlayerUpdates(
            followerId: getCurrentPlayerId(),
            followeeId: playerId
        )
    }
    
    private func monitorAlertCondition(_ alert: LeaderboardAlert) async {
        // Implement alert monitoring logic
        Timer.scheduledTimer(withTimeInterval: alert.checkFrequency, repeats: true) { _ in
            Task {
                await self.checkAlertCondition(alert)
            }
        }
    }
    
    private func checkAlertCondition(_ alert: LeaderboardAlert) async {
        do {
            let currentRank = await getPlayerRank(for: alert.leaderboardType, timeframe: alert.timeframe)
            
            if let currentRank = currentRank, alert.shouldTrigger(currentRank: currentRank) {
                let notification = LeaderboardNotification(
                    id: UUID().uuidString,
                    alertId: alert.id,
                    playerId: getCurrentPlayerId(),
                    message: alert.generateMessage(currentRank: currentRank),
                    timestamp: Date(),
                    type: alert.notificationType
                )
                
                await MainActor.run {
                    self.leaderboardNotifications.append(notification)
                }
                
                // Send push notification if enabled
                if alert.sendPushNotification {
                    await sendPushNotification(notification)
                }
            }
            
        } catch {
            print("Failed to check alert condition: \(error)")
        }
    }
    
    private func sendPushNotification(_ notification: LeaderboardNotification) async {
        // Implement push notification sending
        try? await apiClient.sendPushNotification(notification: notification)
    }
    
    private func getCurrentPlayerId() -> String {
        return UserDefaults.standard.string(forKey: "playerId") ?? "unknown"
    }
}

// MARK: - Enhanced Leaderboard Models

struct SocialLeaderboard: Codable, Identifiable {
    let id: String
    let name: String
    let type: SocialLeaderboardType
    let entries: [LeaderboardEntry]
    let metadata: LeaderboardMetadata
    let lastUpdated: Date
}

enum SocialLeaderboardType: String, Codable, CaseIterable {
    case friends = "Friends"
    case alliance = "Alliance"
    case rivals = "Rivals"
    case nearby = "Nearby Players"
    case similar = "Similar Skill Level"
}

struct LeaderboardFilter: Codable, Identifiable {
    let id: String
    let name: String
    let criteria: FilterCriteria
    let isCustom: Bool
    let createdBy: String
    let createdAt: Date
    var isActive: Bool = true
}

struct FilterCriteria: Codable {
    let leaderboardType: LeaderboardType
    let timeframe: Timeframe
    let regionFilter: String?
    let skillLevelRange: SkillLevelRange?
    let gamesModeFilter: [GameMode]?
    let achievementFilter: [Achievement]?
    let minimumGamesPlayed: Int?
    let excludeBannedPlayers: Bool
    let includeOnlyVerified: Bool
    
    init(leaderboardType: LeaderboardType, timeframe: Timeframe) {
        self.leaderboardType = leaderboardType
        self.timeframe = timeframe
        self.regionFilter = nil
        self.skillLevelRange = nil
        self.gamesModeFilter = nil
        self.achievementFilter = nil
        self.minimumGamesPlayed = nil
        self.excludeBannedPlayers = true
        self.includeOnlyVerified = false
    }
}

struct SkillLevelRange: Codable {
    let minimum: Int
    let maximum: Int
}

struct FilteredLeaderboard: Codable {
    let filter: LeaderboardFilter
    let entries: [LeaderboardEntry]
    let metadata: LeaderboardMetadata
    let lastUpdated: Date
}

struct LeaderboardMetadata: Codable {
    let totalPlayers: Int
    let averageScore: Double
    let medianScore: Double
    let percentileBreakdowns: [Int: Double] // Percentile to score
    let regionDistribution: [String: Int]
    let lastUpdated: Date
}

struct PlayerComparison: Codable {
    let player1: ComparisonPlayerData
    let player2: ComparisonPlayerData
    let metrics: [ComparisonResult]
    let overallWinner: String?
    let recommendations: [String]
}

struct ComparisonPlayerData: Codable {
    let playerId: String
    let playerName: String
    let stats: PlayerStats
    let achievements: [Achievement]
    let currentRanks: [LeaderboardType: Int]
}

struct ComparisonResult: Codable {
    let metric: ComparisonMetric
    let player1Value: Double
    let player2Value: Double
    let winner: String?
    let difference: Double
    let percentageDifference: Double
}

enum ComparisonMetric: String, Codable, CaseIterable {
    case totalWealth = "Total Wealth"
    case averageEfficiency = "Average Efficiency"
    case gamesWon = "Games Won"
    case winRate = "Win Rate"
    case averageGameDuration = "Average Game Duration"
    case singularityProgress = "Singularity Progress"
    case achievementCount = "Achievement Count"
    case playtime = "Total Playtime"
}

struct LeaderboardSearchQuery: Codable {
    let playerName: String?
    let achievementFilter: [Achievement]?
    let rankRange: RankRange?
    let regionFilter: String?
    let limit: Int
    let offset: Int
    
    init(limit: Int = 50, offset: Int = 0) {
        self.playerName = nil
        self.achievementFilter = nil
        self.rankRange = nil
        self.regionFilter = nil
        self.limit = limit
        self.offset = offset
    }
}

struct RankRange: Codable {
    let minimum: Int
    let maximum: Int
}

struct LeaderboardHistory: Codable {
    let playerId: String
    let leaderboardType: LeaderboardType
    let dataPoints: [HistoricalDataPoint]
    let timeRange: TimeRange
    let trends: LeaderboardTrends
}

struct HistoricalDataPoint: Codable {
    let timestamp: Date
    let rank: Int
    let score: Double
    let percentile: Double
}

struct TimeRange: Codable {
    let startDate: Date
    let endDate: Date
    
    static var lastWeek: TimeRange {
        let now = Date()
        return TimeRange(
            startDate: now.addingTimeInterval(-7 * 24 * 3600),
            endDate: now
        )
    }
    
    static var lastMonth: TimeRange {
        let now = Date()
        return TimeRange(
            startDate: now.addingTimeInterval(-30 * 24 * 3600),
            endDate: now
        )
    }
    
    static var lastYear: TimeRange {
        let now = Date()
        return TimeRange(
            startDate: now.addingTimeInterval(-365 * 24 * 3600),
            endDate: now
        )
    }
}

struct LeaderboardTrends: Codable {
    let rankTrend: TrendDirection
    let scoreTrend: TrendDirection
    let velocityTrend: TrendDirection // Rate of improvement
    let consistency: Double // 0.0 to 1.0
    let momentum: Double // Current improvement rate
}

enum TrendDirection: String, Codable {
    case improving = "Improving"
    case declining = "Declining"
    case stable = "Stable"
    case volatile = "Volatile"
}

struct LeaderboardAlert: Codable, Identifiable {
    let id: String
    let playerId: String
    let leaderboardType: LeaderboardType
    let timeframe: Timeframe
    let condition: AlertCondition
    let notificationType: NotificationType
    let isActive: Bool
    let sendPushNotification: Bool
    let checkFrequency: TimeInterval
    let createdAt: Date
    
    func shouldTrigger(currentRank: Int) -> Bool {
        switch condition {
        case .rankImproved(let threshold):
            return currentRank <= threshold
        case .rankDeclined(let threshold):
            return currentRank >= threshold
        case .enteredTopN(let n):
            return currentRank <= n
        case .leftTopN(let n):
            return currentRank > n
        case .passedPlayer(let playerId):
            // Would need additional logic to check if we passed specific player
            return false
        }
    }
    
    func generateMessage(currentRank: Int) -> String {
        switch condition {
        case .rankImproved(let threshold):
            return "🎉 You've improved to rank #\(currentRank)! Target was \(threshold)."
        case .rankDeclined(let threshold):
            return "📉 Your rank has dropped to #\(currentRank). Target threshold was \(threshold)."
        case .enteredTopN(let n):
            return "🏆 Congratulations! You've entered the top \(n) at rank #\(currentRank)!"
        case .leftTopN(let n):
            return "⚠️ You've dropped out of the top \(n) to rank #\(currentRank)."
        case .passedPlayer(let playerId):
            return "🏃‍♂️ You've passed player \(playerId) and are now rank #\(currentRank)!"
        }
    }
}

enum AlertCondition: Codable {
    case rankImproved(Int)
    case rankDeclined(Int)
    case enteredTopN(Int)
    case leftTopN(Int)
    case passedPlayer(String)
}

enum NotificationType: String, Codable, CaseIterable {
    case immediate = "Immediate"
    case digest = "Daily Digest"
    case weekly = "Weekly Summary"
    case milestone = "Milestone Only"
}

struct LeaderboardNotification: Codable, Identifiable {
    let id: String
    let alertId: String
    let playerId: String
    let message: String
    let timestamp: Date
    let type: NotificationType
    var isRead: Bool = false
}

struct LeaderboardInsights: Codable {
    let playerId: String
    let timeframe: Timeframe
    let rankingBreakdown: [LeaderboardType: RankInsight]
    let improvementSuggestions: [String]
    let strengthsAndWeaknesses: StrengthsWeaknesses
    let competitivePosition: CompetitivePosition
    let projectedRankings: [LeaderboardType: RankPrediction]
}

struct RankInsight: Codable {
    let currentRank: Int
    let bestRank: Int
    let worstRank: Int
    let averageRank: Double
    let rankVolatility: Double
    let improvementRate: Double
    let timeInTopPercentile: Double
}

struct StrengthsWeaknesses: Codable {
    let strengths: [String]
    let weaknesses: [String]
    let opportunities: [String]
    let threats: [String]
}

struct CompetitivePosition: Codable {
    let overallPercentile: Double
    let nearbyCompetitors: [CompetitorInfo]
    let gapToNext: CompetitionGap
    let gapToPrevious: CompetitionGap
}

struct CompetitorInfo: Codable {
    let playerId: String
    let playerName: String
    let rank: Int
    let score: Double
    let trend: TrendDirection
}

struct CompetitionGap: Codable {
    let rankDifference: Int
    let scoreDifference: Double
    let estimatedTimeToClose: TimeInterval?
}

struct RankPrediction: Codable {
    let leaderboardType: LeaderboardType
    let currentRank: Int
    let predictedRank: Int
    let confidence: Double
    let timeframe: Timeframe
    let factors: [PredictionFactor]
}

struct PredictionFactor: Codable {
    let factor: String
    let impact: Double // -1.0 to 1.0
    let description: String
}

// MARK: - Friends and Rivalry System

class FriendsManager {
    func getFriends(for playerId: String) async -> [String] {
        // Implementation would fetch friends list
        return []
    }
    
    func addFriend(_ friendId: String, for playerId: String) async throws {
        // Implementation would add friend
    }
    
    func removeFriend(_ friendId: String, for playerId: String) async throws {
        // Implementation would remove friend
    }
}

class RivalryTracker {
    func getRivals(for playerId: String) async -> [String] {
        // Implementation would identify rivals based on frequent competition
        return []
    }
    
    func getRivalryStats(player1: String, player2: String) async -> RivalryStats? {
        // Implementation would get head-to-head stats
        return nil
    }
}

struct RivalryStats: Codable {
    let player1Id: String
    let player2Id: String
    let gamesPlayed: Int
    let player1Wins: Int
    let player2Wins: Int
    let draws: Int
    let lastMatchDate: Date
    let competitionIntensity: Double // 0.0 to 1.0
}

class AchievementTracker {
    func getRecentAchievements(for playerId: String) async -> [Achievement] {
        // Implementation would get recent achievements
        return []
    }
    
    func trackProgress(for playerId: String, achievement: Achievement) async {
        // Implementation would track achievement progress
    }
}

// MARK: - API Extensions for Enhanced Leaderboards

extension APIClient {
    func getFilteredLeaderboard(filter: LeaderboardFilter) async throws -> LeaderboardResponse {
        // Implementation would fetch filtered leaderboard
        return LeaderboardResponse(entries: [], playerRank: nil, totalPlayers: 0)
    }
    
    func saveCustomFilter(filter: LeaderboardFilter) async throws {
        // Implementation would save custom filter
    }
    
    func getSocialLeaderboards(playerId: String) async throws -> [SocialLeaderboard] {
        // Implementation would fetch social leaderboards
        return []
    }
    
    func followPlayer(followerId: String, followeeId: String) async throws {
        // Implementation would follow player
    }
    
    func unfollowPlayer(followerId: String, followeeId: String) async throws {
        // Implementation would unfollow player
    }
    
    func getPlayerComparison(player1: String, player2: String, metrics: [ComparisonMetric]) async throws -> PlayerComparison {
        // Implementation would get player comparison
        throw NetworkError.custom("Not implemented")
    }
    
    func searchLeaderboards(query: LeaderboardSearchQuery) async throws -> LeaderboardResponse {
        // Implementation would search leaderboards
        return LeaderboardResponse(entries: [], playerRank: nil, totalPlayers: 0)
    }
    
    func getLeaderboardHistory(type: LeaderboardType, playerId: String, timeRange: TimeRange) async throws -> LeaderboardHistory {
        // Implementation would get leaderboard history
        throw NetworkError.custom("Not implemented")
    }
    
    func createLeaderboardAlert(alert: LeaderboardAlert) async throws {
        // Implementation would create leaderboard alert
    }
    
    func getLeaderboardInsights(playerId: String, timeframe: Timeframe) async throws -> LeaderboardInsights {
        // Implementation would get leaderboard insights
        throw NetworkError.custom("Not implemented")
    }
    
    func getPredictedRank(playerId: String, type: LeaderboardType, timeframe: Timeframe) async throws -> RankPrediction {
        // Implementation would get predicted rank
        throw NetworkError.custom("Not implemented")
    }
    
    func subscribeToPlayerUpdates(followerId: String, followeeId: String) async throws {
        // Implementation would subscribe to player updates
    }
    
    func sendPushNotification(notification: LeaderboardNotification) async throws {
        // Implementation would send push notification
    }
}