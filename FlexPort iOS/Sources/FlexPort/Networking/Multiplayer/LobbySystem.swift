import Foundation
import Combine

/// Manages game lobbies and player matchmaking
class LobbySystem: ObservableObject {
    
    // Lobby configuration
    private let maxLobbies = 100
    private let lobbyTimeout: TimeInterval = 300 // 5 minutes
    
    // Active lobbies
    @Published private(set) var publicLobbies: [GameLobby] = []
    @Published private(set) var privateLobbies: [String: GameLobby] = [:] // Code to lobby
    
    // Matchmaking queues
    private var matchmakingQueues: [GameMode: MatchmakingQueue] = [:]
    
    // Player tracking
    private var playerLobbies: [UUID: String] = [:] // Player to lobby ID
    
    // System components
    private let matchmaker = Matchmaker()
    private let lobbyValidator = LobbyValidator()
    
    // Publishers
    private let lobbyEventSubject = PassthroughSubject<LobbyEvent, Never>()
    var lobbyEventPublisher: AnyPublisher<LobbyEvent, Never> {
        lobbyEventSubject.eraseToAnyPublisher()
    }
    
    init() {
        setupMatchmakingQueues()
        startLobbyMaintenance()
    }
    
    // MARK: - Lobby Management
    
    /// Create a new game lobby
    func createLobby(settings: LobbySettings, host: PlayerInfo) -> Result<GameLobby, LobbyError> {
        guard publicLobbies.count + privateLobbies.count < maxLobbies else {
            return .failure(.serverFull)
        }
        
        let lobby = GameLobby(
            id: UUID().uuidString,
            name: settings.name,
            host: host,
            settings: settings
        )
        
        if settings.isPrivate {
            let code = generateLobbyCode()
            lobby.joinCode = code
            privateLobbies[code] = lobby
        } else {
            publicLobbies.append(lobby)
        }
        
        // Add host to lobby
        lobby.addPlayer(host)
        playerLobbies[host.id] = lobby.id
        
        lobbyEventSubject.send(.lobbyCreated(lobby))
        
        return .success(lobby)
    }
    
    /// Join a lobby by ID
    func joinLobby(lobbyId: String, player: PlayerInfo) -> Result<GameLobby, LobbyError> {
        guard let lobby = findLobby(id: lobbyId) else {
            return .failure(.lobbyNotFound)
        }
        
        // Validate join request
        let validation = lobbyValidator.canJoin(player: player, lobby: lobby)
        guard validation.allowed else {
            return .failure(.joinDenied(validation.reason ?? "Unknown reason"))
        }
        
        // Check if player is already in a lobby
        if let currentLobbyId = playerLobbies[player.id] {
            _ = leaveLobby(playerId: player.id)
        }
        
        // Add player to lobby
        lobby.addPlayer(player)
        playerLobbies[player.id] = lobby.id
        
        lobbyEventSubject.send(.playerJoined(lobby, player))
        
        // Check if lobby is ready to start
        if lobby.isReady {
            lobbyEventSubject.send(.lobbyReady(lobby))
        }
        
        return .success(lobby)
    }
    
    /// Join a private lobby by code
    func joinLobbyByCode(_ code: String, player: PlayerInfo) -> Result<GameLobby, LobbyError> {
        guard let lobby = privateLobbies[code] else {
            return .failure(.invalidCode)
        }
        
        return joinLobby(lobbyId: lobby.id, player: player)
    }
    
    /// Leave current lobby
    func leaveLobby(playerId: UUID) -> Result<Void, LobbyError> {
        guard let lobbyId = playerLobbies[playerId],
              let lobby = findLobby(id: lobbyId) else {
            return .failure(.notInLobby)
        }
        
        lobby.removePlayer(playerId)
        playerLobbies.removeValue(forKey: playerId)
        
        lobbyEventSubject.send(.playerLeft(lobby, playerId))
        
        // Handle host leaving
        if lobby.host.id == playerId {
            if lobby.players.isEmpty {
                // Remove empty lobby
                removeLobby(lobby)
            } else {
                // Transfer host to next player
                lobby.transferHost(to: lobby.players.first!)
                lobbyEventSubject.send(.hostChanged(lobby, lobby.host))
            }
        }
        
        return .success(())
    }
    
    /// Update lobby settings
    func updateLobbySettings(_ lobbyId: String, settings: LobbySettings, requesterId: UUID) -> Result<Void, LobbyError> {
        guard let lobby = findLobby(id: lobbyId) else {
            return .failure(.lobbyNotFound)
        }
        
        guard lobby.host.id == requesterId else {
            return .failure(.notHost)
        }
        
        // Validate new settings
        guard lobbyValidator.validateSettings(settings) else {
            return .failure(.invalidSettings)
        }
        
        lobby.updateSettings(settings)
        lobbyEventSubject.send(.settingsUpdated(lobby))
        
        return .success(())
    }
    
    /// Start game from lobby
    func startGame(lobbyId: String, requesterId: UUID) -> Result<String, LobbyError> {
        guard let lobby = findLobby(id: lobbyId) else {
            return .failure(.lobbyNotFound)
        }
        
        guard lobby.host.id == requesterId else {
            return .failure(.notHost)
        }
        
        guard lobby.isReady else {
            return .failure(.notReady)
        }
        
        // Create game session
        let sessionId = createGameSession(from: lobby)
        
        // Mark lobby as in-game
        lobby.state = .inGame
        lobby.gameSessionId = sessionId
        
        lobbyEventSubject.send(.gameStarted(lobby, sessionId))
        
        return .success(sessionId)
    }
    
    // MARK: - Matchmaking
    
    /// Enter matchmaking queue
    func enterMatchmaking(player: PlayerInfo, preferences: MatchmakingPreferences) -> Result<String, LobbyError> {
        let queue = matchmakingQueues[preferences.gameMode] ?? MatchmakingQueue(mode: preferences.gameMode)
        
        let ticket = queue.addPlayer(player, preferences: preferences)
        
        // Start matching process
        Task {
            await processMatchmaking(for: preferences.gameMode)
        }
        
        return .success(ticket.id)
    }
    
    /// Cancel matchmaking
    func cancelMatchmaking(ticketId: String) -> Result<Void, LobbyError> {
        for queue in matchmakingQueues.values {
            if queue.removeTicket(ticketId) {
                return .success(())
            }
        }
        
        return .failure(.ticketNotFound)
    }
    
    /// Get matchmaking status
    func getMatchmakingStatus(ticketId: String) -> MatchmakingStatus? {
        for queue in matchmakingQueues.values {
            if let status = queue.getStatus(for: ticketId) {
                return status
            }
        }
        return nil
    }
    
    // MARK: - Chat System
    
    /// Send chat message in lobby
    func sendChatMessage(lobbyId: String, senderId: UUID, message: String) -> Result<Void, LobbyError> {
        guard let lobby = findLobby(id: lobbyId) else {
            return .failure(.lobbyNotFound)
        }
        
        guard lobby.players.contains(where: { $0.id == senderId }) else {
            return .failure(.notInLobby)
        }
        
        let chatMessage = LobbyChatMessage(
            id: UUID().uuidString,
            senderId: senderId,
            senderName: lobby.players.first { $0.id == senderId }?.name ?? "Unknown",
            message: filterMessage(message),
            timestamp: Date()
        )
        
        lobby.addChatMessage(chatMessage)
        lobbyEventSubject.send(.chatMessage(lobby, chatMessage))
        
        return .success(())
    }
    
    // MARK: - Trade Negotiation
    
    /// Propose a trade in lobby
    func proposeTrade(lobbyId: String, trade: TradeProposal) -> Result<Void, LobbyError> {
        guard let lobby = findLobby(id: lobbyId) else {
            return .failure(.lobbyNotFound)
        }
        
        guard lobby.players.contains(where: { $0.id == trade.proposerId }) else {
            return .failure(.notInLobby)
        }
        
        lobby.addTradeProposal(trade)
        lobbyEventSubject.send(.tradeProposed(lobby, trade))
        
        return .success(())
    }
    
    /// Respond to trade proposal
    func respondToTrade(lobbyId: String, tradeId: String, response: TradeResponse) -> Result<Void, LobbyError> {
        guard let lobby = findLobby(id: lobbyId) else {
            return .failure(.lobbyNotFound)
        }
        
        guard let trade = lobby.tradeProposals.first(where: { $0.id == tradeId }) else {
            return .failure(.tradeNotFound)
        }
        
        trade.addResponse(response)
        
        if trade.isAccepted {
            lobbyEventSubject.send(.tradeAccepted(lobby, trade))
        } else if trade.isRejected {
            lobbyEventSubject.send(.tradeRejected(lobby, trade))
        }
        
        return .success(())
    }
    
    // MARK: - Private Methods
    
    private func setupMatchmakingQueues() {
        for mode in GameMode.allCases {
            matchmakingQueues[mode] = MatchmakingQueue(mode: mode)
        }
    }
    
    private func startLobbyMaintenance() {
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            self.cleanupInactiveLobbies()
        }
    }
    
    private func cleanupInactiveLobbies() {
        let now = Date()
        
        // Remove inactive public lobbies
        publicLobbies.removeAll { lobby in
            if lobby.lastActivity.distance(to: now) > lobbyTimeout && lobby.state == .waiting {
                removeLobby(lobby)
                return true
            }
            return false
        }
        
        // Remove inactive private lobbies
        let inactiveCodes = privateLobbies.compactMap { code, lobby in
            if lobby.lastActivity.distance(to: now) > lobbyTimeout && lobby.state == .waiting {
                removeLobby(lobby)
                return code
            }
            return nil
        }
        
        for code in inactiveCodes {
            privateLobbies.removeValue(forKey: code)
        }
    }
    
    private func findLobby(id: String) -> GameLobby? {
        if let lobby = publicLobbies.first(where: { $0.id == id }) {
            return lobby
        }
        
        return privateLobbies.values.first { $0.id == id }
    }
    
    private func removeLobby(_ lobby: GameLobby) {
        // Remove all players from lobby
        for player in lobby.players {
            playerLobbies.removeValue(forKey: player.id)
        }
        
        // Remove from collections
        publicLobbies.removeAll { $0.id == lobby.id }
        if let code = lobby.joinCode {
            privateLobbies.removeValue(forKey: code)
        }
        
        lobbyEventSubject.send(.lobbyClosed(lobby))
    }
    
    private func generateLobbyCode() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }
    
    private func createGameSession(from lobby: GameLobby) -> String {
        // In production, would create actual game session
        return UUID().uuidString
    }
    
    private func filterMessage(_ message: String) -> String {
        // Basic profanity filter
        return message // Simplified
    }
    
    private func processMatchmaking(for mode: GameMode) async {
        guard let queue = matchmakingQueues[mode] else { return }
        
        let matches = await matchmaker.findMatches(in: queue)
        
        for match in matches {
            // Create lobby for matched players
            let settings = LobbySettings(
                name: "Matchmade Game",
                gameMode: mode,
                maxPlayers: match.players.count,
                isPrivate: false,
                region: match.region
            )
            
            if case .success(let lobby) = createLobby(settings: settings, host: match.players.first!) {
                // Add other players
                for player in match.players.dropFirst() {
                    _ = joinLobby(lobbyId: lobby.id, player: player)
                }
                
                // Notify players
                lobbyEventSubject.send(.matchFound(lobby, match))
            }
        }
    }
}

// MARK: - Game Lobby

class GameLobby: ObservableObject {
    let id: String
    @Published var name: String
    @Published var host: PlayerInfo
    @Published var players: [PlayerInfo] = []
    @Published var settings: LobbySettings
    @Published var state: LobbyState = .waiting
    @Published var chatMessages: [LobbyChatMessage] = []
    @Published var tradeProposals: [TradeProposal] = []
    
    var joinCode: String?
    var gameSessionId: String?
    var lastActivity: Date = Date()
    
    var isReady: Bool {
        players.count >= settings.minPlayers &&
        players.count <= settings.maxPlayers &&
        players.allSatisfy { $0.isReady }
    }
    
    var isFull: Bool {
        players.count >= settings.maxPlayers
    }
    
    init(id: String, name: String, host: PlayerInfo, settings: LobbySettings) {
        self.id = id
        self.name = name
        self.host = host
        self.settings = settings
    }
    
    func addPlayer(_ player: PlayerInfo) {
        players.append(player)
        lastActivity = Date()
    }
    
    func removePlayer(_ playerId: UUID) {
        players.removeAll { $0.id == playerId }
        lastActivity = Date()
    }
    
    func transferHost(to player: PlayerInfo) {
        host = player
        lastActivity = Date()
    }
    
    func updateSettings(_ newSettings: LobbySettings) {
        settings = newSettings
        lastActivity = Date()
    }
    
    func addChatMessage(_ message: LobbyChatMessage) {
        chatMessages.append(message)
        
        // Keep only recent messages
        if chatMessages.count > 100 {
            chatMessages.removeFirst()
        }
        
        lastActivity = Date()
    }
    
    func addTradeProposal(_ trade: TradeProposal) {
        tradeProposals.append(trade)
        lastActivity = Date()
    }
}

// MARK: - Supporting Types

struct LobbySettings {
    var name: String
    var gameMode: GameMode
    var maxPlayers: Int
    var minPlayers: Int = 2
    var isPrivate: Bool
    var region: String?
    var customRules: [String: Any] = [:]
}

enum LobbyState {
    case waiting
    case starting
    case inGame
    case finished
}

struct PlayerInfo: Codable {
    let id: UUID
    var name: String
    var avatar: String?
    var level: Int
    var rating: Int
    var isReady: Bool = false
}

struct LobbyChatMessage {
    let id: String
    let senderId: UUID
    let senderName: String
    let message: String
    let timestamp: Date
}

enum LobbyEvent {
    case lobbyCreated(GameLobby)
    case lobbyClosed(GameLobby)
    case playerJoined(GameLobby, PlayerInfo)
    case playerLeft(GameLobby, UUID)
    case hostChanged(GameLobby, PlayerInfo)
    case settingsUpdated(GameLobby)
    case lobbyReady(GameLobby)
    case gameStarted(GameLobby, String)
    case chatMessage(GameLobby, LobbyChatMessage)
    case tradeProposed(GameLobby, TradeProposal)
    case tradeAccepted(GameLobby, TradeProposal)
    case tradeRejected(GameLobby, TradeProposal)
    case matchFound(GameLobby, Match)
}

enum LobbyError: Error {
    case serverFull
    case lobbyNotFound
    case invalidCode
    case notInLobby
    case joinDenied(String)
    case notHost
    case invalidSettings
    case notReady
    case ticketNotFound
    case tradeNotFound
}

// MARK: - Trade System

class TradeProposal: ObservableObject {
    let id: String
    let proposerId: UUID
    let targetId: UUID
    @Published var offers: [TradeOffer] = []
    @Published var requests: [TradeRequest] = []
    @Published var responses: [UUID: TradeResponse] = [:]
    @Published var status: TradeStatus = .pending
    let createdAt: Date
    
    var isAccepted: Bool {
        responses[targetId]?.accepted ?? false
    }
    
    var isRejected: Bool {
        responses[targetId]?.accepted == false
    }
    
    init(proposerId: UUID, targetId: UUID) {
        self.id = UUID().uuidString
        self.proposerId = proposerId
        self.targetId = targetId
        self.createdAt = Date()
    }
    
    func addResponse(_ response: TradeResponse) {
        responses[response.responderId] = response
        
        if response.accepted {
            status = .accepted
        } else {
            status = .rejected
        }
    }
}

struct TradeOffer {
    let type: TradeItemType
    let itemId: String
    let quantity: Int
}

struct TradeRequest {
    let type: TradeItemType
    let itemId: String
    let quantity: Int
}

struct TradeResponse {
    let responderId: UUID
    let accepted: Bool
    let counterOffer: TradeProposal?
}

enum TradeItemType {
    case money
    case cargo
    case ship
    case warehouse
}

enum TradeStatus {
    case pending
    case accepted
    case rejected
    case expired
}

// MARK: - Lobby Validator

class LobbyValidator {
    
    func canJoin(player: PlayerInfo, lobby: GameLobby) -> (allowed: Bool, reason: String?) {
        // Check if lobby is full
        if lobby.isFull {
            return (false, "Lobby is full")
        }
        
        // Check if game already started
        if lobby.state != .waiting {
            return (false, "Game already in progress")
        }
        
        // Check player level requirements
        if let minLevel = lobby.settings.customRules["minLevel"] as? Int {
            if player.level < minLevel {
                return (false, "Level requirement not met")
            }
        }
        
        // Check rating requirements
        if let minRating = lobby.settings.customRules["minRating"] as? Int {
            if player.rating < minRating {
                return (false, "Rating requirement not met")
            }
        }
        
        return (true, nil)
    }
    
    func validateSettings(_ settings: LobbySettings) -> Bool {
        guard settings.maxPlayers >= 2 && settings.maxPlayers <= 16 else {
            return false
        }
        
        guard settings.minPlayers >= 2 && settings.minPlayers <= settings.maxPlayers else {
            return false
        }
        
        guard !settings.name.isEmpty else {
            return false
        }
        
        return true
    }
}