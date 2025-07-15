import Foundation
import Combine

/// Handles matchmaking for multiplayer games
class MatchmakingService: ObservableObject {
    static let shared = MatchmakingService()
    
    @Published private(set) var currentRequest: MatchmakingRequest?
    @Published private(set) var status: MatchmakingStatus = .idle
    @Published private(set) var estimatedWaitTime: TimeInterval?
    @Published private(set) var matchedSession: GameSession?
    
    private let apiClient = APIClient.shared
    private var pollTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    /// Start matchmaking process
    func findMatch(gameMode: GameMode, region: String? = nil, skillRating: Int? = nil) async throws {
        guard status == .idle else {
            throw MatchmakingError.alreadySearching
        }
        
        let playerId = getCurrentPlayerId()
        let request = MatchmakingRequest(
            playerId: playerId,
            gameMode: gameMode,
            preferredRegion: region,
            skillRating: skillRating
        )
        
        await MainActor.run {
            self.currentRequest = request
            self.status = .searching
        }
        
        do {
            let response = try await apiClient.requestMatch(request: request)
            
            await MainActor.run {
                self.estimatedWaitTime = response.estimatedWaitTime
                
                switch response.status {
                case .matched:
                    if let sessionId = response.sessionId {
                        Task {
                            await self.handleMatchFound(sessionId: sessionId)
                        }
                    }
                case .searching:
                    self.startPolling(requestId: response.requestId)
                case .failed:
                    self.status = .failed
                case .cancelled:
                    self.status = .idle
                }
            }
        } catch {
            await MainActor.run {
                self.status = .failed
                self.currentRequest = nil
            }
            throw error
        }
    }
    
    /// Cancel current matchmaking request
    func cancelSearch() async {
        guard let request = currentRequest,
              status == .searching else { return }
        
        do {
            // Cancel with server (assuming we have a request ID)
            // In production, store the request ID from the initial response
            await MainActor.run {
                self.stopPolling()
                self.status = .idle
                self.currentRequest = nil
                self.estimatedWaitTime = nil
            }
        }
    }
    
    private func startPolling(requestId: String) {
        stopPolling()
        
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task {
                await self?.pollMatchmakingStatus(requestId: requestId)
            }
        }
    }
    
    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
    
    private func pollMatchmakingStatus(requestId: String) async {
        // In production, implement a polling endpoint to check match status
        // For now, simulate the polling behavior
        
        // This would be a real API call:
        // let status = try await apiClient.getMatchmakingStatus(requestId: requestId)
        
        // Simulate finding a match after some time
        if let startTime = currentRequest?.timestamp,
           Date().timeIntervalSince(startTime) > 10.0 {
            
            let mockSessionId = "session_\(UUID().uuidString)"
            await handleMatchFound(sessionId: mockSessionId)
        }
    }
    
    private func handleMatchFound(sessionId: String) async {
        do {
            let session = try await apiClient.getGameSession(sessionId: sessionId)
            
            await MainActor.run {
                self.matchedSession = session
                self.status = .matched
                self.stopPolling()
            }
            
            // Notify delegates about successful match
            NotificationCenter.default.post(
                name: .matchFound,
                object: session
            )
            
        } catch {
            await MainActor.run {
                self.status = .failed
                self.stopPolling()
            }
        }
    }
    
    /// Get skill-based matchmaking rating for current player
    func getSkillRating() async -> Int? {
        let playerId = getCurrentPlayerId()
        
        do {
            let stats = try await apiClient.getPlayerStats(playerId: playerId)
            return calculateSkillRating(from: stats)
        } catch {
            return nil
        }
    }
    
    private func calculateSkillRating(from stats: PlayerStats) -> Int {
        // Simple ELO-like rating calculation
        let winRate = stats.gamesPlayed > 0 ? Double(stats.gamesWon) / Double(stats.gamesPlayed) : 0.5
        let experienceModifier = min(stats.gamesPlayed, 100) / 100.0
        let efficiencyModifier = min(stats.averageEfficiency / 100.0, 2.0)
        
        let baseRating = 1000.0
        let rating = baseRating + (winRate - 0.5) * 400.0 * experienceModifier * efficiencyModifier
        
        return max(100, min(2000, Int(rating)))
    }
    
    private func getCurrentPlayerId() -> String {
        return UserDefaults.standard.string(forKey: "playerId") ?? "player_\(UUID().uuidString)"
    }
}

// MARK: - Matchmaking Status
enum MatchmakingStatus {
    case idle
    case searching
    case matched
    case failed
}

// MARK: - Matchmaking Errors
enum MatchmakingError: LocalizedError {
    case alreadySearching
    case noPlayersFound
    case serverUnavailable
    case invalidGameMode
    
    var errorDescription: String? {
        switch self {
        case .alreadySearching:
            return "Already searching for a match"
        case .noPlayersFound:
            return "No suitable players found"
        case .serverUnavailable:
            return "Matchmaking service unavailable"
        case .invalidGameMode:
            return "Invalid game mode selected"
        }
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let matchFound = Notification.Name("MatchFound")
    static let matchmakingFailed = Notification.Name("MatchmakingFailed")
}

// MARK: - Enhanced Matchmaking Request
extension MatchmakingRequest {
    var timestamp: Date {
        return Date()
    }
}

// MARK: - Regional Matchmaking
extension MatchmakingService {
    /// Get optimal region based on player location and ping
    func getOptimalRegion() async -> String {
        // In production, ping different regional servers
        // and return the one with lowest latency
        
        let regions = ["us-east", "us-west", "eu-west", "asia-pacific"]
        
        // Mock implementation - in reality, measure ping to each region
        return regions.randomElement() ?? "us-east"
    }
    
    /// Estimate network latency for gaming
    func estimateLatency() async -> TimeInterval {
        // In production, ping the game servers
        // For now, return a mock latency based on connection type
        
        let reachability = NetworkReachability()
        
        switch reachability.connectionType {
        case .wifi:
            return 0.025 // 25ms
        case .cellular:
            return 0.075 // 75ms
        case .ethernet:
            return 0.015 // 15ms
        case .unknown:
            return 0.100 // 100ms
        }
    }
}