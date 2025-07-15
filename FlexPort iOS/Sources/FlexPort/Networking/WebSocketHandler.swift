import Foundation
import Combine

/// Handles WebSocket connections for real-time multiplayer gameplay
actor WebSocketHandler {
    private var webSocketTask: URLSessionWebSocketTask?
    private let session: URLSession
    private let configuration = NetworkConfiguration.shared
    
    // Publishers for game events
    private let messageSubject = PassthroughSubject<GameMessage, Never>()
    private let connectionStateSubject = CurrentValueSubject<ConnectionState, Never>(.disconnected)
    
    var messagePublisher: AnyPublisher<GameMessage, Never> {
        messageSubject.eraseToAnyPublisher()
    }
    
    var connectionStatePublisher: AnyPublisher<ConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }
    
    private var pingTimer: Timer?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = configuration.webSocketTimeout
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }
    
    /// Connect to the game server
    func connect(sessionId: String, authToken: String) async throws {
        guard connectionStateSubject.value != .connected else { return }
        
        connectionStateSubject.send(.connecting)
        
        var request = URLRequest(url: configuration.webSocketURL)
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue(sessionId, forHTTPHeaderField: "X-Session-ID")
        
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        
        // Start receiving messages
        await startReceiving()
        
        // Start ping timer for keep-alive
        await startPingTimer()
        
        connectionStateSubject.send(.connected)
        reconnectAttempts = 0
    }
    
    /// Disconnect from the server
    func disconnect() async {
        await stopPingTimer()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        connectionStateSubject.send(.disconnected)
    }
    
    /// Send a game message
    func send(_ message: GameMessage) async throws {
        guard let webSocketTask = webSocketTask,
              connectionStateSubject.value == .connected else {
            throw NetworkError.noConnection
        }
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(message)
        let wsMessage = URLSessionWebSocketTask.Message.data(data)
        
        try await webSocketTask.send(wsMessage)
    }
    
    /// Handle incoming messages
    private func startReceiving() async {
        guard let webSocketTask = webSocketTask else { return }
        
        do {
            let message = try await webSocketTask.receive()
            
            switch message {
            case .data(let data):
                await handleData(data)
            case .string(let string):
                if let data = string.data(using: .utf8) {
                    await handleData(data)
                }
            @unknown default:
                break
            }
            
            // Continue receiving
            await startReceiving()
            
        } catch {
            await handleConnectionError(error)
        }
    }
    
    private func handleData(_ data: Data) async {
        do {
            let decoder = JSONDecoder()
            let message = try decoder.decode(GameMessage.self, from: data)
            messageSubject.send(message)
        } catch {
            print("Failed to decode message: \(error)")
        }
    }
    
    private func handleConnectionError(_ error: Error) async {
        connectionStateSubject.send(.disconnected)
        
        // Attempt reconnection if appropriate
        if reconnectAttempts < maxReconnectAttempts {
            reconnectAttempts += 1
            connectionStateSubject.send(.reconnecting)
            
            try? await Task.sleep(nanoseconds: UInt64(configuration.retryDelay * Double(reconnectAttempts) * 1_000_000_000))
            
            // Attempt to reconnect with stored credentials
            // Note: In production, store and retrieve auth token securely
        }
    }
    
    private func startPingTimer() async {
        await MainActor.run {
            pingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
                Task {
                    await self.sendPing()
                }
            }
        }
    }
    
    private func stopPingTimer() async {
        await MainActor.run {
            pingTimer?.invalidate()
            pingTimer = nil
        }
    }
    
    private func sendPing() async {
        guard let webSocketTask = webSocketTask else { return }
        
        do {
            try await webSocketTask.sendPing()
        } catch {
            await handleConnectionError(error)
        }
    }
}

/// Connection states
enum ConnectionState {
    case disconnected
    case connecting
    case connected
    case reconnecting
}

/// Game message types for WebSocket communication
struct GameMessage: Codable {
    let id: String
    let type: MessageType
    let timestamp: Date
    let payload: MessagePayload
    
    enum MessageType: String, Codable {
        case gameAction
        case stateUpdate
        case playerJoined
        case playerLeft
        case chatMessage
        case systemMessage
        case conflictResolution
    }
}

/// Message payload variants
enum MessagePayload: Codable {
    case action(GameAction)
    case stateUpdate(GameStateUpdate)
    case playerEvent(PlayerEvent)
    case chat(ChatMessage)
    case system(SystemMessage)
    case conflict(ConflictResolution)
    
    private enum CodingKeys: String, CodingKey {
        case type, data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "action":
            let action = try container.decode(GameAction.self, forKey: .data)
            self = .action(action)
        case "stateUpdate":
            let update = try container.decode(GameStateUpdate.self, forKey: .data)
            self = .stateUpdate(update)
        case "playerEvent":
            let event = try container.decode(PlayerEvent.self, forKey: .data)
            self = .playerEvent(event)
        case "chat":
            let message = try container.decode(ChatMessage.self, forKey: .data)
            self = .chat(message)
        case "system":
            let message = try container.decode(SystemMessage.self, forKey: .data)
            self = .system(message)
        case "conflict":
            let resolution = try container.decode(ConflictResolution.self, forKey: .data)
            self = .conflict(resolution)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown message type")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .action(let action):
            try container.encode("action", forKey: .type)
            try container.encode(action, forKey: .data)
        case .stateUpdate(let update):
            try container.encode("stateUpdate", forKey: .type)
            try container.encode(update, forKey: .data)
        case .playerEvent(let event):
            try container.encode("playerEvent", forKey: .type)
            try container.encode(event, forKey: .data)
        case .chat(let message):
            try container.encode("chat", forKey: .type)
            try container.encode(message, forKey: .data)
        case .system(let message):
            try container.encode("system", forKey: .type)
            try container.encode(message, forKey: .data)
        case .conflict(let resolution):
            try container.encode("conflict", forKey: .type)
            try container.encode(resolution, forKey: .data)
        }
    }
}

// Message payload types
struct GameAction: Codable {
    let playerId: String
    let actionType: String
    let parameters: [String: AnyCodable]
}

struct GameStateUpdate: Codable {
    let turn: Int
    let playerStates: [String: PlayerStateSnapshot]
    let marketState: MarketStateSnapshot
}

struct PlayerEvent: Codable {
    let playerId: String
    let eventType: String
    let isJoining: Bool
}

struct ChatMessage: Codable {
    let playerId: String
    let message: String
    let timestamp: Date
}

struct SystemMessage: Codable {
    let message: String
    let severity: String
}

struct ConflictResolution: Codable {
    let conflictId: String
    let originalActions: [GameAction]
    let resolution: GameAction
    let reason: String
}

// Snapshot types for state synchronization
struct PlayerStateSnapshot: Codable {
    let money: Double
    let shipCount: Int
    let warehouseCount: Int
    let reputation: Double
}

struct MarketStateSnapshot: Codable {
    let commodityPrices: [String: Double]
    let interestRate: Double
}

// Helper for encoding/decoding any values
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode value")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let string = value as? String {
            try container.encode(string)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Cannot encode value"))
        }
    }
}