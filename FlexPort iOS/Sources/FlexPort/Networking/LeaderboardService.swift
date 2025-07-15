import Foundation
import Combine

/// Manages leaderboards and player statistics
class LeaderboardService: ObservableObject {
    static let shared = LeaderboardService()
    
    @Published private(set) var globalLeaderboard: [LeaderboardEntry] = []
    @Published private(set) var playerRank: Int?
    @Published private(set) var playerStats: PlayerStats?
    @Published private(set) var isLoading: Bool = false
    
    private let apiClient = APIClient.shared
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // Cache management
    private var leaderboardCache: [String: (data: LeaderboardResponse, timestamp: Date)] = [:]
    private let cacheTimeout: TimeInterval = 300 // 5 minutes
    
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