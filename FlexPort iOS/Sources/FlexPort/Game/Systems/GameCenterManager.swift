import Foundation
import GameKit
import Combine

// MARK: - Game Center Manager

public class GameCenterManager: NSObject, ObservableObject {
    public static let shared = GameCenterManager()
    
    @Published public var isAuthenticated = false
    @Published public var localPlayer: GKLocalPlayer?
    @Published public var authenticationViewController: UIViewController?
    @Published public var leaderboards: [GKLeaderboard] = []
    @Published public var achievements: [GKAchievement] = []
    
    private var authenticationContinuation: CheckedContinuation<Bool, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    // Leaderboard IDs
    public enum LeaderboardID: String, CaseIterable {
        case totalExperience = "com.flexport.total_experience"
        case playerLevel = "com.flexport.player_level"
        case totalProfit = "com.flexport.total_profit"
        case fleetSize = "com.flexport.fleet_size"
        case tradesCompleted = "com.flexport.trades_completed"
        case singularitySurvival = "com.flexport.singularity_survival_time"
    }
    
    // Achievement IDs
    public enum AchievementID: String {
        case firstTrade = "com.flexport.first_trade"
        case tradeMaster = "com.flexport.trade_master"
        case profitKing = "com.flexport.profit_king"
        case fleetBuilder = "com.flexport.fleet_builder"
        case diverseFleet = "com.flexport.diverse_fleet"
        case fleetAdmiral = "com.flexport.fleet_admiral"
        case routePlanner = "com.flexport.route_planner"
        case globalNetwork = "com.flexport.global_network"
        case marketWatcher = "com.flexport.market_watcher"
        case arbitrageExpert = "com.flexport.arbitrage_expert"
        case level10 = "com.flexport.level_10"
        case level25 = "com.flexport.level_25"
        case level50 = "com.flexport.level_50"
        case singularitySurvivor = "com.flexport.singularity_survivor"
        case efficiencyMaster = "com.flexport.efficiency_master"
        case monopolist = "com.flexport.monopolist"
    }
    
    private override init() {
        super.init()
    }
    
    // MARK: - Authentication
    
    @MainActor
    public func authenticatePlayer() async -> Bool {
        if GKLocalPlayer.local.isAuthenticated {
            self.isAuthenticated = true
            self.localPlayer = GKLocalPlayer.local
            await loadGameCenterData()
            return true
        }
        
        return await withCheckedContinuation { continuation in
            self.authenticationContinuation = continuation
            
            GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
                DispatchQueue.main.async {
                    if let viewController = viewController {
                        self?.authenticationViewController = viewController
                    } else if GKLocalPlayer.local.isAuthenticated {
                        self?.isAuthenticated = true
                        self?.localPlayer = GKLocalPlayer.local
                        self?.authenticationContinuation?.resume(returning: true)
                        self?.authenticationContinuation = nil
                        
                        Task {
                            await self?.loadGameCenterData()
                        }
                    } else {
                        self?.isAuthenticated = false
                        self?.authenticationContinuation?.resume(returning: false)
                        self?.authenticationContinuation = nil
                        
                        if let error = error {
                            print("Game Center authentication failed: \(error)")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Data Loading
    
    @MainActor
    private func loadGameCenterData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadLeaderboards() }
            group.addTask { await self.loadAchievements() }
        }
    }
    
    @MainActor
    private func loadLeaderboards() async {
        do {
            let leaderboardIDs = LeaderboardID.allCases.map { $0.rawValue }
            let loadedLeaderboards = try await GKLeaderboard.loadLeaderboards(IDs: leaderboardIDs)
            self.leaderboards = loadedLeaderboards
        } catch {
            print("Failed to load leaderboards: \(error)")
        }
    }
    
    @MainActor
    private func loadAchievements() async {
        do {
            let loadedAchievements = try await GKAchievement.loadAchievements()
            self.achievements = loadedAchievements
        } catch {
            print("Failed to load achievements: \(error)")
        }
    }
    
    // MARK: - Score Reporting
    
    public func reportScore(_ score: Int, for leaderboardID: LeaderboardID) async {
        guard isAuthenticated else { return }
        
        do {
            try await GKLeaderboard.submitScore(
                score,
                context: 0,
                player: GKLocalPlayer.local,
                leaderboardIDs: [leaderboardID.rawValue]
            )
            print("Score reported successfully: \(score) to \(leaderboardID.rawValue)")
        } catch {
            print("Failed to report score: \(error)")
        }
    }
    
    // MARK: - Achievement Reporting
    
    public func reportAchievement(_ achievementID: AchievementID, percentComplete: Double = 100.0) async {
        guard isAuthenticated else { return }
        
        let achievement = GKAchievement(identifier: achievementID.rawValue)
        achievement.percentComplete = percentComplete
        achievement.showsCompletionBanner = percentComplete >= 100.0
        
        do {
            try await GKAchievement.report([achievement])
            print("Achievement reported: \(achievementID.rawValue) - \(percentComplete)%")
            
            // Update local cache
            if let index = achievements.firstIndex(where: { $0.identifier == achievementID.rawValue }) {
                achievements[index] = achievement
            } else {
                achievements.append(achievement)
            }
        } catch {
            print("Failed to report achievement: \(error)")
        }
    }
    
    // MARK: - Progress Tracking
    
    public func updateAchievementProgress(_ achievementID: AchievementID, progress: Double) async {
        guard isAuthenticated else { return }
        
        // Check if achievement is already completed
        if let existingAchievement = achievements.first(where: { $0.identifier == achievementID.rawValue }),
           existingAchievement.isCompleted {
            return
        }
        
        await reportAchievement(achievementID, percentComplete: min(progress, 100.0))
    }
    
    // MARK: - Leaderboard Display
    
    @MainActor
    public func showLeaderboard(_ leaderboardID: LeaderboardID) -> GKGameCenterViewController {
        let viewController = GKGameCenterViewController(leaderboardID: leaderboardID.rawValue, playerScope: .global, timeScope: .allTime)
        viewController.gameCenterDelegate = self
        return viewController
    }
    
    @MainActor
    public func showAchievements() -> GKGameCenterViewController {
        let viewController = GKGameCenterViewController(state: .achievements)
        viewController.gameCenterDelegate = self
        return viewController
    }
    
    // MARK: - Score Fetching
    
    public func fetchPlayerScore(for leaderboardID: LeaderboardID) async -> Int? {
        guard isAuthenticated else { return nil }
        
        do {
            let leaderboards = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboardID.rawValue])
            guard let leaderboard = leaderboards.first else { return nil }
            
            let entry = try await leaderboard.loadEntries(for: .global, timeScope: .allTime, range: NSRange(1...1))
            return entry.localPlayerEntry?.score
        } catch {
            print("Failed to fetch player score: \(error)")
            return nil
        }
    }
    
    // MARK: - Friends & Challenges
    
    public func loadFriends() async -> [GKPlayer] {
        guard isAuthenticated else { return [] }
        
        do {
            let friends = try await GKLocalPlayer.local.loadFriends()
            return friends
        } catch {
            print("Failed to load friends: \(error)")
            return []
        }
    }
    
    public func challengePlayer(_ player: GKPlayer, score: Int, leaderboardID: LeaderboardID, message: String) async {
        guard isAuthenticated else { return }
        
        do {
            let challenge = GKChallenge()
            // Configure challenge
            // Note: Full challenge implementation would require more setup
            print("Challenge feature placeholder for player: \(player.displayName)")
        } catch {
            print("Failed to create challenge: \(error)")
        }
    }
    
    // MARK: - Achievement Helpers
    
    public func getAchievementProgress(_ achievementID: AchievementID) -> Double {
        return achievements.first(where: { $0.identifier == achievementID.rawValue })?.percentComplete ?? 0.0
    }
    
    public func isAchievementCompleted(_ achievementID: AchievementID) -> Bool {
        return achievements.first(where: { $0.identifier == achievementID.rawValue })?.isCompleted ?? false
    }
    
    public func getCompletedAchievementsCount() -> Int {
        return achievements.filter { $0.isCompleted }.count
    }
    
    public func getAchievementCompletionPercentage() -> Double {
        let totalPossibleAchievements = 16 // Based on AchievementID cases
        let completed = getCompletedAchievementsCount()
        return Double(completed) / Double(totalPossibleAchievements) * 100.0
    }
    
    // MARK: - Reset
    
    public func resetAchievements() async {
        guard isAuthenticated else { return }
        
        do {
            try await GKAchievement.resetAchievements()
            achievements.removeAll()
            print("Achievements reset successfully")
        } catch {
            print("Failed to reset achievements: \(error)")
        }
    }
}

// MARK: - GKGameCenterControllerDelegate

extension GameCenterManager: GKGameCenterControllerDelegate {
    public func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}

// MARK: - Game Center Integration Extensions

extension ProgressionSystem {
    public func syncWithGameCenter() async {
        let gameCenter = GameCenterManager.shared
        
        // Report current level
        await gameCenter.reportScore(currentLevel, for: .playerLevel)
        
        // Report total experience
        await gameCenter.reportScore(currentExperience, for: .totalExperience)
        
        // Sync achievements
        for achievement in achievements {
            if let achievementID = mapToGameCenterID(achievement.id) {
                if achievement.isUnlocked {
                    await gameCenter.reportAchievement(achievementID, percentComplete: 100.0)
                } else {
                    let progress = (achievement.progress / achievement.maxProgress) * 100.0
                    await gameCenter.updateAchievementProgress(achievementID, progress: Double(progress))
                }
            }
        }
    }
    
    private func mapToGameCenterID(_ localID: String) -> GameCenterManager.AchievementID? {
        switch localID {
        case "first_trade": return .firstTrade
        case "trade_master": return .tradeMaster
        case "profit_king": return .profitKing
        case "fleet_builder": return .fleetBuilder
        case "diverse_fleet": return .diverseFleet
        case "fleet_admiral": return .fleetAdmiral
        case "route_planner": return .routePlanner
        case "global_network": return .globalNetwork
        case "market_watcher": return .marketWatcher
        case "arbitrage_expert": return .arbitrageExpert
        case "level_10": return .level10
        case "level_25": return .level25
        case "level_50": return .level50
        case "singularity_survivor": return .singularitySurvivor
        case "efficiency_master": return .efficiencyMaster
        case "monopolist": return .monopolist
        default: return nil
        }
    }
}