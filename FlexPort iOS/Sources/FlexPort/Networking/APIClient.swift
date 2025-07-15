import Foundation
import Combine

/// REST API client for FlexPort game services
class APIClient {
    static let shared = APIClient()
    
    private let session: URLSession
    private let configuration = NetworkConfiguration.shared
    private var authToken: String?
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = configuration.requestTimeout
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.waitsForConnectivity = true
        
        // Configure for low latency
        config.httpAdditionalHeaders = [
            "Accept": "application/json",
            "Content-Type": "application/json",
            "X-Client-Version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        ]
        
        self.session = URLSession(configuration: config)
    }
    
    /// Set authentication token
    func setAuthToken(_ token: String) {
        self.authToken = token
    }
    
    /// Generic request method with retry logic
    private func request<T: Decodable>(_ endpoint: NetworkConfiguration.Endpoint, 
                                      method: HTTPMethod = .get,
                                      body: Encodable? = nil,
                                      retryCount: Int = 0) async throws -> T {
        let url = configuration.baseURL.appendingPathComponent(endpoint.path)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        
        // Add auth header if available
        if let authToken = authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        
        // Add body if provided
        if let body = body {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(body)
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(T.self, from: data)
                
            case 401:
                throw NetworkError.authenticationFailed
                
            case 429:
                throw NetworkError.rateLimited
                
            case 500...599:
                throw NetworkError.serverError(httpResponse.statusCode)
                
            default:
                throw NetworkError.custom("Unexpected status code: \(httpResponse.statusCode)")
            }
            
        } catch {
            // Retry logic for transient failures
            if retryCount < configuration.maxRetries,
               shouldRetry(error: error) {
                try await Task.sleep(nanoseconds: UInt64(configuration.retryDelay * pow(2.0, Double(retryCount)) * 1_000_000_000))
                return try await request(endpoint, method: method, body: body, retryCount: retryCount + 1)
            }
            
            throw error
        }
    }
    
    private func shouldRetry(error: Error) -> Bool {
        if let networkError = error as? NetworkError {
            switch networkError {
            case .timeout, .noConnection, .serverError:
                return true
            default:
                return false
            }
        }
        return (error as NSError).code == NSURLErrorTimedOut ||
               (error as NSError).code == NSURLErrorNetworkConnectionLost
    }
}

// MARK: - Matchmaking
extension APIClient {
    /// Request matchmaking for a game session
    func requestMatch(request: MatchmakingRequest) async throws -> MatchmakingResponse {
        return try await self.request(.matchmaking, method: .post, body: request)
    }
    
    /// Cancel matchmaking request
    func cancelMatchmaking(requestId: String) async throws {
        let _: EmptyResponse = try await request(.matchmaking, method: .delete, body: ["requestId": requestId])
    }
}

// MARK: - Game Sessions
extension APIClient {
    /// Get game session details
    func getGameSession(sessionId: String) async throws -> GameSession {
        return try await request(.gameSession(sessionId))
    }
    
    /// Sync game state for offline mode
    func syncGameState(state: GameStateSyncRequest) async throws -> GameStateSyncResponse {
        return try await request(.syncGameState, method: .post, body: state)
    }
}

// MARK: - Leaderboards & Stats
extension APIClient {
    /// Get global leaderboard
    func getLeaderboard(type: LeaderboardType, timeframe: Timeframe) async throws -> LeaderboardResponse {
        var components = URLComponents(url: configuration.baseURL.appendingPathComponent(NetworkConfiguration.Endpoint.leaderboard.path), resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "type", value: type.rawValue),
            URLQueryItem(name: "timeframe", value: timeframe.rawValue)
        ]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = HTTPMethod.get.rawValue
        
        if let authToken = authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(LeaderboardResponse.self, from: data)
    }
    
    /// Get player statistics
    func getPlayerStats(playerId: String) async throws -> PlayerStats {
        return try await request(.playerStats(playerId))
    }
    
    /// Update player statistics
    func updatePlayerStats(playerId: String, stats: PlayerStatsUpdate) async throws -> PlayerStats {
        return try await request(.playerStats(playerId), method: .patch, body: stats)
    }
}

// MARK: - HTTP Methods
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

// MARK: - Request/Response Models
struct MatchmakingRequest: Encodable {
    let playerId: String
    let gameMode: GameMode
    let preferredRegion: String?
    let skillRating: Int?
}

struct MatchmakingResponse: Decodable {
    let requestId: String
    let status: MatchmakingStatus
    let estimatedWaitTime: TimeInterval?
    let sessionId: String?
}

enum MatchmakingStatus: String, Codable {
    case searching
    case matched
    case cancelled
    case failed
}

enum GameMode: String, Codable {
    case realtime
    case turnBased
    case cooperative
    case competitive
}

struct GameSession: Decodable {
    let id: String
    let mode: GameMode
    let players: [PlayerInfo]
    let status: SessionStatus
    let createdAt: Date
    let turn: Int?
}

struct PlayerInfo: Codable {
    let id: String
    let name: String
    let avatarURL: String?
    let isOnline: Bool
}

enum SessionStatus: String, Codable {
    case waiting
    case active
    case paused
    case completed
}

struct GameStateSyncRequest: Encodable {
    let playerId: String
    let sessionId: String
    let localState: Data // Compressed game state
    let lastSyncTimestamp: Date
    let pendingActions: [GameAction]
}

struct GameStateSyncResponse: Decodable {
    let serverState: Data // Compressed game state
    let conflicts: [ConflictResolution]
    let serverTimestamp: Date
}

enum LeaderboardType: String {
    case wealth
    case efficiency
    case reputation
    case singularityProgress
}

enum Timeframe: String {
    case daily
    case weekly
    case monthly
    case allTime
}

struct LeaderboardResponse: Decodable {
    let entries: [LeaderboardEntry]
    let playerRank: Int?
    let totalPlayers: Int
}

struct LeaderboardEntry: Decodable {
    let rank: Int
    let playerId: String
    let playerName: String
    let score: Double
    let additionalData: [String: Double]?
}

struct PlayerStats: Codable {
    let playerId: String
    let gamesPlayed: Int
    let gamesWon: Int
    let totalWealth: Double
    let averageEfficiency: Double
    let bestSingularityProgress: Double
    let achievements: [String]
    let lastUpdated: Date
}

struct PlayerStatsUpdate: Encodable {
    let deltaGamesPlayed: Int?
    let deltaGamesWon: Int?
    let newWealth: Double?
    let newEfficiency: Double?
    let newSingularityProgress: Double?
    let newAchievements: [String]?
}

struct EmptyResponse: Decodable {}