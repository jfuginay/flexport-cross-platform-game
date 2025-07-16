import Foundation
import Combine
import SwiftUI
import os.log

/// Container 7 integration coordinator for analytics, monetization, and LiveOps
@MainActor
public class Container7Coordinator: ObservableObject {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "FlexPort", category: "Container7")
    private var cancellables = Set<AnyCancellable>()
    
    // Core managers
    public let analyticsEngine: AnalyticsEngine
    public let playerBehaviorAnalyzer: PlayerBehaviorAnalyzer
    public let ethicalMonetizationManager: EthicalMonetizationManager
    public let abTestingManager: ABTestingManager
    public let liveOpsManager: LiveOpsManager
    public let retentionManager: RetentionManager
    public let analyticsDashboard: AnalyticsDashboard
    
    // Integration state
    @Published public private(set) var isInitialized = false
    @Published public private(set) var systemHealth: SystemHealthStatus = .unknown
    @Published public private(set) var activeFeatures: Set<Container7Feature> = []
    
    // Dependencies from other containers
    private let coreDataManager: CoreDataManager
    private let networkConfiguration: NetworkConfiguration
    
    // MARK: - Initialization
    
    public init(coreDataManager: CoreDataManager, networkConfiguration: NetworkConfiguration) {
        self.coreDataManager = coreDataManager
        self.networkConfiguration = networkConfiguration
        
        // Initialize core components
        self.analyticsEngine = AnalyticsEngine(
            coreDataManager: coreDataManager,
            networkConfiguration: networkConfiguration
        )
        
        self.playerBehaviorAnalyzer = PlayerBehaviorAnalyzer()
        
        self.ethicalMonetizationManager = EthicalMonetizationManager(
            analyticsEngine: analyticsEngine,
            playerBehaviorAnalyzer: playerBehaviorAnalyzer
        )
        
        self.abTestingManager = ABTestingManager(
            analyticsEngine: analyticsEngine,
            playerBehaviorAnalyzer: playerBehaviorAnalyzer
        )
        
        self.liveOpsManager = LiveOpsManager(
            analyticsEngine: analyticsEngine,
            playerBehaviorAnalyzer: playerBehaviorAnalyzer
        )
        
        self.retentionManager = RetentionManager(
            analyticsEngine: analyticsEngine,
            playerBehaviorAnalyzer: playerBehaviorAnalyzer
        )
        
        self.analyticsDashboard = AnalyticsDashboard(
            analyticsEngine: analyticsEngine,
            playerBehaviorAnalyzer: playerBehaviorAnalyzer,
            abTestingManager: abTestingManager,
            retentionManager: retentionManager,
            monetizationManager: ethicalMonetizationManager
        )
        
        setupIntegration()
        logger.info("Container 7 Coordinator initialized")
    }
    
    // MARK: - Public Interface
    
    /// Initialize all Container 7 systems
    public func initialize(userId: UUID? = nil) async {
        logger.info("Initializing Container 7 systems...")
        
        do {
            // Start analytics session
            let gameState = await getCurrentGameState()
            analyticsEngine.startSession(userId: userId, gameState: gameState)
            
            // Load monetization store
            await ethicalMonetizationManager.loadStore()
            
            // Refresh live content
            await liveOpsManager.refreshContent()
            
            // Check retention interventions
            if let userId = userId {
                retentionManager.checkRetentionInterventions(playerId: userId)
            }
            
            // Update system health
            systemHealth = await checkSystemHealth()
            
            // Mark as initialized
            isInitialized = true
            activeFeatures = getAllActiveFeatures()
            
            logger.info("Container 7 systems initialized successfully")
            
        } catch {
            logger.error("Failed to initialize Container 7: \(error.localizedDescription)")
            systemHealth = .error
        }
    }
    
    /// Shutdown all Container 7 systems
    public func shutdown() {
        logger.info("Shutting down Container 7 systems...")
        
        let gameState = getCurrentGameStateSync()
        analyticsEngine.endCurrentSession(gameState: gameState)
        analyticsEngine.uploadEvents()
        
        isInitialized = false
        systemHealth = .shutdown
        activeFeatures.removeAll()
        
        logger.info("Container 7 systems shut down")
    }
    
    /// Handle player login
    public func handlePlayerLogin(userId: UUID, profile: PlayerBehaviorProfile?) {
        // Update analytics
        if let profile = profile {
            playerBehaviorAnalyzer.updateProfile(
                from: createMockSession(userId: userId),
                userId: userId
            )
        }
        
        // Check for personalized offers
        let recommendations = ethicalMonetizationManager.getPersonalizedRecommendations(for: userId)
        if !recommendations.isEmpty {
            logger.info("Found \(recommendations.count) personalized offers for player \(userId)")
        }
        
        // Check daily rewards
        if retentionManager.canClaimDailyReward(playerId: userId) {
            logger.info("Daily reward available for player \(userId)")
        }
        
        // Check active events
        let activeEvents = liveOpsManager.getActiveEvents(for: userId)
        logger.info("Player \(userId) eligible for \(activeEvents.count) active events")
        
        // Track login event
        analyticsEngine.trackEvent(.sessionStart, parameters: [
            "user_id": .string(userId.uuidString),
            "login_type": .string("standard")
        ])
    }
    
    /// Handle player logout
    public func handlePlayerLogout(userId: UUID) {
        // End analytics session
        let gameState = getCurrentGameStateSync()
        analyticsEngine.endCurrentSession(gameState: gameState)
        
        // Track logout event
        analyticsEngine.trackEvent(.sessionEnd, parameters: [
            "user_id": .string(userId.uuidString)
        ])
        
        logger.info("Player \(userId) logged out")
    }
    
    /// Handle game state changes
    public func handleGameStateChange(_ change: GameStateChange) {
        let userId = change.playerId
        
        switch change.changeType {
        case .levelUp:
            // Update achievement progress
            retentionManager.updateAchievementProgress(
                playerId: userId,
                achievementId: "level_progression",
                value: 1
            )
            
            // Track analytics
            analyticsEngine.trackEvent(.levelUp, parameters: [
                "user_id": .string(userId.uuidString),
                "new_level": .integer(change.newValue),
                "previous_level": .integer(change.oldValue)
            ])
            
        case .purchaseCompleted:
            // Record monetization event
            ethicalMonetizationManager.recordConversion(
                userId: userId,
                experimentId: UUID(), // Would get from active experiment
                value: change.newValue
            )
            
            // Add loyalty points
            retentionManager.addLoyaltyPoints(
                playerId: userId,
                points: Int(change.newValue / 100), // 1 point per $1
                reason: "Purchase completed",
                action: .earnRevenue
            )
            
        case .achievementUnlocked:
            // Track analytics
            analyticsEngine.trackEvent(.achievementUnlocked, parameters: [
                "user_id": .string(userId.uuidString),
                "achievement_id": .string("achievement_\(change.newValue)")
            ])
            
        case .routeCompleted:
            // Update milestone progress
            retentionManager.updateMilestoneProgress(
                playerId: userId,
                metric: .routesCompleted,
                value: 1
            )
            
            // Update achievement progress
            retentionManager.updateAchievementProgress(
                playerId: userId,
                achievementId: "route_master",
                value: 1
            )
            
        case .eventParticipation:
            // Track event participation
            analyticsEngine.trackEvent(.specialEvents, parameters: [
                "user_id": .string(userId.uuidString),
                "event_id": .string("event_\(change.newValue)"),
                "action": .string("participated")
            ])
        }
        
        // Check for retention interventions after significant changes
        retentionManager.checkRetentionInterventions(playerId: userId)
    }
    
    /// Get comprehensive player insights
    public func getPlayerInsights(for userId: UUID) -> PlayerInsights {
        let behaviorProfile = playerBehaviorAnalyzer.getProfile(for: userId)
        let loyaltyStatus = retentionManager.getLoyaltyStatus(playerId: userId)
        let dailyRewardPreview = retentionManager.getDailyRewardPreview(playerId: userId)
        let activeEvents = liveOpsManager.getActiveEvents(for: userId)
        let recommendedOffers = ethicalMonetizationManager.getPersonalizedRecommendations(for: userId)
        
        return PlayerInsights(
            userId: userId,
            behaviorProfile: behaviorProfile,
            loyaltyStatus: loyaltyStatus,
            dailyRewardPreview: dailyRewardPreview,
            activeEvents: activeEvents,
            recommendedOffers: recommendedOffers,
            generatedAt: Date()
        )
    }
    
    /// Get system-wide analytics summary
    public func getAnalyticsSummary() -> AnalyticsSummary {
        let segments = playerBehaviorAnalyzer.getPlayerSegments()
        let churnRiskPlayers = playerBehaviorAnalyzer.getHighChurnRiskPlayers()
        let highValuePlayers = playerBehaviorAnalyzer.getHighValuePlayers()
        
        return AnalyticsSummary(
            totalActivePlayers: segments.regularPlayers.count + segments.newPlayers.count,
            newPlayers: segments.newPlayers.count,
            atRiskPlayers: segments.atRiskPlayers.count,
            highValuePlayers: highValuePlayers.count,
            activeExperiments: abTestingManager.activeExperiments.count,
            activeEvents: liveOpsManager.activeEvents.count,
            systemHealth: systemHealth,
            lastUpdated: Date()
        )
    }
    
    // MARK: - A/B Testing Integration
    
    /// Get A/B test variant for a feature
    public func getABTestVariant<T>(
        feature: String,
        userId: UUID,
        defaultValue: T,
        experimentId: UUID? = nil
    ) -> T {
        // Find active experiment for this feature
        let activeExperiments = abTestingManager.getActiveExperiments(for: userId)
        
        if let experiment = activeExperiments.first(where: { $0.name.contains(feature) }) {
            return abTestingManager.getVariantValue(
                feature,
                for: userId,
                experiment: experiment.id,
                defaultValue: defaultValue
            )
        }
        
        return defaultValue
    }
    
    /// Track A/B test conversion
    public func trackABTestConversion(userId: UUID, experimentId: UUID, value: Double = 1.0) {
        abTestingManager.recordConversion(
            userId: userId,
            experimentId: experimentId,
            value: value
        )
    }
    
    // MARK: - Private Methods
    
    private func setupIntegration() {
        // Set up data flow between systems
        setupAnalyticsIntegration()
        setupMonetizationIntegration()
        setupRetentionIntegration()
        setupLiveOpsIntegration()
        
        // Monitor system health
        setupHealthMonitoring()
    }
    
    private func setupAnalyticsIntegration() {
        // Connect analytics to other systems
        analyticsEngine.$currentSession
            .compactMap { $0 }
            .sink { [weak self] session in
                if let userId = session.userId {
                    self?.playerBehaviorAnalyzer.updateProfile(from: session, userId: userId)
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupMonetizationIntegration() {
        // Connect monetization to analytics and retention
        ethicalMonetizationManager.$purchaseHistory
            .compactMap { $0 }
            .sink { [weak self] history in
                // Update loyalty points for purchases
                // Implementation would sync purchase data
            }
            .store(in: &cancellables)
    }
    
    private func setupRetentionIntegration() {
        // Connect retention systems to analytics
        retentionManager.$playerDailyProgress
            .sink { [weak self] dailyProgress in
                // Track daily reward metrics
                for (playerId, progress) in dailyProgress {
                    if progress.canClaimToday {
                        self?.analyticsEngine.trackEvent(.featureUsed, parameters: [
                            "feature_name": .string("daily_reward_available"),
                            "player_id": .string(playerId.uuidString),
                            "streak": .integer(progress.currentStreak)
                        ])
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupLiveOpsIntegration() {
        // Connect live ops to analytics and retention
        liveOpsManager.$activeEvents
            .sink { [weak self] events in
                self?.analyticsEngine.trackEvent(.featureUsed, parameters: [
                    "feature_name": .string("active_events_updated"),
                    "event_count": .integer(events.count)
                ])
            }
            .store(in: &cancellables)
    }
    
    private func setupHealthMonitoring() {
        // Monitor system health every 5 minutes
        Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.updateSystemHealth()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateSystemHealth() async {
        systemHealth = await checkSystemHealth()
    }
    
    private func checkSystemHealth() async -> SystemHealthStatus {
        var healthChecks: [Bool] = []
        
        // Check analytics engine
        healthChecks.append(analyticsEngine.isTrackingEnabled)
        
        // Check monetization manager
        healthChecks.append(ethicalMonetizationManager.isStoreLoaded)
        
        // Check if all systems are responsive
        healthChecks.append(isInitialized)
        
        let healthyCount = healthChecks.filter { $0 }.count
        let totalChecks = healthChecks.count
        
        switch Double(healthyCount) / Double(totalChecks) {
        case 1.0:
            return .healthy
        case 0.5..<1.0:
            return .degraded
        case 0.1..<0.5:
            return .warning
        default:
            return .error
        }
    }
    
    private func getAllActiveFeatures() -> Set<Container7Feature> {
        var features: Set<Container7Feature> = []
        
        if analyticsEngine.isTrackingEnabled {
            features.insert(.analytics)
        }
        
        if ethicalMonetizationManager.isStoreLoaded {
            features.insert(.monetization)
        }
        
        if !abTestingManager.activeExperiments.isEmpty {
            features.insert(.abTesting)
        }
        
        if !liveOpsManager.activeEvents.isEmpty {
            features.insert(.liveOps)
        }
        
        features.insert(.retention) // Always active
        features.insert(.dashboard) // Always active
        
        return features
    }
    
    private func getCurrentGameState() async -> GameStateSnapshot {
        // This would collect actual game state from other containers
        return GameStateSnapshot(
            playerLevel: 1,
            totalShips: 0,
            totalWarehouses: 0,
            currentCash: 10000.0,
            activeRoutes: 0,
            gameTime: 0,
            currentScreen: "main_menu",
            tutorialProgress: 0.0,
            hasCompletedTutorial: false,
            achievementsUnlocked: 0,
            totalPlayTime: 0
        )
    }
    
    private func getCurrentGameStateSync() -> GameStateSnapshot {
        // Synchronous version for shutdown
        return GameStateSnapshot(
            playerLevel: 1,
            totalShips: 0,
            totalWarehouses: 0,
            currentCash: 10000.0,
            activeRoutes: 0,
            gameTime: 0,
            currentScreen: "main_menu",
            tutorialProgress: 0.0,
            hasCompletedTutorial: false,
            achievementsUnlocked: 0,
            totalPlayTime: 0
        )
    }
    
    private func createMockSession(userId: UUID) -> PlayerSession {
        let deviceInfo = DeviceInfo(
            deviceModel: "iPhone",
            osVersion: "iOS 17",
            screenSize: "390x844",
            memoryGB: 6.0,
            storageGB: 128.0,
            batteryLevel: 0.8,
            networkType: "WiFi",
            timezone: "UTC",
            locale: "en_US"
        )
        
        return PlayerSession(
            userId: userId,
            appVersion: "1.0.0",
            deviceInfo: deviceInfo,
            gameStateAtStart: getCurrentGameStateSync()
        )
    }
}

// MARK: - Supporting Types

public enum Container7Feature: String, CaseIterable {
    case analytics = "analytics"
    case monetization = "monetization"
    case abTesting = "ab_testing"
    case liveOps = "live_ops"
    case retention = "retention"
    case dashboard = "dashboard"
}

public enum SystemHealthStatus: String, Codable {
    case unknown = "unknown"
    case healthy = "healthy"
    case degraded = "degraded"
    case warning = "warning"
    case error = "error"
    case shutdown = "shutdown"
    
    public var color: String {
        switch self {
        case .unknown: return "#808080"
        case .healthy: return "#00FF00"
        case .degraded: return "#FFA500"
        case .warning: return "#FFFF00"
        case .error: return "#FF0000"
        case .shutdown: return "#000000"
        }
    }
}

public struct GameStateChange {
    public let playerId: UUID
    public let changeType: GameStateChangeType
    public let oldValue: Double
    public let newValue: Double
    public let timestamp: Date
    
    public init(playerId: UUID, changeType: GameStateChangeType, oldValue: Double, newValue: Double) {
        self.playerId = playerId
        self.changeType = changeType
        self.oldValue = oldValue
        self.newValue = newValue
        self.timestamp = Date()
    }
}

public enum GameStateChangeType {
    case levelUp
    case purchaseCompleted
    case achievementUnlocked
    case routeCompleted
    case eventParticipation
}

public struct PlayerInsights {
    public let userId: UUID
    public let behaviorProfile: PlayerBehaviorProfile?
    public let loyaltyStatus: PlayerLoyaltyStatus?
    public let dailyRewardPreview: DailyRewardPreview?
    public let activeEvents: [LiveEvent]
    public let recommendedOffers: [ItemRecommendation]
    public let generatedAt: Date
    
    public init(userId: UUID, behaviorProfile: PlayerBehaviorProfile?,
                loyaltyStatus: PlayerLoyaltyStatus?, dailyRewardPreview: DailyRewardPreview?,
                activeEvents: [LiveEvent], recommendedOffers: [ItemRecommendation],
                generatedAt: Date) {
        self.userId = userId
        self.behaviorProfile = behaviorProfile
        self.loyaltyStatus = loyaltyStatus
        self.dailyRewardPreview = dailyRewardPreview
        self.activeEvents = activeEvents
        self.recommendedOffers = recommendedOffers
        self.generatedAt = generatedAt
    }
}

public struct AnalyticsSummary {
    public let totalActivePlayers: Int
    public let newPlayers: Int
    public let atRiskPlayers: Int
    public let highValuePlayers: Int
    public let activeExperiments: Int
    public let activeEvents: Int
    public let systemHealth: SystemHealthStatus
    public let lastUpdated: Date
    
    public init(totalActivePlayers: Int, newPlayers: Int, atRiskPlayers: Int,
                highValuePlayers: Int, activeExperiments: Int, activeEvents: Int,
                systemHealth: SystemHealthStatus, lastUpdated: Date) {
        self.totalActivePlayers = totalActivePlayers
        self.newPlayers = newPlayers
        self.atRiskPlayers = atRiskPlayers
        self.highValuePlayers = highValuePlayers
        self.activeExperiments = activeExperiments
        self.activeEvents = activeEvents
        self.systemHealth = systemHealth
        self.lastUpdated = lastUpdated
    }
}

// MARK: - SwiftUI Integration

extension Container7Coordinator {
    /// Create SwiftUI environment object
    public func createEnvironmentObject() -> some View {
        EmptyView()
            .environmentObject(self)
            .environmentObject(analyticsEngine)
            .environmentObject(playerBehaviorAnalyzer)
            .environmentObject(ethicalMonetizationManager)
            .environmentObject(abTestingManager)
            .environmentObject(liveOpsManager)
            .environmentObject(retentionManager)
            .environmentObject(analyticsDashboard)
    }
}

// MARK: - Logging Extension

extension Container7Coordinator {
    /// Log comprehensive system status
    public func logSystemStatus() {
        logger.info("=== Container 7 System Status ===")
        logger.info("Initialized: \(isInitialized)")
        logger.info("Health: \(systemHealth.rawValue)")
        logger.info("Active Features: \(activeFeatures.map { $0.rawValue }.joined(separator: ", "))")
        logger.info("Analytics Tracking: \(analyticsEngine.isTrackingEnabled)")
        logger.info("Store Loaded: \(ethicalMonetizationManager.isStoreLoaded)")
        logger.info("Active Experiments: \(abTestingManager.activeExperiments.count)")
        logger.info("Active Events: \(liveOpsManager.activeEvents.count)")
        logger.info("================================")
    }
}