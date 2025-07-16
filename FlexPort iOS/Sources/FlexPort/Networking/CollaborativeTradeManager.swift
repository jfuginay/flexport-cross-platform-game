import Foundation
import Combine

/// Manages real-time collaborative trade route creation and multiplayer logistics
class CollaborativeTradeManager: ObservableObject {
    static let shared = CollaborativeTradeManager()
    
    @Published private(set) var activeCollaborations: [TradeCollaboration] = []
    @Published private(set) var invitations: [CollaborationInvitation] = []
    @Published private(set) var sharedRoutes: [SharedTradeRoute] = []
    @Published private(set) var collaborativeContracts: [CollaborativeContract] = []
    @Published private(set) var realTimeUsers: [RealTimeUser] = []
    @Published private(set) var routeTemplates: [RouteTemplate] = []
    
    private let apiClient = APIClient.shared
    private let multiplayerManager = MultiplayerManager.shared
    private let securityManager = SecurityManager.shared
    private let webSocketHandler = WebSocketHandler()
    private var cancellables = Set<AnyCancellable>()
    
    // Real-time collaboration state
    @Published private(set) var collaborationSessions: [String: CollaborationSession] = [:]
    @Published private(set) var activeCursors: [String: CollaborativeCursor] = [:]
    @Published private(set) var liveEdits: [String: [LiveEdit]] = [:]
    @Published private(set) var conflictResolutions: [String: ConflictResolution] = [:]
    
    // Performance tracking
    private var operationalThroughput = OperationalThroughput()
    private var collaborationMetrics = CollaborationMetrics()
    
    private init() {
        setupCollaborativeFeatures()
    }
    
    private func setupCollaborativeFeatures() {
        // Listen for real-time collaboration events
        webSocketHandler.messagePublisher
            .compactMap { message in
                if case .collaborativeUpdate(let update) = message.payload {
                    return update
                } else {
                    return nil
                }
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                self?.handleCollaborativeUpdate(update)
            }
            .store(in: &cancellables)
        
        // Track active users in collaboration sessions
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task {
                await self.updateActiveUsers()
            }
        }
        
        // Periodic sync of collaborative data
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            Task {
                await self.syncCollaborativeState()
            }
        }
    }
    
    // MARK: - Collaboration Session Management
    
    /// Start a new collaborative trade route design session
    func startCollaborativeSession(name: String, participants: [String], routeTemplate: RouteTemplate? = nil) async throws -> CollaborationSession {
        let sessionId = UUID().uuidString
        let playerId = getCurrentPlayerId()
        
        let session = CollaborationSession(
            id: sessionId,
            name: name,
            hostId: playerId,
            participants: participants,
            status: .active,
            routeTemplate: routeTemplate,
            createdAt: Date()
        )
        
        try await apiClient.createCollaborationSession(session: session)
        
        await MainActor.run {
            self.collaborationSessions[sessionId] = session
        }
        
        // Invite participants
        for participantId in participants {
            let invitation = CollaborationInvitation(
                id: UUID().uuidString,
                sessionId: sessionId,
                sessionName: name,
                hostId: playerId,
                inviteeId: participantId,
                timestamp: Date(),
                status: .pending
            )
            
            try await sendCollaborationInvitation(invitation)
        }
        
        await broadcastCollaborativeAction(.sessionCreated(session))
        return session
    }
    
    /// Join an existing collaboration session
    func joinCollaborationSession(_ sessionId: String) async throws {
        let playerId = getCurrentPlayerId()
        
        guard let session = collaborationSessions[sessionId] else {
            throw CollaborativeError.sessionNotFound
        }
        
        guard session.participants.contains(playerId) || session.isPublic else {
            throw CollaborativeError.notInvited
        }
        
        // Update session participant status
        try await apiClient.joinCollaborationSession(sessionId: sessionId, playerId: playerId)
        
        await MainActor.run {
            self.collaborationSessions[sessionId]?.activeParticipants.insert(playerId)
        }
        
        // Start real-time collaboration
        try await startRealTimeCollaboration(sessionId)
        
        await broadcastCollaborativeAction(.participantJoined(sessionId, playerId))
    }
    
    /// Leave a collaboration session
    func leaveCollaborationSession(_ sessionId: String) async throws {
        let playerId = getCurrentPlayerId()
        
        try await apiClient.leaveCollaborationSession(sessionId: sessionId, playerId: playerId)
        
        await MainActor.run {
            self.collaborationSessions[sessionId]?.activeParticipants.remove(playerId)
            self.activeCursors.removeValue(forKey: playerId)
            self.liveEdits[sessionId]?.removeAll { $0.playerId == playerId }
        }
        
        await broadcastCollaborativeAction(.participantLeft(sessionId, playerId))
    }
    
    // MARK: - Real-Time Collaborative Route Design
    
    /// Create a shared trade route collaboratively
    func createSharedRoute(sessionId: String, routeData: RouteDesignData) async throws -> SharedTradeRoute {
        guard let session = collaborationSessions[sessionId] else {
            throw CollaborativeError.sessionNotFound
        }
        
        let playerId = getCurrentPlayerId()
        guard session.activeParticipants.contains(playerId) else {
            throw CollaborativeError.notParticipant
        }
        
        // Validate route design with security checks
        let validation = await securityManager.validateGameAction(GameAction(
            playerId: playerId,
            actionType: "create_shared_route",
            parameters: [
                "sessionId": AnyCodable(sessionId),
                "routeData": AnyCodable(routeData)
            ]
        ))
        
        guard validation.isValid else {
            throw CollaborativeError.invalidRouteData
        }
        
        let sharedRoute = SharedTradeRoute(
            id: UUID().uuidString,
            sessionId: sessionId,
            routeData: routeData,
            contributors: session.activeParticipants,
            createdBy: playerId,
            createdAt: Date(),
            status: .draft
        )
        
        try await apiClient.createSharedRoute(route: sharedRoute)
        
        await MainActor.run {
            self.sharedRoutes.append(sharedRoute)
        }
        
        await broadcastCollaborativeAction(.routeCreated(sharedRoute))
        return sharedRoute
    }
    
    /// Update route design in real-time
    func updateRouteDesign(routeId: String, changes: RouteDesignChanges) async throws {
        let playerId = getCurrentPlayerId()
        let timestamp = Date()
        
        // Create live edit
        let liveEdit = LiveEdit(
            id: UUID().uuidString,
            routeId: routeId,
            playerId: playerId,
            changes: changes,
            timestamp: timestamp,
            status: .pending
        )
        
        // Apply optimistic update locally
        await MainActor.run {
            if self.liveEdits[routeId] == nil {
                self.liveEdits[routeId] = []
            }
            self.liveEdits[routeId]?.append(liveEdit)
        }
        
        // Send to other participants
        await broadcastCollaborativeAction(.liveEdit(liveEdit))
        
        // Validate and apply on server
        do {
            let validatedEdit = try await apiClient.applyRouteEdit(edit: liveEdit)
            
            await MainActor.run {
                if let index = self.liveEdits[routeId]?.firstIndex(where: { $0.id == liveEdit.id }) {
                    self.liveEdits[routeId]?[index] = validatedEdit
                }
            }
            
        } catch {
            // Handle edit conflict
            await handleEditConflict(liveEdit, error: error)
        }
    }
    
    /// Update collaborative cursor position
    func updateCursorPosition(sessionId: String, position: CursorPosition) async {
        let playerId = getCurrentPlayerId()
        
        let cursor = CollaborativeCursor(
            playerId: playerId,
            sessionId: sessionId,
            position: position,
            timestamp: Date()
        )
        
        await MainActor.run {
            self.activeCursors[playerId] = cursor
        }
        
        await broadcastCollaborativeAction(.cursorMoved(cursor))
    }
    
    // MARK: - Collaborative Contracts & Agreements
    
    /// Create a collaborative contract for shared routes
    func createCollaborativeContract(routeId: String, terms: ContractTerms, participants: [String]) async throws -> CollaborativeContract {
        let playerId = getCurrentPlayerId()
        
        let contract = CollaborativeContract(
            id: UUID().uuidString,
            routeId: routeId,
            initiatorId: playerId,
            participants: participants,
            terms: terms,
            status: .proposed,
            createdAt: Date()
        )
        
        try await apiClient.createCollaborativeContract(contract: contract)
        
        await MainActor.run {
            self.collaborativeContracts.append(contract)
        }
        
        await broadcastCollaborativeAction(.contractProposed(contract))
        return contract
    }
    
    /// Sign a collaborative contract
    func signContract(_ contractId: String, signature: DigitalSignature) async throws {
        let playerId = getCurrentPlayerId()
        
        guard var contract = collaborativeContracts.first(where: { $0.id == contractId }) else {
            throw CollaborativeError.contractNotFound
        }
        
        guard contract.participants.contains(playerId) else {
            throw CollaborativeError.notContractParticipant
        }
        
        // Validate signature
        guard securityManager.validateAuthToken(signature.token, playerId: playerId, sessionId: signature.sessionId) else {
            throw CollaborativeError.invalidSignature
        }
        
        contract.signatures[playerId] = signature
        
        // Check if all participants have signed
        let allSigned = contract.participants.allSatisfy { contract.signatures[$0] != nil }
        if allSigned {
            contract.status = .active
            contract.activatedAt = Date()
        }
        
        try await apiClient.updateCollaborativeContract(contract: contract)
        
        await MainActor.run {
            if let index = self.collaborativeContracts.firstIndex(where: { $0.id == contractId }) {
                self.collaborativeContracts[index] = contract
            }
        }
        
        await broadcastCollaborativeAction(.contractSigned(contractId, playerId, allSigned))
    }
    
    // MARK: - Route Templates & Sharing
    
    /// Create a reusable route template
    func createRouteTemplate(name: String, description: String, routeData: RouteDesignData, isPublic: Bool = false) async throws -> RouteTemplate {
        let playerId = getCurrentPlayerId()
        
        let template = RouteTemplate(
            id: UUID().uuidString,
            name: name,
            description: description,
            creatorId: playerId,
            routeData: routeData,
            isPublic: isPublic,
            createdAt: Date(),
            usageCount: 0
        )
        
        try await apiClient.createRouteTemplate(template: template)
        
        await MainActor.run {
            self.routeTemplates.append(template)
        }
        
        return template
    }
    
    /// Load route templates
    func loadRouteTemplates(category: TemplateCategory? = nil, searchTerm: String? = nil) async {
        do {
            let templates = try await apiClient.getRouteTemplates(category: category, searchTerm: searchTerm)
            
            await MainActor.run {
                self.routeTemplates = templates
            }
            
        } catch {
            print("Failed to load route templates: \(error)")
        }
    }
    
    /// Use a route template in collaboration
    func useRouteTemplate(_ templateId: String, sessionId: String) async throws {
        guard let template = routeTemplates.first(where: { $0.id == templateId }) else {
            throw CollaborativeError.templateNotFound
        }
        
        guard let session = collaborationSessions[sessionId] else {
            throw CollaborativeError.sessionNotFound
        }
        
        let playerId = getCurrentPlayerId()
        guard session.activeParticipants.contains(playerId) else {
            throw CollaborativeError.notParticipant
        }
        
        // Apply template to current collaboration
        let templateApplication = TemplateApplication(
            templateId: templateId,
            sessionId: sessionId,
            appliedBy: playerId,
            appliedAt: Date()
        )
        
        try await apiClient.applyRouteTemplate(application: templateApplication)
        
        await broadcastCollaborativeAction(.templateApplied(templateApplication))
    }
    
    // MARK: - Operational Throughput & Performance
    
    /// Calculate operational throughput for collaborative routes
    func calculateOperationalThroughput(routeId: String, timeframe: TimeInterval) async -> OperationalThroughputResult {
        guard let route = sharedRoutes.first(where: { $0.id == routeId }) else {
            return OperationalThroughputResult()
        }
        
        let metrics = try? await apiClient.getRoutePerformanceMetrics(
            routeId: routeId,
            timeframe: timeframe
        )
        
        let throughput = OperationalThroughputResult(
            totalVolume: metrics?.totalVolume ?? 0,
            averageDeliveryTime: metrics?.averageDeliveryTime ?? 0,
            efficiencyRating: metrics?.efficiencyRating ?? 0,
            costEffectiveness: metrics?.costEffectiveness ?? 0,
            collaborationBonus: calculateCollaborationBonus(route)
        )
        
        return throughput
    }
    
    /// Get real-time performance updates
    func subscribeToPerformanceUpdates(routeId: String) async {
        // Subscribe to real-time performance data
        let subscription = PerformanceSubscription(
            routeId: routeId,
            playerId: getCurrentPlayerId(),
            startTime: Date()
        )
        
        try? await apiClient.subscribeToPerformanceUpdates(subscription: subscription)
    }
    
    // MARK: - Conflict Resolution
    
    private func handleEditConflict(_ edit: LiveEdit, error: Error) async {
        let conflict = EditConflict(
            editId: edit.id,
            routeId: edit.routeId,
            conflictingPlayerId: edit.playerId,
            conflictType: .simultaneousEdit,
            timestamp: Date(),
            error: error.localizedDescription
        )
        
        // Attempt automatic resolution
        let resolution = await attemptAutomaticResolution(conflict)
        
        if let resolution = resolution {
            await applyConflictResolution(resolution)
        } else {
            // Require manual resolution
            await requestManualResolution(conflict)
        }
    }
    
    private func attemptAutomaticResolution(_ conflict: EditConflict) async -> ConflictResolution? {
        // Implement automatic conflict resolution logic
        // For example: last-write-wins, merge compatible changes, etc.
        
        return ConflictResolution(
            conflictId: conflict.id,
            resolutionType: .lastWriteWins,
            resolvedBy: "system",
            resolvedAt: Date(),
            resolutionData: [:]
        )
    }
    
    private func applyConflictResolution(_ resolution: ConflictResolution) async {
        await MainActor.run {
            self.conflictResolutions[resolution.conflictId] = resolution
        }
        
        await broadcastCollaborativeAction(.conflictResolved(resolution))
    }
    
    private func requestManualResolution(_ conflict: EditConflict) async {
        await broadcastCollaborativeAction(.conflictDetected(conflict))
    }
    
    // MARK: - Real-Time Features
    
    private func startRealTimeCollaboration(_ sessionId: String) async throws {
        // Establish WebSocket connection for real-time features
        try await webSocketHandler.connect(sessionId: sessionId, authToken: getAuthToken())
        
        // Start sending periodic heartbeat
        startCollaborationHeartbeat(sessionId)
    }
    
    private func startCollaborationHeartbeat(_ sessionId: String) {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { timer in
            Task {
                let heartbeat = CollaborationHeartbeat(
                    sessionId: sessionId,
                    playerId: self.getCurrentPlayerId(),
                    timestamp: Date(),
                    status: .active
                )
                
                await self.broadcastCollaborativeAction(.heartbeat(heartbeat))
            }
        }
    }
    
    private func updateActiveUsers() async {
        // Update list of users active in real-time collaboration
        let activeUsers = collaborationSessions.values.flatMap { session in
            session.activeParticipants.map { participantId in
                RealTimeUser(
                    playerId: participantId,
                    sessionId: session.id,
                    lastActivity: Date(),
                    status: .active
                )
            }
        }
        
        await MainActor.run {
            self.realTimeUsers = activeUsers
        }
    }
    
    private func syncCollaborativeState() async {
        // Sync collaborative state with server
        for (sessionId, session) in collaborationSessions {
            do {
                let serverSession = try await apiClient.getCollaborationSession(id: sessionId)
                
                await MainActor.run {
                    self.collaborationSessions[sessionId] = serverSession
                }
                
            } catch {
                print("Failed to sync session \(sessionId): \(error)")
            }
        }
    }
    
    // MARK: - Network Message Handling
    
    private func handleCollaborativeUpdate(_ update: CollaborativeUpdate) {
        switch update {
        case .liveEdit(let edit):
            handleLiveEdit(edit)
            
        case .cursorMoved(let cursor):
            activeCursors[cursor.playerId] = cursor
            
        case .participantJoined(let sessionId, let playerId):
            collaborationSessions[sessionId]?.activeParticipants.insert(playerId)
            
        case .participantLeft(let sessionId, let playerId):
            collaborationSessions[sessionId]?.activeParticipants.remove(playerId)
            activeCursors.removeValue(forKey: playerId)
            
        case .conflictDetected(let conflict):
            handleConflictDetection(conflict)
            
        case .conflictResolved(let resolution):
            conflictResolutions[resolution.conflictId] = resolution
            
        case .performanceUpdate(let update):
            handlePerformanceUpdate(update)
        }
    }
    
    private func handleLiveEdit(_ edit: LiveEdit) {
        if liveEdits[edit.routeId] == nil {
            liveEdits[edit.routeId] = []
        }
        liveEdits[edit.routeId]?.append(edit)
        
        // Apply edit to local route data
        applyEditLocally(edit)
    }
    
    private func handleConflictDetection(_ conflict: EditConflict) {
        // Handle conflict detection from other participants
        print("Conflict detected: \(conflict.conflictType)")
    }
    
    private func handlePerformanceUpdate(_ update: PerformanceUpdate) {
        // Update real-time performance metrics
        operationalThroughput.updateMetrics(update)
    }
    
    private func applyEditLocally(_ edit: LiveEdit) {
        // Apply edit changes to local route data
        guard let routeIndex = sharedRoutes.firstIndex(where: { $0.id == edit.routeId }) else {
            return
        }
        
        // Apply the changes from the edit
        var route = sharedRoutes[routeIndex]
        route.routeData = edit.changes.applyTo(route.routeData)
        route.lastModified = edit.timestamp
        route.lastModifiedBy = edit.playerId
        
        sharedRoutes[routeIndex] = route
    }
    
    private func broadcastCollaborativeAction(_ action: CollaborativeAction) async {
        let message = GameMessage(
            id: UUID().uuidString,
            type: .collaborativeAction,
            timestamp: Date(),
            payload: .collaborativeAction(action)
        )
        
        try? await webSocketHandler.send(message)
    }
    
    // MARK: - Invitations
    
    private func sendCollaborationInvitation(_ invitation: CollaborationInvitation) async throws {
        try await apiClient.sendCollaborationInvitation(invitation: invitation)
        
        await MainActor.run {
            self.invitations.append(invitation)
        }
        
        await broadcastCollaborativeAction(.invitationSent(invitation))
    }
    
    /// Respond to collaboration invitation
    func respondToInvitation(_ invitationId: String, accept: Bool) async throws {
        guard let invitation = invitations.first(where: { $0.id == invitationId }) else {
            throw CollaborativeError.invitationNotFound
        }
        
        let response = InvitationResponse(
            invitationId: invitationId,
            playerId: getCurrentPlayerId(),
            accepted: accept,
            timestamp: Date()
        )
        
        try await apiClient.respondToCollaborationInvitation(response: response)
        
        await MainActor.run {
            self.invitations.removeAll { $0.id == invitationId }
        }
        
        if accept {
            try await joinCollaborationSession(invitation.sessionId)
        }
        
        await broadcastCollaborativeAction(.invitationResponse(response))
    }
    
    // MARK: - Helper Methods
    
    private func calculateCollaborationBonus(_ route: SharedTradeRoute) -> Double {
        // Calculate efficiency bonus based on number of contributors
        let baseBonus = 1.0
        let contributorBonus = Double(route.contributors.count) * 0.1
        let experienceBonus = route.collaborativeExperience * 0.05
        
        return baseBonus + contributorBonus + experienceBonus
    }
    
    private func getCurrentPlayerId() -> String {
        return UserDefaults.standard.string(forKey: "playerId") ?? "unknown"
    }
    
    private func getAuthToken() -> String {
        return UserDefaults.standard.string(forKey: "authToken") ?? "mock_token"
    }
}

// MARK: - Collaboration Models

struct CollaborationSession: Codable, Identifiable {
    let id: String
    var name: String
    let hostId: String
    let participants: [String]
    var activeParticipants: Set<String>
    var status: SessionStatus
    let routeTemplate: RouteTemplate?
    let createdAt: Date
    var lastActivity: Date
    let isPublic: Bool
    let maxParticipants: Int
    
    init(id: String, name: String, hostId: String, participants: [String], 
         status: SessionStatus, routeTemplate: RouteTemplate?, createdAt: Date) {
        self.id = id
        self.name = name
        self.hostId = hostId
        self.participants = participants
        self.activeParticipants = Set(participants)
        self.status = status
        self.routeTemplate = routeTemplate
        self.createdAt = createdAt
        self.lastActivity = createdAt
        self.isPublic = false
        self.maxParticipants = 16
    }
}

enum SessionStatus: String, Codable {
    case active = "Active"
    case paused = "Paused"
    case completed = "Completed"
    case cancelled = "Cancelled"
}

struct CollaborationInvitation: Codable, Identifiable {
    let id: String
    let sessionId: String
    let sessionName: String
    let hostId: String
    let inviteeId: String
    let timestamp: Date
    var status: InvitationStatus
    let expiresAt: Date
    
    init(id: String, sessionId: String, sessionName: String, hostId: String, 
         inviteeId: String, timestamp: Date, status: InvitationStatus) {
        self.id = id
        self.sessionId = sessionId
        self.sessionName = sessionName
        self.hostId = hostId
        self.inviteeId = inviteeId
        self.timestamp = timestamp
        self.status = status
        self.expiresAt = timestamp.addingTimeInterval(7 * 24 * 3600) // 7 days
    }
}

struct SharedTradeRoute: Codable, Identifiable {
    let id: String
    let sessionId: String
    var routeData: RouteDesignData
    let contributors: Set<String>
    let createdBy: String
    let createdAt: Date
    var lastModified: Date
    var lastModifiedBy: String
    var status: RouteStatus
    var collaborativeExperience: Double
    var profitSharing: [String: Double]
    var performanceMetrics: RoutePerformanceMetrics?
    
    init(id: String, sessionId: String, routeData: RouteDesignData, contributors: Set<String>, 
         createdBy: String, createdAt: Date, status: RouteStatus) {
        self.id = id
        self.sessionId = sessionId
        self.routeData = routeData
        self.contributors = contributors
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.lastModified = createdAt
        self.lastModifiedBy = createdBy
        self.status = status
        self.collaborativeExperience = 0.0
        self.profitSharing = [:]
    }
}

enum RouteStatus: String, Codable {
    case draft = "Draft"
    case active = "Active"
    case paused = "Paused"
    case completed = "Completed"
    case cancelled = "Cancelled"
}

struct RouteDesignData: Codable {
    var waypoints: [Waypoint]
    var cargo: [CargoAllocation]
    var vessels: [VesselAssignment]
    var schedule: RouteSchedule
    var optimization: OptimizationSettings
    var constraints: [RouteConstraint]
    
    init() {
        self.waypoints = []
        self.cargo = []
        self.vessels = []
        self.schedule = RouteSchedule()
        self.optimization = OptimizationSettings()
        self.constraints = []
    }
}

struct Waypoint: Codable, Identifiable {
    let id: String
    var location: Location
    var arrivalTime: Date?
    var departureTime: Date?
    var services: [PortService]
    var loadOperations: [LoadOperation]
    var unloadOperations: [UnloadOperation]
    
    init(location: Location) {
        self.id = UUID().uuidString
        self.location = location
        self.services = []
        self.loadOperations = []
        self.unloadOperations = []
    }
}

struct CargoAllocation: Codable, Identifiable {
    let id: String
    var cargoType: String
    var quantity: Int
    var weight: Double
    var origin: String
    var destination: String
    var priority: CargoPriority
    var specialRequirements: [String]
    var assignedVessel: String?
}

enum CargoPriority: String, Codable, CaseIterable {
    case low = "Low"
    case normal = "Normal"
    case high = "High"
    case urgent = "Urgent"
}

struct VesselAssignment: Codable, Identifiable {
    let id: String
    var vesselId: String
    var role: VesselRole
    var assignedRoute: [String] // Waypoint IDs
    var capacity: VesselCapacity
    var schedule: VesselSchedule
    var owner: String // Player ID who owns the vessel
}

enum VesselRole: String, Codable, CaseIterable {
    case primary = "Primary"
    case support = "Support"
    case backup = "Backup"
    case specialized = "Specialized"
}

struct VesselCapacity: Codable {
    let maxWeight: Double
    let maxVolume: Double
    let specializedCapabilities: [String]
    var currentLoad: Double
    
    init(maxWeight: Double, maxVolume: Double) {
        self.maxWeight = maxWeight
        self.maxVolume = maxVolume
        self.specializedCapabilities = []
        self.currentLoad = 0.0
    }
}

struct VesselSchedule: Codable {
    var departureTimes: [String: Date] // Waypoint ID to departure time
    var arrivalTimes: [String: Date] // Waypoint ID to arrival time
    var maintenanceWindows: [MaintenanceWindow]
    var availabilityPeriods: [AvailabilityPeriod]
}

struct MaintenanceWindow: Codable {
    let startDate: Date
    let endDate: Date
    let type: MaintenanceType
    let location: String
}

enum MaintenanceType: String, Codable {
    case routine = "Routine"
    case emergency = "Emergency"
    case upgrade = "Upgrade"
    case inspection = "Inspection"
}

struct AvailabilityPeriod: Codable {
    let startDate: Date
    let endDate: Date
    let availabilityType: AvailabilityType
}

enum AvailabilityType: String, Codable {
    case available = "Available"
    case reserved = "Reserved"
    case maintenance = "Maintenance"
    case transit = "Transit"
}

struct RouteSchedule: Codable {
    var frequency: ScheduleFrequency
    var startDate: Date?
    var endDate: Date?
    var recurringPattern: RecurringPattern?
    var exceptions: [ScheduleException]
    
    init() {
        self.frequency = .weekly
        self.exceptions = []
    }
}

enum ScheduleFrequency: String, Codable, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case biweekly = "Biweekly"
    case monthly = "Monthly"
    case onDemand = "On Demand"
}

struct RecurringPattern: Codable {
    let daysOfWeek: [Int] // 1-7, Monday-Sunday
    let timesOfDay: [String] // HH:MM format
    let monthlyPattern: MonthlyPattern?
}

enum MonthlyPattern: String, Codable {
    case firstWeek = "First Week"
    case secondWeek = "Second Week"
    case thirdWeek = "Third Week"
    case fourthWeek = "Fourth Week"
    case lastWeek = "Last Week"
}

struct ScheduleException: Codable {
    let date: Date
    let type: ExceptionType
    let reason: String
    let alternativeArrangement: String?
}

enum ExceptionType: String, Codable {
    case holiday = "Holiday"
    case weather = "Weather"
    case maintenance = "Maintenance"
    case emergency = "Emergency"
    case custom = "Custom"
}

struct OptimizationSettings: Codable {
    var objective: OptimizationObjective
    var constraints: OptimizationConstraints
    var parameters: OptimizationParameters
    
    init() {
        self.objective = .profitMaximization
        self.constraints = OptimizationConstraints()
        self.parameters = OptimizationParameters()
    }
}

enum OptimizationObjective: String, Codable, CaseIterable {
    case profitMaximization = "Profit Maximization"
    case timeMinimization = "Time Minimization"
    case costMinimization = "Cost Minimization"
    case carbonFootprintMinimization = "Carbon Footprint Minimization"
    case balancedApproach = "Balanced Approach"
}

struct OptimizationConstraints: Codable {
    var maxDeliveryTime: TimeInterval?
    var maxCost: Double?
    var minReliability: Double?
    var environmentalLimits: EnvironmentalLimits?
    var regulatoryCompliance: [String]
    
    init() {
        self.regulatoryCompliance = []
    }
}

struct EnvironmentalLimits: Codable {
    let maxCarbonEmissions: Double
    let maxNoise: Double
    let wasteManagementRequirements: [String]
}

struct OptimizationParameters: Codable {
    var weatherConsideration: Double // 0.0 - 1.0
    var trafficConsideration: Double // 0.0 - 1.0
    var fuelPriceVolatility: Double // 0.0 - 1.0
    var riskTolerance: Double // 0.0 - 1.0
    
    init() {
        self.weatherConsideration = 0.8
        self.trafficConsideration = 0.7
        self.fuelPriceVolatility = 0.6
        self.riskTolerance = 0.5
    }
}

struct RouteConstraint: Codable, Identifiable {
    let id: String
    let type: ConstraintType
    let description: String
    let severity: ConstraintSeverity
    let parameters: [String: AnyCodable]
}

enum ConstraintType: String, Codable, CaseIterable {
    case timeWindow = "Time Window"
    case capacity = "Capacity"
    case regulatory = "Regulatory"
    case environmental = "Environmental"
    case cost = "Cost"
    case security = "Security"
}

enum ConstraintSeverity: String, Codable, CaseIterable {
    case soft = "Soft"
    case hard = "Hard"
    case critical = "Critical"
}

struct LoadOperation: Codable, Identifiable {
    let id: String
    var cargoId: String
    var quantity: Int
    var estimatedTime: TimeInterval
    var specialEquipment: [String]
    var safetyRequirements: [String]
}

struct UnloadOperation: Codable, Identifiable {
    let id: String
    var cargoId: String
    var quantity: Int
    var estimatedTime: TimeInterval
    var destination: String // Warehouse or customer
    var qualityChecks: [QualityCheck]
}

struct QualityCheck: Codable {
    let checkType: String
    let requirements: [String]
    let estimatedTime: TimeInterval
}

// MARK: - Real-Time Collaboration

struct CollaborativeCursor: Codable {
    let playerId: String
    let sessionId: String
    let position: CursorPosition
    let timestamp: Date
    let color: String
    
    init(playerId: String, sessionId: String, position: CursorPosition, timestamp: Date) {
        self.playerId = playerId
        self.sessionId = sessionId
        self.position = position
        self.timestamp = timestamp
        self.color = CursorColor.colorForPlayer(playerId)
    }
}

struct CursorPosition: Codable {
    let x: Double
    let y: Double
    let zoom: Double
    let context: CursorContext
}

enum CursorContext: String, Codable {
    case mapView = "Map View"
    case routeDesign = "Route Design"
    case cargoAllocation = "Cargo Allocation"
    case scheduling = "Scheduling"
    case optimization = "Optimization"
}

struct CursorColor {
    static func colorForPlayer(_ playerId: String) -> String {
        let colors = ["#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FECA57", "#FF9FF3", "#54A0FF"]
        let hash = playerId.hash
        return colors[abs(hash) % colors.count]
    }
}

struct LiveEdit: Codable, Identifiable {
    let id: String
    let routeId: String
    let playerId: String
    let changes: RouteDesignChanges
    let timestamp: Date
    var status: EditStatus
    let conflict: EditConflict?
    
    init(id: String, routeId: String, playerId: String, changes: RouteDesignChanges, timestamp: Date, status: EditStatus) {
        self.id = id
        self.routeId = routeId
        self.playerId = playerId
        self.changes = changes
        self.timestamp = timestamp
        self.status = status
        self.conflict = nil
    }
}

enum EditStatus: String, Codable {
    case pending = "Pending"
    case applied = "Applied"
    case rejected = "Rejected"
    case conflicted = "Conflicted"
}

struct RouteDesignChanges: Codable {
    let changeType: ChangeType
    let targetId: String // ID of the element being changed
    let oldValue: AnyCodable?
    let newValue: AnyCodable
    let metadata: [String: AnyCodable]
    
    func applyTo(_ routeData: RouteDesignData) -> RouteDesignData {
        var updatedData = routeData
        
        switch changeType {
        case .addWaypoint:
            if let waypoint = newValue.value as? Waypoint {
                updatedData.waypoints.append(waypoint)
            }
        case .removeWaypoint:
            updatedData.waypoints.removeAll { $0.id == targetId }
        case .updateWaypoint:
            if let index = updatedData.waypoints.firstIndex(where: { $0.id == targetId }),
               let waypoint = newValue.value as? Waypoint {
                updatedData.waypoints[index] = waypoint
            }
        case .addCargo:
            if let cargo = newValue.value as? CargoAllocation {
                updatedData.cargo.append(cargo)
            }
        case .updateCargo:
            if let index = updatedData.cargo.firstIndex(where: { $0.id == targetId }),
               let cargo = newValue.value as? CargoAllocation {
                updatedData.cargo[index] = cargo
            }
        case .addVessel:
            if let vessel = newValue.value as? VesselAssignment {
                updatedData.vessels.append(vessel)
            }
        case .updateVessel:
            if let index = updatedData.vessels.firstIndex(where: { $0.id == targetId }),
               let vessel = newValue.value as? VesselAssignment {
                updatedData.vessels[index] = vessel
            }
        case .updateSchedule:
            if let schedule = newValue.value as? RouteSchedule {
                updatedData.schedule = schedule
            }
        case .updateOptimization:
            if let optimization = newValue.value as? OptimizationSettings {
                updatedData.optimization = optimization
            }
        }
        
        return updatedData
    }
}

enum ChangeType: String, Codable, CaseIterable {
    case addWaypoint = "Add Waypoint"
    case removeWaypoint = "Remove Waypoint"
    case updateWaypoint = "Update Waypoint"
    case addCargo = "Add Cargo"
    case removeCargo = "Remove Cargo"
    case updateCargo = "Update Cargo"
    case addVessel = "Add Vessel"
    case removeVessel = "Remove Vessel"
    case updateVessel = "Update Vessel"
    case updateSchedule = "Update Schedule"
    case updateOptimization = "Update Optimization"
    case addConstraint = "Add Constraint"
    case removeConstraint = "Remove Constraint"
}

// MARK: - Contracts & Agreements

struct CollaborativeContract: Codable, Identifiable {
    let id: String
    let routeId: String
    let initiatorId: String
    let participants: [String]
    let terms: ContractTerms
    var status: ContractStatus
    let createdAt: Date
    var activatedAt: Date?
    var signatures: [String: DigitalSignature]
    var amendments: [ContractAmendment]
    
    init(id: String, routeId: String, initiatorId: String, participants: [String], 
         terms: ContractTerms, status: ContractStatus, createdAt: Date) {
        self.id = id
        self.routeId = routeId
        self.initiatorId = initiatorId
        self.participants = participants
        self.terms = terms
        self.status = status
        self.createdAt = createdAt
        self.signatures = [:]
        self.amendments = []
    }
}

enum ContractStatus: String, Codable {
    case proposed = "Proposed"
    case active = "Active"
    case completed = "Completed"
    case terminated = "Terminated"
    case disputed = "Disputed"
}

struct ContractTerms: Codable {
    let duration: TimeInterval
    let profitSharing: [String: Double] // Player ID to percentage
    let responsibilities: [String: [String]] // Player ID to responsibilities
    let penalties: [ContractPenalty]
    let bonuses: [ContractBonus]
    let termination: TerminationClause
    let disputeResolution: DisputeResolutionClause
}

struct ContractPenalty: Codable {
    let condition: String
    let amount: Double
    let type: PenaltyType
}

enum PenaltyType: String, Codable {
    case fixed = "Fixed"
    case percentage = "Percentage"
    case performance = "Performance"
}

struct ContractBonus: Codable {
    let condition: String
    let amount: Double
    let type: BonusType
}

enum BonusType: String, Codable {
    case efficiency = "Efficiency"
    case time = "Time"
    case quality = "Quality"
    case safety = "Safety"
}

struct TerminationClause: Codable {
    let noticePeriod: TimeInterval
    let earlyTerminationFee: Double?
    let conditions: [String]
}

struct DisputeResolutionClause: Codable {
    let method: DisputeResolutionMethod
    let arbitrator: String?
    let timeLimit: TimeInterval
}

enum DisputeResolutionMethod: String, Codable {
    case negotiation = "Negotiation"
    case mediation = "Mediation"
    case arbitration = "Arbitration"
    case communityVote = "Community Vote"
}

struct ContractAmendment: Codable, Identifiable {
    let id: String
    let proposedBy: String
    let changes: [String: AnyCodable]
    let reason: String
    let proposedAt: Date
    var approvals: [String: Bool]
    var status: AmendmentStatus
}

enum AmendmentStatus: String, Codable {
    case proposed = "Proposed"
    case approved = "Approved"
    case rejected = "Rejected"
    case active = "Active"
}

struct DigitalSignature: Codable {
    let playerId: String
    let contractId: String
    let token: String
    let sessionId: String
    let timestamp: Date
    let ipAddress: String?
}

// MARK: - Route Templates

struct RouteTemplate: Codable, Identifiable {
    let id: String
    var name: String
    var description: String
    let creatorId: String
    let routeData: RouteDesignData
    let category: TemplateCategory
    let tags: [String]
    let isPublic: Bool
    let createdAt: Date
    var lastUpdated: Date
    var usageCount: Int
    var rating: Double
    var reviews: [TemplateReview]
    
    init(id: String, name: String, description: String, creatorId: String, 
         routeData: RouteDesignData, isPublic: Bool, createdAt: Date, usageCount: Int) {
        self.id = id
        self.name = name
        self.description = description
        self.creatorId = creatorId
        self.routeData = routeData
        self.category = .general
        self.tags = []
        self.isPublic = isPublic
        self.createdAt = createdAt
        self.lastUpdated = createdAt
        self.usageCount = usageCount
        self.rating = 0.0
        self.reviews = []
    }
}

enum TemplateCategory: String, Codable, CaseIterable {
    case general = "General"
    case container = "Container"
    case bulk = "Bulk"
    case refrigerated = "Refrigerated"
    case hazardous = "Hazardous"
    case express = "Express"
    case longHaul = "Long Haul"
    case regional = "Regional"
    case multimodal = "Multimodal"
}

struct TemplateReview: Codable, Identifiable {
    let id: String
    let templateId: String
    let reviewerId: String
    let rating: Int // 1-5
    let comment: String
    let createdAt: Date
}

struct TemplateApplication: Codable {
    let templateId: String
    let sessionId: String
    let appliedBy: String
    let appliedAt: Date
    let customizations: [String: AnyCodable]
}

// MARK: - Performance & Metrics

struct OperationalThroughput {
    var totalVolume: Double = 0.0
    var averageDeliveryTime: TimeInterval = 0.0
    var efficiencyRating: Double = 0.0
    var costEffectiveness: Double = 0.0
    var collaborationBonus: Double = 0.0
    
    mutating func updateMetrics(_ update: PerformanceUpdate) {
        totalVolume = update.totalVolume
        averageDeliveryTime = update.averageDeliveryTime
        efficiencyRating = update.efficiencyRating
        costEffectiveness = update.costEffectiveness
    }
}

struct OperationalThroughputResult: Codable {
    let totalVolume: Double
    let averageDeliveryTime: TimeInterval
    let efficiencyRating: Double
    let costEffectiveness: Double
    let collaborationBonus: Double
    
    init() {
        self.totalVolume = 0.0
        self.averageDeliveryTime = 0.0
        self.efficiencyRating = 0.0
        self.costEffectiveness = 0.0
        self.collaborationBonus = 0.0
    }
    
    init(totalVolume: Double, averageDeliveryTime: TimeInterval, efficiencyRating: Double, 
         costEffectiveness: Double, collaborationBonus: Double) {
        self.totalVolume = totalVolume
        self.averageDeliveryTime = averageDeliveryTime
        self.efficiencyRating = efficiencyRating
        self.costEffectiveness = costEffectiveness
        self.collaborationBonus = collaborationBonus
    }
}

struct RoutePerformanceMetrics: Codable {
    let routeId: String
    let timeframe: TimeInterval
    let totalVolume: Double
    let averageDeliveryTime: TimeInterval
    let efficiencyRating: Double
    let costEffectiveness: Double
    let onTimePerformance: Double
    let customerSatisfaction: Double
    let environmentalImpact: EnvironmentalMetrics
    let lastUpdated: Date
}

struct EnvironmentalMetrics: Codable {
    let carbonEmissions: Double
    let fuelConsumption: Double
    let noiseLevel: Double
    let wasteGeneration: Double
}

struct CollaborationMetrics {
    var activeSessions: Int = 0
    var totalParticipants: Int = 0
    var averageSessionDuration: TimeInterval = 0.0
    var collaborationEfficiency: Double = 0.0
    var conflictRate: Double = 0.0
}

struct PerformanceUpdate: Codable {
    let routeId: String
    let totalVolume: Double
    let averageDeliveryTime: TimeInterval
    let efficiencyRating: Double
    let costEffectiveness: Double
    let timestamp: Date
}

struct PerformanceSubscription: Codable {
    let routeId: String
    let playerId: String
    let startTime: Date
    let updateFrequency: TimeInterval
    
    init(routeId: String, playerId: String, startTime: Date) {
        self.routeId = routeId
        self.playerId = playerId
        self.startTime = startTime
        self.updateFrequency = 5.0 // 5 seconds
    }
}

// MARK: - Conflict Resolution

struct EditConflict: Codable, Identifiable {
    let id: String
    let editId: String
    let routeId: String
    let conflictingPlayerId: String
    let conflictType: ConflictType
    let timestamp: Date
    let error: String
    
    init(editId: String, routeId: String, conflictingPlayerId: String, conflictType: ConflictType, timestamp: Date, error: String) {
        self.id = UUID().uuidString
        self.editId = editId
        self.routeId = routeId
        self.conflictingPlayerId = conflictingPlayerId
        self.conflictType = conflictType
        self.timestamp = timestamp
        self.error = error
    }
}

enum ConflictType: String, Codable, CaseIterable {
    case simultaneousEdit = "Simultaneous Edit"
    case incompatibleChanges = "Incompatible Changes"
    case constraintViolation = "Constraint Violation"
    case permissionDenied = "Permission Denied"
    case dataCorruption = "Data Corruption"
}

struct ConflictResolution: Codable {
    let conflictId: String
    let resolutionType: ResolutionType
    let resolvedBy: String
    let resolvedAt: Date
    let resolutionData: [String: AnyCodable]
}

enum ResolutionType: String, Codable, CaseIterable {
    case lastWriteWins = "Last Write Wins"
    case merge = "Merge"
    case revert = "Revert"
    case manual = "Manual"
    case vote = "Community Vote"
}

// MARK: - Real-Time Users

struct RealTimeUser: Codable, Identifiable {
    let id: String
    let playerId: String
    let sessionId: String
    let lastActivity: Date
    var status: UserStatus
    let cursor: CollaborativeCursor?
    
    init(playerId: String, sessionId: String, lastActivity: Date, status: UserStatus) {
        self.id = UUID().uuidString
        self.playerId = playerId
        self.sessionId = sessionId
        self.lastActivity = lastActivity
        self.status = status
        self.cursor = nil
    }
}

enum UserStatus: String, Codable {
    case active = "Active"
    case idle = "Idle"
    case away = "Away"
    case disconnected = "Disconnected"
}

struct CollaborationHeartbeat: Codable {
    let sessionId: String
    let playerId: String
    let timestamp: Date
    let status: UserStatus
    let activity: String?
    
    init(sessionId: String, playerId: String, timestamp: Date, status: UserStatus) {
        self.sessionId = sessionId
        self.playerId = playerId
        self.timestamp = timestamp
        self.status = status
        self.activity = nil
    }
}

// MARK: - Network Message Types

enum CollaborativeAction: Codable {
    case sessionCreated(CollaborationSession)
    case participantJoined(String, String) // session ID, player ID
    case participantLeft(String, String) // session ID, player ID
    case routeCreated(SharedTradeRoute)
    case liveEdit(LiveEdit)
    case cursorMoved(CollaborativeCursor)
    case conflictDetected(EditConflict)
    case conflictResolved(ConflictResolution)
    case contractProposed(CollaborativeContract)
    case contractSigned(String, String, Bool) // contract ID, player ID, all signed
    case templateApplied(TemplateApplication)
    case invitationSent(CollaborationInvitation)
    case invitationResponse(InvitationResponse)
    case heartbeat(CollaborationHeartbeat)
    case performanceUpdate(PerformanceUpdate)
}

enum CollaborativeUpdate: Codable {
    case liveEdit(LiveEdit)
    case cursorMoved(CollaborativeCursor)
    case participantJoined(String, String) // session ID, player ID
    case participantLeft(String, String) // session ID, player ID
    case conflictDetected(EditConflict)
    case conflictResolved(ConflictResolution)
    case performanceUpdate(PerformanceUpdate)
}

// MARK: - Error Types

enum CollaborativeError: LocalizedError {
    case sessionNotFound
    case notInvited
    case notParticipant
    case invalidRouteData
    case contractNotFound
    case notContractParticipant
    case invalidSignature
    case templateNotFound
    case invitationNotFound
    case sessionFull
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .sessionNotFound:
            return "Collaboration session not found"
        case .notInvited:
            return "You are not invited to this session"
        case .notParticipant:
            return "You are not a participant in this session"
        case .invalidRouteData:
            return "Invalid route data provided"
        case .contractNotFound:
            return "Collaborative contract not found"
        case .notContractParticipant:
            return "You are not a participant in this contract"
        case .invalidSignature:
            return "Invalid digital signature"
        case .templateNotFound:
            return "Route template not found"
        case .invitationNotFound:
            return "Collaboration invitation not found"
        case .sessionFull:
            return "Collaboration session is full"
        case .permissionDenied:
            return "Permission denied for this action"
        }
    }
}

// MARK: - Extensions

extension GameMessage.MessageType {
    static let collaborativeAction = GameMessage.MessageType(rawValue: "collaborativeAction")!
}

extension MessagePayload {
    static func collaborativeAction(_ action: CollaborativeAction) -> MessagePayload {
        // This would need to be implemented in the MessagePayload enum
        return .system(SystemMessage(message: "Collaborative action", severity: "info"))
    }
    
    static func collaborativeUpdate(_ update: CollaborativeUpdate) -> MessagePayload {
        // This would need to be implemented in the MessagePayload enum  
        return .system(SystemMessage(message: "Collaborative update", severity: "info"))
    }
}

// MARK: - API Extensions

extension APIClient {
    func createCollaborationSession(session: CollaborationSession) async throws {
        // Implementation would create collaboration session on server
    }
    
    func joinCollaborationSession(sessionId: String, playerId: String) async throws {
        // Implementation would join collaboration session
    }
    
    func leaveCollaborationSession(sessionId: String, playerId: String) async throws {
        // Implementation would leave collaboration session
    }
    
    func getCollaborationSession(id: String) async throws -> CollaborationSession {
        // Implementation would fetch collaboration session
        throw NetworkError.custom("Not implemented")
    }
    
    func createSharedRoute(route: SharedTradeRoute) async throws {
        // Implementation would create shared route
    }
    
    func applyRouteEdit(edit: LiveEdit) async throws -> LiveEdit {
        // Implementation would apply route edit
        return edit
    }
    
    func createCollaborativeContract(contract: CollaborativeContract) async throws {
        // Implementation would create collaborative contract
    }
    
    func updateCollaborativeContract(contract: CollaborativeContract) async throws {
        // Implementation would update collaborative contract
    }
    
    func createRouteTemplate(template: RouteTemplate) async throws {
        // Implementation would create route template
    }
    
    func getRouteTemplates(category: TemplateCategory?, searchTerm: String?) async throws -> [RouteTemplate] {
        // Implementation would fetch route templates
        return []
    }
    
    func applyRouteTemplate(application: TemplateApplication) async throws {
        // Implementation would apply route template
    }
    
    func getRoutePerformanceMetrics(routeId: String, timeframe: TimeInterval) async throws -> RoutePerformanceMetrics? {
        // Implementation would fetch route performance metrics
        return nil
    }
    
    func subscribeToPerformanceUpdates(subscription: PerformanceSubscription) async throws {
        // Implementation would subscribe to performance updates
    }
    
    func sendCollaborationInvitation(invitation: CollaborationInvitation) async throws {
        // Implementation would send collaboration invitation
    }
    
    func respondToCollaborationInvitation(response: InvitationResponse) async throws {
        // Implementation would respond to collaboration invitation
    }
}