import Foundation
import Combine
import os.log

/// Advanced player behavior analysis and segmentation system
public class PlayerBehaviorAnalyzer: ObservableObject {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "FlexPort", category: "BehaviorAnalyzer")
    
    @Published public private(set) var playerProfiles: [UUID: PlayerBehaviorProfile] = [:]
    @Published public private(set) var cohorts: [String: PlayerCohort] = [:]
    @Published public private(set) var funnels: [String: AnalyticsFunnel] = [:]
    
    private var sessionHistory: [UUID: [PlayerSession]] = [:]
    private let retentionCalculator = RetentionCalculator()
    private let churnPredictor = ChurnPredictor()
    private let ltv 
: LTVCalculator()
    
    // MARK: - Initialization
    
    public init() {
        setupDefaultFunnels()
        logger.info("Player behavior analyzer initialized")
    }
    
    // MARK: - Profile Management
    
    /// Update player behavior profile from session data
    public func updateProfile(from session: PlayerSession, userId: UUID) {
        var profile = playerProfiles[userId] ?? PlayerBehaviorProfile(playerId: userId)
        
        // Update session statistics
        profile.totalSessions += 1
        profile.totalPlayTime += session.duration
        profile.averageSessionDuration = profile.totalPlayTime / Double(profile.totalSessions)
        profile.lastActive = session.endTime ?? Date()
        
        // Analyze session patterns
        updateSessionFrequency(&profile, session: session)
        updateGameplayStyle(&profile, session: session)
        updateSocialEngagement(&profile, session: session)
        updateProgressionRate(&profile, session: session)
        updateRetentionRisk(&profile)
        
        // Store session history
        sessionHistory[userId, default: []].append(session)
        
        // Keep only last 30 sessions for analysis
        if sessionHistory[userId]!.count > 30 {
            sessionHistory[userId]!.removeFirst()
        }
        
        playerProfiles[userId] = profile
        
        // Update cohort if player is new
        if profile.totalSessions == 1 {
            addPlayerToCohort(userId: userId, session: session)
        }
        
        logger.debug("Updated behavior profile for player \(userId)")
    }
    
    /// Get player behavior profile
    public func getProfile(for playerId: UUID) -> PlayerBehaviorProfile? {
        return playerProfiles[playerId]
    }
    
    /// Get all player profiles matching criteria
    public func getProfiles(matching criteria: ProfileCriteria) -> [PlayerBehaviorProfile] {
        return playerProfiles.values.filter { profile in
            criteria.matches(profile)
        }
    }
    
    // MARK: - Cohort Analysis
    
    /// Get cohort by name
    public func getCohort(named cohortName: String) -> PlayerCohort? {
        return cohorts[cohortName]
    }
    
    /// Calculate retention rates for all cohorts
    public func calculateRetentionRates() {
        for (cohortName, var cohort) in cohorts {
            cohort.retentionData = retentionCalculator.calculateRetention(for: cohort, sessions: sessionHistory)
            cohorts[cohortName] = cohort
        }
        logger.info("Updated retention rates for \(cohorts.count) cohorts")
    }
    
    /// Get top performing cohorts
    public func getTopPerformingCohorts(limit: Int = 10) -> [PlayerCohort] {
        return Array(cohorts.values.sorted { 
            $0.retentionRate(day: 7) > $1.retentionRate(day: 7) 
        }.prefix(limit))
    }
    
    // MARK: - Funnel Analysis
    
    /// Get funnel by name
    public func getFunnel(named funnelName: String) -> AnalyticsFunnel? {
        return funnels[funnelName]
    }
    
    /// Update funnel with new event data
    public func updateFunnel(_ funnelName: String, with events: [AnalyticsEvent]) {
        guard var funnel = funnels[funnelName] else { return }
        
        let userJourneys = groupEventsByUser(events)
        
        for (_, userEvents) in userJourneys {
            updateFunnelSteps(&funnel, with: userEvents)
        }
        
        funnels[funnelName] = funnel
        logger.debug("Updated funnel \(funnelName)")
    }
    
    // MARK: - Churn Prediction
    
    /// Predict churn risk for all players
    public func predictChurnRisk() -> [UUID: Double] {
        return churnPredictor.predictChurnProbabilities(from: playerProfiles.values)
    }
    
    /// Get players at high risk of churning
    public func getHighChurnRiskPlayers(threshold: Double = 0.7) -> [PlayerBehaviorProfile] {
        let churnProbabilities = predictChurnRisk()
        
        return playerProfiles.values.filter { profile in
            (churnProbabilities[profile.playerId] ?? 0) >= threshold
        }
    }
    
    // MARK: - LTV Analysis
    
    /// Calculate LTV for all players
    public func calculateLTV() -> [UUID: Double] {
        return ltvCalculator.calculateLTV(from: playerProfiles.values, sessions: sessionHistory)
    }
    
    /// Get highest value players
    public func getHighValuePlayers(limit: Int = 100) -> [PlayerBehaviorProfile] {
        let ltvData = calculateLTV()
        
        return playerProfiles.values.sorted { 
            (ltvData[$0.playerId] ?? 0) > (ltvData[$1.playerId] ?? 0)
        }.prefix(limit).map { $0 }
    }
    
    // MARK: - Segmentation
    
    /// Get player segments
    public func getPlayerSegments() -> PlayerSegments {
        let profiles = Array(playerProfiles.values)
        
        return PlayerSegments(
            newPlayers: profiles.filter { $0.totalSessions <= 3 },
            regularPlayers: profiles.filter { $0.sessionFrequency == .regular },
            atRiskPlayers: profiles.filter { $0.retentionRisk == .high || $0.retentionRisk == .critical },
            whales: profiles.filter { $0.spendingBehavior == .whale },
            socialPlayers: profiles.filter { $0.socialEngagement == .active || $0.socialEngagement == .leader }
        )
    }
    
    // MARK: - Private Methods
    
    private func setupDefaultFunnels() {
        // Tutorial funnel
        let tutorialFunnel = AnalyticsFunnel(
            funnelName: "tutorial",
            description: "Player tutorial completion",
            steps: [
                FunnelStep(stepName: "Game Started", stepOrder: 1, eventType: .gameStart),
                FunnelStep(stepName: "Tutorial Step 1", stepOrder: 2, eventType: .tutorialStep, requiredParameters: ["step"]),
                FunnelStep(stepName: "First Ship Purchased", stepOrder: 3, eventType: .shipPurchased),
                FunnelStep(stepName: "First Route Created", stepOrder: 4, eventType: .tradeRouteCreated),
                FunnelStep(stepName: "Tutorial Completed", stepOrder: 5, eventType: .tutorialComplete)
            ],
            timeframe: 3600 // 1 hour
        )
        
        // Monetization funnel
        let monetizationFunnel = AnalyticsFunnel(
            funnelName: "monetization",
            description: "Purchase conversion funnel",
            steps: [
                FunnelStep(stepName: "Store Viewed", stepOrder: 1, eventType: .storeViewed),
                FunnelStep(stepName: "Item Considered", stepOrder: 2, eventType: .itemConsidered),
                FunnelStep(stepName: "Purchase Initiated", stepOrder: 3, eventType: .purchaseInitiated),
                FunnelStep(stepName: "Purchase Completed", stepOrder: 4, eventType: .purchaseCompleted)
            ],
            timeframe: 1800 // 30 minutes
        )
        
        funnels["tutorial"] = tutorialFunnel
        funnels["monetization"] = monetizationFunnel
    }
    
    private func updateSessionFrequency(_ profile: inout PlayerBehaviorProfile, session: PlayerSession) {
        guard let sessions = sessionHistory[profile.playerId], sessions.count >= 2 else {
            profile.sessionFrequency = .unknown
            return
        }
        
        let recentSessions = Array(sessions.suffix(10))
        let intervals = zip(recentSessions.dropFirst(), recentSessions).map { 
            $0.startTime.timeIntervalSince($1.startTime) 
        }
        
        let averageInterval = intervals.reduce(0, +) / Double(intervals.count)
        let daysBetweenSessions = averageInterval / 86400 // Convert to days
        
        switch daysBetweenSessions {
        case 0..<1:
            profile.sessionFrequency = .frequent
        case 1..<2:
            profile.sessionFrequency = .daily
        case 2..<4:
            profile.sessionFrequency = .regular
        case 4..<8:
            profile.sessionFrequency = .occasional
        default:
            profile.sessionFrequency = .rare
        }
    }
    
    private func updateGameplayStyle(_ profile: inout PlayerBehaviorProfile, session: PlayerSession) {
        let economicEvents = session.events.filter { 
            [.tradeRouteCreated, .commodityTraded, .profitGenerated].contains($0.eventType) 
        }
        
        let socialEvents = session.events.filter { 
            [.allianceJoined, .playerInteraction].contains($0.eventType) 
        }
        
        let explorationEvents = session.events.filter { 
            $0.eventType == .screenViewed 
        }
        
        // Analyze predominant behavior patterns
        if economicEvents.count > socialEvents.count + explorationEvents.count {
            profile.gameplayStyle = .economic
        } else if socialEvents.count > economicEvents.count {
            profile.gameplayStyle = .social
        } else if session.duration > 3600 { // Sessions longer than 1 hour
            profile.gameplayStyle = .hardcore
        } else if explorationEvents.count > economicEvents.count + socialEvents.count {
            profile.gameplayStyle = .explorer
        } else {
            profile.gameplayStyle = .casual
        }
    }
    
    private func updateSocialEngagement(_ profile: inout PlayerBehaviorProfile, session: PlayerSession) {
        let socialEvents = session.events.filter { 
            [.allianceJoined, .playerInteraction, .leaderboardViewed].contains($0.eventType) 
        }
        
        switch socialEvents.count {
        case 0:
            profile.socialEngagement = .solo
        case 1...3:
            profile.socialEngagement = .casual
        case 4...10:
            profile.socialEngagement = .active
        default:
            profile.socialEngagement = .leader
        }
    }
    
    private func updateProgressionRate(_ profile: inout PlayerBehaviorProfile, session: PlayerSession) {
        let progressEvents = session.events.filter { 
            [.levelUp, .achievementUnlocked, .shipPurchased, .tradeRouteCompleted].contains($0.eventType) 
        }
        
        let progressRate = Double(progressEvents.count) / session.duration * 3600 // Events per hour
        
        switch progressRate {
        case 0..<0.5:
            profile.progressionRate = .slow
        case 0.5..<2.0:
            profile.progressionRate = .normal
        case 2.0..<5.0:
            profile.progressionRate = .fast
        default:
            profile.progressionRate = .expert
        }
    }
    
    private func updateRetentionRisk(_ profile: inout PlayerBehaviorProfile) {
        let daysSinceLastActive = Date().timeIntervalSince(profile.lastActive) / 86400
        
        switch daysSinceLastActive {
        case 0..<1:
            profile.retentionRisk = .low
        case 1..<3:
            profile.retentionRisk = .medium
        case 3..<7:
            profile.retentionRisk = .high
        default:
            profile.retentionRisk = .critical
        }
    }
    
    private func addPlayerToCohort(userId: UUID, session: PlayerSession) {
        let cohortDate = Calendar.current.startOfDay(for: session.startTime)
        let cohortName = DateFormatter().string(from: cohortDate)
        
        if var cohort = cohorts[cohortName] {
            cohort.playerIds.insert(userId)
            cohorts[cohortName] = cohort
        } else {
            var newCohort = PlayerCohort(cohortDate: cohortDate, cohortName: cohortName)
            newCohort.playerIds.insert(userId)
            cohorts[cohortName] = newCohort
        }
    }
    
    private func groupEventsByUser(_ events: [AnalyticsEvent]) -> [UUID: [AnalyticsEvent]] {
        var userEvents: [UUID: [AnalyticsEvent]] = [:]
        
        for event in events {
            // Group by session ID for now, would need user ID mapping
            userEvents[event.sessionId, default: []].append(event)
        }
        
        return userEvents
    }
    
    private func updateFunnelSteps(_ funnel: inout AnalyticsFunnel, with events: [AnalyticsEvent]) {
        let sortedEvents = events.sorted { $0.timestamp < $1.timestamp }
        var currentStepIndex = 0
        
        for event in sortedEvents {
            guard currentStepIndex < funnel.steps.count else { break }
            
            let currentStep = funnel.steps[currentStepIndex]
            if event.eventType == currentStep.eventType {
                funnel.steps[currentStepIndex].completions += 1
                currentStepIndex += 1
            }
        }
        
        // Count drop-offs for incomplete funnels
        if currentStepIndex < funnel.steps.count {
            for i in currentStepIndex..<funnel.steps.count {
                funnel.steps[i].dropOffs += 1
            }
        }
    }
}

// MARK: - Supporting Classes

/// Calculates retention rates for player cohorts
private class RetentionCalculator {
    
    func calculateRetention(for cohort: PlayerCohort, sessions: [UUID: [PlayerSession]]) -> [Int: Double] {
        var retentionData: [Int: Double] = [:]
        
        let cohortPlayers = cohort.playerIds
        let cohortDate = cohort.cohortDate
        
        for day in [1, 3, 7, 14, 30] {
            let targetDate = Calendar.current.date(byAdding: .day, value: day, to: cohortDate)!
            let activePlayersOnDay = cohortPlayers.filter { playerId in
                guard let playerSessions = sessions[playerId] else { return false }
                return playerSessions.contains { session in
                    Calendar.current.isDate(session.startTime, inSameDayAs: targetDate)
                }
            }
            
            retentionData[day] = Double(activePlayersOnDay.count) / Double(cohortPlayers.count)
        }
        
        return retentionData
    }
}

/// Predicts player churn using behavior patterns
private class ChurnPredictor {
    
    func predictChurnProbabilities(from profiles: [PlayerBehaviorProfile]) -> [UUID: Double] {
        var predictions: [UUID: Double] = [:]
        
        for profile in profiles {
            let churnScore = calculateChurnScore(for: profile)
            predictions[profile.playerId] = churnScore
        }
        
        return predictions
    }
    
    private func calculateChurnScore(for profile: PlayerBehaviorProfile) -> Double {
        var score = 0.0
        
        // Days since last active (weighted heavily)
        let daysSinceActive = Date().timeIntervalSince(profile.lastActive) / 86400
        score += min(daysSinceActive * 0.15, 0.6) // Max 0.6 from inactivity
        
        // Session frequency
        switch profile.sessionFrequency {
        case .rare: score += 0.3
        case .occasional: score += 0.2
        case .regular: score += 0.1
        case .daily, .frequent: score += 0.0
        case .unknown: score += 0.15
        }
        
        // Average session duration (very short sessions indicate disengagement)
        if profile.averageSessionDuration < 300 { // Less than 5 minutes
            score += 0.2
        }
        
        // Progression rate
        switch profile.progressionRate {
        case .slow: score += 0.15
        case .normal: score += 0.05
        case .fast, .expert: score += 0.0
        case .unknown: score += 0.1
        }
        
        return min(score, 1.0) // Cap at 1.0
    }
}

/// Calculates customer lifetime value
private class LTVCalculator {
    
    func calculateLTV(from profiles: [PlayerBehaviorProfile], sessions: [UUID: [PlayerSession]]) -> [UUID: Double] {
        var ltvData: [UUID: Double] = [:]
        
        for profile in profiles {
            let ltv = calculatePlayerLTV(profile: profile, sessions: sessions[profile.playerId] ?? [])
            ltvData[profile.playerId] = ltv
        }
        
        return ltvData
    }
    
    private func calculatePlayerLTV(profile: PlayerBehaviorProfile, sessions: [PlayerSession]) -> Double {
        // Simple LTV calculation based on engagement and spending patterns
        let engagementValue = profile.averageSessionDuration * 0.01 // Base value from engagement
        let loyaltyMultiplier = getLoyaltyMultiplier(for: profile.sessionFrequency)
        let spendingValue = getSpendingValue(for: profile.spendingBehavior)
        
        return (engagementValue * loyaltyMultiplier) + spendingValue
    }
    
    private func getLoyaltyMultiplier(for frequency: SessionFrequency) -> Double {
        switch frequency {
        case .frequent: return 3.0
        case .daily: return 2.5
        case .regular: return 2.0
        case .occasional: return 1.5
        case .rare: return 1.0
        case .unknown: return 1.0
        }
    }
    
    private func getSpendingValue(for behavior: SpendingBehavior) -> Double {
        switch behavior {
        case .whale: return 500.0
        case .dolphin: return 50.0
        case .minnow: return 5.0
        case .nonSpender: return 0.0
        case .unknown: return 0.0
        }
    }
}

// MARK: - Supporting Types

public struct ProfileCriteria {
    let sessionFrequency: SessionFrequency?
    let gameplayStyle: GameplayStyle?
    let spendingBehavior: SpendingBehavior?
    let retentionRisk: RetentionRisk?
    let minSessions: Int?
    let maxDaysSinceActive: Int?
    
    func matches(_ profile: PlayerBehaviorProfile) -> Bool {
        if let frequency = sessionFrequency, profile.sessionFrequency != frequency { return false }
        if let style = gameplayStyle, profile.gameplayStyle != style { return false }
        if let spending = spendingBehavior, profile.spendingBehavior != spending { return false }
        if let risk = retentionRisk, profile.retentionRisk != risk { return false }
        if let minSessions = minSessions, profile.totalSessions < minSessions { return false }
        
        if let maxDays = maxDaysSinceActive {
            let daysSinceActive = Date().timeIntervalSince(profile.lastActive) / 86400
            if daysSinceActive > Double(maxDays) { return false }
        }
        
        return true
    }
}

public struct PlayerSegments {
    let newPlayers: [PlayerBehaviorProfile]
    let regularPlayers: [PlayerBehaviorProfile]
    let atRiskPlayers: [PlayerBehaviorProfile]
    let whales: [PlayerBehaviorProfile]
    let socialPlayers: [PlayerBehaviorProfile]
}