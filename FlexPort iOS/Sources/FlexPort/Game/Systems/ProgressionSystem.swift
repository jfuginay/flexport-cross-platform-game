import Foundation
import CoreData
import Combine
import GameKit

// MARK: - Progression System

public class ProgressionSystem: ObservableObject {
    @Published public var currentLevel: Int = 1
    @Published public var currentExperience: Int = 0
    @Published public var experienceToNextLevel: Int = 100
    @Published public var unlockedFeatures: Set<String> = []
    @Published public var achievements: [Achievement] = []
    @Published public var levelProgress: Float = 0.0
    
    private let maxLevel = 50
    private let baseXPRequirement = 100
    private let xpGrowthRate: Float = 1.15
    
    private var levelRequirements: [LevelRequirement] = []
    private var experienceRewards: [ExperienceReward] = []
    private var achievementProgress: [String: Float] = [:]
    
    private let coreDataManager = CoreDataManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Game Center integration
    private var isGameCenterAuthenticated = false
    
    public init() {
        initializeLevelRequirements()
        initializeExperienceRewards()
        initializeAchievements()
        loadProgressFromCoreData()
        authenticateGameCenter()
    }
    
    // MARK: - Level Requirements
    
    private func initializeLevelRequirements() {
        for level in 1...maxLevel {
            let experienceRequired = Int(Float(baseXPRequirement) * pow(xpGrowthRate, Float(level - 1)))
            
            var unlocks: [String] = []
            var rewards = LevelReward()
            
            // Define level-specific unlocks and rewards (matching web version)
            switch level {
            case 2:
                unlocks.append("basic_trade_routes")
            case 3:
                unlocks.append("bulk_carrier_ships")
            case 5:
                unlocks.append(contentsOf: ["container_ships", "advanced_navigation"])
                rewards.researchPoints = 5
            case 8:
                unlocks.append(contentsOf: ["tanker_ships", "fuel_efficiency_upgrade"])
                rewards.shipSlots = 1
            case 10:
                unlocks.append(contentsOf: ["market_analytics", "crew_management"])
                rewards.cash = 500000
                rewards.researchPoints = 10
            case 12:
                unlocks.append("general_cargo_ships")
            case 15:
                unlocks.append(contentsOf: ["trade_route_optimization", "roro_ships"])
                rewards.routeSlots = 2
                rewards.researchPoints = 15
            case 18:
                unlocks.append(contentsOf: ["refrigerated_ships", "advanced_cargo_handling"])
            case 20:
                unlocks.append(contentsOf: ["fleet_management", "automated_trading"])
                rewards.cash = 1000000
                rewards.shipSlots = 2
            case 22:
                unlocks.append("heavy_lift_ships")
            case 25:
                unlocks.append(contentsOf: ["ai_assisted_navigation", "predictive_maintenance"])
                rewards.researchPoints = 25
                rewards.routeSlots = 3
            case 30:
                unlocks.append(contentsOf: ["global_trade_network", "market_manipulation"])
                rewards.cash = 2500000
                rewards.shipSlots = 3
            case 35:
                unlocks.append(contentsOf: ["quantum_logistics", "hyperloop_integration"])
                rewards.researchPoints = 50
            case 40:
                unlocks.append(contentsOf: ["autonomous_fleet_operations", "supply_chain_ai"])
                rewards.cash = 5000000
                rewards.shipSlots = 5
            case 45:
                unlocks.append(contentsOf: ["singularity_resistance", "market_dominance"])
                rewards.researchPoints = 100
            case 50:
                unlocks.append(contentsOf: ["logistics_mastery", "infinite_scalability"])
                rewards.cash = 10000000
                rewards.shipSlots = 10
                rewards.routeSlots = 10
            default:
                break
            }
            
            // Every 5 levels, grant bonus rewards
            if level % 5 == 0 {
                rewards.cash = (rewards.cash ?? 0) + level * 50000
                rewards.researchPoints = (rewards.researchPoints ?? 0) + level / 2
            }
            
            levelRequirements.append(LevelRequirement(
                level: level,
                experienceRequired: experienceRequired,
                unlocks: unlocks,
                rewards: rewards
            ))
        }
    }
    
    // MARK: - Experience Rewards
    
    private func initializeExperienceRewards() {
        experienceRewards = [
            // Trading XP
            ExperienceReward(action: "complete_trade", baseXP: 50, multipliers: ["profit_margin": 2.0, "distance": 1.5]),
            ExperienceReward(action: "profitable_trade", baseXP: 100, multipliers: ["profit_amount": 0.001]),
            ExperienceReward(action: "establish_route", baseXP: 200),
            ExperienceReward(action: "optimize_route", baseXP: 150),
            
            // Fleet Management XP
            ExperienceReward(action: "purchase_ship", baseXP: 300, multipliers: ["ship_tier": 1.5]),
            ExperienceReward(action: "upgrade_ship", baseXP: 100),
            ExperienceReward(action: "maintain_fleet", baseXP: 25),
            ExperienceReward(action: "crew_hire", baseXP: 50),
            
            // Market Activities XP
            ExperienceReward(action: "market_analysis", baseXP: 30),
            ExperienceReward(action: "price_prediction", baseXP: 75, multipliers: ["accuracy": 2.0]),
            ExperienceReward(action: "arbitrage_success", baseXP: 250),
            
            // Strategic Actions XP
            ExperienceReward(action: "port_expansion", baseXP: 500),
            ExperienceReward(action: "research_complete", baseXP: 150, multipliers: ["research_tier": 1.5]),
            ExperienceReward(action: "compete_ai_win", baseXP: 400),
            
            // Milestone XP
            ExperienceReward(action: "first_million", baseXP: 1000),
            ExperienceReward(action: "fleet_size_milestone", baseXP: 500, multipliers: ["fleet_size": 10]),
            ExperienceReward(action: "trade_volume_milestone", baseXP: 750, multipliers: ["volume": 0.0001]),
            
            // Daily/Recurring XP
            ExperienceReward(action: "daily_login", baseXP: 100),
            ExperienceReward(action: "weekly_profit", baseXP: 500, multipliers: ["profit_percentage": 1.5]),
            ExperienceReward(action: "monthly_dominance", baseXP: 2000)
        ]
    }
    
    // MARK: - Grant Experience
    
    public func grantExperience(action: String, context: [String: Float] = [:]) -> Int {
        guard let reward = experienceRewards.first(where: { $0.action == action }) else {
            return 0
        }
        
        var xpGained = Float(reward.baseXP)
        
        // Apply multipliers
        if let multipliers = reward.multipliers {
            for (key, multiplier) in multipliers {
                if let contextValue = context[key] {
                    xpGained *= (1 + (contextValue * multiplier))
                }
            }
        }
        
        // Apply level scaling
        let levelBonus = 1 + (Float(currentLevel) * 0.02)
        xpGained *= levelBonus
        
        let finalXP = Int(xpGained)
        currentExperience += finalXP
        
        // Check for level up
        checkLevelUp()
        
        // Update achievement progress
        updateAchievementProgress(action: action, context: context)
        
        // Save progress
        saveProgressToCoreData()
        
        // Report to Game Center
        reportScoreToGameCenter(score: currentExperience)
        
        return finalXP
    }
    
    // MARK: - Level Up
    
    private func checkLevelUp() {
        guard currentLevel < maxLevel else { return }
        
        while currentExperience >= experienceToNextLevel && currentLevel < maxLevel {
            levelUp()
        }
        
        updateLevelProgress()
    }
    
    private func levelUp() {
        currentLevel += 1
        currentExperience -= experienceToNextLevel
        
        // Get new level requirement
        if let nextLevel = levelRequirements.first(where: { $0.level == currentLevel }) {
            experienceToNextLevel = nextLevel.experienceRequired
            
            // Apply unlocks
            for unlock in nextLevel.unlocks {
                unlockedFeatures.insert(unlock)
                notifyUnlock(unlock)
            }
            
            // Grant rewards
            if let rewards = nextLevel.rewards {
                applyRewards(rewards)
            }
        }
        
        // Achievement for leveling
        updateAchievementProgress(action: "level_reached", context: ["level": Float(currentLevel)])
        
        // Report level to Game Center
        reportLevelToGameCenter(level: currentLevel)
    }
    
    private func updateLevelProgress() {
        if experienceToNextLevel > 0 {
            levelProgress = Float(currentExperience) / Float(experienceToNextLevel)
        } else {
            levelProgress = 1.0
        }
    }
    
    // MARK: - Rewards
    
    private func applyRewards(_ rewards: LevelReward) {
        // This would integrate with the game's economy system
        var rewardNotifications: [String] = []
        
        if let cash = rewards.cash {
            rewardNotifications.append("💰 +$\(cash.formatted())")
        }
        
        if let researchPoints = rewards.researchPoints {
            rewardNotifications.append("🔬 +\(researchPoints) Research Points")
        }
        
        if let shipSlots = rewards.shipSlots {
            rewardNotifications.append("🚢 +\(shipSlots) Ship Slots")
        }
        
        if let routeSlots = rewards.routeSlots {
            rewardNotifications.append("🗺 +\(routeSlots) Route Slots")
        }
        
        // Post notification for UI
        NotificationCenter.default.post(
            name: .levelUpRewards,
            object: nil,
            userInfo: ["rewards": rewardNotifications]
        )
    }
    
    private func notifyUnlock(_ unlock: String) {
        NotificationCenter.default.post(
            name: .featureUnlocked,
            object: nil,
            userInfo: ["unlock": unlock]
        )
    }
    
    // MARK: - Achievements
    
    private func initializeAchievements() {
        achievements = [
            // Trading Achievements
            Achievement(id: "first_trade", name: "First Steps", description: "Complete your first trade", maxProgress: 1),
            Achievement(id: "trade_master", name: "Trade Master", description: "Complete 100 successful trades", maxProgress: 100),
            Achievement(id: "profit_king", name: "Profit King", description: "Earn $10 million in total profit", maxProgress: 10000000),
            
            // Fleet Achievements
            Achievement(id: "fleet_builder", name: "Fleet Builder", description: "Own 10 ships", maxProgress: 10),
            Achievement(id: "diverse_fleet", name: "Diverse Operations", description: "Own one ship of each type", maxProgress: 7),
            Achievement(id: "fleet_admiral", name: "Fleet Admiral", description: "Command 50 ships", maxProgress: 50),
            
            // Route Achievements
            Achievement(id: "route_planner", name: "Route Planner", description: "Establish 5 trade routes", maxProgress: 5),
            Achievement(id: "global_network", name: "Global Network", description: "Have routes connecting all continents", maxProgress: 7),
            
            // Market Achievements
            Achievement(id: "market_watcher", name: "Market Watcher", description: "Track market trends for 7 days", maxProgress: 7),
            Achievement(id: "arbitrage_expert", name: "Arbitrage Expert", description: "Profit from 50 arbitrage opportunities", maxProgress: 50),
            
            // Progression Achievements
            Achievement(id: "level_10", name: "Rising Star", description: "Reach level 10", maxProgress: 10),
            Achievement(id: "level_25", name: "Industry Leader", description: "Reach level 25", maxProgress: 25),
            Achievement(id: "level_50", name: "Logistics Legend", description: "Reach level 50", maxProgress: 50),
            
            // Special Achievements
            Achievement(id: "singularity_survivor", name: "Singularity Survivor", description: "Survive an AI singularity event", maxProgress: 1),
            Achievement(id: "efficiency_master", name: "Efficiency Master", description: "Achieve 95% fleet efficiency", maxProgress: 95),
            Achievement(id: "monopolist", name: "Monopolist", description: "Control 50% of a commodity market", maxProgress: 50)
        ]
    }
    
    private func updateAchievementProgress(action: String, context: [String: Float]) {
        for i in 0..<achievements.count {
            guard !achievements[i].isUnlocked else { continue }
            
            var shouldUpdate = false
            var progressIncrement: Float = 0
            
            switch achievements[i].id {
            case "first_trade":
                if action == "complete_trade" {
                    shouldUpdate = true
                    progressIncrement = 1
                }
                
            case "trade_master":
                if action == "complete_trade" {
                    shouldUpdate = true
                    progressIncrement = 1
                }
                
            case "profit_king":
                if action == "profitable_trade", let profit = context["profit_amount"] {
                    shouldUpdate = true
                    progressIncrement = profit
                }
                
            case "fleet_builder", "fleet_admiral":
                if action == "purchase_ship", let fleetSize = context["fleet_size"] {
                    shouldUpdate = true
                    achievements[i].progress = fleetSize
                }
                
            case "level_10", "level_25", "level_50":
                if action == "level_reached", let level = context["level"] {
                    achievements[i].progress = level
                    shouldUpdate = true
                }
                
            case "arbitrage_expert":
                if action == "arbitrage_success" {
                    shouldUpdate = true
                    progressIncrement = 1
                }
                
            default:
                break
            }
            
            if shouldUpdate {
                if progressIncrement > 0 {
                    achievements[i].progress = min(
                        achievements[i].progress + progressIncrement,
                        achievements[i].maxProgress
                    )
                }
                
                // Check if achievement is completed
                if achievements[i].progress >= achievements[i].maxProgress {
                    achievements[i].isUnlocked = true
                    achievements[i].unlockedDate = Date()
                    
                    // Grant achievement XP
                    let rarity = getAchievementRarity(achievements[i].id)
                    _ = grantExperience(action: "achievement_unlocked", context: ["rarity": Float(rarity)])
                    
                    // Report to Game Center
                    reportAchievementToGameCenter(achievementId: achievements[i].id)
                    
                    // Notify UI
                    NotificationCenter.default.post(
                        name: .achievementUnlocked,
                        object: nil,
                        userInfo: ["achievement": achievements[i]]
                    )
                }
            }
        }
    }
    
    private func getAchievementRarity(_ achievementId: String) -> Int {
        let rarityMap: [String: Int] = [
            "first_trade": 1,
            "trade_master": 2,
            "profit_king": 3,
            "fleet_builder": 2,
            "diverse_fleet": 3,
            "fleet_admiral": 4,
            "route_planner": 2,
            "global_network": 4,
            "market_watcher": 2,
            "arbitrage_expert": 3,
            "level_10": 2,
            "level_25": 3,
            "level_50": 5,
            "singularity_survivor": 5,
            "efficiency_master": 4,
            "monopolist": 5
        ]
        
        return rarityMap[achievementId] ?? 1
    }
    
    // MARK: - Feature Checking
    
    public func isFeatureUnlocked(_ feature: String) -> Bool {
        return unlockedFeatures.contains(feature)
    }
    
    public func getUnlocksForLevel(_ level: Int) -> [String] {
        return levelRequirements.first(where: { $0.level == level })?.unlocks ?? []
    }
    
    public func getProgressToNextLevel() -> ProgressInfo {
        return ProgressInfo(
            currentLevel: currentLevel,
            nextLevel: min(currentLevel + 1, maxLevel),
            currentXP: currentExperience,
            requiredXP: experienceToNextLevel,
            progress: levelProgress
        )
    }
    
    // MARK: - Core Data Persistence
    
    private func saveProgressToCoreData() {
        let context = coreDataManager.context
        
        // Create or update player progress entity
        let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "PlayerProgress")
        request.predicate = NSPredicate(format: "playerId == %@", "main_player")
        
        do {
            let results = try context.fetch(request)
            let progress: NSManagedObject
            
            if let existingProgress = results.first as? NSManagedObject {
                progress = existingProgress
            } else {
                progress = NSEntityDescription.insertNewObject(forEntityName: "PlayerProgress", into: context)
                progress.setValue("main_player", forKey: "playerId")
            }
            
            progress.setValue(currentLevel, forKey: "level")
            progress.setValue(currentExperience, forKey: "experience")
            progress.setValue(Array(unlockedFeatures), forKey: "unlockedFeatures")
            progress.setValue(Date(), forKey: "lastUpdated")
            
            // Save achievements
            let achievementData = try JSONEncoder().encode(achievements)
            progress.setValue(achievementData, forKey: "achievementsData")
            
            try context.save()
        } catch {
            print("Failed to save progress: \(error)")
        }
    }
    
    private func loadProgressFromCoreData() {
        let context = coreDataManager.context
        let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "PlayerProgress")
        request.predicate = NSPredicate(format: "playerId == %@", "main_player")
        
        do {
            let results = try context.fetch(request)
            if let progress = results.first as? NSManagedObject {
                currentLevel = progress.value(forKey: "level") as? Int ?? 1
                currentExperience = progress.value(forKey: "experience") as? Int ?? 0
                
                if let features = progress.value(forKey: "unlockedFeatures") as? [String] {
                    unlockedFeatures = Set(features)
                }
                
                if let achievementData = progress.value(forKey: "achievementsData") as? Data {
                    achievements = try JSONDecoder().decode([Achievement].self, from: achievementData)
                }
                
                // Update experience requirement for current level
                if let levelReq = levelRequirements.first(where: { $0.level == currentLevel + 1 }) {
                    experienceToNextLevel = levelReq.experienceRequired
                }
                
                updateLevelProgress()
            }
        } catch {
            print("Failed to load progress: \(error)")
        }
    }
    
    // MARK: - Game Center Integration
    
    private func authenticateGameCenter() {
        let localPlayer = GKLocalPlayer.local
        
        localPlayer.authenticateHandler = { [weak self] viewController, error in
            if let viewController = viewController {
                // Present authentication view controller
                NotificationCenter.default.post(
                    name: .presentGameCenterAuth,
                    object: nil,
                    userInfo: ["viewController": viewController]
                )
            } else if localPlayer.isAuthenticated {
                self?.isGameCenterAuthenticated = true
                self?.loadGameCenterData()
            } else {
                self?.isGameCenterAuthenticated = false
                print("Game Center authentication failed: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    private func loadGameCenterData() {
        // Load achievements from Game Center
        GKAchievement.loadAchievements { [weak self] achievements, error in
            if let achievements = achievements {
                for gcAchievement in achievements {
                    if let achievement = self?.achievements.first(where: { $0.id == gcAchievement.identifier }) {
                        achievement.progress = Float(gcAchievement.percentComplete)
                        achievement.isUnlocked = gcAchievement.isCompleted
                    }
                }
            }
        }
    }
    
    private func reportScoreToGameCenter(score: Int) {
        guard isGameCenterAuthenticated else { return }
        
        let scoreReporter = GKScore(leaderboardIdentifier: "com.flexport.total_experience")
        scoreReporter.value = Int64(score)
        
        GKScore.report([scoreReporter]) { error in
            if let error = error {
                print("Failed to report score: \(error)")
            }
        }
    }
    
    private func reportLevelToGameCenter(level: Int) {
        guard isGameCenterAuthenticated else { return }
        
        let scoreReporter = GKScore(leaderboardIdentifier: "com.flexport.player_level")
        scoreReporter.value = Int64(level)
        
        GKScore.report([scoreReporter]) { error in
            if let error = error {
                print("Failed to report level: \(error)")
            }
        }
    }
    
    private func reportAchievementToGameCenter(achievementId: String) {
        guard isGameCenterAuthenticated else { return }
        
        let achievement = GKAchievement(identifier: "com.flexport.\(achievementId)")
        achievement.percentComplete = 100.0
        achievement.showsCompletionBanner = true
        
        GKAchievement.report([achievement]) { error in
            if let error = error {
                print("Failed to report achievement: \(error)")
            }
        }
    }
}

// MARK: - Supporting Types

public struct LevelRequirement {
    let level: Int
    let experienceRequired: Int
    let unlocks: [String]
    let rewards: LevelReward?
}

public struct LevelReward {
    var cash: Int?
    var researchPoints: Int?
    var shipSlots: Int?
    var routeSlots: Int?
}

public struct ExperienceReward {
    let action: String
    let baseXP: Int
    let multipliers: [String: Float]?
    
    init(action: String, baseXP: Int, multipliers: [String: Float]? = nil) {
        self.action = action
        self.baseXP = baseXP
        self.multipliers = multipliers
    }
}

public class Achievement: Codable {
    let id: String
    let name: String
    let description: String
    var progress: Float
    let maxProgress: Float
    var isUnlocked: Bool
    var unlockedDate: Date?
    
    init(id: String, name: String, description: String, maxProgress: Float) {
        self.id = id
        self.name = name
        self.description = description
        self.progress = 0
        self.maxProgress = maxProgress
        self.isUnlocked = false
        self.unlockedDate = nil
    }
}

public struct ProgressInfo {
    let currentLevel: Int
    let nextLevel: Int
    let currentXP: Int
    let requiredXP: Int
    let progress: Float
}

// MARK: - Notifications

extension Notification.Name {
    static let levelUpRewards = Notification.Name("levelUpRewards")
    static let featureUnlocked = Notification.Name("featureUnlocked")
    static let achievementUnlocked = Notification.Name("achievementUnlocked")
    static let presentGameCenterAuth = Notification.Name("presentGameCenterAuth")
}