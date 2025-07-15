import Foundation

/// Network configuration for FlexPort game services
struct NetworkConfiguration {
    static let shared = NetworkConfiguration()
    
    // Backend URLs
    let baseURL: URL
    let webSocketURL: URL
    
    // API endpoints
    let apiVersion = "v1"
    
    // Timeouts
    let requestTimeout: TimeInterval = 30.0
    let webSocketTimeout: TimeInterval = 60.0
    
    // Network settings
    let maxRetries = 3
    let retryDelay: TimeInterval = 1.0
    
    private init() {
        // Production URLs - replace with actual backend URLs
        self.baseURL = URL(string: "https://api.flexport-game.com/\(apiVersion)")!
        self.webSocketURL = URL(string: "wss://ws.flexport-game.com/\(apiVersion)")!
    }
    
    // API Endpoints
    enum Endpoint {
        case matchmaking
        case leaderboard
        case gameSession(String)
        case playerStats(String)
        case syncGameState
        
        var path: String {
            switch self {
            case .matchmaking:
                return "/matchmaking"
            case .leaderboard:
                return "/leaderboard"
            case .gameSession(let sessionId):
                return "/sessions/\(sessionId)"
            case .playerStats(let playerId):
                return "/players/\(playerId)/stats"
            case .syncGameState:
                return "/sync"
            }
        }
    }
}

/// Network error types
enum NetworkError: LocalizedError {
    case noConnection
    case timeout
    case serverError(Int)
    case invalidResponse
    case authenticationFailed
    case rateLimited
    case custom(String)
    
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No internet connection available"
        case .timeout:
            return "Request timed out"
        case .serverError(let code):
            return "Server error: \(code)"
        case .invalidResponse:
            return "Invalid response from server"
        case .authenticationFailed:
            return "Authentication failed"
        case .rateLimited:
            return "Too many requests. Please try again later"
        case .custom(let message):
            return message
        }
    }
}