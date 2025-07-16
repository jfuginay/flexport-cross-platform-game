import Foundation

/// Advanced matchmaking system with skill-based matching and regional preferences
class Matchmaker {
    
    // Matching configuration
    private let matchingInterval: TimeInterval = 2.0
    private let expandSearchTime: TimeInterval = 10.0
    private let maxSearchTime: TimeInterval = 60.0
    
    // Skill rating parameters
    private let initialSkillRange: Float = 100.0
    private let skillRangeExpansionRate: Float = 50.0
    private let maxSkillRange: Float = 500.0
    
    // Regional matching
    private let regions = ["NA-East", "NA-West", "EU-West", "EU-East", "Asia-Pacific", "South-America"]
    private let crossRegionPenalty: Float = 200.0 // Additional latency penalty
    
    // MARK: - Match Finding
    
    /// Find matches in a matchmaking queue
    func findMatches(in queue: MatchmakingQueue) async -> [Match] {
        var matches: [Match] = []
        let tickets = queue.getActiveTickets()
        
        // Group tickets by game mode specifics
        let groupedTickets = groupTickets(tickets)
        
        for group in groupedTickets {
            let groupMatches = await createMatches(from: group)
            matches.append(contentsOf: groupMatches)
        }
        
        return matches
    }
    
    /// Create matches from a group of compatible tickets
    private func createMatches(from tickets: [MatchmakingTicket]) async -> [Match] {
        var matches: [Match] = []
        var remainingTickets = tickets
        
        while remainingTickets.count >= 2 {
            if let match = await findBestMatch(in: remainingTickets) {
                matches.append(match)
                
                // Remove matched tickets
                remainingTickets.removeAll { ticket in
                    match.tickets.contains { $0.id == ticket.id }
                }
            } else {
                break
            }
        }
        
        return matches
    }
    
    /// Find the best possible match from available tickets
    private func findBestMatch(in tickets: [MatchmakingTicket]) async -> Match? {
        guard tickets.count >= 2 else { return nil }
        
        var bestMatch: Match?
        var bestScore: Float = Float.infinity
        
        // Try different combinations
        for i in 0..<tickets.count {
            let anchor = tickets[i]
            let candidates = findCandidates(for: anchor, in: tickets)
            
            if let match = createOptimalMatch(anchor: anchor, candidates: candidates) {
                let score = calculateMatchScore(match)
                
                if score < bestScore {
                    bestScore = score
                    bestMatch = match
                }
            }
        }
        
        return bestMatch
    }
    
    /// Find candidate tickets for matching
    private func findCandidates(for anchor: MatchmakingTicket, in tickets: [MatchmakingTicket]) -> [MatchmakingTicket] {
        let searchTime = Date().timeIntervalSince(anchor.createdAt)
        let skillRange = calculateSkillRange(searchTime: searchTime)
        
        return tickets.filter { candidate in
            guard candidate.id != anchor.id else { return false }
            
            // Check basic compatibility
            guard isCompatible(anchor, candidate) else { return false }
            
            // Check skill rating
            let skillDiff = abs(anchor.player.rating - candidate.player.rating)
            guard Float(skillDiff) <= skillRange else { return false }
            
            // Check wait time (prefer players waiting longer)
            let waitTimeDiff = abs(anchor.createdAt.timeIntervalSince(candidate.createdAt))
            guard waitTimeDiff < maxSearchTime else { return false }
            
            return true
        }
    }
    
    /// Create optimal match from anchor and candidates
    private func createOptimalMatch(anchor: MatchmakingTicket, candidates: [MatchmakingTicket]) -> Match? {
        let targetSize = anchor.preferences.preferredTeamSize
        
        // Sort candidates by match quality
        let sortedCandidates = candidates.sorted { candidate1, candidate2 in
            let score1 = calculatePairScore(anchor, candidate1)
            let score2 = calculatePairScore(anchor, candidate2)
            return score1 < score2
        }
        
        // Select best candidates up to target size
        var selectedTickets = [anchor]
        for candidate in sortedCandidates {
            if selectedTickets.count >= targetSize { break }
            
            // Check if candidate is compatible with all selected tickets
            let compatible = selectedTickets.allSatisfy { selected in
                isCompatible(selected, candidate)
            }
            
            if compatible {
                selectedTickets.append(candidate)
            }
        }
        
        // Create match if we have enough players
        if selectedTickets.count >= anchor.preferences.minTeamSize {
            return createMatch(from: selectedTickets)
        }
        
        return nil
    }
    
    // MARK: - Compatibility Checking
    
    /// Check if two tickets are compatible for matching
    private func isCompatible(_ ticket1: MatchmakingTicket, _ ticket2: MatchmakingTicket) -> Bool {
        // Game mode must match
        guard ticket1.preferences.gameMode == ticket2.preferences.gameMode else {
            return false
        }
        
        // Check custom rules compatibility
        for (key, value1) in ticket1.preferences.customRules {
            if let value2 = ticket2.preferences.customRules[key] {
                if !areValuesCompatible(value1, value2) {
                    return false
                }
            }
        }
        
        // Check blocked players
        if ticket1.preferences.blockedPlayers.contains(ticket2.player.id) ||
           ticket2.preferences.blockedPlayers.contains(ticket1.player.id) {
            return false
        }
        
        return true
    }
    
    private func areValuesCompatible(_ value1: Any, _ value2: Any) -> Bool {
        // Simple compatibility check - in production would be more sophisticated
        if let bool1 = value1 as? Bool, let bool2 = value2 as? Bool {
            return bool1 == bool2
        }
        return true
    }
    
    // MARK: - Scoring
    
    /// Calculate match score (lower is better)
    private func calculateMatchScore(_ match: Match) -> Float {
        var score: Float = 0
        
        // Skill variance penalty
        let ratings = match.players.map { Float($0.rating) }
        let avgRating = ratings.reduce(0, +) / Float(ratings.count)
        let variance = ratings.map { pow($0 - avgRating, 2) }.reduce(0, +) / Float(ratings.count)
        score += variance * 0.1
        
        // Wait time bonus (negative score for longer waits)
        let avgWaitTime = match.tickets.map { Date().timeIntervalSince($0.createdAt) }.reduce(0, +) / Double(match.tickets.count)
        score -= Float(avgWaitTime) * 10.0
        
        // Regional penalty
        let regions = match.tickets.compactMap { $0.preferences.region }
        if Set(regions).count > 1 {
            score += crossRegionPenalty
        }
        
        // Team size preference penalty
        for ticket in match.tickets {
            let sizeDiff = abs(match.players.count - ticket.preferences.preferredTeamSize)
            score += Float(sizeDiff) * 20.0
        }
        
        return score
    }
    
    /// Calculate pair score for two tickets
    private func calculatePairScore(_ ticket1: MatchmakingTicket, _ ticket2: MatchmakingTicket) -> Float {
        var score: Float = 0
        
        // Skill difference
        let skillDiff = abs(ticket1.player.rating - ticket2.player.rating)
        score += Float(skillDiff)
        
        // Regional difference
        if ticket1.preferences.region != ticket2.preferences.region {
            score += crossRegionPenalty
        }
        
        // Wait time similarity bonus
        let waitDiff = abs(ticket1.createdAt.timeIntervalSince(ticket2.createdAt))
        score -= Float(waitDiff) * 5.0
        
        // Friend bonus
        if ticket1.preferences.preferredPlayers.contains(ticket2.player.id) ||
           ticket2.preferences.preferredPlayers.contains(ticket1.player.id) {
            score -= 500.0
        }
        
        return score
    }
    
    // MARK: - Helper Methods
    
    private func calculateSkillRange(searchTime: TimeInterval) -> Float {
        let expansionFactor = Float(searchTime / expandSearchTime)
        let range = initialSkillRange + (skillRangeExpansionRate * expansionFactor)
        return min(range, maxSkillRange)
    }
    
    private func groupTickets(_ tickets: [MatchmakingTicket]) -> [[MatchmakingTicket]] {
        var groups: [String: [MatchmakingTicket]] = [:]
        
        for ticket in tickets {
            let key = "\(ticket.preferences.gameMode)-\(ticket.preferences.preferredTeamSize)"
            groups[key, default: []].append(ticket)
        }
        
        return Array(groups.values)
    }
    
    private func createMatch(from tickets: [MatchmakingTicket]) -> Match {
        let players = tickets.map { $0.player }
        let region = selectOptimalRegion(for: tickets)
        
        return Match(
            id: UUID().uuidString,
            tickets: tickets,
            players: players,
            region: region,
            createdAt: Date()
        )
    }
    
    private func selectOptimalRegion(for tickets: [MatchmakingTicket]) -> String {
        // Count region preferences
        var regionCounts: [String: Int] = [:]
        
        for ticket in tickets {
            if let region = ticket.preferences.region {
                regionCounts[region, default: 0] += 1
            }
        }
        
        // Return most common region, or default
        return regionCounts.max(by: { $0.value < $1.value })?.key ?? "NA-East"
    }
}

// MARK: - Matchmaking Queue

class MatchmakingQueue {
    let mode: GameMode
    private var tickets: [MatchmakingTicket] = []
    private let queueLock = NSLock()
    
    init(mode: GameMode) {
        self.mode = mode
    }
    
    /// Add player to queue
    func addPlayer(_ player: PlayerInfo, preferences: MatchmakingPreferences) -> MatchmakingTicket {
        let ticket = MatchmakingTicket(
            player: player,
            preferences: preferences
        )
        
        queueLock.lock()
        tickets.append(ticket)
        queueLock.unlock()
        
        return ticket
    }
    
    /// Remove ticket from queue
    @discardableResult
    func removeTicket(_ ticketId: String) -> Bool {
        queueLock.lock()
        defer { queueLock.unlock() }
        
        if let index = tickets.firstIndex(where: { $0.id == ticketId }) {
            tickets.remove(at: index)
            return true
        }
        
        return false
    }
    
    /// Get all active tickets
    func getActiveTickets() -> [MatchmakingTicket] {
        queueLock.lock()
        defer { queueLock.unlock() }
        
        // Remove expired tickets
        let now = Date()
        tickets.removeAll { ticket in
            now.timeIntervalSince(ticket.createdAt) > 120.0 // 2 minute timeout
        }
        
        return tickets
    }
    
    /// Get matchmaking status for a ticket
    func getStatus(for ticketId: String) -> MatchmakingStatus? {
        queueLock.lock()
        defer { queueLock.unlock() }
        
        guard let ticket = tickets.first(where: { $0.id == ticketId }) else {
            return nil
        }
        
        let position = tickets.firstIndex(where: { $0.id == ticketId }) ?? 0
        let estimatedWait = estimateWaitTime(for: ticket)
        
        return MatchmakingStatus(
            ticketId: ticketId,
            state: .searching,
            queuePosition: position + 1,
            estimatedWaitTime: estimatedWait,
            searchStartTime: ticket.createdAt
        )
    }
    
    private func estimateWaitTime(for ticket: MatchmakingTicket) -> TimeInterval {
        // Simple estimation based on queue size and recent match rate
        let baseWait = 10.0 // seconds
        let queueFactor = Double(tickets.count) * 2.0
        let skillFactor = Double(ticket.player.rating - 1000) / 100.0 * 5.0
        
        return baseWait + queueFactor + skillFactor
    }
}

// MARK: - Supporting Types

class MatchmakingTicket {
    let id: String
    let player: PlayerInfo
    let preferences: MatchmakingPreferences
    let createdAt: Date
    
    init(player: PlayerInfo, preferences: MatchmakingPreferences) {
        self.id = UUID().uuidString
        self.player = player
        self.preferences = preferences
        self.createdAt = Date()
    }
}

struct MatchmakingPreferences {
    let gameMode: GameMode
    let preferredTeamSize: Int
    let minTeamSize: Int
    let maxTeamSize: Int
    let region: String?
    let preferredPlayers: [UUID] // Friends to match with
    let blockedPlayers: [UUID] // Players to avoid
    let customRules: [String: Any]
    
    init(gameMode: GameMode,
         preferredTeamSize: Int = 4,
         minTeamSize: Int = 2,
         maxTeamSize: Int = 8,
         region: String? = nil,
         preferredPlayers: [UUID] = [],
         blockedPlayers: [UUID] = [],
         customRules: [String: Any] = [:]) {
        self.gameMode = gameMode
        self.preferredTeamSize = preferredTeamSize
        self.minTeamSize = minTeamSize
        self.maxTeamSize = maxTeamSize
        self.region = region
        self.preferredPlayers = preferredPlayers
        self.blockedPlayers = blockedPlayers
        self.customRules = customRules
    }
}

struct MatchmakingStatus {
    let ticketId: String
    let state: MatchmakingState
    let queuePosition: Int
    let estimatedWaitTime: TimeInterval
    let searchStartTime: Date
    
    var elapsedTime: TimeInterval {
        Date().timeIntervalSince(searchStartTime)
    }
}

enum MatchmakingState {
    case queued
    case searching
    case matchFound
    case failed
    case cancelled
}

struct Match {
    let id: String
    let tickets: [MatchmakingTicket]
    let players: [PlayerInfo]
    let region: String
    let createdAt: Date
    
    var averageSkillRating: Float {
        let total = players.reduce(0) { $0 + $1.rating }
        return Float(total) / Float(players.count)
    }
}

// MARK: - Game Mode Extension

enum GameMode: String, CaseIterable, Codable {
    case realtime = "Realtime"
    case turnBased = "TurnBased"
    case campaign = "Campaign"
    case tutorial = "Tutorial"
    
    var defaultTeamSize: Int {
        switch self {
        case .realtime: return 4
        case .turnBased: return 2
        case .campaign: return 1
        case .tutorial: return 1
        }
    }
    
    var maxTeamSize: Int {
        switch self {
        case .realtime: return 16
        case .turnBased: return 8
        case .campaign: return 1
        case .tutorial: return 1
        }
    }
}