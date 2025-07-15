import Foundation
import CoreData
import Combine

/// Manages offline gameplay and data synchronization
class OfflineManager: ObservableObject {
    static let shared = OfflineManager()
    
    @Published var isOfflineMode: Bool = false
    @Published var hasPendingSync: Bool = false
    
    private let persistentContainer: NSPersistentContainer
    private let apiClient = APIClient.shared
    private let reachability = NetworkReachability()
    
    private var syncQueue = OperationQueue()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Initialize Core Data stack
        persistentContainer = NSPersistentContainer(name: "FlexPortOffline")
        persistentContainer.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load Core Data stack: \(error)")
            }
        }
        
        syncQueue.maxConcurrentOperationCount = 1
        syncQueue.qualityOfService = .background
        
        setupReachabilityMonitoring()
    }
    
    private func setupReachabilityMonitoring() {
        reachability.isConnectedPublisher
            .sink { [weak self] isConnected in
                self?.handleConnectivityChange(isConnected: isConnected)
            }
            .store(in: &cancellables)
    }
    
    private func handleConnectivityChange(isConnected: Bool) {
        if isConnected && isOfflineMode {
            // Transition from offline to online
            Task {
                await syncPendingData()
            }
        }
        
        isOfflineMode = !isConnected
    }
    
    /// Save game action for offline play
    func saveOfflineAction(_ action: GameAction, sessionId: String) {
        let context = persistentContainer.viewContext
        
        let offlineAction = OfflineAction(context: context)
        offlineAction.id = UUID()
        offlineAction.sessionId = sessionId
        offlineAction.actionData = try? JSONEncoder().encode(action)
        offlineAction.timestamp = Date()
        offlineAction.isSynced = false
        
        do {
            try context.save()
            hasPendingSync = true
        } catch {
            print("Failed to save offline action: \(error)")
        }
    }
    
    /// Save game state snapshot for offline continuity
    func saveGameStateSnapshot(_ state: GameState, sessionId: String) {
        let context = persistentContainer.viewContext
        
        // Remove old snapshots for this session
        let fetchRequest: NSFetchRequest<GameStateSnapshot> = GameStateSnapshot.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "sessionId == %@", sessionId)
        
        do {
            let oldSnapshots = try context.fetch(fetchRequest)
            oldSnapshots.forEach { context.delete($0) }
            
            // Save new snapshot
            let snapshot = GameStateSnapshot(context: context)
            snapshot.id = UUID()
            snapshot.sessionId = sessionId
            snapshot.stateData = try? JSONEncoder().encode(state)
            snapshot.timestamp = Date()
            snapshot.turn = Int32(state.turn)
            
            try context.save()
        } catch {
            print("Failed to save game state snapshot: \(error)")
        }
    }
    
    /// Load the latest game state for a session
    func loadGameStateSnapshot(sessionId: String) -> GameState? {
        let context = persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<GameStateSnapshot> = GameStateSnapshot.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "sessionId == %@", sessionId)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        fetchRequest.fetchLimit = 1
        
        do {
            if let snapshot = try context.fetch(fetchRequest).first,
               let data = snapshot.stateData {
                return try JSONDecoder().decode(GameState.self, from: data)
            }
        } catch {
            print("Failed to load game state snapshot: \(error)")
        }
        
        return nil
    }
    
    /// Get pending offline actions
    func getPendingActions(sessionId: String) -> [GameAction] {
        let context = persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<OfflineAction> = OfflineAction.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "sessionId == %@ AND isSynced == %@", sessionId, NSNumber(value: false))
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        
        do {
            let offlineActions = try context.fetch(fetchRequest)
            return offlineActions.compactMap { offlineAction in
                guard let data = offlineAction.actionData else { return nil }
                return try? JSONDecoder().decode(GameAction.self, from: data)
            }
        } catch {
            print("Failed to fetch pending actions: \(error)")
            return []
        }
    }
    
    /// Sync all pending data with server
    func syncPendingData() async {
        guard !isOfflineMode else { return }
        
        let context = persistentContainer.newBackgroundContext()
        
        // Get all sessions with pending actions
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "OfflineAction")
        fetchRequest.predicate = NSPredicate(format: "isSynced == %@", NSNumber(value: false))
        fetchRequest.resultType = .dictionaryResultType
        fetchRequest.propertiesToFetch = ["sessionId"]
        fetchRequest.returnsDistinctResults = true
        
        do {
            let results = try context.fetch(fetchRequest) as? [[String: Any]] ?? []
            let sessionIds = results.compactMap { $0["sessionId"] as? String }
            
            for sessionId in sessionIds {
                await syncSession(sessionId, context: context)
            }
            
            hasPendingSync = false
        } catch {
            print("Failed to sync pending data: \(error)")
        }
    }
    
    private func syncSession(_ sessionId: String, context: NSManagedObjectContext) async {
        // Get latest snapshot and pending actions
        let snapshotRequest: NSFetchRequest<GameStateSnapshot> = GameStateSnapshot.fetchRequest()
        snapshotRequest.predicate = NSPredicate(format: "sessionId == %@", sessionId)
        snapshotRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        snapshotRequest.fetchLimit = 1
        
        let actionsRequest: NSFetchRequest<OfflineAction> = OfflineAction.fetchRequest()
        actionsRequest.predicate = NSPredicate(format: "sessionId == %@ AND isSynced == %@", sessionId, NSNumber(value: false))
        actionsRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        
        do {
            guard let snapshot = try context.fetch(snapshotRequest).first,
                  let stateData = snapshot.stateData else { return }
            
            let pendingActions = try context.fetch(actionsRequest)
            let actions = pendingActions.compactMap { action -> GameAction? in
                guard let data = action.actionData else { return nil }
                return try? JSONDecoder().decode(GameAction.self, from: data)
            }
            
            // Create sync request
            let syncRequest = GameStateSyncRequest(
                playerId: getCurrentPlayerId(),
                sessionId: sessionId,
                localState: stateData,
                lastSyncTimestamp: snapshot.timestamp ?? Date(),
                pendingActions: actions
            )
            
            // Send sync request
            let response = try await apiClient.syncGameState(state: syncRequest)
            
            // Handle conflicts
            if !response.conflicts.isEmpty {
                await handleConflicts(response.conflicts, sessionId: sessionId)
            }
            
            // Mark actions as synced
            pendingActions.forEach { $0.isSynced = true }
            
            // Update local state with server state
            if let serverState = try? JSONDecoder().decode(GameState.self, from: response.serverState) {
                saveGameStateSnapshot(serverState, sessionId: sessionId)
            }
            
            try context.save()
            
        } catch {
            print("Failed to sync session \(sessionId): \(error)")
        }
    }
    
    private func handleConflicts(_ conflicts: [ConflictResolution], sessionId: String) async {
        // Notify game manager about conflicts
        // In a real implementation, this would update the UI to show conflict resolutions
        for conflict in conflicts {
            print("Conflict resolved: \(conflict.reason)")
        }
    }
    
    private func getCurrentPlayerId() -> String {
        // In production, get from authentication service
        return UserDefaults.standard.string(forKey: "playerId") ?? "unknown"
    }
}

// MARK: - Core Data Models
extension OfflineManager {
    func createOfflineDataModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        // OfflineAction entity
        let offlineAction = NSEntityDescription()
        offlineAction.name = "OfflineAction"
        offlineAction.managedObjectClassName = "OfflineAction"
        
        let actionId = NSAttributeDescription()
        actionId.name = "id"
        actionId.attributeType = .UUIDAttributeType
        
        let sessionId = NSAttributeDescription()
        sessionId.name = "sessionId"
        sessionId.attributeType = .stringAttributeType
        
        let actionData = NSAttributeDescription()
        actionData.name = "actionData"
        actionData.attributeType = .binaryDataAttributeType
        
        let timestamp = NSAttributeDescription()
        timestamp.name = "timestamp"
        timestamp.attributeType = .dateAttributeType
        
        let isSynced = NSAttributeDescription()
        isSynced.name = "isSynced"
        isSynced.attributeType = .booleanAttributeType
        isSynced.defaultValue = false
        
        offlineAction.properties = [actionId, sessionId, actionData, timestamp, isSynced]
        
        // GameStateSnapshot entity
        let stateSnapshot = NSEntityDescription()
        stateSnapshot.name = "GameStateSnapshot"
        stateSnapshot.managedObjectClassName = "GameStateSnapshot"
        
        let snapshotId = NSAttributeDescription()
        snapshotId.name = "id"
        snapshotId.attributeType = .UUIDAttributeType
        
        let snapshotSessionId = NSAttributeDescription()
        snapshotSessionId.name = "sessionId"
        snapshotSessionId.attributeType = .stringAttributeType
        
        let stateData = NSAttributeDescription()
        stateData.name = "stateData"
        stateData.attributeType = .binaryDataAttributeType
        
        let snapshotTimestamp = NSAttributeDescription()
        snapshotTimestamp.name = "timestamp"
        snapshotTimestamp.attributeType = .dateAttributeType
        
        let turn = NSAttributeDescription()
        turn.name = "turn"
        turn.attributeType = .integer32AttributeType
        
        stateSnapshot.properties = [snapshotId, snapshotSessionId, stateData, snapshotTimestamp, turn]
        
        model.entities = [offlineAction, stateSnapshot]
        
        return model
    }
}

// Core Data managed object classes
class OfflineAction: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var sessionId: String?
    @NSManaged var actionData: Data?
    @NSManaged var timestamp: Date?
    @NSManaged var isSynced: Bool
}

class GameStateSnapshot: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var sessionId: String?
    @NSManaged var stateData: Data?
    @NSManaged var timestamp: Date?
    @NSManaged var turn: Int32
}