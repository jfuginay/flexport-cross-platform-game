import Foundation
import Combine

/// Manages tournaments, competitive events, and seasonal competitions
class TournamentManager: ObservableObject {
    static let shared = TournamentManager()
    
    @Published private(set) var activeTournaments: [Tournament] = []
    @Published private(set) var currentParticipation: [TournamentParticipation] = []
    @Published private(set) var tournamentHistory: [Tournament] = []
    @Published private(set) var leaderboards: [TournamentLeaderboard] = []
    @Published private(set) var seasonalEvents: [SeasonalEvent] = []
    @Published private(set) var rewards: [TournamentReward] = []
    
    private let apiClient = APIClient.shared
    private let multiplayerManager = MultiplayerManager.shared
    private let securityManager = SecurityManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Tournament state tracking
    @Published private(set) var registrationStatus: [String: RegistrationStatus] = [:]
    @Published private(set) var matchProgress: [String: MatchProgress] = [:]
    @Published private(set) var spectatorCounts: [String: Int] = [:]
    
    private init() {
        setupTournamentMonitoring()
        loadActiveTournaments()
    }
    
    private func setupTournamentMonitoring() {
        // Monitor for tournament-related network messages
        NotificationCenter.default.addObserver(
            forName: .tournamentUpdateReceived,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let update = notification.object as? TournamentUpdate {
                self?.handleTournamentUpdate(update)
            }
        }
        
        // Periodic tournament refresh
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task {
                await self.refreshTournamentData()
            }
        }
    }
    
    // MARK: - Tournament Discovery & Registration
    
    /// Load available tournaments
    func loadAvailableTournaments(category: TournamentCategory? = nil) async {
        do {
            let tournaments = try await apiClient.getAvailableTournaments(category: category)
            
            await MainActor.run {
                self.activeTournaments = tournaments.filter { $0.status != .completed }
                self.tournamentHistory = tournaments.filter { $0.status == .completed }
            }
            
        } catch {
            print("Failed to load tournaments: \(error)")
        }
    }
    
    /// Register for a tournament
    func registerForTournament(_ tournamentId: String) async throws {
        let playerId = getCurrentPlayerId()
        
        // Check eligibility
        guard let tournament = activeTournaments.first(where: { $0.id == tournamentId }) else {
            throw TournamentError.tournamentNotFound
        }
        
        try validateTournamentEligibility(tournament, playerId: playerId)
        
        let registration = TournamentRegistration(
            tournamentId: tournamentId,
            playerId: playerId,
            timestamp: Date(),
            teamId: nil
        )
        
        try await apiClient.registerForTournament(registration: registration)
        
        await MainActor.run {
            self.registrationStatus[tournamentId] = .registered
        }
        
        await broadcastTournamentAction(.playerRegistered(tournamentId, playerId))
    }
    
    /// Unregister from a tournament
    func unregisterFromTournament(_ tournamentId: String) async throws {
        let playerId = getCurrentPlayerId()
        
        try await apiClient.unregisterFromTournament(tournamentId: tournamentId, playerId: playerId)
        
        await MainActor.run {
            self.registrationStatus[tournamentId] = .unregistered
            self.currentParticipation.removeAll { $0.tournamentId == tournamentId }
        }
        
        await broadcastTournamentAction(.playerUnregistered(tournamentId, playerId))
    }
    
    /// Register team for tournament
    func registerTeamForTournament(_ tournamentId: String, teamMembers: [String], teamName: String) async throws {
        guard let tournament = activeTournaments.first(where: { $0.id == tournamentId }) else {
            throw TournamentError.tournamentNotFound
        }
        
        guard tournament.format.supportsTeams else {
            throw TournamentError.teamsNotSupported
        }
        
        // Validate team size
        guard teamMembers.count >= tournament.format.minTeamSize &&
              teamMembers.count <= tournament.format.maxTeamSize else {
            throw TournamentError.invalidTeamSize
        }
        
        let team = TournamentTeam(
            id: UUID().uuidString,
            name: teamName,
            members: teamMembers,
            captainId: getCurrentPlayerId(),
            tournamentId: tournamentId
        )
        
        try await apiClient.registerTeamForTournament(team: team)
        
        await MainActor.run {
            self.registrationStatus[tournamentId] = .teamRegistered
        }
        
        await broadcastTournamentAction(.teamRegistered(tournamentId, team))
    }
    
    // MARK: - Tournament Management
    
    /// Create a new tournament (for tournament organizers)
    func createTournament(_ tournament: Tournament) async throws {
        guard hasOrganizerPermissions() else {
            throw TournamentError.insufficientPermissions
        }
        
        let createdTournament = try await apiClient.createTournament(tournament: tournament)
        
        await MainActor.run {
            self.activeTournaments.append(createdTournament)
        }
        
        await broadcastTournamentAction(.tournamentCreated(createdTournament))
    }
    
    /// Start a tournament
    func startTournament(_ tournamentId: String) async throws {
        guard hasOrganizerPermissions() else {
            throw TournamentError.insufficientPermissions
        }
        
        var tournament = try await apiClient.getTournament(id: tournamentId)
        tournament.status = .active
        tournament.actualStartTime = Date()
        
        try await apiClient.updateTournament(tournament: tournament)
        
        await updateTournamentLocally(tournament)
        await broadcastTournamentAction(.tournamentStarted(tournament))
        
        // Generate initial brackets/matches
        await generateTournamentMatches(tournament)
    }
    
    /// End a tournament
    func endTournament(_ tournamentId: String, results: TournamentResults) async throws {
        guard hasOrganizerPermissions() else {
            throw TournamentError.insufficientPermissions
        }
        
        var tournament = try await apiClient.getTournament(id: tournamentId)
        tournament.status = .completed
        tournament.results = results
        
        try await apiClient.updateTournament(tournament: tournament)
        
        await updateTournamentLocally(tournament)
        await distributeTournamentRewards(tournament, results: results)
        await broadcastTournamentAction(.tournamentEnded(tournament, results))
    }
    
    // MARK: - Match Management
    
    /// Report match result
    func reportMatchResult(_ matchId: String, result: MatchResult) async throws {
        let playerId = getCurrentPlayerId()
        
        // Validate player can report this match
        guard let match = try await apiClient.getTournamentMatch(id: matchId) else {
            throw TournamentError.matchNotFound
        }
        
        guard match.participants.contains(playerId) else {
            throw TournamentError.notMatchParticipant
        }
        
        // Security validation
        let validation = await securityManager.validateGameAction(GameAction(
            playerId: playerId,
            actionType: "report_match_result",
            parameters: [
                "matchId": AnyCodable(matchId),
                "result": AnyCodable(result)
            ]
        ))
        
        guard validation.isValid else {
            throw TournamentError.invalidMatchResult
        }
        
        try await apiClient.reportMatchResult(matchId: matchId, result: result, reportedBy: playerId)
        
        await broadcastTournamentAction(.matchResultReported(matchId, result, playerId))
        
        // Check if tournament bracket needs updating
        if let tournamentId = match.tournamentId {
            await updateTournamentBracket(tournamentId)
        }
    }
    
    /// Challenge match result (dispute)
    func challengeMatchResult(_ matchId: String, reason: String, evidence: [String]) async throws {
        let playerId = getCurrentPlayerId()
        
        let challenge = MatchChallenge(
            id: UUID().uuidString,
            matchId: matchId,
            challengerId: playerId,
            reason: reason,
            evidence: evidence,
            timestamp: Date(),
            status: .pending
        )
        
        try await apiClient.submitMatchChallenge(challenge: challenge)
        
        await broadcastTournamentAction(.matchChallenged(challenge))
    }
    
    // MARK: - Live Tournament Features
    
    /// Start spectating a tournament match
    func spectateMatch(_ matchId: String) async throws {
        let playerId = getCurrentPlayerId()
        
        try await apiClient.startSpectating(matchId: matchId, spectatorId: playerId)
        
        await MainActor.run {
            let currentCount = self.spectatorCounts[matchId] ?? 0
            self.spectatorCounts[matchId] = currentCount + 1
        }
        
        await broadcastTournamentAction(.spectatorJoined(matchId, playerId))
    }
    
    /// Stop spectating a tournament match
    func stopSpectating(_ matchId: String) async throws {
        let playerId = getCurrentPlayerId()
        
        try await apiClient.stopSpectating(matchId: matchId, spectatorId: playerId)
        
        await MainActor.run {
            let currentCount = max(0, (self.spectatorCounts[matchId] ?? 1) - 1)
            self.spectatorCounts[matchId] = currentCount
        }
        
        await broadcastTournamentAction(.spectatorLeft(matchId, playerId))
    }
    
    /// Get live match data for spectators
    func getLiveMatchData(_ matchId: String) async throws -> LiveMatchData {
        return try await apiClient.getLiveMatchData(matchId: matchId)
    }
    
    // MARK: - Seasonal Events
    
    /// Load current seasonal events
    func loadSeasonalEvents() async {
        do {
            let events = try await apiClient.getSeasonalEvents()
            
            await MainActor.run {
                self.seasonalEvents = events.filter { $0.isActive }
            }
            
        } catch {
            print("Failed to load seasonal events: \(error)")
        }
    }
    
    /// Participate in seasonal event
    func participateInSeasonalEvent(_ eventId: String) async throws {
        let playerId = getCurrentPlayerId()
        
        guard let event = seasonalEvents.first(where: { $0.id == eventId }) else {
            throw TournamentError.eventNotFound
        }
        
        guard event.isActive && event.canParticipate(playerId) else {
            throw TournamentError.cannotParticipate
        }
        
        let participation = SeasonalEventParticipation(
            eventId: eventId,
            playerId: playerId,
            startTime: Date(),
            progress: 0.0
        )
        
        try await apiClient.participateInSeasonalEvent(participation: participation)
        
        await broadcastTournamentAction(.seasonalEventJoined(eventId, playerId))
    }
    
    /// Update seasonal event progress
    func updateSeasonalEventProgress(_ eventId: String, progress: Double, achievements: [String] = []) async throws {
        let playerId = getCurrentPlayerId()
        
        let update = SeasonalEventProgress(
            eventId: eventId,
            playerId: playerId,
            progress: progress,
            achievements: achievements,
            timestamp: Date()
        )
        
        try await apiClient.updateSeasonalEventProgress(update: update)
        
        await broadcastTournamentAction(.seasonalEventProgressUpdated(update))
    }
    
    // MARK: - Leaderboards & Rankings
    
    /// Load tournament leaderboard
    func loadTournamentLeaderboard(_ tournamentId: String) async {
        do {
            let leaderboard = try await apiClient.getTournamentLeaderboard(tournamentId: tournamentId)
            
            await MainActor.run {
                if let index = self.leaderboards.firstIndex(where: { $0.tournamentId == tournamentId }) {
                    self.leaderboards[index] = leaderboard
                } else {
                    self.leaderboards.append(leaderboard)
                }
            }
            
        } catch {
            print("Failed to load tournament leaderboard: \(error)")
        }
    }
    
    /// Get player's tournament ranking
    func getPlayerTournamentRanking(_ tournamentId: String, playerId: String? = nil) async -> TournamentRanking? {
        let targetPlayerId = playerId ?? getCurrentPlayerId()
        
        do {
            return try await apiClient.getPlayerTournamentRanking(
                tournamentId: tournamentId,
                playerId: targetPlayerId
            )
        } catch {
            return nil
        }
    }
    
    // MARK: - Rewards & Prizes
    
    /// Claim tournament rewards
    func claimTournamentRewards(_ tournamentId: String) async throws {
        let playerId = getCurrentPlayerId()
        
        let claimedRewards = try await apiClient.claimTournamentRewards(
            tournamentId: tournamentId,
            playerId: playerId
        )
        
        await MainActor.run {
            self.rewards.append(contentsOf: claimedRewards)
        }
        
        await broadcastTournamentAction(.rewardsClaimed(tournamentId, playerId, claimedRewards))
    }
    
    /// Get available rewards for player
    func getAvailableRewards() async -> [TournamentReward] {
        let playerId = getCurrentPlayerId()
        
        do {
            return try await apiClient.getAvailableRewards(playerId: playerId)
        } catch {
            return []
        }
    }
    
    // MARK: - Network Message Handling
    
    private func handleTournamentUpdate(_ update: TournamentUpdate) {
        switch update {
        case .statusChanged(let tournamentId, let newStatus):
            if let index = activeTournaments.firstIndex(where: { $0.id == tournamentId }) {
                activeTournaments[index].status = newStatus
            }
            
        case .participantJoined(let tournamentId, let playerId):
            // Update participant count
            break
            
        case .matchStarted(let matchId, let participants):
            matchProgress[matchId] = MatchProgress(
                matchId: matchId,
                status: .active,
                startTime: Date(),
                participants: participants
            )
            
        case .matchCompleted(let matchId, let result):
            matchProgress[matchId]?.status = .completed
            matchProgress[matchId]?.result = result
            
        case .bracketUpdated(let tournamentId, let bracket):
            // Update tournament bracket
            break
        }
    }
    
    private func broadcastTournamentAction(_ action: TournamentAction) async {
        let message = GameMessage(
            id: UUID().uuidString,
            type: .tournamentAction,
            timestamp: Date(),
            payload: .tournamentAction(action)
        )
        
        try? await multiplayerManager.sendGameAction(GameAction(
            playerId: getCurrentPlayerId(),
            actionType: "tournament_action",
            parameters: ["action": AnyCodable(action)]
        ))
    }
    
    // MARK: - Tournament Generation & Brackets
    
    private func generateTournamentMatches(_ tournament: Tournament) async {
        do {
            let matches = try await apiClient.generateTournamentMatches(tournamentId: tournament.id)
            
            await MainActor.run {
                for match in matches {
                    self.matchProgress[match.id] = MatchProgress(
                        matchId: match.id,
                        status: .scheduled,
                        startTime: match.scheduledTime,
                        participants: match.participants
                    )
                }
            }
            
        } catch {
            print("Failed to generate tournament matches: \(error)")
        }
    }
    
    private func updateTournamentBracket(_ tournamentId: String) async {
        do {
            let bracket = try await apiClient.getTournamentBracket(tournamentId: tournamentId)
            await broadcastTournamentAction(.bracketUpdated(tournamentId, bracket))
        } catch {
            print("Failed to update tournament bracket: \(error)")
        }
    }
    
    private func distributeTournamentRewards(_ tournament: Tournament, results: TournamentResults) async {
        do {
            let rewards = try await apiClient.distributeTournamentRewards(
                tournamentId: tournament.id,
                results: results
            )
            
            await MainActor.run {
                self.rewards.append(contentsOf: rewards)
            }
            
        } catch {
            print("Failed to distribute tournament rewards: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadActiveTournaments() {
        Task {
            await loadAvailableTournaments()
            await loadSeasonalEvents()
        }
    }
    
    private func refreshTournamentData() async {
        await loadAvailableTournaments()
        
        // Refresh leaderboards for active tournaments
        for tournament in activeTournaments.filter({ $0.status == .active }) {
            await loadTournamentLeaderboard(tournament.id)
        }
    }
    
    private func validateTournamentEligibility(_ tournament: Tournament, playerId: String) throws {
        // Check if registration is open
        guard tournament.status == .registrationOpen else {
            throw TournamentError.registrationClosed
        }
        
        // Check if player meets requirements
        if let minRating = tournament.requirements.minimumRating {
            // Would need to get player rating from stats
            // For now, assume eligible
        }
        
        // Check if tournament is full
        if tournament.currentParticipants >= tournament.maxParticipants {
            throw TournamentError.tournamentFull
        }
        
        // Check if player is already registered
        if registrationStatus[tournament.id] == .registered {
            throw TournamentError.alreadyRegistered
        }
    }
    
    private func updateTournamentLocally(_ tournament: Tournament) async {
        await MainActor.run {
            if let index = self.activeTournaments.firstIndex(where: { $0.id == tournament.id }) {
                self.activeTournaments[index] = tournament
            }
        }
    }
    
    private func hasOrganizerPermissions() -> Bool {
        // In production, check if user has tournament organizer role
        return true // Placeholder
    }
    
    private func getCurrentPlayerId() -> String {
        return UserDefaults.standard.string(forKey: "playerId") ?? "unknown"
    }
}

// MARK: - Tournament Models

struct Tournament: Codable, Identifiable {
    let id: String
    var name: String
    var description: String
    let category: TournamentCategory
    let format: TournamentFormat
    var status: TournamentStatus
    let creatorId: String
    let scheduledStartTime: Date
    var actualStartTime: Date?
    let registrationDeadline: Date
    let maxParticipants: Int
    var currentParticipants: Int
    let prizePool: PrizePool
    let requirements: TournamentRequirements
    let rules: TournamentRules
    var results: TournamentResults?
    let isSpectatable: Bool
    let allowsTeams: Bool
    
    init(name: String, description: String, category: TournamentCategory, format: TournamentFormat,
         creatorId: String, scheduledStartTime: Date, registrationDeadline: Date,
         maxParticipants: Int, prizePool: PrizePool, requirements: TournamentRequirements,
         rules: TournamentRules) {
        self.id = UUID().uuidString
        self.name = name
        self.description = description
        self.category = category
        self.format = format
        self.status = .registrationOpen
        self.creatorId = creatorId
        self.scheduledStartTime = scheduledStartTime
        self.registrationDeadline = registrationDeadline
        self.maxParticipants = maxParticipants
        self.currentParticipants = 0
        self.prizePool = prizePool
        self.requirements = requirements
        self.rules = rules
        self.isSpectatable = true
        self.allowsTeams = format.supportsTeams
    }
}

enum TournamentCategory: String, Codable, CaseIterable {
    case logistics = "Logistics Master"
    case speed = "Speed Challenge"
    case efficiency = "Efficiency Contest"
    case profit = "Profit Maximizer"
    case innovation = "Innovation Tournament"
    case endurance = "Endurance Marathon"
    case team = "Team Championship"
    case seasonal = "Seasonal Event"
    
    var description: String {
        switch self {
        case .logistics: return "Complete complex logistics challenges"
        case .speed: return "Fastest completion of trade routes"
        case .efficiency: return "Most efficient resource utilization"
        case .profit: return "Highest profit generation"
        case .innovation: return "Most innovative shipping solutions"
        case .endurance: return "Long-duration competitive gameplay"
        case .team: return "Team-based cooperative challenges"
        case .seasonal: return "Special seasonal competitions"
        }
    }
}

enum TournamentStatus: String, Codable, CaseIterable {
    case registrationOpen = "Registration Open"
    case registrationClosed = "Registration Closed"
    case active = "Active"
    case paused = "Paused"
    case completed = "Completed"
    case cancelled = "Cancelled"
    
    var isActive: Bool {
        return self == .active
    }
}

struct TournamentFormat: Codable {
    let type: FormatType
    let duration: TimeInterval
    let maxRounds: Int?
    let eliminationStyle: EliminationStyle
    let scoring: ScoringSystem
    let minTeamSize: Int
    let maxTeamSize: Int
    
    var supportsTeams: Bool {
        return maxTeamSize > 1
    }
    
    init(type: FormatType, duration: TimeInterval, eliminationStyle: EliminationStyle, scoring: ScoringSystem) {
        self.type = type
        self.duration = duration
        self.maxRounds = nil
        self.eliminationStyle = eliminationStyle
        self.scoring = scoring
        self.minTeamSize = 1
        self.maxTeamSize = 1
    }
}

enum FormatType: String, Codable, CaseIterable {
    case singleElimination = "Single Elimination"
    case doubleElimination = "Double Elimination"
    case roundRobin = "Round Robin"
    case swiss = "Swiss System"
    case league = "League"
    case bracket = "Bracket"
}

enum EliminationStyle: String, Codable, CaseIterable {
    case single = "Single"
    case double = "Double"
    case none = "None"
}

enum ScoringSystem: String, Codable, CaseIterable {
    case points = "Points"
    case time = "Time"
    case profit = "Profit"
    case efficiency = "Efficiency"
    case combined = "Combined"
}

struct PrizePool: Codable {
    let totalValue: Double
    let currency: String
    let distribution: [PrizeDistribution]
    let specialRewards: [SpecialReward]
    
    init(totalValue: Double, currency: String = "USD") {
        self.totalValue = totalValue
        self.currency = currency
        self.distribution = [
            PrizeDistribution(position: 1, percentage: 50.0),
            PrizeDistribution(position: 2, percentage: 30.0),
            PrizeDistribution(position: 3, percentage: 20.0)
        ]
        self.specialRewards = []
    }
}

struct PrizeDistribution: Codable {
    let position: Int
    let percentage: Double
    let fixedAmount: Double?
    
    init(position: Int, percentage: Double, fixedAmount: Double? = nil) {
        self.position = position
        self.percentage = percentage
        self.fixedAmount = fixedAmount
    }
}

struct SpecialReward: Codable {
    let name: String
    let description: String
    let condition: String
    let value: Double
}

struct TournamentRequirements: Codable {
    let minimumRating: Int?
    let maximumRating: Int?
    let minimumGamesPlayed: Int?
    let regionRestriction: String?
    let premiumRequired: Bool
    let ageRestriction: Int?
    
    init() {
        self.minimumRating = nil
        self.maximumRating = nil
        self.minimumGamesPlayed = nil
        self.regionRestriction = nil
        self.premiumRequired = false
        self.ageRestriction = nil
    }
}

struct TournamentRules: Codable {
    let gameMode: String
    let timeControls: TimeControls
    let allowedStrategies: [String]
    let bannedItems: [String]
    let specialConditions: [String]
    
    init(gameMode: String) {
        self.gameMode = gameMode
        self.timeControls = TimeControls()
        self.allowedStrategies = []
        self.bannedItems = []
        self.specialConditions = []
    }
}

struct TimeControls: Codable {
    let turnTimeLimit: TimeInterval?
    let totalTimeLimit: TimeInterval?
    let incrementPerAction: TimeInterval?
    
    init() {
        self.turnTimeLimit = nil
        self.totalTimeLimit = nil
        self.incrementPerAction = nil
    }
}

struct TournamentResults: Codable {
    let finalRankings: [PlayerRanking]
    let statistics: TournamentStatistics
    let highlights: [TournamentHighlight]
    let completionTime: Date
    
    init(finalRankings: [PlayerRanking]) {
        self.finalRankings = finalRankings
        self.statistics = TournamentStatistics()
        self.highlights = []
        self.completionTime = Date()
    }
}

struct PlayerRanking: Codable {
    let playerId: String
    let playerName: String
    let position: Int
    let score: Double
    let matches: TournamentMatchRecord
    let prizes: [TournamentReward]
}

struct TournamentMatchRecord: Codable {
    let played: Int
    let won: Int
    let lost: Int
    let draws: Int
    
    var winRate: Double {
        guard played > 0 else { return 0 }
        return Double(won) / Double(played)
    }
}

struct TournamentStatistics: Codable {
    let totalParticipants: Int
    let totalMatches: Int
    let averageMatchDuration: TimeInterval
    let competitiveBalance: Double
    
    init() {
        self.totalParticipants = 0
        self.totalMatches = 0
        self.averageMatchDuration = 0
        self.competitiveBalance = 0
    }
}

struct TournamentHighlight: Codable {
    let id: String
    let title: String
    let description: String
    let playerId: String
    let timestamp: Date
    let type: HighlightType
}

enum HighlightType: String, Codable, CaseIterable {
    case upset = "Upset Victory"
    case record = "Record Breaking"
    case comeback = "Amazing Comeback"
    case perfect = "Perfect Performance"
    case innovative = "Innovative Strategy"
}

// MARK: - Participation & Registration

struct TournamentRegistration: Codable {
    let tournamentId: String
    let playerId: String
    let timestamp: Date
    let teamId: String?
}

struct TournamentParticipation: Codable {
    let tournamentId: String
    let playerId: String
    let registrationTime: Date
    let currentRank: Int?
    let matchesPlayed: Int
    let currentScore: Double
    let status: ParticipationStatus
}

enum ParticipationStatus: String, Codable {
    case registered = "Registered"
    case active = "Active"
    case eliminated = "Eliminated"
    case withdrawn = "Withdrawn"
    case disqualified = "Disqualified"
}

enum RegistrationStatus: String, Codable {
    case unregistered = "Unregistered"
    case registered = "Registered"
    case teamRegistered = "Team Registered"
    case waitlisted = "Waitlisted"
}

struct TournamentTeam: Codable {
    let id: String
    let name: String
    let members: [String]
    let captainId: String
    let tournamentId: String
    let registrationTime: Date
    
    init(id: String, name: String, members: [String], captainId: String, tournamentId: String) {
        self.id = id
        self.name = name
        self.members = members
        self.captainId = captainId
        self.tournamentId = tournamentId
        self.registrationTime = Date()
    }
}

// MARK: - Matches & Competition

struct TournamentMatch: Codable {
    let id: String
    let tournamentId: String
    let round: Int
    let participants: [String]
    let scheduledTime: Date
    var startTime: Date?
    var endTime: Date?
    var result: MatchResult?
    let status: MatchStatus
    let isSpectatable: Bool
}

struct MatchResult: Codable {
    let winnerId: String?
    let scores: [String: Double]
    let statistics: MatchStatistics
    let duration: TimeInterval
    let timestamp: Date
    
    init(winnerId: String?, scores: [String: Double]) {
        self.winnerId = winnerId
        self.scores = scores
        self.statistics = MatchStatistics()
        self.duration = 0
        self.timestamp = Date()
    }
}

struct MatchStatistics: Codable {
    let totalActions: Int
    let averageActionTime: TimeInterval
    let peakPerformance: Double
    let efficiency: Double
    
    init() {
        self.totalActions = 0
        self.averageActionTime = 0
        self.peakPerformance = 0
        self.efficiency = 0
    }
}

enum MatchStatus: String, Codable {
    case scheduled = "Scheduled"
    case active = "Active"
    case paused = "Paused"
    case completed = "Completed"
    case disputed = "Disputed"
    case voided = "Voided"
}

struct MatchChallenge: Codable {
    let id: String
    let matchId: String
    let challengerId: String
    let reason: String
    let evidence: [String]
    let timestamp: Date
    var status: ChallengeStatus
    
    init(id: String, matchId: String, challengerId: String, reason: String, evidence: [String], timestamp: Date, status: ChallengeStatus) {
        self.id = id
        self.matchId = matchId
        self.challengerId = challengerId
        self.reason = reason
        self.evidence = evidence
        self.timestamp = timestamp
        self.status = status
    }
}

enum ChallengeStatus: String, Codable {
    case pending = "Pending"
    case underReview = "Under Review"
    case upheld = "Upheld"
    case dismissed = "Dismissed"
}

struct MatchProgress: Codable {
    let matchId: String
    var status: MatchStatus
    let startTime: Date
    let participants: [String]
    var result: MatchResult?
    
    init(matchId: String, status: MatchStatus, startTime: Date, participants: [String]) {
        self.matchId = matchId
        self.status = status
        self.startTime = startTime
        self.participants = participants
    }
}

// MARK: - Live Tournament Features

struct LiveMatchData: Codable {
    let matchId: String
    let currentState: GameState
    let playerStates: [String: PlayerStateSnapshot]
    let spectatorCount: Int
    let commentary: [LiveComment]
    let timestamp: Date
}

struct LiveComment: Codable {
    let id: String
    let spectatorId: String
    let content: String
    let timestamp: Date
    let type: CommentType
}

enum CommentType: String, Codable {
    case general = "General"
    case analysis = "Analysis"
    case prediction = "Prediction"
    case reaction = "Reaction"
}

// MARK: - Seasonal Events

struct SeasonalEvent: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let theme: String
    let startDate: Date
    let endDate: Date
    let objectives: [EventObjective]
    let rewards: [EventReward]
    let leaderboard: SeasonalLeaderboard?
    
    var isActive: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }
    
    func canParticipate(_ playerId: String) -> Bool {
        // Check if player can participate in this event
        return isActive // Simplified check
    }
}

struct EventObjective: Codable {
    let id: String
    let title: String
    let description: String
    let target: Double
    let reward: EventReward
    let isRepeatable: Bool
}

struct EventReward: Codable {
    let id: String
    let name: String
    let description: String
    let type: RewardType
    let value: Double
    let rarity: RewardRarity
}

enum RewardType: String, Codable, CaseIterable {
    case currency = "Currency"
    case experience = "Experience"
    case cosmetic = "Cosmetic"
    case achievement = "Achievement"
    case title = "Title"
    case ship = "Ship"
    case upgrade = "Upgrade"
}

enum RewardRarity: String, Codable, CaseIterable {
    case common = "Common"
    case uncommon = "Uncommon"
    case rare = "Rare"
    case epic = "Epic"
    case legendary = "Legendary"
    
    var color: String {
        switch self {
        case .common: return "gray"
        case .uncommon: return "green"
        case .rare: return "blue"
        case .epic: return "purple"
        case .legendary: return "orange"
        }
    }
}

struct SeasonalEventParticipation: Codable {
    let eventId: String
    let playerId: String
    let startTime: Date
    var progress: Double
    var completedObjectives: [String]
    var earnedRewards: [EventReward]
}

struct SeasonalEventProgress: Codable {
    let eventId: String
    let playerId: String
    let progress: Double
    let achievements: [String]
    let timestamp: Date
}

struct SeasonalLeaderboard: Codable {
    let eventId: String
    let entries: [SeasonalLeaderboardEntry]
    let lastUpdated: Date
}

struct SeasonalLeaderboardEntry: Codable {
    let rank: Int
    let playerId: String
    let playerName: String
    let score: Double
    let progress: Double
}

// MARK: - Leaderboards & Rankings

struct TournamentLeaderboard: Codable {
    let tournamentId: String
    let entries: [LeaderboardEntry]
    let lastUpdated: Date
    let totalParticipants: Int
}

struct TournamentRanking: Codable {
    let tournamentId: String
    let playerId: String
    let currentRank: Int
    let score: Double
    let matchRecord: TournamentMatchRecord
    let lastUpdated: Date
}

// MARK: - Rewards

struct TournamentReward: Codable, Identifiable {
    let id: String
    let tournamentId: String
    let playerId: String
    let rewardType: RewardType
    let name: String
    let description: String
    let value: Double
    let rarity: RewardRarity
    let earnedAt: Date
    var isClaimed: Bool
}

// MARK: - Network Messages

enum TournamentAction: Codable {
    case tournamentCreated(Tournament)
    case tournamentStarted(Tournament)
    case tournamentEnded(Tournament, TournamentResults)
    case playerRegistered(String, String) // tournament ID, player ID
    case playerUnregistered(String, String) // tournament ID, player ID
    case teamRegistered(String, TournamentTeam) // tournament ID, team
    case matchResultReported(String, MatchResult, String) // match ID, result, reporter
    case matchChallenged(MatchChallenge)
    case spectatorJoined(String, String) // match ID, spectator ID
    case spectatorLeft(String, String) // match ID, spectator ID
    case seasonalEventJoined(String, String) // event ID, player ID
    case seasonalEventProgressUpdated(SeasonalEventProgress)
    case rewardsClaimed(String, String, [TournamentReward]) // tournament ID, player ID, rewards
    case bracketUpdated(String, TournamentBracket) // tournament ID, bracket
}

enum TournamentUpdate: Codable {
    case statusChanged(String, TournamentStatus) // tournament ID, new status
    case participantJoined(String, String) // tournament ID, player ID
    case matchStarted(String, [String]) // match ID, participants
    case matchCompleted(String, MatchResult) // match ID, result
    case bracketUpdated(String, TournamentBracket) // tournament ID, bracket
}

struct TournamentBracket: Codable {
    let tournamentId: String
    let rounds: [BracketRound]
    let currentRound: Int
    let lastUpdated: Date
}

struct BracketRound: Codable {
    let roundNumber: Int
    let matches: [TournamentMatch]
    let isComplete: Bool
}

// MARK: - Error Types

enum TournamentError: LocalizedError {
    case tournamentNotFound
    case registrationClosed
    case tournamentFull
    case alreadyRegistered
    case teamsNotSupported
    case invalidTeamSize
    case insufficientPermissions
    case matchNotFound
    case notMatchParticipant
    case invalidMatchResult
    case eventNotFound
    case cannotParticipate
    
    var errorDescription: String? {
        switch self {
        case .tournamentNotFound:
            return "Tournament not found"
        case .registrationClosed:
            return "Registration is closed for this tournament"
        case .tournamentFull:
            return "Tournament is full"
        case .alreadyRegistered:
            return "Already registered for this tournament"
        case .teamsNotSupported:
            return "This tournament does not support teams"
        case .invalidTeamSize:
            return "Invalid team size for this tournament"
        case .insufficientPermissions:
            return "Insufficient permissions to perform this action"
        case .matchNotFound:
            return "Match not found"
        case .notMatchParticipant:
            return "You are not a participant in this match"
        case .invalidMatchResult:
            return "Invalid match result"
        case .eventNotFound:
            return "Seasonal event not found"
        case .cannotParticipate:
            return "Cannot participate in this event"
        }
    }
}

// MARK: - Extensions

extension GameMessage.MessageType {
    static let tournamentAction = GameMessage.MessageType(rawValue: "tournamentAction")!
}

extension MessagePayload {
    static func tournamentAction(_ action: TournamentAction) -> MessagePayload {
        // This would need to be implemented in the MessagePayload enum
        return .system(SystemMessage(message: "Tournament action", severity: "info"))
    }
}

extension Notification.Name {
    static let tournamentUpdateReceived = Notification.Name("TournamentUpdateReceived")
}

// MARK: - API Extensions

extension APIClient {
    func getAvailableTournaments(category: TournamentCategory? = nil) async throws -> [Tournament] {
        // Implementation would fetch tournaments from server
        return []
    }
    
    func registerForTournament(registration: TournamentRegistration) async throws {
        // Implementation would register player for tournament
    }
    
    func unregisterFromTournament(tournamentId: String, playerId: String) async throws {
        // Implementation would unregister player from tournament
    }
    
    func registerTeamForTournament(team: TournamentTeam) async throws {
        // Implementation would register team for tournament
    }
    
    func createTournament(tournament: Tournament) async throws -> Tournament {
        // Implementation would create tournament on server
        return tournament
    }
    
    func getTournament(id: String) async throws -> Tournament {
        // Implementation would fetch tournament details
        throw NetworkError.custom("Not implemented")
    }
    
    func updateTournament(tournament: Tournament) async throws {
        // Implementation would update tournament on server
    }
    
    func getTournamentMatch(id: String) async throws -> TournamentMatch? {
        // Implementation would fetch match details
        return nil
    }
    
    func reportMatchResult(matchId: String, result: MatchResult, reportedBy: String) async throws {
        // Implementation would report match result
    }
    
    func submitMatchChallenge(challenge: MatchChallenge) async throws {
        // Implementation would submit match challenge
    }
    
    func startSpectating(matchId: String, spectatorId: String) async throws {
        // Implementation would start spectating match
    }
    
    func stopSpectating(matchId: String, spectatorId: String) async throws {
        // Implementation would stop spectating match
    }
    
    func getLiveMatchData(matchId: String) async throws -> LiveMatchData {
        // Implementation would fetch live match data
        throw NetworkError.custom("Not implemented")
    }
    
    func getSeasonalEvents() async throws -> [SeasonalEvent] {
        // Implementation would fetch seasonal events
        return []
    }
    
    func participateInSeasonalEvent(participation: SeasonalEventParticipation) async throws {
        // Implementation would register for seasonal event
    }
    
    func updateSeasonalEventProgress(update: SeasonalEventProgress) async throws {
        // Implementation would update seasonal event progress
    }
    
    func getTournamentLeaderboard(tournamentId: String) async throws -> TournamentLeaderboard {
        // Implementation would fetch tournament leaderboard
        throw NetworkError.custom("Not implemented")
    }
    
    func getPlayerTournamentRanking(tournamentId: String, playerId: String) async throws -> TournamentRanking {
        // Implementation would fetch player ranking
        throw NetworkError.custom("Not implemented")
    }
    
    func claimTournamentRewards(tournamentId: String, playerId: String) async throws -> [TournamentReward] {
        // Implementation would claim tournament rewards
        return []
    }
    
    func getAvailableRewards(playerId: String) async throws -> [TournamentReward] {
        // Implementation would fetch available rewards
        return []
    }
    
    func generateTournamentMatches(tournamentId: String) async throws -> [TournamentMatch] {
        // Implementation would generate tournament matches
        return []
    }
    
    func getTournamentBracket(tournamentId: String) async throws -> TournamentBracket {
        // Implementation would fetch tournament bracket
        throw NetworkError.custom("Not implemented")
    }
    
    func distributeTournamentRewards(tournamentId: String, results: TournamentResults) async throws -> [TournamentReward] {
        // Implementation would distribute tournament rewards
        return []
    }
}