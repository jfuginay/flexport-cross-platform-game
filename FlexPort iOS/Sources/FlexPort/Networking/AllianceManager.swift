import Foundation
import Combine

/// Manages alliance formation, diplomacy, and cooperative gameplay
class AllianceManager: ObservableObject {
    static let shared = AllianceManager()
    
    @Published private(set) var currentAlliance: Alliance?
    @Published private(set) var allianceInvitations: [AllianceInvitation] = []
    @Published private(set) var proposedDiplomacy: [DiplomaticProposal] = []
    @Published private(set) var allianceChat: [AllianceChatMessage] = []
    @Published private(set) var sharedResources: [SharedResource] = []
    @Published private(set) var cooperativeRoutes: [CooperativeRoute] = []
    
    private let apiClient = APIClient.shared
    private let multiplayerManager = MultiplayerManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Alliance metrics
    @Published private(set) var allianceStrength: AllianceStrength = AllianceStrength()
    @Published private(set) var diplomaticRelations: [String: DiplomaticStatus] = [:]
    
    private init() {
        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
        // Listen for alliance-related network messages
        multiplayerManager.$currentSession
            .compactMap { $0 }
            .sink { [weak self] session in
                self?.initializeAllianceForSession(session)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Alliance Formation
    
    /// Create a new alliance
    func createAlliance(name: String, description: String, type: AllianceType) async throws {
        guard currentAlliance == nil else {
            throw AllianceError.alreadyInAlliance
        }
        
        let playerId = getCurrentPlayerId()
        let alliance = Alliance(
            name: name,
            description: description,
            type: type,
            founderId: playerId,
            members: [AllianceMember(playerId: playerId, role: .leader)]
        )
        
        do {
            let createdAlliance = try await apiClient.createAlliance(alliance: alliance)
            
            await MainActor.run {
                self.currentAlliance = createdAlliance
            }
            
            // Broadcast alliance creation to session
            await broadcastAllianceUpdate(.created(createdAlliance))
            
        } catch {
            throw AllianceError.creationFailed(error.localizedDescription)
        }
    }
    
    /// Send an alliance invitation
    func invitePlayer(_ playerId: String, role: AllianceRole = .member) async throws {
        guard let alliance = currentAlliance else {
            throw AllianceError.noActiveAlliance
        }
        
        guard hasPermission(.inviteMembers) else {
            throw AllianceError.insufficientPermissions
        }
        
        let invitation = AllianceInvitation(
            id: UUID().uuidString,
            allianceId: alliance.id,
            allianceName: alliance.name,
            inviterId: getCurrentPlayerId(),
            inviteeId: playerId,
            proposedRole: role,
            timestamp: Date(),
            status: .pending
        )
        
        try await apiClient.sendAllianceInvitation(invitation: invitation)
        await broadcastDiplomaticAction(.invitationSent(invitation))
    }
    
    /// Respond to an alliance invitation
    func respondToInvitation(_ invitationId: String, accept: Bool) async throws {
        guard let invitation = allianceInvitations.first(where: { $0.id == invitationId }) else {
            throw AllianceError.invitationNotFound
        }
        
        let response = InvitationResponse(
            invitationId: invitationId,
            playerId: getCurrentPlayerId(),
            accepted: accept,
            timestamp: Date()
        )
        
        try await apiClient.respondToAllianceInvitation(response: response)
        
        if accept {
            // Join the alliance
            let alliance = try await apiClient.getAlliance(id: invitation.allianceId)
            await MainActor.run {
                self.currentAlliance = alliance
                self.allianceInvitations.removeAll { $0.id == invitationId }
            }
            
            await broadcastAllianceUpdate(.memberJoined(getCurrentPlayerId(), alliance))
        } else {
            await MainActor.run {
                self.allianceInvitations.removeAll { $0.id == invitationId }
            }
        }
    }
    
    /// Leave current alliance
    func leaveAlliance() async throws {
        guard let alliance = currentAlliance else {
            throw AllianceError.noActiveAlliance
        }
        
        let playerId = getCurrentPlayerId()
        
        try await apiClient.leaveAlliance(allianceId: alliance.id, playerId: playerId)
        
        await MainActor.run {
            self.currentAlliance = nil
            self.sharedResources.removeAll()
            self.cooperativeRoutes.removeAll()
        }
        
        await broadcastAllianceUpdate(.memberLeft(playerId, alliance))
    }
    
    // MARK: - Diplomatic Relations
    
    /// Propose a diplomatic agreement
    func proposeDiplomaticAgreement(with playerId: String, type: DiplomaticAgreementType, terms: DiplomaticTerms) async throws {
        let proposal = DiplomaticProposal(
            id: UUID().uuidString,
            proposerId: getCurrentPlayerId(),
            targetId: playerId,
            agreementType: type,
            terms: terms,
            timestamp: Date(),
            status: .pending
        )
        
        try await apiClient.proposeDiplomaticAgreement(proposal: proposal)
        await broadcastDiplomaticAction(.proposalSent(proposal))
    }
    
    /// Respond to a diplomatic proposal
    func respondToDiplomaticProposal(_ proposalId: String, accept: Bool, counterTerms: DiplomaticTerms? = nil) async throws {
        guard let proposal = proposedDiplomacy.first(where: { $0.id == proposalId }) else {
            throw AllianceError.proposalNotFound
        }
        
        let response = DiplomaticResponse(
            proposalId: proposalId,
            responderId: getCurrentPlayerId(),
            accepted: accept,
            counterTerms: counterTerms,
            timestamp: Date()
        )
        
        try await apiClient.respondToDiplomaticProposal(response: response)
        
        if accept {
            // Establish diplomatic relation
            await MainActor.run {
                self.diplomaticRelations[proposal.proposerId] = proposal.agreementType.diplomaticStatus
                self.proposedDiplomacy.removeAll { $0.id == proposalId }
            }
        }
        
        await broadcastDiplomaticAction(.responseGiven(response))
    }
    
    /// Declare war or break diplomatic relations
    func changeDiplomaticStatus(with playerId: String, to status: DiplomaticStatus) async throws {
        let currentStatus = diplomaticRelations[playerId] ?? .neutral
        
        guard currentStatus != status else { return }
        
        // Validate status change
        guard isValidStatusChange(from: currentStatus, to: status) else {
            throw AllianceError.invalidDiplomaticChange
        }
        
        try await apiClient.changeDiplomaticStatus(
            fromPlayer: getCurrentPlayerId(),
            toPlayer: playerId,
            status: status
        )
        
        await MainActor.run {
            self.diplomaticRelations[playerId] = status
        }
        
        await broadcastDiplomaticAction(.statusChanged(getCurrentPlayerId(), playerId, status))
    }
    
    // MARK: - Cooperative Gameplay
    
    /// Create a shared trade route with alliance members
    func createCooperativeRoute(name: String, participants: [String], terms: CooperativeTerms) async throws {
        guard let alliance = currentAlliance else {
            throw AllianceError.noActiveAlliance
        }
        
        // Validate participants are alliance members
        let allianceMembers = Set(alliance.members.map { $0.playerId })
        guard Set(participants).isSubset(of: allianceMembers) else {
            throw AllianceError.invalidParticipants
        }
        
        let route = CooperativeRoute(
            id: UUID().uuidString,
            name: name,
            allianceId: alliance.id,
            participants: participants,
            terms: terms,
            status: .proposed,
            createdBy: getCurrentPlayerId(),
            createdAt: Date()
        )
        
        try await apiClient.createCooperativeRoute(route: route)
        
        await MainActor.run {
            self.cooperativeRoutes.append(route)
        }
        
        await broadcastCooperativeAction(.routeProposed(route))
    }
    
    /// Approve or reject a cooperative route
    func respondToCooperativeRoute(_ routeId: String, approved: Bool) async throws {
        guard var route = cooperativeRoutes.first(where: { $0.id == routeId }) else {
            throw AllianceError.routeNotFound
        }
        
        let playerId = getCurrentPlayerId()
        guard route.participants.contains(playerId) else {
            throw AllianceError.notParticipant
        }
        
        // Update route approval
        if approved {
            route.approvals[playerId] = true
        } else {
            route.status = .rejected
        }
        
        // Check if all participants have approved
        let allApproved = route.participants.allSatisfy { 
            route.approvals[$0] == true 
        }
        
        if allApproved {
            route.status = .active
        }
        
        try await apiClient.updateCooperativeRoute(route: route)
        
        await MainActor.run {
            if let index = self.cooperativeRoutes.firstIndex(where: { $0.id == routeId }) {
                self.cooperativeRoutes[index] = route
            }
        }
        
        await broadcastCooperativeAction(.routeResponseGiven(route, playerId, approved))
    }
    
    /// Share resources with alliance members
    func shareResource(type: ResourceType, amount: Double, recipients: [String]) async throws {
        guard let alliance = currentAlliance else {
            throw AllianceError.noActiveAlliance
        }
        
        guard hasPermission(.shareResources) else {
            throw AllianceError.insufficientPermissions
        }
        
        let sharedResource = SharedResource(
            id: UUID().uuidString,
            allianceId: alliance.id,
            sharerPlayerId: getCurrentPlayerId(),
            resourceType: type,
            amount: amount,
            recipients: recipients,
            timestamp: Date(),
            status: .pending
        )
        
        try await apiClient.shareResource(resource: sharedResource)
        
        await MainActor.run {
            self.sharedResources.append(sharedResource)
        }
        
        await broadcastCooperativeAction(.resourceShared(sharedResource))
    }
    
    // MARK: - Alliance Communication
    
    /// Send a message to alliance chat
    func sendAllianceMessage(_ content: String) async throws {
        guard let alliance = currentAlliance else {
            throw AllianceError.noActiveAlliance
        }
        
        let message = AllianceChatMessage(
            id: UUID().uuidString,
            allianceId: alliance.id,
            senderId: getCurrentPlayerId(),
            content: content,
            timestamp: Date(),
            messageType: .standard
        )
        
        try await apiClient.sendAllianceMessage(message: message)
        
        await MainActor.run {
            self.allianceChat.append(message)
        }
        
        await broadcastCommunication(.chatMessage(message))
    }
    
    /// Send an alliance-wide announcement
    func sendAllianceAnnouncement(_ content: String) async throws {
        guard hasPermission(.sendAnnouncements) else {
            throw AllianceError.insufficientPermissions
        }
        
        guard let alliance = currentAlliance else {
            throw AllianceError.noActiveAlliance
        }
        
        let message = AllianceChatMessage(
            id: UUID().uuidString,
            allianceId: alliance.id,
            senderId: getCurrentPlayerId(),
            content: content,
            timestamp: Date(),
            messageType: .announcement
        )
        
        try await apiClient.sendAllianceMessage(message: message)
        await broadcastCommunication(.announcement(message))
    }
    
    // MARK: - Alliance Management
    
    /// Update alliance member role
    func updateMemberRole(_ playerId: String, newRole: AllianceRole) async throws {
        guard var alliance = currentAlliance else {
            throw AllianceError.noActiveAlliance
        }
        
        guard hasPermission(.manageMembers) else {
            throw AllianceError.insufficientPermissions
        }
        
        guard let memberIndex = alliance.members.firstIndex(where: { $0.playerId == playerId }) else {
            throw AllianceError.memberNotFound
        }
        
        alliance.members[memberIndex].role = newRole
        
        try await apiClient.updateAlliance(alliance: alliance)
        
        await MainActor.run {
            self.currentAlliance = alliance
        }
        
        await broadcastAllianceUpdate(.memberRoleChanged(playerId, newRole))
    }
    
    /// Remove a member from the alliance
    func removeMember(_ playerId: String) async throws {
        guard var alliance = currentAlliance else {
            throw AllianceError.noActiveAlliance
        }
        
        guard hasPermission(.manageMembers) else {
            throw AllianceError.insufficientPermissions
        }
        
        alliance.members.removeAll { $0.playerId == playerId }
        
        try await apiClient.updateAlliance(alliance: alliance)
        
        await MainActor.run {
            self.currentAlliance = alliance
        }
        
        await broadcastAllianceUpdate(.memberRemoved(playerId))
    }
    
    // MARK: - Network Message Broadcasting
    
    private func broadcastAllianceUpdate(_ update: AllianceUpdate) async {
        let message = GameMessage(
            id: UUID().uuidString,
            type: .allianceUpdate,
            timestamp: Date(),
            payload: .allianceUpdate(update)
        )
        
        try? await multiplayerManager.sendGameAction(GameAction(
            playerId: getCurrentPlayerId(),
            actionType: "alliance_update",
            parameters: ["update": AnyCodable(update)]
        ))
    }
    
    private func broadcastDiplomaticAction(_ action: DiplomaticAction) async {
        let message = GameMessage(
            id: UUID().uuidString,
            type: .diplomaticAction,
            timestamp: Date(),
            payload: .diplomaticAction(action)
        )
        
        try? await multiplayerManager.sendGameAction(GameAction(
            playerId: getCurrentPlayerId(),
            actionType: "diplomatic_action",
            parameters: ["action": AnyCodable(action)]
        ))
    }
    
    private func broadcastCooperativeAction(_ action: CooperativeAction) async {
        let message = GameMessage(
            id: UUID().uuidString,
            type: .cooperativeAction,
            timestamp: Date(),
            payload: .cooperativeAction(action)
        )
        
        try? await multiplayerManager.sendGameAction(GameAction(
            playerId: getCurrentPlayerId(),
            actionType: "cooperative_action",
            parameters: ["action": AnyCodable(action)]
        ))
    }
    
    private func broadcastCommunication(_ communication: AllianceCommunication) async {
        let message = GameMessage(
            id: UUID().uuidString,
            type: .allianceCommunication,
            timestamp: Date(),
            payload: .allianceCommunication(communication)
        )
        
        try? await multiplayerManager.sendGameAction(GameAction(
            playerId: getCurrentPlayerId(),
            actionType: "alliance_communication",
            parameters: ["communication": AnyCodable(communication)]
        ))
    }
    
    // MARK: - Helper Methods
    
    private func initializeAllianceForSession(_ session: GameSession) {
        // Load alliance data for current session
        Task {
            do {
                let playerId = getCurrentPlayerId()
                if let alliance = try await apiClient.getPlayerAlliance(playerId: playerId) {
                    await MainActor.run {
                        self.currentAlliance = alliance
                    }
                    
                    // Load alliance-related data
                    await loadAllianceData(alliance)
                }
            } catch {
                print("Failed to load alliance data: \(error)")
            }
        }
    }
    
    private func loadAllianceData(_ alliance: Alliance) async {
        do {
            // Load alliance chat messages
            let messages = try await apiClient.getAllianceMessages(allianceId: alliance.id, limit: 50)
            await MainActor.run {
                self.allianceChat = messages
            }
            
            // Load cooperative routes
            let routes = try await apiClient.getCooperativeRoutes(allianceId: alliance.id)
            await MainActor.run {
                self.cooperativeRoutes = routes
            }
            
            // Load shared resources
            let resources = try await apiClient.getSharedResources(allianceId: alliance.id)
            await MainActor.run {
                self.sharedResources = resources
            }
            
        } catch {
            print("Failed to load alliance data: \(error)")
        }
    }
    
    private func hasPermission(_ permission: AlliancePermission) -> Bool {
        guard let alliance = currentAlliance,
              let member = alliance.members.first(where: { $0.playerId == getCurrentPlayerId() }) else {
            return false
        }
        
        return member.role.hasPermission(permission)
    }
    
    private func isValidStatusChange(from current: DiplomaticStatus, to new: DiplomaticStatus) -> Bool {
        switch (current, new) {
        case (.neutral, _): return true
        case (.ally, .neutral), (.ally, .enemy): return true
        case (.enemy, .neutral): return true
        case (.nonAggression, .neutral), (.nonAggression, .ally): return true
        case (.tradeAgreement, .neutral), (.tradeAgreement, .ally): return true
        default: return false
        }
    }
    
    private func getCurrentPlayerId() -> String {
        return UserDefaults.standard.string(forKey: "playerId") ?? "unknown"
    }
}

// MARK: - Alliance Models

struct Alliance: Codable, Identifiable {
    let id: String
    var name: String
    var description: String
    var type: AllianceType
    let founderId: String
    var members: [AllianceMember]
    let createdAt: Date
    var lastActivity: Date
    var isActive: Bool
    var tags: [String]
    var maxMembers: Int
    
    init(name: String, description: String, type: AllianceType, founderId: String, members: [AllianceMember]) {
        self.id = UUID().uuidString
        self.name = name
        self.description = description
        self.type = type
        self.founderId = founderId
        self.members = members
        self.createdAt = Date()
        self.lastActivity = Date()
        self.isActive = true
        self.tags = []
        self.maxMembers = type.maxMembers
    }
}

struct AllianceMember: Codable {
    let playerId: String
    var role: AllianceRole
    let joinedAt: Date
    var contribution: AllianceContribution
    var lastActivity: Date
    
    init(playerId: String, role: AllianceRole) {
        self.playerId = playerId
        self.role = role
        self.joinedAt = Date()
        self.contribution = AllianceContribution()
        self.lastActivity = Date()
    }
}

enum AllianceType: String, Codable, CaseIterable {
    case military = "Military"
    case trade = "Trade"
    case research = "Research"
    case diplomatic = "Diplomatic"
    case mixed = "Mixed"
    
    var maxMembers: Int {
        switch self {
        case .military: return 8
        case .trade: return 12
        case .research: return 6
        case .diplomatic: return 10
        case .mixed: return 16
        }
    }
    
    var description: String {
        switch self {
        case .military: return "Focused on combat and territorial control"
        case .trade: return "Focused on economic cooperation and trade"
        case .research: return "Focused on technological advancement"
        case .diplomatic: return "Focused on political influence and diplomacy"
        case .mixed: return "Balanced approach to all aspects"
        }
    }
}

enum AllianceRole: String, Codable, CaseIterable {
    case leader = "Leader"
    case officer = "Officer"
    case member = "Member"
    case recruit = "Recruit"
    
    func hasPermission(_ permission: AlliancePermission) -> Bool {
        switch self {
        case .leader:
            return true // Leader has all permissions
        case .officer:
            return permission != .disbandAlliance && permission != .transferLeadership
        case .member:
            return [.shareResources, .participateInRoutes, .sendMessages].contains(permission)
        case .recruit:
            return permission == .sendMessages
        }
    }
}

enum AlliancePermission: String, Codable, CaseIterable {
    case inviteMembers = "Invite Members"
    case manageMembers = "Manage Members"
    case shareResources = "Share Resources"
    case participateInRoutes = "Participate in Routes"
    case sendMessages = "Send Messages"
    case sendAnnouncements = "Send Announcements"
    case manageDiplomacy = "Manage Diplomacy"
    case disbandAlliance = "Disband Alliance"
    case transferLeadership = "Transfer Leadership"
}

struct AllianceContribution: Codable {
    var resourcesShared: Double = 0.0
    var routesCompleted: Int = 0
    var diplomaticActions: Int = 0
    var messagesContributed: Int = 0
    var lastContribution: Date = Date()
}

struct AllianceStrength: Codable {
    var military: Double = 0.0
    var economic: Double = 0.0
    var diplomatic: Double = 0.0
    var technological: Double = 0.0
    
    var overall: Double {
        (military + economic + diplomatic + technological) / 4.0
    }
}

// MARK: - Diplomatic Models

struct AllianceInvitation: Codable, Identifiable {
    let id: String
    let allianceId: String
    let allianceName: String
    let inviterId: String
    let inviteeId: String
    let proposedRole: AllianceRole
    let timestamp: Date
    var status: InvitationStatus
    let expiresAt: Date
    
    init(id: String, allianceId: String, allianceName: String, inviterId: String, 
         inviteeId: String, proposedRole: AllianceRole, timestamp: Date, status: InvitationStatus) {
        self.id = id
        self.allianceId = allianceId
        self.allianceName = allianceName
        self.inviterId = inviterId
        self.inviteeId = inviteeId
        self.proposedRole = proposedRole
        self.timestamp = timestamp
        self.status = status
        self.expiresAt = timestamp.addingTimeInterval(7 * 24 * 3600) // 7 days
    }
}

enum InvitationStatus: String, Codable {
    case pending = "Pending"
    case accepted = "Accepted"
    case declined = "Declined"
    case expired = "Expired"
}

struct DiplomaticProposal: Codable, Identifiable {
    let id: String
    let proposerId: String
    let targetId: String
    let agreementType: DiplomaticAgreementType
    let terms: DiplomaticTerms
    let timestamp: Date
    var status: ProposalStatus
    let expiresAt: Date
    
    init(id: String, proposerId: String, targetId: String, agreementType: DiplomaticAgreementType,
         terms: DiplomaticTerms, timestamp: Date, status: ProposalStatus) {
        self.id = id
        self.proposerId = proposerId
        self.targetId = targetId
        self.agreementType = agreementType
        self.terms = terms
        self.timestamp = timestamp
        self.status = status
        self.expiresAt = timestamp.addingTimeInterval(3 * 24 * 3600) // 3 days
    }
}

enum DiplomaticAgreementType: String, Codable, CaseIterable {
    case nonAggression = "Non-Aggression Pact"
    case tradeAgreement = "Trade Agreement"
    case alliance = "Alliance"
    case vassalage = "Vassalage"
    case neutrality = "Neutrality Pact"
    
    var diplomaticStatus: DiplomaticStatus {
        switch self {
        case .nonAggression: return .nonAggression
        case .tradeAgreement: return .tradeAgreement
        case .alliance: return .ally
        case .vassalage: return .vassal
        case .neutrality: return .neutral
        }
    }
}

enum DiplomaticStatus: String, Codable, CaseIterable {
    case ally = "Ally"
    case neutral = "Neutral"
    case enemy = "Enemy"
    case nonAggression = "Non-Aggression"
    case tradeAgreement = "Trade Agreement"
    case vassal = "Vassal"
    case overlord = "Overlord"
    
    var color: String {
        switch self {
        case .ally: return "green"
        case .neutral: return "gray"
        case .enemy: return "red"
        case .nonAggression: return "blue"
        case .tradeAgreement: return "yellow"
        case .vassal: return "purple"
        case .overlord: return "gold"
        }
    }
}

struct DiplomaticTerms: Codable {
    var duration: TimeInterval = 30 * 24 * 3600 // 30 days default
    var conditions: [String] = []
    var benefits: [String] = []
    var penalties: [String] = []
    var autoRenewal: Bool = false
}

enum ProposalStatus: String, Codable {
    case pending = "Pending"
    case accepted = "Accepted"
    case rejected = "Rejected"
    case expired = "Expired"
    case withdrawn = "Withdrawn"
}

// MARK: - Cooperative Models

struct CooperativeRoute: Codable, Identifiable {
    let id: String
    var name: String
    let allianceId: String
    let participants: [String]
    let terms: CooperativeTerms
    var status: CooperativeStatus
    let createdBy: String
    let createdAt: Date
    var approvals: [String: Bool] = [:]
    var profitSharing: [String: Double] = [:]
    
    init(id: String, name: String, allianceId: String, participants: [String],
         terms: CooperativeTerms, status: CooperativeStatus, createdBy: String, createdAt: Date) {
        self.id = id
        self.name = name
        self.allianceId = allianceId
        self.participants = participants
        self.terms = terms
        self.status = status
        self.createdBy = createdBy
        self.createdAt = createdAt
    }
}

struct CooperativeTerms: Codable {
    var profitSplit: [String: Double] = [:]
    var resourceContributions: [String: ResourceContribution] = [:]
    var responsibilities: [String: [String]] = [:]
    var duration: TimeInterval = 90 * 24 * 3600 // 90 days
}

struct ResourceContribution: Codable {
    let type: ResourceType
    let amount: Double
    let frequency: ContributionFrequency
}

enum ResourceType: String, Codable, CaseIterable {
    case money = "Money"
    case ships = "Ships"
    case fuel = "Fuel"
    case cargo = "Cargo"
    case intelligence = "Intelligence"
    case technology = "Technology"
}

enum ContributionFrequency: String, Codable {
    case once = "Once"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
}

enum CooperativeStatus: String, Codable {
    case proposed = "Proposed"
    case active = "Active"
    case suspended = "Suspended"
    case completed = "Completed"
    case rejected = "Rejected"
}

struct SharedResource: Codable, Identifiable {
    let id: String
    let allianceId: String
    let sharerPlayerId: String
    let resourceType: ResourceType
    let amount: Double
    let recipients: [String]
    let timestamp: Date
    var status: ResourceStatus
    var message: String?
}

enum ResourceStatus: String, Codable {
    case pending = "Pending"
    case distributed = "Distributed"
    case rejected = "Rejected"
}

// MARK: - Communication Models

struct AllianceChatMessage: Codable, Identifiable {
    let id: String
    let allianceId: String
    let senderId: String
    let content: String
    let timestamp: Date
    let messageType: ChatMessageType
    var isRead: Bool = false
    var reactions: [String: Int] = [:]
}

enum ChatMessageType: String, Codable {
    case standard = "Standard"
    case announcement = "Announcement"
    case system = "System"
    case diplomatic = "Diplomatic"
}

// MARK: - Network Message Types

enum AllianceUpdate: Codable {
    case created(Alliance)
    case disbanded(String) // alliance ID
    case memberJoined(String, Alliance) // player ID, alliance
    case memberLeft(String, Alliance) // player ID, alliance
    case memberRoleChanged(String, AllianceRole) // player ID, new role
    case memberRemoved(String) // player ID
}

enum DiplomaticAction: Codable {
    case invitationSent(AllianceInvitation)
    case proposalSent(DiplomaticProposal)
    case responseGiven(DiplomaticResponse)
    case statusChanged(String, String, DiplomaticStatus) // from player, to player, status
}

enum CooperativeAction: Codable {
    case routeProposed(CooperativeRoute)
    case routeResponseGiven(CooperativeRoute, String, Bool) // route, player, approved
    case resourceShared(SharedResource)
}

enum AllianceCommunication: Codable {
    case chatMessage(AllianceChatMessage)
    case announcement(AllianceChatMessage)
}

// MARK: - Response Models

struct InvitationResponse: Codable {
    let invitationId: String
    let playerId: String
    let accepted: Bool
    let timestamp: Date
}

struct DiplomaticResponse: Codable {
    let proposalId: String
    let responderId: String
    let accepted: Bool
    let counterTerms: DiplomaticTerms?
    let timestamp: Date
}

// MARK: - Error Types

enum AllianceError: LocalizedError {
    case alreadyInAlliance
    case noActiveAlliance
    case insufficientPermissions
    case invitationNotFound
    case proposalNotFound
    case memberNotFound
    case routeNotFound
    case notParticipant
    case invalidParticipants
    case invalidDiplomaticChange
    case creationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .alreadyInAlliance:
            return "Player is already in an alliance"
        case .noActiveAlliance:
            return "No active alliance found"
        case .insufficientPermissions:
            return "Insufficient permissions for this action"
        case .invitationNotFound:
            return "Alliance invitation not found"
        case .proposalNotFound:
            return "Diplomatic proposal not found"
        case .memberNotFound:
            return "Alliance member not found"
        case .routeNotFound:
            return "Cooperative route not found"
        case .notParticipant:
            return "Player is not a participant in this route"
        case .invalidParticipants:
            return "Invalid participants for this action"
        case .invalidDiplomaticChange:
            return "Invalid diplomatic status change"
        case .creationFailed(let reason):
            return "Alliance creation failed: \(reason)"
        }
    }
}

// MARK: - Extension for Message Types

extension GameMessage.MessageType {
    static let allianceUpdate = GameMessage.MessageType(rawValue: "allianceUpdate")!
    static let diplomaticAction = GameMessage.MessageType(rawValue: "diplomaticAction")!
    static let cooperativeAction = GameMessage.MessageType(rawValue: "cooperativeAction")!
    static let allianceCommunication = GameMessage.MessageType(rawValue: "allianceCommunication")!
}

extension MessagePayload {
    static func allianceUpdate(_ update: AllianceUpdate) -> MessagePayload {
        return .custom("allianceUpdate", update)
    }
    
    static func diplomaticAction(_ action: DiplomaticAction) -> MessagePayload {
        return .custom("diplomaticAction", action)
    }
    
    static func cooperativeAction(_ action: CooperativeAction) -> MessagePayload {
        return .custom("cooperativeAction", action)
    }
    
    static func allianceCommunication(_ communication: AllianceCommunication) -> MessagePayload {
        return .custom("allianceCommunication", communication)
    }
    
    private static func custom<T: Codable>(_ type: String, _ data: T) -> MessagePayload {
        // This would need to be implemented in the MessagePayload enum
        // For now, using a placeholder that would work with the existing system
        return .system(SystemMessage(message: "Alliance system message", severity: "info"))
    }
}